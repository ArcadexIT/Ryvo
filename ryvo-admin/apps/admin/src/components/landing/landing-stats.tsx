'use client';

import { Clock, CreditCard, MapPin, ShieldCheck } from 'lucide-react';
import { Reveal } from './reveal';

const STATS = [
  {
    icon: Clock,
    label: 'Minutes to a driver',
    value: '~8',
    unit: 'min',
    detail: 'Typical time from request to a nearby driver',
  },
  {
    icon: ShieldCheck,
    label: 'Verified drivers',
    value: 'Vetted',
    detail: 'Licence, insurance, and vehicle checked',
  },
  {
    icon: CreditCard,
    label: 'Secure payments',
    value: 'In-app',
    detail: 'Estimate first. Charged when the trip ends',
  },
  {
    icon: MapPin,
    label: 'Coverage plan',
    value: 'Live areas',
    detail: 'The app shows where rides are open',
  },
] as const;

export function LandingStats() {
  return (
    <section className="relative z-10 bg-[var(--landing-cream)] px-4 pt-5 pb-1 sm:px-6 sm:pt-6 lg:px-8">
      <div className="mx-auto grid max-w-7xl grid-cols-2 gap-2.5 lg:grid-cols-4 lg:gap-3">
        {STATS.map((stat, i) => {
          const Icon = stat.icon;
          return (
            <Reveal key={stat.label} delay={(i + 1) as 1 | 2 | 3 | 4}>
      <article className="flex h-full items-start gap-3 rounded-2xl border border-[var(--landing-border)] bg-[var(--landing-paper)] px-3.5 py-3.5 shadow-[var(--landing-shadow)] sm:gap-3.5 sm:px-4 sm:py-4">
                <span className="flex h-8 w-8 shrink-0 items-center justify-center rounded-full bg-[var(--landing-peach)] text-[var(--landing-orange)]">
                  <Icon className="h-3.5 w-3.5" strokeWidth={1.75} />
                </span>
                <div className="min-w-0">
                  <p className="landing-text-navy flex items-baseline gap-1 text-[1.2rem] font-semibold leading-none tracking-tight sm:text-[1.35rem]">
                    <span>{stat.value}</span>
                    {'unit' in stat ? (
                      <span className="text-[0.8rem] font-semibold tracking-tight text-[var(--landing-muted)]">
                        {stat.unit}
                      </span>
                    ) : null}
                  </p>
                  <p className="landing-text-navy mt-1.5 text-[12px] font-semibold tracking-tight">{stat.label}</p>
                  <p className="landing-text-muted mt-0.5 text-[11px] leading-snug sm:text-xs">{stat.detail}</p>
                </div>
              </article>
            </Reveal>
          );
        })}
      </div>
    </section>
  );
}
