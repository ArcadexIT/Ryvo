'use client';

import { useMemo, useState } from 'react';
import { useQuery } from '@tanstack/react-query';
import { ChevronDown, ChevronRight } from 'lucide-react';
import { Header } from '@/components/layout/header';
import { PageContent } from '@/components/layout/page-content';
import { PageToolbar } from '@/components/layout/page-toolbar';
import { DataTable, type Column } from '@/components/data-table';
import { Badge } from '@/components/ui/badge';
import { DateRangePicker, dateRangeToDays, type DateRange } from '@/components/ui/date-range-picker';
import { apiFetch, buildQuery } from '@/lib/api';
import { formatDate } from '@/lib/utils';

interface AuditLog {
  id: string;
  action: string;
  entityType: string;
  entityId: string | null;
  oldValues?: Record<string, unknown> | null;
  newValues?: Record<string, unknown> | null;
  createdAt: string;
  admin?: { user: { fullName: string } };
}

function dateRangeBounds(range: DateRange) {
  const days = dateRangeToDays(range);
  const from = new Date(Date.now() - days * 24 * 60 * 60 * 1000).toISOString();
  const to = new Date().toISOString();
  return { from, to };
}

export default function AuditPage() {
  const [page, setPage] = useState(1);
  const [actionFilter, setActionFilter] = useState('all');
  const [dateRange, setDateRange] = useState<DateRange>('30d');
  const [expandedId, setExpandedId] = useState<string | null>(null);
  const [entityFilter, setEntityFilter] = useState('all');

  const { from, to } = useMemo(() => dateRangeBounds(dateRange), [dateRange]);

  const { data, isLoading, error } = useQuery({
    queryKey: ['audit-logs', page, entityFilter, actionFilter, from, to],
    queryFn: async () => {
      const res = await apiFetch<AuditLog[]>(
        `/admin/audit-logs${buildQuery({
          page,
          limit: 20,
          entityType: entityFilter === 'all' ? undefined : entityFilter,
          action: actionFilter === 'all' ? undefined : actionFilter,
          from,
          to,
        })}`,
      );
      return { items: res.data ?? [], meta: res.meta };
    },
  });

  const exportParams = useMemo(
    () => ({
      entityType: entityFilter === 'all' ? undefined : entityFilter,
      action: actionFilter === 'all' ? undefined : actionFilter,
      from,
      to,
    }),
    [entityFilter, actionFilter, from, to],
  );

  const columns: Column<AuditLog>[] = [
    {
      key: 'expand',
      header: '',
      sortable: false,
      render: (r) => (
        <button
          type="button"
          onClick={(e) => {
            e.stopPropagation();
            setExpandedId(expandedId === r.id ? null : r.id);
          }}
          className="text-muted hover:text-primary"
        >
          {expandedId === r.id ? (
            <ChevronDown className="h-4 w-4" />
          ) : (
            <ChevronRight className="h-4 w-4" />
          )}
        </button>
      ),
    },
    {
      key: 'action',
      header: 'Action',
      render: (r) => (
        <div>
          <Badge variant="outline">{r.action}</Badge>
          {expandedId === r.id && (
            <pre className="mt-2 max-w-md overflow-x-auto rounded-md bg-surface p-2 text-xs text-secondary">
              {JSON.stringify(
                r.newValues ?? r.oldValues ?? { entityType: r.entityType, entityId: r.entityId },
                null,
                2,
              )}
            </pre>
          )}
        </div>
      ),
      searchable: (r) => r.action,
      sortValue: (r) => r.action,
      exportValue: (r) => r.action,
    },
    {
      key: 'entity',
      header: 'Entity',
      render: (r) => `${r.entityType} · ${(r.entityId ?? '').slice(0, 8)}…`,
      searchable: (r) => r.entityType,
      sortValue: (r) => r.entityType,
      exportValue: (r) => `${r.entityType}:${r.entityId ?? ''}`,
    },
    {
      key: 'admin',
      header: 'Admin',
      render: (r) => r.admin?.user.fullName ?? '—',
      sortValue: (r) => r.admin?.user.fullName ?? '',
      exportValue: (r) => r.admin?.user.fullName ?? '',
    },
    {
      key: 'time',
      header: 'Timestamp',
      render: (r) => formatDate(r.createdAt),
      sortValue: (r) => new Date(r.createdAt).getTime(),
      exportValue: (r) => formatDate(r.createdAt),
    },
  ];

  return (
    <>
      <Header title="Audit" description="Admin action history" />
      <PageContent>
        <PageToolbar>
          <DateRangePicker value={dateRange} onChange={(v) => { setDateRange(v); setPage(1); }} />
        </PageToolbar>
        <DataTable
          data={data?.items ?? []}
          columns={columns}
          meta={data?.meta}
          page={page}
          onPageChange={setPage}
          isLoading={isLoading}
          error={error ? 'Failed to load audit logs' : null}
          searchPlaceholder="Search audit logs..."
          serverExport={{ type: 'audit', params: exportParams }}
          filters={[
            {
              key: 'entity',
              label: 'Entity',
              value: entityFilter,
              onChange: (v) => {
                setEntityFilter(v);
                setPage(1);
              },
              options: [
                { value: 'all', label: 'All entities' },
                { value: 'job', label: 'Job' },
                { value: 'provider', label: 'Driver' },
                { value: 'customer', label: 'Customer' },
                { value: 'support_ticket', label: 'Support' },
                { value: 'rating', label: 'Rating' },
              ],
            },
            {
              key: 'action',
              label: 'Action',
              value: actionFilter,
              onChange: (v) => {
                setActionFilter(v);
                setPage(1);
              },
              options: [
                { value: 'all', label: 'All actions' },
                { value: 'create', label: 'Create' },
                { value: 'update', label: 'Update' },
                { value: 'delete', label: 'Delete' },
                { value: 'review', label: 'Review' },
              ],
            },
          ]}
        />
      </PageContent>
    </>
  );
}
