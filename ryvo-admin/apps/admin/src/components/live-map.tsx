'use client';

import { forwardRef, useEffect, useImperativeHandle, useRef, useState } from 'react';
import { loadGoogleMaps, type MapMarker } from '@/lib/google-maps';

interface LiveMapProps {
  apiKey: string;
  markers: MapMarker[];
  /** Id of the marker that should render in its highlighted/selected state. */
  activeId?: string | null;
  /** Fired when a marker badge is clicked, so the caller can sync selection. */
  onMarkerClick?: (id: string) => void;
  className?: string;
}

export interface LiveMapHandle {
  fitAll: () => void;
  focusOn: (id: string) => void;
}

const DEFAULT_CENTER = { lat: 40.7128, lng: -74.006 };

/**
 * A custom google.maps.OverlayView subclass rendering a real DOM node per marker,
 * so we get proper CSS (gradients, blur, pulse animation, hover scale) instead of a
 * flat canvas icon. Built lazily once the Maps JS API + a map instance exist.
 */
interface ProviderMarker {
  setPosition: (lat: number, lng: number) => void;
  setLabelAndTitle: (label: string, title: string) => void;
  setHeading: (heading?: number) => void;
  setActive: (active: boolean) => void;
  setClickHandler: (fn?: () => void) => void;
  bounce: () => void;
  getLatLng: () => google.maps.LatLng;
  destroy: () => void;
}

type ProviderMarkerCtor = new (
  google: typeof globalThis.google,
  map: google.maps.Map,
  position: google.maps.LatLngLiteral,
  label: string,
  title: string,
  heading: number | undefined,
) => ProviderMarker;

function createProviderMarkerClass(googleNs: typeof globalThis.google): ProviderMarkerCtor {
  class ProviderMarkerOverlay extends googleNs.maps.OverlayView implements ProviderMarker {
    private div: HTMLDivElement | null = null;
    private badgeEl: HTMLDivElement | null = null;
    private arrowEl: HTMLDivElement | null = null;
    private clickHandler?: () => void;
    private position: google.maps.LatLng;

    constructor(
      _google: typeof globalThis.google,
      map: google.maps.Map,
      position: google.maps.LatLngLiteral,
      private label: string,
      private title: string,
      private heading: number | undefined,
    ) {
      super();
      this.position = new googleNs.maps.LatLng(position.lat, position.lng);
      this.setMap(map);
    }

    override onAdd() {
      const div = document.createElement('div');
      div.style.position = 'absolute';
      div.style.cursor = 'pointer';
      div.style.willChange = 'left, top';
      div.title = this.title;
      div.innerHTML = `
        <div class="group relative flex h-11 w-11 -translate-x-1/2 -translate-y-1/2 items-center justify-center">
          <span class="marker-pulse pointer-events-none absolute h-8 w-8 rounded-full bg-accent opacity-40"></span>
          <div class="marker-arrow pointer-events-none absolute left-1/2 top-1/2 h-4 w-4 opacity-0" style="transition: opacity .2s;">
            <div class="h-full w-full" style="clip-path: polygon(50% 0%, 20% 100%, 80% 100%); background: var(--accent);"></div>
          </div>
          <div class="marker-badge relative flex h-9 w-9 items-center justify-center rounded-full border-[2.5px] border-white bg-gradient-to-br from-accent to-accent-hover text-xs font-bold text-white shadow-[0_2px_8px_rgba(0,0,0,0.35)] transition-transform duration-200 ease-out group-hover:scale-110">
            <span class="marker-badge-label">${escapeHtml(this.label)}</span>
          </div>
        </div>
      `;
      this.div = div;
      this.badgeEl = div.querySelector('.marker-badge');
      this.arrowEl = div.querySelector('.marker-arrow');
      this.setHeading(this.heading);
      if (this.clickHandler) {
        div.addEventListener('click', this.clickHandler);
      }
      const panes = this.getPanes();
      panes?.overlayMouseTarget.appendChild(div);
      this.draw();
    }

    override draw() {
      if (!this.div) return;
      const projection = this.getProjection();
      if (!projection) return;
      const point = projection.fromLatLngToDivPixel(this.position);
      if (point) {
        this.div.style.left = `${point.x}px`;
        this.div.style.top = `${point.y}px`;
      }
    }

    override onRemove() {
      if (this.div) {
        if (this.clickHandler) this.div.removeEventListener('click', this.clickHandler);
        this.div.remove();
        this.div = null;
      }
    }

    setPosition(lat: number, lng: number) {
      this.position = new googleNs.maps.LatLng(lat, lng);
      this.draw();
    }

    setLabelAndTitle(label: string, title: string) {
      this.label = label;
      this.title = title;
      if (this.div) this.div.title = title;
      const labelEl = this.div?.querySelector('.marker-badge-label');
      if (labelEl) labelEl.textContent = label;
    }

    setHeading(heading?: number) {
      this.heading = heading;
      if (!this.arrowEl) return;
      if (heading === undefined || heading === null || Number.isNaN(heading)) {
        this.arrowEl.style.opacity = '0';
        return;
      }
      this.arrowEl.style.opacity = '1';
      this.arrowEl.style.transform = `translate(-50%, -50%) rotate(${heading}deg) translateY(-22px)`;
    }

    setActive(active: boolean) {
      this.badgeEl?.classList.toggle('marker-badge-active', active);
    }

    setClickHandler(fn?: () => void) {
      if (this.div && this.clickHandler) this.div.removeEventListener('click', this.clickHandler);
      this.clickHandler = fn;
      if (this.div && fn) this.div.addEventListener('click', fn);
    }

    bounce() {
      const el = this.badgeEl;
      if (!el) return;
      el.classList.remove('marker-bounce');
      // eslint-disable-next-line @typescript-eslint/no-unused-expressions
      void el.offsetWidth;
      el.classList.add('marker-bounce');
      window.setTimeout(() => el.classList.remove('marker-bounce'), 700);
    }

    getLatLng() {
      return this.position;
    }

    destroy() {
      this.setMap(null);
    }
  }

  return ProviderMarkerOverlay;
}

