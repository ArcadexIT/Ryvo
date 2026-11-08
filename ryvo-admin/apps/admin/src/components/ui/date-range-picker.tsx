'use client';

import { Calendar } from 'lucide-react';
import { Button } from '@/components/ui/button';
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
} from '@/components/ui/dropdown-menu';

export type DateRange = 'today' | '7d' | '30d' | '90d' | 'qtd' | 'custom';

interface DateRangePickerProps {
  value: DateRange;
  onChange: (value: DateRange) => void;
  className?: string;
}

const OPTIONS: { value: DateRange; label: string }[] = [
  { value: 'today', label: 'Today' },
  { value: '7d', label: '7d' },
  { value: '30d', label: '30d' },
  { value: 'qtd', label: 'QTD' },
  { value: 'custom', label: 'Custom' },
];

export function dateRangeToDays(range: DateRange): number {
  const now = new Date();
  switch (range) {
    case 'today':
      return 1;
    case '7d':
      return 7;
    case '30d':
      return 30;
    case '90d':
      return 90;
    case 'qtd': {
      const start = new Date(now.getFullYear(), Math.floor(now.getMonth() / 3) * 3, 1);
      return Math.max(1, Math.round((now.getTime() - start.getTime()) / 86_400_000) + 1);
    }
    default:
      return 30;
  }
}

export function DateRangePicker({ value, onChange, className }: DateRangePickerProps) {
  const current = OPTIONS.find((option) => option.value === value)?.label ?? 'Custom';

  return (
    <DropdownMenu>
      <DropdownMenuTrigger asChild>
        <Button variant="secondary" className={className}>
          <Calendar strokeWidth={1.75} />
          {current}
        </Button>
      </DropdownMenuTrigger>
      <DropdownMenuContent align="end">
        {OPTIONS.map((option) => (
          <DropdownMenuItem key={option.value} onClick={() => onChange(option.value)}>
            {option.label}
          </DropdownMenuItem>
        ))}
      </DropdownMenuContent>
    </DropdownMenu>
  );
}
