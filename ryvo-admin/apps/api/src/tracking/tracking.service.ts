import { Injectable, Logger, OnModuleDestroy, OnModuleInit } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { RedisService } from '../redis/redis.service';

const PROVIDER_GEO_KEY = 'provider:online';
const PERSIST_INTERVAL_MS = 15000;

interface PendingLocation {
  jobId: string;
  providerId: string;
  lat: number;
  lng: number;
  heading?: number;
  speed?: number;
  updatedAt: Date;
}

@Injectable()
export class TrackingService implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(TrackingService.name);
  private pending = new Map<string, PendingLocation>();
  private persistTimer?: ReturnType<typeof setInterval>;

  constructor(
    private prisma: PrismaService,
    private redis: RedisService,
  ) {}

  onModuleInit() {
    this.persistTimer = setInterval(() => {
      void this.flushPendingLocations();
    }, PERSIST_INTERVAL_MS);
  }

  onModuleDestroy() {
    if (this.persistTimer) clearInterval(this.persistTimer);
  }

  async updateProviderLocation(
    providerId: string,
    lat: number,
    lng: number,
    jobId?: string,
    heading?: number,
    speed?: number,
  ) {
    const existing = await this.prisma.provider.findUnique({
      where: { id: providerId },
      select: { verificationStatus: true, onlineStatus: true },
    });

    await this.prisma.provider.update({
      where: { id: providerId },
      data: {
        currentLat: lat,
        currentLng: lng,
        lastLocationAt: new Date(),
      },
    });

    const canIndex =
      existing?.verificationStatus === 'approved' &&
      (existing.onlineStatus === 'online' || existing.onlineStatus === 'busy');
    if (canIndex) {
      await this.redis.getClient().geoadd(PROVIDER_GEO_KEY, lng, lat, providerId);
    } else {
      await this.redis.getClient().zrem(PROVIDER_GEO_KEY, providerId);
    }

    if (jobId) {
      const key = `${jobId}:${providerId}`;
      this.pending.set(key, {
        jobId,
        providerId,
        lat,
        lng,
        heading,
        speed,
        updatedAt: new Date(),
      });
    }

    return { providerId, lat, lng, jobId, heading, speed };
  }

  async getLiveProviders() {
    const providers = await this.prisma.provider.findMany({
      where: { onlineStatus: { in: ['online', 'busy'] } },
      select: {
        id: true,
        onlineStatus: true,
        currentLat: true,
        currentLng: true,
        lastLocationAt: true,
        user: { select: { fullName: true } },
        jobs: {
          where: { status: { in: ['matched', 'provider_en_route', 'arrived', 'in_progress'] } },
          take: 1,
          select: { id: true, jobNumber: true, status: true },
        },
      },
    });
    return providers;
  }

  async getJobLatestLocation(jobId: string) {
    return this.prisma.jobLocationLog.findFirst({
      where: { jobId },
      orderBy: { recordedAt: 'desc' },
    });
  }

  private async flushPendingLocations() {
    if (!this.pending.size) return;

    const batch = Array.from(this.pending.values());
    this.pending.clear();

    try {
      await this.prisma.jobLocationLog.createMany({
        data: batch.map((loc) => ({
          jobId: loc.jobId,
          providerId: loc.providerId,
          lat: loc.lat,
          lng: loc.lng,
          heading: loc.heading,
          speed: loc.speed,
          recordedAt: loc.updatedAt,
        })),
      });
    } catch (err) {
      this.logger.error('Failed to persist location logs', err);
    }
  }
}
