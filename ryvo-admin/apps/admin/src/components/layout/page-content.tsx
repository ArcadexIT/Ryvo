import { cn } from '@/lib/utils';

export function PageContent({
  children,
  className,
}: {
  children: React.ReactNode;
  className?: string;
}) {
  return (
    <div className={cn('flex-1 overflow-y-auto px-5 py-4 lg:px-6', className)}>{children}</div>
  );
}
