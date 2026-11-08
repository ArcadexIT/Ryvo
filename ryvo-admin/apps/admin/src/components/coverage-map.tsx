'use client';

import { useEffect, useRef, useState } from 'react';
import { loadGoogleMaps } from '@/lib/google-maps';
import { cssColor, opsMapStyles } from '@/lib/css-color';

export interface CoverageZoneShape {
  id: string;
  name: string;
  audience: 'customer' | 'provider' | 'both';
  centerLat: number;
  centerLng: number;
  radiusKm: number;
  isActive: boolean;
}

export interface CoveragePin {
  id: string;
  lat: number;
  lng: number;
  title: string;
}

export interface DraftZone {
  lat: number;
  lng: number;
  radiusKm: number;
}

const AUDIENCE_TOKEN: Record<CoverageZoneShape['audience'], string> = {
  both: '--success',
  customer: '--info',
  provider: '--warning',
};

interface CoverageMapProps {
  apiKey: string;
  zones: CoverageZoneShape[];
  interests: CoveragePin[];
  draft: DraftZone;
  selectedId?: string;
  focusNonce: number;
  onPick: (lat: number, lng: number) => void;
  onSelectZone: (id: string) => void;
}

export function CoverageMap({
  apiKey,
  zones,
  interests,
  draft,
  selectedId,
  focusNonce,
  onPick,
  onSelectZone,
}: CoverageMapProps) {
  const containerRef = useRef<HTMLDivElement>(null);
  const mapRef = useRef<google.maps.Map | null>(null);
  const markerRef = useRef<google.maps.Marker | null>(null);
  const draftCircleRef = useRef<google.maps.Circle | null>(null);
  const zoneCirclesRef = useRef<google.maps.Circle[]>([]);
  const interestMarkersRef = useRef<google.maps.Marker[]>([]);
  const [ready, setReady] = useState(false);
  const onPickRef = useRef(onPick);
  const onSelectRef = useRef(onSelectZone);
  onPickRef.current = onPick;
  onSelectRef.current = onSelectZone;

  useEffect(() => {
    let cancelled = false;
    loadGoogleMaps(apiKey).then((google) => {
      if (cancelled || !containerRef.current || mapRef.current) return;
      const map = new google.maps.Map(containerRef.current, {
        center: { lat: draft.lat, lng: draft.lng },
        zoom: 10,
        disableDefaultUI: true,
        zoomControl: true,
        zoomControlOptions: { position: google.maps.ControlPosition.RIGHT_BOTTOM },
        gestureHandling: 'greedy',
        styles: opsMapStyles(),
        clickableIcons: false,
      });
      map.addListener('click', (event: google.maps.MapMouseEvent) => {
        if (!event.latLng) return;
        onPickRef.current(event.latLng.lat(), event.latLng.lng());
      });
      const marker = new google.maps.Marker({
        map,
        position: { lat: draft.lat, lng: draft.lng },
        draggable: true,
        title: 'Zone centre',
      });
      marker.addListener('dragend', () => {
        const position = marker.getPosition();
        if (!position) return;
        onPickRef.current(position.lat(), position.lng());
      });
      draftCircleRef.current = new google.maps.Circle({
        map,
        center: { lat: draft.lat, lng: draft.lng },
        radius: draft.radiusKm * 1000,
        strokeColor: cssColor('--warning'),
        strokeWeight: 2,
        fillColor: cssColor('--warning'),
        fillOpacity: 0.16,
        clickable: false,
      });
      mapRef.current = map;
      markerRef.current = marker;
      setReady(true);
    });
    return () => {
      cancelled = true;
    };
    // Create the map once. Draft updates are applied below.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [apiKey]);

  useEffect(() => {
    const map = mapRef.current;
    const marker = markerRef.current;
    const circle = draftCircleRef.current;
    if (!map || !marker || !circle) return;
    const center = { lat: draft.lat, lng: draft.lng };
    marker.setPosition(center);
    circle.setCenter(center);
    circle.setRadius(Math.max(draft.radiusKm, 0.2) * 1000);
  }, [draft.lat, draft.lng, draft.radiusKm]);

  useEffect(() => {
    const map = mapRef.current;
    const circle = draftCircleRef.current;
    if (!map || !circle || !ready || focusNonce === 0) return;
    const bounds = circle.getBounds();
    if (bounds) map.fitBounds(bounds, 48);
  }, [focusNonce, ready]);

  useEffect(() => {
    const map = mapRef.current;
    if (!map || !ready || !window.google) return;
    zoneCirclesRef.current.forEach((circle) => circle.setMap(null));
    zoneCirclesRef.current = zones
      .filter((zone) => zone.id !== selectedId)
      .map((zone) => {
        const color = zone.isActive ? cssColor(AUDIENCE_TOKEN[zone.audience]) : cssColor('--text-muted');
        const circle = new google.maps.Circle({
          map,
          center: { lat: zone.centerLat, lng: zone.centerLng },
          radius: Number(zone.radiusKm) * 1000,
          strokeColor: color,
          strokeWeight: zone.isActive ? 2 : 1,
          fillColor: color,
          fillOpacity: zone.isActive ? 0.12 : 0.05,
          clickable: true,
        });
        circle.addListener('click', () => onSelectRef.current(zone.id));
        return circle;
      });
  }, [zones, selectedId, ready]);

  useEffect(() => {
    const map = mapRef.current;
    if (!map || !ready || !window.google) return;
    interestMarkersRef.current.forEach((marker) => marker.setMap(null));
    interestMarkersRef.current = interests.map(
      (pin) =>
        new google.maps.Marker({
          map,
          position: { lat: pin.lat, lng: pin.lng },
          title: pin.title,
          icon: {
            path: google.maps.SymbolPath.CIRCLE,
            scale: 6,
            fillColor: cssColor('--danger'),
            fillOpacity: 1,
            strokeColor: cssColor('--text'),
            strokeWeight: 1,
          },
        }),
    );
  }, [interests, ready]);

  return <div ref={containerRef} className="h-full w-full" />;
}
