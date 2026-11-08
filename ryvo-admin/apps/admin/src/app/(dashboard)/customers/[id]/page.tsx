'use client';

import { useState } from 'react';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { useParams, useRouter } from 'next/navigation';
import Link from 'next/link';
import { Header } from '@/components/layout/header';
import { PageContent } from '@/components/layout/page-content';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { StatusBadge } from '@/components/ui/badge';
import { KeyValueList } from '@/components/ui/key-value-list';
import { Avatar } from '@/components/ui/avatar';
import { Button } from '@/components/ui/button';
import { ConfirmDeleteDialog } from '@/components/ui/confirm-delete-dialog';
import { Input } from '@/components/ui/input';
import { SegmentedTabs } from '@/components/ui/segmented-tabs';
import { Toast, useToast } from '@/components/ui/toast';
import { apiFetch, apiMutate } from '@/lib/api';
import { formatCurrency, formatDate } from '@/lib/utils';
import { ArrowLeft, Trash2, Wallet } from 'lucide-react';

interface CustomerJob {
  id: string;
  jobNumber: string;
  status: string;
  finalFare?: number;
  estimatedFare?: number;
  createdAt: string;
  serviceCategory?: { name: string };
  provider?: { user: { fullName: string } };
}

interface CustomerDetail {
  id: string;
  createdAt: string;
  user: {
    id: string;
    fullName: string;
    phone: string;
    email?: string;
    status: string;
    wallet?: { balance: number; currency: string };
  };
  jobs?: CustomerJob[];
}

