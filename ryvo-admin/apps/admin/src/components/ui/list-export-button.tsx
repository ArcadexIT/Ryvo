'use client';

import { Download } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { apiMutate } from '@/lib/api';

interface ListExportButtonProps {
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
  disabled?: boolean;
}

export function ListExportButton({ type, params, disabled }: ListExportButtonProps) {
  async function handleExport() {
    const res = await apiMutate<{ filename: string; content: string }>(
      '/admin/export/list',
      'POST',
      { type, ...params },
    );
    if (!res.data?.content) return;
    const blob = new Blob([res.data.content], { type: 'text/csv;charset=utf-8;' });
    const url = URL.createObjectURL(blob);
    const link = document.createElement('a');
    link.href = url;
    link.download = res.data.filename;
    link.click();
    URL.revokeObjectURL(url);
  }

  return (
    <Button variant="outline" size="sm" onClick={() => void handleExport()} disabled={disabled}>
      <Download className="h-4 w-4" />
      Export CSV
    </Button>
  );
}
