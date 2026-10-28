'use client';

import { useState } from 'react';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { useRouter } from 'next/navigation';
import { Header } from '@/components/layout/header';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Select } from '@/components/ui/select';
import { Dialog } from '@/components/ui/dialog';
import { StatusBadge } from '@/components/ui/badge';
import { Toast, useToast } from '@/components/ui/toast';
import { apiFetch, apiMutate, buildQuery } from '@/lib/api';
import { formatDate } from '@/lib/utils';
import { Clock, User } from 'lucide-react';

interface DispatchJob {
  id: string;
  jobNumber: string;
  status: string;
  createdAt: string;
  pickupAddress?: string;
  dropoffAddress?: string;
  customer?: { user: { fullName: string } };
  serviceCategory?: { name: string };
  _count?: { offers: number };
}

interface ProviderOption {
  id: string;
  user: { fullName: string; phone: string };
}

function slaMinutes(createdAt: string) {
  return Math.floor((Date.now() - new Date(createdAt).getTime()) / 60000);
}

export default function DispatchPage() {
  const router = useRouter();
  const queryClient = useQueryClient();
  const { toast, show } = useToast();
  const [assignJob, setAssignJob] = useState<DispatchJob | null>(null);
  const [selectedProvider, setSelectedProvider] = useState('');

  const { data, isLoading, error, dataUpdatedAt } = useQuery({
    queryKey: ['dispatch-jobs'],
    queryFn: async () => {
      const res = await apiFetch<{ activeJobs: DispatchJob[] }>('/admin/dashboard/live');
      return (res.data?.activeJobs ?? []).filter((j) => j.status === 'searching');
    },
    refetchInterval: 15_000,
  });

  const { data: providers } = useQuery({
    queryKey: ['dispatch-providers'],
    queryFn: async () => {
      const res = await apiFetch<ProviderOption[]>(
        `/admin/providers${buildQuery({ onlineStatus: 'online', limit: 50 })}`,
      );
      return res.data ?? [];
    },
    enabled: !!assignJob,
  });

  const assignMutation = useMutation({
    mutationFn: () =>
      apiMutate(`/admin/jobs/${assignJob!.id}/assign-provider`, 'PATCH', {
        providerId: selectedProvider,
      }),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['dispatch-jobs'] });
      setAssignJob(null);
      setSelectedProvider('');
      show('Driver assigned');
    },
    onError: (err: Error) => show(err.message, 'error'),
  });

  return (
    <>
      <Header
        title="Dispatch"
        description="Rides still looking for a driver"
      />
      <div className="flex-1 overflow-y-auto p-4 lg:p-6">
        <p className="mb-4 text-xs text-muted">
          Last updated {formatDate(new Date(dataUpdatedAt))} · auto-refresh every 15s
        </p>

        {isLoading && <p className="text-sm text-muted">Loading dispatch queue...</p>}
        {error && <p className="text-sm text-danger">Failed to load dispatch data</p>}

        {!isLoading && !data?.length && (
          <Card>
            <CardContent className="py-12 text-center text-secondary">
              No rides are waiting for a driver.
            </CardContent>
          </Card>
        )}

        <div className="grid gap-4 lg:grid-cols-2">
          {(data ?? []).map((job) => {
            const minutes = slaMinutes(job.createdAt);
            const urgent = minutes >= 5;
            return (
              <Card key={job.id} className={urgent ? 'border-warning/50' : undefined}>
                <CardHeader className="pb-2">
                  <div className="flex items-center justify-between">
                    <CardTitle className="font-mono text-base">{job.jobNumber}</CardTitle>
                    <StatusBadge status={job.status} />
                  </div>
                </CardHeader>
                <CardContent className="space-y-3 text-sm">
                  <p className="text-secondary">{job.serviceCategory?.name} · {job.customer?.user.fullName}</p>
                  <p className="text-primary">Pickup · {job.pickupAddress ?? 'No pickup address'}</p>
                  <p className="text-secondary">Dropoff · {job.dropoffAddress ?? 'No dropoff'}</p>
                  <div className="flex items-center gap-4 text-xs text-muted">
                    <span className="inline-flex items-center gap-1">
                      <Clock className="h-3.5 w-3.5" />
                      {minutes}m waiting {urgent && <span className="text-warning font-medium">· SLA risk</span>}
                    </span>
                    <span>{job._count?.offers ?? 0} offers sent</span>
                  </div>
                  <div className="flex gap-2 pt-1">
                    <Button size="sm" onClick={() => setAssignJob(job)}>
                      <User className="mr-1 h-3.5 w-3.5" />
                      Assign driver
                    </Button>
                    <Button size="sm" variant="ghost" onClick={() => router.push(`/jobs/${job.id}`)}>
                      View ride
                    </Button>
                  </div>
                </CardContent>
              </Card>
            );
          })}
        </div>
      </div>

      <Dialog open={!!assignJob} onClose={() => setAssignJob(null)} title={`Assign — ${assignJob?.jobNumber}`}>
        <div className="space-y-4">
          <Select value={selectedProvider} onChange={(e) => setSelectedProvider(e.target.value)}>
            <option value="">Select an online driver...</option>
            {(providers ?? []).map((p) => (
              <option key={p.id} value={p.id}>
                {p.user.fullName} · {p.user.phone}
              </option>
            ))}
          </Select>
          <div className="flex justify-end gap-2">
            <Button variant="ghost" onClick={() => setAssignJob(null)}>Cancel</Button>
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
