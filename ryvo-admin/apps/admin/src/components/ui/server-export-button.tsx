'use client';

import { Download } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { apiMutate } from '@/lib/api';

interface ServerExportButtonProps {
  type: 'payments' | 'earnings' | 'payouts';
  disabled?: boolean;
}

export function ServerExportButton({ type, disabled }: ServerExportButtonProps) {
  async function handleExport() {
    const res = await apiMutate<{ filename: string; content: string }>(
      '/admin/finance/export',
      'POST',
      { type },
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
