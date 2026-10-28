'use client';

import { useEffect, useMemo, useRef, useState } from 'react';
import { useQuery } from '@tanstack/react-query';
import { useRouter } from 'next/navigation';
import { io, Socket } from 'socket.io-client';
import { Header } from '@/components/layout/header';
import { StatusBadge } from '@/components/ui/badge';
import { Avatar } from '@/components/ui/avatar';
import { EmptyState } from '@/components/ui/empty-state';
import { Input } from '@/components/ui/input';
import { Button } from '@/components/ui/button';
import { SegmentedTabs } from '@/components/ui/segmented-tabs';
import { apiFetch, getSocketBaseUrl } from '@/lib/api';
import { useMapApiKey } from '@/hooks/use-map-api-key';
import { LiveMap, type LiveMapHandle } from '@/components/live-map';
import {
  MapPin,
  Radio,
  WifiOff,
  Navigation,
  Users,
  Briefcase,
  RotateCw,
  Maximize2,
  Search,
  ChevronRight,
  Compass,
} from 'lucide-react';
import { cn } from '@/lib/utils';

interface LiveProvider {
  providerId: string;
  lat: number;
  lng: number;
  heading?: number;
  speed?: number;
  fullName?: string;
}

interface LiveJob {
  id: string;
  jobNumber: string;
  status: string;
  customer?: { user: { fullName: string } };
  provider?: { user: { fullName: string } };
}

interface SnapshotProvider {
  id: string;
  currentLat: number | null;
  currentLng: number | null;
  user?: { fullName: string };
}

interface LiveSnapshot {
  providers: SnapshotProvider[];
  activeJobs: LiveJob[];
}

interface ProviderLocationEvent {
  providerId: string;
  lat: number;
  lng: number;
  heading?: number;
  speed?: number;
  jobId?: string;
}

function useRelativeTime(timestamp: number) {
  const [, setTick] = useState(0);

  useEffect(() => {
    const interval = setInterval(() => setTick((t) => t + 1), 1000);
    return () => clearInterval(interval);
  }, []);

  if (!timestamp) return 'never';
  const seconds = Math.max(0, Math.floor((Date.now() - timestamp) / 1000));
  if (seconds < 5) return 'just now';
  if (seconds < 60) return `${seconds}s ago`;
  const minutes = Math.floor(seconds / 60);
  if (minutes < 60) return `${minutes}m ago`;
  return `${Math.floor(minutes / 60)}h ago`;
}

