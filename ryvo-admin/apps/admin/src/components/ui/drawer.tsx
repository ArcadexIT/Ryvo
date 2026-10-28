'use client';

import { X } from 'lucide-react';
import { cn } from '@/lib/utils';
import { Button } from './button';

interface DrawerProps {
  open: boolean;
  onClose: () => void;
  title: string;
  children: React.ReactNode;
  className?: string;
}

export function Drawer({ open, onClose, title, children, className }: DrawerProps) {
  if (!open) return null;

  return (
    <div className="fixed inset-0 z-50 flex justify-end">
      <div
        className="absolute inset-0 bg-black/50 backdrop-blur-sm animate-in fade-in-0 duration-200"
        onClick={onClose}
      />
      <div
        className={cn(
          'relative z-10 flex h-full w-full max-w-md flex-col border-l border-border bg-elevated shadow-xl animate-in slide-in-from-right duration-300',
          className,
        )}
      >
        <div className="flex h-topbar items-center justify-between border-b border-border px-6">
          <h2 className="text-lg font-semibold text-primary">{title}</h2>
          <Button variant="ghost" size="icon" onClick={onClose}>
            <X className="h-4 w-4" />
          </Button>
        </div>
        <div className="flex-1 overflow-y-auto p-6">{children}</div>
      </div>
    </div>
  );
}
