'use client';

import {
  Area,
  CartesianGrid,
  ComposedChart,
  Line,
  ResponsiveContainer,
  Tooltip,
  XAxis,
  YAxis,
} from 'recharts';
import { useChartTheme } from '@/components/charts/chart-theme';
import { formatCurrency } from '@/lib/utils';

interface RevenueChartProps {
  data: { date: string; jobs: number; revenue: number }[];
  days?: number;
}

const REVENUE = '#1fa855';
const JOBS = '#8b5cf6';

function fillDays(data: { date: string; jobs: number; revenue: number }[], days: number) {
  const map = new Map(data.map((item) => [item.date.slice(0, 10), item]));
  const start = new Date();
  start.setHours(12, 0, 0, 0);
  start.setDate(start.getDate() - (days - 1));
  return Array.from({ length: days }, (_, index) => {
    const day = new Date(start);
    day.setDate(start.getDate() + index);
    const key = day.toISOString().slice(0, 10);
    const found = map.get(key);
    return {
      date: key,
      label: day.toLocaleDateString('en-GB', { month: 'short', day: 'numeric' }),
      jobs: found?.jobs ?? 0,
      revenue: found?.revenue ?? 0,
    };
  });
}

function ChartTooltip({
  active,
  payload,
}: {
  active?: boolean;
  payload?: { payload: { label: string; jobs: number; revenue: number } }[];
}) {
  if (!active || !payload?.length) return null;
  const point = payload[0].payload;
  return (
    <div className="rounded-xl border border-border bg-white px-3 py-2 text-xs shadow-md">
      <p className="font-medium text-primary">{point.label}</p>
      <p className="mt-1 text-secondary">Jobs {point.jobs}</p>
      <p className="text-secondary">Revenue {formatCurrency(point.revenue)}</p>
    </div>
  );
}

export function RevenueChart({ data, days = 7 }: RevenueChartProps) {
  const theme = useChartTheme();
  const series = fillDays(data, days);

  return (
    <ResponsiveContainer width="100%" height={250}>
      <ComposedChart data={series} margin={{ top: 8, right: 8, left: -18, bottom: 0 }}>
        <defs>
          <linearGradient id="jobsFill" x1="0" y1="0" x2="0" y2="1">
            <stop offset="0%" stopColor={JOBS} stopOpacity={0.22} />
            <stop offset="100%" stopColor={JOBS} stopOpacity={0} />
          </linearGradient>
          <linearGradient id="revenueFill" x1="0" y1="0" x2="0" y2="1">
            <stop offset="0%" stopColor={REVENUE} stopOpacity={0.2} />
            <stop offset="100%" stopColor={REVENUE} stopOpacity={0} />
          </linearGradient>
        </defs>
        <CartesianGrid stroke={theme.grid} vertical={false} />
        <XAxis dataKey="label" tick={{ fill: theme.text, fontSize: 11 }} axisLine={false} tickLine={false} />
        <YAxis yAxisId="jobs" tick={{ fill: theme.text, fontSize: 11 }} axisLine={false} tickLine={false} allowDecimals={false} />
        <YAxis yAxisId="revenue" hide />
        <Tooltip content={<ChartTooltip />} />
        <Area yAxisId="jobs" type="monotone" dataKey="jobs" stroke="none" fill="url(#jobsFill)" />
        <Line yAxisId="jobs" type="monotone" dataKey="jobs" stroke={JOBS} strokeWidth={2.5} dot={false} />
        <Area yAxisId="revenue" type="monotone" dataKey="revenue" stroke="none" fill="url(#revenueFill)" />
        <Line yAxisId="revenue" type="monotone" dataKey="revenue" stroke={REVENUE} strokeWidth={2.5} dot={false} />
      </ComposedChart>
    </ResponsiveContainer>
  );
}
