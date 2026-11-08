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
    <div className="rounded-lg border border-hairline bg-sheet px-3 py-2 text-xs shadow-popover">
      <p className="font-medium text-primary">{point.label}</p>
      <p className="num mt-1 text-muted">Trips {point.jobs}</p>
      <p className="num text-muted">Revenue {formatCurrency(point.revenue)}</p>
    </div>
  );
}

export function RevenueChart({ data, days = 7 }: RevenueChartProps) {
  const theme = useChartTheme();
  const series = fillDays(data, days);
  if (series.every((point) => point.jobs === 0 && point.revenue === 0)) {
    return <p className="flex h-[250px] items-center justify-center text-sm text-muted">No trips in this range.</p>;
  }

  return (
    <ResponsiveContainer width="100%" height={250}>
      <ComposedChart data={series} margin={{ top: 8, right: 8, left: -18, bottom: 0 }}>
        <CartesianGrid stroke={theme.grid} vertical={false} />
        <XAxis dataKey="label" tick={{ fill: theme.text, fontSize: 12 }} axisLine={false} tickLine={false} />
        <YAxis
          yAxisId="jobs"
          tick={{ fill: theme.text, fontSize: 12 }}
          axisLine={false}
          tickLine={false}
          allowDecimals={false}
        />
        <YAxis yAxisId="revenue" hide />
        <Tooltip content={<ChartTooltip />} />
        <Area
          yAxisId="revenue"
          type="monotone"
          dataKey="revenue"
          stroke="var(--success)"
          strokeWidth={2}
          fill="var(--success)"
          fillOpacity={0.1}
          dot={false}
        />
        <Line
          yAxisId="jobs"
          type="monotone"
          dataKey="jobs"
          stroke="var(--text-muted)"
          strokeWidth={1.75}
          dot={false}
        />
      </ComposedChart>
    </ResponsiveContainer>
  );
}
