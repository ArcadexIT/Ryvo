'use client';

import { useMemo, useState } from 'react';
import { useQuery } from '@tanstack/react-query';
import { Header } from '@/components/layout/header';
import { PageContent } from '@/components/layout/page-content';
import { PageToolbar } from '@/components/layout/page-toolbar';
import { DataTable, type Column } from '@/components/data-table';
import { Badge, statusBadgeVariant } from '@/components/ui/badge';
import { apiFetch, buildQuery } from '@/lib/api';
import { ServerExportButton } from '@/components/ui/server-export-button';
import { formatCurrency, formatDate } from '@/lib/utils';

interface Earning {
  id: string;
  grossAmount: number;
  platformFee: number;
  netAmount: number;
  payoutStatus: string;
  createdAt: string;
  provider?: { id: string; user: { fullName: string } };
  job?: { jobNumber: string };
}

interface Provider {
  id: string;
  user: { fullName: string };
}

export default function EarningsPage() {
  const [page, setPage] = useState(1);
  const [providerFilter, setProviderFilter] = useState('all');

  const { data: providers } = useQuery({
    queryKey: ['providers-filter'],
    queryFn: async () => {
      const res = await apiFetch<Provider[]>('/admin/providers?limit=100');
      return res.data ?? [];
    },
  });

  const { data, isLoading, error } = useQuery({
    queryKey: ['finance-earnings', page, providerFilter],
    queryFn: async () => {
      const res = await apiFetch<Earning[]>(
        `/admin/finance/earnings${buildQuery({
          page,
          limit: 20,
          providerId: providerFilter === 'all' ? undefined : providerFilter,
        })}`,
      );
      return { items: res.data ?? [], meta: res.meta };
    },
  });

  const columns: Column<Earning>[] = [
    {
      key: 'provider',
      header: 'Driver',
      render: (r) => r.provider?.user.fullName ?? '—',
      searchable: (r) => r.provider?.user.fullName ?? '',
    },
    {
      key: 'job',
      header: 'Job',
      render: (r) => r.job?.jobNumber ?? '—',
    },
    {
      key: 'gross',
      header: 'Gross',
      render: (r) => formatCurrency(Number(r.grossAmount)),
    },
    {
      key: 'commission',
      header: 'Commission',
      render: (r) => formatCurrency(Number(r.platformFee)),
    },
    {
      key: 'net',
      header: 'Net',
      render: (r) => formatCurrency(Number(r.netAmount)),
    },
    {
      key: 'status',
      header: 'Status',
      render: (r) =>
        r.payoutStatus ? (
          <Badge variant={statusBadgeVariant(r.payoutStatus)}>{r.payoutStatus}</Badge>
        ) : (
          '—'
        ),
    },
    {
      key: 'date',
      header: 'Date',
      render: (r) => formatDate(r.createdAt),
    },
  ];

  return (
    <>
      <Header title="Earnings" description="Driver earnings records" />
      <PageContent>
        <PageToolbar>
          <ServerExportButton
            type="earnings"
          />
        </PageToolbar>
        <DataTable
          data={data?.items ?? []}
          columns={columns}
          meta={data?.meta}
          page={page}
          onPageChange={setPage}
          isLoading={isLoading}
          error={error ? 'Failed to load earnings' : null}
          searchPlaceholder="Search earnings..."
          filters={[
            {
              key: 'provider',
              label: 'Driver',
              value: providerFilter,
              onChange: (v) => {
                setProviderFilter(v);
                setPage(1);
              },
              options: [
                { value: 'all', label: 'All drivers' },
                ...(providers ?? []).map((p) => ({ value: p.id, label: p.user.fullName })),
              ],
            },
          ]}
        />
      </PageContent>
    </>
  );
}
