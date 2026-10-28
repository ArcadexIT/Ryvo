'use client';

import { useEffect, useMemo, useState } from 'react';
import { ChevronDown, ChevronUp, Search } from 'lucide-react';
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
import { cn } from '@/lib/utils';

export interface Column<T> {
  key: string;
  header: string;
  render: (row: T) => React.ReactNode;
  searchable?: (row: T) => string;
  sortable?: boolean;
  sortValue?: (row: T) => string | number;
  exportValue?: (row: T) => string | number;
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

  return (
    <div className="space-y-4">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <div className="relative min-w-[200px] max-w-sm flex-1">
          <Search className="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-muted" />
          <Input
            placeholder={searchPlaceholder}
            value={search}
            onChange={(e) => setLocalSearch(e.target.value)}
            className="pl-9"
          />
        </div>
        <div className="flex items-center gap-2">
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

      {filters && filters.length > 0 && <FilterBar filters={filters} />}

      {enableBulkSelect && selected.size > 0 && (
        <div className="flex items-center gap-3 rounded-md border border-accent/30 bg-accent-soft px-4 py-2">
          <span className="text-sm font-medium text-accent">{selected.size} selected</span>
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
        <div className="overflow-hidden rounded-xl border border-border bg-elevated shadow-sm">
          <Table>
            <TableHeader>
              <TableRow className="hover:bg-transparent even:bg-transparent">
                {enableBulkSelect && (
                  <TableHead className="w-10">
                    <input
                      type="checkbox"
                      checked={selected.size === filtered.length && filtered.length > 0}
                      onChange={toggleSelectAll}
                      className="rounded border-border accent-accent"
                    />
                  </TableHead>
                )}
                {columns.map((col) => (
                  <TableHead key={col.key}>
                    {col.sortable !== false && col.sortValue ? (
                      <button
                        type="button"
                        className="inline-flex items-center gap-1 hover:text-primary"
                        onClick={() => toggleSort(col.key)}
                      >
                        {col.header}
                        {sortKey === col.key ? (
                          sortDir === 'asc' ? (
                            <ChevronUp className="h-3 w-3" />
                          ) : (
                            <ChevronDown className="h-3 w-3" />
                          )
                        ) : (
                          <ChevronDown className="h-3 w-3 opacity-30" />
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
                    className={cn(onRowClick && 'cursor-pointer')}
                    onClick={() => onRowClick?.(row)}
                  >
                    {enableBulkSelect && (
                      <TableCell onClick={(e) => e.stopPropagation()}>
                        <input
                          type="checkbox"
                          checked={selected.has(rowId)}
                          onChange={() => toggleSelect(rowId)}
                          className="rounded border-border accent-accent"
                        />
                      </TableCell>
                    )}
                    {columns.map((col) => (
                      <TableCell key={col.key}>{col.render(row)}</TableCell>
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
  );
}
