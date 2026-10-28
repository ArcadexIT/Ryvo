'use client';

import { LandingImage } from './landing-image';
import { ArrowRight } from 'lucide-react';
import { SectionHeading } from './section-heading';
import { LandingButton } from './landing-button';
import { LANDING_IMAGES } from './images';
import { Reveal } from './reveal';
import { landingSection } from './paths';
import { LiveTrackingMockup } from './live-tracking-mockup';
import { cn } from '@/lib/utils';

const FEATURE_CARDS = [
  {
    title: 'Secure In-App Payments',
    description: 'Save a card or wallet, then pay the final fare when you arrive.',
    image: LANDING_IMAGES.features01,
    alt: 'RYVO secure payment screen on mobile',
    imageClass: 'scale-[1.06]',
  },
  {
    title: 'Instant Matching',
    description: 'Nearby drivers see the offer and the first to accept takes the ride.',
    image: LANDING_IMAGES.features02,
    alt: 'RYVO instant matching map interface',
    imageClass: 'scale-[1.24]',
  },
  {
    title: 'In-App Chat & Call',
    description: 'Message or call your driver without swapping phone numbers.',
    image: LANDING_IMAGES.features03,
    alt: 'RYVO in-app chat and call with a driver',
    imageClass: 'scale-[1.24]',
  },
];

export function LandingFeatures() {
  return (
    <section id="features" className="landing-section bg-[var(--landing-cream)]">
      <div className="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8">
        <Reveal>
          <SectionHeading
            eyebrow="Features"
            title="Built for speed, designed for peace of mind"
            className="mb-8 lg:mb-10"
          />
        </Reveal>

        <div className="grid gap-4 lg:grid-cols-3">
          {FEATURE_CARDS.map((card, i) => (
            <Reveal key={card.title} delay={(i + 1) as 1 | 2 | 3}>
              <article className={cn('landing-card h-full overflow-hidden', i === 0 && 'lg:col-span-2')}>
                <div className="landing-feature-media">
                  <LandingImage
                    src={card.image}
                    alt={card.alt}
                    fill
                    className={cn('object-contain object-center', card.imageClass)}
                    sizes="(max-width: 768px) 100vw, 33vw"
                  />
                </div>
                <div className="px-6 py-5">
                  <h3 className="landing-text-navy text-lg font-semibold tracking-tight">{card.title}</h3>
                  <p className="landing-text-muted mt-1.5 text-sm leading-relaxed">{card.description}</p>
                </div>
              </article>
            </Reveal>
          ))}
        </div>

        <Reveal className="mt-6 lg:mt-8">
          <div className="landing-on-dark grid items-center gap-10 rounded-[28px] bg-[#111] px-6 py-8 text-[#fbf8f4] sm:px-10 sm:py-10 lg:grid-cols-[1fr_auto] lg:gap-16 lg:px-14 lg:py-12">
            <div className="max-w-lg">
              <p className="landing-eyebrow text-[var(--landing-orange)]">Live tracking</p>
              <h3 className="landing-display mt-3 text-3xl text-[#fbf8f4] sm:text-4xl">
                Instantly matched, always in view
              </h3>
              <p className="mt-3 text-base leading-relaxed text-white/65">
                See the driver who accepted, then follow the car from pickup to dropoff.
              </p>
              <LandingButton href={landingSection('download')} variant="orange" className="mt-6">
                Request a ride
                <ArrowRight className="h-4 w-4" />
              </LandingButton>
            </div>
            <div className="flex justify-center">
              <LiveTrackingMockup />
            </div>
          </div>
        </Reveal>
      </div>
    </section>
  );
}
