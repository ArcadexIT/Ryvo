import { cn } from '@/lib/utils';
import { landingSection } from './paths';
import { STORE_LINKS } from './store-links';

type Store = 'appStore' | 'playStore';
type Audience = 'customer' | 'provider';

function AppleLogo({ className }: { className?: string }) {
  return (
    <svg className={className} viewBox="0 0 24 24" fill="currentColor" aria-hidden>
      <path d="M18.71 19.5c-.83 1.24-1.71 2.45-3.05 2.47-1.34.03-1.77-.79-3.29-.79-1.53 0-2 .77-3.27.82-1.31.05-2.3-1.32-3.14-2.53C4.25 17 2.94 12.45 4.7 9.39c.87-1.52 2.43-2.48 4.12-2.51 1.28-.02 2.5.87 3.29.87.78 0 2.26-1.07 3.8-.91.65.03 2.47.26 3.64 1.98-.09.06-2.17 1.28-2.15 3.81.03 3.02 2.65 4.03 2.68 4.04-.03.07-.42 1.44-1.37 2.83M13 3.5c.73-.83 1.94-1.46 2.94-1.5.13 1.17-.34 2.35-1.04 3.19-.69.85-1.83 1.51-2.95 1.42-.15-1.15.41-2.35 1.05-3.11z" />
    </svg>
  );
}

function PlayLogo({ className }: { className?: string }) {
  return (
    <svg className={className} viewBox="0 0 24 24" aria-hidden>
      <path fill="#EA4335" d="M3.6 2.8c-.2.2-.3.5-.3.9v16.6c0 .4.1.7.3.9l.1.1 9.4-9.4v-.2L3.7 2.7l-.1.1z" />
      <path fill="#FBBC04" d="M16.5 15.4l-3.3-3.3v-.2l3.3-3.3.1.1 3.9 2.2c1.1.6 1.1 1.7 0 2.4l-3.9 2.2-.1-.1z" />
      <path fill="#4285F4" d="M16.6 15.3l-3.4-3.4-9.4 9.4c.4.4 1 .4 1.7.1l11.1-6.1z" />
      <path fill="#34A853" d="M16.6 8.7L5.5 2.6c-.7-.4-1.3-.3-1.7.1l9.4 9.4 3.4-3.4z" />
    </svg>
  );
}

type StoreBadgeProps = {
  store: Store;
  href?: string;
  className?: string;
  /** Use on dark backgrounds (e.g. footer). */
  tone?: 'dark' | 'light';
};

export function StoreBadge({
  store,
  href = landingSection('download'),
  className,
  tone = 'dark',
}: StoreBadgeProps) {
  const isApple = store === 'appStore';
  const isLight = tone === 'light';
  const isExternal = href.startsWith('http');

  return (
    <a
      href={href}
      {...(isExternal ? { target: '_blank', rel: 'noopener noreferrer' } : {})}
      className={cn(
        'inline-flex h-auto min-h-12 shrink-0 items-center gap-2.5 rounded-full px-4 py-2.5 transition-transform duration-200 hover:scale-[1.03] focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-[var(--landing-orange)]',
        // !important so header/footer nav link color rules cannot wash out badge text/icons
        isLight
          ? '!bg-white !text-[#0b1b33] hover:!bg-white/90'
          : '!bg-[#0b1b33] !text-white hover:!bg-[#1a2d4a]',
        className,
      )}
      aria-label={isApple ? 'Download on the App Store' : 'Get it on Google Play'}
    >
      {isApple ? (
        <AppleLogo className="h-7 w-7 shrink-0" />
      ) : (
        <PlayLogo className="h-6 w-6 shrink-0" />
      )}
      <span className="flex min-w-0 flex-col items-start justify-center leading-tight">
        <span
          className={cn(
            'text-[10px] font-medium tracking-wide',
            isLight ? '!text-[#0b1b33]/70' : '!text-white/80',
          )}
        >
          {isApple ? 'Download on the' : 'GET IT ON'}
        </span>
        <span
          className={cn(
            'mt-0.5 whitespace-nowrap text-sm font-semibold tracking-tight',
            isLight ? '!text-[#0b1b33]' : '!text-white',
          )}
        >
          {isApple ? 'App Store' : 'Google Play'}
        </span>
      </span>
    </a>
  );
}

type StoreBadgeRowProps = {
  audience?: Audience;
  className?: string;
  tone?: 'dark' | 'light';
};

export function StoreBadgeRow({
  audience = 'customer',
  className,
  tone = 'dark',
}: StoreBadgeRowProps) {
  const links = STORE_LINKS[audience];

  return (
    <div className={cn('flex flex-wrap gap-3', className)}>
      <StoreBadge store="appStore" href={links.appStore} tone={tone} />
      <StoreBadge store="playStore" href={links.playStore} tone={tone} />
    </div>
  );
}

type DualAudienceStoreBadgesProps = {
  className?: string;
  tone?: 'dark' | 'light';
};

export function DualAudienceStoreBadges({ className, tone = 'dark' }: DualAudienceStoreBadgesProps) {
  const onDark = tone === 'light';

  return (
    <div className={cn('flex flex-col gap-5', className)}>
      <div>
        <p className={cn('mb-2.5 text-sm font-semibold tracking-wide', onDark ? 'text-[#fbf8f4]/80' : 'landing-text-navy')}>
          Customer app
        </p>
        <StoreBadgeRow audience="customer" tone={tone} />
      </div>
      <div>
        <p className={cn('mb-2.5 text-sm font-semibold tracking-wide', onDark ? 'text-[#fbf8f4]/80' : 'landing-text-navy')}>
          Driver app
        </p>
        <StoreBadgeRow audience="provider" tone={tone} />
      </div>
    </div>
  );
}
