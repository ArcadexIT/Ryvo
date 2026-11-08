'use client';

import { useLayoutEffect, useRef, useState } from 'react';
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
  const listRef = useRef<HTMLDivElement>(null);
  const [indicator, setIndicator] = useState({ left: 0, width: 0 });

  useLayoutEffect(() => {
    const root = listRef.current;
    const active = root?.querySelector<HTMLElement>('[data-active="true"]');
    if (!root || !active) return;
    setIndicator({ left: active.offsetLeft, width: active.offsetWidth });
  }, [value, items]);

  return (
    <div
      ref={listRef}
      className={cn('relative inline-flex items-center rounded-lg bg-input p-1', className)}
      role="tablist"
    >
      <span
        aria-hidden
        className="pointer-events-none absolute bottom-1 top-1 rounded-md bg-sheet transition-[left,width] duration-200 ease-out"
        style={{ left: indicator.left, width: indicator.width }}
      />
      {items.map((item) => {
        const active = item.value === value;
        const Icon = item.icon;
        return (
          <button
            key={item.value}
            type="button"
            role="tab"
            data-active={active}
            aria-selected={active}
            onClick={() => onChange(item.value)}
            className={cn(
              'relative z-10 inline-flex h-8 items-center gap-1.5 rounded-md px-3 text-sm font-medium transition-colors duration-150',
              active ? 'text-primary' : 'text-secondary hover:text-primary',
            )}
          >
            {Icon ? <Icon className="size-4" strokeWidth={1.75} /> : null}
            {item.label}
            {item.count !== undefined ? (
              <span className={cn('num rounded-full px-1.5 text-xs', active ? 'text-primary' : 'text-muted')}>
                {item.count}
              </span>
            ) : null}
          </button>
        );
      })}
    </div>
  );
}
