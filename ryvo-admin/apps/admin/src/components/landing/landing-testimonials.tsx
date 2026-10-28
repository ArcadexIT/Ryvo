'use client';

import { useEffect, useState } from 'react';
import { LandingImage } from './landing-image';
import { ChevronLeft, ChevronRight, Star } from 'lucide-react';
import { cn } from '@/lib/utils';
import { SectionHeading } from './section-heading';
import { LANDING_IMAGES } from './images';

const TESTIMONIALS = [
  {
    quote:
      'I set the dropoff, saw the fare, and a driver accepted in a minute. I watched the car the whole way.',
    name: 'Sarah M.',
    role: 'Rider',
    photo: LANDING_IMAGES.testimonials.sarah,
    filled: 4,
  },
  {
    quote:
      'The offer shows pickup, dropoff, and what I earn. I accept the ones that fit and skip the rest.',
    name: 'David Emon',
    role: 'Driver',
    photo: LANDING_IMAGES.testimonials.david,
    filled: 4,
  },
  {
    quote:
      'I could see exactly who was coming and when. The trip felt calm from the first pin to dropoff.',
    name: 'Amara Kyser',
    role: 'Rider',
    photo: LANDING_IMAGES.testimonials.amara,
    filled: 5,
  },
  {
    quote:
      'Late train, full platform, and a Comfort car was outside before I reached the exit.',
    name: 'James Cole',
    role: 'Rider',
    photo: LANDING_IMAGES.testimonials.james,
    filled: 5,
  },
  {
    quote:
      'Navigation takes me to the rider, then straight on to the destination. The trip details are clear.',
    name: 'Priya N.',
    role: 'Driver',
    photo: LANDING_IMAGES.testimonials.priya,
    filled: 4,
  },
  {
    quote:
      'The estimate was on screen before I requested. I paid when we arrived, and it matched the trip.',
    name: 'Tom Walsh',
    role: 'Rider',
    photo: LANDING_IMAGES.testimonials.tom,
    filled: 5,
  },
  {
    quote:
      'Airport run with luggage. I picked XL, the driver accepted, and we were moving in a few minutes.',
    name: 'Emma R.',
    role: 'Rider',
    photo: LANDING_IMAGES.testimonials.emma,
    filled: 5,
  },
  {
    quote:
      'Offers stay close to me and the payouts are reliable. I can fit RYVO around the rest of the day.',
    name: 'Hassan Ali',
    role: 'Driver',
    photo: LANDING_IMAGES.testimonials.hassan,
    filled: 4,
  },
  {
    quote:
      'Home after a late shift. I tracked the driver the whole way and the card was charged at the end.',
    name: 'Chloe P.',
    role: 'Rider',
    photo: LANDING_IMAGES.testimonials.chloe,
    filled: 5,
  },
];

const VISIBLE = 3;

function Stars({ filled }: { filled: number }) {
  return (
    <div className="flex gap-0.5">
      {Array.from({ length: 5 }).map((_, i) => (
        <Star
          key={i}
          className={cn(
            'h-3.5 w-3.5',
            i < filled
              ? 'fill-[var(--landing-orange)] text-[var(--landing-orange)]'
              : 'text-[var(--landing-border)]',
          )}
        />
      ))}
    </div>
  );
}

function TestimonialCard({ item }: { item: (typeof TESTIMONIALS)[number] }) {
  return (
    <article className="flex h-full min-w-0 flex-col rounded-[1.5rem] border border-[var(--landing-border)] bg-[var(--landing-cream)] p-6 sm:p-7">
      <Stars filled={item.filled} />
      <p className="landing-display landing-text-navy mt-4 flex-1 text-lg leading-snug sm:text-xl">
        &ldquo;{item.quote}&rdquo;
      </p>
      <div className="mt-6 flex items-center gap-3 border-t border-[var(--landing-border)] pt-5">
        <div className="relative h-12 w-12 shrink-0 overflow-hidden rounded-full ring-2 ring-white">
          <LandingImage src={item.photo} alt={item.name} fill className="object-cover" sizes="48px" />
        </div>
        <div>
          <p className="landing-text-navy text-sm font-semibold">{item.name}</p>
          <p className="landing-text-muted text-xs">{item.role}</p>
        </div>
      </div>
    </article>
  );
}

export function LandingTestimonials() {
  const [page, setPage] = useState(0);
  const [paused, setPaused] = useState(false);
  const pageCount = Math.ceil(TESTIMONIALS.length / VISIBLE);

  useEffect(() => {
    if (paused) return undefined;
    const reduceMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
    if (reduceMotion) return undefined;

    const timer = window.setInterval(() => {
      setPage((i) => (i === pageCount - 1 ? 0 : i + 1));
    }, 5000);

    return () => window.clearInterval(timer);
  }, [paused, pageCount]);

  function prev() {
    setPage((i) => (i === 0 ? pageCount - 1 : i - 1));
  }

  function next() {
    setPage((i) => (i === pageCount - 1 ? 0 : i + 1));
  }

  return (
    <section id="reviews" className="landing-section bg-[var(--landing-paper)]">
      <div className="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8">
        <div className="mb-8 flex flex-col items-start justify-between gap-4 sm:flex-row sm:items-end lg:mb-10">
          <SectionHeading
            eyebrow="Testimonials"
            title="Riders and drivers already trust RYVO"
            align="left"
            className="mx-0 max-w-xl"
          />
          <div className="flex gap-2">
            <button
              type="button"
              onClick={prev}
              aria-label="Previous testimonials"
              className="landing-text-navy flex h-11 w-11 items-center justify-center rounded-full border border-[var(--landing-border)] bg-[var(--landing-paper)] transition-colors hover:bg-[var(--landing-cream)]"
            >
              <ChevronLeft className="h-5 w-5" />
            </button>
            <button
              type="button"
              onClick={next}
              aria-label="Next testimonials"
              className="landing-text-navy flex h-11 w-11 items-center justify-center rounded-full border border-[var(--landing-border)] bg-[var(--landing-paper)] transition-colors hover:bg-[var(--landing-cream)]"
            >
              <ChevronRight className="h-5 w-5" />
            </button>
          </div>
        </div>

        <div
          className="min-w-0 overflow-hidden"
          onMouseEnter={() => setPaused(true)}
          onMouseLeave={() => setPaused(false)}
        >
          <div
            className="flex transition-transform duration-500 ease-out"
            style={{
              width: `${pageCount * 100}%`,
              transform: `translateX(-${page * (100 / pageCount)}%)`,
            }}
          >
            {Array.from({ length: pageCount }).map((_, pageIndex) => (
              <div
                key={pageIndex}
                className="grid shrink-0 grid-cols-1 gap-6 md:grid-cols-3"
                style={{ width: `${100 / pageCount}%` }}
              >
                {TESTIMONIALS.slice(pageIndex * VISIBLE, pageIndex * VISIBLE + VISIBLE).map(
                  (item) => (
                    <TestimonialCard key={item.name} item={item} />
                  ),
                )}
              </div>
            ))}
          </div>
        </div>

        <div className="mt-5 flex justify-center gap-2">
          {Array.from({ length: pageCount }).map((_, i) => (
            <button
              key={i}
              type="button"
              aria-label={`Go to testimonials page ${i + 1}`}
              aria-current={i === page ? true : undefined}
              onClick={() => setPage(i)}
              className={cn(
                'h-1.5 rounded-full transition-all',
                i === page ? 'w-7 bg-[var(--landing-orange)]' : 'w-2 bg-[var(--landing-border)]',
              )}
            />
          ))}
        </div>
      </div>
    </section>
  );
}
