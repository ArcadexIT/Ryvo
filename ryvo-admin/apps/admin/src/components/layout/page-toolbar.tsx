import { cn } from '@/lib/utils';

interface PageToolbarProps {
  children?: React.ReactNode;
  className?: string;
}

export function PageToolbar({ children, className }: PageToolbarProps) {
  if (!children) return null;
  return (
    <div className={cn('mb-4 flex flex-wrap items-center justify-between gap-3', className)}>
      {children}
    </div>
  );
}

export function PageToolbarActions({ children, className }: PageToolbarProps) {
  return <div className={cn('flex flex-wrap items-center gap-2', className)}>{children}</div>;
}
