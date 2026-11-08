import type { ReactNode } from 'react';
import Link from 'next/link';
import { cn } from '@/lib/utils';

interface StatProps {
  label: string;
  value: ReactNode;
  delta?: number | null;
  caption?: string;
  spark?: ReactNode;
  href?: string;
}

export function Stat({ label, value, delta, caption = 'vs previous period', spark, href }: StatProps) {
  const body = (
    <div className="flex h-full flex-col gap-3 rounded-lg border border-hairline bg-card p-4">
      <div className="flex items-start justify-between gap-3">
        <p className="text-sm text-muted">{label}</p>
        {delta === undefined || delta === null ? null : <Delta value={delta} />}
      </div>
      <p className="num text-2xl font-semibold tracking-tight text-primary">{value}</p>
      <div className="mt-auto flex items-end justify-between gap-3">
        {delta === undefined || delta === null ? <span /> : <p className="text-xs text-muted">{caption}</p>}
        {spark ? <div className="h-8 w-24 text-success">{spark}</div> : null}
      </div>
    </div>
  );

  if (!href) return body;
  return (
    <Link href={href} className="block rounded-lg transition-colors duration-150 hover:bg-input">
      {body}
    </Link>
  );
}

function Delta({ value }: { value: number }) {
  const flat = value === 0;
  const up = value > 0;
  return (
    <span
      className={cn(
        'num rounded-full px-2 py-0.5 text-xs font-medium',
        flat && 'bg-input text-muted',
        up && 'bg-success/10 text-success',
        !flat && !up && 'bg-danger/10 text-danger',
      )}
    >
      {flat ? '0%' : `${up ? '+' : ''}${value}%`}
    </span>
  );
}
