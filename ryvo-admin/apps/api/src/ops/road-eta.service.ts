import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { PLATFORM_SETTINGS_KEYS } from '@ryvo/shared';
import { SettingsService } from '../settings/settings.service';

export type DriveLeg = {
  key: string;
  originLat: number;
  originLng: number;
  destLat: number;
  destLng: number;
};

export type DriveMeasure = {
  etaMinutes: number;
  distanceKm: number;
};

const ROAD_TIMEOUT_MS = 4_000;

/**
 * Driving time for a handful of origin/destination pairs.
 * Google Distance Matrix when a key is configured, then the public OSRM
 * table, then nothing — callers keep their straight-line estimate.
 */
@Injectable()
export class RoadEtaService {
  private readonly logger = new Logger(RoadEtaService.name);

  constructor(
    private settings: SettingsService,
    private config: ConfigService,
  ) {}

  async measure(legs: DriveLeg[]): Promise<Map<string, DriveMeasure>> {
    const clean = legs.filter((leg) => this.isLeg(leg));
    if (!clean.length) return new Map();

    const found = new Map<string, DriveMeasure>();
    try {
      for (const [key, value] of await this.googleMatrix(clean)) {
        found.set(key, value);
      }
    } catch (err) {
      this.logger.warn('Distance Matrix request failed', err);
    }
    if (found.size === clean.length) return found;

    const missing = clean.filter((leg) => !found.has(leg.key));
    try {
      for (const [key, value] of await this.osrmTable(missing)) {
        found.set(key, value);
      }
    } catch (err) {
      this.logger.warn('OSRM table request failed', err);
    }
    return found;
  }

  private isLeg(leg: DriveLeg) {
    return [leg.originLat, leg.originLng, leg.destLat, leg.destLng].every((n) =>
      Number.isFinite(n),
    );
  }

  private async apiKey() {
    const stored = await this.settings.get(PLATFORM_SETTINGS_KEYS.MAP_API_KEY);
    const fromSettings = typeof stored === 'string' ? stored.trim() : '';
    if (fromSettings) return fromSettings;
    return this.config.get<string>('GOOGLE_MAPS_API_KEY')?.trim() ?? '';
  }

  private async googleMatrix(legs: DriveLeg[]) {
    const key = await this.apiKey();
    const found = new Map<string, DriveMeasure>();
    if (!key) return found;

    const dests: { lat: number; lng: number }[] = [];
    const destIndex = new Map<string, number>();
    for (const leg of legs) {
      const id = this.pointKey(leg.destLat, leg.destLng);
      if (!destIndex.has(id)) {
        destIndex.set(id, dests.length);
        dests.push({ lat: leg.destLat, lng: leg.destLng });
      }
    }

    const url = new URL('https://maps.googleapis.com/maps/api/distancematrix/json');
    url.searchParams.set(
      'origins',
      legs.map((leg) => `${leg.originLat},${leg.originLng}`).join('|'),
    );
    url.searchParams.set(
      'destinations',
      dests.map((point) => `${point.lat},${point.lng}`).join('|'),
    );
    url.searchParams.set('mode', 'driving');
    url.searchParams.set('key', key);

    const res = await fetch(url, { signal: AbortSignal.timeout(ROAD_TIMEOUT_MS) });
    if (!res.ok) return found;
    const body = (await res.json()) as {
      status?: string;
      rows?: { elements?: { status?: string; duration?: { value?: number }; distance?: { value?: number } }[] }[];
    };
    if (body.status !== 'OK' || !Array.isArray(body.rows)) return found;

    legs.forEach((leg, index) => {
      const element = body.rows?.[index]?.elements?.[destIndex.get(this.pointKey(leg.destLat, leg.destLng)) ?? -1];
      const measure = this.fromMeters(element?.status, element?.duration?.value, element?.distance?.value);
      if (measure) found.set(leg.key, measure);
    });
    return found;
  }

  private async osrmTable(legs: DriveLeg[]) {
    const found = new Map<string, DriveMeasure>();
    if (!legs.length) return found;

    const dests: { lat: number; lng: number }[] = [];
    const destIndex = new Map<string, number>();
    for (const leg of legs) {
      const id = this.pointKey(leg.destLat, leg.destLng);
      if (!destIndex.has(id)) {
        destIndex.set(id, dests.length);
        dests.push({ lat: leg.destLat, lng: leg.destLng });
      }
    }

    const coords = [
      ...legs.map((leg) => `${leg.originLng},${leg.originLat}`),
      ...dests.map((point) => `${point.lng},${point.lat}`),
    ].join(';');
    const sources = legs.map((_, index) => index).join(';');
    const destinations = dests.map((_, index) => legs.length + index).join(';');
    const url =
      `https://router.project-osrm.org/table/v1/driving/${coords}` +
      `?annotations=duration,distance&sources=${sources}&destinations=${destinations}`;

    const res = await fetch(url, { signal: AbortSignal.timeout(ROAD_TIMEOUT_MS) });
    if (!res.ok) return found;
    const body = (await res.json()) as {
      code?: string;
      durations?: (number | null)[][];
      distances?: (number | null)[][];
    };
    if (body.code !== 'Ok' || !Array.isArray(body.durations)) return found;

    legs.forEach((leg, index) => {
      const column = destIndex.get(this.pointKey(leg.destLat, leg.destLng)) ?? -1;
      const seconds = body.durations?.[index]?.[column];
      const meters = body.distances?.[index]?.[column];
      const measure = this.fromMeters('OK', seconds, meters);
      if (measure) found.set(leg.key, measure);
    });
    return found;
  }

  private fromMeters(status: string | undefined, seconds: number | null | undefined, meters: number | null | undefined) {
    if (status !== 'OK' || seconds == null || meters == null) return null;
    if (!Number.isFinite(seconds) || !Number.isFinite(meters) || seconds < 0 || meters < 0) {
      return null;
    }
    return {
      etaMinutes: Math.max(1, Math.round(seconds / 60)),
      distanceKm: Math.round((meters / 1000) * 10) / 10,
    };
  }

  private pointKey(lat: number, lng: number) {
    return `${lat.toFixed(5)},${lng.toFixed(5)}`;
  }
}
