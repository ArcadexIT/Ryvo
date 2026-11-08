'use client';

import type { ReactNode } from 'react';
import { X } from 'lucide-react';
import { cn } from '@/lib/utils';

export interface FilterOption {
  value: string;
  label: string;
}

interface FilterBarProps {
  filters: {
    key: string;
    label: string;
    options: FilterOption[];
    value: string;
    onChange: (value: string) => void;
  }[];
  activeChips?: { key: string; label: string; onRemove: () => void }[];
  savedView?: ReactNode;
  className?: string;
}

function isActive(value: string) {
  return value !== '' && value !== 'all';
}

export function FilterBar({ filters, activeChips = [], savedView, className }: FilterBarProps) {
  const derived = filters
    .filter((filter) => isActive(filter.value))
    .map((filter) => ({
      key: filter.key,
      label: filter.options.find((option) => option.value === filter.value)?.label ?? filter.value,
      onRemove: () => {
        const reset = filter.options.find((option) => !isActive(option.value))?.value ?? '';
        filter.onChange(reset);
      },
    }));
  const chips = activeChips.length > 0 ? activeChips : derived;

  return (
    <div className={cn('flex flex-wrap items-center gap-2', className)}>
      {filters.map((filter) => (
        <label key={filter.key} className="flex items-center gap-2 text-xs text-muted">
          <span>{filter.label}</span>
          <select
            value={filter.value}
            onChange={(e) => filter.onChange(e.target.value)}
            className="h-8 rounded-full border border-transparent bg-input px-3 text-xs text-primary transition-colors duration-150 hover:border-hairline"
          >
            {filter.options.map((opt) => (
              <option key={opt.value} value={opt.value}>
                {opt.label}
              </option>
            ))}
          </select>
        </label>
      ))}
      {chips.map((chip) => (
        <button
          key={chip.key}
          type="button"
          onClick={chip.onRemove}
          className="inline-flex h-8 items-center gap-1 rounded-full bg-input px-3 text-xs font-medium text-primary"
        >
          {chip.label}
          <X className="size-3" strokeWidth={1.75} />
        </button>
      ))}
      {chips.length > 0 ? (
        <button
          type="button"
          onClick={() => chips.forEach((chip) => chip.onRemove())}
          className="text-xs font-medium text-success hover:underline"
        >
          Clear all
          <span className="num ml-1 text-muted">{chips.length}</span>
        </button>
      ) : null}
      {savedView ? <div className="ml-auto">{savedView}</div> : null}
    </div>
  );
}
