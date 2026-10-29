'use client';

import { useState } from 'react';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { useParams, useRouter } from 'next/navigation';
import Link from 'next/link';
import { Header } from '@/components/layout/header';
import { PageContent } from '@/components/layout/page-content';
import { SecureAvatar } from '@/components/ui/secure-avatar';
import { Badge, StatusBadge, statusBadgeVariant } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { ConfirmDeleteDialog } from '@/components/ui/confirm-delete-dialog';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Input } from '@/components/ui/input';
import { Modal } from '@/components/ui/modal';
import { SecureFilePreview } from '@/components/ui/secure-file-preview';
import { Select } from '@/components/ui/select';
import { SegmentedTabs } from '@/components/ui/segmented-tabs';
import { Textarea } from '@/components/ui/textarea';
import { EmptyState } from '@/components/ui/empty-state';
import { Skeleton } from '@/components/ui/skeleton';
import { apiFetch, apiMutate } from '@/lib/api';
import { cn, formatCurrency, formatDate, formatDocumentType } from '@/lib/utils';
import { toast } from 'sonner';
import {
  ArrowLeft,
  Briefcase,
  CheckCircle2,
  Clock,
  Copy,
  Eye,
  FileCheck,
  FileText,
  GraduationCap,
  Mail,
  Percent,
  Phone,
  Star,
  Trash2,
  Wallet,
  WifiOff,
  XCircle,
} from 'lucide-react';

interface ProviderDocument {
  id: string;
  docType: string;
  status: string;
  fileUrl?: string;
  createdAt?: string;
  rejectionReason?: string;
  equipmentLabel?: string | null;
  serviceCategory?: { name?: string } | null;
}

interface ProviderJob {
  id: string;
  jobNumber: string;
  status: string;
  finalFare?: number;
  estimatedFare?: number;
  createdAt: string;
  serviceCategory?: { name: string };
}

interface ProviderQualification {
  id: string;
  title: string;
  passed: boolean;
  lastScore?: number | null;
  passPercent?: number;
  serviceCategory?: { name?: string } | null;
}

interface ProviderDetail {
  id: string;
  businessName?: string;
  verificationStatus: string;
  onlineStatus: string;
  commissionRate: number;
  ratingAvg: number;
  totalJobs: number;
  createdAt: string;
  agreementAcceptedAt?: string | null;
  agreementVersionAccepted?: string | null;
  user: {
    fullName: string;
    phone: string;
    email?: string;
    avatarUrl?: string;
    status?: string;
    wallet?: { balance: number; currency: string };
  };
  earningsWallet?: {
    available: number;
    pending: number;
    currency: string;
  };
  documents?: ProviderDocument[];
  jobs?: ProviderJob[];
  qualifications?: ProviderQualification[];
  subscriptions?: Array<{
    id: string;
    status: string;
    expiresAt?: string | null;
    plan?: { name: string; period: string };
  }>;
}

type TabId = 'overview' | 'documents' | 'jobs' | 'qualifications';

function OnlineIndicator({ status }: { status: string }) {
  const isOnline = status === 'online' || status === 'busy';
  return (
    <span className="inline-flex items-center gap-1.5">
      <span
        className={cn(
          'h-2 w-2 rounded-full',
          isOnline ? 'bg-success animate-pulse' : 'bg-muted',
        )}
      />
      <span className="capitalize">{status.replace('_', ' ')}</span>
    </span>
  );
}

function copyText(value: string, label: string) {
  void navigator.clipboard.writeText(value).then(() => {
    toast.success(`${label} copied`);
  });
}

function ProviderDetailSkeleton() {
  return (
    <div className="space-y-6">
      <Skeleton className="h-40 w-full rounded-2xl" />
      <div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-4">
        {Array.from({ length: 4 }).map((_, i) => (
          <Skeleton key={i} className="h-28 rounded-xl" />
        ))}
      </div>
      <Skeleton className="h-10 w-80 rounded-lg" />
      <div className="grid gap-6 lg:grid-cols-5">
        <Skeleton className="h-72 rounded-xl lg:col-span-2" />
        <Skeleton className="h-72 rounded-xl lg:col-span-3" />
      </div>
    </div>
  );
}

