'use client';

import { type LucideIcon } from 'lucide-react';
import { cn } from '@/lib/utils';

interface SegmentedTabItem {
  value: string;
  label: string;
  icon?: LucideIcon;
  count?: number;
}

interface SegmentedTabsProps {
  items: SegmentedTabItem[];
  value: string;
  onChange: (value: string) => void;
  className?: string;
}

export function SegmentedTabs({ items, value, onChange, className }: SegmentedTabsProps) {
  return (
    <div className={cn('inline-flex items-center gap-1 rounded-lg bg-surface p-1', className)}>
      {items.map((item) => {
        const active = item.value === value;
        const Icon = item.icon;
        return (
          <button
            key={item.value}
            type="button"
            onClick={() => onChange(item.value)}
            className={cn(
              'inline-flex items-center gap-1.5 rounded-md px-3 py-1.5 text-sm font-medium transition-all duration-150',
              active
                ? 'bg-elevated text-primary shadow-xs'
                : 'text-secondary hover:text-primary',
            )}
          >
            {Icon && <Icon className="h-3.5 w-3.5" />}
            {item.label}
            {item.count !== undefined && (
              <span
                className={cn(
                  'font-tabular rounded-full px-1.5 py-px text-[11px]',
                  active ? 'bg-accent-soft text-accent' : 'bg-border/70 text-muted',
                )}
              >
                {item.count}
              </span>
            )}
          </button>
        );
      })}
    </div>
  );
}
