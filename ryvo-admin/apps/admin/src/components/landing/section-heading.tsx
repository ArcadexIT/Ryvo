import type { ReactNode } from 'react';
import { cn } from '@/lib/utils';

export function LandingBadge({ children, className }: { children: ReactNode; className?: string }) {
  return <span className={cn('landing-eyebrow', className)}>{children}</span>;
}

export function SectionHeading({
  eyebrow,
  title,
  className,
  align = 'center',
  tone = 'light',
}: {
  eyebrow?: string;
  title: string;
  className?: string;
  align?: 'center' | 'left';
  tone?: 'light' | 'dark';
}) {
  return (
    <div className={cn(align === 'center' ? 'mx-auto max-w-3xl text-center' : 'max-w-3xl text-left', className)}>
      {eyebrow ? (
        <LandingBadge className={cn(align === 'center' && 'justify-center before:hidden sm:before:block')}>
          {eyebrow}
        </LandingBadge>
      ) : null}
      <h2
        className={cn(
          'text-[2rem] leading-[1.12] sm:text-4xl lg:text-[2.75rem]',
          tone === 'dark' ? 'landing-text-white' : 'landing-text-navy',
          eyebrow && 'mt-4',
        )}
      >
        {title}
      </h2>
    </div>
  );
}
