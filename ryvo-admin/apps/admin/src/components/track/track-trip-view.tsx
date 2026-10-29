'use client';

import { useEffect, useRef, useState } from 'react';
import { io, Socket } from 'socket.io-client';
import { getApiBaseUrl, getSocketBaseUrl } from '@/lib/api';
import { loadGoogleMaps } from '@/lib/google-maps';

type Place = { address: string; lat: number; lng: number };

type Vehicle = {
  make: string;
  model: string;
  color: string | null;
  plate: string;
};

type Driver = {
  firstName: string;
  rating: number | null;
  lat: number | null;
  lng: number | null;
  vehicle: Vehicle | null;
};

type LiveTrip = {
  active: true;
  state: 'live' | 'waiting';
  status: string;
  riderFirstName: string;
  pickup: Place;
  dropoff: Place | null;
  driver: Driver | null;
  mapApiKey: string | null;
};

type EndedTrip = { active: false; state: 'ended' };

type Trip = LiveTrip | EndedTrip;

type Car = { lat: number; lng: number; heading?: number };

const LIVE = new Set(['matched', 'provider_en_route', 'arrived', 'in_progress']);

const ENV_MAP_KEY = process.env.NEXT_PUBLIC_MAP_API_KEY ?? '';

function statusLabel(status: string, state: LiveTrip['state']) {
  if (state === 'waiting') return 'Looking for a driver';
  switch (status) {
    case 'matched':
    case 'provider_en_route':
      return 'Driver on the way';
    case 'arrived':
      return 'Driver arrived';
    case 'in_progress':
      return 'Trip in progress';
    default:
      return 'Trip update';
  }
}

function vehicleTitle(vehicle: Vehicle) {
  const make = vehicle.make.trim();
  const model = vehicle.model.trim();
  if (!model) return make;
  if (make && model.toLowerCase().includes(make.toLowerCase())) return model;
  return `${make} ${model}`.trim();
}

function labelName(name: string) {
  return name
    .split(/\s+/)
    .map((part) => (part ? part.charAt(0).toUpperCase() + part.slice(1) : part))
    .join(' ');
}

type Point = { lat: number; lng: number };

type RouteLeg = { minutes: number; km: number; path: Point[] };

function routeEnds(trip: LiveTrip, car: Car | null): { origin: Point; destination: Point; to: 'pickup' | 'dropoff' } | null {
  const carPoint = trip.state === 'live' && car ? car : null;
  const onTheWay = trip.status === 'matched' || trip.status === 'provider_en_route' || trip.status === 'arrived';
  if (onTheWay) {
    const origin = carPoint ?? null;
    if (!origin) {
      if (!trip.dropoff) return null;
      return { origin: trip.pickup, destination: trip.dropoff, to: 'dropoff' };
    }
    return { origin, destination: trip.pickup, to: 'pickup' };
  }
  if (trip.dropoff) {
    return { origin: carPoint ?? trip.pickup, destination: trip.dropoff, to: 'dropoff' };
  }
  return null;
}

function routeKeyOf(status: string, ends: { origin: Point; destination: Point }) {
  const origin = `${ends.origin.lat.toFixed(3)},${ends.origin.lng.toFixed(3)}`;
  const dest = `${ends.destination.lat.toFixed(4)},${ends.destination.lng.toFixed(4)}`;
  return `${status}:${origin}>${dest}`;
}

function decodePolyline(encoded: string): Point[] {
  const points: Point[] = [];
  let index = 0;
  let lat = 0;
  let lng = 0;
  while (index < encoded.length) {
    let shift = 0;
    let result = 0;
    let byte = 0;
    do {
      byte = encoded.charCodeAt(index++) - 63;
      result |= (byte & 0x1f) << shift;
      shift += 5;
    } while (byte >= 0x20);
    lat += result & 1 ? ~(result >> 1) : result >> 1;
    shift = 0;
    result = 0;
    do {
      byte = encoded.charCodeAt(index++) - 63;
      result |= (byte & 0x1f) << shift;
      shift += 5;
    } while (byte >= 0x20);
    lng += result & 1 ? ~(result >> 1) : result >> 1;
    points.push({ lat: lat / 1e5, lng: lng / 1e5 });
  }
  return points;
}

