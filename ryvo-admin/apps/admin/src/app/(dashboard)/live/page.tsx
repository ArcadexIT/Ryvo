'use client';

import { useEffect, useMemo, useRef, useState, type ReactNode } from 'react';
import { useQuery } from '@tanstack/react-query';
import { useRouter } from 'next/navigation';
import { io, Socket } from 'socket.io-client';
import { CartesianGrid, Line, LineChart, ResponsiveContainer, XAxis, YAxis } from 'recharts';
import {
  ArrowUpRight,
  Car,
  CheckCircle2,
  Circle,
  CircleDollarSign,
  Database,
  Flame,
  LocateFixed,
  MapPin,
  Minus,
  Plus,
  Radio,
  Server,
  Star,
  Users,
  Zap,
} from 'lucide-react';
import { apiFetch, getSocketBaseUrl } from '@/lib/api';
import { useMapApiKey } from '@/hooks/use-map-api-key';
import { LiveMap, type LiveMapHandle } from '@/components/live-map';
import { StatWave } from '@/components/ui/sparkline';
import { Skeleton } from '@/components/ui/skeleton';
import { cn, formatCurrency } from '@/lib/utils';

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
  serviceCategory?: { name: string } | null;
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
}

interface Kpis {
  totalJobs: number;
  activeJobs: number;
  completedToday: number;
  onlineProviders: number;
  revenueToday: number;
  trends?: { completedToday: number; revenueToday: number; totalJobs: number };
}

interface Charts {
  jobsByDay: { date: string; jobs: number; revenue: number }[];
  statusBreakdown: Record<string, number>;
}

interface TopProvider {
  id: string;
  name: string;
  jobs: number;
  rating: number;
}

interface HealthService {
  name: string;
  status: 'operational' | 'degraded' | 'down';
}

interface ActivityItem {
  id: string;
  type: 'customer' | 'job' | 'payout' | 'alert' | 'admin';
  message: string;
  timestamp: string;
  href?: string;
}

type RangeKey = 'live' | 'today' | 'week' | 'month';
type MapFilter = 'all' | 'drivers' | 'riders' | 'heatmap';

const RANGES: { key: RangeKey; label: string }[] = [
  { key: 'live', label: 'Live' },
  { key: 'today', label: 'Today' },
  { key: 'week', label: 'This Week' },
  { key: 'month', label: 'This Month' },
];

const FILTERS: { key: MapFilter; label: string; icon: typeof Car }[] = [
  { key: 'all', label: 'All', icon: Circle },
  { key: 'drivers', label: 'Drivers', icon: Car },
  { key: 'riders', label: 'Riders', icon: Users },
  { key: 'heatmap', label: 'Heatmap', icon: Flame },
];

const HEALTH_ICONS: Record<string, typeof Zap> = {
  API: Zap,
  Database: Database,
  Redis: Server,
  'SMS (Twilio)': Radio,
};

function timeAgo(value: string) {
  const seconds = Math.max(0, (Date.now() - new Date(value).getTime()) / 1000);
  if (seconds < 60) return 'just now';
  const minutes = Math.floor(seconds / 60);
  if (minutes < 60) return `${minutes}m ago`;
  const hours = Math.floor(minutes / 60);
  if (hours < 24) return `${hours}h ago`;
  return `${Math.floor(hours / 24)}d ago`;
}

function fillDays(data: { date: string; jobs: number; revenue: number }[], days: number) {
  const map = new Map(data.map((item) => [item.date.slice(0, 10), item]));
  const start = new Date();
  start.setHours(12, 0, 0, 0);
  start.setDate(start.getDate() - (days - 1));
  return Array.from({ length: days }, (_, index) => {
    const day = new Date(start);
    day.setDate(start.getDate() + index);
    const key = day.toISOString().slice(0, 10);
    const found = map.get(key);
    return {
      date: key,
      label: day.toLocaleDateString('en-GB', { weekday: 'short' }),
      jobs: found?.jobs ?? 0,
      revenue: found?.revenue ?? 0,
    };
  });
}

function jobActivity(job: LiveJob) {
  const rider = job.customer?.user.fullName;
  const driver = job.provider?.user.fullName;
  if (job.status === 'searching') {
    return {
      title: 'New ride request',
      meta: [rider, job.serviceCategory?.name].filter(Boolean).join(' · ') || job.jobNumber,
      pill: 'New',
      tone: 'sky' as const,
      icon: Users,
    };
  }
  if (job.status === 'in_progress') {
    return {
      title: 'Trip in progress',
      meta: job.jobNumber,
      pill: 'On trip',
      tone: 'emerald' as const,
      icon: Car,
    };
  }
  return {
    title: 'Driver on the way',
    meta: [driver ?? rider, job.jobNumber].filter(Boolean).join(' · '),
    pill: 'En Route',
    tone: 'emerald' as const,
    icon: Car,
  };
}

