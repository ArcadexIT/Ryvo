'use client';

import { CreditCard, Crosshair, MessageCircle, Navigation, ShieldCheck } from 'lucide-react';
import { Reveal } from './reveal';

const ITEMS = [
  { icon: CreditCard, label: 'Secure In-App Payments' },
  { icon: Crosshair, label: 'Instant Matching' },
  { icon: MessageCircle, label: 'In-App Chat & Call' },
  { icon: Navigation, label: 'Live Tracking, Instantly Matched' },
  { icon: ShieldCheck, label: 'Verified drivers' },
];

export function LandingWhy() {
  return (
    <section className="landing-section bg-[var(--landing-grey-blue)]">
      <div className="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8">
        <div className="grid gap-8 sm:grid-cols-2 lg:grid-cols-5 lg:gap-6">
          {ITEMS.map((item, i) => {
            const Icon = item.icon;
            return (
              <Reveal key={item.label} delay={((i % 4) + 1) as 1 | 2 | 3 | 4}>
                <article className="flex flex-col items-center text-center">
                  <span className="flex h-12 w-12 items-center justify-center rounded-full bg-[var(--landing-peach)] text-[var(--landing-orange)]">
                    <Icon className="h-5 w-5" strokeWidth={1.75} />
                  </span>
                  <p className="landing-text-navy mt-3 text-sm font-bold leading-snug">{item.label}</p>
                </article>
              </Reveal>
            );
          })}
        </div>
      </div>
    </section>
  );
}
