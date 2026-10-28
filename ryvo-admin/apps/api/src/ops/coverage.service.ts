import { Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { NotificationsService } from '../notifications/notifications.service';
import { ZoneAudience } from '@ryvo/database';
import { distanceKm } from './geo';

const OUT_OF_AREA_MESSAGE = 'RYVO is unavailable in the current area';

@Injectable()
export class CoverageService {
  constructor(
    private prisma: PrismaService,
    private notifications: NotificationsService,
  ) {}

  async listZones() {
    return this.prisma.serviceZone.findMany({ orderBy: { name: 'asc' } });
  }

  async upsertZone(input: {
    id?: string;
    name: string;
    audience: ZoneAudience;
    centerLat: number;
    centerLng: number;
    radiusKm: number;
    isActive?: boolean;
  }) {
    const data = {
      name: input.name,
      audience: input.audience,
      centerLat: input.centerLat,
      centerLng: input.centerLng,
      radiusKm: input.radiusKm,
      isActive: input.isActive ?? true,
    };
    const zone = input.id
      ? await this.prisma.serviceZone.update({ where: { id: input.id }, data })
      : await this.prisma.serviceZone.create({ data });
    await this.notifyInterestsInsideZones();
    return zone;
  }

  async check(lat: number, lng: number, audience: 'customer' | 'provider') {
    const zones = await this.prisma.serviceZone.findMany({ where: { isActive: true } });
    const relevant = zones.filter((z) => z.audience === 'both' || z.audience === audience);
    if (!relevant.length) {
      return { inside: true, configured: false, message: null as string | null };
    }
    const inside = relevant.some(
      (z) => distanceKm(lat, lng, Number(z.centerLat), Number(z.centerLng)) <= Number(z.radiusKm),
    );
    return {
      inside,
      configured: true,
      message: inside ? null : OUT_OF_AREA_MESSAGE,
    };
  }

  async notify(userId: string, audience: 'customer' | 'provider', lat: number, lng: number, addressLabel?: string) {
    return this.prisma.coverageInterest.create({
      data: { userId, audience, lat, lng, addressLabel },
    });
  }

  async listInterests() {
    return this.prisma.coverageInterest.findMany({
      orderBy: { createdAt: 'desc' },
      include: { user: { select: { id: true, fullName: true, phone: true, email: true, role: true } } },
    });
  }

  private async notifyInterestsInsideZones() {
    const [zones, interests] = await Promise.all([
      this.prisma.serviceZone.findMany({ where: { isActive: true } }),
      this.prisma.coverageInterest.findMany({ where: { notifiedAt: null } }),
    ]);
    for (const interest of interests) {
      const audience = interest.audience === 'both' ? 'customer' : interest.audience;
      const relevant = zones.filter((z) => z.audience === 'both' || z.audience === audience);
      const inside = relevant.some(
        (z) =>
          distanceKm(Number(interest.lat), Number(interest.lng), Number(z.centerLat), Number(z.centerLng)) <=
          Number(z.radiusKm),
      );
      if (!inside) continue;
      await this.prisma.coverageInterest.update({
        where: { id: interest.id },
        data: { notifiedAt: new Date() },
      });
      await this.notifications.notify({
        userId: interest.userId,
        type: 'coverage_available',
        title: 'RYVO is now available',
        body: 'RYVO coverage now includes your saved area.',
      });
    }
  }
}
