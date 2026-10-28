import {
  Injectable,
  NotFoundException,
  BadRequestException,
  Logger,
  OnModuleDestroy,
  OnModuleInit,
  Inject,
  forwardRef,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { RedisService } from '../redis/redis.service';
import { SettingsService } from '../settings/settings.service';
import { RealtimeService } from '../tracking/realtime.service';
import { NotificationsService } from '../notifications/notifications.service';
import { PaymentsService } from '../payments/payments.service';
import { CoverageService } from '../ops/coverage.service';
import { providerTravelToPickup } from '../ops/geo';
import { SmsService } from '../sms/sms.service';
import { JobOfferStatus } from '@ryvo/database';

const PROVIDER_GEO_KEY = 'provider:online';

const EXPIRE_OFFERS_INTERVAL_MS = 10_000;

@Injectable()
export class MatchingService implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(MatchingService.name);
  private expireTimer?: ReturnType<typeof setInterval>;

  constructor(
    private prisma: PrismaService,
    private redis: RedisService,
    private settings: SettingsService,
    private realtime: RealtimeService,
    private notifications: NotificationsService,
    @Inject(forwardRef(() => PaymentsService))
    private payments: PaymentsService,
    private coverage: CoverageService,
    private sms: SmsService,
  ) {}

  onModuleInit() {
    this.expireTimer = setInterval(() => {
      void this.expireOffers().catch((err) =>
        this.logger.error('expireOffers failed', err),
      );
    }, EXPIRE_OFFERS_INTERVAL_MS);
  }

  onModuleDestroy() {
    if (this.expireTimer) clearInterval(this.expireTimer);
  }

  async findNearbyProviders(lat: number, lng: number, radiusKm?: number) {
    const radius = radiusKm ?? (await this.settings.getMatchingRadiusKm());
    const client = this.redis.getClient();

    const results = await client.georadius(
      PROVIDER_GEO_KEY,
      lng,
      lat,
      radius,
      'km',
      'WITHDIST',
      'ASC',
    );

    const providerIds = results.map((r) => (Array.isArray(r) ? r[0] : r) as string);
    if (!providerIds.length) return [];

    const providers = await this.prisma.provider.findMany({
      where: {
        id: { in: providerIds },
        onlineStatus: 'online',
        verificationStatus: 'approved',
      },
      include: {
        user: { select: { fullName: true, avatarUrl: true } },
      },
    });

    const inside: typeof providers = [];
    for (const provider of providers) {
      if (provider.currentLat == null || provider.currentLng == null) continue;
      const area = await this.coverage.check(Number(provider.currentLat), Number(provider.currentLng), 'provider');
      if (area.inside) inside.push(provider);
    }

    const distMap = new Map<string, number>();
    for (const row of results) {
      if (Array.isArray(row) && row.length >= 2) {
        distMap.set(row[0] as string, Number(row[1]));
      }
    }

    return inside
      .map((p) => ({ ...p, distanceKm: distMap.get(p.id) ?? null }))
      .sort((a, b) => (a.distanceKm ?? 999) - (b.distanceKm ?? 999));
  }

  async sendOffers(jobId: string, providerIds?: string[]) {
    const job = await this.prisma.job.findUnique({ where: { id: jobId } });
    if (!job) throw new NotFoundException('Job not found');
    if (job.status !== 'searching') {
      throw new BadRequestException('Job is not in searching status');
    }
    if (job.jobType === 'bidding') {
      return this.sendBidRequests(jobId, providerIds);
    }

    const timeoutSec = await this.settings.getOfferTimeoutSec();
    const expiresAt = new Date(Date.now() + timeoutSec * 1000);

    let targets = providerIds;
    if (!targets?.length) {
      const nearby = await this.findNearbyProviders(
        Number(job.pickupLat),
        Number(job.pickupLng),
      );
      targets = nearby.slice(0, 8).map((p) => p.id);
    }

    const excluded = new Set(job.excludedProviderIds ?? []);
    const nearbyIds = targets.filter((id) => !excluded.has(id));
    targets = await this.providerIdsForRideClass(job.serviceCategoryId, nearbyIds);
    if (nearbyIds.length && !targets.length) {
      this.logger.warn(
        `Ride ${jobId} has ${nearbyIds.length} nearby driver(s) but none serve ${job.serviceCategoryId}`,
      );
    }

    if (!targets.length) {
      // No eligible provider right now. Give up only once the admin-configured
      // search window has elapsed; otherwise keep the job in `searching` and let
      // the periodic retry scan try again shortly (a provider may come online /
      // move in range). The window starts when searching begins (after payment),
      // not when the unpaid job row was created.
      const searchWindowMs = (await this.settings.getSearchTimeoutSec()) * 1000;
      const startedAt = await this.searchingSince(jobId, job.createdAt);
      if (Date.now() - startedAt.getTime() >= searchWindowMs) {
        await this.markNoProviderFound(jobId);
        return { offers: [], message: 'No drivers found nearby' };
      }
      return { offers: [], message: 'No drivers available yet, still searching' };
    }

    const offers = await this.prisma.$transaction(async (tx) => {
      const created = [];
      for (const providerId of targets!) {
        const existing = await tx.jobOffer.findFirst({
          where: { jobId, providerId },
        });
        if (existing) {
          created.push(
            await tx.jobOffer.update({
              where: { id: existing.id },
              data: { expiresAt, status: 'sent', respondedAt: null },
            }),
          );
        } else {
          created.push(
            await tx.jobOffer.create({
              data: { jobId, providerId, expiresAt, status: 'sent' },
            }),
          );
        }
      }
      return created;
    });

    await this.broadcastOffers(jobId, offers, expiresAt);

    return { offers, expiresAt };
  }

  /** Broadcast an open bid request to nearby drivers (not exclusive JobOffers). */
  async sendBidRequests(jobId: string, providerIds?: string[]) {
    const job = await this.prisma.job.findUnique({
      where: { id: jobId },
      include: {
        serviceCategory: { select: { name: true, slug: true } },
        customer: { include: { user: { select: { fullName: true } } } },
      },
    });
    if (!job) throw new NotFoundException('Job not found');
    if (job.status !== 'searching' || job.jobType !== 'bidding') {
      throw new BadRequestException('Job is not open for bidding');
    }

    let targets = providerIds;
    if (!targets?.length) {
      const nearby = await this.findNearbyProviders(Number(job.pickupLat), Number(job.pickupLng));
      targets = nearby.slice(0, 12).map((p) => p.id);
    }
    const excluded = new Set(job.excludedProviderIds ?? []);
    const nearbyIds = targets.filter((id) => !excluded.has(id));
    targets = await this.providerIdsForRideClass(job.serviceCategoryId, nearbyIds);

    const searchWindowMs = (await this.settings.getSearchTimeoutSec()) * 1000;
    const startedAt = await this.searchingSince(jobId, job.createdAt);
    const pendingBids = await this.prisma.jobBid.count({
      where: { jobId, status: 'pending' },
    });
    if (!targets.length && pendingBids === 0 && Date.now() - startedAt.getTime() >= searchWindowMs) {
      await this.markNoProviderFound(jobId);
      return { offers: [], message: 'No drivers found nearby' };
    }
    if (!targets.length) {
      return { offers: [], message: 'No drivers available yet, still searching' };
    }

    const windowSec = await this.settings.getBidWindowSec();
    const expiresAt = new Date(Date.now() + windowSec * 1000);
    const riderFirstName = (job.customer.user.fullName ?? 'Rider').trim().split(/\s+/)[0] || 'Rider';
    const offeredPrice = Number(job.offeredPrice ?? job.estimatedFare ?? 0);

    const providers = await this.prisma.provider.findMany({
      where: { id: { in: targets } },
      select: { id: true, userId: true, currentLat: true, currentLng: true },
    });

    for (const provider of providers) {
      const travel = providerTravelToPickup(
        provider.currentLat,
        provider.currentLng,
        job.pickupLat,
        job.pickupLng,
      );
      const payload = {
        offerId: `bid:${job.id}`,
        jobId: job.id,
        mode: 'bidding',
        expiresAt,
        job: {
          id: job.id,
          jobNumber: job.jobNumber,
          status: job.status,
          jobType: job.jobType,
          serviceCategory: job.serviceCategory,
          pickupAddress: job.pickupAddress,
          pickupLat: job.pickupLat,
          pickupLng: job.pickupLng,
          dropoffAddress: job.dropoffAddress,
          dropoffLat: job.dropoffLat,
          dropoffLng: job.dropoffLng,
          estimatedFare: job.estimatedFare,
          offeredPrice,
          distanceKm: job.distanceKm,
          tripDistanceKm: job.distanceKm,
          providerDistanceKm: travel?.providerDistanceKm ?? null,
          etaMinutes: travel?.etaMinutes ?? null,
          customerName: riderFirstName,
          riderFirstName,
        },
      };
      this.realtime.emitToProvider(provider.id, 'job:incoming', payload);
      if (provider.userId) {
        void this.notifications.notify({
          userId: provider.userId,
          type: 'job_bid_request',
          title: 'New bid request',
          body: `${riderFirstName} offered ${offeredPrice} · ${job.pickupAddress}`,
          data: { jobId: job.id },
        });
      }
    }

    return { offers: targets.map((id) => ({ providerId: id })), expiresAt };
  }

  async announceMatchPublic(jobId: string, providerId: string) {
    return this.announceMatch(jobId, providerId);
  }

  async providerIdsForRideClassPublic(categoryIds: string[], providerId: string) {
    const eligible = new Set<string>();
    for (const categoryId of [...new Set(categoryIds)]) {
      const ids = await this.providerIdsForRideClass(categoryId, [providerId]);
      if (ids.includes(providerId)) eligible.add(categoryId);
    }
    return eligible;
  }

  /** Push incoming-job offers to each targeted provider in real time + push. */
  private async broadcastOffers(
    jobId: string,
    offers: { id: string; providerId: string }[],
    expiresAt: Date,
  ) {
    const fullJob = await this.prisma.job.findUnique({
      where: { id: jobId },
      include: {
        serviceCategory: { select: { name: true, slug: true } },
        vehicle: {
          select: {
            vehicleType: true,
            make: true,
            model: true,
            year: true,
            plateNumber: true,
            transmission: true,
            fuelType: true,
            color: true,
            engineCapacity: true,
          },
        },
        customer: { include: { user: { select: { fullName: true } } } },
      },
    });
    if (!fullJob) return;

    const riderFirstName = (fullJob.customer.user.fullName ?? 'Rider').trim().split(/\s+/)[0] || 'Rider';

    const providers = await this.prisma.provider.findMany({
      where: { id: { in: offers.map((o) => o.providerId) } },
      select: { id: true, userId: true, currentLat: true, currentLng: true },
    });
    const providerById = new Map(providers.map((p) => [p.id, p]));

    for (const offer of offers) {
      const provider = providerById.get(offer.providerId);
      const travel = providerTravelToPickup(
        provider?.currentLat,
        provider?.currentLng,
        fullJob.pickupLat,
        fullJob.pickupLng,
      );
      const payload = {
        offerId: offer.id,
        jobId: fullJob.id,
        expiresAt,
        job: {
          id: fullJob.id,
          jobNumber: fullJob.jobNumber,
          status: fullJob.status,
          jobType: fullJob.jobType,
          recipientName: fullJob.recipientName,
          parcelSize: fullJob.parcelSize,
          serviceCategory: fullJob.serviceCategory,
          vehicle: fullJob.vehicle,
          pickupAddress: fullJob.pickupAddress,
          pickupLat: fullJob.pickupLat,
          pickupLng: fullJob.pickupLng,
          dropoffAddress: fullJob.dropoffAddress,
          dropoffLat: fullJob.dropoffLat,
          dropoffLng: fullJob.dropoffLng,
          estimatedFare: fullJob.estimatedFare,
          distanceKm: fullJob.distanceKm,
          tripDistanceKm: fullJob.distanceKm,
          providerDistanceKm: travel?.providerDistanceKm ?? null,
          etaMinutes: travel?.etaMinutes ?? null,
          customerName: riderFirstName,
          riderFirstName,
        },
      };
      this.realtime.emitToProvider(offer.providerId, 'job:incoming', payload);

      const userId = provider?.userId;
      if (userId) {
        void this.notifications.notify({
          userId,
          type: 'job_offer',
          title: 'New ride request',
          body: `${fullJob.serviceCategory.name} · ${riderFirstName} · ${fullJob.pickupAddress}`,
          data: { jobId: fullJob.id, offerId: offer.id },
        });
      }
    }
  }

  async acceptOffer(offerId: string, providerId: string) {
    const offer = await this.prisma.jobOffer.findUnique({
      where: { id: offerId },
      include: { job: true },
    });
    if (!offer) throw new NotFoundException('Offer not found');
    if (offer.providerId !== providerId) {
      throw new BadRequestException('Offer does not belong to this driver');
    }
    if (offer.status !== 'sent') {
      throw new BadRequestException('Offer is no longer available');
    }
    if (offer.expiresAt < new Date()) {
      await this.prisma.jobOffer.update({
        where: { id: offerId },
        data: { status: 'expired', respondedAt: new Date() },
      });
      throw new BadRequestException('Offer has expired');
    }

    const provider = await this.prisma.provider.findUnique({
      where: { id: providerId },
      select: { verificationStatus: true },
    });
    if (provider?.verificationStatus !== 'approved') {
      throw new BadRequestException('Only approved drivers can accept jobs');
    }

    const job = await this.prisma.$transaction(async (tx) => {
      await tx.jobOffer.update({
        where: { id: offerId },
        data: { status: 'accepted', respondedAt: new Date() },
      });
      await tx.jobOffer.updateMany({
        where: { jobId: offer.jobId, id: { not: offerId }, status: 'sent' },
        data: { status: 'rejected', respondedAt: new Date() },
      });
      const updated = await tx.job.update({
        where: { id: offer.jobId },
        data: { providerId, status: 'matched', matchedAt: new Date() },
      });
      await tx.jobStatusHistory.create({
        data: {
          jobId: offer.jobId,
          fromStatus: offer.job.status,
          toStatus: 'matched',
          changedByType: 'provider',
          changedById: providerId,
        },
      });
      await tx.provider.update({
        where: { id: providerId },
        data: { onlineStatus: 'busy' },
      });
      return updated;
    });

    await this.announceMatch(job.id, providerId);

    return job;
  }

  /** Notify the customer (realtime + push) that a provider accepted the job. */
  private async announceMatch(jobId: string, providerId: string) {
    const job = await this.prisma.job.findUnique({
      where: { id: jobId },
      include: {
        customer: { select: { userId: true } },
        provider: {
          include: {
            user: { select: { fullName: true, avatarUrl: true, phone: true } },
            vehicles: { take: 1 },
          },
        },
      },
    });
    if (!job) return;

    const statusPayload = {
      jobId,
      status: job.status,
      providerId,
      provider: job.provider
        ? {
            id: job.provider.id,
            fullName: job.provider.user.fullName,
            avatarUrl: job.provider.user.avatarUrl,
            phone: job.provider.user.phone,
            ratingAvg: job.provider.ratingAvg,
            currentLat: job.provider.currentLat,
            currentLng: job.provider.currentLng,
            vehicle: job.provider.vehicles[0] ?? null,
          }
        : null,
    };
    this.realtime.emitToJob(jobId, 'job:status', statusPayload);
    this.realtime.emitToJob(jobId, 'job:provider_assigned', statusPayload);
    if (job.provider?.currentLat != null && job.provider?.currentLng != null) {
      this.realtime.emitToJob(jobId, 'job:location', {
        providerId,
        lat: Number(job.provider.currentLat),
        lng: Number(job.provider.currentLng),
        jobId,
      });
    }

    void this.notifications.notify({
      userId: job.customer.userId,
      type: 'provider_assigned',
      title: 'Driver on the way',
      body: `${job.provider?.user.fullName ?? 'A driver'} accepted your ride`,
      data: { jobId, status: 'matched' },
    });
    await this.notifyWhatsApp(
      jobId,
      `${job.provider?.user.fullName ?? 'A driver'} accepted your booking and is on the way.`,
    );
  }

  async rejectOffer(offerId: string, providerId: string) {
    const offer = await this.prisma.jobOffer.findUnique({ where: { id: offerId } });
    if (!offer) throw new NotFoundException('Offer not found');
    if (offer.providerId !== providerId) {
      throw new BadRequestException('Offer does not belong to this driver');
    }
    if (offer.status !== 'sent') {
      throw new BadRequestException('Offer is no longer available');
    }

    return this.prisma.jobOffer.update({
      where: { id: offerId },
      data: { status: 'rejected', respondedAt: new Date() },
    });
  }

  async expireOffers() {
    const now = new Date();
    const expired = await this.prisma.jobOffer.findMany({
      where: { status: 'sent', expiresAt: { lt: now } },
      select: { id: true },
    });

    if (expired.length) {
      await this.prisma.jobOffer.updateMany({
        where: { id: { in: expired.map((o) => o.id) } },
        data: { status: 'expired' as JobOfferStatus, respondedAt: now },
      });
    }

    await this.prisma.jobBid.updateMany({
      where: { status: 'pending', expiresAt: { lt: now } },
      data: { status: 'expired' },
    });

    // Keep searching jobs moving: re-dispatch while within the search window and
    // only give up once it has elapsed. This also covers jobs that never got a
    // single offer (no provider online at dispatch time), which the old
    // expired-offer-only loop silently ignored.
    await this.retrySearchingJobs();

    return { expired: expired.length };
  }

  /**
   * Re-dispatch (or time out) every job still in `searching` that has no
   * outstanding offer. Runs on the EXPIRE_OFFERS timer so a customer who just
   * paid keeps waiting for the full admin-configured search window instead of
   * being dropped the instant no provider is available.
   */
  private async retrySearchingJobs() {
    const jobs = await this.prisma.job.findMany({
      where: { status: 'searching' },
      select: { id: true, createdAt: true, jobType: true },
    });
    if (!jobs.length) return;

    const searchWindowMs = (await this.settings.getSearchTimeoutSec()) * 1000;

    for (const job of jobs) {
      if (job.jobType === 'bidding') {
        const pendingBids = await this.prisma.jobBid.count({
          where: { jobId: job.id, status: 'pending' },
        });
        const startedAt = await this.searchingSince(job.id, job.createdAt);
        if (pendingBids === 0 && Date.now() - startedAt.getTime() >= searchWindowMs) {
          await this.markNoProviderFound(job.id);
          continue;
        }
        try {
          await this.sendBidRequests(job.id);
        } catch (err) {
          this.logger.warn(`Retry sendBidRequests failed for job ${job.id}`, err);
        }
        continue;
      }

      const pending = await this.prisma.jobOffer.count({
        where: { jobId: job.id, status: 'sent' },
      });
      if (pending > 0) continue;

      const startedAt = await this.searchingSince(job.id, job.createdAt);
      if (Date.now() - startedAt.getTime() >= searchWindowMs) {
        await this.markNoProviderFound(job.id);
        continue;
      }

      // Still within the window — try nearby providers again.
      try {
        await this.sendOffers(job.id);
      } catch (err) {
        this.logger.warn(`Retry sendOffers failed for job ${job.id}`, err);
      }
    }
  }

  /** Drivers whose approved vehicle is allowed to serve this ride class. */
  private async providerIdsForRideClass(serviceCategoryId: string, providerIds: string[]) {
    if (!providerIds.length) return [];
    const category = await this.prisma.serviceCategory.findUnique({
      where: { id: serviceCategoryId },
      select: { id: true, slug: true },
    });
    if (!category) return [];

    const vehicles = await this.prisma.providerVehicle.findMany({
      where: { providerId: { in: providerIds } },
      select: { providerId: true, serviceCapabilities: true },
    });
    const eligible = new Set<string>();
    for (const vehicle of vehicles) {
      const caps = Array.isArray(vehicle.serviceCapabilities)
        ? vehicle.serviceCapabilities.map((value) => String(value))
        : [];
      if (caps.includes(category.id) || caps.includes(category.slug)) {
        eligible.add(vehicle.providerId);
      }
    }
    return providerIds.filter((id) => eligible.has(id));
  }

  /** When the job actually entered `searching`, not an older unpaid row. */
  private async searchingSince(jobId: string, createdAt: Date) {
    const entered = await this.prisma.jobStatusHistory.findFirst({
      where: { jobId, toStatus: 'searching' },
      orderBy: { createdAt: 'desc' },
      select: { createdAt: true },
    });
    return entered?.createdAt ?? createdAt;
  }

  private async markNoProviderFound(jobId: string) {
    const job = await this.prisma.job.findUnique({
      where: { id: jobId },
      select: { status: true, customer: { select: { userId: true } } },
    });
    if (!job || job.status !== 'searching') return;

    await this.prisma.$transaction(async (tx) => {
      await tx.job.update({
        where: { id: jobId },
        data: { status: 'no_provider_found' },
      });
      await tx.jobStatusHistory.create({
        data: {
          jobId,
          fromStatus: job.status,
          toStatus: 'no_provider_found',
          changedByType: 'system',
          note: 'No drivers found nearby',
        },
      });
    });

    const payload = { jobId, status: 'no_provider_found' };
    this.realtime.emitToJob(jobId, 'job:status', payload);
    this.realtime.emitToUser(job.customer.userId, 'job:status', payload);

    await this.payments.releaseHoldForJob(jobId).catch((err) => {
      this.logger.warn(`Failed to release hold for job ${jobId}`, err);
    });
    await this.notifyWhatsApp(jobId, 'No drivers were available. You can send a new booking anytime.');
  }

  private async notifyWhatsApp(jobId: string, text: string) {
    const session = await this.prisma.whatsAppSession.findFirst({ where: { lastJobId: jobId } });
    if (!session) return;
    await this.sms.sendWhatsApp(session.phone, text);
  }
}
