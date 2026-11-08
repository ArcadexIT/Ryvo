import type { ReactNode } from 'react';
import { cn } from '@/lib/utils';

interface KeyValueItem {
  label: string;
  value: ReactNode;
}

export function KeyValueList({ items, className }: { items: KeyValueItem[]; className?: string }) {
  return (
    <dl className={cn('divide-y divide-hairline', className)}>
      {items.map((item) => (
        <div key={item.label} className="flex items-start justify-between gap-4 py-3">
          <dt className="text-sm text-muted">{item.label}</dt>
          <dd className="num text-right text-sm font-medium text-primary">{item.value}</dd>
        </div>
      ))}
    </dl>
  );
}
