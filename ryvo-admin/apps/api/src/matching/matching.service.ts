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
import {
  CHAIN_MAX_REMAINING_MIN,
  CHAIN_PICKUP_RADIUS_KM,
  CHAIN_STALE_REMAINING_MIN,
  distanceKm,
  etaMinutesFromKm,
  providerTravelToPickup,
} from '../ops/geo';
import { SmsService } from '../sms/sms.service';
import { JobOfferStatus } from '@ryvo/database';

const PROVIDER_GEO_KEY = 'provider:online';

const EXPIRE_OFFERS_INTERVAL_MS = 10_000;

const OPEN_JOB_STATUSES = [
  'matched',
  'provider_en_route',
  'arrived',
  'in_progress',
  'payment_pending',
] as const;

export type OfferTravel = {
  providerDistanceKm: number;
  etaMinutes: number;
  chained: boolean;
};

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
    if (!providerIds?.length) {
      targets = await this.preferFinishingDriver(job, targets, excluded);
    }
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
      const travel = await this.offerTravel(
        offer.providerId,
        fullJob.pickupLat,
        fullJob.pickupLng,
        provider?.currentLat,
        provider?.currentLng,
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
          chained: travel?.chained ?? false,
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
          title: travel?.chained ? 'Next trip after dropoff' : 'New ride request',
          body: travel?.chained
            ? `After this dropoff · ${riderFirstName} · ${fullJob.pickupAddress}`
            : `${fullJob.serviceCategory.name} · ${riderFirstName} · ${fullJob.pickupAddress}`,
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

    const openJobs = await this.prisma.job.findMany({
      where: { providerId, status: { in: [...OPEN_JOB_STATUSES] } },
      select: { status: true },
    });
    const onTrip = openJobs.filter((row) => row.status === 'in_progress');
    const otherOpen = openJobs.filter((row) => row.status !== 'in_progress');
    if (otherOpen.length > 0) {
      throw new BadRequestException('Finish or decline your other request before taking another trip');
    }
    if (onTrip.length > 1) {
      throw new BadRequestException('Finish your current trip first');
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

    const pickupEtaMinutes = await this.pickupEtaMinutesForJob(job);
    const statusPayload = {
      jobId,
      status: job.status,
      providerId,
      ...(pickupEtaMinutes != null ? { pickupEtaMinutes } : {}),
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

    const finishingNearby = pickupEtaMinutes != null;
    void this.notifications.notify({
      userId: job.customer.userId,
      type: 'provider_assigned',
      title: finishingNearby ? 'Driver finishing a nearby trip' : 'Driver on the way',
      body: finishingNearby
        ? `${job.provider?.user.fullName ?? 'Your driver'} will head to you after a nearby dropoff · about ${pickupEtaMinutes} min`
        : `${job.provider?.user.fullName ?? 'A driver'} accepted your ride`,
      data: { jobId, status: 'matched' },
    });
    await this.notifyWhatsApp(
      jobId,
      finishingNearby
        ? `${job.provider?.user.fullName ?? 'A driver'} accepted your booking and will reach you in about ${pickupEtaMinutes} min, after a nearby dropoff.`
        : `${job.provider?.user.fullName ?? 'A driver'} accepted your booking and is on the way.`,
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
    await this.releaseStaleChains();

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

  /**
   * Uber-style chain: a driver in the last few minutes of a trip is matched
   * from the dropoff, and only when that arrival beats every free driver.
   */
  private async preferFinishingDriver(
    job: { serviceCategoryId: string; pickupLat: unknown; pickupLng: unknown },
    idleIds: string[],
    excluded: Set<string>,
  ) {
    const finishing = await this.findFinishingDrivers(
      Number(job.pickupLat),
      Number(job.pickupLng),
      job.serviceCategoryId,
      excluded,
    );
    const bestFinish = finishing[0];
    if (!bestFinish) return idleIds;

    const bestIdle = await this.bestIdleEta(idleIds, job.pickupLat, job.pickupLng);
    if (bestIdle != null && bestFinish.etaMinutes >= bestIdle) return idleIds;
    return [bestFinish.providerId];
  }

  private async bestIdleEta(providerIds: string[], pickupLat: unknown, pickupLng: unknown) {
    if (!providerIds.length) return null;
    const providers = await this.prisma.provider.findMany({
      where: { id: { in: providerIds } },
      select: { currentLat: true, currentLng: true },
    });
    let best: number | null = null;
    for (const provider of providers) {
      const travel = providerTravelToPickup(
        provider.currentLat,
        provider.currentLng,
        pickupLat,
        pickupLng,
      );
      if (!travel) continue;
      if (best == null || travel.etaMinutes < best) best = travel.etaMinutes;
    }
    return best;
  }

  private async findFinishingDrivers(
    pickupLat: number,
    pickupLng: number,
    serviceCategoryId: string,
    excluded: Set<string>,
  ) {
    const trips = await this.prisma.job.findMany({
      where: {
        status: 'in_progress',
        dropoffLat: { not: null },
        dropoffLng: { not: null },
        provider: { onlineStatus: 'busy', verificationStatus: 'approved' },
      },
      select: {
        providerId: true,
        dropoffLat: true,
        dropoffLng: true,
        provider: { select: { id: true, currentLat: true, currentLng: true } },
      },
    });
    if (!trips.length) return [];

    const providerIds = trips
      .map((trip) => trip.providerId)
      .filter((id): id is string => !!id && !excluded.has(id));
    if (!providerIds.length) return [];

    const alreadyQueued = await this.prisma.job.findMany({
      where: {
        providerId: { in: providerIds },
        status: { in: ['matched', 'provider_en_route', 'arrived', 'payment_pending'] },
      },
      select: { providerId: true },
    });
    const queued = new Set(alreadyQueued.map((row) => row.providerId));
    const eligible = await this.providerIdsForRideClass(
      serviceCategoryId,
      providerIds.filter((id) => !queued.has(id)),
    );
    const eligibleSet = new Set(eligible);

    const ranked: { providerId: string; etaMinutes: number }[] = [];
    for (const trip of trips) {
      const providerId = trip.providerId;
      const provider = trip.provider;
      if (!providerId || !provider || !eligibleSet.has(providerId)) continue;
      if (provider.currentLat == null || provider.currentLng == null) continue;
      if (trip.dropoffLat == null || trip.dropoffLng == null) continue;

      const area = await this.coverage.check(
        Number(provider.currentLat),
        Number(provider.currentLng),
        'provider',
      );
      if (!area.inside) continue;

      const remainingMin = etaMinutesFromKm(
        distanceKm(
          Number(provider.currentLat),
          Number(provider.currentLng),
          Number(trip.dropoffLat),
          Number(trip.dropoffLng),
        ),
      );
      if (remainingMin > CHAIN_MAX_REMAINING_MIN) continue;

      const hopKm = distanceKm(
        Number(trip.dropoffLat),
        Number(trip.dropoffLng),
        pickupLat,
        pickupLng,
      );
      if (hopKm > CHAIN_PICKUP_RADIUS_KM) continue;

      ranked.push({
        providerId,
        etaMinutes: remainingMin + etaMinutesFromKm(hopKm),
      });
    }

    return ranked.sort((a, b) => a.etaMinutes - b.etaMinutes);
  }

  /** Arrival time for an offer. Chained drivers are scored from the current dropoff. */
  async offerTravel(
    providerId: string,
    pickupLat: unknown,
    pickupLng: unknown,
    currentLat?: unknown,
    currentLng?: unknown,
  ): Promise<OfferTravel | null> {
    const chained = await this.chainTravel(providerId, pickupLat, pickupLng);
    if (chained) return chained;

    let lat = currentLat;
    let lng = currentLng;
    if (lat == null || lng == null) {
      const provider = await this.prisma.provider.findUnique({
        where: { id: providerId },
        select: { currentLat: true, currentLng: true },
      });
      lat = provider?.currentLat;
      lng = provider?.currentLng;
    }
    const travel = providerTravelToPickup(lat, lng, pickupLat, pickupLng);
    if (!travel) return null;
    return { ...travel, chained: false };
  }

  /** Minutes until this driver can reach a pickup, including a trip they are still finishing. */
  async pickupEtaMinutesForJob(job: {
    id: string;
    providerId: string | null;
    pickupLat: unknown;
    pickupLng: unknown;
  }) {
    if (!job.providerId) return null;
    const travel = await this.chainTravel(job.providerId, job.pickupLat, job.pickupLng, job.id);
    return travel?.etaMinutes ?? null;
  }

  private async chainTravel(
    providerId: string,
    pickupLat: unknown,
    pickupLng: unknown,
    exceptJobId?: string,
  ): Promise<OfferTravel | null> {
    const current = await this.prisma.job.findFirst({
      where: {
        providerId,
        status: 'in_progress',
        ...(exceptJobId ? { id: { not: exceptJobId } } : {}),
        dropoffLat: { not: null },
        dropoffLng: { not: null },
      },
      select: {
        dropoffLat: true,
        dropoffLng: true,
        provider: { select: { currentLat: true, currentLng: true } },
      },
    });
    if (!current?.dropoffLat || !current.dropoffLng || !current.provider) return null;
    if (current.provider.currentLat == null || current.provider.currentLng == null) return null;

    const remainingMin = etaMinutesFromKm(
      distanceKm(
        Number(current.provider.currentLat),
        Number(current.provider.currentLng),
        Number(current.dropoffLat),
        Number(current.dropoffLng),
      ),
    );
    const hopKm = distanceKm(
      Number(current.dropoffLat),
      Number(current.dropoffLng),
      Number(pickupLat),
      Number(pickupLng),
    );
    return {
      providerDistanceKm: Math.round(hopKm * 10) / 10,
      etaMinutes: remainingMin + etaMinutesFromKm(hopKm),
      chained: true,
    };
  }

  /**
   * After the current trip closes, keep a queued next trip only when the driver
   * actually finished at the dropoff. A cancel means they will not be there.
   */
  async reconcileProviderAfterJobClosed(
    providerId: string,
    closedJobId: string,
    mode: 'complete' | 'cancel',
  ) {
    const open = await this.prisma.job.findMany({
      where: {
        providerId,
        id: { not: closedJobId },
        status: { in: [...OPEN_JOB_STATUSES] },
      },
      select: {
        id: true,
        status: true,
        customer: { select: { userId: true } },
      },
    });
    const stillOnTrip = open.some(
      (row) =>
        row.status === 'in_progress' ||
        row.status === 'arrived' ||
        row.status === 'provider_en_route',
    );

    if (mode === 'complete' || stillOnTrip) {
      await this.prisma.provider.update({
        where: { id: providerId },
        data: { onlineStatus: open.length ? 'busy' : 'online' },
      });
      return;
    }

    const queued = open.filter(
      (row) => row.status === 'matched' || row.status === 'payment_pending',
    );
    for (const job of queued) {
      await this.releaseQueuedJob(
        job,
        'The current trip was cancelled before dropoff, so this next trip is searching again.',
      );
    }
    await this.prisma.provider.update({
      where: { id: providerId },
      data: { onlineStatus: 'online' },
    });
  }

  /** Send a queued trip back to search when the dropoff it was matched from is no longer valid. */
  private async releaseStaleChains() {
    const queued = await this.prisma.job.findMany({
      where: { status: 'matched', providerId: { not: null } },
      select: {
        id: true,
        status: true,
        providerId: true,
        pickupLat: true,
        pickupLng: true,
        customer: { select: { userId: true } },
      },
    });
    for (const job of queued) {
      if (!job.providerId) continue;
      const current = await this.prisma.job.findFirst({
        where: {
          providerId: job.providerId,
          id: { not: job.id },
          status: 'in_progress',
          dropoffLat: { not: null },
          dropoffLng: { not: null },
        },
        select: {
          dropoffLat: true,
          dropoffLng: true,
          provider: { select: { currentLat: true, currentLng: true } },
        },
      });
      if (!current?.dropoffLat || !current.dropoffLng) continue;

      const hopKm = distanceKm(
        Number(current.dropoffLat),
        Number(current.dropoffLng),
        Number(job.pickupLat),
        Number(job.pickupLng),
      );
      const remainingMin =
        current.provider?.currentLat != null && current.provider.currentLng != null
          ? etaMinutesFromKm(
              distanceKm(
                Number(current.provider.currentLat),
                Number(current.provider.currentLng),
                Number(current.dropoffLat),
                Number(current.dropoffLng),
              ),
            )
          : CHAIN_STALE_REMAINING_MIN + 1;
      if (hopKm <= CHAIN_PICKUP_RADIUS_KM && remainingMin <= CHAIN_STALE_REMAINING_MIN) continue;

      await this.releaseQueuedJob(
        job,
        'The current dropoff moved, so this next trip is searching again.',
      );
      await this.prisma.provider.update({
        where: { id: job.providerId },
        data: { onlineStatus: 'busy' },
      });
    }
  }

  private async releaseQueuedJob(
    job: { id: string; status: string; customer?: { userId: string } | null },
    note: string,
  ) {
    const current = await this.prisma.job.findUnique({
      where: { id: job.id },
      select: { status: true },
    });
    if (!current || (current.status !== 'matched' && current.status !== 'payment_pending')) return;

    await this.prisma.$transaction(async (tx) => {
      await tx.job.update({
        where: { id: job.id },
        data: { status: 'searching', providerId: null, matchedAt: null },
      });
      await tx.jobStatusHistory.create({
        data: {
          jobId: job.id,
          fromStatus: current.status,
          toStatus: 'searching',
          changedByType: 'system',
          note,
        },
      });
    });

    const payload = {
      jobId: job.id,
      status: 'searching',
      providerId: null,
      message: 'Looking for another driver.',
    };
    this.realtime.emitToJob(job.id, 'job:status', payload);
    if (job.customer?.userId) {
      this.realtime.emitToUser(job.customer.userId, 'job:status', payload);
    }
    await this.sendOffers(job.id).catch((err) => {
      this.logger.warn(`Re-dispatch after chain release failed for job ${job.id}`, err);
    });
  }

  private async notifyWhatsApp(jobId: string, text: string) {
    const session = await this.prisma.whatsAppSession.findFirst({ where: { lastJobId: jobId } });
    if (!session) return;
    await this.sms.sendWhatsApp(session.phone, text);
  }
}
