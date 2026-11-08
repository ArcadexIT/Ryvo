'use client';

import * as DialogPrimitive from '@radix-ui/react-dialog';
import { X } from 'lucide-react';
import { cn } from '@/lib/utils';
import { Button } from './button';

interface DrawerProps {
  open: boolean;
  onClose: () => void;
  title: string;
  children: React.ReactNode;
  className?: string;
  side?: 'left' | 'right';
  hideHeader?: boolean;
}

export function Drawer({ open, onClose, title, children, className, side = 'right', hideHeader }: DrawerProps) {
  const left = side === 'left';
  return (
    <DialogPrimitive.Root open={open} onOpenChange={(v) => !v && onClose()}>
      <DialogPrimitive.Portal>
        <DialogPrimitive.Overlay className="animate-overlay-in fixed inset-0 z-50 bg-black/40" />
        <DialogPrimitive.Content
          className={cn(
            'fixed inset-y-0 z-50 flex h-full w-full max-w-md flex-col bg-sheet',
            left ? 'animate-sheet-in-left left-0 border-r border-hairline' : 'animate-sheet-in right-0 border-l border-hairline',
            className,
          )}
        >
          {hideHeader ? (
            <DialogPrimitive.Title className="sr-only">{title}</DialogPrimitive.Title>
          ) : (
            <div className="flex h-14 items-center justify-between border-b border-hairline px-5">
              <DialogPrimitive.Title className="text-base font-semibold text-primary">{title}</DialogPrimitive.Title>
              <DialogPrimitive.Close asChild>
                <Button variant="ghost" size="icon" aria-label="Close">
                  <X strokeWidth={1.75} />
                </Button>
              </DialogPrimitive.Close>
            </div>
          )}
          <div className={cn('flex min-h-0 flex-1 flex-col', hideHeader ? '' : 'overflow-y-auto p-5')}>{children}</div>
        </DialogPrimitive.Content>
      </DialogPrimitive.Portal>
    </DialogPrimitive.Root>
  );
}
