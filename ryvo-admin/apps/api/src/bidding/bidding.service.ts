import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { SettingsService } from '../settings/settings.service';
import { RealtimeService } from '../tracking/realtime.service';
import { NotificationsService } from '../notifications/notifications.service';
import { MatchingService } from '../matching/matching.service';

@Injectable()
export class BiddingService {
  constructor(
    private prisma: PrismaService,
    private settings: SettingsService,
    private realtime: RealtimeService,
    private notifications: NotificationsService,
    private matching: MatchingService,
  ) {}

  async listBids(jobId: string, customerId: string) {
    const job = await this.prisma.job.findUnique({ where: { id: jobId } });
    if (!job) throw new NotFoundException('Job not found');
    if (job.customerId !== customerId) throw new ForbiddenException('Job does not belong to this customer');
    if (job.jobType !== 'bidding') throw new BadRequestException('This trip is not a bidding request');
    return this.prisma.jobBid.findMany({
      where: { jobId, status: { in: ['pending', 'accepted'] } },
      orderBy: { createdAt: 'desc' },
      include: {
        provider: {
          include: {
            user: { select: { fullName: true, avatarUrl: true, phone: true } },
            vehicles: { take: 1 },
          },
        },
      },
    });
  }

  async submitBid(
    providerId: string,
    jobId: string,
    data: { amount: number; kind: 'accept' | 'counter'; message?: string },
  ) {
    const job = await this.prisma.job.findUnique({
      where: { id: jobId },
      include: { customer: { select: { userId: true } }, serviceCategory: { select: { name: true } } },
    });
    if (!job) throw new NotFoundException('Job not found');
    if (job.jobType !== 'bidding') throw new BadRequestException('This trip is not open for bids');
    if (job.status !== 'searching') throw new BadRequestException('Bidding is closed for this trip');
    if ((job.excludedProviderIds ?? []).includes(providerId)) {
      throw new BadRequestException('You cannot bid on this trip');
    }

    const provider = await this.prisma.provider.findUnique({
      where: { id: providerId },
      select: { verificationStatus: true, onlineStatus: true },
    });
    if (provider?.verificationStatus !== 'approved') {
      throw new BadRequestException('Only approved drivers can bid');
    }

    const countersEnabled = await this.settings.areBidCountersEnabled();
    if (data.kind === 'counter' && !countersEnabled) {
      throw new BadRequestException('Counter offers are disabled');
    }

    const suggested = Number(job.estimatedFare ?? job.offeredPrice ?? 0);
    const offered = Number(job.offeredPrice ?? suggested);
    let amount = data.kind === 'accept' ? offered : data.amount;
    if (!Number.isFinite(amount) || amount <= 0) {
      throw new BadRequestException('Enter a valid bid amount');
    }
    amount = Math.round(amount * 100) / 100;

    const minRatio = await this.settings.getBidMinFareRatio();
    const maxRatio = await this.settings.getBidMaxFareRatio();
    const floor = Math.round(suggested * minRatio * 100) / 100;
    const ceiling = Math.round(suggested * maxRatio * 100) / 100;
    if (amount < floor || amount > ceiling) {
      throw new BadRequestException(`Bid must be between ${floor} and ${ceiling}`);
    }

    const windowSec = await this.settings.getBidWindowSec();
    const expiresAt = new Date(Date.now() + windowSec * 1000);

    const bid = await this.prisma.jobBid.upsert({
      where: { jobId_providerId: { jobId, providerId } },
      update: {
        amount,
        kind: data.kind,
        status: 'pending',
        message: data.message ?? null,
        expiresAt,
      },
      create: {
        jobId,
        providerId,
        amount,
        kind: data.kind,
        status: 'pending',
        message: data.message ?? null,
        expiresAt,
      },
      include: {
        provider: {
          include: {
            user: { select: { fullName: true, avatarUrl: true } },
            vehicles: { take: 1 },
          },
        },
      },
    });

    const payload = {
      jobId,
      bid: {
        id: bid.id,
        amount: Number(bid.amount),
        kind: bid.kind,
        status: bid.status,
        message: bid.message,
        provider: {
          id: providerId,
          fullName: bid.provider.user.fullName,
          avatarUrl: bid.provider.user.avatarUrl,
          ratingAvg: bid.provider.ratingAvg,
          vehicle: bid.provider.vehicles[0] ?? null,
        },
      },
    };
    this.realtime.emitToJob(jobId, 'job:bid_received', payload);
    this.realtime.emitToUser(job.customer.userId, 'job:bid_received', payload);
    void this.notifications.notify({
      userId: job.customer.userId,
      type: 'job_bid',
      title: data.kind === 'accept' ? 'A driver accepted your price' : 'New counter offer',
      body: `${bid.provider.user.fullName ?? 'A driver'} offered ${amount} for ${job.serviceCategory.name}`,
      data: { jobId, bidId: bid.id },
    });

    return bid;
  }

