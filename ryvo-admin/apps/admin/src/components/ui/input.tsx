import * as React from 'react';
import { CheckCircle } from 'lucide-react';
import { cn } from '@/lib/utils';

const fieldClass =
  'flex w-full rounded-md border border-transparent bg-input px-3 text-sm text-primary placeholder:text-muted transition-colors duration-150 hover:border-hairline disabled:cursor-not-allowed disabled:opacity-40';

export interface InputProps extends React.InputHTMLAttributes<HTMLInputElement> {
  error?: string;
  success?: boolean;
  leading?: React.ReactNode;
  trailing?: React.ReactNode;
}

export const Input = React.forwardRef<HTMLInputElement, InputProps>(
  ({ className, type, error, success, leading, trailing, ...props }, ref) => (
    <div className="w-full">
      <div className="relative">
        {leading ? (
          <span className="pointer-events-none absolute left-3 top-1/2 -translate-y-1/2 text-muted [&_svg]:size-4">
            {leading}
          </span>
        ) : null}
        <input
          type={type}
          className={cn(
            fieldClass,
            'h-9',
            leading && 'pl-9',
            (trailing || success) && 'pr-9',
            error && 'border-danger',
            className,
          )}
          ref={ref}
          aria-invalid={error ? true : undefined}
          {...props}
        />
        {trailing ? (
          <span className="absolute right-3 top-1/2 -translate-y-1/2 text-muted [&_svg]:size-4">{trailing}</span>
        ) : null}
        {success && !error && !trailing ? (
          <CheckCircle className="absolute right-3 top-1/2 size-4 -translate-y-1/2 text-success" strokeWidth={1.75} />
        ) : null}
      </div>
      {error ? <p className="mt-1 text-xs text-danger">{error}</p> : null}
    </div>
  ),
);
Input.displayName = 'Input';
