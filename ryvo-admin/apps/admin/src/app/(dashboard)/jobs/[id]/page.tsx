'use client';

import { useState } from 'react';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { useParams } from 'next/navigation';
import Link from 'next/link';
import { Header } from '@/components/layout/header';
import { PageContent } from '@/components/layout/page-content';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Badge, StatusBadge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { Select } from '@/components/ui/select';
import { Input } from '@/components/ui/input';
import { Textarea } from '@/components/ui/textarea';
import { SegmentedTabs } from '@/components/ui/segmented-tabs';
import { Dialog } from '@/components/ui/dialog';
import { Toast, useToast } from '@/components/ui/toast';
import { LiveMap } from '@/components/live-map';
import { useMapApiKey } from '@/hooks/use-map-api-key';
import { apiFetch, apiMutate, buildQuery } from '@/lib/api';
import { formatCurrency, formatDate } from '@/lib/utils';
import { ArrowLeft } from 'lucide-react';
import type { MapMarker } from '@/lib/google-maps';

interface JobDetail {
  id: string;
  jobNumber: string;
  status: string;
  estimatedFare?: number;
  finalFare?: number;
  pickupAddress?: string;
  dropoffAddress?: string;
  pickupLat?: number;
  pickupLng?: number;
  dropoffLat?: number;
  dropoffLng?: number;
  createdAt: string;
  completedAt?: string;
  customer?: { user: { fullName: string; phone: string } };
  provider?: { id: string; user: { fullName: string; phone: string } };
  serviceCategory?: { name: string };
  payment?: { method: string; status: string; amount: number } | null;
}

interface TimelineEntry {
  id: string;
  fromStatus: string | null;
  toStatus: string;
  changedByType: string;
  note?: string;
  createdAt: string;
}

interface LocationPoint {
  id: string;
  lat: number;
  lng: number;
  recordedAt: string;
}

interface ProviderOption {
  id: string;
  user: { fullName: string; phone: string };
  onlineStatus: string;
}

const JOB_STATUSES = [
  'draft',
  'searching',
  'matched',
  'provider_en_route',
  'arrived',
  'in_progress',
  'completed',
  'payment_pending',
  'cancelled_by_admin',
  'cancelled_by_customer',
  'cancelled_by_provider',
  'no_provider_found',
] as const;

const CANCELLABLE = new Set([
  'draft',
  'searching',
  'matched',
  'provider_en_route',
  'arrived',
  'in_progress',
  'payment_pending',
]);

const TABS = [
  { id: 'overview', label: 'Overview' },
  { id: 'timeline', label: 'Timeline' },
  { id: 'map', label: 'Location Trail' },
  { id: 'actions', label: 'Actions' },
] as const;

type TabId = (typeof TABS)[number]['id'];

