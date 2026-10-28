'use client';

import { cn } from '@/lib/utils';
import { useFileAccessUrl } from '@/hooks/use-file-access-url';
import { getInitials } from '@/components/ui/avatar';

interface SecureAvatarProps {
  name: string;
  src?: string | null;
  size?: 'sm' | 'md' | 'lg';
  className?: string;
}

const sizeClasses = {
  sm: 'h-7 w-7 text-xs',
  md: 'h-9 w-9 text-sm',
  lg: 'h-11 w-11 text-base',
};

export function SecureAvatar({ name, src, size = 'md', className }: SecureAvatarProps) {
  const needsPresign = Boolean(src && (src.startsWith('http://') || src.startsWith('https://')));
  const { data: accessUrl, isLoading } = useFileAccessUrl(needsPresign ? src : null);
  const resolvedSrc = needsPresign ? accessUrl : src;

  if (resolvedSrc && !isLoading) {
    return (
      <img
        src={resolvedSrc}
        alt={name}
        className={cn('rounded-full object-cover', sizeClasses[size], className)}
      />
    );
  }

  if (isLoading && needsPresign) {
    return (
      <div
        className={cn(
          'animate-pulse rounded-full bg-surface',
          sizeClasses[size],
          className,
        )}
        aria-hidden
      />
    );
  }

  return (
    <div
      className={cn(
        'flex items-center justify-center rounded-full bg-accent-soft font-semibold text-accent',
        sizeClasses[size],
        className,
      )}
      aria-hidden
    >
      {getInitials(name)}
    </div>
  );
}
