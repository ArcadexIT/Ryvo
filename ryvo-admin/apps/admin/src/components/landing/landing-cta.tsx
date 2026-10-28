'use client';

import { LandingImage } from './landing-image';
import { DualAudienceStoreBadges } from './store-badges';
import { LANDING_IMAGES } from './images';
import { Reveal } from './reveal';

export function LandingCta() {
  return (
    <section id="download" className="landing-section bg-[var(--landing-cream)]">
      <div className="landing-on-dark mx-auto grid max-w-7xl items-center gap-10 overflow-hidden rounded-[1.75rem] bg-[var(--landing-navy)] px-6 py-12 text-[#fbf8f4] sm:px-10 sm:py-14 lg:grid-cols-2 lg:gap-16 lg:px-14 lg:py-16">
        <Reveal>
          <div>
            <p className="landing-eyebrow">Get the app</p>
            <h2 className="mt-4 text-3xl text-[#fbf8f4] sm:text-4xl lg:text-[2.75rem]">
              Download RYVO today
            </h2>
            <p className="mt-4 max-w-md text-base leading-relaxed text-white/65">
              Get the rider app to request a trip, or the driver app to accept offers —
              available on the App Store and Google Play.
            </p>
            <DualAudienceStoreBadges className="mt-8" tone="light" />
          </div>
        </Reveal>

        <Reveal delay={2} variant="fade">
          <div className="relative mx-auto aspect-[4/3] w-full max-w-md lg:max-w-none">
            <LandingImage
              src={LANDING_IMAGES.cta}
              alt="Hand holding smartphone showing RYVO app home screen"
              fill
              className="object-contain object-center"
              sizes="(max-width: 1024px) 100vw, 50vw"
            />
          </div>
        </Reveal>
      </div>
    </section>
  );
}
