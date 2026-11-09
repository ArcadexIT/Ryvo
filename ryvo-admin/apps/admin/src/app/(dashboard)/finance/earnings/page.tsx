'use client';

import { useCallback, useState } from 'react';
import Link from 'next/link';
import { useQuery } from '@tanstack/react-query';
import { Header } from '@/components/layout/header';
import { PageContent } from '@/components/layout/page-content';
import { DataTable, type Column } from '@/components/data-table';
import { StatusBadge } from '@/components/ui/badge';
import { Modal } from '@/components/ui/modal';
import { ServerExportButton } from '@/components/ui/server-export-button';
import { apiFetch, buildQuery } from '@/lib/api';
import { cn, formatCurrency, formatDate } from '@/lib/utils';

interface Earning {
  id: string;
  grossAmount: number;
  platformFee: number;
  netAmount: number;
  payoutStatus: string;
  payoutId?: string | null;
  createdAt: string;
  provider?: { id: string; user: { fullName: string; phone?: string | null } };
  job?: {
    jobNumber: string;
    pickupAddress?: string;
    dropoffAddress?: string | null;
    serviceCategory?: { name?: string } | null;
  } | null;
}

interface Provider {
  id: string;
  user: { fullName: string };
}

interface MoneySlice {
  count: number;
  gross: number;
  platformFee: number;
  net: number;
}

interface EarningsSummary {
  all: MoneySlice;
  pending: MoneySlice;
  processing: MoneySlice;
  paid: MoneySlice;
  rejected: MoneySlice;
}

type StatusFilter = 'all' | 'pending' | 'processing' | 'paid' | 'rejected';
type PeriodFilter = 'all' | 'today' | '7d' | '30d' | '90d';

const emptySlice: MoneySlice = { count: 0, gross: 0, platformFee: 0, net: 0 };

function periodStart(period: PeriodFilter) {
  if (period === 'all') return undefined;
  const start = new Date();
  start.setHours(0, 0, 0, 0);
  const days = period === 'today' ? 1 : period === '7d' ? 7 : period === '30d' ? 30 : 90;
  start.setDate(start.getDate() - (days - 1));
  return start.toISOString();
}

function feeShare(earning: Earning) {
  const gross = Number(earning.grossAmount);
  if (gross <= 0) return null;
  return Math.round((Number(earning.platformFee) / gross) * 1000) / 10;
}

