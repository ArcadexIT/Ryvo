import type { ReactNode } from 'react';
import Link from 'next/link';
import type { LucideIcon } from 'lucide-react';
import { Info } from 'lucide-react';
import { StatWave } from '@/components/ui/sparkline';
import { cn } from '@/lib/utils';

export type StatTone = 'emerald' | 'sky' | 'violet' | 'amber' | 'teal' | 'rose';

const TONES: Record<StatTone, { wash: string; ink: string; wave: string; variant: number }> = {
  emerald: { wash: 'stat-wash-emerald', ink: 'text-chart-1', wave: 'var(--chart-1)', variant: 0 },
  sky: { wash: 'stat-wash-sky', ink: 'text-chart-2', wave: 'var(--chart-2)', variant: 1 },
  violet: { wash: 'stat-wash-violet', ink: 'text-chart-4', wave: 'var(--chart-4)', variant: 2 },
  amber: { wash: 'stat-wash-amber', ink: 'text-chart-3', wave: 'var(--chart-3)', variant: 0 },
  teal: { wash: 'stat-wash-teal', ink: 'text-chart-teal', wave: 'var(--chart-teal)', variant: 1 },
  rose: { wash: 'stat-wash-rose', ink: 'text-chart-5', wave: 'var(--chart-5)', variant: 2 },
};

interface StatProps {
  label: string;
  value: ReactNode;
  delta?: number | null;
  caption?: string;
  href?: string;
  tone?: StatTone;
  icon?: LucideIcon;
  mark?: LucideIcon;
}

export function Stat({
  label,
  value,
  caption = 'vs previous period',
  href,
  tone = 'emerald',
  icon: Icon,
  mark: Mark,
}: StatProps) {
  const colors = TONES[tone];
  const body = (
    <div className={cn('relative h-[138px] overflow-hidden rounded-[18px] border border-white/70 p-4', colors.wash)}>
      <div className="relative z-10 flex items-start justify-between gap-3">
        <div className="flex min-w-0 items-start gap-3">
          {Icon ? (
            <span className={cn('grid size-10 shrink-0 place-items-center rounded-full bg-white/85 shadow-sm', colors.ink)}>
              <Icon className="size-[18px]" strokeWidth={1.75} />
            </span>
          ) : null}
          <div className="min-w-0">
            <p className="text-sm text-muted">{label}</p>
            <p className="num mt-1 text-[28px] font-bold leading-none tracking-tight text-primary">{value}</p>
          </div>
        </div>
        {Mark ? <Mark className={cn('size-4 shrink-0', colors.ink)} strokeWidth={1.75} /> : null}
      </div>
      <p className="relative z-10 mt-3 inline-flex items-center gap-1 text-xs text-muted">
        {caption}
        <Info className="size-3.5" strokeWidth={1.75} />
      </p>
      <div className={cn('pointer-events-none absolute inset-x-0 bottom-0 h-16', colors.ink)}>
        <StatWave color={colors.wave} variant={colors.variant} />
      </div>
    </div>
  );

  if (!href) return body;
  return (
    <Link href={href} className="block rounded-[18px] transition-transform duration-150 hover:-translate-y-0.5">
      {body}
    </Link>
  );
}
