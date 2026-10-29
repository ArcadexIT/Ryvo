import {
  Injectable,
  NotFoundException,
  ForbiddenException,
  BadRequestException,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { RealtimeService } from '../tracking/realtime.service';
import { NotificationsService } from '../notifications/notifications.service';
import { EmailService } from '../email/email.service';
import { SettingsService } from '../settings/settings.service';
import { PaymentsService } from '../payments/payments.service';
import { JobsService } from '../jobs/jobs.service';
import { BillingOpsService } from '../ops/billing-ops.service';
import { SubscriptionsService } from '../subscriptions/subscriptions.service';
import { MatchingService } from '../matching/matching.service';
import { CancelledBy } from '@ryvo/shared';
import { parsePagination, paginateMeta } from '../common/utils';
import { PaginationDto } from '../common/dto/pagination.dto';
import { JobStatus } from '@ryvo/database';

const ACTIVE_STATUSES: JobStatus[] = [
  'payment_pending',
  'matched',
  'provider_en_route',
  'arrived',
  'in_progress',
];

const PROVIDER_ALLOWED_TRANSITIONS: JobStatus[] = [
  'provider_en_route',
  'arrived',
  'in_progress',
  'completed',
];

const jobInclude = {
  serviceCategory: true,
  vehicle: true,
  customer: {
    include: { user: { select: { id: true, fullName: true, phone: true, avatarUrl: true } } },
  },
};

const STATUS_MESSAGES: Partial<Record<JobStatus, { title: string; body: string }>> = {
  payment_pending: { title: 'Payment processing', body: 'Ride payment is being confirmed' },
  matched: { title: 'Driver accepted', body: 'Your driver is getting ready' },
  provider_en_route: { title: 'Driver on the way', body: 'Your driver is heading to pickup' },
  arrived: { title: 'Driver arrived', body: 'Your driver is at the pickup point' },
  in_progress: { title: 'Trip started', body: 'You are on the way to your dropoff' },
  completed: { title: 'Trip completed', body: 'Your ride is complete' },
};

@Injectable()
export class ProviderJobsService {
  constructor(
    private prisma: PrismaService,
    private realtime: RealtimeService,
    private notifications: NotificationsService,
    private email: EmailService,
    private settings: SettingsService,
    private payments: PaymentsService,
    private jobs: JobsService,
    private billing: BillingOpsService,
    private subscriptions: SubscriptionsService,
    private matching: MatchingService,
  ) {}

  async getActive(providerId: string) {
    const jobs = await this.prisma.job.findMany({
      where: { providerId, status: { in: ACTIVE_STATUSES } },
      include: jobInclude,
    });
    if (!jobs.length) return null;

    const rank: Partial<Record<JobStatus, number>> = {
      in_progress: 0,
      arrived: 1,
      provider_en_route: 2,
      payment_pending: 3,
      matched: 4,
    };
    jobs.sort((a, b) => {
      const byStatus = (rank[a.status] ?? 9) - (rank[b.status] ?? 9);
      if (byStatus !== 0) return byStatus;
      return (a.matchedAt?.getTime() ?? 0) - (b.matchedAt?.getTime() ?? 0);
    });

    const current = jobs[0];
    const next = jobs.find(
      (job) => job.id !== current.id && (job.status === 'matched' || job.status === 'payment_pending'),
    );
    if (!next) return current;
    return { ...current, nextPickupAddress: next.pickupAddress, nextJobId: next.id };
  }

  async getHistory(providerId: string, dto: PaginationDto) {
    const { page, limit, skip } = parsePagination(dto);
    const where = {
      providerId,
      status: {
        in: [
          'completed',
          'cancelled_by_customer',
          'cancelled_by_provider',
          'cancelled_by_admin',
        ] as JobStatus[],
      },
    };
    const [items, total] = await Promise.all([
      this.prisma.job.findMany({
        where,
        skip,
        take: limit,
        orderBy: { createdAt: 'desc' },
        include: jobInclude,
      }),
      this.prisma.job.count({ where }),
    ]);
    return { items, meta: paginateMeta(page, limit, total) };
  }

  async getOne(providerId: string, jobId: string) {
    const job = await this.prisma.job.findUnique({
      where: { id: jobId },
      include: {
        ...jobInclude,
        payment: true,
        ratings: true,
        providerEarning: {
          select: { netAmount: true, grossAmount: true, platformFee: true },
        },
      },
    });
    if (!job) throw new NotFoundException('Job not found');
    if (job.providerId !== providerId) {
      throw new ForbiddenException('Job does not belong to this driver');
    }
    return job;
  }

  async confirmStart(providerId: string, jobId: string) {
    await this.getOne(providerId, jobId);
    return this.jobs.confirmJobStart(jobId, 'provider', providerId);
  }

  async cancelJob(providerId: string, jobId: string, reason?: string) {
    const job = await this.getOne(providerId, jobId);
    if (job.status === 'completed' || job.status.startsWith('cancelled')) {
      throw new BadRequestException('Job is already closed');
    }
    return this.jobs.cancelJob(jobId, CancelledBy.PROVIDER, reason, providerId);
  }

  async updateStatus(
    providerId: string,
    jobId: string,
    toStatus: JobStatus,
    location?: { lat?: number; lng?: number },
  ) {
    if (!PROVIDER_ALLOWED_TRANSITIONS.includes(toStatus)) {
      throw new BadRequestException(`Drivers cannot set status ${toStatus}`);
    }

    const job = await this.getOne(providerId, jobId);
    if (job.status === 'completed' || job.status.startsWith('cancelled')) {
      throw new BadRequestException('Job is already closed');
    }
    if (job.status === 'payment_pending') {
      throw new BadRequestException('Waiting for customer payment');
    }
    if (toStatus === 'in_progress' && job.status !== 'arrived' && job.status !== 'in_progress') {
      throw new BadRequestException('Start the trip after you arrive at pickup');
    }
    if (toStatus === 'in_progress' && job.jobType === 'parcel' && !job.pickupPhotoUrl) {
      throw new BadRequestException('Upload a pickup photo before starting the parcel trip');
    }

    let fareJob = job;
    if (toStatus === 'completed') {
      if (job.jobType === 'parcel') {
        if (!job.dropoffPhotoUrl) {
          throw new BadRequestException('Upload proof of delivery before completing the parcel job');
        }
        if ((await this.settings.isParcelOtpEnabled()) && !job.recipientOtp) {
          throw new BadRequestException('Recipient OTP is missing');
        }
      }
      await this.jobs.finalizeFare(jobId);
      await this.payments.chargeForCompletedJob(jobId);
      fareJob = await this.getOne(providerId, jobId);
    }

    const updated = await this.prisma.$transaction(async (tx) => {
      const result = await tx.job.update({
        where: { id: jobId },
        data: {
          status: toStatus,
          ...(toStatus === 'arrived' && { arrivedAt: job.arrivedAt ?? new Date() }),
          ...(toStatus === 'in_progress' && { startedAt: job.startedAt ?? new Date() }),
          ...(toStatus === 'completed' && { completedAt: new Date() }),
        },
      });
      await tx.jobStatusHistory.create({
        data: {
          jobId,
          fromStatus: job.status,
          toStatus,
          changedByType: 'provider',
          changedById: providerId,
        },
      });

      if (toStatus === 'completed') {
        await this.settleCompletion(tx, fareJob, providerId);
      }
      return result;
    });

    if (location?.lat != null && location?.lng != null) {
      await this.prisma.provider
        .update({
          where: { id: providerId },
          data: { currentLat: location.lat, currentLng: location.lng, lastLocationAt: new Date() },
        })
        .catch(() => undefined);
    }

    this.realtime.emitToJob(jobId, 'job:status', {
      jobId,
      status: toStatus,
      providerId,
    });

    const msg = STATUS_MESSAGES[toStatus];
    if (msg) {
      void this.notifications.notify({
        userId: job.customer.user.id,
        type: `job_${toStatus}`,
        title: msg.title,
        body: msg.body,
        data: { jobId },
      });
    }

    if (toStatus === 'completed') {
      void this.sendCompletionEmails(jobId);
      await this.matching
        .reconcileProviderAfterJobClosed(providerId, jobId, 'complete')
        .catch(() => undefined);
    }

    return updated;
  }

  /** Email receipt to customer and provider after a completed job. */
  private async sendCompletionEmails(jobId: string) {
    await this.billing.issueForCompletedJob(jobId).catch(() => undefined);
    if (!this.email.enabled) return;

    const job = await this.prisma.job.findUnique({
      where: { id: jobId },
      include: {
        serviceCategory: { select: { name: true } },
        customer: { include: { user: { select: { email: true, fullName: true } } } },
        provider: { include: { user: { select: { email: true, fullName: true } } } },
        providerEarning: { select: { netAmount: true } },
      },
    });
    if (!job?.provider || !job.completedAt) return;

    const customerEmail = job.customer.user.email?.trim() ?? '';
    const providerEmail = job.provider.user.email?.trim() ?? '';
    if (!customerEmail && !providerEmail) return;

    await this.email.sendJobCompletedEmails({
      jobNumber: job.jobNumber,
      serviceName: job.serviceCategory?.name ?? 'Ride',
      fare: Number(job.finalFare ?? job.estimatedFare ?? 0),
      completedAt: job.completedAt,
      customer: {
        email: customerEmail,
        name: job.customer.user.fullName ?? 'Customer',
      },
      provider: {
        email: providerEmail,
        name: job.provider.user.fullName ?? 'Driver',
      },
      providerNetEarning: job.providerEarning
        ? Number(job.providerEarning.netAmount)
        : undefined,
    });
  }

  /** Create the provider earning and free the provider on job completion. */
  private async settleCompletion(
    tx: Parameters<Parameters<PrismaService['$transaction']>[0]>[0],
    job: { id: string; estimatedFare: unknown; finalFare: unknown },
    providerId: string,
  ) {
    const existing = await tx.providerEarning.findUnique({ where: { jobId: job.id } });
    if (existing) return;

    const provider = await tx.provider.findUnique({
      where: { id: providerId },
      select: { commissionRate: true },
    });
    const fallback =
      provider?.commissionRate != null
        ? Number(provider.commissionRate)
        : await this.settings.getDefaultCommissionRate();
    const rate = await this.subscriptions.getActiveCommissionRate(providerId, fallback);

    const gross = Number(job.finalFare ?? job.estimatedFare ?? 0);
    const platformFee = Math.round(gross * rate * 100) / 100;
    const netAmount = Math.round((gross - platformFee) * 100) / 100;

    await tx.providerEarning.create({
      data: {
        jobId: job.id,
        providerId,
        grossAmount: gross,
        platformFee,
        netAmount,
        payoutStatus: 'pending',
      },
    });

    await tx.provider.update({
      where: { id: providerId },
      data: { totalJobs: { increment: 1 } },
    });
  }
}
