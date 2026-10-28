'use client';

import { LandingImage } from './landing-image';
import { SectionHeading } from './section-heading';
import { LANDING_IMAGES } from './images';
import { Reveal } from './reveal';

const SERVICES = [
  {
    number: '01',
    title: 'Ryvo Go',
    description: 'The everyday ride. Up to four passengers, a clear fare, a nearby driver.',
    image: LANDING_IMAGES.service01,
    alt: 'Ryvo Go, the everyday ride',
  },
  {
    number: '02',
    title: 'Comfort',
    description: 'A newer car and more room when the trip should feel easier.',
    image: LANDING_IMAGES.service02,
    alt: 'Comfort ride with extra room',
  },
  {
    number: '03',
    title: 'XL',
    description: 'A larger vehicle for groups, airport runs, and extra luggage.',
    image: LANDING_IMAGES.service03,
    alt: 'XL ride for groups and luggage',
  },
];

export function LandingServices() {
  return (
    <section
      id="services"
      className="landing-section landing-on-dark bg-[var(--landing-navy)] text-[#fbf8f4]"
    >
      <div className="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8">
        <Reveal>
          <SectionHeading
            eyebrow="Ride types"
            title="Choose the car, see the fare, go"
            tone="dark"
            className="mb-14 lg:mb-16"
          />
        </Reveal>

        <div className="grid gap-5 sm:grid-cols-2 lg:grid-cols-3 lg:gap-6">
          {SERVICES.map((service, i) => (
            <Reveal key={service.title} delay={(i + 1) as 1 | 2 | 3 | 4}>
              <article className="group flex h-full flex-col overflow-hidden rounded-[1.5rem] border border-white/10 bg-[var(--landing-navy-light)] transition-transform duration-500 hover:-translate-y-1">
                <div className="relative aspect-square overflow-hidden bg-white">
                  <LandingImage
                    src={service.image}
                    alt={service.alt}
                    fill
                    className="object-cover object-center transition-transform duration-700 group-hover:scale-[1.04]"
                    sizes="(max-width: 640px) 100vw, (max-width: 1024px) 50vw, 25vw"
                  />
                </div>
                <div className="flex flex-1 flex-col px-6 py-5">
                  <div className="flex items-center justify-between gap-2">
                    <span className="landing-text-orange text-[11px] font-semibold tracking-[0.18em]">
                      {service.number}
                    </span>
                  </div>
                  <h3 className="landing-display landing-text-white mt-2 text-[1.65rem] leading-tight">
                    {service.title}
                  </h3>
                  <p className="landing-text-white-soft mt-2 flex-1 text-[0.9375rem] leading-relaxed">
                    {service.description}
                  </p>
                </div>
              </article>
            </Reveal>
          ))}
        </div>
      </div>
    </section>
  );
}
