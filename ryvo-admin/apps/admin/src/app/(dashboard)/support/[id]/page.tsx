'use client';

import { useState } from 'react';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { useParams } from 'next/navigation';
import Link from 'next/link';
import { Header } from '@/components/layout/header';
import { PageContent } from '@/components/layout/page-content';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Badge, statusBadgeVariant } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { Select } from '@/components/ui/select';
import { Textarea } from '@/components/ui/textarea';
import { Toast, useToast } from '@/components/ui/toast';
import { apiFetch, apiMutate } from '@/lib/api';
import { formatDate } from '@/lib/utils';
import { ArrowLeft } from 'lucide-react';

interface TicketMessage {
  id: string;
  message: string;
  senderType: string;
  createdAt: string;
  sender?: { fullName: string; role?: string };
}

interface TicketDetail {
  id: string;
  ticketNumber: string;
  subject: string;
  category: string;
  status: string;
  priority: string;
  createdAt: string;
  assignedToId?: string | null;
  user?: { fullName: string; phone: string; role?: string };
  assignedTo?: { id: string; user: { fullName: string } };
  job?: { id: string; jobNumber: string };
  messages?: TicketMessage[];
}

interface AdminUser {
  id: string;
  user: { fullName: string };
}

const TICKET_STATUSES = ['open', 'in_progress', 'resolved', 'closed'] as const;
const PRIORITIES = ['low', 'medium', 'high', 'urgent'] as const;

