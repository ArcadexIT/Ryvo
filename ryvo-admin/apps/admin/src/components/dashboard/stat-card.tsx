'use client';

import { type LucideIcon, TrendingDown, TrendingUp } from 'lucide-react';
import { cn } from '@/lib/utils';
import { Sparkline, seededSparklineData } from '@/components/ui/sparkline';

interface StatCardProps {
  label: string;
  value: string | number;
  icon: LucideIcon;
  iconColor?: string;
  iconBg?: string;
  trend?: number;
  sparklineSeed?: number;
  className?: string;
}

export function StatCard({
  label,
  value,
  icon: Icon,
  iconColor = 'text-info',
  iconBg = 'bg-info/10',
  trend,
  sparklineSeed = 0,
  className,
}: StatCardProps) {
  const trendUp = trend !== undefined && trend >= 0;
  const trendColor = trendUp ? 'var(--success)' : 'var(--danger)';
  const sparklineData =
    trend !== undefined ? seededSparklineData(sparklineSeed, trend) : null;

  return (
    <div className={cn('bg-base p-4', className)}>
      <div className="flex items-start justify-between">
        <div
          className={cn(
            'flex h-10 w-10 items-center justify-center rounded-lg shadow-xs',
            iconBg,
          )}
        >
          <Icon className={cn('h-5 w-5', iconColor)} strokeWidth={2.25} />
        </div>
        {trend !== undefined && (
          <span
            className={cn(
              'inline-flex items-center gap-0.5 rounded-full px-2 py-0.5 text-xs font-medium',
              trendUp ? 'bg-success/15 text-success' : 'bg-danger/15 text-danger',
            )}
          >
            {trendUp ? <TrendingUp className="h-3 w-3" /> : <TrendingDown className="h-3 w-3" />}
            {Math.abs(trend)}%
          </span>
        )}
      </div>

      <p className="mt-4 text-xs font-medium text-secondary">{label}</p>
      <p className="font-tabular font-display mt-1 text-stat text-primary">{value}</p>

      {sparklineData && (
        <div className="-mx-1 -mb-1 mt-3 opacity-70 transition-opacity duration-200 group-hover:opacity-100">
          <Sparkline data={sparklineData} color={trendColor} height={28} />
        </div>
      )}
    </div>
  );
}
