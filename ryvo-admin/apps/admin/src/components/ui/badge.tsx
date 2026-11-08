import * as React from 'react';
import { cva, type VariantProps } from 'class-variance-authority';
import { cn } from '@/lib/utils';

const badgeVariants = cva(
  'inline-flex items-center gap-1.5 rounded-full px-2 py-0.5 text-xs font-medium',
  {
    variants: {
      variant: {
        default: 'bg-success/10 text-success',
        secondary: 'bg-input text-muted',
        success: 'bg-success/10 text-success',
        warning: 'bg-warning/10 text-warning',
        destructive: 'bg-danger/10 text-danger',
        info: 'bg-info/10 text-info',
        outline: 'border border-hairline text-secondary',
      },
    },
    defaultVariants: {
      variant: 'default',
    },
  },
);

export interface BadgeProps
  extends React.HTMLAttributes<HTMLDivElement>,
    VariantProps<typeof badgeVariants> {
  dot?: boolean;
  live?: boolean;
}

export function Badge({ className, variant, dot, live, children, ...props }: BadgeProps) {
  return (
    <div className={cn(badgeVariants({ variant }), className)} {...props}>
      {dot ? (
        <span
          className={cn('size-1.5 shrink-0 rounded-full bg-current', live && 'live-dot')}
          aria-hidden
        />
      ) : null}
      {children}
    </div>
  );
}

const SUCCESS = ['active', 'completed', 'paid', 'approved', 'online', 'resolved', 'closed', 'live'];
const WARNING = ['pending', 'open', 'in_progress', 'searching', 'matched', 'review', 'processing'];
const DANGER = ['suspended', 'cancelled', 'canceled', 'rejected', 'failed'];
const MUTED = ['inactive', 'offline', 'disabled'];
const LIVE = ['live', 'online', 'searching', 'in_progress'];

export function statusBadgeVariant(status: string | null | undefined): BadgeProps['variant'] {
  if (!status) return 'secondary';
  const s = status.toLowerCase();
  if (SUCCESS.includes(s)) return 'success';
  if (WARNING.includes(s)) return 'warning';
  if (DANGER.includes(s)) return 'destructive';
  if (MUTED.includes(s)) return 'secondary';
  return 'info';
}

interface StatusBadgeProps {
  status: string | null | undefined;
  className?: string;
}

export function StatusBadge({ status, className }: StatusBadgeProps) {
  const key = status?.toLowerCase() ?? '';
  return (
    <Badge variant={statusBadgeVariant(status)} dot live={LIVE.includes(key)} className={className}>
      <span className="capitalize">{status ? status.replace(/_/g, ' ') : 'Unknown'}</span>
    </Badge>
  );
}
