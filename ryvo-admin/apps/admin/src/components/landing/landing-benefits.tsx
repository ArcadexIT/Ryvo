'use client';

import { Crosshair, Hand, MapPin, Navigation } from 'lucide-react';
import { SectionHeading } from './section-heading';
import { Reveal } from './reveal';

const STEPS = [
  {
    number: '01',
    title: 'Set your trip',
    description: 'Drop a pin for pickup, choose where you are going, and pick Ryvo Go, Comfort, or XL.',
    icon: Hand,
  },
  {
    number: '02',
    title: 'See the fare',
    description: 'The estimate is on screen before you request. You are charged when you arrive.',
    icon: MapPin,
  },
  {
    number: '03',
    title: 'A driver accepts',
    description: 'Nearby drivers see the offer. The first to accept is on the way.',
    icon: Crosshair,
  },
  {
    number: '04',
    title: 'Ride to dropoff',
    description: 'Follow the car on the map, then rate the trip after you arrive.',
    icon: Navigation,
  },
];

export function LandingBenefits() {
  return (
    <section id="how-it-works" className="landing-section bg-[var(--landing-paper)]">
      <div className="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8">
        <Reveal>
          <SectionHeading
            eyebrow="How it works"
            title="From request to dropoff"
            className="mb-4 lg:mb-5"
          />
          <p className="landing-text-muted mx-auto mb-14 max-w-2xl text-center text-base leading-relaxed lg:mb-16">
            Riders request. Drivers accept. Both apps follow the same trip, live on the map.
          </p>
        </Reveal>

        <div className="relative grid gap-8 sm:grid-cols-2 lg:grid-cols-4 lg:gap-6">
          <div
            className="pointer-events-none absolute left-[12%] right-[12%] top-8 hidden h-px bg-gradient-to-r from-transparent via-[var(--landing-border)] to-transparent lg:block"
            aria-hidden
          />
          {STEPS.map(({ number, title, description, icon: Icon }, i) => (
            <Reveal key={number} delay={(i + 1) as 1 | 2 | 3 | 4}>
              <article className="relative flex h-full flex-col items-center px-4 text-center lg:pt-2">
                <span className="landing-display text-5xl text-[var(--landing-orange)]/90">{number}</span>
                <Icon className="mt-5 h-7 w-7 text-[var(--landing-navy)]" strokeWidth={1.4} />
                <h3 className="landing-text-navy mt-4 text-base font-semibold tracking-tight">{title}</h3>
                <p className="landing-text-muted mt-2 text-sm leading-relaxed">{description}</p>
              </article>
            </Reveal>
          ))}
        </div>
      </div>
    </section>
  );
}
