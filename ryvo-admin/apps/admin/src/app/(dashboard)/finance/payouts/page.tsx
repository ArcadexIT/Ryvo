'use client';

import { useEffect, useState, Suspense } from 'react';
import { useSearchParams } from 'next/navigation';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { Header } from '@/components/layout/header';
import { PageContent } from '@/components/layout/page-content';
import { PageToolbar } from '@/components/layout/page-toolbar';
import { DataTable, type Column } from '@/components/data-table';
import { Badge, statusBadgeVariant } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { Modal } from '@/components/ui/modal';
import { Toast, useToast } from '@/components/ui/toast';
import { apiFetch, apiMutate, buildQuery } from '@/lib/api';
import { ServerExportButton } from '@/components/ui/server-export-button';
import { formatCurrency, formatDate } from '@/lib/utils';

interface BankAccount {
  id: string;
  bankName: string;
  accountHolder: string;
  accountNumber: string;
  routingNumber?: string | null;
  lastFour: string;
}

interface Payout {
  id: string;
  amount: number;
  status: string;
  bankAccountRef?: string | null;
  processedAt?: string;
  createdAt: string;
  provider?: {
    id: string;
    user: { id: string; fullName: string; phone?: string; email?: string };
  };
  bankAccount?: BankAccount | null;
}

interface Provider {
  id: string;
  user: { fullName: string };
}

interface PayoutSummary {
  pending: { count: number; amount: number };
  processing: { count: number; amount: number };
  paid: { count: number; amount: number };
}

function maskAccount(accountNumber?: string, lastFour?: string) {
  if (accountNumber) return accountNumber;
  if (lastFour) return `•••• ${lastFour}`;
  return '—';
}

export default function PayoutsPage() {
  return (
    <Suspense fallback={null}>
      <PayoutsPageContent />
    </Suspense>
  );
}