export default function LiveOpsPage() {
  const router = useRouter();
  const [connected, setConnected] = useState(false);
  const [socketProviders, setSocketProviders] = useState<LiveProvider[]>([]);
  const [range, setRange] = useState<RangeKey>('live');
  const [mapFilter, setMapFilter] = useState<MapFilter>('all');
  const [selectedProviderId, setSelectedProviderId] = useState<string | null>(null);
  const socketRef = useRef<Socket | null>(null);
  const mapRef = useRef<LiveMapHandle>(null);
  const socketUrl = `${getSocketBaseUrl()}/tracking`;

  const { data: mapApiKey, isLoading: mapKeyLoading } = useMapApiKey();

  const { data, isLoading, error } = useQuery({
    queryKey: ['live-snapshot'],
    queryFn: async () => {
      const res = await apiFetch<LiveSnapshot>('/admin/dashboard/live');
      return res.data!;
    },
    refetchInterval: 30_000,
  });

  const { data: kpis } = useQuery({
    queryKey: ['dashboard-kpis'],
    queryFn: async () => {
      const res = await apiFetch<Kpis>('/admin/dashboard/kpis');
      return res.data!;
    },
  });

  const { data: charts } = useQuery({
    queryKey: ['dashboard-charts', 30],
    queryFn: async () => {
      const res = await apiFetch<Charts>('/admin/dashboard/charts?days=30');
      return res.data!;
    },
  });

  const { data: topProviders } = useQuery({
    queryKey: ['dashboard-top-providers'],
    queryFn: async () => {
      const res = await apiFetch<TopProvider[]>('/admin/dashboard/top-providers?limit=20');
      return res.data ?? [];
    },
  });

  const { data: health } = useQuery({
    queryKey: ['dashboard-health'],
    queryFn: async () => {
      const res = await apiFetch<{ services: HealthService[] }>('/admin/dashboard/health');
      return res.data!;
    },
    refetchInterval: 60_000,
  });

  const { data: activity } = useQuery({
    queryKey: ['dashboard-activity'],
    queryFn: async () => {
      const res = await apiFetch<ActivityItem[]>('/admin/dashboard/activity?limit=6');
      return res.data ?? [];
    },
    refetchInterval: 30_000,
  });

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
  const series = useMemo(() => fillDays(charts?.jobsByDay ?? [], range === 'month' ? 30 : 7), [charts, range]);
  const week = useMemo(() => fillDays(charts?.jobsByDay ?? [], 7), [charts]);

  const rangeJobs = series.reduce((sum, day) => sum + day.jobs, 0);
  const rangeRevenue = series.reduce((sum, day) => sum + day.revenue, 0);
  const activeDrivers = Math.max(providers.length, kpis?.onlineProviders ?? 0);
  const activeRides = range === 'live' ? activeJobs.length : range === 'today' ? (kpis?.completedToday ?? 0) : rangeJobs;
  const revenue = range === 'live' || range === 'today' ? (kpis?.revenueToday ?? 0) : rangeRevenue;
  const trackedBase = Math.max(kpis?.onlineProviders ?? 0, providers.length);
  const trackingPct = trackedBase === 0 ? 0 : Math.round((providers.length / trackedBase) * 100);

  const rated = (topProviders ?? []).filter((provider) => provider.rating > 0);
  const avgRating = rated.length ? rated.reduce((sum, provider) => sum + provider.rating, 0) / rated.length : 0;
  const breakdown = charts?.statusBreakdown ?? {};
  const breakdownTotal = Object.values(breakdown).reduce((sum, count) => sum + count, 0);
  const completion = breakdownTotal === 0 ? 0 : Math.round(((breakdown.completed ?? 0) / breakdownTotal) * 100);

  const services = (health?.services ?? []).filter((service) => service.name !== 'Live Tracking');
  const allOperational = services.length > 0 && services.every((service) => service.status === 'operational');

  const mapMarkers =
    mapFilter === 'riders'
      ? []
      : providers.map((provider) => ({
          id: provider.providerId,
          lat: provider.lat,
          lng: provider.lng,
          title: provider.fullName ?? 'Driver',
          label: '',
          heading: provider.heading,
        }));

  const liveRows = activeJobs.slice(0, 5).map((job) => ({ id: job.id, href: `/jobs/${job.id}`, ago: connected ? 'live' : '', ...jobActivity(job) }));

  return (
    <div className="flex-1 overflow-y-auto px-5 py-4 lg:px-6">
      <div className="flex flex-wrap items-center justify-between gap-4">
        <div className="flex items-center gap-3">
          <span className="grid size-11 place-items-center rounded-full bg-chart-1/15 text-chart-1">
            <MapPin className="size-5" strokeWidth={1.75} />
          </span>
          <div>
            <h1 className="text-[1.65rem] font-bold leading-none tracking-[-0.04em] text-primary">Live Map</h1>
            <p className="mt-1.5 text-sm text-muted">Real-time driver tracking and active rides</p>
          </div>
        </div>
        <div className="flex items-center gap-1 rounded-full border border-hairline bg-sheet p-1">
          {RANGES.map((item) => (
            <button
              key={item.key}
              type="button"
              onClick={() => setRange(item.key)}
              className={cn(
                'h-8 rounded-full px-3 text-sm font-medium transition-colors',
                range === item.key ? 'bg-nav-active text-white' : 'text-muted hover:text-primary',
              )}
            >
              {item.label}
            </button>
          ))}
        </div>
      </div>

      <div className="mt-4 grid grid-cols-1 gap-4 sm:grid-cols-2 xl:grid-cols-4">
        <LiveStat label="Active Drivers" value={activeDrivers} tone="emerald" icon={Car} delta={kpis?.trends?.totalJobs} />
        <LiveStat label={range === 'live' ? 'Active Rides' : 'Trips'} value={activeRides} tone="sky" icon={MapPin} delta={kpis?.trends?.completedToday} />
        <LiveStat label={range === 'month' || range === 'week' ? 'Revenue' : "Today's Revenue"} value={formatCurrency(revenue)} tone="violet" icon={CircleDollarSign} delta={kpis?.trends?.revenueToday} />
        <LiveStat label="Live Tracking" value={`${trackingPct}%`} tone="amber" icon={CheckCircle2} />
      </div>

      <div className="mt-4 grid grid-cols-1 gap-4 xl:grid-cols-12">
        <section className="panel-card relative h-[520px] overflow-hidden p-0 xl:col-span-8">
          {mapKeyLoading || isLoading ? (
            <Skeleton className="h-full w-full rounded-none" />
          ) : mapApiKey ? (
            <LiveMap
              ref={mapRef}
              apiKey={mapApiKey}
              markers={mapMarkers}
              activeId={selectedProviderId}
              showZoomControl={false}
              className="h-full min-h-0 rounded-none"
              onMarkerClick={(id) => {
                setSelectedProviderId(id);
                mapRef.current?.focusOn(id);
              }}
            />
          ) : (
            <div className="flex h-full flex-col items-center justify-center px-6 text-center">
              <MapPin className="mb-3 size-8 text-chart-1" />
              <p className="text-sm font-medium text-primary">No map API key configured</p>
              <p className="mt-1 max-w-xs text-xs text-muted">Add a Google Maps key in Settings to show the live map.</p>
            </div>
          )}

          <div className="absolute left-3 top-3 flex items-center gap-1 rounded-full border border-hairline bg-sheet p-1 shadow-sm">
            {FILTERS.map((item) => {
              const Icon = item.icon;
              const active = mapFilter === item.key;
              return (
                <button
                  key={item.key}
                  type="button"
                  onClick={() => setMapFilter(item.key)}
                  className={cn(
                    'inline-flex h-8 items-center gap-1.5 rounded-full px-3 text-xs font-medium',
                    active ? 'bg-nav-active text-white' : 'text-muted hover:text-primary',
                  )}
                >
                  <Icon className="size-3.5" strokeWidth={1.75} />
                  {item.label}
                </button>
              );
            })}
          </div>
          <div className="absolute right-3 top-3 inline-flex items-center gap-2 rounded-full border border-hairline bg-sheet px-3 py-1.5 text-xs font-medium text-primary">
            <span className={cn('size-2 rounded-full', connected ? 'bg-nav-active' : 'bg-danger')} />
            {connected ? 'Live' : 'Offline'} · {providers.length} online
          </div>
          {mapFilter === 'riders' ? (
            <p className="absolute bottom-4 left-4 rounded-full bg-sheet px-3 py-1 text-xs text-muted">Rider locations are not shared on the live map.</p>
          ) : null}
          {mapApiKey ? (
            <div className="absolute bottom-4 right-4 flex flex-col gap-2">
              <button type="button" aria-label="Zoom in" onClick={() => mapRef.current?.zoomBy(1)} className="grid size-9 place-items-center rounded-xl border border-hairline bg-sheet text-primary">
                <Plus className="size-4" />
              </button>
              <button type="button" aria-label="Zoom out" onClick={() => mapRef.current?.zoomBy(-1)} className="grid size-9 place-items-center rounded-xl border border-hairline bg-sheet text-primary">
                <Minus className="size-4" />
              </button>
              <button type="button" aria-label="Fit drivers" onClick={() => mapRef.current?.fitAll()} className="grid size-9 place-items-center rounded-xl border border-hairline bg-sheet text-primary">
                <LocateFixed className="size-4" />
              </button>
            </div>
          ) : null}
          {error ? <p className="absolute bottom-4 left-4 text-sm text-danger">Failed to load live snapshot</p> : null}
        </section>

        <section className="panel-card flex h-[520px] flex-col p-4 xl:col-span-4">
          <div className="flex items-center justify-between">
            <h2 className="inline-flex items-center gap-2 text-sm font-semibold text-primary">
              <span className="grid size-8 place-items-center rounded-lg bg-chart-1/15 text-chart-1">
                <Radio className="size-4" strokeWidth={1.75} />
              </span>
              Live Activity
            </h2>
            <button type="button" onClick={() => router.push('/jobs')} className="inline-flex items-center gap-1 text-xs font-medium text-chart-1">
              View all <ArrowUpRight className="size-3.5" />
            </button>
          </div>
          <ul className="mt-4 flex-1 space-y-3 overflow-y-auto">
            {liveRows.length === 0 ? (
              <li className="text-sm text-muted">No active rides right now.</li>
            ) : (
              liveRows.map((row) => {
                const Icon = row.icon;
                return (
                  <li key={row.id}>
                    <button type="button" onClick={() => router.push(row.href)} className="flex w-full items-start gap-3 text-left">
                      <span className={cn('grid size-9 shrink-0 place-items-center rounded-full', row.tone === 'sky' ? 'bg-chart-2/15 text-chart-2' : 'bg-chart-1/15 text-chart-1')}>
                        <Icon className="size-4" strokeWidth={1.75} />
                      </span>
                      <span className="min-w-0 flex-1">
                        <span className="block truncate text-sm font-medium text-primary">{row.title}</span>
                        <span className="block truncate text-xs text-muted">{row.meta}</span>
                      </span>
                      <span className={cn('rounded-full px-2 py-0.5 text-[11px] font-medium', row.tone === 'sky' ? 'bg-chart-2/15 text-chart-2' : 'bg-chart-1/15 text-chart-1')}>
                        {row.pill}
                      </span>
                    </button>
                  </li>
                );
              })
            )}
          </ul>
        </section>
      </div>

      <div className="mt-4 grid grid-cols-1 gap-4 lg:grid-cols-3">
        <section className="panel-card p-4">
          <div className="flex items-center justify-between">
            <h2 className="text-sm font-semibold text-primary">Driver Performance</h2>
            <span className="text-xs text-muted">Last 7 days</span>
          </div>
          <div className="mt-4 grid grid-cols-3 gap-2">
            <Metric value={avgRating.toFixed(1)} label="Avg Rating" icon={<Star className="size-3.5 fill-chart-3 text-chart-3" />} />
            <Metric value={kpis?.totalJobs ?? 0} label="Total Trips" />
            <Metric value={`${completion}%`} label="Completion Rate" />
          </div>
          <div className="mt-2 h-[140px]">
            <ResponsiveContainer width="100%" height="100%">
              <LineChart data={week} margin={{ top: 12, right: 8, left: -18, bottom: 0 }}>
                <CartesianGrid stroke="var(--hairline)" vertical={false} />
                <XAxis dataKey="label" tick={{ fill: 'var(--text-muted)', fontSize: 11 }} axisLine={false} tickLine={false} />
                <YAxis allowDecimals={false} tick={{ fill: 'var(--text-muted)', fontSize: 11 }} axisLine={false} tickLine={false} />
                <Line type="monotone" dataKey="jobs" stroke="var(--chart-1)" strokeWidth={2.5} dot={{ r: 3, fill: 'var(--chart-1)', strokeWidth: 0 }} />
              </LineChart>
            </ResponsiveContainer>
          </div>
        </section>

        <section className="panel-card p-4">
          <div className="flex items-center justify-between gap-2">
            <h2 className="text-sm font-semibold text-primary">System Health</h2>
            <span className={cn('rounded-full px-2 py-0.5 text-[11px] font-medium', allOperational ? 'bg-chart-1/15 text-chart-1' : 'bg-chart-3/15 text-chart-3')}>
              {allOperational ? 'All Systems Operational' : 'Needs attention'}
            </span>
          </div>
          <ul className="mt-5 grid grid-cols-4 gap-2">
            {(services.length ? services : ['API', 'Database', 'Redis', 'SMS (Twilio)'].map((name) => ({ name, status: 'operational' as const }))).map((service) => {
              const Icon = HEALTH_ICONS[service.name] ?? Radio;
              const ok = service.status === 'operational';
              return (
                <li key={service.name} className="text-center">
                  <span className={cn('mx-auto grid size-12 place-items-center rounded-full', ok ? 'bg-chart-1/15 text-chart-1' : 'bg-chart-3/15 text-chart-3')}>
                    <Icon className="size-5" strokeWidth={1.75} />
                  </span>
                  <p className="mt-2 text-xs font-medium text-primary">{service.name.replace(' (Twilio)', '')}</p>
                  <p className={cn('text-[11px] capitalize', ok ? 'text-chart-1' : 'text-chart-3')}>{service.status}</p>
                </li>
              );
            })}
          </ul>
        </section>

        <section className="panel-card p-4">
          <div className="flex items-center justify-between">
            <h2 className="text-sm font-semibold text-primary">Recent Activity</h2>
            <button type="button" onClick={() => router.push('/audit')} className="inline-flex items-center gap-1 text-xs font-medium text-chart-1">
              View all <ArrowUpRight className="size-3.5" />
            </button>
          </div>
          <ul className="mt-4 space-y-3">
            {(activity ?? []).slice(0, 5).map((item) => (
              <li key={item.id} className="flex items-start gap-3">
                <span className={cn('mt-1.5 size-2 shrink-0 rounded-full', item.type === 'alert' ? 'bg-chart-3' : item.type === 'payout' ? 'bg-chart-2' : 'bg-chart-1')} />
                <div className="min-w-0">
                  <p className="truncate text-sm text-primary">{item.message}</p>
                  <p className="text-xs text-muted">{timeAgo(item.timestamp)}</p>
                </div>
              </li>
            ))}
            {(activity ?? []).length === 0 ? <li className="text-sm text-muted">No recent activity.</li> : null}
          </ul>
        </section>
      </div>
    </div>
  );
}

