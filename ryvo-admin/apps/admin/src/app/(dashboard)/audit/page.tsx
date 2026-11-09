'use client';

import { useCallback, useMemo, useState } from 'react';
import { useQuery } from '@tanstack/react-query';
import { Bell, CarFront, ClipboardList, LifeBuoy, Settings, Shield, User, Wallet } from 'lucide-react';
import { Header } from '@/components/layout/header';
import { PageContent } from '@/components/layout/page-content';
import { DataTable, type Column } from '@/components/data-table';
import { Modal } from '@/components/ui/modal';
import { apiFetch, buildQuery } from '@/lib/api';
import { cn, formatDate } from '@/lib/utils';

interface AuditLog {
  id: string;
  action: string;
  entityType: string;
  entityId: string | null;
  oldValues?: Record<string, unknown> | null;
  newValues?: Record<string, unknown> | null;
  ipAddress?: string | null;
  createdAt: string;
  admin?: { user: { fullName: string; email?: string | null } };
}

interface AuditSummary {
  total: number;
  byEntity: Record<string, number>;
}

type Period = 'all' | 'today' | '7d' | '30d' | '90d';

const PHRASES: Record<string, string> = {
  update_job_status: 'updated a trip status',
  assign_provider: 'assigned a driver to a trip',
  cancel_job: 'cancelled a trip',
  review_document: 'reviewed a driver document',
  force_offline: 'took a driver offline',
  update_commission: 'changed a driver commission',
  update_verification_status: 'updated driver verification',
  delete_provider: 'removed a driver',
  update_customer_status: 'updated a rider',
  delete_customer: 'removed a rider',
  wallet_adjust: 'adjusted a wallet',
  process_payout: 'processed a payout',
  assign_ticket: 'assigned a support ticket',
  unassign_ticket: 'unassigned a support ticket',
  update_ticket_status: 'updated a support ticket',
  update_ticket_priority: 'changed a ticket priority',
  update_setting: 'changed a platform setting',
  send_broadcast: 'sent a broadcast',
  create_admin_user: 'added a team member',
  update_admin_user: 'updated a team member',
  update_role_permissions: 'changed access permissions',
  hide: 'hid a review',
  unhide: 'restored a review',
  create: 'created a record',
  update: 'updated a record',
  delete: 'deleted a record',
  review: 'reviewed a record',
};

const ENTITIES: Record<string, string> = {
  job: 'Trip',
  provider: 'Driver',
  provider_document: 'Driver document',
  customer: 'Rider',
  support_ticket: 'Support ticket',
  rating: 'Review',
  payout: 'Payout',
  wallet: 'Wallet',
  platform_setting: 'Setting',
  broadcast: 'Broadcast',
  admin_user: 'Team member',
  admin_role: 'Access',
  country: 'Country',
};

const TILES = [
  { value: 'all', label: 'All activity', types: [] as string[], wash: 'stat-wash-sky' },
  { value: 'job', label: 'Trips', types: ['job'], wash: 'stat-wash-emerald' },
  { value: 'provider,provider_document', label: 'Drivers', types: ['provider', 'provider_document'], wash: 'stat-wash-violet' },
  { value: 'customer', label: 'Riders', types: ['customer'], wash: 'stat-wash-amber' },
  { value: 'payout,wallet', label: 'Money', types: ['payout', 'wallet'], wash: 'stat-wash-teal' },
  { value: 'support_ticket', label: 'Tickets', types: ['support_ticket'], wash: 'stat-wash-rose' },
];

function periodStart(period: Period) {
  if (period === 'all') return undefined;
  const start = new Date();
  start.setHours(0, 0, 0, 0);
  const days = period === 'today' ? 1 : period === '7d' ? 7 : period === '30d' ? 30 : 90;
  start.setDate(start.getDate() - (days - 1));
  return start.toISOString();
}

function entityLabel(type: string) {
  return ENTITIES[type] ?? type.replace(/_/g, ' ');
}

function actionTitle(action: string) {
  const phrase = PHRASES[action] ?? action.replace(/_/g, ' ');
  return phrase.charAt(0).toUpperCase() + phrase.slice(1);
}

function whenLabel(value: string) {
  const diff = Date.now() - new Date(value).getTime();
  const minutes = Math.round(diff / 60_000);
  if (minutes < 1) return 'Just now';
  if (minutes < 60) return `${minutes} min ago`;
  const hours = Math.round(minutes / 60);
  if (hours < 24) return `${hours} hr ago`;
  const days = Math.round(hours / 24);
  if (days < 7) return `${days} day${days === 1 ? '' : 's'} ago`;
  return formatDate(value);
}

function tone(action: string) {
  if (/delete|cancel|offline|reject/.test(action)) return 'bg-danger/10 text-danger';
  if (/create|process|review|assign|unhide/.test(action)) return 'bg-success/10 text-success';
  if (/update|wallet|setting|permission|hide/.test(action)) return 'bg-info/10 text-info';
  return 'bg-input text-muted';
}

