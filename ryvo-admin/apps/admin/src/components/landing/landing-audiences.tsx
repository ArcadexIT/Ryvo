'use client';

import { LandingImage } from './landing-image';
import { SectionHeading } from './section-heading';
import { StoreBadgeRow } from './store-badges';
import { LANDING_IMAGES } from './images';
import { Reveal } from './reveal';

export function LandingAudiences() {
  return (
    <section className="landing-section bg-[var(--landing-paper)]">
      <div className="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8">
        <Reveal>
          <SectionHeading
            eyebrow="Two apps"
            title="One platform. Built for both sides."
            className="mb-14 lg:mb-16"
          />
        </Reveal>

        <div className="grid gap-6 lg:grid-cols-2 lg:gap-8">
          <Reveal delay={1}>
            <article className="relative flex h-full flex-col overflow-hidden rounded-[1.75rem] border border-[var(--landing-border)] bg-[var(--landing-peach)]">
              <div className="px-8 pt-8 sm:px-10 sm:pt-10">
                <span className="landing-eyebrow">For riders</span>
                <h3 className="landing-display landing-text-navy mt-4 text-3xl">Ryvo Rider App</h3>
                <p className="landing-text-muted mt-3 text-base leading-relaxed">
                  Set pickup and dropoff, pick a ride class, and follow your driver. The fare is
                  charged when the trip ends.
                </p>
              </div>
              <div className="relative mt-8 aspect-[4/3] w-full overflow-hidden bg-white">
                <LandingImage
                  src={LANDING_IMAGES.customerApp}
                  alt="Rider holding a phone showing the RYVO app"
                  fill
                  className="object-cover object-center"
                  sizes="(max-width: 1024px) 100vw, 50vw"
                />
              </div>
              <div className="px-8 py-6 sm:px-10 sm:py-8">
                <StoreBadgeRow audience="customer" />
              </div>
            </article>
          </Reveal>

          <Reveal delay={2}>
            <article className="landing-on-dark flex h-full flex-col overflow-hidden rounded-[1.75rem] border border-[var(--landing-border)] bg-[var(--landing-navy)] text-[#fbf8f4]">
              <div className="px-8 pt-8 sm:px-10 sm:pt-10">
                <span className="landing-eyebrow">For drivers</span>
                <h3 className="landing-display mt-4 text-3xl text-[#fbf8f4]">Ryvo Driver App</h3>
                <p className="mt-3 text-base leading-relaxed text-white/65">
                  Go online, accept ride offers, navigate to pickup, and end the trip at dropoff.
                </p>
              </div>
              <div className="relative mt-8 aspect-[4/3] w-full overflow-hidden bg-white">
                <LandingImage
                  src={LANDING_IMAGES.providerApp}
                  alt="Driver holding a phone showing the RYVO driver app"
                  fill
                  className="object-cover object-center"
                  sizes="(max-width: 1024px) 100vw, 50vw"
                />
              </div>
              <div className="px-8 py-6 sm:px-10 sm:py-8">
                <StoreBadgeRow audience="provider" tone="light" />
              </div>
            </article>
          </Reveal>
        </div>
      </div>
    </section>
  );
}
