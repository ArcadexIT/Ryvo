'use client';

import { Calendar } from 'lucide-react';
import { cn } from '@/lib/utils';

export type DateRange = '7d' | '30d' | '90d' | 'custom';

interface DateRangePickerProps {
  value: DateRange;
  onChange: (value: DateRange) => void;
  className?: string;
}

const OPTIONS: { value: DateRange; label: string }[] = [
  { value: '7d', label: '7 days' },
  { value: '30d', label: '30 days' },
  { value: '90d', label: '90 days' },
];

export function dateRangeToDays(range: DateRange): number {
  switch (range) {
    case '7d':
      return 7;
    case '30d':
      return 30;
    case '90d':
      return 90;
    default:
      return 7;
  }
}

export function DateRangePicker({ value, onChange, className }: DateRangePickerProps) {
  return (
    <div className={cn('inline-flex items-center gap-1 rounded-full bg-elevated p-1 shadow-sm ring-1 ring-border', className)}>
      {OPTIONS.map((opt) => (
        <button
          key={opt.value}
          type="button"
          onClick={() => onChange(opt.value)}
          className={cn(
            'rounded-full px-3.5 py-1.5 text-xs font-medium transition-colors',
            value === opt.value
              ? 'bg-[#1fa855] text-white'
              : 'text-secondary hover:text-primary',
          )}
        >
          {opt.label}
        </button>
      ))}
      <button
        type="button"
        onClick={() => onChange('custom')}
        aria-label="Custom range"
        className={cn(
          'grid h-8 w-8 place-items-center rounded-full transition-colors',
          value === 'custom' ? 'bg-[#1fa855] text-white' : 'text-secondary hover:bg-surface hover:text-primary',
        )}
      >
        <Calendar className="h-4 w-4" />
      </button>
    </div>
  );
}
