'use client';

import { useEffect, useMemo, useState } from 'react';
import { ChevronDown, ChevronUp, ChevronsUpDown, Columns3, Rows3, Search } from 'lucide-react';
import { Input } from '@/components/ui/input';
import { Button } from '@/components/ui/button';
import { EmptyState } from '@/components/ui/empty-state';
import { Pagination } from '@/components/ui/pagination';
import { TableSkeleton } from '@/components/ui/skeleton';
import { ExportButton } from '@/components/ui/export-button';
import { ListExportButton } from '@/components/ui/list-export-button';
import { FilterBar } from '@/components/ui/filter-bar';
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from '@/components/ui/table';
import type { PaginationMeta } from '@/lib/api';
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
} from '@/components/ui/dropdown-menu';
import { Tooltip, TooltipContent, TooltipProvider, TooltipTrigger } from '@/components/ui/tooltip';
import { cn } from '@/lib/utils';

export interface Column<T> {
  key: string;
  header: string;
  render: (row: T) => React.ReactNode;
  searchable?: (row: T) => string;
  sortable?: boolean;
  sortValue?: (row: T) => string | number;
  exportValue?: (row: T) => string | number;
  numeric?: boolean;
  truncate?: boolean;
}

export interface FilterConfig {
  key: string;
  label: string;
  options: { value: string; label: string }[];
  value: string;
  onChange: (value: string) => void;
}

interface DataTableProps<T extends { id?: string }> {
  data: T[];
  columns: Column<T>[];
  meta?: PaginationMeta;
  page: number;
  onPageChange: (page: number) => void;
  pageSize?: number;
  onPageSizeChange?: (size: number) => void;
  searchPlaceholder?: string;
  onRowClick?: (row: T) => void;
  isLoading?: boolean;
  error?: string | null;
  emptyMessage?: string;
  emptyActionLabel?: string;
  onEmptyAction?: () => void;
  exportFilename?: string;
  /** Server-side CSV export with current filters (up to 5000 rows). */
  serverExport?: {
    type:
      | 'customers'
      | 'jobs'
      | 'support'
      | 'audit'
      | 'reviews'
      | 'admins'
      | 'promos'
      | 'countries';
    params?: Record<string, string | number | boolean | undefined>;
  };
  /** When set, search is controlled by parent and sent to API (no client-side search filter). */
  searchValue?: string;
  onSearchChange?: (value: string) => void;
  filters?: FilterConfig[];
  enableBulkSelect?: boolean;
  bulkActions?: { label: string; onClick: (ids: string[]) => void; variant?: 'default' | 'destructive' }[];
  getRowId?: (row: T) => string;
  savedView?: React.ReactNode;
}

type SortDir = 'asc' | 'desc';

