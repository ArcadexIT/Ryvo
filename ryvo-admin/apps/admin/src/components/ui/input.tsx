import * as React from 'react';
import { CheckCircle } from 'lucide-react';
import { cn } from '@/lib/utils';

export interface InputProps extends React.InputHTMLAttributes<HTMLInputElement> {
  error?: string;
  success?: boolean;
}

export const Input = React.forwardRef<HTMLInputElement, InputProps>(
  ({ className, type, error, success, ...props }, ref) => (
    <div className="w-full">
      <div className="relative">
        <input
          type={type}
          className={cn(
            'flex h-10 w-full rounded-md border bg-elevated px-3 py-2 text-sm text-primary placeholder:text-muted transition-colors duration-150',
            'focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-accent focus-visible:ring-offset-1 focus-visible:ring-offset-base',
            'disabled:cursor-not-allowed disabled:opacity-40',
            error ? 'border-danger focus-visible:ring-danger' : 'border-border',
            success && !error && 'border-success pr-10',
            className,
          )}
          ref={ref}
          {...props}
        />
        {success && !error && (
          <CheckCircle className="absolute right-3 top-1/2 h-4 w-4 -translate-y-1/2 text-success" />
        )}
      </div>
      {error && <p className="mt-1 text-xs text-danger">{error}</p>}
    </div>
  ),
);
Input.displayName = 'Input';