  async acceptBid(customerId: string, jobId: string, bidId: string) {
    const job = await this.prisma.job.findUnique({ where: { id: jobId } });
    if (!job) throw new NotFoundException('Job not found');
    if (job.customerId !== customerId) throw new ForbiddenException('Job does not belong to this customer');
    if (job.jobType !== 'bidding') throw new BadRequestException('This trip is not a bidding request');
    if (job.status !== 'searching') throw new BadRequestException('Bidding is already closed');

    const bid = await this.prisma.jobBid.findUnique({ where: { id: bidId } });
    if (!bid || bid.jobId !== jobId) throw new NotFoundException('Bid not found');
    if (bid.status !== 'pending') throw new BadRequestException('Bid is no longer available');
    if (bid.expiresAt && bid.expiresAt < new Date()) {
      await this.prisma.jobBid.update({ where: { id: bidId }, data: { status: 'expired' } });
      throw new BadRequestException('Bid has expired');
    }

    const agreed = Number(bid.amount);
    const updated = await this.prisma.$transaction(async (tx) => {
      await tx.jobBid.update({ where: { id: bidId }, data: { status: 'accepted' } });
      await tx.jobBid.updateMany({
        where: { jobId, id: { not: bidId }, status: 'pending' },
        data: { status: 'rejected' },
      });
      const result = await tx.job.update({
        where: { id: jobId },
        data: {
          providerId: bid.providerId,
          status: 'matched',
          matchedAt: new Date(),
          estimatedFare: agreed,
          agreedFare: agreed,
        },
      });
      await tx.jobStatusHistory.create({
        data: {
          jobId,
          fromStatus: job.status,
          toStatus: 'matched',
          changedByType: 'customer',
          changedById: customerId,
          note: `Accepted bid ${bidId} at ${agreed}`,
        },
      });
      await tx.provider.update({
        where: { id: bid.providerId },
        data: { onlineStatus: 'busy' },
      });
      await tx.payment.updateMany({
        where: { jobId, status: { in: ['pending', 'held'] } },
        data: { amount: agreed },
      });
      return result;
    });

    await this.matching.announceMatchPublic(jobId, bid.providerId);
    return this.prisma.job.findUnique({
      where: { id: updated.id },
      include: {
        serviceCategory: true,
        provider: { include: { user: { select: { fullName: true, avatarUrl: true, phone: true } } } },
        bids: true,
      },
    });
  }

  async listOpenBidJobs(providerId: string) {
    const provider = await this.prisma.provider.findUnique({
      where: { id: providerId },
      select: { currentLat: true, currentLng: true },
    });
    if (provider?.currentLat == null || provider?.currentLng == null) return [];

    const nearby = await this.matching.findNearbyProviders(
      Number(provider.currentLat),
      Number(provider.currentLng),
    );
    if (!nearby.some((p) => p.id === providerId)) {
      // Still show jobs near this driver even if they are the only match.
    }

    const radiusKm = await this.settings.getMatchingRadiusKm();
    const jobs = await this.prisma.job.findMany({
      where: {
        jobType: 'bidding',
        status: 'searching',
        NOT: { excludedProviderIds: { has: providerId } },
      },
      include: {
        serviceCategory: { select: { id: true, name: true, slug: true, businessType: true } },
        customer: { include: { user: { select: { fullName: true } } } },
        bids: { where: { providerId } },
      },
      orderBy: { createdAt: 'desc' },
      take: 20,
    });

    const eligibleIds = await this.matching.providerIdsForRideClassPublic(
      jobs.map((j) => j.serviceCategoryId),
      providerId,
    );

    return jobs
      .filter((job) => eligibleIds.has(job.serviceCategoryId))
      .filter((job) => {
        const dlat = Number(job.pickupLat) - Number(provider.currentLat);
        const dlng = Number(job.pickupLng) - Number(provider.currentLng);
        const approxKm = Math.sqrt(dlat * dlat + dlng * dlng) * 111;
        return approxKm <= radiusKm * 2;
      })
      .map((job) => ({
        ...job,
        offeredPrice: job.offeredPrice ?? job.estimatedFare,
        myBid: job.bids[0] ?? null,
      }));
  }
}
