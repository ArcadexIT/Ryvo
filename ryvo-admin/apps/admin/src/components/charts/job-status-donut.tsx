'use client';

import { PieChart, Pie, Cell, Tooltip, ResponsiveContainer } from 'recharts';
import { getStatusColor } from '@/components/charts/chart-theme';
import { cn } from '@/lib/utils';

interface JobStatusDonutProps {
  data: { name: string; value: number }[];
}

function DonutTooltip({
  active,
  payload,
}: {
  active?: boolean;
  payload?: { value: number; name: string; payload: { name: string } }[];
}) {
  if (!active || !payload?.length) return null;
  const entry = payload[0];
  return (
    <div className="rounded-lg border border-border bg-overlay px-3 py-2 shadow-lg">
      <p className="flex items-center gap-1.5 text-sm font-medium capitalize text-primary">
        <span
          className="h-2 w-2 rounded-full"
          style={{ background: getStatusColor(entry.name) }}
        />
        {entry.name.replace(/_/g, ' ')}
      </p>
      <p className="font-tabular mt-0.5 text-xs text-secondary">{entry.value} jobs</p>
    </div>
  );
}

export function JobStatusDonut({ data }: JobStatusDonutProps) {
  const total = data.reduce((sum, d) => sum + d.value, 0);

  return (
    <div className="flex flex-col items-center gap-4 sm:flex-row sm:items-center">
      <div className="relative shrink-0">
        <ResponsiveContainer width={200} height={200}>
          <PieChart>
            <Pie
              data={data}
              dataKey="value"
              nameKey="name"
              cx="50%"
              cy="50%"
              innerRadius={62}
              outerRadius={92}
              paddingAngle={3}
              stroke="none"
            >
              {data.map((entry) => (
                <Cell key={entry.name} fill={getStatusColor(entry.name)} />
              ))}
            </Pie>
            <Tooltip content={<DonutTooltip />} />
          </PieChart>
        </ResponsiveContainer>
        <div className="pointer-events-none absolute inset-0 flex flex-col items-center justify-center">
          <span className="font-tabular font-display text-2xl text-primary">{total}</span>
          <span className="text-xs text-muted">Total Jobs</span>
        </div>
      </div>

      <ul className="w-full min-w-0 flex-1 space-y-2.5">
        {data.map((entry) => {
          const pct = total > 0 ? Math.round((entry.value / total) * 100) : 0;
          return (
            <li key={entry.name} className="flex items-center gap-3 text-sm">
              <span
                className="h-2.5 w-2.5 shrink-0 rounded-full"
                style={{ background: getStatusColor(entry.name) }}
              />
              <span className="min-w-0 flex-1 truncate capitalize text-secondary">
                {entry.name.replace(/_/g, ' ')}
              </span>
              <span className="font-tabular shrink-0 font-medium text-primary">{entry.value}</span>
              <span
                className={cn(
                  'font-tabular w-11 shrink-0 text-right text-xs text-muted',
                )}
              >
                {pct}%
              </span>
            </li>
          );
        })}
      </ul>
    </div>
  );
}