function ActivityIcon({ type }: { type: string }) {
  const Icon = type === 'job' ? CarFront
    : type === 'provider' || type === 'provider_document' || type === 'customer' ? User
    : type === 'payout' || type === 'wallet' ? Wallet
    : type === 'support_ticket' ? LifeBuoy
    : type === 'platform_setting' ? Settings
    : type === 'admin_user' || type === 'admin_role' ? Shield
    : type === 'broadcast' ? Bell
    : ClipboardList;
  return <Icon className="size-4" strokeWidth={1.75} />;
}

function asRecord(value: unknown) {
  if (!value || typeof value !== 'object' || Array.isArray(value)) return null;
  return value as Record<string, unknown>;
}

function formatValue(value: unknown) {
  if (value == null || value === '') return '—';
  if (typeof value === 'boolean') return value ? 'Yes' : 'No';
  if (typeof value === 'number') return String(value);
  if (typeof value === 'string') return value.length > 180 ? `${value.slice(0, 177)}…` : value;
  const json = JSON.stringify(value);
  return json.length > 180 ? `${json.slice(0, 177)}…` : json;
}

function fieldLabel(key: string) {
  return key.replace(/_/g, ' ').replace(/([a-z])([A-Z])/g, '$1 $2').replace(/\b\w/g, (char) => char.toUpperCase());
}

function changes(log: AuditLog) {
  const next = asRecord(log.newValues);
  const previous = asRecord(log.oldValues);
  if (!next && !previous) return [];
  const hidden = new Set(['password', 'token', 'refreshToken', 'accessToken']);
  return Array.from(new Set([...Object.keys(previous ?? {}), ...Object.keys(next ?? {})]))
    .filter((key) => !hidden.has(key) && JSON.stringify(previous?.[key]) !== JSON.stringify(next?.[key]))
    .slice(0, 16)
    .map((key) => ({
      label: fieldLabel(key),
      from: previous && key in previous ? formatValue(previous[key]) : null,
      to: next && key in next ? formatValue(next[key]) : null,
    }));
}

