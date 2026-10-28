'use client';

import Image from 'next/image';
import { Check } from 'lucide-react';
import { LANDING_IMAGES } from './images';
import { Reveal } from './reveal';

const ITEMS = [
  'Secure In-App Payments',
  'Instant Matching',
  'In-App Chat & Call',
  'Live Tracking, Instantly Matched',
];

export function LandingProduct() {
  return (
    <section className="landing-section bg-white">
      <div className="mx-auto grid max-w-7xl items-center gap-10 px-4 sm:px-6 lg:grid-cols-2 lg:gap-16 lg:px-8">
        <Reveal variant="fade">
          <div className="relative aspect-[16/10] overflow-hidden rounded-[1.5rem]">
            <Image
              src={LANDING_IMAGES.truck}
              alt="RYVO technician changing a tyre on a white SUV"
              fill
              className="object-cover"
              sizes="(max-width: 1024px) 100vw, 50vw"
            />
          </div>
        </Reveal>

        <Reveal delay={1}>
          <div>
            <h2 className="landing-text-navy text-2xl font-bold sm:text-3xl lg:text-4xl">
              Built for speed, designed for peace of mind
            </h2>
            <ul className="mt-8 space-y-3">
              {ITEMS.map((item) => (
                <li key={item} className="flex items-center gap-3">
                  <span className="flex h-5 w-5 shrink-0 items-center justify-center rounded-full bg-[var(--landing-peach)] text-[var(--landing-orange)]">
                    <Check className="h-3 w-3" strokeWidth={3} />
                  </span>
                  <span className="landing-text-navy font-semibold">{item}</span>
                </li>
              ))}
            </ul>
            <div className="relative mt-8 mx-auto aspect-[3/4] w-40 sm:w-48">
              <Image
                src={LANDING_IMAGES.features04}
                alt="RYVO live navigation and route tracking on mobile"
                fill
                className="object-contain"
                sizes="192px"
              />
            </div>
          </div>
        </Reveal>
      </div>
    </section>
  );
}
