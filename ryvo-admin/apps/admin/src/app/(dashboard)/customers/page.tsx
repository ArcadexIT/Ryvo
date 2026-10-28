'use client';

import { useEffect, useMemo, useState } from 'react';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { useRouter } from 'next/navigation';
import { toast } from 'sonner';
import {
  Ban,
  Briefcase,
  Car,
  ChevronRight,
  Mail,
  Search,
  Trash2,
  UserCheck,
  Users,
  X,
} from 'lucide-react';
import { Header } from '@/components/layout/header';
import { PageContent } from '@/components/layout/page-content';
import { StatusBadge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { ConfirmDeleteDialog } from '@/components/ui/confirm-delete-dialog';
import { EmptyState } from '@/components/ui/empty-state';
import { Input } from '@/components/ui/input';
import { ListExportButton } from '@/components/ui/list-export-button';
import { Pagination } from '@/components/ui/pagination';
import { SecureAvatar } from '@/components/ui/secure-avatar';
import { SegmentedTabs } from '@/components/ui/segmented-tabs';
import { Skeleton } from '@/components/ui/skeleton';
import { apiFetch, apiMutate, buildQuery } from '@/lib/api';
import { cn, formatDate } from '@/lib/utils';

interface Customer {
  id: string;
  createdAt: string;
  user: {
    id: string;
    fullName: string;
    phone: string;
    email?: string | null;
    status: string;
    avatarUrl?: string | null;
  };
  _count?: { jobs: number; vehicles: number };
}

async function fetchCustomerTotal(filters: Record<string, string | undefined> = {}) {
  const res = await apiFetch<Customer[]>(
    `/admin/customers${buildQuery({ page: 1, limit: 1, ...filters })}`,
  );
  return res.meta?.total ?? 0;
}

function CustomersSkeleton() {
  return (
    <div className="divide-y divide-border/70">
      {Array.from({ length: 8 }).map((_, i) => (
        <div key={i} className="flex items-center gap-4 px-4 py-4 sm:px-5">
          <Skeleton className="h-11 w-11 shrink-0 rounded-full" />
          <div className="min-w-0 flex-1 space-y-2">
            <Skeleton className="h-4 w-44" />
            <Skeleton className="h-3 w-32" />
          </div>
          <Skeleton className="hidden h-6 w-20 sm:block" />
          <Skeleton className="hidden h-6 w-14 lg:block" />
        </div>
      ))}
    </div>
  );
}

function CustomerRow({
  customer,
  onClick,
  onDelete,
}: {
  customer: Customer;
  onClick: () => void;
  onDelete: () => void;
}) {
  const jobs = customer._count?.jobs ?? 0;
  const vehicles = customer._count?.vehicles ?? 0;

  return (
    <div
      role="button"
      tabIndex={0}
      onClick={onClick}
      onKeyDown={(event) => {
        if (event.target !== event.currentTarget) return;
        if (event.key === 'Enter' || event.key === ' ') {
          event.preventDefault();
          onClick();
        }
      }}
      className="group grid w-full cursor-pointer grid-cols-[auto_minmax(0,1fr)_auto] items-center gap-3 px-4 py-3.5 text-left transition-colors hover:bg-surface/80 sm:gap-4 sm:px-5 lg:grid-cols-[auto_minmax(0,1.4fr)_minmax(0,1fr)_88px_88px_auto]"
    >
      <SecureAvatar
        name={customer.user.fullName}
        src={customer.user.avatarUrl}
        size="lg"
        className="h-11 w-11"
      />

      <div className="min-w-0">
        <div className="flex flex-wrap items-center gap-2">
          <p className="truncate font-semibold text-primary group-hover:text-accent">
            {customer.user.fullName}
          </p>
          <StatusBadge status={customer.user.status} />
        </div>
        <p className="mt-0.5 font-mono text-[12px] text-secondary">{customer.user.phone}</p>
        <div className="mt-1.5 flex flex-wrap items-center gap-3 text-[11px] text-muted lg:hidden">
          {customer.user.email && (
            <span className="inline-flex max-w-[180px] items-center gap-1 truncate">
              <Mail className="h-3 w-3 shrink-0" />
              {customer.user.email}
            </span>
          )}
          <span className="inline-flex items-center gap-1">
            <Briefcase className="h-3 w-3" />
            {jobs} jobs
          </span>
          <span className="inline-flex items-center gap-1">
            <Car className="h-3 w-3" />
            {vehicles}
          </span>
        </div>
      </div>

      <div className="hidden min-w-0 lg:block">
        {customer.user.email ? (
          <span className="inline-flex max-w-full items-center gap-1.5 truncate text-sm text-secondary">
            <Mail className="h-3.5 w-3.5 shrink-0 text-muted" />
            <span className="truncate">{customer.user.email}</span>
          </span>
        ) : (
          <span className="text-sm text-muted">—</span>
        )}
      </div>

      <div className="hidden items-center gap-1.5 text-sm text-secondary lg:flex">
        <Briefcase className="h-3.5 w-3.5" />
        <span className="font-tabular">{jobs}</span>
      </div>

      <div className="hidden items-center gap-1.5 text-sm text-secondary lg:flex">
        <Car className="h-3.5 w-3.5" />
        <span className="font-tabular">{vehicles}</span>
      </div>

      <div className="flex items-center gap-2">
        <div className="hidden text-right sm:block">
          <p className="text-[11px] text-muted">Joined</p>
          <p className="font-mono text-[11px] text-secondary">
            {formatDate(customer.createdAt)}
          </p>
        </div>
        <button
          type="button"
          aria-label={`Delete ${customer.user.fullName}`}
          title="Delete"
          className="rounded-md p-1.5 text-muted hover:bg-danger/10 hover:text-danger"
          onClick={(event) => {
            event.stopPropagation();
            onDelete();
          }}
        >
          <Trash2 className="h-4 w-4" />
        </button>
        <ChevronRight className="h-4 w-4 shrink-0 text-muted transition-transform group-hover:translate-x-0.5 group-hover:text-accent" />
      </div>
    </div>
  );
}

export default function CustomersPage() {
  const router = useRouter();
  const queryClient = useQueryClient();
  const [page, setPage] = useState(1);
  const [pendingDelete, setPendingDelete] = useState<Customer | null>(null);
  const [search, setSearch] = useState('');
  const [debouncedSearch, setDebouncedSearch] = useState('');
  const [statusFilter, setStatusFilter] = useState('all');

  useEffect(() => {
    const timer = setTimeout(() => setDebouncedSearch(search.trim()), 300);
    return () => clearTimeout(timer);
  }, [search]);

  useEffect(() => {
    setPage(1);
  }, [debouncedSearch, statusFilter]);

  const deleteMutation = useMutation({
    mutationFn: (customerId: string) => apiMutate(`/admin/customers/${customerId}`, 'DELETE'),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['customers'] });
      queryClient.invalidateQueries({ queryKey: ['customers-stats'] });
      setPendingDelete(null);
      toast.success('Customer deleted');
    },
    onError: (err: Error) => toast.error(err.message),
  });

  const listQuery = useQuery({
    queryKey: ['customers', page, debouncedSearch, statusFilter],
    queryFn: async () => {
      const res = await apiFetch<Customer[]>(
        `/admin/customers${buildQuery({
          page,
          limit: 20,
          search: debouncedSearch || undefined,
          status: statusFilter === 'all' ? undefined : statusFilter,
        })}`,
      );
      return { items: res.data ?? [], meta: res.meta };
    },
  });

  const statsQuery = useQuery({
    queryKey: ['customers-stats'],
    queryFn: async () => {
      const [total, active, suspended] = await Promise.all([
        fetchCustomerTotal(),
        fetchCustomerTotal({ status: 'active' }),
        fetchCustomerTotal({ status: 'suspended' }),
      ]);
      return { total, active, suspended };
    },
    staleTime: 60_000,
  });

  const items = listQuery.data?.items ?? [];
  const meta = listQuery.data?.meta;
  const stats = statsQuery.data;
  const showListSkeleton =
    listQuery.isLoading || (listQuery.isFetching && items.length === 0);

  const exportParams = useMemo(
    () => ({
      status: statusFilter === 'all' ? undefined : statusFilter,
      search: debouncedSearch || undefined,
    }),
    [statusFilter, debouncedSearch],
  );

  const hasFilters = statusFilter !== 'all' || Boolean(debouncedSearch);

  const clearFilters = () => {
    setSearch('');
    setStatusFilter('all');
  };

  return (
    <>
      <Header title="Riders" description="Manage rider accounts and activity" />

      <PageContent>
        <div className="space-y-6">
          {/* KPI strip — clickable filters */}
          <div className="grid gap-3 sm:grid-cols-3">
            {(
              [
                {
                  key: 'all',
                  label: 'Total Customers',
                  value: stats?.total ?? 0,
                  icon: Users,
                  tone: 'bg-accent-soft text-accent',
                },
                {
                  key: 'active',
                  label: 'Active',
                  value: stats?.active ?? 0,
                  icon: UserCheck,
                  tone: 'bg-success/10 text-success',
                },
                {
                  key: 'suspended',
                  label: 'Suspended',
                  value: stats?.suspended ?? 0,
                  icon: Ban,
                  tone: 'bg-danger/10 text-danger',
                },
              ] as const
            ).map((stat) => {
              const active = statusFilter === stat.key;
              return (
                <button
                  key={stat.key}
                  type="button"
                  onClick={() => setStatusFilter(stat.key)}
                  className={cn(
                    'rounded-xl border bg-elevated px-4 py-4 text-left shadow-sm transition-all',
                    active
                      ? 'border-accent/40 ring-2 ring-accent/15'
                      : 'border-border hover:border-border-strong hover:shadow-md',
                  )}
                >
                  <div className="flex items-center justify-between gap-3">
                    <div>
                      <p className="text-xs font-medium text-secondary">{stat.label}</p>
                      {statsQuery.isLoading ? (
                        <Skeleton className="mt-2 h-7 w-12" />
                      ) : (
                        <p className="font-tabular font-display mt-1 text-2xl text-primary">
                          {stat.value}
                        </p>
                      )}
                    </div>
                    <div
                      className={cn(
                        'flex h-10 w-10 items-center justify-center rounded-lg',
                        stat.tone,
                      )}
                    >
                      <stat.icon className="h-5 w-5" />
                    </div>
                  </div>
                </button>
              );
            })}
          </div>

          {/* Toolbar + list */}
          <section className="overflow-hidden rounded-2xl border border-border bg-elevated shadow-sm">
            <div className="space-y-4 border-b border-border p-4 sm:p-5">
              <div className="flex flex-wrap items-center justify-between gap-3">
                <div className="relative min-w-[220px] max-w-md flex-1">
                  <Search className="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-muted" />
                  <Input
                    placeholder="Search by name or phone..."
                    value={search}
                    onChange={(e) => setSearch(e.target.value)}
                    className="pl-9"
                  />
                </div>
                <div className="flex flex-wrap items-center gap-2">
                  {hasFilters && (
                    <Button variant="ghost" size="sm" onClick={clearFilters}>
                      <X className="h-3.5 w-3.5" />
                      Clear
                    </Button>
                  )}
                  <ListExportButton type="customers" params={exportParams} />
                </div>
              </div>

              <div className="space-y-1.5">
                <p className="text-[11px] font-medium uppercase tracking-wide text-muted">
                  Account status
                </p>
                <SegmentedTabs
                  value={statusFilter}
                  onChange={setStatusFilter}
                  className="w-full overflow-x-auto sm:w-auto"
                  items={[
                    { value: 'all', label: 'All', count: stats?.total },
                    { value: 'active', label: 'Active', count: stats?.active },
                    { value: 'suspended', label: 'Suspended', count: stats?.suspended },
                  ]}
                />
              </div>
            </div>

            <div className="flex items-center justify-between gap-3 border-b border-border bg-surface/50 px-4 py-2.5 sm:px-5">
              <p className="text-sm text-secondary">
                <span className="font-tabular font-medium text-primary">
                  {meta?.total ?? items.length}
                </span>{' '}
                {(meta?.total ?? items.length) === 1 ? 'customer' : 'customers'}
                {hasFilters ? ' matched' : ''}
              </p>
              <div className="hidden items-center gap-8 text-[11px] font-medium uppercase tracking-wide text-muted lg:flex">
                <span className="min-w-[140px]">Email</span>
                <span className="w-[88px]">Jobs</span>
                <span className="w-[88px]">Vehicles</span>
                <span className="w-[108px] text-right">Joined</span>
              </div>
            </div>

            {showListSkeleton ? (
              <CustomersSkeleton />
            ) : listQuery.error ? (
              <div className="flex h-48 items-center justify-center px-4">
                <p className="text-sm text-danger">Failed to load customers. Please try again.</p>
              </div>
            ) : items.length === 0 ? (
              <EmptyState
                title="No customers found"
                description={
                  hasFilters
                    ? 'Try adjusting your search or filters.'
                    : 'Customers will appear here once they register.'
                }
                actionLabel={hasFilters ? 'Clear filters' : undefined}
                onAction={hasFilters ? clearFilters : undefined}
                className="border-0 bg-transparent py-16"
              />
            ) : (
              <div className="divide-y divide-border/70">
                {items.map((customer) => (
                  <CustomerRow
                    key={customer.id}
                    customer={customer}
                    onClick={() => router.push(`/customers/${customer.id}`)}
                    onDelete={() => setPendingDelete(customer)}
                  />
                ))}
              </div>
            )}

            {meta && items.length > 0 && (
              <div className="border-t border-border px-4 py-3 sm:px-5">
                <Pagination meta={meta} page={page} onPageChange={setPage} />
              </div>
            )}
          </section>
        </div>
      </PageContent>
      <ConfirmDeleteDialog
        open={!!pendingDelete}
        title="Delete customer?"
        description={
          pendingDelete
            ? `${pendingDelete.user.fullName} (${pendingDelete.user.phone}) will be permanently removed, including their jobs and payment records.`
            : ''
        }
        confirmLabel="Delete customer"
        loading={deleteMutation.isPending}
        onClose={() => setPendingDelete(null)}
        onConfirm={() => {
          if (pendingDelete) deleteMutation.mutate(pendingDelete.id);
        }}
      />
    </>
  );
}
