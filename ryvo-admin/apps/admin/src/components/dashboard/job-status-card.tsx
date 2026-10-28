'use client';

import { Cell, Pie, PieChart, ResponsiveContainer } from 'recharts';

const STATUS_ROWS = [
  { key: 'pending', label: 'Pending', color: '#3b82f6', statuses: ['searching', 'draft', 'payment_pending', 'no_provider_found'] },
  { key: 'accepted', label: 'Accepted', color: '#1fa855', statuses: ['matched'] },
  { key: 'ongoing', label: 'On Going', color: '#f59e0b', statuses: ['provider_en_route', 'arrived', 'in_progress'] },
  { key: 'completed', label: 'Completed', color: '#8b5cf6', statuses: ['completed'] },
  { key: 'cancelled', label: 'Cancelled', color: '#ef4444', statuses: ['cancelled_by_customer', 'cancelled_by_provider', 'cancelled_by_admin'] },
] as const;

export function JobStatusCard({ breakdown }: { breakdown: Record<string, number> }) {
  const rows = STATUS_ROWS.map((row) => ({
    ...row,
    value: row.statuses.reduce((sum, status) => sum + (breakdown[status] ?? 0), 0),
  }));
  const total = rows.reduce((sum, row) => sum + row.value, 0);
  const chart = total > 0
    ? rows.filter((row) => row.value > 0)
    : [{ key: 'empty', label: 'empty', color: '#e8eef4', value: 1, statuses: [] as string[] }];

  return (
    <section className="rounded-2xl border border-border bg-elevated p-4 shadow-sm">
      <h2 className="text-sm font-semibold text-primary">Job Status</h2>
      <div className="mt-2 flex items-center gap-2">
        <div className="relative h-[118px] w-[118px] shrink-0">
          <ResponsiveContainer width="100%" height="100%">
            <PieChart>
              <Pie data={chart} dataKey="value" innerRadius={38} outerRadius={54} stroke="none" paddingAngle={total > 0 ? 3 : 0}>
                {chart.map((entry) => (
                  <Cell key={entry.key} fill={entry.color} />
                ))}
              </Pie>
            </PieChart>
          </ResponsiveContainer>
          <div className="pointer-events-none absolute inset-0 flex flex-col items-center justify-center">
            <span className="text-lg font-semibold text-primary">{total}</span>
            <span className="text-[10px] text-muted">Total Jobs</span>
          </div>
        </div>
        <ul className="min-w-0 flex-1 space-y-1.5">
          {rows.map((row) => {
            const pct = total > 0 ? Math.round((row.value / total) * 100) : 0;
            return (
              <li key={row.key} className="flex items-center gap-2 text-xs">
                <span className="h-2 w-2 rounded-full" style={{ background: row.color }} />
                <span className="flex-1 truncate text-secondary">{row.label}</span>
                <span className="font-medium text-primary">{row.value}</span>
                <span className="w-8 text-right text-muted">{pct}%</span>
              </li>
            );
          })}
        </ul>
      </div>
    </section>
  );
}
