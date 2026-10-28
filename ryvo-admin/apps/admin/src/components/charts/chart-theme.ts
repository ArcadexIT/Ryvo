'use client';

import { useTheme } from '@/hooks/use-theme';

export function useChartTheme() {
  const { theme } = useTheme();

  return {
    grid: 'var(--border)',
    text: 'var(--text-muted)',
    tooltipBg: 'var(--bg-elevated)',
    tooltipBorder: 'var(--border)',
    tooltipText: 'var(--text-primary)',
    accent: 'var(--accent)',
    success: 'var(--success)',
    danger: 'var(--danger)',
    info: 'var(--info)',
    warning: 'var(--warning)',
    isDark: theme === 'dark',
  };
}

export const STATUS_COLORS: Record<string, string> = {
  pending: 'var(--info)',
  active: 'var(--accent)',
  in_progress: 'var(--accent)',
  completed: 'var(--success)',
  cancelled: 'var(--danger)',
  rejected: 'var(--danger)',
};

export function getStatusColor(status: string): string {
  return STATUS_COLORS[status.toLowerCase()] ?? 'var(--text-muted)';
}
