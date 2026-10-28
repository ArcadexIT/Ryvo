'use client';

import { useState } from 'react';
import Link from 'next/link';
import { useQuery } from '@tanstack/react-query';
import { Activity, BarChart3, CheckCircle, ChevronRight } from 'lucide-react';
import { DateRangePicker, dateRangeToDays, type DateRange } from '@/components/ui/date-range-picker';
import { SystemHealth } from '@/components/dashboard/system-health';
import { ActivityFeed } from '@/components/dashboard/activity-feed';
import { DriverPerformance } from '@/components/dashboard/driver-performance';
import { RevenueOverview } from '@/components/dashboard/revenue-overview';
import { JobStatusCard } from '@/components/dashboard/job-status-card';
import { RevenueChart } from '@/components/charts/revenue-chart';
import { Sparkline, seededSparklineData } from '@/components/ui/sparkline';
import { apiFetch } from '@/lib/api';
import { useAuth } from '@/contexts/auth-context';
import { cn } from '@/lib/utils';

interface Kpis {
  totalJobs: number;
  activeJobs: number;
  completedToday: number;
  totalProviders: number;
  onlineProviders: number;
  busyProviders?: number;
  revenueToday: number;
  trends?: {
    totalJobs: number;
    activeJobs: number;
    completedToday: number;
    revenueToday: number;
  };
}

interface Charts {
  jobsByDay: { date: string; jobs: number; revenue: number }[];
  statusBreakdown: Record<string, number>;
}

const KPI_TONES = [
  { key: 'totalJobs', label: 'Total Rides', href: '/jobs', icon: BarChart3, wash: 'bg-[#eefbf3]', ink: 'text-[#1fa855]', spark: '#1fa855' },
  { key: 'activeJobs', label: 'Active Rides', href: '/dispatch', icon: Activity, wash: 'bg-[#fff6ee]', ink: 'text-[#f59e0b]', spark: '#fb923c' },
  { key: 'completedToday', label: 'Completed Today', href: '/jobs', icon: CheckCircle, wash: 'bg-[#f6f3ff]', ink: 'text-[#8b5cf6]', spark: '#a78bfa' },
] as const;

function greeting(name: string) {
  const hour = new Date().getHours();
  const part = hour < 12 ? 'Good morning' : hour < 17 ? 'Good afternoon' : 'Good evening';
  return `${part}, ${name}`;
}