export default function CustomerDetailPage() {
  const { id } = useParams<{ id: string }>();
  const router = useRouter();
  const queryClient = useQueryClient();
  const { toast, show } = useToast();
  const [tab, setTab] = useState('overview');
  const [adjustAmount, setAdjustAmount] = useState('');
  const [adjustDescription, setAdjustDescription] = useState('');
  const [confirmDelete, setConfirmDelete] = useState(false);

  const { data, isLoading, error } = useQuery({
    queryKey: ['customer', id],
    queryFn: async () => {
      const res = await apiFetch<CustomerDetail>(`/admin/customers/${id}`);
      return res.data!;
    },
    enabled: !!id,
  });

  const statusMutation = useMutation({
    mutationFn: (status: 'active' | 'suspended') =>
      apiMutate(`/admin/customers/${id}/status`, 'PATCH', { status }),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['customer', id] });
      show('Customer status updated');
    },
    onError: (err: Error) => show(err.message, 'error'),
  });

  const deleteMutation = useMutation({
    mutationFn: () => apiMutate(`/admin/customers/${id}`, 'DELETE'),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['customers'] });
      queryClient.invalidateQueries({ queryKey: ['customers-stats'] });
      show('Customer deleted');
      router.push('/customers');
    },
    onError: (err: Error) => show(err.message, 'error'),
  });

  const walletMutation = useMutation({
    mutationFn: () =>
      apiMutate('/admin/wallet/adjust', 'POST', {
        userId: data!.user.id,
        amount: Number(adjustAmount),
        description: adjustDescription || undefined,
      }),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['customer', id] });
      setAdjustAmount('');
      setAdjustDescription('');
      show('Wallet adjusted');
    },
    onError: (err: Error) => show(err.message, 'error'),
  });

  const isActive = data?.user.status === 'active';

  return (
    <>
      <Header title={data?.user.fullName ?? 'Customer Detail'} description={data?.user.phone} />
      <PageContent>
        <Link href="/customers">
          <Button variant="ghost" size="sm" className="mb-4">
            <ArrowLeft className="mr-2 h-4 w-4" />
            Back to Customers
          </Button>
        </Link>

        {isLoading && <p className="text-sm text-muted">Loading...</p>}
        {error && <p className="text-sm text-danger">Failed to load customer</p>}

        {data && (
          <div className="space-y-6">
            <SegmentedTabs
              value={tab}
              onChange={setTab}
              items={[
                { value: 'overview', label: 'Overview' },
                { value: 'jobs', label: `Jobs (${data.jobs?.length ?? 0})` },
              ]}
            />

            <section className="flex flex-col gap-4 rounded-lg border border-hairline bg-card p-4 sm:flex-row sm:items-center sm:justify-between">
              <div className="flex items-center gap-3">
                <Avatar name={data.user.fullName} size="lg" />
                <div>
                  <h2 className="text-xl font-semibold tracking-tight text-primary">{data.user.fullName}</h2>
                  <div className="mt-1">
                    <StatusBadge status={data.user.status} />
                  </div>
                </div>
              </div>
              <div className="flex items-center gap-2">
                <Button
                  variant={isActive ? 'destructive' : 'default'}
                  size="sm"
                  disabled={statusMutation.isPending}
                  onClick={() => statusMutation.mutate(isActive ? 'suspended' : 'active')}
                >
                  {isActive ? 'Suspend' : 'Activate'}
                </Button>
                <Button variant="destructive" size="sm" onClick={() => setConfirmDelete(true)} aria-label="Delete rider">
                  <Trash2 strokeWidth={1.75} />
                  Delete
                </Button>
              </div>
            </section>

            {tab === 'overview' && (
              <div className="grid gap-4 lg:grid-cols-[minmax(0,1fr)_280px]">
                <Card>
                  <CardHeader>
                    <CardTitle>Wallet</CardTitle>
                  </CardHeader>
                  <CardContent className="space-y-4">
                    {data.user.wallet ? (
                      <div className="flex items-center gap-3 rounded-lg border border-border bg-surface px-4 py-3">
                        <div className="flex h-10 w-10 shrink-0 items-center justify-center rounded-lg bg-accent-soft">
                          <Wallet className="h-5 w-5 text-accent" />
                        </div>
                        <p className="font-tabular font-display text-2xl text-primary">
                          {formatCurrency(Number(data.user.wallet.balance), data.user.wallet.currency)}
                        </p>
                      </div>
                    ) : (
                      <p className="text-sm text-muted">No wallet found</p>
                    )}
                    <div className="space-y-2">
                      <Input
                        type="number"
                        step="0.01"
                        placeholder="Adjustment amount (+/-)"
                        value={adjustAmount}
                        onChange={(e) => setAdjustAmount(e.target.value)}
                      />
                      <Input
                        placeholder="Description (optional)"
                        value={adjustDescription}
                        onChange={(e) => setAdjustDescription(e.target.value)}
                      />
                      <Button
                        size="sm"
                        disabled={!adjustAmount || walletMutation.isPending}
                        onClick={() => walletMutation.mutate()}
                      >
                        Adjust Wallet
                      </Button>
                    </div>
                  </CardContent>
                </Card>
                <Card>
                  <CardHeader>
                    <CardTitle>Details</CardTitle>
                  </CardHeader>
                  <CardContent>
                    <KeyValueList
                      items={[
                        { label: 'Phone', value: data.user.phone },
                        { label: 'Email', value: data.user.email ?? '—' },
                        { label: 'Status', value: <StatusBadge status={data.user.status} /> },
                        { label: 'Joined', value: formatDate(data.createdAt) },
                        { label: 'Trips', value: data.jobs?.length ?? 0 },
                      ]}
                    />
                  </CardContent>
                </Card>
              </div>
            )}

            {tab === 'jobs' && (
              <Card>
                <CardHeader>
                  <CardTitle>Recent Jobs</CardTitle>
                </CardHeader>
                <CardContent>
                  {!data.jobs?.length ? (
                    <p className="text-sm text-muted">No jobs yet.</p>
                  ) : (
                    <ul className="divide-y divide-border">
                      {data.jobs.map((job) => (
                        <li
                          key={job.id}
                          className="flex cursor-pointer items-center justify-between py-3 hover:bg-surface/50"
                          onClick={() => router.push(`/jobs/${job.id}`)}
                        >
                          <div>
                            <p className="font-mono text-[13px] font-medium text-primary">{job.jobNumber}</p>
                            <p className="text-xs text-muted">
                              {job.serviceCategory?.name ?? 'Service'} · {job.provider?.user.fullName ?? 'Unassigned'}
                            </p>
                          </div>
                          <div className="text-right">
                            <StatusBadge status={job.status} />
                            <p className="mt-1 font-mono text-[13px] text-secondary">
                              {formatCurrency(Number(job.finalFare ?? job.estimatedFare ?? 0))}
                            </p>
                            <p className="text-xs text-muted">{formatDate(job.createdAt)}</p>
                          </div>
                        </li>
                      ))}
                    </ul>
                  )}
                </CardContent>
              </Card>
            )}
          </div>
        )}
      </PageContent>
      <ConfirmDeleteDialog
        open={confirmDelete}
        title="Delete customer?"
        description={
          data
            ? `${data.user.fullName} (${data.user.phone}) will be permanently removed, including their jobs and payment records.`
            : 'This customer will be permanently removed.'
        }
        confirmLabel="Delete customer"
        loading={deleteMutation.isPending}
        onClose={() => setConfirmDelete(false)}
        onConfirm={() => deleteMutation.mutate()}
      />
      {toast && <Toast message={toast.message} type={toast.type} />}
    </>
  );
}