function MetaRow({
  icon: Icon,
  label,
  value,
  mono,
  copyable,
}: {
  icon: React.ElementType;
  label: string;
  value: React.ReactNode;
  mono?: boolean;
  copyable?: string;
}) {
  return (
    <div className="group flex items-center justify-between gap-3 border-b border-border/70 py-3 last:border-0 last:pb-0 first:pt-0">
      <div className="flex min-w-0 items-center gap-3">
        <div className="flex h-8 w-8 shrink-0 items-center justify-center rounded-md bg-surface text-secondary">
          <Icon className="h-3.5 w-3.5" />
        </div>
        <div className="min-w-0">
          <p className="text-[11px] font-medium uppercase tracking-wide text-muted">{label}</p>
          <div
            className={cn(
              'mt-0.5 truncate text-sm text-primary',
              mono && 'font-mono text-[13px]',
            )}
          >
            {value}
          </div>
        </div>
      </div>
      {copyable && (
        <button
          type="button"
          onClick={() => copyText(copyable, label)}
          className="rounded-md p-1.5 text-muted opacity-0 transition-opacity hover:bg-surface hover:text-primary group-hover:opacity-100"
          aria-label={`Copy ${label}`}
        >
          <Copy className="h-3.5 w-3.5" />
        </button>
      )}
    </div>
  );
}

