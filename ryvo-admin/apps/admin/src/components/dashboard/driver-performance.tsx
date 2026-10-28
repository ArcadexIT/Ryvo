'use client';

import { Cell, Pie, PieChart, ResponsiveContainer } from 'recharts';

interface DriverPerformanceProps {
  online: number;
  offline: number;
  onBreak: number;
}

const SEGMENTS = [
  { key: 'online', label: 'Online', color: '#1fa855' },
  { key: 'offline', label: 'Offline', color: '#d7f5e3' },
  { key: 'onBreak', label: 'On Break', color: '#f59e0b' },
] as const;

export function DriverPerformance({ online, offline, onBreak }: DriverPerformanceProps) {
  const values = { online, offline, onBreak };
  const total = online + offline + onBreak;
  const chart = total > 0
    ? SEGMENTS.map((segment) => ({ name: segment.label, value: values[segment.key], color: segment.color })).filter((item) => item.value > 0)
    : [{ name: 'empty', value: 1, color: '#e8eef4' }];

  return (
    <section className="rounded-2xl border border-border bg-elevated p-4 shadow-sm">
      <div className="flex items-center justify-between">
        <div>
          <h2 className="text-sm font-semibold text-primary">Driver Performance</h2>
          <p className="text-[11px] text-muted">Last 7 days</p>
        </div>
        <span className="text-[11px] text-muted">{total} drivers</span>
      </div>
      <div className="mt-2 flex items-center gap-3">
        <div className="relative h-[118px] w-[118px] shrink-0">
          <ResponsiveContainer width="100%" height="100%">
            <PieChart>
              <Pie data={chart} dataKey="value" innerRadius={38} outerRadius={54} stroke="none" startAngle={90} endAngle={-270}>
                {chart.map((entry) => (
                  <Cell key={entry.name} fill={entry.color} />
                ))}
              </Pie>
            </PieChart>
          </ResponsiveContainer>
          <div className="pointer-events-none absolute inset-0 flex flex-col items-center justify-center">
            <span className="text-lg font-semibold text-primary">{online}</span>
            <span className="text-[10px] text-muted">Active Drivers</span>
          </div>
        </div>
        <ul className="min-w-0 flex-1 space-y-2">
          {SEGMENTS.map((segment) => {
            const count = values[segment.key];
            const pct = total > 0 ? Math.round((count / total) * 100) : 0;
            return (
              <li key={segment.key} className="flex items-center gap-2 text-xs">
                <span className="h-2 w-2 rounded-full" style={{ background: segment.color }} />
                <span className="flex-1 text-secondary">{segment.label}</span>
                <span className="font-medium text-primary">{count}</span>
                <span className="w-8 text-right text-muted">{pct}%</span>
              </li>
            );
          })}
        </ul>
      </div>
    </section>
  );
}
