'use client';

import { Area, AreaChart, ResponsiveContainer } from 'recharts';
import { formatCurrency } from '@/lib/utils';

interface RevenueOverviewProps {
  total: number;
  trend?: number;
  series: { date: string; revenue: number }[];
}

export function RevenueOverview({ total, trend = 0, series }: RevenueOverviewProps) {
  const up = trend >= 0;
  const points = series.length > 1 ? series : [{ date: 'a', revenue: 0 }, { date: 'b', revenue: 0 }];

  return (
    <section className="rounded-lg border border-hairline bg-card p-4">
      <h2 className="text-sm font-semibold text-primary">Revenue</h2>
      <p className="num mt-3 text-2xl font-semibold tracking-tight text-primary">{formatCurrency(total)}</p>
      <p className={up ? 'num text-xs font-medium text-success' : 'num text-xs font-medium text-danger'}>
        {up ? '+' : '−'}
        {Math.abs(trend)}% vs previous period
      </p>
      <div className="mt-2 h-16 text-success">
        <ResponsiveContainer width="100%" height="100%">
          <AreaChart data={points}>
            <Area
              type="monotone"
              dataKey="revenue"
              stroke="var(--success)"
              strokeWidth={1.75}
              fill="var(--success)"
              fillOpacity={0.1}
            />
          </AreaChart>
        </ResponsiveContainer>
      </div>
    </section>
  );
}
