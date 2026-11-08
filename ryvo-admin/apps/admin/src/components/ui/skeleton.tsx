import * as React from 'react';
import { cn } from '@/lib/utils';

export function Skeleton({ className, ...props }: React.HTMLAttributes<HTMLDivElement>) {
  return <div className={cn('skeleton-shimmer rounded-md bg-input', className)} {...props} />;
}

export function TableSkeleton({ rows = 5, cols = 4 }: { rows?: number; cols?: number }) {
  return (
    <div className="space-y-2 rounded-lg border border-hairline bg-sheet p-4">
      <Skeleton className="h-9 w-full" />
      {Array.from({ length: rows }).map((_, i) => (
        <Skeleton key={i} className="h-11 w-full" style={{ opacity: 1 - i * 0.08 }} />
      ))}
      <span className="sr-only">{cols} columns loading</span>
    </div>
  );
}

export function CardSkeleton() {
  return (
    <div className="rounded-lg border border-hairline bg-card p-4">
      <Skeleton className="mb-3 h-3 w-24" />
      <Skeleton className="h-8 w-32" />
    </div>
  );
}
