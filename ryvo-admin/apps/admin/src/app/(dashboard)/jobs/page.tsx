'use client';

import { useMemo, useState } from 'react';
import { useQuery } from '@tanstack/react-query';
import { useRouter } from 'next/navigation';
import { Header } from '@/components/layout/header';
import { PageContent } from '@/components/layout/page-content';
import { DataTable, type Column } from '@/components/data-table';
import { StatusBadge } from '@/components/ui/badge';
import { Avatar } from '@/components/ui/avatar';
import { apiFetch, buildQuery } from '@/lib/api';
import { formatCurrency, formatDate } from '@/lib/utils';

interface Job {
  id: string;
  jobNumber: string;
  status: string;
  estimatedFare?: number;
  finalFare?: number;
  createdAt: string;
  customer?: { user: { fullName: string } };
  provider?: { user: { fullName: string } };
}

const STATUS_OPTIONS = [
  { value: 'all', label: 'All statuses' },
  { value: 'searching', label: 'Searching' },
  { value: 'matched', label: 'Matched' },
  { value: 'provider_en_route', label: 'En route' },
  { value: 'in_progress', label: 'In progress' },
  { value: 'completed', label: 'Completed' },
  { value: 'cancelled_by_admin', label: 'Cancelled (admin)' },
  { value: 'cancelled_by_customer', label: 'Cancelled (customer)' },
  { value: 'payment_pending', label: 'Payment pending' },
];

export default function JobsPage() {
  const router = useRouter();
  const [page, setPage] = useState(1);
  const [statusFilter, setStatusFilter] = useState('all');
  const [search, setSearch] = useState('');

  const { data, isLoading, error } = useQuery({
    queryKey: ['jobs', page, statusFilter, search],
    queryFn: async () => {
      const res = await apiFetch<Job[]>(
        `/admin/jobs${buildQuery({
          page,
          limit: 20,
          status: statusFilter === 'all' ? undefined : statusFilter,
          search: search || undefined,
        })}`,
      );
      return { items: res.data ?? [], meta: res.meta };
    },
  });

  const exportParams = useMemo(
    () => ({
      status: statusFilter === 'all' ? undefined : statusFilter,
      search: search || undefined,
    }),
    [statusFilter, search],
  );

  const columns: Column<Job>[] = [
    {
      key: 'jobNumber',
      header: 'Job #',
      render: (r) => <span className="font-mono text-[13px] font-medium text-primary">{r.jobNumber}</span>,
      searchable: (r) => r.jobNumber,
      sortValue: (r) => r.jobNumber,
      exportValue: (r) => r.jobNumber,
    },
    {
      key: 'customer',
      header: 'Customer',
      render: (r) =>
        r.customer ? (
          <div className="flex items-center gap-2">
            <Avatar name={r.customer.user.fullName} size="sm" />
            <span className="text-primary">{r.customer.user.fullName}</span>
          </div>
        ) : (
          <span className="text-muted">—</span>
        ),
      searchable: (r) => r.customer?.user.fullName ?? '',
      exportValue: (r) => r.customer?.user.fullName ?? '',
    },
    {
      key: 'provider',
      header: 'Driver',
      render: (r) =>
        r.provider ? (
          <div className="flex items-center gap-2">
            <Avatar name={r.provider.user.fullName} size="sm" />
            <span className="text-primary">{r.provider.user.fullName}</span>
          </div>
        ) : (
          <span className="text-muted">Unassigned</span>
        ),
      exportValue: (r) => r.provider?.user.fullName ?? '',
    },
    {
      key: 'status',
      header: 'Status',
      render: (r) => <StatusBadge status={r.status} />,
      exportValue: (r) => r.status,
    },
    {
      key: 'fare',
      header: 'Fare',
      render: (r) => (
        <span className="font-mono text-[13px] font-medium text-primary">
          {formatCurrency(Number(r.finalFare ?? r.estimatedFare ?? 0))}
        </span>
      ),
      exportValue: (r) => Number(r.finalFare ?? r.estimatedFare ?? 0),
    },
    {
      key: 'created',
      header: 'Created',
      render: (r) => <span className="font-mono text-[13px] text-muted">{formatDate(r.createdAt)}</span>,
      exportValue: (r) => formatDate(r.createdAt),
    },
  ];

  return (
    <>
      <Header title="Trips" description="Monitor pickup, dropoff, fare, and payment" />
      <PageContent>
        <DataTable
          data={data?.items ?? []}
          columns={columns}
          meta={data?.meta}
          page={page}
          onPageChange={setPage}
          isLoading={isLoading}
          error={error ? 'Failed to load jobs' : null}
          onRowClick={(row) => router.push(`/jobs/${row.id}`)}
          searchPlaceholder="Search rides..."
          searchValue={search}
          onSearchChange={(v) => {
            setSearch(v);
            setPage(1);
          }}
          serverExport={{ type: 'jobs', params: exportParams }}
          filters={[
            {
              key: 'status',
              label: 'Status',
              value: statusFilter,
              onChange: (v) => {
                setStatusFilter(v);
                setPage(1);
              },
              options: STATUS_OPTIONS,
            },
          ]}
        />
      </PageContent>
    </>
  );
}
