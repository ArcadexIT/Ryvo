import { Injectable, NotFoundException, BadRequestException, ForbiddenException, Inject, forwardRef } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { PaymentsService } from '../payments/payments.service';
import { RealtimeService } from '../tracking/realtime.service';
import { SettingsService } from '../settings/settings.service';
import { MatchingService } from '../matching/matching.service';
import { NotificationsService } from '../notifications/notifications.service';
import { CoverageService } from '../ops/coverage.service';
import { parsePagination, paginateMeta, generateJobNumber } from '../common/utils';
import { PaginationDto } from '../common/dto/pagination.dto';
import { Prisma, JobStatus } from '@ryvo/database';
import { CancelledBy } from '@ryvo/shared';

function haversineKm(lat1: number, lng1: number, lat2: number, lng2: number): number {
  const R = 6371;
  const dLat = ((lat2 - lat1) * Math.PI) / 180;
  const dLng = ((lng2 - lng1) * Math.PI) / 180;
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos((lat1 * Math.PI) / 180) *
      Math.cos((lat2 * Math.PI) / 180) *
      Math.sin(dLng / 2) ** 2;
  return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

@Injectable()
export class JobsService {
  constructor(
    private prisma: PrismaService,
    private payments: PaymentsService,
    private realtime: RealtimeService,
    private settings: SettingsService,
    @Inject(forwardRef(() => MatchingService))
    private matching: MatchingService,
    private notifications: NotificationsService,
    private coverage: CoverageService,
  ) {}

  async findAll(
    dto: PaginationDto & {
      status?: JobStatus;
      customerId?: string;
      providerId?: string;
      from?: string;
      to?: string;
    },
  ) {
    const { page, limit, skip } = parsePagination(dto);
    const where: Prisma.JobWhereInput = {
      ...(dto.status && { status: dto.status }),
      ...(dto.customerId && { customerId: dto.customerId }),
      ...(dto.providerId && { providerId: dto.providerId }),
      ...(dto.from || dto.to
        ? {
            createdAt: {
              ...(dto.from && { gte: new Date(dto.from) }),
              ...(dto.to && { lte: new Date(dto.to) }),
            },
          }
        : {}),
      ...(dto.search && {
        OR: [
          { jobNumber: { contains: dto.search, mode: 'insensitive' } },
          { pickupAddress: { contains: dto.search, mode: 'insensitive' } },
        ],
      }),
    };

    const [items, total] = await Promise.all([
      this.prisma.job.findMany({
        where,
        skip,
        take: limit,
        orderBy: { createdAt: 'desc' },
        include: {
          customer: { include: { user: { select: { fullName: true, phone: true } } } },
          provider: { include: { user: { select: { fullName: true, phone: true } } } },
          serviceCategory: true,
          vehicle: true,
        },
      }),
      this.prisma.job.count({ where }),
    ]);

    return { items, meta: paginateMeta(page, limit, total) };
  }

  async findOne(id: string) {
    const job = await this.prisma.job.findUnique({
      where: { id },
      include: {
        customer: { include: { user: { select: { id: true, fullName: true, phone: true } } } },
        provider: { include: { user: { select: { id: true, fullName: true, phone: true } } } },
        serviceCategory: true,
        vehicle: true,
        payment: true,
        ratings: true,
        offers: { include: { provider: { include: { user: { select: { fullName: true } } } } } },
        bids: {
          include: {
            provider: {
              include: { user: { select: { fullName: true, avatarUrl: true } } },
            },
          },
        },
      },
    });
    if (!job) throw new NotFoundException('Job not found');
    return this.withPickupEta(job);
  }

  async findByCustomer(customerId: string, dto: PaginationDto) {
    return this.findAll({ ...dto, customerId });
  }

  async findActiveByCustomer(customerId: string) {
    const activeStatuses: JobStatus[] = [
      'searching',
      'payment_pending',
      'matched',
      'provider_en_route',
      'arrived',
      'in_progress',
    ];
    const job = await this.prisma.job.findFirst({
      where: {
        customerId,
        status: { in: activeStatuses },
        completedAt: null,
        cancelledAt: null,
      },
      orderBy: { createdAt: 'desc' },
      include: {
        serviceCategory: true,
        vehicle: true,
        provider: {
          include: {
            user: { select: { id: true, fullName: true, phone: true, avatarUrl: true } },
          },
        },
        payment: true,
      },
    });

    // Payment already secured, but the job was left on payment_pending.
    if (
      job?.status === 'payment_pending' &&
      (job.payment?.status === 'held' || job.payment?.status === 'paid')
    ) {
      await this.payments.advanceJobAfterHold(job.id);
      const refreshed = await this.prisma.job.findFirst({
        where: {
          id: job.id,
          status: { in: activeStatuses },
          completedAt: null,
          cancelledAt: null,
        },
        include: {
          serviceCategory: true,
          vehicle: true,
          provider: {
            include: {
              user: { select: { id: true, fullName: true, phone: true, avatarUrl: true } },
            },
          },
          payment: true,
        },
      });
      return refreshed ? this.withPickupEta(refreshed) : refreshed;
    }

    return job ? this.withPickupEta(job) : job;
  }

  private async withPickupEta<T extends {
    id: string;
    providerId: string | null;
    pickupLat: unknown;
    pickupLng: unknown;
  }>(job: T) {
    const pickupEtaMinutes = await this.matching.pickupEtaMinutesForJob(job);
    if (pickupEtaMinutes == null) return job;
    return { ...job, pickupEtaMinutes };
  }

  async updateStatus(
    jobId: string,
    toStatus: JobStatus,
    changedBy: { type: string; id?: string },
    note?: string,
  ) {
    const job = await this.findOne(jobId);
    const updated = await this.prisma.$transaction(async (tx) => {
      const result = await tx.job.update({
        where: { id: jobId },
        data: {
          status: toStatus,
          ...(toStatus === 'matched' && { matchedAt: new Date() }),
          ...(toStatus === 'arrived' && { arrivedAt: new Date() }),
          ...(toStatus === 'in_progress' && !job.startedAt && { startedAt: new Date() }),
          ...(toStatus === 'completed' && { completedAt: new Date() }),
        },
      });
      await tx.jobStatusHistory.create({
        data: {
          jobId,
          fromStatus: job.status,
          toStatus,
          changedByType: changedBy.type,
          changedById: changedBy.id,
          note,
        },
      });
      return result;
    });
    if (toStatus === 'completed') {
      await this.finalizeFare(jobId);
      await this.payments.chargeForCompletedJob(jobId);
    }
    return updated;
  }

  async confirmJobStart(
    jobId: string,
    party: 'customer' | 'provider',
    actorId: string,
  ) {
    const job = await this.findOne(jobId);
    if (job.status === 'completed' || job.status.startsWith('cancelled')) {
      throw new BadRequestException('Job is already closed');
    }
    if (job.status !== 'arrived' && job.status !== 'in_progress') {
      throw new BadRequestException('Job start can only be confirmed after the driver arrives');
    }
    if (job.jobType === 'parcel' && party === 'provider' && !job.pickupPhotoUrl) {
      throw new BadRequestException('Upload a pickup photo before starting the parcel trip');
    }
    if (party === 'customer' && job.customerId !== actorId) {
      throw new ForbiddenException('Job does not belong to this customer');
    }
    if (party === 'provider' && job.providerId !== actorId) {
      throw new ForbiddenException('Job does not belong to this driver');
    }

    const now = new Date();
    const customerAt = job.customerStartConfirmedAt ?? (party === 'customer' ? now : null);
    const providerAt = job.providerStartConfirmedAt ?? (party === 'provider' ? now : null);
    const bothConfirmed = !!(customerAt && providerAt);
    const shouldStart = bothConfirmed && !job.startedAt;

    const updated = await this.prisma.$transaction(async (tx) => {
      const result = await tx.job.update({
        where: { id: jobId },
        data: {
          customerStartConfirmedAt: customerAt,
          providerStartConfirmedAt: providerAt,
          ...(shouldStart && { status: 'in_progress', startedAt: now }),
        },
      });
      if (shouldStart) {
        await tx.jobStatusHistory.create({
          data: {
            jobId,
            fromStatus: job.status,
            toStatus: 'in_progress',
            changedByType: party,
            changedById: actorId,
            note: 'Both parties confirmed job start',
          },
        });
      }
      return result;
    });

    if (shouldStart) {
      this.realtime.emitToJob(jobId, 'job:status', {
        jobId,
        status: 'in_progress',
        providerId: job.providerId,
      });
    } else {
      this.realtime.emitToJob(jobId, 'job:status', {
        jobId,
        status: updated.status,
        providerId: job.providerId,
        customerStartConfirmedAt: updated.customerStartConfirmedAt,
        providerStartConfirmedAt: updated.providerStartConfirmedAt,
      });
    }

    return this.findOne(jobId);
  }

  async assignProvider(jobId: string, providerId: string, adminId?: string) {
    const job = await this.findOne(jobId);
    if (['completed', 'cancelled_by_customer', 'cancelled_by_provider', 'cancelled_by_admin'].includes(job.status)) {
      throw new BadRequestException('Cannot assign a driver to a closed job');
    }
    const provider = await this.prisma.provider.findUnique({ where: { id: providerId } });
    if (!provider) throw new NotFoundException('Driver not found');

    return this.prisma.$transaction(async (tx) => {
      const updated = await tx.job.update({
        where: { id: jobId },
        data: { providerId, status: 'matched', matchedAt: new Date() },
      });
      await tx.jobStatusHistory.create({
        data: {
          jobId,
          fromStatus: job.status,
          toStatus: 'matched',
          changedByType: 'admin',
          changedById: adminId,
          note: `Assigned provider ${providerId}`,
        },
      });
      return updated;
    });
  }

  async cancelJob(
    jobId: string,
    cancelledBy: CancelledBy,
    reason?: string,
    actorId?: string,
  ) {
    const job = await this.findOne(jobId);
    if (job.status === 'completed' || job.status === 'no_provider_found' || job.status.startsWith('cancelled')) {
      throw new BadRequestException('Job is already closed');
    }

    if (cancelledBy === 'provider' && job.providerId) {
      return this.reassignAfterProviderCancel(job, reason, actorId);
    }

    const cancellationFeeAmount =
      cancelledBy === 'customer' ? await this.settings.getCustomerCancelFee(job.status) : 0;
    const providerPenaltyAmount =
      cancelledBy === 'provider' ? await this.settings.getProviderCancelPenalty(job.status) : 0;

    const statusMap: Record<CancelledBy, JobStatus> = {
      customer: 'cancelled_by_customer',
      provider: 'cancelled_by_provider',
      admin: 'cancelled_by_admin',
      system: 'cancelled_by_admin',
    };
    const toStatus = statusMap[cancelledBy];

    const updated = await this.prisma.$transaction(async (tx) => {
      const result = await tx.job.update({
        where: { id: jobId },
        data: {
          status: toStatus,
          cancelledAt: new Date(),
          cancelledBy,
          cancellationReason: reason,
          cancellationFeeAmount: cancellationFeeAmount || null,
          providerPenaltyAmount: providerPenaltyAmount || null,
        },
      });
      await tx.jobStatusHistory.create({
        data: {
          jobId,
          fromStatus: job.status,
          toStatus,
          changedByType: cancelledBy,
          changedById: actorId,
          note: reason,
        },
      });
      return result;
    });

    if (job.providerId) {
      await this.matching
        .reconcileProviderAfterJobClosed(job.providerId, jobId, 'cancel')
        .catch(() => undefined);
    }

    if (cancelledBy === 'customer') {
      await this.payments.settleCustomerCancellation(jobId, cancellationFeeAmount).catch(() => undefined);
    } else {
      await this.payments.releaseHoldForJob(jobId).catch(() => undefined);
    }

    if (cancelledBy === 'provider' && providerPenaltyAmount > 0 && job.provider?.user?.id) {
      await this.payments
        .applyProviderPenalty(job.provider.user.id, providerPenaltyAmount, jobId)
        .catch(() => undefined);
    }

    this.realtime.emitToJob(jobId, 'job:status', {
      jobId,
      status: toStatus,
      providerId: job.providerId,
    });

    if (cancelledBy === 'customer' && job.provider?.user?.id) {
      await this.notifications.notify({
        userId: job.provider.user.id,
        type: 'job_cancelled',
        title: 'Job cancelled',
        body: 'The customer cancelled this job.',
        data: { jobId, status: toStatus },
      });
      this.realtime.emitToUser(job.provider.user.id, 'job:status', {
        jobId,
        status: toStatus,
      });
    }

    return updated;
  }

  private async reassignAfterProviderCancel(
    job: Awaited<ReturnType<JobsService['findOne']>>,
    reason?: string,
    actorId?: string,
  ) {
    const providerId = job.providerId!;
    const excluded = Array.from(new Set([...(job.excludedProviderIds ?? []), providerId]));
    const updated = await this.prisma.$transaction(async (tx) => {
      const result = await tx.job.update({
        where: { id: job.id },
        data: {
          status: 'searching',
          providerId: null,
          excludedProviderIds: excluded,
          matchedAt: null,
        },
      });
      await tx.jobStatusHistory.create({
        data: {
          jobId: job.id,
          fromStatus: job.status,
          toStatus: 'searching',
          changedByType: 'provider',
          changedById: actorId,
          note: reason ?? 'Driver cancelled. Looking for another driver.',
        },
      });
      return result;
    });

    await this.matching
      .reconcileProviderAfterJobClosed(providerId, job.id, 'cancel')
      .catch(() => undefined);

    this.realtime.emitToJob(job.id, 'job:status', {
      jobId: job.id,
      status: 'searching',
      providerId: null,
      message: 'Your driver cancelled. We are looking for a new driver.',
    });
    if (job.customer.user?.id) {
      await this.notifications.notify({
        userId: job.customer.user.id,
        type: 'job_reassign',
        title: 'Looking for a new driver',
        body: 'Your driver cancelled. We are searching again.',
        data: { jobId: job.id, status: 'searching' },
      });
    }
    await this.matching.sendOffers(job.id).catch(() => undefined);
    return updated;
  }

  async getTimeline(jobId: string) {
    await this.findOne(jobId);
    return this.prisma.jobStatusHistory.findMany({
      where: { jobId },
      orderBy: { createdAt: 'asc' },
    });
  }

  async estimateFare(params: {
    serviceCategoryId: string;
    pickupLat: number;
    pickupLng: number;
    dropoffLat?: number;
    dropoffLng?: number;
    durationMin?: number;
    requireActive?: boolean;
  }) {
    const category = await this.prisma.serviceCategory.findFirst({
      where: {
        id: params.serviceCategoryId,
        ...(params.requireActive === false ? {} : { isActive: true }),
      },
    });
    if (!category) throw new NotFoundException('Ride class is not available');

    const rule = await this.prisma.servicePricingRule.findFirst({
      where: {
        serviceCategoryId: params.serviceCategoryId,
        isActive: true,
        OR: [{ effectiveTo: null }, { effectiveTo: { gte: new Date() } }],
      },
      orderBy: { effectiveFrom: 'desc' },
    });
    if (!rule) throw new NotFoundException('No active pricing rule for this ride class');

    const distanceKm =
      params.dropoffLat != null && params.dropoffLng != null
        ? haversineKm(params.pickupLat, params.pickupLng, params.dropoffLat, params.dropoffLng)
        : 0;
    const durationMin =
      params.durationMin ?? (distanceKm > 0 ? Math.max(1, Math.round((distanceKm / 30) * 60)) : 0);

    const base = Number(rule.baseFare);
    const perKm = Number(rule.perKmRate) * distanceKm;
    const perMinute = Number(rule.perMinuteRate) * durationMin;
    const subtotal = base + perKm + perMinute;
    const ruleSurge = Number(rule.surgeMultiplier);
    const safeRuleSurge = Number.isFinite(ruleSurge) && ruleSurge > 0 ? ruleSurge : 1;
    const platformSurge = (await this.settings.isSurgeEnabled())
      ? await this.settings.getSurgeMultiplier()
      : 1;
    const withSurge = subtotal * safeRuleSurge * platformSurge;
    const estimated = Math.max(withSurge, Number(rule.minFare));

    return {
      estimatedFare: Math.round(estimated * 100) / 100,
      distanceKm: Math.round(distanceKm * 100) / 100,
      durationMin,
      pricingRuleId: rule.id,
    };
  }

  /** Recompute the fare from the actual trip distance and time, then store it. */
  async finalizeFare(jobId: string) {
    const job = await this.prisma.job.findUnique({ where: { id: jobId } });
    if (!job) throw new NotFoundException('Job not found');

    if (job.jobType === 'bidding' && job.agreedFare != null) {
      const agreed = Number(job.agreedFare);
      return this.prisma.job.update({
        where: { id: jobId },
        data: { finalFare: agreed },
      });
    }

    const started = job.startedAt ?? job.arrivedAt ?? job.matchedAt ?? job.createdAt;
    const durationMin = Math.max(1, Math.round((Date.now() - started.getTime()) / 60000));
    const quote = await this.estimateFare({
      serviceCategoryId: job.serviceCategoryId,
      pickupLat: Number(job.pickupLat),
      pickupLng: Number(job.pickupLng),
      dropoffLat: job.dropoffLat != null ? Number(job.dropoffLat) : undefined,
      dropoffLng: job.dropoffLng != null ? Number(job.dropoffLng) : undefined,
      durationMin,
      requireActive: false,
    });

    const updated = await this.prisma.job.update({
      where: { id: jobId },
      data: {
        finalFare: quote.estimatedFare,
        distanceKm: quote.distanceKm,
        durationMin: quote.durationMin,
      },
    });
    await this.prisma.payment.updateMany({
      where: { jobId, status: { in: ['pending', 'failed'] } },
      data: { amount: quote.estimatedFare },
    });
    return updated;
  }

  async createJob(
    customerId: string,
    data: {
      vehicleId?: string;
      serviceCategoryId: string;
      pickupAddress: string;
      pickupLat: number;
      pickupLng: number;
      dropoffAddress?: string;
      dropoffLat?: number;
      dropoffLng?: number;
      customerNotes?: string;
      bookingType?: 'instant' | 'scheduled';
      scheduledAt?: string;
      promoCodeId?: string;
      paymentMethod: 'stripe' | 'wallet' | 'cash';
      stripePaymentMethodId?: string;
      jobType?: 'taxi' | 'bidding' | 'parcel';
      offeredPrice?: number;
      recipientName?: string;
      recipientPhone?: string;
      parcelSize?: 'small' | 'medium' | 'large';
      parcelNotes?: string;
      channel?: string;
    },
  ) {
    const customer = await this.prisma.customer.findUnique({ where: { id: customerId } });
    if (!customer) throw new BadRequestException('Customer not found');

    if (data.vehicleId) {
      const vehicle = await this.prisma.vehicle.findFirst({
        where: { id: data.vehicleId, customerId },
      });
      if (!vehicle) throw new BadRequestException('Vehicle not found for customer');
    }

    const pickupAddress = data.pickupAddress.trim();
    if (!pickupAddress || pickupAddress === 'Locating your position…') {
      throw new BadRequestException('Confirm a pickup address before requesting a ride');
    }
    const dropoffAddress = data.dropoffAddress?.trim() ?? '';
    if (!dropoffAddress || data.dropoffLat == null || data.dropoffLng == null) {
      throw new BadRequestException('Choose a dropoff before requesting a ride');
    }

    const area = await this.coverage.check(data.pickupLat, data.pickupLng, 'customer');
    if (!area.inside) {
      throw new ForbiddenException(area.message ?? 'RYVO is unavailable in the current area');
    }

    const category = await this.prisma.serviceCategory.findUnique({
      where: { id: data.serviceCategoryId },
    });
    if (!category?.isActive) throw new NotFoundException('Ride class is not available');

    const jobType = data.jobType ?? (category.businessType === 'parcel' ? 'parcel' : 'taxi');
    if (jobType === 'parcel' && category.businessType !== 'parcel') {
      throw new BadRequestException('Choose a parcel category for parcel delivery');
    }
    if (jobType !== 'parcel' && category.businessType === 'parcel') {
      throw new BadRequestException('Parcel categories can only be used for parcel delivery');
    }
    if (jobType === 'parcel') {
      if (!data.recipientName?.trim() || !data.recipientPhone?.trim()) {
        throw new BadRequestException('Recipient name and phone are required for parcel delivery');
      }
    }

    const fare = await this.estimateFare({
      serviceCategoryId: data.serviceCategoryId,
      pickupLat: data.pickupLat,
      pickupLng: data.pickupLng,
      dropoffLat: data.dropoffLat,
      dropoffLng: data.dropoffLng,
    });

    let estimatedFare = fare.estimatedFare;
    let offeredPrice: number | null = null;
    if (jobType === 'bidding') {
      const minRatio = await this.settings.getBidMinFareRatio();
      const maxRatio = await this.settings.getBidMaxFareRatio();
      const offered = Number(data.offeredPrice ?? fare.estimatedFare);
      const floor = Math.round(fare.estimatedFare * minRatio * 100) / 100;
      const ceiling = Math.round(fare.estimatedFare * maxRatio * 100) / 100;
      if (!Number.isFinite(offered) || offered < floor || offered > ceiling) {
        throw new BadRequestException(`Offer a price between ${floor} and ${ceiling}`);
      }
      offeredPrice = Math.round(offered * 100) / 100;
      estimatedFare = offeredPrice;
    }

    const recipientOtp =
      jobType === 'parcel' && (await this.settings.isParcelOtpEnabled())
        ? String(Math.floor(1000 + Math.random() * 9000))
        : null;

    const job = await this.prisma.$transaction(async (tx) => {
      const created = await tx.job.create({
        data: {
          jobNumber: generateJobNumber(),
          customerId,
          vehicleId: data.vehicleId ?? null,
          serviceCategoryId: data.serviceCategoryId,
          status: 'searching',
          jobType,
          bookingType: data.bookingType ?? 'instant',
          scheduledAt: data.scheduledAt ? new Date(data.scheduledAt) : null,
          pickupAddress,
          pickupLat: data.pickupLat,
          pickupLng: data.pickupLng,
          dropoffAddress,
          dropoffLat: data.dropoffLat,
          dropoffLng: data.dropoffLng,
          customerNotes: data.customerNotes,
          estimatedFare,
          offeredPrice,
          recipientName: data.recipientName?.trim() ?? null,
          recipientPhone: data.recipientPhone?.trim() ?? null,
          parcelSize: data.parcelSize ?? null,
          parcelNotes: data.parcelNotes ?? data.customerNotes ?? null,
          recipientOtp,
          channel: data.channel ?? 'app',
          distanceKm: fare.distanceKm,
          durationMin: fare.durationMin,
          promoCodeId: data.promoCodeId,
        },
        include: { serviceCategory: true, vehicle: true, payment: true },
      });
      await tx.jobStatusHistory.create({
        data: {
          jobId: created.id,
          toStatus: 'searching',
          changedByType: 'customer',
          changedById: customerId,
        },
      });
      return created;
    });

    try {
      await this.payments.recordPendingRidePayment({
        jobId: job.id,
        userId: customer.userId,
        method: data.paymentMethod,
        amount: estimatedFare,
        stripePaymentMethodId: data.stripePaymentMethodId,
      });
    } catch (err) {
      await this.prisma.job.delete({ where: { id: job.id } }).catch(() => undefined);
      throw err;
    }

    await this.matching.sendOffers(job.id).catch(() => undefined);
    return this.findOne(job.id);
  }

  async getLocationTrail(jobId: string) {
    await this.findOne(jobId);
    return this.prisma.jobLocationLog.findMany({
      where: { jobId },
      orderBy: { recordedAt: 'asc' },
    });
  }

  async assertCustomerOwnership(jobId: string, customerId: string) {
    const job = await this.findOne(jobId);
    if (job.customerId !== customerId) {
      throw new ForbiddenException('Job does not belong to this customer');
    }
    return job;
  }

  async setParcelPickupPhoto(jobId: string, providerId: string, fileUrl: string) {
    const job = await this.findOne(jobId);
    if (job.providerId !== providerId) throw new ForbiddenException('Job does not belong to this driver');
    if (job.jobType !== 'parcel') throw new BadRequestException('Not a parcel job');
    if (!['matched', 'provider_en_route', 'arrived'].includes(job.status)) {
      throw new BadRequestException('Pickup photo can be added after you are assigned');
    }
    const updated = await this.prisma.job.update({
      where: { id: jobId },
      data: { pickupPhotoUrl: fileUrl },
    });
    this.realtime.emitToJob(jobId, 'job:status', { jobId, status: job.status, pickupPhotoUrl: fileUrl });
    return updated;
  }

  async deliverParcel(
    jobId: string,
    providerId: string,
    data: { fileUrl?: string; otp?: string },
  ) {
    const job = await this.findOne(jobId);
    if (job.providerId !== providerId) throw new ForbiddenException('Job does not belong to this driver');
    if (job.jobType !== 'parcel') throw new BadRequestException('Not a parcel job');
    if (job.status !== 'in_progress' && job.status !== 'arrived') {
      throw new BadRequestException('Mark the parcel in progress before delivery');
    }
    if (await this.settings.isParcelOtpEnabled()) {
      if (!data.otp || data.otp.trim() !== (job.recipientOtp ?? '')) {
        throw new BadRequestException('Recipient OTP does not match');
      }
    }
    if (!data.fileUrl && !job.dropoffPhotoUrl) {
      throw new BadRequestException('Upload a proof-of-delivery photo');
    }
    return this.prisma.job.update({
      where: { id: jobId },
      data: { dropoffPhotoUrl: data.fileUrl ?? job.dropoffPhotoUrl },
    });
  }
}
