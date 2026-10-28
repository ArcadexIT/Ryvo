'use client';

import { LandingImage } from './landing-image';
import { LANDING_IMAGES } from './images';
import { Reveal } from './reveal';
import { LandingBadge } from './section-heading';

const REGIONS = [
  {
    title: 'Nearby',
    description: 'A driver close to you sees the offer and can accept.',
    number: '01',
  },
  {
    title: 'Live areas',
    description: 'The app confirms your pickup is inside a covered area.',
    number: '02',
  },
  {
    title: 'Growing',
    description: 'New areas open over time, with the same fare and tracking.',
    number: '03',
  },
];

export function LandingCoverage() {
  return (
    <section id="roadmap" className="landing-section bg-[var(--landing-cream)]">
      <div className="mx-auto grid max-w-7xl items-stretch gap-10 px-4 sm:px-6 lg:grid-cols-2 lg:gap-16 lg:px-8">
        <Reveal>
          <div>
            <LandingBadge>Coverage</LandingBadge>
            <h2 className="landing-text-navy mt-4 text-[2rem] sm:text-4xl lg:text-[2.75rem]">
              Rides where you are
            </h2>

            <ol className="mt-10 space-y-0">
              {REGIONS.map((region, index) => (
                <li key={region.title} className="relative flex gap-5 py-5">
                  {index < REGIONS.length - 1 ? (
                    <span
                      className="absolute bottom-0 left-[15px] top-12 w-px bg-[var(--landing-border)]"
                      aria-hidden
                    />
                  ) : null}
                  <span className="landing-display relative z-10 mt-0.5 w-8 shrink-0 text-xl text-[var(--landing-orange)]">
                    {region.number}
                  </span>
                  <div className="min-w-0 flex-1 border-b border-[var(--landing-border)] pb-5">
                    <h3 className="landing-text-navy text-lg font-semibold tracking-tight">{region.title}</h3>
                    <p className="landing-text-muted mt-1 text-sm leading-relaxed">{region.description}</p>
                  </div>
                </li>
              ))}
            </ol>
          </div>
        </Reveal>

        <Reveal delay={2} variant="fade">
          <div className="relative h-full min-h-[240px] overflow-hidden rounded-[1.75rem] bg-[var(--landing-navy)] shadow-[var(--landing-shadow-lg)] sm:min-h-[320px]">
            <LandingImage
              src={LANDING_IMAGES.coverage}
              alt="City streets at dusk with cars on the road"
              fill
              className="object-cover object-center"
              sizes="(max-width: 1024px) 100vw, 50vw"
            />
          </div>
        </Reveal>
      </div>
    </section>
  );
}
