'use client';

import { Download } from 'lucide-react';
import { Button } from '@/components/ui/button';

interface ExportButtonProps<T extends Record<string, unknown>> {
  data: T[];
  filename: string;
  columns: { key: keyof T; header: string }[];
  disabled?: boolean;
}

export function ExportButton<T extends Record<string, unknown>>({
  data,
  filename,
  columns,
  disabled,
}: ExportButtonProps<T>) {
  function handleExport() {
    const headers = columns.map((c) => c.header).join(',');
    const rows = data.map((row) =>
      columns
        .map((c) => {
          const val = row[c.key];
          const str = val == null ? '' : String(val);
          return str.includes(',') ? `"${str.replace(/"/g, '""')}"` : str;
        })
        .join(','),
    );
    const csv = [headers, ...rows].join('\n');
    const blob = new Blob([csv], { type: 'text/csv;charset=utf-8;' });
    const url = URL.createObjectURL(blob);
    const link = document.createElement('a');
    link.href = url;
    link.download = `${filename}.csv`;
    link.click();
    URL.revokeObjectURL(url);
  }

  return (
    <Button variant="outline" size="sm" onClick={handleExport} disabled={disabled || data.length === 0}>
      <Download className="h-4 w-4" />
      Export CSV
    </Button>
  );
}
