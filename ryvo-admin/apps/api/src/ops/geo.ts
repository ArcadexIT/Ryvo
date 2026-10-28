export function distanceKm(lat1: number, lng1: number, lat2: number, lng2: number): number {
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

/** Arrival estimate at a typical urban speed of 40 km/h. */
export function etaMinutesFromKm(km: number): number {
  return Math.max(1, Math.round((km / 40) * 60));
}

/** Provider-to-pickup distance for an incoming job offer. */
export function providerTravelToPickup(
  providerLat: unknown,
  providerLng: unknown,
  pickupLat: unknown,
  pickupLng: unknown,
): { providerDistanceKm: number; etaMinutes: number } | null {
  if (providerLat == null || providerLng == null || pickupLat == null || pickupLng == null) {
    return null;
  }
  const km =
    Math.round(
      distanceKm(Number(providerLat), Number(providerLng), Number(pickupLat), Number(pickupLng)) * 10,
    ) / 10;
  if (!Number.isFinite(km)) return null;
  return { providerDistanceKm: km, etaMinutes: etaMinutesFromKm(km) };
}