export default function EarningsPage() {
  const [page, setPage] = useState(1);
  const [providerFilter, setProviderFilter] = useState('all');
  const [status, setStatus] = useState<StatusFilter>('all');
  const [period, setPeriod] = useState<PeriodFilter>('all');
  const [search, setSearch] = useState('');
  const [selected, setSelected] = useState<Earning | null>(null);
  const onSearchChange = useCallback((value: string) => {
    setSearch(value);
    setPage(1);
  }, []);

  const from = periodStart(period);
  const providerId = providerFilter === 'all' ? undefined : providerFilter;
  const scope = { providerId, search: search.trim() || undefined, from };

  const { data: providers } = useQuery({
    queryKey: ['providers-filter'],
    queryFn: async () => (await apiFetch<Provider[]>('/admin/providers?limit=100')).data ?? [],
  });

  const summary = useQuery({
    queryKey: ['finance-earnings-summary', scope],
    queryFn: async () => (await apiFetch<EarningsSummary>(`/admin/finance/earnings/summary${buildQuery(scope)}`)).data,
  });

  const { data, isLoading, error } = useQuery({
    queryKey: ['finance-earnings', page, scope, status],
    queryFn: async () => {
      const res = await apiFetch<Earning[]>(
        `/admin/finance/earnings${buildQuery({ page, limit: 20, ...scope, status: status === 'all' ? undefined : status })}`,
      );
      return { items: res.data ?? [], meta: res.meta };
    },
  });

  const totals = summary.data ?? {
    all: emptySlice,
    pending: emptySlice,
    processing: emptySlice,
    paid: emptySlice,
    rejected: emptySlice,
  };
  const slice = status === 'all' ? totals.all : totals[status];

  const columns: Column<Earning>[] = [
    {
      key: 'provider',
      header: 'Driver',
      sortable: true,
      sortValue: (row) => row.provider?.user.fullName ?? '',
      render: (row) => (
        <span>
          <span className="block font-medium text-primary">{row.provider?.user.fullName ?? '—'}</span>
          <span className="block text-xs text-muted">{row.provider?.user.phone || 'No phone'}</span>
        </span>
      ),
    },
    {
      key: 'job',
      header: 'Trip',
      sortable: true,
      sortValue: (row) => row.job?.jobNumber ?? '',
      render: (row) => (
        <span>
          <span className="block text-primary">{row.job?.jobNumber ?? '—'}</span>
          <span className="block text-xs text-muted">{row.job?.serviceCategory?.name || 'Trip'}</span>
        </span>
      ),
    },
    {
      key: 'route',
      header: 'Route',
      render: (row) => (
        <span className="block max-w-[240px]">
          <span className="block truncate text-primary">{row.job?.pickupAddress || '—'}</span>
          <span className="block truncate text-xs text-muted">{row.job?.dropoffAddress || 'No dropoff'}</span>
        </span>
      ),
    },
    {
      key: 'gross',
      header: 'Gross',
      numeric: true,
      sortable: true,
      sortValue: (row) => Number(row.grossAmount),
      render: (row) => <span className="num">{formatCurrency(Number(row.grossAmount))}</span>,
    },
    {
      key: 'commission',
      header: 'Commission',
      numeric: true,
      sortable: true,
      sortValue: (row) => Number(row.platformFee),
      render: (row) => {
        const share = feeShare(row);
        return (
          <span className="num block text-muted">
            {formatCurrency(Number(row.platformFee))}
            {share != null ? <span className="ml-1 text-xs">{share}%</span> : null}
          </span>
        );
      },
    },
    {
      key: 'net',
      header: 'Net',
      numeric: true,
      sortable: true,
      sortValue: (row) => Number(row.netAmount),
      render: (row) => <span className="num font-medium text-primary">{formatCurrency(Number(row.netAmount))}</span>,
    },
    {
      key: 'status',
      header: 'Payout',
      sortable: true,
      sortValue: (row) => row.payoutStatus,
      render: (row) => <StatusBadge status={row.payoutStatus} />,
    },
    {
      key: 'date',
      header: 'Earned',
      sortable: true,
      sortValue: (row) => new Date(row.createdAt).getTime(),
      render: (row) => <span className="text-muted">{formatDate(row.createdAt)}</span>,
    },
  ];

  return (
    <>
      <Header
        title="Earnings"
        description="Driver gross, commission, and payout status for completed trips."
        actions={<ServerExportButton type="earnings" params={{ ...scope, status: status === 'all' ? undefined : status }} />}
      />
      <PageContent>
        <div className="mb-4 grid gap-4 sm:grid-cols-2 xl:grid-cols-4">
          <Summary label="Gross" value={formatCurrency(slice.gross)} hint={`${slice.count} earnings`} wash="stat-wash-sky" />
          <Summary label="Commission" value={formatCurrency(slice.platformFee)} hint="Platform fee" wash="stat-wash-violet" />
          <Summary label="Driver net" value={formatCurrency(slice.net)} hint="After commission" wash="stat-wash-emerald" />
          <Summary label="Records" value={slice.count} hint={period === 'all' ? 'All time' : periodLabel(period)} wash="stat-wash-amber" />
        </div>
        <div className="mb-4 grid gap-3 sm:grid-cols-2 xl:grid-cols-4">
          {(['pending', 'processing', 'paid', 'rejected'] as const).map((key) => (
            <button
              key={key}
              type="button"
              onClick={() => {
                setStatus((current) => (current === key ? 'all' : key));
                setPage(1);
              }}
              className={cn(
                'rounded-[18px] border px-4 py-3 text-left',
                key === 'paid' ? 'stat-wash-teal' : key === 'rejected' ? 'stat-wash-rose' : key === 'processing' ? 'stat-wash-sky' : 'stat-wash-amber',
                status === key ? 'border-primary' : 'border-white/70',
              )}
            >
              <p className="text-sm capitalize text-muted">{key}</p>
              <p className="num mt-1 text-lg font-bold leading-none text-primary">{totals[key].count}</p>
              <p className="num mt-1 text-xs text-muted">{formatCurrency(totals[key].net)} net</p>
            </button>
          ))}
        </div>
        <DataTable
          data={data?.items ?? []}
          columns={columns}
          meta={data?.meta}
          page={page}
          onPageChange={setPage}
          isLoading={isLoading}
          error={error ? 'Failed to load earnings' : null}
          emptyMessage="No earnings match these filters."
          searchPlaceholder="Search driver, phone, trip, address..."
          searchValue={search}
          onSearchChange={onSearchChange}
          onRowClick={setSelected}
          filters={[
            {
              key: 'provider',
              label: 'Driver',
              value: providerFilter,
              onChange: (value) => {
                setProviderFilter(value);
                setPage(1);
              },
              options: [
                { value: 'all', label: 'All drivers' },
                ...(providers ?? []).map((provider) => ({ value: provider.id, label: provider.user.fullName })),
              ],
            },
            {
              key: 'status',
              label: 'Payout',
              value: status,
              onChange: (value) => {
                setStatus(value as StatusFilter);
                setPage(1);
              },
              options: [
                { value: 'all', label: 'All' },
                { value: 'pending', label: 'Pending' },
                { value: 'processing', label: 'Processing' },
                { value: 'paid', label: 'Paid' },
                { value: 'rejected', label: 'Rejected' },
              ],
            },
            {
              key: 'period',
              label: 'Earned',
              value: period,
              onChange: (value) => {
                setPeriod(value as PeriodFilter);
                setPage(1);
              },
              options: [
                { value: 'all', label: 'All time' },
                { value: 'today', label: 'Today' },
                { value: '7d', label: 'Last 7 days' },
                { value: '30d', label: 'Last 30 days' },
                { value: '90d', label: 'Last 90 days' },
              ],
            },
          ]}
        />
      </PageContent>
      <Modal
        open={Boolean(selected)}
        onClose={() => setSelected(null)}
        title={selected?.job?.jobNumber ?? 'Earning'}
        description={selected?.provider?.user.fullName}
        className="max-w-xl"
      >
        {selected ? (
          <div className="space-y-4">
            <div className="grid grid-cols-3 gap-3">
              <Amount label="Gross" value={formatCurrency(Number(selected.grossAmount))} />
              <Amount label="Commission" value={formatCurrency(Number(selected.platformFee))} />
              <Amount label="Net" value={formatCurrency(Number(selected.netAmount))} />
            </div>
            <dl className="grid grid-cols-2 gap-3 text-sm">
              <Detail label="Payout" value={selected.payoutStatus.replace(/_/g, ' ')} />
              <Detail label="Earned" value={formatDate(selected.createdAt)} />
              <Detail label="Service" value={selected.job?.serviceCategory?.name || '—'} />
              <Detail label="Phone" value={selected.provider?.user.phone || '—'} />
              <Detail label="Pickup" value={selected.job?.pickupAddress || '—'} />
              <Detail label="Dropoff" value={selected.job?.dropoffAddress || '—'} />
            </dl>
            {selected.provider?.id ? (
              <Link href={`/providers/${selected.provider.id}`} className="text-sm font-medium text-primary underline-offset-4 hover:underline">
                Open driver
              </Link>
            ) : null}
          </div>
        ) : null}
      </Modal>
    </>
  );
}

function periodLabel(period: PeriodFilter) {
  if (period === 'today') return 'Today';
  if (period === '7d') return 'Last 7 days';
  if (period === '30d') return 'Last 30 days';
  if (period === '90d') return 'Last 90 days';
  return 'All time';
}

function Summary({ label, value, hint, wash }: { label: string; value: string | number; hint: string; wash: string }) {
  return (
    <div className={cn('rounded-[18px] border border-white/70 p-4', wash)}>
      <p className="text-sm text-muted">{label}</p>
      <p className="num mt-1 text-[26px] font-bold leading-none tracking-tight text-primary">{value}</p>
      <p className="mt-1 text-xs text-muted">{hint}</p>
    </div>
  );
}

function Amount({ label, value }: { label: string; value: string }) {
  return (
    <div className="rounded-2xl bg-input px-3 py-2">
      <p className="text-xs text-muted">{label}</p>
      <p className="num mt-1 font-semibold text-primary">{value}</p>
    </div>
  );
}

function Detail({ label, value }: { label: string; value: string }) {
  return (
    <div className="min-w-0">
      <dt className="text-xs capitalize text-muted">{label}</dt>
      <dd className="mt-0.5 truncate text-primary">{value}</dd>
    </div>
  );
}
