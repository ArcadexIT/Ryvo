'use client';

import { useState } from 'react';
import { Plus } from 'lucide-react';
import { cn } from '@/lib/utils';
import { SectionHeading } from './section-heading';
import { Reveal } from './reveal';

const FAQS = [
  {
    question: 'How much does a ride cost?',
    answer:
      'You see an estimate before you request, based on the ride class, distance, and time. The final fare is charged to your saved card or wallet when the trip ends.',
  },
  {
    question: 'Where is RYVO available?',
    answer:
      'RYVO runs in live service areas. The app tells you if your pickup is covered before you request.',
  },
  {
    question: 'How does a driver get my ride?',
    answer:
      'After you set pickup, dropoff, and a ride class, nearby online drivers see the offer. The first driver to accept is matched, and you can track them live.',
  },
  {
    question: 'What is the difference between the rider and driver apps?',
    answer:
      'Riders use the rider app to request a trip, follow the car, and pay at the end. Drivers use the driver app to go online, accept offers, and complete the trip.',
  },
  {
    question: 'When do I pay?',
    answer:
      'You choose a card, wallet, or cash before the request. Nothing is charged until the driver ends the trip at your dropoff.',
  },
  {
    question: 'Which ride types can I request?',
    answer:
      'Ryvo Go, Comfort, and XL. Each class has its own fare. A driver only receives offers for the classes their vehicle is approved to serve.',
  },
];

export function LandingFaq() {
  const [openIndex, setOpenIndex] = useState<number | null>(0);

  return (
    <section id="faq" className="landing-section bg-[var(--landing-paper)]">
      <div className="mx-auto max-w-3xl px-4 sm:px-6 lg:px-8">
        <Reveal>
          <SectionHeading
            eyebrow="FAQ"
            title="Questions riders and drivers ask"
            className="mb-12 lg:mb-14"
          />
        </Reveal>

        <div className="divide-y divide-[var(--landing-border)] border-y border-[var(--landing-border)]">
          {FAQS.map((faq, i) => {
            const isOpen = openIndex === i;
            return (
              <Reveal key={faq.question} delay={((i % 4) + 1) as 1 | 2 | 3 | 4}>
                <div>
                  <button
                    type="button"
                    className="flex w-full items-start justify-between gap-4 py-5 text-left sm:py-6"
                    aria-expanded={isOpen}
                    onClick={() => setOpenIndex(isOpen ? null : i)}
                  >
                    <span className="landing-text-navy text-base font-semibold tracking-tight sm:text-lg">
                      {faq.question}
                    </span>
                    <Plus
                      className={cn(
                        'mt-1 h-5 w-5 shrink-0 text-[var(--landing-orange)] transition-transform duration-300',
                        isOpen && 'rotate-45',
                      )}
                    />
                  </button>
                  <div className={cn('landing-faq-answer', isOpen && 'is-open')}>
                    <div>
                      <p className="landing-text-muted pb-5 text-sm leading-relaxed sm:pb-6 sm:text-base">
                        {faq.answer}
                      </p>
                    </div>
                  </div>
                </div>
              </Reveal>
            );
          })}
        </div>
      </div>
    </section>
  );
}
