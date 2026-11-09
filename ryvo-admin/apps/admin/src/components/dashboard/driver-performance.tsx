'use client';

import { BarChart3 } from 'lucide-react';
import { Bar, BarChart, Cell, ResponsiveContainer, Tooltip, XAxis, YAxis } from 'recharts';

interface DriverPerformanceProps {
  online: number;
  offline: number;
  onBreak: number;
}

const SEGMENTS = [
  { key: 'online', label: 'Online', color: 'var(--chart-1)' },
  { key: 'offline', label: 'Offline', color: 'var(--chart-2)' },
  { key: 'onBreak', label: 'On break', color: 'var(--chart-3)' },
] as const;

export function DriverPerformance({ online, offline, onBreak }: DriverPerformanceProps) {
  const values = { online, offline, onBreak };
  const total = online + offline + onBreak;
  const rows = SEGMENTS.map((segment) => ({ ...segment, value: values[segment.key] }));

  return (
    <section className="panel-card p-4">
      <div className="flex items-center justify-between">
        <h2 className="inline-flex items-center gap-2 text-sm font-semibold text-primary">
          <span className="grid size-8 place-items-center rounded-lg bg-chart-4/15 text-chart-4">
            <BarChart3 className="size-4" strokeWidth={1.75} />
          </span>
          Driver performance
        </h2>
        <span className="text-xs text-muted">Last 7 days</span>
      </div>
      {total === 0 ? (
        <p className="mt-6 text-sm text-muted">No drivers to show.</p>
      ) : (
        <>
          <div className="mt-2 h-[150px]">
            <ResponsiveContainer width="100%" height="100%">
              <BarChart data={rows} margin={{ top: 8, right: 0, left: -28, bottom: 0 }}>
                <XAxis
                  dataKey="label"
                  tick={{ fill: 'var(--text-muted)', fontSize: 12 }}
                  axisLine={false}
                  tickLine={false}
                />
                <YAxis allowDecimals={false} tick={{ fill: 'var(--text-muted)', fontSize: 11 }} axisLine={false} tickLine={false} />
                <Tooltip
                  cursor={{ fill: 'var(--input)' }}
                  content={({ active, payload }) => {
                    if (!active || !payload?.length) return null;
                    const row = payload[0].payload as { label: string; value: number };
                    const pct = Math.round((row.value / total) * 100);
                    return (
                      <div className="rounded-lg border border-hairline bg-sheet px-3 py-2 text-xs shadow-popover">
                        <p className="font-medium text-primary">{row.label}</p>
                        <p className="num mt-1 text-muted">
                          {row.value} · {pct}%
                        </p>
                      </div>
                    );
                  }}
                />
                <Bar dataKey="value" radius={[6, 6, 0, 0]} maxBarSize={36}>
                  {rows.map((row) => (
                    <Cell key={row.key} fill={row.color} />
                  ))}
                </Bar>
              </BarChart>
            </ResponsiveContainer>
          </div>
          <ul className="mt-1 flex flex-wrap gap-x-3 gap-y-1">
            {rows.map((row) => (
              <li key={row.key} className="inline-flex items-center gap-1.5 text-xs text-muted">
                <span className="size-2 rounded-full" style={{ backgroundColor: row.color }} />
                {row.label}
                <span className="num text-primary">{row.value}</span>
              </li>
            ))}
          </ul>
        </>
      )}
    </section>
  );
}
