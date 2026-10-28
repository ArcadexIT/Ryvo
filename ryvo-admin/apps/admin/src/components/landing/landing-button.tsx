import { cn } from '@/lib/utils';

type LandingButtonProps = React.AnchorHTMLAttributes<HTMLAnchorElement> & {
  variant?: 'orange' | 'navy' | 'outline' | 'ghost' | 'ghost-light';
  size?: 'md' | 'lg';
};

export function LandingButton({
  className,
  variant = 'orange',
  size = 'md',
  children,
  ...props
}: LandingButtonProps) {
  return (
    <a
      className={cn(
        'inline-flex items-center justify-center gap-2 rounded-full font-semibold tracking-tight transition-all duration-300',
        size === 'lg' ? 'h-12 px-7 text-[0.95rem] sm:h-[3.25rem] sm:px-8' : 'h-11 px-6 text-sm',
        variant === 'orange' &&
          'bg-[var(--landing-orange)] text-white shadow-[0_10px_24px_-12px_rgba(255,85,0,0.65)] hover:bg-[var(--landing-orange-hover)]',
        variant === 'navy' &&
          'bg-[var(--landing-navy)] text-[#fbf8f4] shadow-[0_10px_24px_-12px_rgba(10,20,36,0.45)] hover:bg-[var(--landing-navy-light)]',
        variant === 'outline' &&
          'landing-text-navy border border-[var(--landing-border)] bg-[var(--landing-paper)] hover:border-[var(--landing-navy)]/30',
        variant === 'ghost' &&
          'landing-text-navy border border-[var(--landing-navy)]/15 bg-transparent hover:border-[var(--landing-navy)]/40 hover:bg-[var(--landing-paper)]/70',
        variant === 'ghost-light' &&
          'border border-white/25 bg-white/[0.08] text-[#fbf8f4] backdrop-blur-md hover:bg-white/15',
        className,
      )}
      {...props}
    >
      {children}
    </a>
  );
}