export default function DashboardPage() {
  const { user } = useAuth();
  const [dateRange, setDateRange] = useState<DateRange>('7d');
  const days = dateRangeToDays(dateRange);

  const { data: kpis, isLoading: kpisLoading, error: kpisError } = useQuery({
    queryKey: ['dashboard-kpis'],
    queryFn: async () => {
      const res = await apiFetch<Kpis>('/admin/dashboard/kpis');
      return res.data!;
    },
  });

  const { data: charts, isLoading: chartsLoading, error: chartsError } = useQuery({
    queryKey: ['dashboard-charts', days],
    queryFn: async () => {
      const res = await apiFetch<Charts>(`/admin/dashboard/charts?days=${days}`);
      return res.data!;
    },
  });

  const online = kpis?.onlineProviders ?? 0;
  const busy = kpis?.busyProviders ?? 0;
  const offline = Math.max(0, (kpis?.totalProviders ?? 0) - online - busy);
  const rangeLabel = days === 7 ? 'last 7 days' : `last ${days} days`;

  return (
    <div className="relative flex-1 overflow-y-auto bg-[#f4f7fb] px-5 py-5 lg:px-6">
      <svg
        aria-hidden
        viewBox="0 0 360 220"
        className="pointer-events-none absolute right-10 top-0 hidden h-52 w-80 text-emerald-200/80 lg:block"
      >
        <path d="M250 20c30 18 48 48 42 78-8 38-52 42-78 28" fill="none" stroke="currentColor" strokeWidth="10" strokeLinecap="round" />
        <path d="M210 48c22 8 40 28 36 48" fill="none" stroke="currentColor" strokeWidth="8" strokeLinecap="round" />
        <ellipse cx="286" cy="54" rx="28" ry="14" transform="rotate(-30 286 54)" fill="currentColor" opacity="0.55" />
        <ellipse cx="248" cy="86" rx="22" ry="11" transform="rotate(20 248 86)" fill="currentColor" opacity="0.4" />
      </svg>

      <div className="relative grid grid-cols-1 gap-4 xl:grid-cols-4">
        <div className="xl:col-span-3">
          <h1 className="text-[1.65rem] font-semibold tracking-tight text-[#0f172a]">
            {greeting(user?.fullName ?? 'Super Admin')} <span aria-hidden>👋</span>
          </h1>
          <p className="mt-1 text-sm text-[#64748b]">Here&apos;s what&apos;s happening with your platform today.</p>
        </div>
        <div className="flex items-start xl:justify-end">
          <DateRangePicker value={dateRange} onChange={setDateRange} />
        </div>

        {kpisError && <p className="text-sm text-danger xl:col-span-4">Failed to load KPIs</p>}

        {KPI_TONES.map((tone, index) => {
          const Icon = tone.icon;
          const value = kpis ? kpis[tone.key] : 0;
          const trend = kpis?.trends?.[tone.key] ?? 0;
          const spark = charts?.jobsByDay?.map((day) => day.jobs) ?? seededSparklineData(index, trend);
          return (
            <Link
              key={tone.key}
              href={tone.href}
              className={cn('rounded-2xl p-4 shadow-sm transition-transform hover:-translate-y-0.5', tone.wash)}
            >
              <div className="flex items-center justify-between">
                <span className="flex items-center gap-2 text-sm font-medium text-[#334155]">
                  <span className={cn('grid h-7 w-7 place-items-center rounded-full bg-white', tone.ink)}>
                    <Icon className="h-3.5 w-3.5" />
                  </span>
                  {tone.label}
                </span>
                <ChevronRight className="h-4 w-4 text-[#94a3b8]" />
              </div>
              <p className="mt-3 text-3xl font-semibold tracking-tight text-[#0f172a]">
                {kpisLoading ? '—' : value}
              </p>
              <p className={cn('mt-1 text-xs font-medium', trend < 0 ? 'text-danger' : tone.ink)}>
                {trend < 0 ? '' : ''}
                {Math.abs(trend)}% vs {rangeLabel}
              </p>
              <Sparkline data={spark.length > 1 ? spark : [0, 0]} color={tone.spark} height={36} className="mt-2 h-9 w-full" />
            </Link>
          );
        })}

        <SystemHealth />

        <section className="rounded-2xl border border-border bg-white p-4 shadow-sm xl:col-span-3">
          <div className="mb-2 flex items-start justify-between gap-3">
            <div className="flex items-center gap-2">
              <span className="grid h-8 w-8 place-items-center rounded-lg bg-[#eefbf3] text-[#1fa855]">
                <BarChart3 className="h-4 w-4" />
              </span>
              <div>
                <h2 className="text-sm font-semibold text-primary">Rides & Revenue</h2>
                <p className="text-[11px] text-muted">Last {days} days</p>
              </div>
            </div>
            <div className="flex items-center gap-3 text-xs text-secondary">
              <span className="inline-flex items-center gap-1.5"><span className="h-2 w-2 rounded-full bg-[#1fa855]" /> Revenue</span>
              <span className="inline-flex items-center gap-1.5"><span className="h-2 w-2 rounded-full bg-[#8b5cf6]" /> Jobs</span>
            </div>
          </div>
          {chartsLoading ? (
            <div className="flex h-[250px] items-center justify-center text-sm text-muted">Loading charts...</div>
          ) : chartsError ? (
            <div className="flex h-[250px] items-center justify-center text-sm text-danger">Failed to load charts</div>
          ) : (
            <RevenueChart data={charts?.jobsByDay ?? []} days={days} />
          )}
        </section>

        <div className="h-full xl:row-span-2">
          <ActivityFeed />
        </div>

        <DriverPerformance online={online} offline={offline} onBreak={busy} />
        <RevenueOverview
          total={charts?.jobsByDay.reduce((sum, day) => sum + day.revenue, 0) ?? kpis?.revenueToday ?? 0}
          trend={kpis?.trends?.revenueToday ?? 0}
          series={charts?.jobsByDay ?? []}
        />
        <JobStatusCard breakdown={charts?.statusBreakdown ?? {}} />
      </div>
    </div>
  );
}
