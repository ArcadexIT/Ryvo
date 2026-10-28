import * as React from 'react';
import { cva, type VariantProps } from 'class-variance-authority';
import {
  CheckCircle2,
  Clock,
  XCircle,
  Ban,
  Loader2,
  AlertTriangle,
  HelpCircle,
  type LucideIcon,
} from 'lucide-react';
import { cn } from '@/lib/utils';

const badgeVariants = cva(
  'inline-flex items-center gap-1 rounded-full border px-2.5 py-0.5 text-xs font-medium',
  {
    variants: {
      variant: {
        default: 'border-accent/20 bg-accent-soft text-accent',
        secondary: 'border-border bg-surface text-secondary',
        success: 'border-success/20 bg-success/15 text-success',
        warning: 'border-warning/20 bg-warning/15 text-warning',
        destructive: 'border-danger/20 bg-danger/15 text-danger',
        info: 'border-info/20 bg-info/15 text-info',
        outline: 'border-border text-secondary',
      },
    },
    defaultVariants: {
      variant: 'default',
    },
  },
);

export interface BadgeProps
  extends React.HTMLAttributes<HTMLDivElement>,
    VariantProps<typeof badgeVariants> {}

export function Badge({ className, variant, ...props }: BadgeProps) {
  return <div className={cn(badgeVariants({ variant }), className)} {...props} />;
}

export function statusBadgeVariant(status: string | null | undefined): BadgeProps['variant'] {
  if (!status) return 'secondary';
  const s = status.toLowerCase();
  if (['active', 'completed', 'paid', 'approved', 'online', 'resolved', 'closed'].includes(s)) {
    return 'success';
  }
  if (['pending', 'open', 'in_progress', 'searching', 'matched'].includes(s)) {
    return 'warning';
  }
  if (['suspended', 'cancelled', 'rejected', 'failed', 'offline'].includes(s)) {
    return 'destructive';
  }
  return 'info';
}

const STATUS_ICONS: Record<string, LucideIcon> = {
  active: CheckCircle2,
  completed: CheckCircle2,
  paid: CheckCircle2,
  approved: CheckCircle2,
  online: CheckCircle2,
  resolved: CheckCircle2,
  closed: CheckCircle2,
  pending: Clock,
  open: Clock,
  in_progress: Loader2,
  searching: Loader2,
  matched: Loader2,
  suspended: Ban,
  offline: Ban,
  cancelled: XCircle,
  rejected: XCircle,
  failed: XCircle,
  refunded: AlertTriangle,
};

export function statusIcon(status: string | null | undefined): LucideIcon {
  if (!status) return HelpCircle;
  return STATUS_ICONS[status.toLowerCase()] ?? HelpCircle;
}

interface StatusBadgeProps {
  status: string | null | undefined;
  className?: string;
}

/** Standard icon + label + tinted-background status pill used across all data tables. */
export function StatusBadge({ status, className }: StatusBadgeProps) {
  const Icon = statusIcon(status);
  const spinning = status?.toLowerCase() === 'in_progress' || status?.toLowerCase() === 'searching';

  return (
    <Badge variant={statusBadgeVariant(status)} className={className}>
      <Icon className={cn('h-3 w-3', spinning && 'animate-spin')} />
      <span className="capitalize">{status ? status.replace(/_/g, ' ') : 'Unknown'}</span>
    </Badge>
  );
}