function escapeHtml(value: string): string {
  return value.replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[c] ?? c);
}

export const LiveMap = forwardRef<LiveMapHandle, LiveMapProps>(function LiveMap(
  { apiKey, markers, activeId, onMarkerClick, className },
  ref,
) {
  const containerRef = useRef<HTMLDivElement>(null);
  const mapRef = useRef<google.maps.Map | null>(null);
  const markerCtorRef = useRef<ProviderMarkerCtor | null>(null);
  const markerRefs = useRef<Map<string, ProviderMarker>>(new Map());
  const [error, setError] = useState<string | null>(null);
  const [ready, setReady] = useState(false);

  useEffect(() => {
    if (!apiKey || !containerRef.current) return;

    let cancelled = false;

    loadGoogleMaps(apiKey)
      .then((google) => {
        if (cancelled || !containerRef.current) return;

        const center =
          markers.length > 0
            ? { lat: markers[0].lat, lng: markers[0].lng }
            : DEFAULT_CENTER;

        mapRef.current = new google.maps.Map(containerRef.current, {
          center,
          zoom: markers.length > 0 ? 12 : 10,
          disableDefaultUI: true,
          zoomControl: true,
          zoomControlOptions: { position: google.maps.ControlPosition.RIGHT_BOTTOM },
          gestureHandling: 'greedy',
          styles: [
            { elementType: 'geometry', stylers: [{ color: '#14151a' }] },
            { elementType: 'labels.icon', stylers: [{ visibility: 'off' }] },
            { elementType: 'labels.text.fill', stylers: [{ color: '#7c8394' }] },
            { elementType: 'labels.text.stroke', stylers: [{ color: '#0b0b0c' }] },
            { featureType: 'administrative', elementType: 'geometry', stylers: [{ color: '#26272e' }] },
            { featureType: 'road', elementType: 'geometry', stylers: [{ color: '#25262d' }] },
            { featureType: 'road', elementType: 'geometry.stroke', stylers: [{ color: '#1a1b20' }] },
            { featureType: 'road.highway', elementType: 'geometry', stylers: [{ color: '#33343d' }] },
            { featureType: 'road.arterial', elementType: 'labels.text.fill', stylers: [{ color: '#8b909d' }] },
            { featureType: 'poi', stylers: [{ visibility: 'off' }] },
            { featureType: 'transit', stylers: [{ visibility: 'off' }] },
            { featureType: 'water', elementType: 'geometry', stylers: [{ color: '#0c1420' }] },
          ],
        });

        markerCtorRef.current = createProviderMarkerClass(google);
        setReady(true);
        setError(null);
      })
      .catch((err: Error) => {
        if (!cancelled) setError(err.message);
      });

    return () => {
      cancelled = true;
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [apiKey]);

  useEffect(() => {
    if (!ready || !mapRef.current || !window.google?.maps || !markerCtorRef.current) return;

    const map = mapRef.current;
    const google = window.google;
    const MarkerCtor = markerCtorRef.current;
    const nextIds = new Set(markers.map((m) => m.id));

    markerRefs.current.forEach((marker, id) => {
      if (!nextIds.has(id)) {
        marker.destroy();
        markerRefs.current.delete(id);
      }
    });

    const bounds = new google.maps.LatLngBounds();

    markers.forEach((m) => {
      bounds.extend({ lat: m.lat, lng: m.lng });
      const label = m.label ?? '•';
      const title = m.title ?? label;
      const existing = markerRefs.current.get(m.id);
      if (existing) {
        existing.setPosition(m.lat, m.lng);
        existing.setLabelAndTitle(label, title);
        existing.setHeading(m.heading);
        existing.setClickHandler(onMarkerClick ? () => onMarkerClick(m.id) : undefined);
        return;
      }

      const marker = new MarkerCtor(google, map, { lat: m.lat, lng: m.lng }, label, title, m.heading);
      marker.setClickHandler(onMarkerClick ? () => onMarkerClick(m.id) : undefined);
      markerRefs.current.set(m.id, marker);
    });

    if (markers.length === 1) {
      map.setCenter({ lat: markers[0].lat, lng: markers[0].lng });
      map.setZoom(13);
    } else if (markers.length > 1) {
      map.fitBounds(bounds, 48);
    }
  }, [markers, ready, onMarkerClick]);

  useEffect(() => {
    markerRefs.current.forEach((marker, id) => marker.setActive(id === activeId));
  }, [activeId]);

  useImperativeHandle(
    ref,
    () => ({
      fitAll: () => {
        const map = mapRef.current;
        const google = window.google;
        if (!map || !google?.maps || markers.length === 0) return;
        if (markers.length === 1) {
          map.panTo({ lat: markers[0].lat, lng: markers[0].lng });
          map.setZoom(13);
          return;
        }
        const bounds = new google.maps.LatLngBounds();
        markers.forEach((m) => bounds.extend({ lat: m.lat, lng: m.lng }));
        map.fitBounds(bounds, 48);
      },
      focusOn: (id: string) => {
        const map = mapRef.current;
        const marker = markerRefs.current.get(id);
        if (!map || !marker) return;
        map.panTo(marker.getLatLng());
        map.setZoom(15);
        marker.bounce();
      },
    }),
    [markers],
  );

  if (error) {
    return (
      <div
        className={`flex h-full min-h-[20rem] items-center justify-center rounded-xl border border-danger/30 bg-danger/5 ${className ?? ''}`}
      >
        <p className="text-sm text-danger">{error}</p>
      </div>
    );
  }

  return (
    <div
      ref={containerRef}
      className={`h-full min-h-[20rem] w-full overflow-hidden rounded-xl ${className ?? ''}`}
    />
  );
});
