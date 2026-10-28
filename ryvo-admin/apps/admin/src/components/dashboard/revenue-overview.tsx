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
    <section className="rounded-2xl border border-border bg-elevated p-4 shadow-sm">
      <h2 className="text-sm font-semibold text-primary">Revenue Overview</h2>
      <p className="text-[11px] text-muted">Last 7 days</p>
      <p className="mt-3 text-[1.7rem] font-semibold tracking-tight text-primary">{formatCurrency(total)}</p>
      <p className={up ? 'text-xs font-medium text-[#1fa855]' : 'text-xs font-medium text-danger'}>
        {up ? '' : '-'}
        {Math.abs(trend)}% vs previous 7 days
      </p>
      <div className="mt-2 h-16">
        <ResponsiveContainer width="100%" height="100%">
          <AreaChart data={points}>
            <defs>
              <linearGradient id="revMini" x1="0" y1="0" x2="0" y2="1">
                <stop offset="0%" stopColor="#1fa855" stopOpacity={0.25} />
                <stop offset="100%" stopColor="#1fa855" stopOpacity={0} />
              </linearGradient>
            </defs>
            <Area type="monotone" dataKey="revenue" stroke="#1fa855" strokeWidth={2} fill="url(#revMini)" />
          </AreaChart>
        </ResponsiveContainer>
      </div>
    </section>
  );
}
