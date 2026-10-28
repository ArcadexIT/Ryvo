'use client';

import { useMemo, useState } from 'react';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { Header } from '@/components/layout/header';
import { PageContent } from '@/components/layout/page-content';
import { DataTable, type Column } from '@/components/data-table';
import { Badge, statusBadgeVariant } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { Toast, useToast } from '@/components/ui/toast';
import { apiFetch, apiMutate, buildQuery } from '@/lib/api';

interface Country {
  id: string;
  name: string;
  code: string;
  code3: string;
  numeric: string;
  dialCode: string;
  icon: string;
  isActive: boolean;
  sortOrder: number;
}

export default function CountriesPage() {
  const [page, setPage] = useState(1);
  const [statusFilter, setStatusFilter] = useState('all');
  const [search, setSearch] = useState('');
  const queryClient = useQueryClient();
  const { toast, show } = useToast();

  const { data, isLoading, error } = useQuery({
    queryKey: ['admin-countries', page, statusFilter, search],
    queryFn: async () => {
      const res = await apiFetch<Country[]>(
        `/admin/countries${buildQuery({
          page,
          limit: 20,
          status: statusFilter === 'all' ? undefined : statusFilter,
          search: search || undefined,
        })}`,
      );
      return { items: res.data ?? [], meta: res.meta };
    },
  });

  const toggleMutation = useMutation({
    mutationFn: ({ id, isActive }: { id: string; isActive: boolean }) =>
      apiMutate(`/admin/countries/${id}/active`, 'PATCH', { isActive }),
    onSuccess: (_, vars) => {
      queryClient.invalidateQueries({ queryKey: ['admin-countries'] });
      show(vars.isActive ? 'Country activated' : 'Country deactivated');
    },
    onError: (err: Error) => show(err.message, 'error'),
  });

  const exportParams = useMemo(
    () => ({
      status: statusFilter === 'all' ? undefined : statusFilter,
      search: search || undefined,
    }),
    [statusFilter, search],
  );

  const columns: Column<Country>[] = [
    {
      key: 'name',
      header: 'Country',
      render: (r) => (
        <div className="flex items-center gap-2">
          <span className="text-lg leading-none">{r.icon}</span>
          <span className="font-medium text-primary">{r.name}</span>
        </div>
      ),
      exportValue: (r) => r.name,
    },
    {
      key: 'code',
      header: 'Code',
      render: (r) => <span className="font-mono text-[13px] text-secondary">{r.code}</span>,
      exportValue: (r) => r.code,
    },
    {
      key: 'code3',
      header: 'Code3',
      render: (r) => <span className="font-mono text-[13px] text-secondary">{r.code3}</span>,
      exportValue: (r) => r.code3,
    },
    {
      key: 'numeric',
      header: 'Numeric',
      render: (r) => <span className="font-mono text-[13px] text-muted">{r.numeric}</span>,
      exportValue: (r) => r.numeric,
    },
    {
      key: 'dialCode',
      header: 'Dial Code',
      render: (r) => <span className="font-mono text-[13px] text-secondary">{r.dialCode}</span>,
      exportValue: (r) => r.dialCode,
    },
    {
      key: 'status',
      header: 'Status',
      render: (r) => (
        <Badge variant={r.isActive ? statusBadgeVariant('active') : 'secondary'}>
          {r.isActive ? 'Active' : 'Inactive'}
        </Badge>
      ),
      exportValue: (r) => (r.isActive ? 'active' : 'inactive'),
    },
    {
      key: 'actions',
      header: '',
      render: (r) => (
        <Button
          size="sm"
          variant={r.isActive ? 'outline' : 'default'}
          disabled={toggleMutation.isPending}
          onClick={() => toggleMutation.mutate({ id: r.id, isActive: !r.isActive })}
        >
          {r.isActive ? 'Deactivate' : 'Activate'}
        </Button>
      ),
    },
  ];

  return (
    <>
      <Header
        title="Countries"
        description="Manage which countries are available across the platform"
      />
      <PageContent>
        <DataTable
          data={data?.items ?? []}
          columns={columns}
          meta={data?.meta}
          page={page}
          onPageChange={setPage}
          isLoading={isLoading}
          error={error ? 'Failed to load countries' : null}
          searchPlaceholder="Search by name, code, or dial code..."
          searchValue={search}
          onSearchChange={(v) => {
            setSearch(v);
            setPage(1);
          }}
          serverExport={{ type: 'countries', params: exportParams }}
          filters={[
            {
              key: 'status',
              label: 'Status',
              value: statusFilter,
              onChange: (v) => {
                setStatusFilter(v);
                setPage(1);
              },
              options: [
                { value: 'all', label: 'All statuses' },
                { value: 'active', label: 'Active' },
                { value: 'inactive', label: 'Inactive' },
              ],
            },
          ]}
          emptyMessage="No countries found"
        />
      </PageContent>
      {toast && <Toast message={toast.message} type={toast.type} />}
    </>
  );
}