export default function JobDetailPage() {
  const { id } = useParams<{ id: string }>();
  const queryClient = useQueryClient();
  const { toast, show } = useToast();
  const { data: mapApiKey } = useMapApiKey();
  const [activeTab, setActiveTab] = useState<TabId>('overview');
  const [assignOpen, setAssignOpen] = useState(false);
  const [selectedProvider, setSelectedProvider] = useState('');
  const [statusNote, setStatusNote] = useState('');
  const [newStatus, setNewStatus] = useState('');
  const [refundReason, setRefundReason] = useState('');
  const [cancelReason, setCancelReason] = useState('');

  const { data, isLoading, error } = useQuery({
    queryKey: ['job', id],
    queryFn: async () => {
      const res = await apiFetch<JobDetail>(`/admin/jobs/${id}`);
      return res.data!;
    },
    enabled: !!id,
  });

  const { data: timeline, isLoading: timelineLoading } = useQuery({
    queryKey: ['job-timeline', id],
    queryFn: async () => {
      const res = await apiFetch<TimelineEntry[]>(`/admin/jobs/${id}/timeline`);
      return res.data ?? [];
    },
    enabled: !!id,
  });

  const { data: locationTrail } = useQuery({
    queryKey: ['job-location-trail', id],
    queryFn: async () => {
      const res = await apiFetch<LocationPoint[]>(`/admin/jobs/${id}/location-trail`);
      return res.data ?? [];
    },
    enabled: !!id && activeTab === 'map',
  });

  const { data: providers } = useQuery({
    queryKey: ['providers-online'],
    queryFn: async () => {
      const res = await apiFetch<ProviderOption[]>(
        `/admin/providers${buildQuery({ onlineStatus: 'online', limit: 50 })}`,
      );
      return res.data ?? [];
    },
    enabled: assignOpen,
  });

  const cancelMutation = useMutation({
    mutationFn: () => apiMutate(`/admin/jobs/${id}/cancel`, 'PATCH', { reason: cancelReason }),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['job', id] });
      queryClient.invalidateQueries({ queryKey: ['job-timeline', id] });
      setCancelReason('');
      show('Job cancelled');
    },
    onError: (err: Error) => show(err.message, 'error'),
  });

  const assignMutation = useMutation({
    mutationFn: () =>
      apiMutate(`/admin/jobs/${id}/assign-provider`, 'PATCH', { providerId: selectedProvider }),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['job', id] });
      queryClient.invalidateQueries({ queryKey: ['job-timeline', id] });
      setAssignOpen(false);
      setSelectedProvider('');
      show('Driver assigned');
    },
    onError: (err: Error) => show(err.message, 'error'),
  });

  const statusMutation = useMutation({
    mutationFn: () =>
      apiMutate(`/admin/jobs/${id}/status`, 'PATCH', { status: newStatus, note: statusNote }),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['job', id] });
      queryClient.invalidateQueries({ queryKey: ['job-timeline', id] });
      setStatusNote('');
      show('Status updated');
    },
    onError: (err: Error) => show(err.message, 'error'),
  });

  const retryPayment = useMutation({
    mutationFn: () => apiMutate(`/admin/payments/job/${id}/retry`, 'POST'),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['job', id] });
      show('Payment retry finished');
    },
    onError: (err: Error) => show(err.message, 'error'),
  });

  const refundMutation = useMutation({
    mutationFn: () =>
      apiMutate(`/admin/payments/job/${id}/refund`, 'POST', { reason: refundReason }),
    onSuccess: () => {
      setRefundReason('');
      show('Refund processed');
    },
    onError: (err: Error) => show(err.message, 'error'),
  });

  const canCancel = data && CANCELLABLE.has(data.status);

  const trailMarkers: MapMarker[] = (locationTrail ?? []).map((p, i) => ({
    id: p.id,
    lat: Number(p.lat),
    lng: Number(p.lng),
    label: String(i + 1),
    title: formatDate(p.recordedAt),
  }));

  if (data?.pickupLat && data?.pickupLng) {
    trailMarkers.unshift({
      id: 'pickup',
      lat: Number(data.pickupLat),
      lng: Number(data.pickupLng),
      label: 'P',
      title: 'Pickup',
    });
  }
  if (data?.dropoffLat && data?.dropoffLng) {
    trailMarkers.push({
      id: 'dropoff',
      lat: Number(data.dropoffLat),
      lng: Number(data.dropoffLng),
      label: 'D',
      title: 'Dropoff',
    });
  }

  return (
    <>
      <Header title={data ? data.jobNumber : 'Ride'} description={data?.serviceCategory?.name ?? 'Ride detail'} />
      <PageContent>
        <Link href="/jobs">
          <Button variant="ghost" size="sm" className="mb-4">
            <ArrowLeft className="mr-2 h-4 w-4" />
            Back to Rides
          </Button>
        </Link>

        {isLoading && <p className="text-sm text-muted">Loading...</p>}
        {error && <p className="text-sm text-danger">Failed to load job</p>}

        {data && (
          <div className="space-y-6">
            <div className="flex flex-wrap items-center justify-between gap-3">
              <div>
                <h2 className="font-mono text-lg text-primary">{data.jobNumber}</h2>
                <p className="text-sm text-secondary">{data.serviceCategory?.name}</p>
              </div>
              <StatusBadge status={data.status} />
            </div>

            <SegmentedTabs
              items={TABS.map((t) => ({ value: t.id, label: t.label }))}
              value={activeTab}
              onChange={(v) => setActiveTab(v as TabId)}
            />

            {activeTab === 'overview' && (
              <div className="grid gap-6 lg:grid-cols-2">
                <Card>
                  <CardHeader>
                    <CardTitle>Ride</CardTitle>
                  </CardHeader>
                  <CardContent className="space-y-3 text-sm">
                    <div className="flex justify-between border-b border-border pb-3">
                      <span className="text-secondary">Estimated Fare</span>
                      <span className="font-mono">{formatCurrency(Number(data.estimatedFare ?? 0))}</span>
                    </div>
                    <div className="flex justify-between border-b border-border pb-3">
                      <span className="text-secondary">Final Fare</span>
                      <span className="font-mono font-medium">
                        {data.finalFare ? formatCurrency(Number(data.finalFare)) : '—'}
                      </span>
                    </div>
                    <div className="flex justify-between border-b border-border pb-3">
                      <span className="text-secondary">Ride type</span>
                      <span>{data.serviceCategory?.name ?? '—'}</span>
                    </div>
                    <div className="flex justify-between border-b border-border pb-3">
                      <span className="text-secondary">Payment</span>
                      <span className="capitalize">
                        {data.payment
                          ? `${data.payment.method} · ${data.payment.status}`
                          : '—'}
                      </span>
                    </div>
                    <div className="flex justify-between">
                      <span className="text-secondary">Created</span>
                      <span className="font-mono text-xs">{formatDate(data.createdAt)}</span>
                    </div>
                  </CardContent>
                </Card>

                <Card>
                  <CardHeader>
                    <CardTitle>Route & Parties</CardTitle>
                  </CardHeader>
                  <CardContent className="space-y-3 text-sm">
                    <div>
                      <p className="text-xs text-muted">Pickup</p>
                      <p>{data.pickupAddress ?? '—'}</p>
                    </div>
                    <div>
                      <p className="text-xs text-muted">Dropoff</p>
                      <p>{data.dropoffAddress ?? '—'}</p>
                    </div>
                    <div>
                      <p className="text-xs text-muted">Rider</p>
                      <p>{data.customer?.user.fullName ?? '—'} · {data.customer?.user.phone ?? ''}</p>
                    </div>
                    <div>
                      <p className="text-xs text-muted">Driver</p>
                      <p>
                        {data.provider?.user.fullName ?? 'Unassigned'}
                        {data.provider?.user.phone ? ` · ${data.provider.user.phone}` : ''}
                      </p>
                    </div>
                  </CardContent>
                </Card>
              </div>
            )}

            {activeTab === 'timeline' && (
              <Card>
                <CardHeader>
                  <CardTitle>Status Timeline</CardTitle>
                </CardHeader>
                <CardContent>
                  {timelineLoading ? (
                    <p className="text-sm text-muted">Loading timeline...</p>
                  ) : !timeline?.length ? (
                    <p className="text-sm text-muted">No status history yet.</p>
                  ) : (
                    <ul className="space-y-3">
                      {timeline.map((entry) => (
                        <li
                          key={entry.id}
                          className="flex items-start justify-between rounded-lg bg-surface px-4 py-3 text-sm"
                        >
                          <div>
                            <p className="flex items-center gap-1.5">
                              {entry.fromStatus && (
                                <>
                                  <Badge variant="outline">{entry.fromStatus}</Badge>
                                  <span className="text-muted">→</span>
                                </>
                              )}
                              <StatusBadge status={entry.toStatus} />
                            </p>
                            {entry.note && (
                              <p className="mt-1.5 text-xs text-secondary">{entry.note}</p>
                            )}
                            <p className="mt-1 text-xs capitalize text-muted">by {entry.changedByType}</p>
                          </div>
                          <span className="shrink-0 font-mono text-xs text-muted">
                            {formatDate(entry.createdAt)}
                          </span>
                        </li>
                      ))}
                    </ul>
                  )}
                </CardContent>
              </Card>
            )}

            {activeTab === 'map' && (
              <Card>
                <CardHeader>
                  <CardTitle>Location Trail</CardTitle>
                </CardHeader>
                <CardContent>
                  {!mapApiKey ? (
                    <p className="text-sm text-warning">Configure Google Maps API key in Settings.</p>
                  ) : trailMarkers.length === 0 ? (
                    <p className="text-sm text-muted">No location data recorded for this job.</p>
                  ) : (
                    <LiveMap apiKey={mapApiKey!} markers={trailMarkers} className="h-[360px] w-full rounded-lg" />
                  )}
                  {locationTrail && locationTrail.length > 0 && (
                    <p className="mt-2 text-xs text-muted">{locationTrail.length} GPS points recorded</p>
                  )}
                </CardContent>
              </Card>
            )}

            {activeTab === 'actions' && (
              <div className="grid gap-6 lg:grid-cols-2">
                <Card>
                  <CardHeader>
                    <CardTitle>Assign driver</CardTitle>
                  </CardHeader>
                  <CardContent>
                    <Button onClick={() => setAssignOpen(true)}>Assign driver</Button>
                  </CardContent>
                </Card>

                <Card>
                  <CardHeader>
                    <CardTitle>Override Status</CardTitle>
                  </CardHeader>
                  <CardContent className="space-y-3">
                    <Select
                      value={newStatus || data.status}
                      onChange={(e) => setNewStatus(e.target.value)}
                    >
                      {JOB_STATUSES.map((s) => (
                        <option key={s} value={s}>
                          {s.replace(/_/g, ' ')}
                        </option>
                      ))}
                    </Select>
                    <Textarea
                      placeholder="Note (optional)"
                      value={statusNote}
                      onChange={(e) => setStatusNote(e.target.value)}
                    />
                    <Button
                      disabled={statusMutation.isPending || !newStatus}
                      onClick={() => statusMutation.mutate()}
                    >
                      Update Status
                    </Button>
                  </CardContent>
                </Card>

                {data.payment?.status === 'failed' && (
                  <Card>
                    <CardHeader>
                      <CardTitle>Retry payment</CardTitle>
                    </CardHeader>
                    <CardContent>
                      <p className="mb-3 text-sm text-secondary">
                        The trip ended, but the {data.payment.method} charge failed.
                      </p>
                      <Button disabled={retryPayment.isPending} onClick={() => retryPayment.mutate()}>
                        Charge again
                      </Button>
                    </CardContent>
                  </Card>
                )}

                <Card>
                  <CardHeader>
                    <CardTitle>Refund Payment</CardTitle>
                  </CardHeader>
                  <CardContent className="space-y-3">
                    <Textarea
                      placeholder="Refund reason (optional)"
                      value={refundReason}
                      onChange={(e) => setRefundReason(e.target.value)}
                    />
                    <Button
                      variant="destructive"
                      disabled={refundMutation.isPending}
                      onClick={() => refundMutation.mutate()}
                    >
                      Process Refund
                    </Button>
                  </CardContent>
                </Card>

                {canCancel && (
                  <Card>
                    <CardHeader>
                      <CardTitle>Cancel Job</CardTitle>
                    </CardHeader>
                    <CardContent className="space-y-3">
                      <Input
                        placeholder="Cancellation reason (optional)"
                        value={cancelReason}
                        onChange={(e) => setCancelReason(e.target.value)}
                      />
                      <Button
                        variant="destructive"
                        disabled={cancelMutation.isPending}
                        onClick={() => cancelMutation.mutate()}
                      >
                        Cancel Job
                      </Button>
                    </CardContent>
                  </Card>
                )}
              </div>
            )}
          </div>
        )}
      </PageContent>

      <Dialog open={assignOpen} onClose={() => setAssignOpen(false)} title="Assign Driver">
        <div className="space-y-4">
          <Select
            value={selectedProvider}
            onChange={(e) => setSelectedProvider(e.target.value)}
          >
            <option value="">Select online provider...</option>
            {(providers ?? []).map((p) => (
              <option key={p.id} value={p.id}>
                {p.user.fullName} · {p.user.phone}
              </option>
            ))}
          </Select>
          <div className="flex justify-end gap-2">
            <Button variant="ghost" onClick={() => setAssignOpen(false)}>
              Cancel
            </Button>
            <Button
              disabled={!selectedProvider || assignMutation.isPending}
              onClick={() => assignMutation.mutate()}
            >
              Assign
            </Button>
          </div>
        </div>
      </Dialog>

      {toast && <Toast message={toast.message} type={toast.type} />}
    </>
  );
}
