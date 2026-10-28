'use client';

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
  className?: string;
}

export function FilterBar({ filters, activeChips = [], className }: FilterBarProps) {
  return (
    <div className={cn('flex flex-wrap items-center gap-3', className)}>
      {filters.map((filter) => (
        <div key={filter.key} className="flex items-center gap-2">
          <label className="text-xs text-muted">{filter.label}</label>
          <select
            value={filter.value}
            onChange={(e) => filter.onChange(e.target.value)}
            className="h-8 rounded-md border border-border bg-elevated px-2 text-xs text-primary"
          >
            {filter.options.map((opt) => (
              <option key={opt.value} value={opt.value}>
                {opt.label}
              </option>
            ))}
          </select>
        </div>
      ))}
      {activeChips.map((chip) => (
        <button
          key={chip.key}
          type="button"
          onClick={chip.onRemove}
          className="inline-flex items-center gap-1 rounded-full bg-accent-soft px-2.5 py-0.5 text-xs font-medium text-accent"
        >
          {chip.label}
          <X className="h-3 w-3" />
        </button>
      ))}
    </div>
  );
}
