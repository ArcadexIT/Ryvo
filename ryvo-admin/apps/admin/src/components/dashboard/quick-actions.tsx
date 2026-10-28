'use client';

import Link from 'next/link';
import { Ticket, Image, FileCheck, Banknote } from 'lucide-react';
import { cn } from '@/lib/utils';

const ACTIONS = [
  { label: 'Add Promo', href: '/pricing/promos', icon: Ticket, color: 'text-accent' },
  { label: 'Create Banner', href: '/cms/banners', icon: Image, color: 'text-info' },
  { label: 'Open verification', href: '/providers/kyc', icon: FileCheck, color: 'text-warning' },
  { label: 'Process Payouts', href: '/finance/payouts', icon: Banknote, color: 'text-success' },
];

export function QuickActions() {
  return (
    <div className="flex flex-wrap gap-2">
      {ACTIONS.map((action) => {
        const Icon = action.icon;
        return (
          <Link
            key={action.href}
            href={action.href}
            className="inline-flex items-center gap-2 border border-border bg-base px-3 py-2 text-sm font-medium text-primary transition-colors hover:bg-surface"
          >
            <Icon className={cn('h-4 w-4', action.color)} />
            {action.label}
          </Link>
        );
      })}
    </div>
  );
}