export default function SupportDetailPage() {
  const { id } = useParams<{ id: string }>();
  const queryClient = useQueryClient();
  const { toast, show } = useToast();
  const [reply, setReply] = useState('');

  const { data, isLoading, error } = useQuery({
    queryKey: ['support-ticket', id],
    queryFn: async () => {
      const res = await apiFetch<TicketDetail>(`/admin/support/tickets/${id}`);
      return res.data!;
    },
    enabled: !!id,
  });

  const replyMutation = useMutation({
    mutationFn: () =>
      apiMutate(`/admin/support/tickets/${id}/messages`, 'POST', { message: reply }),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['support-ticket', id] });
      setReply('');
      show('Reply sent');
    },
    onError: (err: Error) => show(err.message, 'error'),
  });

  const statusMutation = useMutation({
    mutationFn: (status: string) =>
      apiMutate(`/admin/support/tickets/${id}/status`, 'PATCH', { status }),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['support-ticket', id] });
      show('Status updated');
    },
    onError: (err: Error) => show(err.message, 'error'),
  });

  const priorityMutation = useMutation({
    mutationFn: (priority: string) =>
      apiMutate(`/admin/support/tickets/${id}/priority`, 'PATCH', { priority }),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['support-ticket', id] });
      show('Priority updated');
    },
    onError: (err: Error) => show(err.message, 'error'),
  });

  const { data: admins } = useQuery({
    queryKey: ['admin-users-assign'],
    queryFn: async () => {
      const res = await apiFetch<AdminUser[]>('/admin/users?limit=50');
      return res.data ?? [];
    },
  });

  const assignMutation = useMutation({
    mutationFn: (adminUserId: string) =>
      apiMutate(`/admin/support/tickets/${id}/assign`, 'PATCH', { adminUserId }),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['support-ticket', id] });
      show('Ticket assigned');
    },
    onError: (err: Error) => show(err.message, 'error'),
  });

  const unassignMutation = useMutation({
    mutationFn: () => apiMutate(`/admin/support/tickets/${id}/unassign`, 'PATCH'),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['support-ticket', id] });
      show('Ticket unassigned');
    },
    onError: (err: Error) => show(err.message, 'error'),
  });

  return (
    <>
      <Header
        title={data ? `${data.ticketNumber}` : 'Ticket Detail'}
        description={data?.subject}
      />
      <PageContent>
        <Link href="/support">
          <Button variant="ghost" size="sm" className="mb-4">
            <ArrowLeft className="mr-2 h-4 w-4" />
            Back to Support
          </Button>
        </Link>

        {isLoading && <p className="text-sm text-muted">Loading...</p>}
        {error && <p className="text-sm text-danger">Failed to load ticket</p>}

        {data && (
          <div className="grid gap-6 lg:grid-cols-3">
            <Card className="lg:col-span-2">
              <CardHeader>
                <div className="flex flex-wrap items-center justify-between gap-2">
                  <CardTitle>{data.subject}</CardTitle>
                  <div className="flex gap-2">
                    <Badge variant={statusBadgeVariant(data.priority)}>{data.priority}</Badge>
                    <Badge variant={statusBadgeVariant(data.status)}>{data.status}</Badge>
                  </div>
                </div>
              </CardHeader>
              <CardContent>
                {!data.messages?.length ? (
                  <p className="text-sm text-muted">No messages yet.</p>
                ) : (
                  <ul className="mb-4 space-y-4">
                    {data.messages.map((msg) => (
                      <li key={msg.id} className="rounded-lg border border-border bg-surface px-4 py-3">
                        <div className="mb-1 flex items-center justify-between text-xs text-muted">
                          <span>
                            {msg.sender?.fullName
                              ? `${msg.sender.fullName} (${msg.senderType})`
                              : msg.senderType}
                          </span>
                          <span>{formatDate(msg.createdAt)}</span>
                        </div>
                        <p className="text-sm text-primary">{msg.message}</p>
                      </li>
                    ))}
                  </ul>
                )}
                <div className="space-y-2">
                  <Textarea
                    placeholder="Write a reply..."
                    value={reply}
                    onChange={(e) => setReply(e.target.value)}
                  />
                  <Button
                    disabled={!reply.trim() || replyMutation.isPending}
                    onClick={() => replyMutation.mutate()}
                  >
                    Send Reply
                  </Button>
                </div>
              </CardContent>
            </Card>

            <Card>
              <CardHeader>
                <CardTitle>Details</CardTitle>
              </CardHeader>
              <CardContent className="space-y-4 text-sm">
                <div className="flex items-center justify-between border-b border-border pb-3">
                  <span className="text-secondary">Category</span>
                  <span className="text-primary">{data.category}</span>
                </div>
                <div className="flex items-center justify-between border-b border-border pb-3">
                  <span className="text-secondary">User</span>
                  <span className="text-right text-primary">
                    {data.user?.fullName ?? '—'}
                    {data.user?.role ? (
                      <>
                        <br />
                        <span className="text-xs capitalize text-muted">{data.user.role}</span>
                      </>
                    ) : null}
                    <br />
                    <span className="font-mono text-xs text-muted">{data.user?.phone}</span>
                  </span>
                </div>
                {data.job && (
                  <div className="flex items-center justify-between border-b border-border pb-3">
                    <span className="text-secondary">Related job</span>
                    <Link href={`/jobs/${data.job.id}`} className="font-mono text-[13px] text-accent hover:underline">
                      {data.job.jobNumber}
                    </Link>
                  </div>
                )}
                <div className="flex items-center justify-between border-b border-border pb-3">
                  <span className="text-secondary">Created</span>
                  <span className="font-mono text-[13px] text-primary">{formatDate(data.createdAt)}</span>
                </div>
                <div className="space-y-2">
                  <label className="text-secondary">Priority</label>
                  <Select
                    value={data.priority}
                    onChange={(e) => priorityMutation.mutate(e.target.value)}
                    disabled={priorityMutation.isPending}
                  >
                    {PRIORITIES.map((p) => (
                      <option key={p} value={p}>{p}</option>
                    ))}
                  </Select>
                </div>
                <div className="space-y-2">
                  <label className="text-secondary">Status</label>
                  <Select
                    value={data.status}
                    onChange={(e) => statusMutation.mutate(e.target.value)}
                    disabled={statusMutation.isPending}
                  >
                    {TICKET_STATUSES.map((s) => (
                      <option key={s} value={s}>{s.replace('_', ' ')}</option>
                    ))}
                  </Select>
                </div>
                <div className="space-y-2">
                  <label className="text-secondary">Assigned to</label>
                  <Select
                    value={data.assignedToId ?? ''}
                    onChange={(e) => {
                      if (e.target.value) assignMutation.mutate(e.target.value);
                      else unassignMutation.mutate();
                    }}
                    disabled={assignMutation.isPending || unassignMutation.isPending}
                  >
                    <option value="">Unassigned</option>
                    {(admins ?? []).map((a) => (
                      <option key={a.id} value={a.id}>{a.user.fullName}</option>
                    ))}
                  </Select>
                </div>
              </CardContent>
            </Card>
          </div>
        )}
      </PageContent>
      {toast && <Toast message={toast.message} type={toast.type} />}
    </>
  );
}
