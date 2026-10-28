'use client';

import { ChevronLeft, ChevronRight } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { cn } from '@/lib/utils';
import type { PaginationMeta } from '@/lib/api';

interface PaginationProps {
  meta?: PaginationMeta;
  page: number;
  onPageChange: (page: number) => void;
  pageSize?: number;
  onPageSizeChange?: (size: number) => void;
  className?: string;
}

const PAGE_SIZES = [10, 20, 50, 100];

export function Pagination({
  meta,
  page,
  onPageChange,
  pageSize = 20,
  onPageSizeChange,
  className,
}: PaginationProps) {
  const totalPages = meta?.totalPages ?? 1;
  const total = meta?.total ?? 0;

  const rangeStart = total === 0 ? 0 : (page - 1) * pageSize + 1;
  const rangeEnd = Math.min(page * pageSize, total);

  const pages = getPageNumbers(page, totalPages);

  return (
    <div
      className={cn(
        'flex flex-wrap items-center justify-between gap-4 border-t border-border pt-4 text-sm text-secondary',
        className,
      )}
    >
      <div className="flex items-center gap-3">
        <span className="font-tabular">
          {total === 0 ? (
            'No results'
          ) : (
            <>
              <span className="font-medium text-primary">
                {rangeStart}–{rangeEnd}
              </span>{' '}
              of <span className="font-medium text-primary">{total}</span>
            </>
          )}
        </span>
        {onPageSizeChange && (
          <select
            value={pageSize}
            onChange={(e) => onPageSizeChange(Number(e.target.value))}
            className="h-8 rounded-lg border border-border bg-elevated px-2 text-xs text-primary transition-colors hover:border-border-strong"
          >
            {PAGE_SIZES.map((s) => (
              <option key={s} value={s}>
                {s} / page
              </option>
            ))}
          </select>
        )}
      </div>
      <div className="flex items-center gap-1">
        <Button
          variant="ghost"
          size="icon"
          className="h-8 w-8 rounded-full"
          disabled={page <= 1}
          onClick={() => onPageChange(page - 1)}
          aria-label="Previous page"
        >
          <ChevronLeft className="h-4 w-4" />
        </Button>
        {pages.map((p, i) =>
          p === '...' ? (
            <span key={`ellipsis-${i}`} className="px-1.5 text-muted">
              …
            </span>
          ) : (
            <button
              key={p}
              type="button"
              onClick={() => onPageChange(p as number)}
              className={cn(
                'font-tabular flex h-8 min-w-8 items-center justify-center rounded-full px-2 text-sm font-medium transition-colors duration-150',
                p === page
                  ? 'bg-accent text-accent-foreground shadow-xs'
                  : 'text-secondary hover:bg-surface hover:text-primary',
              )}
              aria-current={p === page ? 'page' : undefined}
            >
              {p}
            </button>
          ),
        )}
        <Button
          variant="ghost"
          size="icon"
          className="h-8 w-8 rounded-full"
          disabled={page >= totalPages}
          onClick={() => onPageChange(page + 1)}
          aria-label="Next page"
        >
          <ChevronRight className="h-4 w-4" />
        </Button>
      </div>
    </div>
  );
}

function getPageNumbers(current: number, total: number): (number | '...')[] {
  if (total <= 7) return Array.from({ length: total }, (_, i) => i + 1);
  if (current <= 3) return [1, 2, 3, 4, '...', total];
  if (current >= total - 2) return [1, '...', total - 3, total - 2, total - 1, total];
  return [1, '...', current - 1, current, current + 1, '...', total];
}