function fetchGoogleRoute(
  maps: typeof google,
  origin: Point,
  destination: Point,
): Promise<RouteLeg | null> {
  const service = new maps.maps.DirectionsService();
  return new Promise((resolve) => {
    service.route(
      {
        origin,
        destination,
        travelMode: maps.maps.TravelMode.DRIVING,
      },
      (result, status) => {
        const drawn = result?.routes?.[0];
        if (status !== 'OK' || !drawn) {
          resolve(null);
          return;
        }
        const leg = drawn.legs[0];
        resolve({
          path: drawn.overview_path.map((point) => ({ lat: point.lat(), lng: point.lng() })),
          minutes: leg?.duration?.value != null ? Math.ceil(leg.duration.value / 60) : 0,
          km: leg?.distance?.value != null ? leg.distance.value / 1000 : 0,
        });
      },
    );
  });
}

async function fetchOsrmRoute(origin: Point, destination: Point): Promise<RouteLeg | null> {
  try {
    const url =
      `https://router.project-osrm.org/route/v1/driving/` +
      `${origin.lng},${origin.lat};${destination.lng},${destination.lat}` +
      `?overview=full&geometries=polyline`;
    const res = await fetch(url);
    if (!res.ok) return null;
    const data = (await res.json()) as {
      code?: string;
      routes?: { geometry?: string; duration?: number; distance?: number }[];
    };
    const route = data.code === 'Ok' ? data.routes?.[0] : undefined;
    if (!route?.geometry) return null;
    const path = decodePolyline(route.geometry);
    if (path.length < 2) return null;
    return {
      path,
      minutes: typeof route.duration === 'number' ? Math.ceil(route.duration / 60) : 0,
      km: typeof route.distance === 'number' ? route.distance / 1000 : 0,
    };
  } catch {
    return null;
  }
}

async function fetchDrivingRoute(maps: typeof google, origin: Point, destination: Point): Promise<RouteLeg> {
  const googleRoute = await fetchGoogleRoute(maps, origin, destination).catch(() => null);
  if (googleRoute && googleRoute.path.length >= 2) return googleRoute;
  const osrm = await fetchOsrmRoute(origin, destination);
  if (osrm) return osrm;
  return { path: [origin, destination], minutes: 0, km: 0 };
}