function PayoutsPageContent() {
  const searchParams = useSearchParams();
  const [page, setPage] = useState(1);
  const [providerFilter, setProviderFilter] = useState('all');
  const [statusFilter, setStatusFilter] = useState('all');
  const [selected, setSelected] = useState<Payout | null>(null);
  const queryClient = useQueryClient();
  const { toast, show } = useToast();

  useEffect(() => {
    const status = searchParams.get('status');
    if (status && ['pending', 'processing', 'paid'].includes(status)) {
      setStatusFilter(status);
      setPage(1);
    }
  }, [searchParams]);

  const { data: providers } = useQuery({
    queryKey: ['providers-filter'],
    queryFn: async () => {
      const res = await apiFetch<Provider[]>('/admin/providers?limit=100');
      return res.data ?? [];
    },
  });

  const { data: summary } = useQuery({
    queryKey: ['finance-payouts-summary'],
    queryFn: async () => {
      const res = await apiFetch<PayoutSummary>('/admin/finance/payouts/summary');
      return res.data ?? { pending: { count: 0, amount: 0 }, processing: { count: 0, amount: 0 }, paid: { count: 0, amount: 0 } };
    },
    staleTime: 15_000,
    refetchInterval: 30_000,
  });

  const { data, isLoading, error } = useQuery({
    queryKey: ['finance-payouts', page, providerFilter, statusFilter],
    queryFn: async () => {
      const res = await apiFetch<Payout[]>(
        `/admin/finance/payouts${buildQuery({
          page,
          limit: 20,
          providerId: providerFilter === 'all' ? undefined : providerFilter,
          status: statusFilter === 'all' ? undefined : statusFilter,
        })}`,
      );
      return { items: res.data ?? [], meta: res.meta };
    },
  });

  const processMutation = useMutation({
    mutationFn: (payoutId: string) =>
      apiMutate(`/admin/finance/payouts/${payoutId}/process`, 'PATCH'),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['finance-payouts'] });
      queryClient.invalidateQueries({ queryKey: ['finance-payouts-summary'] });
      queryClient.invalidateQueries({ queryKey: ['admin-notifications'] });
      queryClient.invalidateQueries({ queryKey: ['dashboard-activity'] });
      setSelected(null);
      show('Payout sent through Stripe');
    },
    onError: (err: Error) => show(err.message, 'error'),
  });

  const rejectMutation = useMutation({
    mutationFn: (payoutId: string) =>
      apiMutate(`/admin/finance/payouts/${payoutId}/reject`, 'PATCH'),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['finance-payouts'] });
      queryClient.invalidateQueries({ queryKey: ['finance-payouts-summary'] });
      queryClient.invalidateQueries({ queryKey: ['admin-notifications'] });
      queryClient.invalidateQueries({ queryKey: ['dashboard-activity'] });
      setSelected(null);
      show('Payout rejected');
    },
    onError: (err: Error) => show(err.message, 'error'),
  });

  const columns: Column<Payout>[] = [
    {
      key: 'provider',
      header: 'Driver',
      render: (r) => (
        <div>
          <p className="font-medium text-primary">{r.provider?.user.fullName ?? '—'}</p>
          {r.provider?.user.phone && (
            <p className="text-xs text-secondary">{r.provider.user.phone}</p>
          )}
        </div>
      ),
      searchable: (r) =>
        [r.provider?.user.fullName, r.provider?.user.phone, r.provider?.user.email]
          .filter(Boolean)
          .join(' '),
    },
    {
      key: 'amount',
      header: 'Amount',
      render: (r) => (
        <span className="font-semibold text-primary">{formatCurrency(Number(r.amount))}</span>
      ),
    },
    {
      key: 'bank',
      header: 'Destination',
      render: (r) => {
        const bank = r.bankAccount;
        const stripe = !bank && (!r.bankAccountRef || r.bankAccountRef === 'Stripe Connect');
        const label = stripe ? 'Stripe account' : (r.bankAccountRef ?? bank?.bankName ?? '—');
        return (
          <div>
            <p className="text-sm text-primary">{label}</p>
            {bank ? (
              <p className="text-xs text-secondary">
                {bank.accountHolder} · {maskAccount(bank.accountNumber, bank.lastFour)}
              </p>
            ) : stripe ? (
              <p className="text-xs text-secondary">Bank details stay with Stripe</p>
            ) : null}
          </div>
        );
      },
      searchable: (r) =>
        [
          r.bankAccountRef,
          r.bankAccount?.bankName,
          r.bankAccount?.accountHolder,
          r.bankAccount?.accountNumber,
          r.bankAccount?.routingNumber,
        ]
          .filter(Boolean)
          .join(' '),
    },
    {
      key: 'status',
      header: 'Status',
      render: (r) => <Badge variant={statusBadgeVariant(r.status)}>{r.status}</Badge>,
    },
    {
      key: 'created',
      header: 'Requested',
      render: (r) => formatDate(r.createdAt),
    },
    {
      key: 'processed',
      header: 'Paid',
      render: (r) => (r.processedAt ? formatDate(r.processedAt) : '—'),
    },
    {
      key: 'actions',
      header: 'Actions',
      render: (r) =>
        r.status !== 'paid' ? (
          <Button
            size="sm"
            disabled={processMutation.isPending}
            onClick={(e) => {
              e.stopPropagation();
              setSelected(r);
            }}
          >
            Process
          </Button>
        ) : (
          <span className="text-xs text-secondary">Completed</span>
        ),
    },
  ];

  return (
    <>
      <Header
        title="Payouts"
        description="Review withdrawal requests and send them to the driver's Stripe account"
      />
      <PageContent>
        <div className="mb-6 grid gap-4 sm:grid-cols-3">
          <button
            type="button"
            onClick={() => {
              setStatusFilter('pending');
              setPage(1);
            }}
            className="rounded-xl border border-border bg-elevated p-4 text-left transition-colors hover:border-warning/50"
          >
            <p className="text-sm text-secondary">Waiting for review</p>
            <p className="mt-1 text-2xl font-bold text-warning">{summary?.pending.count ?? 0}</p>
            <p className="text-sm text-secondary">{formatCurrency(summary?.pending.amount ?? 0)}</p>
          </button>
          <div className="rounded-xl border border-border bg-elevated p-4">
            <p className="text-sm text-secondary">Processing</p>
            <p className="mt-1 text-2xl font-bold text-primary">{summary?.processing.count ?? 0}</p>
            <p className="text-sm text-secondary">{formatCurrency(summary?.processing.amount ?? 0)}</p>
          </div>
          <div className="rounded-xl border border-border bg-elevated p-4">
            <p className="text-sm text-secondary">Paid (all time)</p>
            <p className="mt-1 text-2xl font-bold text-success">{summary?.paid.count ?? 0}</p>
            <p className="text-sm text-secondary">{formatCurrency(summary?.paid.amount ?? 0)}</p>
          </div>
        </div>

        <PageToolbar>
          <ServerExportButton type="payouts" />
        </PageToolbar>

        <DataTable
          data={data?.items ?? []}
          columns={columns}
          meta={data?.meta}
          page={page}
          onPageChange={setPage}
          isLoading={isLoading}
          error={error ? 'Failed to load payouts' : null}
          searchPlaceholder="Search driver, bank, account..."
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
                { value: 'processing', label: 'Processing' },
                { value: 'pending', label: 'Pending' },
                { value: 'paid', label: 'Paid' },
              ],
            },
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

      <Modal
        open={!!selected}
        onClose={() => setSelected(null)}
        title="Process payout"
        description="Send this withdrawal to the driver's Stripe account, then confirm below."
        className="max-w-xl"
      >
        {selected && (
          <div className="space-y-4">
            <div className="rounded-lg border border-border bg-surface p-4">
              <div className="flex items-start justify-between gap-4">
                <div>
                  <p className="text-sm text-secondary">Driver</p>
                  <p className="font-semibold text-primary">{selected.provider?.user.fullName}</p>
                  {selected.provider?.user.phone && (
                    <p className="text-sm text-secondary">{selected.provider.user.phone}</p>
                  )}
                  {selected.provider?.user.email && (
                    <p className="text-sm text-secondary">{selected.provider.user.email}</p>
                  )}
                </div>
                <div className="text-right">
                  <p className="text-sm text-secondary">Amount</p>
                  <p className="text-2xl font-bold text-primary">{formatCurrency(Number(selected.amount))}</p>
                </div>
              </div>
            </div>

            {selected.bankAccount ? (
              <div className="rounded-lg border border-primary/20 bg-primary/5 p-4">
                <p className="mb-3 text-sm font-medium text-primary">Bank transfer details</p>
                <dl className="grid gap-2 text-sm">
                  <div className="flex justify-between gap-4">
                    <dt className="text-secondary">Bank</dt>
                    <dd className="font-medium text-primary">{selected.bankAccount.bankName}</dd>
                  </div>
                  <div className="flex justify-between gap-4">
                    <dt className="text-secondary">Account holder</dt>
                    <dd className="font-medium text-primary">{selected.bankAccount.accountHolder}</dd>
                  </div>
                  <div className="flex justify-between gap-4">
                    <dt className="text-secondary">Account number</dt>
                    <dd className="font-mono font-medium text-primary">
                      {maskAccount(selected.bankAccount.accountNumber, selected.bankAccount.lastFour)}
                    </dd>
                  </div>
                  {selected.bankAccount.routingNumber && (
                    <div className="flex justify-between gap-4">
                      <dt className="text-secondary">Routing number</dt>
                      <dd className="font-mono font-medium text-primary">{selected.bankAccount.routingNumber}</dd>
                    </div>
                  )}
                  <div className="flex justify-between gap-4">
                    <dt className="text-secondary">Requested</dt>
                    <dd className="text-primary">{formatDate(selected.createdAt)}</dd>
                  </div>
                </dl>
              </div>
            ) : (
              <div className="rounded-lg border border-primary/20 bg-primary/5 p-4">
                <p className="text-sm font-medium text-primary">Paid to Stripe</p>
                <p className="mt-1 text-sm text-secondary">
                  Bank details stay with Stripe. Approving sends {formatCurrency(Number(selected.amount))} to this provider&apos;s Stripe account.
                </p>
                <p className="mt-3 text-sm text-secondary">Requested {formatDate(selected.createdAt)}</p>
              </div>
            )}

            <p className="text-xs text-secondary">
              Confirming will mark this payout as paid, update linked earnings, and notify the provider in the app.
            </p>

            <div className="flex justify-end gap-3 pt-2">
              <Button variant="outline" onClick={() => setSelected(null)}>
                Cancel
              </Button>
              <Button
                variant="outline"
                disabled={rejectMutation.isPending || selected.status === 'rejected' || selected.status === 'paid'}
                onClick={() => rejectMutation.mutate(selected.id)}
              >
                Reject
              </Button>
              <Button
                disabled={processMutation.isPending || selected.status === 'paid' || selected.status === 'rejected'}
                onClick={() => processMutation.mutate(selected.id)}
              >
                {processMutation.isPending ? 'Processing…' : 'Approve and pay'}
              </Button>
            </div>
          </div>
        )}
      </Modal>

      {toast && <Toast message={toast.message} type={toast.type} />}
    </>
  );
}
