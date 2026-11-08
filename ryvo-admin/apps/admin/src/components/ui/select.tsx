'use client';

import * as React from 'react';
import { ChevronDown } from 'lucide-react';
import { cn } from '@/lib/utils';

interface SelectProps extends React.SelectHTMLAttributes<HTMLSelectElement> {
  error?: string;
  leading?: React.ReactNode;
}

export const Select = React.forwardRef<HTMLSelectElement, SelectProps>(
  ({ className, children, error, leading, ...props }, ref) => (
    <div className="w-full">
      <div className="relative">
        {leading ? (
          <span className="pointer-events-none absolute left-3 top-1/2 -translate-y-1/2 text-muted [&_svg]:size-4">
            {leading}
          </span>
        ) : null}
        <select
          ref={ref}
          className={cn(
            'flex h-9 w-full appearance-none rounded-md border border-transparent bg-input px-3 pr-8 text-sm text-primary transition-colors duration-150 hover:border-hairline disabled:cursor-not-allowed disabled:opacity-40',
            leading && 'pl-9',
            error && 'border-danger',
            className,
          )}
          aria-invalid={error ? true : undefined}
          {...props}
        >
          {children}
        </select>
        <ChevronDown
          className="pointer-events-none absolute right-2.5 top-1/2 size-4 -translate-y-1/2 text-muted"
          strokeWidth={1.75}
        />
      </div>
      {error ? <p className="mt-1 text-xs text-danger">{error}</p> : null}
    </div>
  ),
);
Select.displayName = 'Select';