export function DataTable<T extends { id?: string }>({
  data,
  columns,
  meta,
  page,
  onPageChange,
  pageSize = 20,
  onPageSizeChange,
  searchPlaceholder = 'Search...',
  onRowClick,
  isLoading,
  error,
  emptyMessage = 'No records found.',
  emptyActionLabel,
  onEmptyAction,
  exportFilename,
  serverExport,
  searchValue,
  onSearchChange,
  filters,
  enableBulkSelect,
  bulkActions,
  getRowId = (row) => row.id ?? '',
  savedView,
}: DataTableProps<T>) {
  const [localSearch, setLocalSearch] = useState(searchValue ?? '');
  const serverSearch = !!onSearchChange;

  useEffect(() => {
    if (searchValue !== undefined) setLocalSearch(searchValue);
  }, [searchValue]);

  useEffect(() => {
    if (!onSearchChange) return;
    const timer = setTimeout(() => onSearchChange(localSearch), 300);
    return () => clearTimeout(timer);
  }, [localSearch, onSearchChange]);

  const search = localSearch;

  const [sortKey, setSortKey] = useState<string | null>(null);
  const [sortDir, setSortDir] = useState<SortDir>('asc');
  const [selected, setSelected] = useState<Set<string>>(new Set());
  const [hidden, setHidden] = useState<Set<string>>(new Set());
  const [compact, setCompact] = useState(false);
  const visibleColumns = columns.filter((col) => !hidden.has(col.key));

  const filtered = useMemo(() => {
    let rows = data;
    if (!serverSearch && search.trim()) {
      const q = search.toLowerCase();
      rows = rows.filter((row) =>
        columns.some((col) => col.searchable?.(row)?.toLowerCase().includes(q)),
      );
    }
    if (sortKey) {
      const col = columns.find((c) => c.key === sortKey);
      if (col?.sortValue) {
        rows = [...rows].sort((a, b) => {
          const av = col.sortValue!(a);
          const bv = col.sortValue!(b);
          const cmp = av < bv ? -1 : av > bv ? 1 : 0;
          return sortDir === 'asc' ? cmp : -cmp;
        });
      }
    }
    return rows;
  }, [data, columns, search, sortKey, sortDir, serverSearch]);

  function toggleSort(key: string) {
    if (sortKey === key) {
      setSortDir((d) => (d === 'asc' ? 'desc' : 'asc'));
    } else {
      setSortKey(key);
      setSortDir('asc');
    }
  }

  function toggleSelect(id: string) {
    setSelected((prev) => {
      const next = new Set(prev);
      if (next.has(id)) next.delete(id);
      else next.add(id);
      return next;
    });
  }

  function toggleSelectAll() {
    if (selected.size === filtered.length) {
      setSelected(new Set());
    } else {
      setSelected(new Set(filtered.map(getRowId).filter(Boolean)));
    }
  }

  const exportCols = columns.filter((c) => c.exportValue);

  const exportData = useMemo(
    () =>
      filtered.map((row) => {
        const record: Record<string, string | number> = {};
        for (const col of exportCols) {
          record[col.key] = col.exportValue!(row);
        }
        return record;
      }),
    [filtered, exportCols],
  );

  if (isLoading) {
    return <TableSkeleton rows={6} cols={columns.length} />;
  }

  if (error) {
    return (
      <div className="flex h-48 items-center justify-center rounded-lg border border-danger/30 bg-danger/5">
        <p className="text-sm text-danger">{error}</p>
      </div>
    );
  }

  function toggleColumn(key: string) {
    setHidden((prev) => {
      const next = new Set(prev);
      if (next.has(key)) next.delete(key);
      else if (columns.length - next.size > 1) next.add(key);
      return next;
    });
  }

  return (
    <TooltipProvider delayDuration={400}>
    <div className="space-y-3">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <div className="min-w-[200px] max-w-sm flex-1">
          <Input
            leading={<Search strokeWidth={1.75} />}
            placeholder={searchPlaceholder}
            value={search}
            onChange={(e) => setLocalSearch(e.target.value)}
            className="rounded-full"
          />
        </div>
        <div className="flex items-center gap-2">
          <Button
            variant="ghost"
            size="icon"
            aria-label={compact ? 'Comfortable rows' : 'Compact rows'}
            aria-pressed={compact}
            onClick={() => setCompact((value) => !value)}
          >
            <Rows3 strokeWidth={1.75} />
          </Button>
          <DropdownMenu>
            <DropdownMenuTrigger asChild>
              <Button variant="ghost" size="icon" aria-label="Columns">
                <Columns3 strokeWidth={1.75} />
              </Button>
            </DropdownMenuTrigger>
            <DropdownMenuContent align="end">
              {columns.map((col) => (
                <DropdownMenuItem key={col.key} onSelect={(event) => event.preventDefault()} onClick={() => toggleColumn(col.key)}>
                  <span className={cn('size-3 rounded-sm border border-hairline', !hidden.has(col.key) && 'bg-primary')} />
                  {col.header}
                </DropdownMenuItem>
              ))}
            </DropdownMenuContent>
          </DropdownMenu>
          {serverExport ? (
            <ListExportButton type={serverExport.type} params={serverExport.params} />
          ) : (
            exportFilename &&
            exportCols.length > 0 && (
              <ExportButton
                data={exportData}
                filename={exportFilename}
                columns={exportCols.map((c) => ({ key: c.key, header: c.header }))}
              />
            )
          )}
        </div>
      </div>

      {filters && filters.length > 0 && <FilterBar filters={filters} savedView={savedView} />}

      {enableBulkSelect && selected.size > 0 && (
        <div className="sticky bottom-3 z-20 flex items-center gap-3 rounded-lg border border-hairline bg-sheet px-4 py-2 shadow-popover">
          <span className="num text-sm font-medium text-primary">{selected.size} selected</span>
          {bulkActions?.map((action) => (
            <Button
              key={action.label}
              size="sm"
              variant={action.variant === 'destructive' ? 'destructive' : 'outline'}
              onClick={() => {
                action.onClick(Array.from(selected));
                setSelected(new Set());
              }}
            >
              {action.label}
            </Button>
          ))}
          <Button size="sm" variant="ghost" onClick={() => setSelected(new Set())}>
            Clear
          </Button>
        </div>
      )}

      {filtered.length === 0 ? (
        <EmptyState
          title={emptyMessage}
          actionLabel={emptyActionLabel}
          onAction={onEmptyAction}
        />
      ) : (
        <div className="overflow-hidden rounded-lg border border-hairline bg-sheet">
          <Table>
            <TableHeader>
              <TableRow className="hover:bg-transparent">
                {enableBulkSelect && (
                  <TableHead className="w-10">
                    <input
                      type="checkbox"
                      checked={selected.size === filtered.length && filtered.length > 0}
                      onChange={toggleSelectAll}
                      aria-label="Select all rows"
                      className="rounded border-hairline"
                      style={{ accentColor: 'var(--primary)' }}
                    />
                  </TableHead>
                )}
                {visibleColumns.map((col) => (
                  <TableHead key={col.key} className={cn(col.numeric && 'text-right')}>
                    {col.sortable !== false && col.sortValue ? (
                      <button
                        type="button"
                        className={cn('inline-flex items-center gap-1 hover:text-primary', col.numeric && 'ml-auto')}
                        onClick={() => toggleSort(col.key)}
                      >
                        {col.header}
                        {sortKey === col.key ? (
                          sortDir === 'asc' ? (
                            <ChevronUp className="size-3" strokeWidth={1.75} />
                          ) : (
                            <ChevronDown className="size-3" strokeWidth={1.75} />
                          )
                        ) : (
                          <ChevronsUpDown className="size-3 opacity-40" strokeWidth={1.75} />
                        )}
                      </button>
                    ) : (
                      col.header
                    )}
                  </TableHead>
                ))}
              </TableRow>
            </TableHeader>
            <TableBody>
              {filtered.map((row, idx) => {
                const rowId = getRowId(row);
                return (
                  <TableRow
                    key={rowId || idx}
                    className={cn(onRowClick && 'cursor-pointer', selected.has(rowId) && 'selected-surface')}
                    onClick={() => onRowClick?.(row)}
                  >
                    {enableBulkSelect && (
                      <TableCell className={compact ? 'h-9' : undefined} onClick={(e) => e.stopPropagation()}>
                        <input
                          type="checkbox"
                          checked={selected.has(rowId)}
                          onChange={() => toggleSelect(rowId)}
                          aria-label="Select row"
                          className="rounded border-hairline"
                          style={{ accentColor: 'var(--primary)' }}
                        />
                      </TableCell>
                    )}
                    {visibleColumns.map((col) => (
                      <TableCell
                        key={col.key}
                        className={cn(compact && 'h-9', col.numeric && 'num text-right')}
                      >
                        <CellValue truncate={col.truncate}>{col.render(row)}</CellValue>
                      </TableCell>
                    ))}
                  </TableRow>
                );
              })}
            </TableBody>
          </Table>
        </div>
      )}

      {meta && (
        <Pagination
          meta={meta}
          page={page}
          onPageChange={onPageChange}
          pageSize={pageSize}
          onPageSizeChange={onPageSizeChange}
        />
      )}
    </div>
    </TooltipProvider>
  );
}

function CellValue({ truncate, children }: { truncate?: boolean; children: React.ReactNode }) {
  if (!truncate || (typeof children !== 'string' && typeof children !== 'number')) return children;
  const text = String(children);
  return (
    <Tooltip>
      <TooltipTrigger asChild>
        <span className="block max-w-[220px] truncate">{text}</span>
      </TooltipTrigger>
      <TooltipContent>{text}</TooltipContent>
    </Tooltip>
  );
}
