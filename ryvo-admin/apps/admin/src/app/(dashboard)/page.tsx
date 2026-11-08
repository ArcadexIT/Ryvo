'use client';

import { useState } from 'react';
import Link from 'next/link';
import { useQuery } from '@tanstack/react-query';
import { DateRangePicker, dateRangeToDays, type DateRange } from '@/components/ui/date-range-picker';
import { SystemHealth } from '@/components/dashboard/system-health';
import { ActivityFeed } from '@/components/dashboard/activity-feed';
import { DriverPerformance } from '@/components/dashboard/driver-performance';
import { JobStatusCard } from '@/components/dashboard/job-status-card';
import { RevenueChart } from '@/components/charts/revenue-chart';
import { Sparkline } from '@/components/ui/sparkline';
import { Stat } from '@/components/ui/stat';
import { Skeleton } from '@/components/ui/skeleton';
import { apiFetch, buildQuery } from '@/lib/api';
import { useAuth } from '@/contexts/auth-context';
import { hasPermission } from '@/lib/permissions';
import { formatCurrency } from '@/lib/utils';

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

export default function DashboardPage() {
  const { permissions } = useAuth();
  const canFinance = hasPermission(permissions, 'finance');
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

  const { data: kycCount } = useQuery({
    queryKey: ['kyc-pending-count'],
    queryFn: async () => {
      const res = await apiFetch<{ summary?: { documents: number } }>(
        `/admin/providers/kyc/pending${buildQuery({ page: 1, limit: 1 })}`,
      );
      return res.data?.summary?.documents ?? res.meta?.total ?? 0;
    },
  });

  const { data: payoutSummary } = useQuery({
    queryKey: ['finance-payouts-summary'],
    queryFn: async () => {
      const res = await apiFetch<{ pending: { count: number; amount: number } }>(
        '/admin/finance/payouts/summary',
      );
      return res.data?.pending ?? { count: 0, amount: 0 };
    },
    enabled: canFinance,
  });

  const online = kpis?.onlineProviders ?? 0;
  const busy = kpis?.busyProviders ?? 0;
  const offline = Math.max(0, (kpis?.totalProviders ?? 0) - online - busy);
  const spark = charts?.jobsByDay?.map((day) => day.jobs) ?? [];

  return (
    <div className="flex-1 overflow-y-auto px-5 py-5 lg:px-6">
      <div className="flex flex-wrap items-start justify-between gap-4">
        <div>
          <h1 className="page-title">Overview</h1>
          <p className="mt-1 text-sm text-muted">Platform activity for the selected period.</p>
        </div>
        <DateRangePicker value={dateRange} onChange={setDateRange} />
      </div>

      {kpisError ? <p className="mt-4 text-sm text-danger">Failed to load KPIs</p> : null}

      <div className="mt-5 grid grid-cols-1 gap-3 sm:grid-cols-2 xl:grid-cols-4">
        {kpisLoading ? (
          Array.from({ length: 4 }).map((_, index) => <Skeleton key={index} className="h-32 rounded-lg" />)
        ) : (
          <>
            <Stat
              label="Active trips"
              value={kpis?.activeJobs ?? 0}
              delta={kpis?.trends?.activeJobs}
              href="/dispatch"
              spark={spark.length > 1 ? <Sparkline data={spark} color="currentColor" height={32} /> : null}
            />
            <Stat
              label="Revenue today"
              value={formatCurrency(kpis?.revenueToday ?? 0)}
              delta={kpis?.trends?.revenueToday}
              href="/finance/earnings"
            />
            <Stat label="Online drivers" value={online} href="/providers" />
            <Stat label="Pending KYC" value={kycCount ?? 0} href="/providers/kyc" />
          </>
        )}
      </div>

      <div className="mt-3 grid grid-cols-1 gap-3 xl:grid-cols-12">
        <section className="rounded-lg border border-hairline bg-card p-4 xl:col-span-8">
          <div className="mb-2 flex items-center justify-between gap-3">
            <div>
              <h2 className="text-sm font-semibold text-primary">Trips and revenue</h2>
              <p className="text-xs text-muted">Last {days} days</p>
            </div>
            <div className="flex items-center gap-3 text-xs text-muted">
              <span className="inline-flex items-center gap-1.5">
                <span className="size-1.5 rounded-full bg-success" /> Revenue
              </span>
              <span className="inline-flex items-center gap-1.5">
                <span className="size-1.5 rounded-full bg-muted" /> Trips
              </span>
            </div>
          </div>
          {chartsLoading ? (
            <Skeleton className="h-[250px] w-full" />
          ) : chartsError ? (
            <p className="flex h-[250px] items-center justify-center text-sm text-danger">Failed to load charts</p>
          ) : (
            <RevenueChart data={charts?.jobsByDay ?? []} days={days} />
          )}
        </section>

        <section className="rounded-lg border border-hairline bg-card p-4 xl:col-span-4">
          <h2 className="text-sm font-semibold text-primary">Needs attention</h2>
          <ul className="mt-4 divide-y divide-hairline">
            <AttentionRow href="/providers/kyc" label="KYC queue" value={kycCount ?? 0} />
            {canFinance ? (
              <AttentionRow
                href="/finance/payouts"
                label="Payouts awaiting confirmation"
                value={payoutSummary?.count ?? 0}
              />
            ) : null}
            <AttentionRow href="/dispatch" label="Active trips" value={kpis?.activeJobs ?? 0} />
          </ul>
        </section>
      </div>

      <div className="mt-3 grid grid-cols-1 gap-3 lg:grid-cols-3">
        <DriverPerformance online={online} offline={offline} onBreak={busy} />
        <SystemHealth />
        <ActivityFeed />
        <JobStatusCard breakdown={charts?.statusBreakdown ?? {}} />
      </div>
    </div>
  );
}

function AttentionRow({ href, label, value }: { href: string; label: string; value: number }) {
  return (
    <li>
      <Link href={href} className="flex items-center justify-between py-3 text-sm hover:text-primary">
        <span className="text-muted">{label}</span>
        <span className="num font-medium text-primary">{value}</span>
      </Link>
    </li>
  );
}
