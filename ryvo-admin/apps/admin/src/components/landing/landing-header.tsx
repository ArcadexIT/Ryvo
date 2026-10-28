'use client';

import { useEffect, useState } from 'react';
import Image from 'next/image';
import { Menu, X } from 'lucide-react';
import { cn } from '@/lib/utils';
import { StoreBadgeRow } from './store-badges';
import { LANDING_HOME, landingSection } from './paths';

const NAV_LINKS = [
  { label: 'Ride types', href: landingSection('services') },
  { label: 'How it works', href: landingSection('how-it-works') },
  { label: 'Coverage', href: landingSection('roadmap') },
  { label: 'Download', href: landingSection('download') },
];

export function LandingHeader({ variant: _variant = 'default' }: { variant?: 'default' | 'overlay' }) {
  const [open, setOpen] = useState(false);
  const [scrolled, setScrolled] = useState(false);

  useEffect(() => {
    function onScroll() {
      setScrolled(window.scrollY > 8);
    }
    onScroll();
    window.addEventListener('scroll', onScroll, { passive: true });
    return () => window.removeEventListener('scroll', onScroll);
  }, []);

  function closeMenu() {
    setOpen(false);
  }

  return (
    <header className="fixed left-1/2 top-3 z-50 w-[min(72rem,calc(100%-1.25rem))] -translate-x-1/2">
      <div
        className={cn(
          'flex h-14 items-center justify-between gap-3 rounded-full border border-black/5 bg-white/90 px-2.5 shadow-[0_16px_40px_-24px_rgba(10,20,36,0.45)] backdrop-blur-xl sm:px-3',
          scrolled && 'bg-white',
        )}
      >
        <a href={LANDING_HOME} className="shrink-0 pl-2" onClick={closeMenu} aria-label="RYVO">
          <Image
            src="/logo-wordmark.png"
            alt="RYVO"
            width={1415}
            height={360}
            priority
            className="h-6 w-auto sm:h-7"
          />
        </a>

        <nav className="hidden items-center gap-1 lg:flex">
          {NAV_LINKS.map((link) => (
            <a
              key={link.href}
              href={link.href}
              className="rounded-full px-3 py-2 text-[13px] font-medium text-[var(--landing-navy)] transition-colors hover:bg-[var(--landing-peach)] hover:text-[var(--landing-orange)]"
            >
              {link.label}
            </a>
          ))}
        </nav>

        <div className="flex items-center gap-2">
          <a
            href={landingSection('download')}
            className="hidden rounded-full bg-[var(--landing-orange)] px-4 py-2 text-[13px] font-semibold text-white transition-colors hover:bg-[var(--landing-orange-hover)] sm:inline-flex"
          >
            Get the app
          </a>
          <button
            type="button"
            className="inline-flex h-10 w-10 items-center justify-center rounded-full text-[var(--landing-navy)] hover:bg-black/5 lg:hidden"
            aria-label={open ? 'Close menu' : 'Open menu'}
            onClick={() => setOpen((prev) => !prev)}
          >
            {open ? <X className="h-5 w-5" /> : <Menu className="h-5 w-5" />}
          </button>
        </div>
      </div>

      <div
        className={cn(
          'mt-2 overflow-hidden rounded-[24px] border border-black/5 bg-white shadow-lg transition-[max-height,opacity] duration-300 lg:hidden',
          open ? 'max-h-96 opacity-100' : 'max-h-0 border-transparent opacity-0 shadow-none',
        )}
      >
        <nav className="flex flex-col gap-1 p-3">
          {NAV_LINKS.map((link) => (
            <a
              key={link.href}
              href={link.href}
              className="rounded-2xl px-3 py-3 text-base font-medium text-[var(--landing-navy)] hover:bg-[var(--landing-peach)]"
              onClick={closeMenu}
            >
              {link.label}
            </a>
          ))}
          <div className="px-1 pt-2" onClick={closeMenu}>
            <StoreBadgeRow className="flex-col sm:flex-row [&>a]:w-full sm:[&>a]:w-auto" tone="dark" />
          </div>
        </nav>
      </div>
    </header>
  );
}
