import { Inbox } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { cn } from '@/lib/utils';

interface EmptyStateProps {
  title?: string;
  description?: string;
  actionLabel?: string;
  onAction?: () => void;
  className?: string;
}

export function EmptyState({
  title = 'No data found',
  description = 'There are no records to display yet.',
  actionLabel,
  onAction,
  className,
}: EmptyStateProps) {
  return (
    <div className={cn('flex flex-col items-center justify-center px-6 py-16 text-center', className)}>
      <div className="mb-4 grid size-12 place-items-center rounded-full bg-input text-muted">
        <Inbox className="size-5" strokeWidth={1.75} />
      </div>
      <h3 className="text-base font-semibold text-primary">{title}</h3>
      <p className="mt-1 max-w-sm text-sm text-muted">{description}</p>
      {actionLabel && onAction ? (
        <Button onClick={onAction} size="sm" className="mt-4">
          {actionLabel}
        </Button>
      ) : null}
    </div>
  );
}