export default function AuditPage() {
  const [page, setPage] = useState(1);
  const [entity, setEntity] = useState('all');
  const [action, setAction] = useState('all');
  const [period, setPeriod] = useState<Period>('30d');
  const [search, setSearch] = useState('');
  const [selected, setSelected] = useState<AuditLog | null>(null);
  const onSearchChange = useCallback((value: string) => {
    setSearch(value);
    setPage(1);
  }, []);

  const from = periodStart(period);
  const scope = {
    search: search.trim() || undefined,
    from,
    entityType: entity === 'all' ? undefined : entity,
    action: action === 'all' ? undefined : action,
  };

  const summary = useQuery({
    queryKey: ['audit-summary', search, from],
    queryFn: async () =>
      (await apiFetch<AuditSummary>(`/admin/audit-logs/summary${buildQuery({ search: scope.search, from })}`)).data,
  });

  const { data, isLoading, error } = useQuery({
    queryKey: ['audit-logs', page, scope],
    queryFn: async () => {
      const res = await apiFetch<AuditLog[]>(`/admin/audit-logs${buildQuery({ page, limit: 20, ...scope })}`);
      return { items: res.data ?? [], meta: res.meta };
    },
  });

  const counts = summary.data?.byEntity ?? {};
  const total = summary.data?.total ?? 0;
  const countFor = (types: string[]) => (types.length === 0 ? total : types.reduce((sum, type) => sum + (counts[type] ?? 0), 0));

  const columns: Column<AuditLog>[] = useMemo(
    () => [
      {
        key: 'what',
        header: 'What happened',
        sortable: true,
        sortValue: (row) => row.action,
        render: (row) => (
          <span className="flex items-center gap-3">
            <span className={cn('grid size-9 shrink-0 place-items-center rounded-full', tone(row.action))}>
              <ActivityIcon type={row.entityType} />
            </span>
            <span className="min-w-0">
              <span className="block font-medium text-primary">{actionTitle(row.action)}</span>
              <span className="block text-xs text-muted">{entityLabel(row.entityType)}</span>
            </span>
          </span>
        ),
      },
      {
        key: 'admin',
        header: 'By',
        sortable: true,
        sortValue: (row) => row.admin?.user.fullName ?? '',
        render: (row) => <span className="text-primary">{row.admin?.user.fullName ?? 'Unknown admin'}</span>,
      },
      {
        key: 'time',
        header: 'When',
        sortable: true,
        sortValue: (row) => new Date(row.createdAt).getTime(),
        render: (row) => {
          const recent = Date.now() - new Date(row.createdAt).getTime() < 7 * 86_400_000;
          return (
            <span>
              <span className="block text-primary">{whenLabel(row.createdAt)}</span>
              {recent ? <span className="block text-xs text-muted">{formatDate(row.createdAt)}</span> : null}
            </span>
          );
        },
      },
    ],
    [],
  );

  const selectedChanges = selected ? changes(selected) : [];

  return (
    <>
      <Header title="Audit" description="A plain record of who changed what, and when." />
      <PageContent>
        <div className="mb-4 grid gap-3 sm:grid-cols-2 xl:grid-cols-6">
          {TILES.map((tile) => (
            <button
              key={tile.value}
              type="button"
              onClick={() => {
                setEntity(tile.value);
                setPage(1);
              }}
              className={cn('rounded-[18px] border p-4 text-left', tile.wash, entity === tile.value ? 'border-primary' : 'border-white/70')}
            >
              <p className="text-sm text-muted">{tile.label}</p>
              <p className="num mt-1 text-[26px] font-bold leading-none tracking-tight text-primary">{countFor(tile.types)}</p>
            </button>
          ))}
        </div>
        <DataTable
          data={data?.items ?? []}
          columns={columns}
          meta={data?.meta}
          page={page}
          onPageChange={setPage}
          isLoading={isLoading}
          error={error ? 'Failed to load the audit log' : null}
          emptyMessage="No activity matches these filters."
          searchPlaceholder="Search person, action, or record..."
          searchValue={search}
          onSearchChange={onSearchChange}
          onRowClick={setSelected}
          serverExport={{ type: 'audit', params: scope }}
          filters={[
            {
              key: 'entity',
              label: 'Area',
              value: entity,
              onChange: (value) => {
                setEntity(value);
                setPage(1);
              },
              options: [
                { value: 'all', label: 'All areas' },
                { value: 'job', label: 'Trips' },
                { value: 'provider,provider_document', label: 'Drivers' },
                { value: 'provider_document', label: 'Driver documents' },
                { value: 'customer', label: 'Riders' },
                { value: 'payout,wallet', label: 'Money' },
                { value: 'payout', label: 'Payouts' },
                { value: 'wallet', label: 'Wallets' },
                { value: 'support_ticket', label: 'Tickets' },
                { value: 'rating', label: 'Reviews' },
                { value: 'platform_setting', label: 'Settings' },
                { value: 'admin_user,admin_role', label: 'Team & access' },
                { value: 'broadcast', label: 'Broadcasts' },
                { value: 'country', label: 'Countries' },
              ],
            },
            {
              key: 'action',
              label: 'Kind',
              value: action,
              onChange: (value) => {
                setAction(value);
                setPage(1);
              },
              options: [
                { value: 'all', label: 'All kinds' },
                { value: 'update', label: 'Changes' },
                { value: 'delete', label: 'Removals' },
                { value: 'cancel', label: 'Cancellations' },
                { value: 'review', label: 'Reviews' },
                { value: 'payout', label: 'Payouts' },
              ],
            },
            {
              key: 'period',
              label: 'When',
              value: period,
              onChange: (value) => {
                setPeriod(value as Period);
                setPage(1);
              },
              options: [
                { value: 'all', label: 'All time' },
                { value: 'today', label: 'Today' },
                { value: '7d', label: 'Last 7 days' },
                { value: '30d', label: 'Last 30 days' },
                { value: '90d', label: 'Last 90 days' },
              ],
            },
          ]}
        />
      </PageContent>
      <Modal
        open={Boolean(selected)}
        onClose={() => setSelected(null)}
        title={selected ? actionTitle(selected.action) : 'Activity'}
        description={selected ? `${selected.admin?.user.fullName ?? 'Unknown admin'} · ${formatDate(selected.createdAt)}` : undefined}
        className="max-w-xl"
      >
        {selected ? (
          <div className="space-y-4">
            <dl className="grid grid-cols-2 gap-3 text-sm">
              <div>
                <dt className="text-xs text-muted">Area</dt>
                <dd className="mt-0.5 text-primary">{entityLabel(selected.entityType)}</dd>
              </div>
              <div>
                <dt className="text-xs text-muted">Email</dt>
                <dd className="mt-0.5 truncate text-primary">{selected.admin?.user.email || '—'}</dd>
              </div>
              <div className="col-span-2">
                <dt className="text-xs text-muted">Record</dt>
                <dd className="mt-0.5 break-all font-mono text-xs text-secondary">{selected.entityId || '—'}</dd>
              </div>
              {selected.ipAddress ? (
                <div>
                  <dt className="text-xs text-muted">IP address</dt>
                  <dd className="mt-0.5 text-primary">{selected.ipAddress}</dd>
                </div>
              ) : null}
            </dl>
            {selectedChanges.length > 0 ? (
              <div className="space-y-2">
                <p className="text-xs font-medium uppercase tracking-wide text-muted">What changed</p>
                <ul className="divide-y divide-hairline rounded-2xl border border-hairline">
                  {selectedChanges.map((change) => (
                    <li key={change.label} className="grid gap-1 px-3 py-2 text-sm sm:grid-cols-[140px_1fr]">
                      <span className="text-muted">{change.label}</span>
                      <span className="min-w-0 break-words text-primary">
                        {change.from != null && change.to != null ? `${change.from} → ${change.to}` : change.to ?? change.from}
                      </span>
                    </li>
                  ))}
                </ul>
              </div>
            ) : (
              <p className="text-sm text-muted">No field changes were stored for this action.</p>
            )}
          </div>
        ) : null}
      </Modal>
    </>
  );
}
