'use client';

import { useState } from 'react';
import Link from 'next/link';
import { useQuery } from '@tanstack/react-query';
import {
  AlertCircle,
  ArrowUpRight,
  Ban,
  BarChart3,
  Car,
  CircleCheck,
  CreditCard,
  FileText,
  Navigation,
  TrendingUp,
  Users,
  Wallet,
} from 'lucide-react';
import { Header } from '@/components/layout/header';
import { DateRangePicker, dateRangeToDays, type DateRange } from '@/components/ui/date-range-picker';
import { SystemHealth } from '@/components/dashboard/system-health';
import { ActivityFeed } from '@/components/dashboard/activity-feed';
import { DriverPerformance } from '@/components/dashboard/driver-performance';
import { RevenueChart } from '@/components/charts/revenue-chart';
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
  const [dateRange, setDateRange] = useState<DateRange>('30d');
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
  return (
    <>
    <Header
      title="Overview"
      description="Platform activity for the selected period."
      breadcrumb={false}
      actions={<DateRangePicker value={dateRange} onChange={setDateRange} />}
    />
    <div className="flex-1 overflow-y-auto px-5 pb-6 lg:px-6">
      {kpisError ? <p className="text-sm text-danger">Failed to load KPIs</p> : null}

      <div className="mt-4 grid grid-cols-1 gap-4 sm:grid-cols-2 xl:grid-cols-3">
        {kpisLoading ? (
          Array.from({ length: 6 }).map((_, index) => <Skeleton key={index} className="h-[138px] rounded-[18px]" />)
        ) : (
          <>
            <Stat label="Active trips" value={kpis?.activeJobs ?? 0} href="/dispatch" tone="emerald" icon={Car} mark={TrendingUp} />
            <Stat label="Revenue today" value={formatCurrency(kpis?.revenueToday ?? 0)} href="/finance/earnings" tone="sky" icon={CreditCard} mark={TrendingUp} />
            <Stat label="Completed today" value={kpis?.completedToday ?? 0} href="/jobs" tone="violet" icon={CircleCheck} mark={TrendingUp} />
            <Stat label="All trips" value={kpis?.totalJobs ?? 0} href="/jobs" tone="amber" icon={Navigation} mark={BarChart3} />
            <Stat label="Online drivers" value={online} href="/providers" tone="teal" icon={Users} mark={Users} />
            <Stat label="Pending KYC" value={kycCount ?? 0} href="/providers/kyc" tone="rose" icon={Ban} mark={AlertCircle} />
          </>
        )}
      </div>

      <div className="mt-4 grid grid-cols-1 gap-4 xl:grid-cols-12">
        <section className="panel-card p-4 xl:col-span-8">
          <div className="mb-2 flex items-center justify-between gap-3">
            <div className="flex items-center gap-2">
              <span className="grid size-8 place-items-center rounded-lg bg-chart-1/15 text-chart-1">
                <BarChart3 className="size-4" strokeWidth={1.75} />
              </span>
              <div>
                <h2 className="text-sm font-semibold text-primary">Trips and revenue</h2>
                <p className="text-xs text-muted">Last {days} days</p>
              </div>
            </div>
            <div className="flex items-center gap-3 text-xs text-muted">
              <span className="inline-flex items-center gap-1.5">
                <span className="size-2 rounded-full bg-chart-2" /> Trips
              </span>
              <span className="inline-flex items-center gap-1.5">
                <span className="size-2 rounded-full bg-chart-1" /> Revenue
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

        <section className="panel-card p-4 xl:col-span-4">
          <div className="flex items-center justify-between gap-3">
            <h2 className="inline-flex items-center gap-2 text-sm font-semibold text-primary">
              <span className="grid size-8 place-items-center rounded-lg bg-chart-3/15 text-chart-3">
                <AlertCircle className="size-4" strokeWidth={1.75} />
              </span>
              Needs attention
            </h2>
            <Link href="/dispatch" className="inline-flex items-center gap-1 text-xs font-medium text-chart-1 hover:underline">
              View all <ArrowUpRight className="size-3.5" strokeWidth={1.75} />
            </Link>
          </div>
          <ul className="mt-4 space-y-2">
            <AttentionRow href="/providers/kyc" label="KYC queue" value={kycCount ?? 0} icon={FileText} />
            {canFinance ? (
              <AttentionRow href="/finance/payouts" label="Payouts awaiting confirmation" value={payoutSummary?.count ?? 0} icon={Wallet} />
            ) : null}
            <AttentionRow href="/dispatch" label="Active trips" value={kpis?.activeJobs ?? 0} icon={Car} />
          </ul>
        </section>
      </div>

      <div className="mt-4 grid grid-cols-1 gap-4 lg:grid-cols-3">
        <DriverPerformance online={online} offline={offline} onBreak={busy} />
        <SystemHealth />
        <ActivityFeed />
      </div>
    </div>
    </>
  );
}

function AttentionRow({
  href,
  label,
  value,
  icon: Icon,
}: {
  href: string;
  label: string;
  value: number;
  icon: typeof Car;
}) {
  return (
    <li>
      <Link href={href} className="flex items-center gap-3 rounded-xl bg-canvas px-3 py-2.5 transition-colors hover:bg-input">
        <span className="grid size-8 place-items-center rounded-lg bg-sheet text-muted shadow-sm">
          <Icon className="size-4" strokeWidth={1.75} />
        </span>
        <span className="min-w-0 flex-1 truncate text-sm text-primary">{label}</span>
        <span className="num grid size-7 place-items-center rounded-full bg-sheet text-xs font-semibold text-primary">{value}</span>
      </Link>
    </li>
  );
}
