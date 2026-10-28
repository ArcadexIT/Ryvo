'use client';

import { useMemo, useState } from 'react';
import { useQuery } from '@tanstack/react-query';
import { useRouter } from 'next/navigation';
import { Header } from '@/components/layout/header';
import { PageContent } from '@/components/layout/page-content';
import { DataTable, type Column } from '@/components/data-table';
import { Badge, statusBadgeVariant } from '@/components/ui/badge';
import { apiFetch, buildQuery } from '@/lib/api';
import { formatDate } from '@/lib/utils';

interface SupportTicket {
  id: string;
  ticketNumber: string;
  subject: string;
  category: string;
  status: string;
  priority: string;
  createdAt: string;
  user?: { fullName: string };
}

interface AdminUser {
  id: string;
  user: { fullName: string };
}

export default function SupportPage() {
  const router = useRouter();
  const [page, setPage] = useState(1);
  const [statusFilter, setStatusFilter] = useState('all');
  const [priorityFilter, setPriorityFilter] = useState('all');
  const [assigneeFilter, setAssigneeFilter] = useState('all');
  const [search, setSearch] = useState('');

  const { data: admins } = useQuery({
    queryKey: ['admin-users-filter'],
    queryFn: async () => {
      const res = await apiFetch<AdminUser[]>('/admin/users?limit=50');
      return res.data ?? [];
    },
  });

  const { data, isLoading, error } = useQuery({
    queryKey: ['support-tickets', page, statusFilter, priorityFilter, assigneeFilter, search],
    queryFn: async () => {
      const res = await apiFetch<SupportTicket[]>(
        `/admin/support/tickets${buildQuery({
          page,
          limit: 20,
          status: statusFilter === 'all' ? undefined : statusFilter,
          priority: priorityFilter === 'all' ? undefined : priorityFilter,
          assignedToId: assigneeFilter === 'all' ? undefined : assigneeFilter,
          search: search || undefined,
        })}`,
      );
      return { items: res.data ?? [], meta: res.meta };
    },
  });

  const exportParams = useMemo(
    () => ({
      status: statusFilter === 'all' ? undefined : statusFilter,
      priority: priorityFilter === 'all' ? undefined : priorityFilter,
      assignedToId: assigneeFilter === 'all' ? undefined : assigneeFilter,
      search: search || undefined,
    }),
    [statusFilter, priorityFilter, assigneeFilter, search],
  );

  const columns: Column<SupportTicket>[] = [
    {
      key: 'ticket',
      header: 'Ticket #',
      render: (r) => <span className="font-mono text-[13px]">{r.ticketNumber}</span>,
      searchable: (r) => r.ticketNumber,
      exportValue: (r) => r.ticketNumber,
    },
    {
      key: 'subject',
      header: 'Subject',
      render: (r) => r.subject,
      searchable: (r) => r.subject,
      exportValue: (r) => r.subject,
    },
    {
      key: 'user',
      header: 'User',
      render: (r) => r.user?.fullName ?? '—',
      exportValue: (r) => r.user?.fullName ?? '',
    },
    {
      key: 'category',
      header: 'Category',
      render: (r) => r.category,
      exportValue: (r) => r.category,
    },
    {
      key: 'priority',
      header: 'Priority',
      render: (r) => <Badge variant={statusBadgeVariant(r.priority)}>{r.priority}</Badge>,
      exportValue: (r) => r.priority,
    },
    {
      key: 'status',
      header: 'Status',
      render: (r) => <Badge variant={statusBadgeVariant(r.status)}>{r.status}</Badge>,
      exportValue: (r) => r.status,
    },
    {
      key: 'created',
      header: 'Created',
      render: (r) => formatDate(r.createdAt),
      exportValue: (r) => formatDate(r.createdAt),
    },
  ];

  return (
    <>
      <Header title="Tickets" description="Rider and driver support tickets" />
      <PageContent>
        <DataTable
          data={data?.items ?? []}
          columns={columns}
          meta={data?.meta}
          page={page}
          onPageChange={setPage}
          isLoading={isLoading}
          error={error ? 'Failed to load tickets' : null}
          onRowClick={(row) => router.push(`/support/${row.id}`)}
          searchPlaceholder="Search tickets..."
          searchValue={search}
          onSearchChange={(v) => {
            setSearch(v);
            setPage(1);
          }}
          serverExport={{ type: 'support', params: exportParams }}
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
                { value: 'all', label: 'All' },
                { value: 'open', label: 'Open' },
                { value: 'in_progress', label: 'In progress' },
                { value: 'resolved', label: 'Resolved' },
                { value: 'closed', label: 'Closed' },
              ],
            },
            {
              key: 'priority',
              label: 'Priority',
              value: priorityFilter,
              onChange: (v) => {
                setPriorityFilter(v);
                setPage(1);
              },
              options: [
                { value: 'all', label: 'All priorities' },
                { value: 'low', label: 'Low' },
                { value: 'medium', label: 'Medium' },
                { value: 'high', label: 'High' },
                { value: 'urgent', label: 'Urgent' },
              ],
            },
            {
              key: 'assignee',
              label: 'Assignee',
              value: assigneeFilter,
              onChange: (v) => {
                setAssigneeFilter(v);
                setPage(1);
              },
              options: [
                { value: 'all', label: 'All assignees' },
                ...(admins ?? []).map((a) => ({
                  value: a.id,
                  label: a.user.fullName,
                })),
              ],
            },
          ]}
        />
      </PageContent>
    </>
  );
}
