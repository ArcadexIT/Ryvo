'use client';

import {
  Area,
  Bar,
  CartesianGrid,
  ComposedChart,
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
      <p className="num mt-1 text-chart-2">Trips {point.jobs}</p>
      <p className="num text-chart-1">Revenue {formatCurrency(point.revenue)}</p>
    </div>
  );
}

export function RevenueChart({ data, days = 7 }: RevenueChartProps) {
  const theme = useChartTheme();
  const series = fillDays(data, days);
  const empty = series.every((point) => point.jobs === 0 && point.revenue === 0);

  return (
    <div className="relative">
      <ResponsiveContainer width="100%" height={280}>
        <ComposedChart data={series} margin={{ top: 8, right: 8, left: -12, bottom: 0 }}>
          <CartesianGrid stroke={theme.grid} vertical={false} />
          <XAxis
            dataKey="label"
            tick={{ fill: theme.text, fontSize: 11 }}
            axisLine={false}
            tickLine={false}
            interval="preserveStartEnd"
            minTickGap={24}
          />
          <YAxis
            yAxisId="jobs"
            tick={{ fill: theme.text, fontSize: 11 }}
            axisLine={false}
            tickLine={false}
            allowDecimals={false}
            width={32}
          />
          <YAxis yAxisId="revenue" orientation="right" hide />
          <Tooltip content={<ChartTooltip />} cursor={{ fill: 'var(--input)' }} />
          <Bar
            yAxisId="jobs"
            dataKey="jobs"
            fill="var(--chart-2)"
            radius={[5, 5, 0, 0]}
            maxBarSize={28}
          />
          <Area
            yAxisId="revenue"
            type="monotone"
            dataKey="revenue"
            stroke="var(--chart-1)"
            strokeWidth={2.5}
            fill="var(--chart-1)"
            fillOpacity={0.18}
            dot={false}
          />
        </ComposedChart>
      </ResponsiveContainer>
      {empty ? (
        <p className="pointer-events-none absolute inset-0 flex items-center justify-center text-sm text-muted">
          No trips in this range.
        </p>
      ) : null}
    </div>
  );
}