export default function ProviderDetailPage() {
  const { id } = useParams<{ id: string }>();
  const router = useRouter();
  const queryClient = useQueryClient();
  const [tab, setTab] = useState<TabId>('overview');
  const [commissionPct, setCommissionPct] = useState('');
  const [editingCommission, setEditingCommission] = useState(false);
  const [previewDoc, setPreviewDoc] = useState<ProviderDocument | null>(null);
  const [rejectDoc, setRejectDoc] = useState<ProviderDocument | null>(null);
  const [rejectReason, setRejectReason] = useState('');
  const [confirmDelete, setConfirmDelete] = useState(false);

  const { data, isLoading, error } = useQuery({
    queryKey: ['provider', id],
    queryFn: async () => {
      const res = await apiFetch<ProviderDetail>(`/admin/providers/${id}`);
      return res.data!;
    },
    enabled: !!id,
  });

  const agreements = useQuery({
    queryKey: ['provider-agreements', id],
    queryFn: async () => {
      const res = await apiFetch<
        {
          key: string;
          title: string;
          version: string;
          accepted: boolean;
          acceptedAt?: string | null;
          reacceptanceRequired: boolean;
          insuranceProofStatus?: string | null;
        }[]
      >(`/admin/providers/${id}/agreements`);
      return res.data ?? [];
    },
    enabled: !!id,
  });

  const requestProof = useMutation({
    mutationFn: () => apiMutate(`/admin/providers/${id}/insurance-proof`, 'PATCH'),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['provider-agreements', id] });
      toast.success('Insurance proof requested');
    },
    onError: (err: Error) => toast.error(err.message),
  });

  const reviewMutation = useMutation({
    mutationFn: ({
      docId,
      status,
      reason,
    }: {
      docId: string;
      status: 'approved' | 'rejected';
      reason?: string;
    }) =>
      apiMutate(`/admin/providers/documents/${docId}/review`, 'PATCH', {
        status,
        ...(reason ? { rejectionReason: reason } : {}),
      }),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['provider', id] });
      setPreviewDoc(null);
      setRejectDoc(null);
      setRejectReason('');
      toast.success('Document reviewed');
    },
    onError: (err: Error) => toast.error(err.message),
  });

  const deleteMutation = useMutation({
    mutationFn: () => apiMutate(`/admin/providers/${id}`, 'DELETE'),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['providers'] });
      queryClient.invalidateQueries({ queryKey: ['providers-stats'] });
      toast.success('Driver deleted');
      router.push('/providers');
    },
    onError: (err: Error) => toast.error(err.message),
  });

  const forceOfflineMutation = useMutation({
    mutationFn: () => apiMutate(`/admin/providers/${id}/force-offline`, 'PATCH'),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['provider', id] });
      toast.success('Driver forced offline');
    },
    onError: (err: Error) => toast.error(err.message),
  });

  const commissionMutation = useMutation({
    mutationFn: (commissionRate: number) =>
      apiMutate(`/admin/providers/${id}/commission`, 'PATCH', { commissionRate }),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['provider', id] });
      setEditingCommission(false);
      toast.success('Commission updated');
    },
    onError: (err: Error) => toast.error(err.message),
  });

  const verificationMutation = useMutation({
    mutationFn: (verificationStatus: string) =>
      apiMutate(`/admin/providers/${id}/verification-status`, 'PATCH', { verificationStatus }),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['provider', id] });
      toast.success('Verification status updated');
    },
    onError: (err: Error) => toast.error(err.message),
  });

  const isReviewable = (status: string) => status === 'pending' || status === 'rejected';
  const isOnline = data?.onlineStatus !== 'offline';
  const pendingDocs = data?.documents?.filter((d) => d.status === 'pending').length ?? 0;
  const approvedDocs = data?.documents?.filter((d) => d.status === 'approved').length ?? 0;
  const earningsWallet = data?.earningsWallet;
  const jobQualifications =
    data?.qualifications?.filter((q) => !!q.serviceCategory) ?? [];

  return (
    <>
      <Header
        title={data?.user.fullName ?? 'Driver Detail'}
        description={data?.businessName ?? 'Manage driver profile and verification'}
      />
      <PageContent>
        <div className="mb-5">
          <Link href="/providers">
            <Button variant="ghost" size="sm">
              <ArrowLeft className="h-4 w-4" />
              Back to Drivers
            </Button>
          </Link>
        </div>

        {isLoading && <ProviderDetailSkeleton />}

        {error && (
          <EmptyState
            title="Failed to load driver"
            description="The driver could not be found or an error occurred."
            actionLabel="Back to Drivers"
            onAction={() => router.push('/providers')}
          />
        )}

        {data && (
          <div className="space-y-6">
            {/* Profile header */}
            <section className="relative overflow-hidden rounded-2xl border border-border bg-elevated shadow-sm">
              <div className="pointer-events-none absolute inset-x-0 top-0 h-24 bg-[radial-gradient(ellipse_at_top_left,var(--accent-soft),transparent_55%),linear-gradient(90deg,transparent,color-mix(in_srgb,var(--info)_8%,transparent))]" />
              <div className="relative flex flex-col gap-5 p-5 sm:p-6 lg:flex-row lg:items-center lg:justify-between">
                <div className="flex items-start gap-4">
                  <SecureAvatar
                    name={data.user.fullName}
                    src={data.user.avatarUrl}
                    size="lg"
                    className="h-16 w-16 text-lg shadow-md ring-4 ring-elevated"
                  />
                  <div className="min-w-0 space-y-2">
                    <div>
                      <h2 className="font-display text-2xl tracking-tight text-primary">
                        {data.user.fullName}
                      </h2>
                      <p className="mt-0.5 text-sm text-secondary">
                        {data.businessName || 'Independent driver'}
                        <span className="mx-2 text-border-strong">·</span>
                        <span className="font-mono text-[12px] text-muted">
                          Joined {formatDate(data.createdAt)}
                        </span>
                      </p>
                    </div>
                    <div className="flex flex-wrap items-center gap-2">
                      <StatusBadge status={data.verificationStatus} />
                      <Badge variant={statusBadgeVariant(data.onlineStatus)}>
                        <OnlineIndicator status={data.onlineStatus} />
                      </Badge>
                      {data.user.status && (
                        <Badge variant={statusBadgeVariant(data.user.status)}>
                          Account {data.user.status}
                        </Badge>
                      )}
                      {pendingDocs > 0 && (
                        <Badge variant="warning">
                          {pendingDocs} pending review
                        </Badge>
                      )}
                    </div>
                  </div>
                </div>

                <div className="flex flex-wrap items-center gap-2 lg:justify-end">
                  <Select
                    value={data.verificationStatus}
                    onChange={(e) => verificationMutation.mutate(e.target.value)}
                    disabled={verificationMutation.isPending}
                    className="h-9 w-auto min-w-[150px] text-sm"
                  >
                    <option value="pending">Pending</option>
                    <option value="approved">Approved</option>
                    <option value="rejected">Rejected</option>
                    <option value="suspended">Suspended</option>
                  </Select>
                  {isOnline && (
                    <Button
                      variant="destructive"
                      size="sm"
                      loading={forceOfflineMutation.isPending}
                      onClick={() => forceOfflineMutation.mutate()}
                    >
                      <WifiOff className="h-4 w-4" />
                      Force Offline
                    </Button>
                  )}
                  <Button
                    variant="destructive"
                    size="sm"
                    onClick={() => setConfirmDelete(true)}
                  >
                    <Trash2 className="h-4 w-4" />
                    Delete
                  </Button>
                </div>
              </div>
            </section>

            {/* KPI strip */}
            <div className="grid gap-3 sm:grid-cols-2 xl:grid-cols-4">
              {[
                {
                  label: 'Commission',
                  value: `${(Number(data.commissionRate) * 100).toFixed(0)}%`,
                  icon: Percent,
                  tone: 'bg-accent-soft text-accent',
                },
                {
                  label: 'Avg. Rating',
                  value: Number(data.ratingAvg).toFixed(1),
                  icon: Star,
                  tone: 'bg-warning/10 text-warning',
                },
                {
                  label: 'Total rides',
                  value: data.totalJobs,
                  icon: Briefcase,
                  tone: 'bg-info/10 text-info',
                },
                {
                  label: 'Available to withdraw',
                  value: earningsWallet
                    ? formatCurrency(
                        Number(earningsWallet.available),
                        earningsWallet.currency,
                      )
                    : '—',
                  icon: Wallet,
                  tone: 'bg-success/10 text-success',
                },
              ].map((stat) => (
                <div
                  key={stat.label}
                  className="rounded-xl border border-border bg-elevated px-4 py-4 shadow-sm transition-colors hover:border-border-strong"
                >
                  <div className="flex items-center justify-between gap-3">
                    <div>
                      <p className="text-xs font-medium text-secondary">{stat.label}</p>
                      <p className="font-tabular font-display mt-1 text-2xl text-primary">
                        {stat.value}
                      </p>
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
                </div>
              ))}
            </div>

            <SegmentedTabs
              value={tab}
              onChange={(v) => setTab(v as TabId)}
              items={[
                { value: 'overview', label: 'Overview' },
                {
                  value: 'documents',
                  label: 'Documents',
                  count: data.documents?.length ?? 0,
                },
                {
                  value: 'jobs',
                  label: 'Rides',
                  count: data.jobs?.length ?? 0,
                },
                {
                  value: 'qualifications',
                  label: 'Qualifications',
                  count: jobQualifications.length,
                },
              ]}
            />

            {tab === 'overview' && (
              <div className="grid gap-6 lg:grid-cols-5">
                <Card className="lg:col-span-2">
                  <CardHeader className="pb-3">
                    <CardTitle className="text-base">Contact & Agreement</CardTitle>
                  </CardHeader>
                  <CardContent>
                    <MetaRow
                      icon={Phone}
                      label="Phone"
                      value={data.user.phone}
                      mono
                      copyable={data.user.phone}
                    />
                    <MetaRow
                      icon={Mail}
                      label="Email"
                      value={data.user.email ?? '—'}
                      copyable={data.user.email}
                    />
                    <MetaRow
                      icon={FileCheck}
                      label="Driver agreement"
                      value={
                        data.agreementAcceptedAt
                          ? `v${data.agreementVersionAccepted ?? '?'} · ${formatDate(data.agreementAcceptedAt)}`
                          : 'Not accepted'
                      }
                    />
                    <MetaRow
                      icon={Clock}
                      label="Member since"
                      value={formatDate(data.createdAt)}
                      mono
                    />
                    <MetaRow
                      icon={Wallet}
                      label="Driver plan"
                      value={
                        data.subscriptions?.find((s) => s.status === 'active')
                          ? `${data.subscriptions.find((s) => s.status === 'active')?.plan?.name ?? 'Active'}${
                              data.subscriptions.find((s) => s.status === 'active')?.expiresAt
                                ? ` · until ${formatDate(data.subscriptions.find((s) => s.status === 'active')!.expiresAt!)}`
                                : ''
                            }`
                          : 'None'
                      }
                    />
                  </CardContent>
                </Card>

                <Card className="lg:col-span-3">
                  <CardHeader className="flex-row items-center justify-between space-y-0 pb-3">
                    <div>
                      <CardTitle className="text-base">Commission</CardTitle>
                      <p className="mt-1 text-sm text-secondary">
                        Platform fee applied to completed jobs
                      </p>
                    </div>
                    {!editingCommission && (
                      <Button
                        variant="outline"
                        size="sm"
                        onClick={() => {
                          setCommissionPct(String(Number(data.commissionRate) * 100));
                          setEditingCommission(true);
                        }}
                      >
                        Edit rate
                      </Button>
                    )}
                  </CardHeader>
                  <CardContent>
                    {editingCommission ? (
                      <div className="flex flex-wrap items-end gap-2 rounded-xl border border-border bg-surface p-4">
                        <div className="min-w-[160px] flex-1">
                          <label className="mb-1.5 block text-xs text-secondary">
                            Rate (%)
                          </label>
                          <Input
                            type="number"
                            min="0"
                            max="100"
                            value={commissionPct}
                            onChange={(e) => setCommissionPct(e.target.value)}
                            placeholder="e.g. 15"
                          />
                        </div>
                        <Button
                          size="sm"
                          loading={commissionMutation.isPending}
                          onClick={() =>
                            commissionMutation.mutate(Number(commissionPct) / 100)
                          }
                        >
                          Save
                        </Button>
                        <Button
                          variant="ghost"
                          size="sm"
                          onClick={() => setEditingCommission(false)}
                        >
                          Cancel
                        </Button>
                      </div>
                    ) : (
                      <div className="grid gap-3 sm:grid-cols-3">
                        <div className="rounded-xl border border-border bg-surface p-4 sm:col-span-1">
                          <p className="text-xs font-medium text-secondary">Current rate</p>
                          <p className="font-tabular font-display mt-2 text-4xl text-accent">
                            {(Number(data.commissionRate) * 100).toFixed(0)}
                            <span className="text-xl">%</span>
                          </p>
                        </div>
                        <div className="rounded-xl border border-border bg-surface p-4 sm:col-span-2">
                          <p className="text-xs font-medium text-secondary">KYC progress</p>
                          <div className="mt-3 flex items-end justify-between gap-3">
                            <div>
                              <p className="font-tabular text-2xl font-semibold text-primary">
                                {approvedDocs}
                                <span className="text-base font-normal text-secondary">
                                  /{data.documents?.length ?? 0}
                                </span>
                              </p>
                              <p className="mt-1 text-xs text-muted">documents approved</p>
                            </div>
                            {pendingDocs > 0 && (
                              <Button
                                size="sm"
                                variant="outline"
                                onClick={() => setTab('documents')}
                              >
                                Review {pendingDocs} pending
                              </Button>
                            )}
                          </div>
                          <div className="mt-3 h-1.5 overflow-hidden rounded-full bg-border">
                            <div
                              className="h-full rounded-full bg-accent transition-all"
                              style={{
                                width: `${
                                  data.documents?.length
                                    ? (approvedDocs / data.documents.length) * 100
                                    : 0
                                }%`,
                              }}
                            />
                          </div>
                        </div>
                      </div>
                    )}
                  </CardContent>
                </Card>
              </div>
            )}

            {tab === 'documents' && (
              <div className="space-y-4">
              <Card>
                <CardHeader>
                  <CardTitle className="text-base">Agreements</CardTitle>
                </CardHeader>
                <CardContent className="space-y-3 text-sm">
                  {(agreements.data ?? []).map((row) => (
                    <div key={row.key} className="rounded-lg border border-border p-3">
                      <p className="font-medium text-primary">{row.title}</p>
                      <p className="text-secondary">
                        {row.accepted ? 'Accepted' : 'Not accepted'} · version {row.version}
                        {row.acceptedAt ? ` · ${formatDate(row.acceptedAt)}` : ''}
                        {' · '}Re-acceptance required: {row.reacceptanceRequired ? 'Yes' : 'No'}
                      </p>
                      {row.key === 'insurance' && (
                        <div className="mt-2 flex items-center justify-between gap-3">
                          <span className="text-secondary">Proof: {row.insuranceProofStatus || 'not_requested'}</span>
                          <Button size="sm" variant="outline" disabled={requestProof.isPending} onClick={() => requestProof.mutate()}>
                            Request proof
                          </Button>
                        </div>
                      )}
                    </div>
                  ))}
                </CardContent>
              </Card>
              <Card>
                <CardHeader className="flex-row items-center justify-between space-y-0 pb-3">
                  <div>
                    <CardTitle className="text-base">KYC Documents</CardTitle>
                    <p className="mt-1 text-sm text-secondary">
                      Review uploads and approve or reject verification files
                    </p>
                  </div>
                  {pendingDocs > 0 && (
                    <Badge variant="warning">{pendingDocs} awaiting review</Badge>
                  )}
                </CardHeader>
                <CardContent>
                  {!data.documents?.length ? (
                    <EmptyState
                      title="No documents"
                      description="This driver has not uploaded any verification documents."
                      className="py-12"
                    />
                  ) : (
                    <ul className="grid gap-3 xl:grid-cols-2">
                      {data.documents.map((doc) => (
                        <li
                          key={doc.id}
                          className="flex flex-col rounded-xl border border-border bg-surface p-4 transition-colors hover:border-accent/30"
                        >
                          <div className="flex items-start justify-between gap-3">
                            <div className="flex items-start gap-3">
                              <div className="flex h-10 w-10 shrink-0 items-center justify-center rounded-lg bg-accent-soft">
                                <FileText className="h-5 w-5 text-accent" />
                              </div>
                              <div>
                                <p className="font-medium text-primary">
                                  {doc.equipmentLabel || formatDocumentType(doc.docType)}
                                </p>
                                {doc.equipmentLabel && (
                                  <p className="text-xs text-secondary">
                                    {doc.serviceCategory?.name || 'Equipment'} · {formatDocumentType(doc.docType)}
                                  </p>
                                )}
                                {doc.createdAt && (
                                  <p className="mt-0.5 font-mono text-[11px] text-secondary">
                                    Submitted {formatDate(doc.createdAt)}
                                  </p>
                                )}
                                {doc.rejectionReason && (
                                  <p className="mt-1.5 text-xs text-danger">
                                    {doc.rejectionReason}
                                  </p>
                                )}
                              </div>
                            </div>
                            <StatusBadge status={doc.status} />
                          </div>
                          <div className="mt-auto flex flex-wrap gap-2 border-t border-border pt-3 mt-4">
                            {doc.fileUrl && (
                              <Button
                                size="sm"
                                variant="outline"
                                onClick={() => setPreviewDoc(doc)}
                              >
                                <Eye className="h-3.5 w-3.5" />
                                Preview
                              </Button>
                            )}
                            {isReviewable(doc.status) && (
                              <>
                                <Button
                                  size="sm"
                                  loading={reviewMutation.isPending}
                                  onClick={() =>
                                    reviewMutation.mutate({
                                      docId: doc.id,
                                      status: 'approved',
                                    })
                                  }
                                >
                                  <CheckCircle2 className="h-3.5 w-3.5" />
                                  {doc.status === 'rejected' ? 'Approve Anyway' : 'Approve'}
                                </Button>
                                {doc.status === 'pending' && (
                                  <Button
                                    size="sm"
                                    variant="destructive"
                                    onClick={() => setRejectDoc(doc)}
                                  >
                                    <XCircle className="h-3.5 w-3.5" />
                                    Reject
                                  </Button>
                                )}
                              </>
                            )}
                          </div>
                        </li>
                      ))}
                    </ul>
                  )}
                </CardContent>
              </Card>
              </div>
            )}

            {tab === 'jobs' && (
              <Card>
                <CardHeader className="pb-3">
                  <CardTitle className="text-base">Recent rides</CardTitle>
                  <p className="mt-1 text-sm text-secondary">
                    Latest jobs associated with this provider
                  </p>
                </CardHeader>
                <CardContent>
                  {!data.jobs?.length ? (
                    <EmptyState
                      title="No jobs yet"
                      description="This driver has not completed or received any jobs."
                      className="py-12"
                    />
                  ) : (
                    <div className="overflow-x-auto rounded-xl border border-border">
                      <table className="w-full text-sm">
                        <thead>
                          <tr className="border-b border-border bg-surface text-left text-xs text-secondary">
                            <th className="px-4 py-3 font-medium">Job #</th>
                            <th className="px-4 py-3 font-medium">Service</th>
                            <th className="px-4 py-3 font-medium">Status</th>
                            <th className="px-4 py-3 font-medium">Fare</th>
                            <th className="px-4 py-3 font-medium">Date</th>
                          </tr>
                        </thead>
                        <tbody>
                          {data.jobs.map((job) => (
                            <tr
                              key={job.id}
                              className="cursor-pointer border-b border-border/50 transition-colors last:border-0 hover:bg-surface/80"
                              onClick={() => router.push(`/jobs/${job.id}`)}
                            >
                              <td className="px-4 py-3 font-mono text-[13px] font-medium text-accent">
                                {job.jobNumber}
                              </td>
                              <td className="px-4 py-3 text-primary">
                                {job.serviceCategory?.name ?? '—'}
                              </td>
                              <td className="px-4 py-3">
                                <StatusBadge status={job.status} />
                              </td>
                              <td className="px-4 py-3 font-mono text-[13px] text-primary">
                                {job.finalFare
                                  ? formatCurrency(Number(job.finalFare))
                                  : job.estimatedFare
                                    ? formatCurrency(Number(job.estimatedFare))
                                    : '—'}
                              </td>
                              <td className="px-4 py-3 font-mono text-[13px] text-secondary">
                                {formatDate(job.createdAt)}
                              </td>
                            </tr>
                          ))}
                        </tbody>
                      </table>
                    </div>
                  )}
                </CardContent>
              </Card>
            )}

            {tab === 'qualifications' && (
              <Card>
                <CardHeader className="pb-3">
                  <CardTitle className="text-base">Job Type Qualifications</CardTitle>
                  <p className="mt-1 text-sm text-secondary">
                    Exam results for each job type this provider can be assigned
                  </p>
                </CardHeader>
                <CardContent>
                  {!jobQualifications.length ? (
                    <EmptyState
                      title="No qualifications yet"
                      description="This driver has not taken any job type exams."
                      className="py-12"
                    />
                  ) : (
                    <ul className="grid gap-3 xl:grid-cols-2">
                      {jobQualifications.map((qual) => {
                        const attempted =
                          qual.lastScore !== null && qual.lastScore !== undefined;
                        const state = qual.passed
                          ? { label: 'Passed', variant: 'success' as const }
                          : attempted
                            ? { label: 'Retake', variant: 'destructive' as const }
                            : { label: 'Not started', variant: 'secondary' as const };
                        return (
                          <li
                            key={qual.id}
                            className="flex items-start justify-between gap-3 rounded-xl border border-border bg-surface p-4"
                          >
                            <div className="flex items-start gap-3">
                              <div className="flex h-10 w-10 shrink-0 items-center justify-center rounded-lg bg-accent-soft">
                                <GraduationCap className="h-5 w-5 text-accent" />
                              </div>
                              <div>
                                <p className="font-medium text-primary">
                                  {qual.serviceCategory?.name || qual.title}
                                </p>
                                <p className="text-xs text-secondary">{qual.title}</p>
                                <p className="mt-0.5 font-mono text-[11px] text-secondary">
                                  {attempted
                                    ? `Score ${qual.lastScore}%${qual.passPercent ? ` · pass ${qual.passPercent}%` : ''}`
                                    : 'No attempt yet'}
                                </p>
                              </div>
                            </div>
                            <Badge variant={state.variant}>{state.label}</Badge>
                          </li>
                        );
                      })}
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
        title="Delete driver?"
        description={
          data
            ? `${data.user.fullName} (${data.user.phone}) will be permanently removed. Jobs they served stay with the customer, and this driver is unassigned.`
            : 'This driver will be permanently removed.'
        }
        confirmLabel="Delete driver"
        loading={deleteMutation.isPending}
        onClose={() => setConfirmDelete(false)}
        onConfirm={() => deleteMutation.mutate()}
      />

      <Modal
        open={!!previewDoc}
        onClose={() => setPreviewDoc(null)}
        title={`Document — ${previewDoc ? formatDocumentType(previewDoc.docType) : ''}`}
        className={previewDoc?.docType === 'selfie' ? 'max-w-4xl' : 'max-w-2xl'}
      >
        {previewDoc?.fileUrl && (
          <div className="space-y-4">
            {previewDoc.docType === 'selfie' ? (
              <div className="space-y-3">
                <p className="text-sm text-secondary">
                  Compare the identity selfie with the driver license to confirm they match.
                </p>
                <div className="grid gap-4 sm:grid-cols-2">
                  <div className="space-y-2">
                    <p className="text-xs font-semibold uppercase tracking-wide text-secondary">
                      Identity Selfie
                    </p>
                    <SecureFilePreview
                      fileUrl={previewDoc.fileUrl}
                      title="Identity Selfie"
                    />
                  </div>
                  <div className="space-y-2">
                    <p className="text-xs font-semibold uppercase tracking-wide text-secondary">
                      Driver License (Front)
                    </p>
                    {(() => {
                      const licenseFront = data?.documents?.find((d) => d.docType === 'license');
                      return licenseFront?.fileUrl ? (
                        <SecureFilePreview
                          fileUrl={licenseFront.fileUrl}
                          title="Driver License (Front)"
                        />
                      ) : (
                        <p className="rounded-lg border border-border bg-surface p-4 text-sm text-secondary">
                          No license front uploaded yet.
                        </p>
                      );
                    })()}
                    {(() => {
                      const licenseBack = data?.documents?.find((d) => d.docType === 'id_card');
                      return licenseBack?.fileUrl ? (
                        <div className="space-y-2 pt-2">
                          <p className="text-xs font-semibold uppercase tracking-wide text-secondary">
                            Driver License (Back)
                          </p>
                          <SecureFilePreview
                            fileUrl={licenseBack.fileUrl}
                            title="Driver License (Back)"
                          />
                        </div>
                      ) : null;
                    })()}
                  </div>
                </div>
              </div>
            ) : (
              <SecureFilePreview
                fileUrl={previewDoc.fileUrl}
                title={`Document — ${formatDocumentType(previewDoc.docType)}`}
              />
            )}
            {previewDoc && isReviewable(previewDoc.status) && (
              <div className="flex gap-2">
                <Button
                  loading={reviewMutation.isPending}
                  onClick={() =>
                    reviewMutation.mutate({ docId: previewDoc.id, status: 'approved' })
                  }
                >
                  {previewDoc.status === 'rejected' ? 'Approve Anyway' : 'Approve'}
                </Button>
                {previewDoc.status === 'pending' && (
                  <Button
                    variant="destructive"
                    onClick={() => {
                      setRejectDoc(previewDoc);
                      setPreviewDoc(null);
                    }}
                  >
                    Reject
                  </Button>
                )}
              </div>
            )}
          </div>
        )}
      </Modal>

      <Modal
        open={!!rejectDoc}
        onClose={() => {
          setRejectDoc(null);
          setRejectReason('');
        }}
        title="Reject Document"
        description="Provide a reason for rejection. The driver will be notified."
      >
        <div className="space-y-4">
          <Textarea
            placeholder="Reason for rejection..."
            value={rejectReason}
            onChange={(e) => setRejectReason(e.target.value)}
            rows={4}
          />
          <div className="flex justify-end gap-2">
            <Button variant="outline" onClick={() => setRejectDoc(null)}>
              Cancel
            </Button>
            <Button
              variant="destructive"
              disabled={!rejectReason.trim()}
              loading={reviewMutation.isPending}
              onClick={() =>
                rejectDoc &&
                reviewMutation.mutate({
                  docId: rejectDoc.id,
                  status: 'rejected',
                  reason: rejectReason.trim(),
                })
              }
            >
              Confirm Reject
            </Button>
          </div>
        </div>
      </Modal>
    </>
  );
}
