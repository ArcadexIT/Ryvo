'use client';

import { LandingImage } from './landing-image';
import { Check } from 'lucide-react';
import { LANDING_IMAGES } from './images';
import { Reveal } from './reveal';
import { LandingBadge } from './section-heading';

const RIDER_BENEFITS = [
  'Pickup and dropoff in a few taps',
  'A fare estimate before you request',
  'A driver you can follow on the map',
];

const DRIVER_BENEFITS = [
  'See the fare, pickup, and dropoff before you accept',
  'Navigate to the rider, then on to the destination',
  'Earnings land in the app after each trip',
];

export function LandingChecklist() {
  return (
    <section id="benefit" className="landing-section bg-[var(--landing-cream)]">
      <div className="mx-auto grid max-w-7xl items-center gap-12 px-4 sm:px-6 lg:grid-cols-2 lg:gap-20 lg:px-8">
        <Reveal variant="fade">
          <div className="relative mx-auto aspect-[4/3] w-full max-w-xl overflow-hidden rounded-[1.75rem] lg:max-w-none">
            <LandingImage
              src={LANDING_IMAGES.benefit}
              alt="A RYVO trip on the road"
              fill
              className="object-cover object-center"
              sizes="(max-width: 1024px) 100vw, 50vw"
            />
          </div>
        </Reveal>

        <Reveal delay={1}>
          <div>
            <LandingBadge>Benefits</LandingBadge>
            <h2 className="landing-text-navy mt-4 text-[2rem] sm:text-4xl lg:text-[2.75rem]">
              Built to work for everyone on the road
            </h2>
            <p className="landing-text-muted mt-4 text-base leading-relaxed">
              Riders get a clear trip. Drivers get offers they can accept or skip.
            </p>

            <div className="mt-10 grid gap-10 sm:grid-cols-2">
              <div>
                <h3 className="text-[11px] font-semibold uppercase tracking-[0.18em] text-[var(--landing-orange)]">
                  For riders
                </h3>
                <ul className="mt-4 space-y-3.5">
                  {RIDER_BENEFITS.map((item) => (
                    <li key={item} className="flex gap-3 text-sm leading-snug sm:text-[0.95rem]">
                      <span className="mt-0.5 flex h-5 w-5 shrink-0 items-center justify-center rounded-full bg-[var(--landing-navy)] text-[#fbf8f4]">
                        <Check className="h-3 w-3" strokeWidth={3} />
                      </span>
                      <span className="landing-text-navy font-medium">{item}</span>
                    </li>
                  ))}
                </ul>
              </div>
              <div>
                <h3 className="text-[11px] font-semibold uppercase tracking-[0.18em] text-[var(--landing-orange)]">
                  For drivers
                </h3>
                <ul className="mt-4 space-y-3.5">
                  {DRIVER_BENEFITS.map((item) => (
                    <li key={item} className="flex gap-3 text-sm leading-snug sm:text-[0.95rem]">
                      <span className="mt-0.5 flex h-5 w-5 shrink-0 items-center justify-center rounded-full border border-[var(--landing-navy)]/20 text-[var(--landing-navy)]">
                        <Check className="h-3 w-3" strokeWidth={3} />
                      </span>
                      <span className="landing-text-navy font-medium">{item}</span>
                    </li>
                  ))}
                </ul>
              </div>
            </div>
          </div>
        </Reveal>
      </div>
    </section>
  );
}
