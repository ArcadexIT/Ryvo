'use client';

import * as React from 'react';
import { toast as sonnerToast } from 'sonner';
import { cn } from '@/lib/utils';
import { CheckCircle, AlertCircle, AlertTriangle, Info } from 'lucide-react';

interface ToastProps {
  message: string;
  type?: 'success' | 'error' | 'warning' | 'info';
  className?: string;
}

/** @deprecated Use sonner toast directly via useToast hook */
export function Toast({ message, type = 'success', className }: ToastProps) {
  if (!message) return null;
  const icons = {
    success: CheckCircle,
    error: AlertCircle,
    warning: AlertTriangle,
    info: Info,
  };
  const Icon = icons[type];

  return (
    <div
      className={cn(
        'fixed bottom-6 right-6 z-50 flex items-center gap-2 rounded-md border px-4 py-3 text-sm shadow-md bg-elevated',
        type === 'success' && 'border-success/30 text-success',
        type === 'error' && 'border-danger/30 text-danger',
        type === 'warning' && 'border-warning/30 text-warning',
        type === 'info' && 'border-info/30 text-info',
        className,
      )}
    >
      <Icon className="h-4 w-4" />
      {message}
    </div>
  );
}

export function useToast() {
  const [toast, setToast] = React.useState<{
    message: string;
    type: 'success' | 'error' | 'warning' | 'info';
  } | null>(null);

  const show = React.useCallback(
    (message: string, type: 'success' | 'error' | 'warning' | 'info' = 'success') => {
      setToast({ message, type });
      sonnerToast[type](message);
      setTimeout(() => setToast(null), 4000);
    },
    [],
  );

  return { toast, show };
}
