import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { randomBytes } from 'crypto';
import { PrismaService } from '../prisma/prisma.service';
import { SettingsService } from '../settings/settings.service';
import { PLATFORM_SETTINGS_KEYS } from '@ryvo/shared';
import { RealtimeService } from './realtime.service';
import { isLiveShareStatus, isTerminalShareStatus } from './trip-share.status';

function firstName(fullName: string | null | undefined, fallback: string) {
  const part = (fullName ?? '').trim().split(/\s+/)[0];
  return part || fallback;
}

function asNumber(value: unknown): number | null {
  if (value == null) return null;
  const n = Number(value);
  return Number.isFinite(n) ? n : null;
}

export type PublicTripSnapshot =
  | { active: false; state: 'ended' }
  | {
      active: true;
      state: 'live' | 'waiting';
      status: string;
      riderFirstName: string;
      pickup: { address: string; lat: number; lng: number };
      dropoff: { address: string; lat: number; lng: number } | null;
      driver: {
        firstName: string;
        rating: number | null;
        lat: number | null;
        lng: number | null;
        vehicle: {
          make: string;
          model: string;
          color: string | null;
          plate: string;
        } | null;
      } | null;
      mapApiKey: string | null;
    };

@Injectable()
export class TripShareService {
  private mapKeyCache: { value: string | null; at: number } | null = null;

  constructor(
    private prisma: PrismaService,
    private config: ConfigService,
    private settings: SettingsService,
    private realtime: RealtimeService,
  ) {}

  async create(customerId: string, jobId: string) {
    const job = await this.prisma.job.findUnique({
      where: { id: jobId },
      select: { id: true, customerId: true, status: true },
    });
    if (!job) throw new NotFoundException('Job not found');
    if (job.customerId !== customerId) {
      throw new ForbiddenException('Job does not belong to this customer');
    }
    if (!isLiveShareStatus(job.status)) {
      throw new BadRequestException('You can share a trip after a driver is assigned');
    }

    const existing = await this.prisma.tripShare.findUnique({ where: { jobId } });
    if (existing && !existing.revokedAt) {
      return { url: this.publicUrl(existing.token), active: true, reused: true };
    }

    const token = randomBytes(32).toString('base64url');
    const share = existing
      ? await this.prisma.tripShare.update({
          where: { id: existing.id },
          data: { token, revokedAt: null },
        })
      : await this.prisma.tripShare.create({
          data: { jobId, token },
        });

    return { url: this.publicUrl(share.token), active: true, reused: false };
  }

  async revoke(customerId: string, jobId: string) {
    const job = await this.prisma.job.findUnique({
      where: { id: jobId },
      select: { customerId: true },
    });
    if (!job) throw new NotFoundException('Job not found');
    if (job.customerId !== customerId) {
      throw new ForbiddenException('Job does not belong to this customer');
    }

    const share = await this.prisma.tripShare.findUnique({ where: { jobId } });
    if (!share || share.revokedAt) return { active: false };

    await this.prisma.tripShare.update({
      where: { id: share.id },
      data: { revokedAt: new Date() },
    });
    this.realtime.emitToShare(share.id, 'job:status', { status: 'ended', ended: true });
    return { active: false };
  }

  async publicSnapshot(token: string): Promise<PublicTripSnapshot> {
    const share = await this.findByToken(token);
    if (!share) throw new NotFoundException('Trip link not found');
    if (share.revokedAt) return { active: false, state: 'ended' };

    const status = share.job.status;
    if (isTerminalShareStatus(status)) {
      await this.prisma.tripShare.update({
        where: { id: share.id },
        data: { revokedAt: new Date() },
      });
      this.realtime.emitToShare(share.id, 'job:status', { status: 'ended', ended: true });
      return { active: false, state: 'ended' };
    }

    const live = isLiveShareStatus(status);
    const provider = share.job.provider;
    const vehicle = provider?.vehicles[0] ?? null;
    const lat = live ? asNumber(provider?.currentLat) : null;
    const lng = live ? asNumber(provider?.currentLng) : null;
    const dropoffLat = asNumber(share.job.dropoffLat);
    const dropoffLng = asNumber(share.job.dropoffLng);

    return {
      active: true,
      state: live ? 'live' : 'waiting',
      status,
      riderFirstName: firstName(share.job.customer.user.fullName, 'Rider'),
      pickup: {
        address: share.job.pickupAddress,
        lat: Number(share.job.pickupLat),
        lng: Number(share.job.pickupLng),
      },
      dropoff:
        share.job.dropoffAddress && dropoffLat != null && dropoffLng != null
          ? { address: share.job.dropoffAddress, lat: dropoffLat, lng: dropoffLng }
          : null,
      driver: live && provider
        ? {
            firstName: firstName(provider.user.fullName, 'Driver'),
            rating: asNumber(provider.ratingAvg),
            lat,
            lng,
            vehicle: vehicle
              ? {
                  make: vehicle.make,
                  model: vehicle.model,
                  color: vehicle.color,
                  plate: vehicle.plateNumber,
                }
              : null,
          }
        : null,
      mapApiKey: await this.browserMapKey(),
    };
  }

  /** Join payload for a family viewer. Never includes the job id or phone numbers. */
  async resolveSubscribe(token: string) {
    const share = await this.findByToken(token);
    if (!share || share.revokedAt) return { ok: false as const };

    if (isTerminalShareStatus(share.job.status)) {
      await this.prisma.tripShare.update({
        where: { id: share.id },
        data: { revokedAt: new Date() },
      });
      return { ok: false as const };
    }

    const live = isLiveShareStatus(share.job.status);
    return {
      ok: true as const,
      shareId: share.id,
      status: share.job.status,
      ended: false,
      lat: live ? asNumber(share.job.provider?.currentLat) : null,
      lng: live ? asNumber(share.job.provider?.currentLng) : null,
    };
  }

  private findByToken(token: string) {
    const trimmed = token.trim();
    if (trimmed.length < 20 || trimmed.length > 128) return Promise.resolve(null);
    return this.prisma.tripShare.findUnique({
      where: { token: trimmed },
      include: {
        job: {
          select: {
            status: true,
            pickupAddress: true,
            pickupLat: true,
            pickupLng: true,
            dropoffAddress: true,
            dropoffLat: true,
            dropoffLng: true,
            customer: { select: { user: { select: { fullName: true } } } },
            provider: {
              select: {
                currentLat: true,
                currentLng: true,
                ratingAvg: true,
                user: { select: { fullName: true } },
                vehicles: {
                  take: 1,
                  orderBy: { createdAt: 'asc' },
                  select: { make: true, model: true, color: true, plateNumber: true },
                },
              },
            },
          },
        },
      },
    });
  }

  private publicUrl(token: string) {
    const base = (
      this.config.get<string>('PUBLIC_WEB_URL') ?? 'https://ryvo.arcadexit.com'
    ).replace(/\/$/, '');
    return `${base}/track/${token}`;
  }

  private async browserMapKey() {
    const now = Date.now();
    if (this.mapKeyCache && now - this.mapKeyCache.at < 60_000) {
      return this.mapKeyCache.value;
    }
    const stored = await this.settings.get(PLATFORM_SETTINGS_KEYS.MAP_API_KEY);
    const fromSettings = typeof stored === 'string' && stored.trim() ? stored.trim() : '';
    const fromEnv = this.config.get<string>('GOOGLE_MAPS_API_KEY')?.trim() ?? '';
    const value = fromSettings || fromEnv || null;
    this.mapKeyCache = { value, at: now };
    return value;
  }
}
