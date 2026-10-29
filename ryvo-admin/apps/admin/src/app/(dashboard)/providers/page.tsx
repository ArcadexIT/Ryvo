'use client';

import { useEffect, useMemo, useState } from 'react';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import Link from 'next/link';
import { useRouter } from 'next/navigation';
import { toast } from 'sonner';
import {
  Briefcase,
  ChevronRight,
  FileCheck,
  Percent,
  Search,
  Star,
  Trash2,
  UserCheck,
  Users,
  Wifi,
  X,
} from 'lucide-react';
import { Header } from '@/components/layout/header';
import { PageContent } from '@/components/layout/page-content';
import { Badge, StatusBadge, statusBadgeVariant } from '@/components/ui/badge';
import { Button, buttonVariants } from '@/components/ui/button';
import { ConfirmDeleteDialog } from '@/components/ui/confirm-delete-dialog';
import { EmptyState } from '@/components/ui/empty-state';
import { ExportButton } from '@/components/ui/export-button';
import { Input } from '@/components/ui/input';
import { Pagination } from '@/components/ui/pagination';
import { SecureAvatar } from '@/components/ui/secure-avatar';
import { SegmentedTabs } from '@/components/ui/segmented-tabs';
import { Skeleton } from '@/components/ui/skeleton';
import { apiFetch, apiMutate, buildQuery } from '@/lib/api';
import { cn, formatDate } from '@/lib/utils';

interface Provider {
  id: string;
  businessName?: string | null;
  verificationStatus: string;
  onlineStatus: string;
  commissionRate: number;
  ratingAvg?: number;
  totalJobs?: number;
  user: { fullName: string; phone: string; avatarUrl?: string; status?: string };
  createdAt: string;
  _count?: { jobs: number; documents: number };
}

async function fetchProviderTotal(filters: Record<string, string | undefined> = {}) {
  const res = await apiFetch<Provider[]>(
    `/admin/providers${buildQuery({ page: 1, limit: 1, ...filters })}`,
  );
  return res.meta?.total ?? 0;
}

function OnlineDot({ status }: { status: string }) {
  const isLive = status === 'online' || status === 'busy';
  return (
    <span
      className={cn(
        'absolute bottom-0 right-0 h-3 w-3 rounded-full border-2 border-elevated',
        isLive ? 'bg-success' : 'bg-muted',
      )}
    />
  );
}

function ProvidersSkeleton() {
  return (
    <div className="divide-y divide-border/70">
      {Array.from({ length: 8 }).map((_, i) => (
        <div
          key={i}
          className="flex items-center gap-4 px-4 py-4 sm:px-5"
        >
          <Skeleton className="h-11 w-11 shrink-0 rounded-full" />
          <div className="min-w-0 flex-1 space-y-2">
            <Skeleton className="h-4 w-44" />
            <Skeleton className="h-3 w-28" />
          </div>
          <Skeleton className="hidden h-6 w-20 sm:block" />
          <Skeleton className="hidden h-6 w-16 md:block" />
          <Skeleton className="hidden h-6 w-14 lg:block" />
        </div>
      ))}
    </div>
  );
}

