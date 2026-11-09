'use client';

import { Bar, BarChart, Cell, ResponsiveContainer, Tooltip, XAxis, YAxis } from 'recharts';

const STATUS_ROWS = [
  { key: 'pending', label: 'Pending', color: 'var(--chart-3)', statuses: ['searching', 'draft', 'payment_pending', 'no_provider_found'] },
  { key: 'accepted', label: 'Accepted', color: 'var(--chart-2)', statuses: ['matched'] },
  { key: 'ongoing', label: 'Ongoing', color: 'var(--chart-4)', statuses: ['provider_en_route', 'arrived', 'in_progress'] },
  { key: 'completed', label: 'Completed', color: 'var(--chart-1)', statuses: ['completed'] },
  { key: 'cancelled', label: 'Cancelled', color: 'var(--chart-5)', statuses: ['cancelled_by_customer', 'cancelled_by_provider', 'cancelled_by_admin'] },
] as const;

export function JobStatusCard({ breakdown }: { breakdown: Record<string, number> }) {
  const rows = STATUS_ROWS.map((row) => ({
    ...row,
    value: row.statuses.reduce((sum, status) => sum + (breakdown[status] ?? 0), 0),
  }));
  const total = rows.reduce((sum, row) => sum + row.value, 0);

  return (
    <section className="rounded-lg border border-hairline bg-card p-4">
      <div className="flex items-center justify-between">
        <h2 className="text-sm font-semibold text-primary">Trip status</h2>
        <span className="num text-xs text-muted">{total}</span>
      </div>
      {total === 0 ? (
        <p className="mt-6 text-sm text-muted">No trips in this range.</p>
      ) : (
        <>
          <div className="mt-3 h-[168px]">
            <ResponsiveContainer width="100%" height="100%">
              <BarChart data={rows} layout="vertical" margin={{ top: 0, right: 8, left: 0, bottom: 0 }}>
                <XAxis type="number" hide />
                <YAxis
                  type="category"
                  dataKey="label"
                  width={78}
                  tick={{ fill: 'var(--text-muted)', fontSize: 12 }}
                  axisLine={false}
                  tickLine={false}
                />
                <Tooltip
                  cursor={{ fill: 'var(--input)' }}
                  content={({ active, payload }) => {
                    if (!active || !payload?.length) return null;
                    const row = payload[0].payload as { label: string; value: number };
                    return (
                      <div className="rounded-lg border border-hairline bg-sheet px-3 py-2 text-xs shadow-popover">
                        <p className="font-medium text-primary">{row.label}</p>
                        <p className="num mt-1 text-muted">{row.value}</p>
                      </div>
                    );
                  }}
                />
                <Bar dataKey="value" radius={[0, 6, 6, 0]} barSize={12}>
                  {rows.map((row) => (
                    <Cell key={row.key} fill={row.color} />
                  ))}
                </Bar>
              </BarChart>
            </ResponsiveContainer>
          </div>
          <ul className="mt-2 grid grid-cols-2 gap-x-3 gap-y-1">
            {rows.map((row) => (
              <li key={row.key} className="flex items-center justify-between gap-2 text-xs">
                <span className="inline-flex items-center gap-1.5 text-muted">
                  <span className="size-2 rounded-full" style={{ backgroundColor: row.color }} />
                  {row.label}
                </span>
                <span className="num text-primary">{row.value}</span>
              </li>
            ))}
          </ul>
        </>
      )}
    </section>
  );
}