export function TrackTripView({ token }: { token: string }) {
  const [trip, setTrip] = useState<Trip | null>(null);
  const [missing, setMissing] = useState(false);
  const [failed, setFailed] = useState(false);
  const [car, setCar] = useState<Car | null>(null);
  const lastSocketAt = useRef(0);
  const seenTrip = useRef(false);
  const liveRef = useRef(false);
  const endedRef = useRef(false);
  const mapNode = useRef<HTMLDivElement | null>(null);
  const mapRef = useRef<google.maps.Map | null>(null);
  const pickupMarker = useRef<google.maps.Marker | null>(null);
  const dropoffMarker = useRef<google.maps.Marker | null>(null);
  const carMarker = useRef<google.maps.Marker | null>(null);
  const routeCasing = useRef<google.maps.Polyline | null>(null);
  const routeLine = useRef<google.maps.Polyline | null>(null);
  const drawnRouteKey = useRef('');
  const [leg, setLeg] = useState<{ minutes: number; km: number; to: 'pickup' | 'dropoff' } | null>(null);

  useEffect(() => {
    let cancelled = false;
    endedRef.current = false;
    const load = async () => {
      try {
        const res = await fetch(`${getApiBaseUrl()}/public/trips/${encodeURIComponent(token)}`, {
          cache: 'no-store',
        });
        if (cancelled || endedRef.current) return;
        if (res.status === 404) {
          if (seenTrip.current) {
            endedRef.current = true;
            liveRef.current = false;
            setCar(null);
            setTrip({ active: false, state: 'ended' });
          } else {
            setMissing(true);
            setTrip(null);
          }
          return;
        }
        if (!res.ok) {
          setFailed(true);
          return;
        }
        const json = (await res.json()) as { success?: boolean; data?: Trip };
        const next = json.data;
        if (!next) {
          setFailed(true);
          return;
        }
        setFailed(false);
        setMissing(false);
        seenTrip.current = true;
        setTrip(next);
        if (!next.active) {
          endedRef.current = true;
          liveRef.current = false;
          lastSocketAt.current = 0;
          setCar(null);
          return;
        }
        liveRef.current = next.state === 'live';
        const lat = next.driver?.lat;
        const lng = next.driver?.lng;
        const socketFresh = Date.now() - lastSocketAt.current < 8000;
        if (!socketFresh && lat != null && lng != null) {
          setCar({ lat, lng });
        }
        if (next.state !== 'live') {
          lastSocketAt.current = 0;
          setCar(null);
        }
      } catch {
        if (!cancelled) setFailed(true);
      }
    };

    void load();
    const timer = window.setInterval(() => void load(), 4000);
    return () => {
      cancelled = true;
      window.clearInterval(timer);
    };
  }, [token]);

  useEffect(() => {
    const socket: Socket = io(`${getSocketBaseUrl()}/tracking`, { transports: ['websocket'] });
    socket.on('connect', () => {
      socket.emit('share:subscribe', { token });
    });
    socket.on('job:status', (payload: { status?: string; ended?: boolean }) => {
      const status = payload?.status ?? '';
      if (payload?.ended || status === 'ended' || status === 'completed' || status.startsWith('cancelled')) {
        endedRef.current = true;
        liveRef.current = false;
        lastSocketAt.current = 0;
        setCar(null);
        setTrip({ active: false, state: 'ended' });
        setMissing(false);
        seenTrip.current = true;
        return;
      }
      if (!status) return;
      const live = LIVE.has(status);
      liveRef.current = live;
      if (!live) {
        lastSocketAt.current = 0;
        setCar(null);
      }
      setTrip((prev) => {
        if (!prev || !prev.active) return prev;
        return {
          ...prev,
          status,
          state: live ? 'live' : 'waiting',
          driver: live ? prev.driver : null,
        };
      });
    });
    socket.on('job:location', (payload: { lat?: number; lng?: number; heading?: number }) => {
      const lat = Number(payload?.lat);
      const lng = Number(payload?.lng);
      if (!Number.isFinite(lat) || !Number.isFinite(lng)) return;
      if (!liveRef.current) return;
      lastSocketAt.current = Date.now();
      const heading = Number(payload.heading);
      setCar({ lat, lng, ...(Number.isFinite(heading) ? { heading } : {}) });
    });
    return () => {
      socket.disconnect();
    };
  }, [token]);

  useEffect(() => {
    drawnRouteKey.current = '';
    setLeg(null);
  }, [token]);

  const mapKey =
    ENV_MAP_KEY || (trip && trip.active ? trip.mapApiKey ?? '' : '');
  const liveTrip = trip && trip.active ? trip : null;
  const ends = liveTrip ? routeEnds(liveTrip, car) : null;
  const routeKey = liveTrip && ends ? routeKeyOf(liveTrip.status, ends) : '';
  const tripSig = liveTrip
    ? `${liveTrip.status}|${liveTrip.state}|${liveTrip.pickup.lat},${liveTrip.pickup.lng}|${liveTrip.dropoff?.lat ?? ''},${liveTrip.dropoff?.lng ?? ''}`
    : '';

  useEffect(() => {
    const marker = carMarker.current;
    if (!marker || !car || !liveTrip || liveTrip.state !== 'live') return;
    marker.setPosition({ lat: car.lat, lng: car.lng });
    if (car.heading != null) {
      const icon = marker.getIcon();
      if (icon && typeof icon === 'object') {
        marker.setIcon({ ...icon, rotation: car.heading });
      }
    }
  }, [car, liveTrip]);

  useEffect(() => {
    if (!mapKey || !liveTrip || !mapNode.current) return;
    let cancelled = false;
    const endsNow = routeEnds(liveTrip, car);
    const keyNow = endsNow ? routeKeyOf(liveTrip.status, endsNow) : '';

    void loadGoogleMaps(mapKey).then(async (maps) => {
      if (cancelled || !mapNode.current) return;
      if (!mapRef.current) {
        mapRef.current = new maps.maps.Map(mapNode.current, {
          center: { lat: liveTrip.pickup.lat, lng: liveTrip.pickup.lng },
          zoom: 14,
          disableDefaultUI: true,
          zoomControl: true,
          zoomControlOptions: { position: maps.maps.ControlPosition.RIGHT_TOP },
          clickableIcons: false,
          gestureHandling: 'greedy',
        });
      }
      const map = mapRef.current;
      const dot = (color: string) => ({
        path: maps.maps.SymbolPath.CIRCLE,
        scale: 9,
        fillColor: color,
        fillOpacity: 1,
        strokeColor: '#ffffff',
        strokeWeight: 2,
      });

      if (!pickupMarker.current) {
        pickupMarker.current = new maps.maps.Marker({ map, title: 'Pickup', icon: dot('#2563eb') });
      }
      pickupMarker.current.setPosition({ lat: liveTrip.pickup.lat, lng: liveTrip.pickup.lng });

      if (liveTrip.dropoff) {
        if (!dropoffMarker.current) {
          dropoffMarker.current = new maps.maps.Marker({ map, title: 'Drop-off', icon: dot('#ef4444') });
        }
        dropoffMarker.current.setMap(map);
        dropoffMarker.current.setPosition({ lat: liveTrip.dropoff.lat, lng: liveTrip.dropoff.lng });
      } else if (dropoffMarker.current) {
        dropoffMarker.current.setMap(null);
      }

      if (car && liveTrip.state === 'live') {
        const carIcon = {
          path: maps.maps.SymbolPath.FORWARD_CLOSED_ARROW,
          scale: 7,
          rotation: car.heading ?? 0,
          fillColor: '#1fa855',
          fillOpacity: 1,
          strokeColor: '#ffffff',
          strokeWeight: 2,
        };
        if (!carMarker.current) {
          carMarker.current = new maps.maps.Marker({ map, title: 'Car', zIndex: 10, icon: carIcon });
        } else {
          carMarker.current.setIcon(carIcon);
        }
        carMarker.current.setMap(map);
        carMarker.current.setPosition({ lat: car.lat, lng: car.lng });
      } else if (carMarker.current) {
        carMarker.current.setMap(null);
      }

      if (!endsNow || !keyNow || drawnRouteKey.current === keyNow) return;
      const route = await fetchDrivingRoute(maps, endsNow.origin, endsNow.destination);
      if (cancelled) return;
      drawnRouteKey.current = keyNow;

      if (!routeCasing.current) {
        routeCasing.current = new maps.maps.Polyline({
          map,
          strokeColor: '#ffffff',
          strokeOpacity: 0.95,
          strokeWeight: 9,
          zIndex: 1,
        });
      }
      if (!routeLine.current) {
        routeLine.current = new maps.maps.Polyline({
          map,
          strokeColor: '#1fa855',
          strokeOpacity: 1,
          strokeWeight: 5,
          zIndex: 2,
        });
      }
      routeCasing.current.setMap(map);
      routeLine.current.setMap(map);
      routeCasing.current.setPath(route.path);
      routeLine.current.setPath(route.path);
      setLeg(
        route.minutes > 0 || route.km > 0
          ? { minutes: route.minutes, km: route.km, to: endsNow.to }
          : null,
      );

      const bounds = new maps.maps.LatLngBounds();
      route.path.forEach((point) => bounds.extend(point));
      bounds.extend(liveTrip.pickup);
      if (liveTrip.dropoff) bounds.extend(liveTrip.dropoff);
      map.fitBounds(bounds, { top: 72, right: 48, bottom: 300, left: 48 });
    });

    return () => {
      cancelled = true;
    };
  }, [mapKey, routeKey, tripSig]);

  if (missing) {
    return <EndedCard title="Link not found" body="This trip link is not valid." />;
  }
  if (trip && !trip.active) {
    return (
      <EndedCard
        title="Trip ended"
        body="This trip has ended. Live location is no longer shared."
      />
    );
  }
  if (!trip && failed) {
    return (
      <EndedCard
        title="Could not load this trip"
        body="Check the link and try again in a moment."
      />
    );
  }
  if (!trip) {
    return (
      <div className="flex min-h-dvh items-center justify-center bg-canvas text-secondary">
        Loading trip…
      </div>
    );
  }

  const driver = trip.driver;
  return (
    <div className="relative min-h-dvh bg-canvas text-primary">
      {mapKey ? (
        <div ref={mapNode} className="absolute inset-0" />
      ) : (
        <div className="absolute inset-0 bg-surface" />
      )}
      <div className="pointer-events-none absolute inset-x-0 bottom-0 p-4 sm:p-6">
        <div className="pointer-events-auto mx-auto w-full max-w-lg rounded-2xl border border-border bg-elevated/95 p-5 shadow-xl backdrop-blur">
          <div className="flex items-start justify-between gap-3">
            <div>
              <p className="text-xs font-semibold uppercase tracking-wide text-accent">Ryvo</p>
              <h1 className="mt-1 text-2xl font-semibold">{labelName(trip.riderFirstName)}&apos;s trip</h1>
              <p className="mt-1 text-secondary">{statusLabel(trip.status, trip.state)}</p>
            </div>
            {leg ? (
              <div className="rounded-xl bg-accent-soft px-3 py-2 text-right">
                <p className="text-lg font-semibold leading-none text-primary">~{leg.minutes} min</p>
                <p className="mt-1 text-xs text-secondary">
                  {leg.km.toFixed(1)} km to {leg.to === 'pickup' ? 'pickup' : 'drop-off'}
                </p>
              </div>
            ) : null}
          </div>
          {driver ? (
            <div className="mt-4 border-t border-border pt-4">
              <div className="flex items-center justify-between gap-3">
                <p className="font-medium">{labelName(driver.firstName)}</p>
                {driver.rating != null && driver.rating > 0 ? (
                  <p className="text-sm text-secondary">{driver.rating.toFixed(1)} rating</p>
                ) : null}
              </div>
              {driver.vehicle ? (
                <div className="mt-2 flex flex-wrap items-center gap-2 text-sm">
                  <span className="text-primary">{vehicleTitle(driver.vehicle)}</span>
                  {driver.vehicle.color ? (
                    <span className="text-secondary">{driver.vehicle.color}</span>
                  ) : null}
                  <span className="rounded-md bg-surface px-2 py-0.5 font-mono text-xs tracking-wide text-primary">
                    {driver.vehicle.plate}
                  </span>
                </div>
              ) : null}
            </div>
          ) : null}
          <div className="mt-4 space-y-2 text-sm">
            <p className="flex gap-2">
              <span className="mt-1 h-2.5 w-2.5 shrink-0 rounded-full bg-[#2563eb]" />
              <span>
                <span className="text-secondary">Pickup · </span>
                {trip.pickup.address}
              </span>
            </p>
            {trip.dropoff ? (
              <p className="flex gap-2">
                <span className="mt-1 h-2.5 w-2.5 shrink-0 rounded-full bg-[#ef4444]" />
                <span>
                  <span className="text-secondary">Drop-off · </span>
                  {trip.dropoff.address}
                </span>
              </p>
            ) : null}
          </div>
          {!mapKey ? (
            <p className="mt-3 text-sm text-secondary">Live map is unavailable right now.</p>
          ) : null}
        </div>
      </div>
    </div>
  );
}

function EndedCard({ title, body }: { title: string; body: string }) {
  return (
    <div className="flex min-h-dvh items-center justify-center bg-canvas px-6">
      <div className="w-full max-w-md rounded-2xl border border-border bg-elevated p-6 text-center shadow-xl">
        <p className="text-xs font-semibold uppercase tracking-wide text-accent">Ryvo</p>
        <h1 className="mt-2 text-2xl font-semibold text-primary">{title}</h1>
        <p className="mt-2 text-secondary">{body}</p>
      </div>
    </div>
  );
}
