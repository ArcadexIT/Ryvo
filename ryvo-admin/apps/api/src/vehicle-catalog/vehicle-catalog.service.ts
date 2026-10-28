import { BadRequestException, Injectable, Logger } from '@nestjs/common';

type VehicleCatalogType = 'car' | 'motorcycle';

interface CacheEntry {
  items: string[];
  expiresAt: number;
}

const CACHE_TTL_MS = 24 * 60 * 60 * 1000;
const NHTSA_BASE = 'https://vpic.nhtsa.dot.gov/api/vehicles';

@Injectable()
export class VehicleCatalogService {
  private readonly logger = new Logger(VehicleCatalogService.name);
  private readonly cache = new Map<string, CacheEntry>();

  async getMakes(type: string): Promise<string[]> {
    const vehicleType = this.parseType(type);
    const cacheKey = `makes:${vehicleType}`;
    const cached = this.getCached(cacheKey);
    if (cached) return cached;

    const url = `${NHTSA_BASE}/GetMakesForVehicleType/${vehicleType}?format=json`;
    const data = await this.fetchJson(url);
    const items = this.uniqueSorted(
      (data.Results ?? [])
        .map((row: { MakeName?: string }) => row.MakeName?.trim())
        .filter((name: string | undefined): name is string => !!name),
    );

    this.setCache(cacheKey, items);
    return items;
  }

  async getModels(type: string, make: string): Promise<string[]> {
    const vehicleType = this.parseType(type);
    const normalizedMake = make?.trim();
    if (!normalizedMake) {
      throw new BadRequestException('make is required');
    }

    const cacheKey = `models:${vehicleType}:${normalizedMake.toUpperCase()}`;
    const cached = this.getCached(cacheKey);
    if (cached) return cached;

    const encodedMake = encodeURIComponent(normalizedMake);
    const url = `${NHTSA_BASE}/GetModelsForMake/${encodedMake}?format=json`;
    const data = await this.fetchJson(url);
    const items = this.uniqueSorted(
      (data.Results ?? [])
        .filter((row: { VehicleTypeName?: string }) => this.matchesVehicleType(row.VehicleTypeName, vehicleType))
        .map((row: { Model_Name?: string }) => row.Model_Name?.trim())
        .filter((name: string | undefined): name is string => !!name),
    );

    this.setCache(cacheKey, items);
    return items;
  }

  private parseType(type: string): VehicleCatalogType {
    if (type === 'car' || type === 'motorcycle') return type;
    throw new BadRequestException('type must be car or motorcycle');
  }

  private getCached(key: string): string[] | null {
    const entry = this.cache.get(key);
    if (!entry) return null;
    if (Date.now() > entry.expiresAt) {
      this.cache.delete(key);
      return null;
    }
    return entry.items;
  }

  private setCache(key: string, items: string[]) {
    this.cache.set(key, { items, expiresAt: Date.now() + CACHE_TTL_MS });
  }

  /** GetModelsForMake omits vehicle type; keep every model in that case. */
  private matchesVehicleType(vehicleTypeName: string | undefined, type: VehicleCatalogType) {
    if (!vehicleTypeName?.trim()) return true;
    const name = vehicleTypeName.toLowerCase();
    if (type === 'motorcycle') return name.includes('motorcycle');
    return !name.includes('motorcycle');
  }

  private uniqueSorted(items: string[]): string[] {
    return [...new Set(items)].sort((a, b) => a.localeCompare(b));
  }

  private async fetchJson(url: string): Promise<{ Results?: Array<Record<string, string>> }> {
    try {
      const res = await fetch(url);
      if (!res.ok) {
        throw new Error(`NHTSA responded with ${res.status}`);
      }
      return (await res.json()) as { Results?: Array<Record<string, string>> };
    } catch (err) {
      this.logger.error(`Failed to fetch vehicle catalog from ${url}`, err instanceof Error ? err.stack : err);
      throw new BadRequestException('Unable to load vehicle catalog. Please try again.');
    }
  }
}