function Metric({ value, label, icon }: { value: string | number; label: string; icon?: ReactNode }) {
  return (
    <div>
      <p className="num inline-flex items-center gap-1 text-xl font-bold tracking-tight text-primary">
        {value}
        {icon}
      </p>
      <p className="text-[11px] text-muted">{label}</p>
    </div>
  );
}

function LiveStat({
  label,
  value,
  tone,
  icon: Icon,
  delta,
}: {
  label: string;
  value: string | number;
  tone: 'emerald' | 'sky' | 'violet' | 'amber';
  icon: typeof Car;
  delta?: number | null;
}) {
  const tones = {
    emerald: { wash: 'stat-wash-emerald', ink: 'text-chart-1', wave: 'var(--chart-1)', variant: 0 },
    sky: { wash: 'stat-wash-sky', ink: 'text-chart-2', wave: 'var(--chart-2)', variant: 1 },
    violet: { wash: 'stat-wash-violet', ink: 'text-chart-4', wave: 'var(--chart-4)', variant: 2 },
    amber: { wash: 'stat-wash-amber', ink: 'text-chart-3', wave: 'var(--chart-3)', variant: 0 },
  }[tone];
  const up = (delta ?? 0) > 0;
  return (
    <div className={cn('relative h-[118px] overflow-hidden rounded-[18px] border border-white/70 p-4', tones.wash)}>
      <div className="relative z-10 flex items-start justify-between gap-3">
        <div className="flex items-center gap-3">
          <span className={cn('grid size-10 place-items-center rounded-full bg-white/85', tones.ink)}>
            <Icon className="size-[18px]" strokeWidth={1.75} />
          </span>
          <div>
            <p className="num text-[26px] font-bold leading-none tracking-tight text-primary">{value}</p>
            <p className="mt-1 text-xs text-muted">{label}</p>
          </div>
        </div>
        {delta ? (
          <span className={cn('inline-flex items-center gap-0.5 text-xs font-semibold', up ? 'text-chart-1' : 'text-chart-5')}>
            <ArrowUpRight className={cn('size-3.5', !up && 'rotate-90')} />
            {Math.abs(delta)}%
          </span>
        ) : null}
      </div>
      <div className={cn('pointer-events-none absolute inset-x-0 bottom-0 h-12', tones.ink)}>
        <StatWave color={tones.wave} variant={tones.variant} />
      </div>
    </div>
  );
}