export default function LiveOpsPage() {
  const router = useRouter();
  const [connected, setConnected] = useState(false);
  const [socketProviders, setSocketProviders] = useState<LiveProvider[]>([]);
  const [tab, setTab] = useState<'providers' | 'jobs'>('providers');
  const [providerSearch, setProviderSearch] = useState('');
  const [jobSearch, setJobSearch] = useState('');
  const [selectedProviderId, setSelectedProviderId] = useState<string | null>(null);
  const socketRef = useRef<Socket | null>(null);
  const mapRef = useRef<LiveMapHandle>(null);
  const socketUrl = `${getSocketBaseUrl()}/tracking`;

  const { data: mapApiKey, isLoading: mapKeyLoading } = useMapApiKey();

  const { data, isLoading, error, dataUpdatedAt, refetch, isFetching } = useQuery({
    queryKey: ['live-snapshot'],
    queryFn: async () => {
      const res = await apiFetch<LiveSnapshot>('/admin/dashboard/live');
      return res.data!;
    },
    refetchInterval: 30_000,
  });

  const relativeUpdated = useRelativeTime(dataUpdatedAt);

  useEffect(() => {
    const socket = io(socketUrl, { transports: ['websocket'] });
    socketRef.current = socket;

    socket.on('connect', () => {
      setConnected(true);
      socket.emit('admin:live-map:subscribe');
    });

    socket.on('disconnect', () => setConnected(false));
    socket.on('connect_error', () => setConnected(false));

    socket.on('provider:location', (payload: ProviderLocationEvent) => {
      setSocketProviders((prev) => {
        const idx = prev.findIndex((p) => p.providerId === payload.providerId);
        const entry: LiveProvider = {
          providerId: payload.providerId,
          lat: payload.lat,
          lng: payload.lng,
          heading: payload.heading,
          speed: payload.speed,
        };
        if (idx >= 0) {
          const next = [...prev];
          next[idx] = { ...next[idx], ...entry };
          return next;
        }
        return [...prev, entry];
      });
    });

    return () => {
      socket.disconnect();
    };
  }, [socketUrl]);

  const snapshotProviders: LiveProvider[] = (data?.providers ?? [])
    .filter((p) => p.currentLat != null && p.currentLng != null)
    .map((p) => ({
      providerId: p.id,
      lat: Number(p.currentLat),
      lng: Number(p.currentLng),
      fullName: p.user?.fullName,
    }));

  const providers = socketProviders.length > 0 ? socketProviders : snapshotProviders;
  const activeJobs = data?.activeJobs ?? [];

  const filteredProviders = useMemo(() => {
    const q = providerSearch.trim().toLowerCase();
    if (!q) return providers;
    return providers.filter((p) => (p.fullName ?? p.providerId).toLowerCase().includes(q));
  }, [providers, providerSearch]);

  const filteredJobs = useMemo(() => {
    const q = jobSearch.trim().toLowerCase();
    if (!q) return activeJobs;
    return activeJobs.filter((j) =>
      [j.jobNumber, j.customer?.user.fullName, j.provider?.user.fullName]
        .filter(Boolean)
        .some((v) => v!.toLowerCase().includes(q)),
    );
  }, [activeJobs, jobSearch]);

  const mapMarkers = providers.map((p) => ({
    id: p.providerId,
    lat: p.lat,
    lng: p.lng,
    title: p.fullName ?? p.providerId,
    label: p.fullName?.charAt(0).toUpperCase(),
    heading: p.heading,
  }));

  function focusProvider(id: string) {
    setSelectedProviderId(id);
    mapRef.current?.focusOn(id);
  }

  function selectProviderFromMap(id: string) {
    setTab('providers');
    setSelectedProviderId(id);
  }

  return (
    <>
      <Header title="Live map" description="Real-time driver tracking and active rides" />
      <div className="flex-1 overflow-y-auto p-4 lg:p-6">
        {/* Control bar */}
        <div className="mb-4 flex flex-wrap items-center justify-between gap-3">
          <div className="flex items-center gap-3">
            {connected ? (
              <span className="inline-flex items-center gap-1.5 rounded-full border border-success/20 bg-success/15 px-2.5 py-0.5 text-xs font-medium text-success">
                <Radio className="h-3 w-3 animate-pulse" />
                Live
              </span>
            ) : (
              <span className="inline-flex items-center gap-1.5 rounded-full border border-danger/20 bg-danger/15 px-2.5 py-0.5 text-xs font-medium text-danger">
                <WifiOff className="h-3 w-3" />
                Reconnecting…
              </span>
            )}
            <span className="text-xs text-muted">Synced {relativeUpdated}</span>
          </div>

          <div className="flex items-center gap-2">
            <div className="flex items-center gap-1.5 rounded-full border border-border bg-elevated px-3 py-1 text-xs font-medium text-secondary shadow-xs">
              <Users className="h-3.5 w-3.5 text-info" />
              <span className="font-tabular text-primary">{providers.length}</span> online
            </div>
            <div className="flex items-center gap-1.5 rounded-full border border-border bg-elevated px-3 py-1 text-xs font-medium text-secondary shadow-xs">
              <Briefcase className="h-3.5 w-3.5 text-accent" />
              <span className="font-tabular text-primary">{activeJobs.length}</span> active
            </div>
            <Button
              variant="outline"
              size="icon"
              className="h-8 w-8"
              onClick={() => refetch()}
              aria-label="Refresh"
            >
              <RotateCw className={cn('h-3.5 w-3.5', isFetching && 'animate-spin')} />
            </Button>
          </div>
        </div>

        {/* Map + live console */}
        <div className="grid gap-6 lg:grid-cols-3">
          <div className="relative overflow-hidden rounded-xl border border-border bg-elevated shadow-sm lg:col-span-2">
            <div className="h-[420px] lg:h-[560px]">
              {mapKeyLoading ? (
                <div className="skeleton-shimmer h-full w-full" />
              ) : mapApiKey ? (
                <LiveMap
                  ref={mapRef}
                  apiKey={mapApiKey}
                  markers={mapMarkers}
                  activeId={selectedProviderId}
                  onMarkerClick={selectProviderFromMap}
                />
              ) : (
                <div className="flex h-full flex-col items-center justify-center bg-surface px-6 text-center">
                  <div className="mb-3 flex h-14 w-14 items-center justify-center rounded-full bg-accent-soft">
                    <MapPin className="h-7 w-7 text-accent" />
                  </div>
                  <p className="text-sm font-medium text-primary">No map API key configured</p>
                  <p className="mt-1 max-w-xs text-xs text-secondary">
                    Go to Settings → Google Maps API Key to enable the live map.
                  </p>
                  <p className="font-mono mt-3 text-xs text-muted">
                    Tracking {providers.length} provider(s) via Socket.IO
                  </p>
                </div>
              )}
            </div>

            {/* Floating overlay chrome */}
            {mapApiKey && !mapKeyLoading && (
              <>
                <div className="pointer-events-none absolute left-4 top-4 flex items-center gap-2 rounded-full border border-border/60 bg-overlay/90 px-3 py-1.5 shadow-lg backdrop-blur-md">
                  <span className="relative flex h-2 w-2">
                    <span className="absolute inline-flex h-full w-full animate-ping rounded-full bg-success opacity-75" />
                    <span className="relative inline-flex h-2 w-2 rounded-full bg-success" />
                  </span>
                  <span className="font-tabular text-xs font-medium text-primary">
                    {providers.length} provider{providers.length === 1 ? '' : 's'} live
                  </span>
                </div>
                <button
                  type="button"
                  onClick={() => mapRef.current?.fitAll()}
                  className="absolute right-4 top-4 flex h-8 w-8 items-center justify-center rounded-full border border-border/60 bg-overlay/90 text-secondary shadow-lg backdrop-blur-md transition-colors duration-150 hover:text-primary"
                  aria-label="Fit all markers"
                >
                  <Maximize2 className="h-3.5 w-3.5" />
                </button>
              </>
            )}
          </div>

          {/* Live console */}
          <div className="flex h-[420px] flex-col overflow-hidden rounded-xl border border-border bg-elevated shadow-sm lg:h-[560px]">
            <div className="flex items-center justify-between gap-2 border-b border-border p-3">
              <SegmentedTabs
                items={[
                  { value: 'providers', label: 'Drivers', icon: Users, count: providers.length },
                  { value: 'jobs', label: 'Rides', icon: Briefcase, count: activeJobs.length },
                ]}
                value={tab}
                onChange={(v) => setTab(v as 'providers' | 'jobs')}
              />
            </div>

            <div className="border-b border-border p-3">
              <div className="relative">
                <Search className="absolute left-3 top-1/2 h-3.5 w-3.5 -translate-y-1/2 text-muted" />
                <Input
                  value={tab === 'providers' ? providerSearch : jobSearch}
                  onChange={(e) =>
                    tab === 'providers'
                      ? setProviderSearch(e.target.value)
                      : setJobSearch(e.target.value)
                  }
                  placeholder={tab === 'providers' ? 'Search drivers...' : 'Search jobs...'}
                  className="h-8 pl-8 text-xs"
                />
              </div>
            </div>

            <div className="flex-1 overflow-y-auto p-2">
              {isLoading ? (
                <div className="space-y-1.5 p-1">
                  {Array.from({ length: 5 }).map((_, i) => (
                    <div key={i} className="skeleton-shimmer h-14 rounded-lg" />
                  ))}
                </div>
              ) : error ? (
                <p className="p-3 text-sm text-danger">Failed to load live snapshot</p>
              ) : tab === 'providers' ? (
                filteredProviders.length === 0 ? (
                  <EmptyState
                    title={providers.length === 0 ? 'No drivers online' : 'No matches'}
                    description={
                      providers.length === 0
                        ? 'Drivers will appear here once they go online.'
                        : 'Try a different search term.'
                    }
                    className="border-none bg-transparent py-10"
                  />
                ) : (
                  <ul className="space-y-1">
                    {filteredProviders.map((p) => (
                      <li key={p.providerId}>
                        <button
                          type="button"
                          onClick={() => focusProvider(p.providerId)}
                          className={cn(
                            'group flex w-full items-center gap-3 rounded-lg px-2 py-2 text-left transition-colors duration-150 hover:bg-surface',
                            selectedProviderId === p.providerId && 'bg-accent-soft',
                          )}
                        >
                          <Avatar name={p.fullName ?? p.providerId} size="sm" />
                          <div className="min-w-0 flex-1">
                            <p className="truncate text-sm font-medium text-primary">
                              {p.fullName ?? p.providerId.slice(0, 8)}
                            </p>
                            <p className="font-mono flex items-center gap-1 text-xs text-muted">
                              <Navigation className="h-3 w-3" />
                              {p.lat.toFixed(4)}, {p.lng.toFixed(4)}
                            </p>
                          </div>
                          <span className="h-2 w-2 shrink-0 rounded-full bg-success" />
                          <ChevronRight
                            className="h-3.5 w-3.5 shrink-0 text-muted opacity-0 transition-opacity group-hover:opacity-100"
                            onClick={(e) => {
                              e.stopPropagation();
                              router.push(`/providers/${p.providerId}`);
                            }}
                          />
                        </button>
                      </li>
                    ))}
                  </ul>
                )
              ) : filteredJobs.length === 0 ? (
                <EmptyState
                  title={activeJobs.length === 0 ? 'No active jobs right now' : 'No matches'}
                  description={
                    activeJobs.length === 0
                      ? 'Active jobs will show up here in real time as customers book services.'
                      : 'Try a different search term.'
                  }
                  className="border-none bg-transparent py-10"
                />
              ) : (
                <ul className="space-y-1">
                  {filteredJobs.map((job) => (
                    <li key={job.id}>
                      <button
                        type="button"
                        onClick={() => router.push(`/jobs/${job.id}`)}
                        className="flex w-full items-center justify-between gap-3 rounded-lg px-3 py-2.5 text-left transition-colors duration-150 hover:bg-surface"
                      >
                        <div className="min-w-0">
                          <p className="font-mono text-[13px] font-medium text-primary">
                            {job.jobNumber}
                          </p>
                          <p className="mt-0.5 truncate text-xs text-secondary">
                            {job.customer?.user.fullName ?? '—'} →{' '}
                            {job.provider?.user.fullName ?? 'Unassigned'}
                          </p>
                        </div>
                        <StatusBadge status={job.status} />
                      </button>
                    </li>
                  ))}
                </ul>
              )}
            </div>

            <div className="flex items-center gap-1.5 border-t border-border px-3 py-2 text-[11px] text-muted">
              <Compass className="h-3 w-3" />
              <span className="font-mono truncate">{socketUrl}</span>
            </div>
          </div>
        </div>
      </div>
    </>
  );
}
