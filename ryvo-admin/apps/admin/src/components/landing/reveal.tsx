'use client';

import type { ReactNode } from 'react';
import { cn } from '@/lib/utils';
import { useReveal } from './use-reveal';

type RevealProps = {
  children: ReactNode;
  className?: string;
  delay?: 1 | 2 | 3 | 4;
  variant?: 'up' | 'fade';
};

export function Reveal({ children, className, delay, variant = 'up' }: RevealProps) {
  const ref = useReveal<HTMLDivElement>();

  return (
    <div
      ref={ref}
      className={cn(
        variant === 'up' ? 'landing-reveal' : 'landing-fade',
        delay === 1 && 'landing-reveal-delay-1',
        delay === 2 && 'landing-reveal-delay-2',
        delay === 3 && 'landing-reveal-delay-3',
        delay === 4 && 'landing-reveal-delay-4',
        className,
      )}
    >
      {children}
    </div>
  );
}