function ProviderRow({
  provider,
  onClick,
  onDelete,
}: {
  provider: Provider;
  onClick: () => void;
  onDelete: () => void;
}) {
  const jobCount = provider._count?.jobs ?? provider.totalJobs ?? 0;
  const rating = Number(provider.ratingAvg ?? 0);
  const commission = (Number(provider.commissionRate) * 100).toFixed(0);

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
      className="group grid w-full cursor-pointer grid-cols-[auto_minmax(0,1fr)_auto] items-center gap-3 px-4 py-3.5 text-left transition-colors hover:bg-surface/80 sm:gap-4 sm:px-5 lg:grid-cols-[auto_minmax(0,1.4fr)_120px_100px_88px_72px_auto]"
    >
      <div className="relative shrink-0">
        <SecureAvatar
          name={provider.user.fullName}
          src={provider.user.avatarUrl}
          size="lg"
          className="h-11 w-11"
        />
        <OnlineDot status={provider.onlineStatus} />
      </div>

      <div className="min-w-0">
        <div className="flex flex-wrap items-center gap-2">
          <p className="truncate font-semibold text-primary group-hover:text-accent">
            {provider.user.fullName}
          </p>
          <StatusBadge status={provider.verificationStatus} />
        </div>
        <div className="mt-0.5 flex flex-wrap items-center gap-x-2 gap-y-0.5 text-xs text-secondary">
          {provider.businessName && (
            <>
              <span className="truncate">{provider.businessName}</span>
              <span className="text-border-strong">·</span>
            </>
          )}
          <span className="font-mono text-[12px]">{provider.user.phone}</span>
        </div>
        <div className="mt-1.5 flex flex-wrap items-center gap-3 text-[11px] text-muted lg:hidden">
          <span className="inline-flex items-center gap-1">
            <Star className="h-3 w-3 text-warning" />
            {rating.toFixed(1)}
          </span>
          <span>{jobCount} jobs</span>
          <span>{commission}% fee</span>
          <Badge variant={statusBadgeVariant(provider.onlineStatus)} className="capitalize">
            {provider.onlineStatus.replace('_', ' ')}
          </Badge>
        </div>
      </div>

      <div className="hidden lg:block">
        <Badge variant={statusBadgeVariant(provider.onlineStatus)} className="capitalize">
          <span
            className={cn(
              'mr-1 h-1.5 w-1.5 rounded-full',
              provider.onlineStatus === 'online' || provider.onlineStatus === 'busy'
                ? 'bg-success'
                : 'bg-current opacity-50',
            )}
          />
          {provider.onlineStatus.replace('_', ' ')}
        </Badge>
      </div>

      <div className="hidden items-center gap-1.5 text-sm text-primary lg:flex">
        <Star className="h-3.5 w-3.5 text-warning" />
        <span className="font-tabular font-medium">{rating.toFixed(1)}</span>
      </div>

      <div className="hidden items-center gap-1.5 text-sm text-secondary lg:flex">
        <Briefcase className="h-3.5 w-3.5" />
        <span className="font-tabular">{jobCount}</span>
      </div>

      <div className="hidden items-center gap-1 text-sm text-secondary lg:flex">
        <Percent className="h-3.5 w-3.5" />
        <span className="font-tabular">{commission}%</span>
      </div>

      <div className="flex items-center gap-2">
        <div className="hidden text-right sm:block">
          <p className="text-[11px] text-muted">Joined</p>
          <p className="font-mono text-[11px] text-secondary">
            {formatDate(provider.createdAt)}
          </p>
        </div>
        <button
          type="button"
          aria-label={`Delete ${provider.user.fullName}`}
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

export default function ProvidersPage() {
  const router = useRouter();
  const queryClient = useQueryClient();
  const [page, setPage] = useState(1);
  const [pendingDelete, setPendingDelete] = useState<Provider | null>(null);
  const [search, setSearch] = useState('');
  const [debouncedSearch, setDebouncedSearch] = useState('');
  const [verificationFilter, setVerificationFilter] = useState('all');
  const [onlineFilter, setOnlineFilter] = useState('all');

  useEffect(() => {
    const timer = setTimeout(() => setDebouncedSearch(search.trim()), 300);
    return () => clearTimeout(timer);
  }, [search]);

  useEffect(() => {
    setPage(1);
  }, [debouncedSearch, verificationFilter, onlineFilter]);

  const deleteMutation = useMutation({
    mutationFn: (providerId: string) => apiMutate(`/admin/providers/${providerId}`, 'DELETE'),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['providers'] });
      queryClient.invalidateQueries({ queryKey: ['providers-stats'] });
      setPendingDelete(null);
      toast.success('Driver deleted');
    },
    onError: (err: Error) => toast.error(err.message),
  });

  const listQuery = useQuery({
    queryKey: ['providers', page, debouncedSearch, verificationFilter, onlineFilter],
    queryFn: async () => {
      const res = await apiFetch<Provider[]>(
        `/admin/providers${buildQuery({
          page,
          limit: 20,
          search: debouncedSearch || undefined,
          verificationStatus: verificationFilter === 'all' ? undefined : verificationFilter,
          onlineStatus: onlineFilter === 'all' ? undefined : onlineFilter,
        })}`,
      );
      return { items: res.data ?? [], meta: res.meta };
    },
  });

  const statsQuery = useQuery({
    queryKey: ['providers-stats'],
    queryFn: async () => {
      const [total, approved, pending, online, kycPending] = await Promise.all([
        fetchProviderTotal(),
        fetchProviderTotal({ verificationStatus: 'approved' }),
        fetchProviderTotal({ verificationStatus: 'pending' }),
        fetchProviderTotal({ onlineStatus: 'online' }),
        apiFetch<{ summary?: { documents: number } }>(
          `/admin/providers/kyc/pending${buildQuery({ page: 1, limit: 1 })}`,
        ).then((r) => r.data?.summary?.documents ?? r.meta?.total ?? 0),
      ]);
      return { total, approved, pending, online, kycPending };
    },
    staleTime: 60_000,
  });

  const items = listQuery.data?.items ?? [];
  const meta = listQuery.data?.meta;
  const stats = statsQuery.data;
  const showListSkeleton =
    listQuery.isLoading || (listQuery.isFetching && items.length === 0);

  const exportData = useMemo(
    () =>
      items.map((p) => ({
        name: p.user.fullName,
        business: p.businessName ?? '',
        phone: p.user.phone,
        verification: p.verificationStatus,
        online: p.onlineStatus,
        commission: `${(Number(p.commissionRate) * 100).toFixed(0)}%`,
        jobs: p._count?.jobs ?? p.totalJobs ?? 0,
        joined: formatDate(p.createdAt),
      })),
    [items],
  );

  const hasFilters =
    verificationFilter !== 'all' || onlineFilter !== 'all' || Boolean(debouncedSearch);

  const clearFilters = () => {
    setSearch('');
    setVerificationFilter('all');
    setOnlineFilter('all');
  };

  const applyStatFilter = (key: 'all' | 'approved' | 'pending' | 'online') => {
    if (key === 'all') {
      setVerificationFilter('all');
      setOnlineFilter('all');
      return;
    }
    if (key === 'online') {
      setOnlineFilter('online');
      setVerificationFilter('all');
      return;
    }
    setVerificationFilter(key);
    setOnlineFilter('all');
  };

  const activeStat =
    onlineFilter === 'online' && verificationFilter === 'all'
      ? 'online'
      : verificationFilter === 'approved' && onlineFilter === 'all'
        ? 'approved'
        : verificationFilter === 'pending' && onlineFilter === 'all'
          ? 'pending'
          : verificationFilter === 'all' && onlineFilter === 'all'
            ? 'all'
            : null;

  return (
    <>
      <Header
        title="Drivers"
        description="Manage drivers, verification, and availability"
      />

      <PageContent>
        <div className="space-y-6">
          {/* KPI strip — clickable filters */}
          <div className="grid gap-3 sm:grid-cols-2 xl:grid-cols-4">
            {(
              [
                {
                  key: 'all' as const,
                  label: 'Total drivers',
                  value: stats?.total ?? 0,
                  icon: Users,
                  tone: 'bg-accent-soft text-accent',
                },
                {
                  key: 'approved' as const,
                  label: 'Verified',
                  value: stats?.approved ?? 0,
                  icon: UserCheck,
                  tone: 'bg-success/10 text-success',
                },
                {
                  key: 'pending' as const,
                  label: 'Pending Review',
                  value: stats?.pending ?? 0,
                  icon: FileCheck,
                  tone: 'bg-warning/10 text-warning',
                },
                {
                  key: 'online' as const,
                  label: 'Online Now',
                  value: stats?.online ?? 0,
                  icon: Wifi,
                  tone: 'bg-info/10 text-info',
                },
              ] as const
            ).map((stat) => {
              const active = activeStat === stat.key;
              return (
                <button
                  key={stat.key}
                  type="button"
                  onClick={() => applyStatFilter(stat.key)}
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

          {/* KYC callout */}
          {(stats?.kycPending ?? 0) > 0 && (
            <div className="relative overflow-hidden rounded-2xl border border-warning/25 bg-warning/5">
              <div className="pointer-events-none absolute inset-y-0 left-0 w-1 bg-warning" />
              <div className="flex flex-wrap items-center justify-between gap-4 px-5 py-4 pl-6">
                <div className="flex items-center gap-3">
                  <div className="flex h-10 w-10 items-center justify-center rounded-lg bg-warning/15">
                    <FileCheck className="h-5 w-5 text-warning" />
                  </div>
                  <div>
                    <p className="font-medium text-primary">
                      {stats?.kycPending === 1
                        ? '1 document awaiting review'
                        : `${stats?.kycPending} documents awaiting review`}
                    </p>
                    <p className="text-sm text-secondary">
                      Clear the KYC queue to keep driver onboarding moving
                    </p>
                  </div>
                </div>
                <Link href="/providers/kyc" className={buttonVariants({ size: 'sm' })}>
                  Open KYC Queue
                </Link>
              </div>
            </div>
          )}

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
                  <ExportButton
                    data={exportData}
                    filename="providers"
                    columns={[
                      { key: 'name', header: 'Name' },
                      { key: 'business', header: 'Business' },
                      { key: 'phone', header: 'Phone' },
                      { key: 'verification', header: 'Verification' },
                      { key: 'online', header: 'Online Status' },
                      { key: 'commission', header: 'Commission' },
                      { key: 'jobs', header: 'Rides' },
                      { key: 'joined', header: 'Joined' },
                    ]}
                  />
                  <Link
                    href="/providers/kyc"
                    className={buttonVariants({ variant: 'outline', size: 'sm' })}
                  >
                    <FileCheck className="h-4 w-4" />
                    KYC Queue
                    {(stats?.kycPending ?? 0) > 0 && (
                      <span className="ml-0.5 rounded-full bg-warning/20 px-1.5 py-0.5 text-[11px] font-semibold text-warning">
                        {stats?.kycPending}
                      </span>
                    )}
                  </Link>
                </div>
              </div>

              <div className="flex flex-col gap-3 lg:flex-row lg:items-center lg:justify-between">
                <div className="space-y-1.5">
                  <p className="text-[11px] font-medium uppercase tracking-wide text-muted">
                    Verification
                  </p>
                  <SegmentedTabs
                    value={verificationFilter}
                    onChange={setVerificationFilter}
                    className="w-full overflow-x-auto sm:w-auto"
                    items={[
                      { value: 'all', label: 'All' },
                      { value: 'pending', label: 'Pending', count: stats?.pending },
                      { value: 'approved', label: 'Approved' },
                      { value: 'rejected', label: 'Rejected' },
                      { value: 'suspended', label: 'Suspended' },
                    ]}
                  />
                </div>
                <div className="space-y-1.5">
                  <p className="text-[11px] font-medium uppercase tracking-wide text-muted">
                    Availability
                  </p>
                  <SegmentedTabs
                    value={onlineFilter}
                    onChange={setOnlineFilter}
                    className="w-full overflow-x-auto sm:w-auto"
                    items={[
                      { value: 'all', label: 'All' },
                      { value: 'online', label: 'Online', count: stats?.online },
                      { value: 'busy', label: 'Busy' },
                      { value: 'offline', label: 'Offline' },
                    ]}
                  />
                </div>
              </div>
            </div>

            <div className="flex items-center justify-between gap-3 border-b border-border bg-surface/50 px-4 py-2.5 sm:px-5">
              <p className="text-sm text-secondary">
                <span className="font-tabular font-medium text-primary">
                  {meta?.total ?? items.length}
                </span>{' '}
                {(meta?.total ?? items.length) === 1 ? 'driver' : 'drivers'}
                {hasFilters ? ' matched' : ''}
              </p>
              <div className="hidden items-center gap-8 text-[11px] font-medium uppercase tracking-wide text-muted lg:flex">
                <span className="w-[120px]">Status</span>
                <span className="w-[100px]">Rating</span>
                <span className="w-[88px]">Jobs</span>
                <span className="w-[72px]">Fee</span>
                <span className="w-[108px] text-right">Joined</span>
              </div>
            </div>

            {showListSkeleton ? (
              <ProvidersSkeleton />
            ) : listQuery.error ? (
              <div className="flex h-48 items-center justify-center px-4">
                <p className="text-sm text-danger">Failed to load providers. Please try again.</p>
              </div>
            ) : items.length === 0 ? (
              <EmptyState
                title="No drivers found"
                description={
                  hasFilters
                    ? 'Try adjusting your search or filters.'
                    : 'Drivers will appear here once they register.'
                }
                actionLabel={hasFilters ? 'Clear filters' : undefined}
                onAction={hasFilters ? clearFilters : undefined}
                className="border-0 bg-transparent py-16"
              />
            ) : (
              <div className="divide-y divide-border/70">
                {items.map((provider) => (
                  <ProviderRow
                    key={provider.id}
                    provider={provider}
                    onClick={() => router.push(`/providers/${provider.id}`)}
                    onDelete={() => setPendingDelete(provider)}
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
        title="Delete driver?"
        description={
          pendingDelete
            ? `${pendingDelete.user.fullName} (${pendingDelete.user.phone}) will be permanently removed. Jobs they served stay with the customer, and this driver is unassigned.`
            : ''
        }
        confirmLabel="Delete driver"
        loading={deleteMutation.isPending}
        onClose={() => setPendingDelete(null)}
        onConfirm={() => {
          if (pendingDelete) deleteMutation.mutate(pendingDelete.id);
        }}
      />
    </>
  );
}
