'use client';

import { useState } from 'react';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { Header } from '@/components/layout/header';
import { PageContent } from '@/components/layout/page-content';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Input } from '@/components/ui/input';
import { Button } from '@/components/ui/button';
import { DataTable, type Column } from '@/components/data-table';
import { Badge, statusBadgeVariant } from '@/components/ui/badge';
import { Toast, useToast } from '@/components/ui/toast';
import { apiFetch, apiMutate, buildQuery } from '@/lib/api';
import { formatCurrency, formatDate } from '@/lib/utils';

interface WalletBalance {
  balance: number;
  heldBalance?: number;
  currency: string;
  role?: string;
  customerWallet?: {
    balance: number;
    heldBalance?: number;
    currency: string;
  };
  providerEarnings?: {
    available: number;
    pending: number;
    currency: string;
  } | null;
}

interface WalletTransaction {
  id: string;
  type: string;
  amount: number;
  balanceAfter: number;
  description?: string;
  createdAt: string;
}

export default function WalletsPage() {
  const [userQuery, setUserQuery] = useState('');
  const [searchId, setSearchId] = useState('');
  const [resolvedUser, setResolvedUser] = useState<{
    fullName: string;
    phone: string;
    role?: string;
  } | null>(null);
  const [page, setPage] = useState(1);
  const [adjustAmount, setAdjustAmount] = useState('');
  const [adjustDescription, setAdjustDescription] = useState('');
  const queryClient = useQueryClient();
  const { toast, show } = useToast();

  const lookupMutation = useMutation({
    mutationFn: async () => {
      const res = await apiFetch<{ id: string; fullName: string; phone: string; role: string }>(
        `/admin/wallet/lookup?q=${encodeURIComponent(userQuery)}`,
      );
      return res.data!;
    },
    onSuccess: (user) => {
      setSearchId(user.id);
      setResolvedUser({ fullName: user.fullName, phone: user.phone, role: user.role });
      setPage(1);
    },
    onError: (err: Error) => show(err.message, 'error'),
  });

  const { data: balance, isLoading: balanceLoading, error: balanceError } = useQuery({
    queryKey: ['wallet-balance', searchId],
    queryFn: async () => {
      const res = await apiFetch<WalletBalance>(`/admin/wallet/user/${searchId}/balance`);
      return res.data!;
    },
    enabled: !!searchId,
  });

  const { data: transactions, isLoading: txLoading, error: txError } = useQuery({
    queryKey: ['wallet-transactions', searchId, page],
    queryFn: async () => {
      const res = await apiFetch<WalletTransaction[]>(
        `/admin/wallet/user/${searchId}/transactions${buildQuery({ page, limit: 20 })}`,
      );
      return { items: res.data ?? [], meta: res.meta };
    },
    enabled: !!searchId,
  });

  const adjustMutation = useMutation({
    mutationFn: () =>
      apiMutate('/admin/wallet/adjust', 'POST', {
        userId: searchId,
        amount: Number(adjustAmount),
        description: adjustDescription || undefined,
      }),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['wallet-balance', searchId] });
      queryClient.invalidateQueries({ queryKey: ['wallet-transactions', searchId] });
      setAdjustAmount('');
      setAdjustDescription('');
      show('Customer wallet adjusted');
    },
    onError: (err: Error) => show(err.message, 'error'),
  });

  const columns: Column<WalletTransaction>[] = [
    {
      key: 'type',
      header: 'Type',
      render: (r) => <Badge variant={statusBadgeVariant(r.type)}>{r.type}</Badge>,
    },
    {
      key: 'amount',
      header: 'Amount',
      render: (r) => formatCurrency(Number(r.amount)),
    },
    {
      key: 'balance',
      header: 'Balance After',
      render: (r) => formatCurrency(Number(r.balanceAfter)),
    },
    {
      key: 'desc',
      header: 'Description',
      render: (r) => r.description ?? '—',
    },
    {
      key: 'date',
      header: 'Date',
      render: (r) => formatDate(r.createdAt),
    },
  ];

  const isProvider = (balance?.role ?? resolvedUser?.role) === 'provider';
  const providerEarnings = balance?.providerEarnings;
  const customerWallet = balance?.customerWallet;

  return (
    <>
      <Header
        title="Wallets"
        description="Look up customer wallets and driver withdrawable earnings"
      />
      <PageContent className="space-y-6">
        <Card>
          <CardHeader>
            <CardTitle>Lookup Wallet</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="flex gap-2">
              <Input
                placeholder="Phone, name, or user ID"
                value={userQuery}
                onChange={(e) => setUserQuery(e.target.value)}
              />
              <Button
                disabled={!userQuery.trim() || lookupMutation.isPending}
                onClick={() => lookupMutation.mutate()}
              >
                Search
              </Button>
            </div>
            {resolvedUser && (
              <p className="mt-2 text-sm text-secondary">
                {resolvedUser.fullName} · {resolvedUser.phone}
                {resolvedUser.role ? (
                  <span className="ml-2 capitalize text-muted">({resolvedUser.role})</span>
                ) : null}
              </p>
            )}
          </CardContent>
        </Card>

        {searchId && (
          <>
            <Card>
              <CardContent className="space-y-5 p-6">
                {balanceLoading ? (
                  <p className="text-sm text-muted">Loading balance...</p>
                ) : balanceError ? (
                  <p className="text-sm text-danger">
                    {balanceError instanceof Error ? balanceError.message : 'Failed to load wallet'}
                  </p>
                ) : balance ? (
                  <>
                    {isProvider && providerEarnings ? (
                      <div>
                        <p className="text-sm text-muted">Available to withdraw (Driver app)</p>
                        <p className="text-3xl font-bold text-accent">
                          {formatCurrency(
                            Number(providerEarnings.available),
                            providerEarnings.currency,
                          )}
                        </p>
                        <p className="mt-1 text-sm text-secondary">
                          Matches the provider app earnings balance. From completed job earnings
                          pending payout.
                        </p>
                        {Number(providerEarnings.pending) > 0 && (
                          <p className="mt-1 text-sm text-secondary">
                            In transit:{' '}
                            {formatCurrency(
                              Number(providerEarnings.pending),
                              providerEarnings.currency,
                            )}
                          </p>
                        )}
                      </div>
                    ) : (
                      <div>
                        <p className="text-sm text-muted">Current Balance</p>
                        <p className="text-3xl font-bold text-accent">
                          {formatCurrency(Number(balance.balance), balance.currency)}
                        </p>
                        {Number(balance.heldBalance ?? 0) > 0 && (
                          <p className="mt-1 text-sm text-secondary">
                            Held:{' '}
                            {formatCurrency(Number(balance.heldBalance), balance.currency)}
                          </p>
                        )}
                      </div>
                    )}

                    {isProvider && customerWallet && (
                      <div className="rounded-lg border border-border bg-surface p-4">
                        <p className="text-sm text-muted">Customer payment wallet (separate)</p>
                        <p className="text-xl font-semibold text-primary">
                          {formatCurrency(
                            Number(customerWallet.balance),
                            customerWallet.currency,
                          )}
                        </p>
                        <p className="mt-1 text-xs text-secondary">
                          This is not the provider app balance. Adjusting it will not change the
                          amount shown in the provider Earnings screen.
                        </p>
                      </div>
                    )}
                  </>
                ) : null}
              </CardContent>
            </Card>

            <Card>
              <CardHeader>
                <CardTitle>
                  {isProvider ? 'Adjust Customer Payment Wallet' : 'Adjust Wallet'}
                </CardTitle>
              </CardHeader>
              <CardContent>
                {isProvider && (
                  <p className="mb-3 text-sm text-secondary">
                    Driver withdrawable earnings come from completed jobs. Use Finance → Earnings /
                    Payouts to manage those. This adjust only changes the separate customer-style
                    wallet record.
                  </p>
                )}
                <div className="flex flex-col gap-2 sm:flex-row">
                  <Input
                    type="number"
                    step="0.01"
                    placeholder="Amount (+/-)"
                    value={adjustAmount}
                    onChange={(e) => setAdjustAmount(e.target.value)}
                  />
                  <Input
                    placeholder="Description (optional)"
                    value={adjustDescription}
                    onChange={(e) => setAdjustDescription(e.target.value)}
                  />
                  <Button
                    disabled={!adjustAmount || adjustMutation.isPending}
                    onClick={() => adjustMutation.mutate()}
                  >
                    Adjust
                  </Button>
                </div>
              </CardContent>
            </Card>

            <DataTable
              data={transactions?.items ?? []}
              columns={columns}
              meta={transactions?.meta}
              page={page}
              onPageChange={setPage}
              isLoading={txLoading}
              error={
                txError
                  ? txError instanceof Error
                    ? txError.message
                    : 'Failed to load transactions'
                  : null
              }
              emptyMessage="No customer wallet transactions found."
            />
          </>
        )}
      </PageContent>
      {toast && <Toast message={toast.message} type={toast.type} />}
    </>
  );
}
