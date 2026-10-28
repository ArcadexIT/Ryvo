import { Armchair, Car, CreditCard, Users } from 'lucide-react';
import { LandingButton } from './landing-button';
import { LandingImage } from './landing-image';
import { StoreBadgeRow } from './store-badges';
import { LANDING_IMAGES } from './images';
import { landingSection } from './paths';

const HERO_SERVICES = [
  {
    title: 'Ryvo Go',
    description: 'Everyday rides for up to four.',
    icon: Car,
  },
  {
    title: 'Comfort',
    description: 'Newer cars with extra room.',
    icon: Armchair,
  },
  {
    title: 'XL',
    description: 'Space for groups and luggage.',
    icon: Users,
  },
  {
    title: 'Pay at the end',
    description: 'See the estimate, then pay on arrival.',
    icon: CreditCard,
  },
];

export function LandingHero() {
  return (
    <section id="home" className="bg-[var(--landing-cream)] px-4 pb-6 pt-28 sm:px-6 lg:px-8 lg:pb-10 lg:pt-32">
      <div className="mx-auto grid max-w-7xl items-center gap-8 lg:grid-cols-[1.05fr_0.95fr] lg:gap-12">
        <div className="max-w-xl">
          <p className="text-[11px] font-semibold uppercase tracking-[0.16em] text-[var(--landing-orange)]">
            Rides, on demand
          </p>
          <h1 className="mt-4 text-[2.6rem] font-semibold leading-[0.98] tracking-[-0.05em] text-[var(--landing-navy)] sm:text-6xl lg:text-[4.4rem]">
            Where to?
            <span className="mt-1 block text-[var(--landing-orange)]">A driver accepts.</span>
          </h1>
          <p className="mt-5 max-w-md text-base leading-relaxed text-[var(--landing-muted)] sm:text-lg">
            Set pickup and dropoff, see the fare, and watch your driver on the way. You pay when the trip ends.
          </p>
          <div className="mt-7 flex flex-wrap items-center gap-3">
            <LandingButton href={landingSection('download')} variant="orange" size="lg">
              Request a ride
            </LandingButton>
            <p className="text-sm font-medium text-[var(--landing-navy)]">Available in live areas</p>
          </div>
          <StoreBadgeRow className="mt-5 [&_a]:!h-11 [&_a]:!rounded-full [&_a]:!px-3.5" tone="dark" />
        </div>

        <div className="relative">
          <div className="relative aspect-[4/5] overflow-hidden rounded-[32px] bg-[#111] shadow-[0_30px_80px_-40px_rgba(10,20,36,0.55)] sm:aspect-[5/4]">
            <picture>
              <source media="(max-width: 1023px)" srcSet={LANDING_IMAGES.heroMobile} />
              <img
                src={LANDING_IMAGES.hero}
                alt="Rider opening RYVO to request a trip, with a nearby driver shown on the map"
                fetchPriority="high"
                decoding="async"
                className="absolute inset-0 h-full w-full object-cover"
              />
            </picture>
          </div>
          <div className="absolute -bottom-4 left-4 right-4 flex items-center gap-3 rounded-[22px] bg-white p-3 shadow-[0_18px_40px_-24px_rgba(10,20,36,0.45)] sm:left-6 sm:right-auto sm:w-[18rem]">
            <span className="relative flex h-2.5 w-2.5 shrink-0">
              <span className="absolute inline-flex h-full w-full animate-ping rounded-full bg-emerald-400 opacity-70" />
              <span className="relative inline-flex h-2.5 w-2.5 rounded-full bg-emerald-400" />
            </span>
            <div>
              <p className="text-sm font-semibold text-[var(--landing-navy)]">Arriving in 6 min</p>
              <p className="text-xs text-[var(--landing-muted)]">1.2 miles away · live map</p>
            </div>
          </div>
        </div>
      </div>

      <div className="mx-auto mt-14 grid max-w-7xl grid-cols-2 gap-3 lg:mt-20 lg:grid-cols-4">
        {HERO_SERVICES.map((service) => {
          const Icon = service.icon;
          return (
            <article key={service.title} className="rounded-[22px] bg-white p-4 ring-1 ring-black/[0.04] sm:p-5">
              <Icon className="h-6 w-6 text-[var(--landing-orange)]" strokeWidth={1.75} />
              <h3 className="mt-4 text-base font-semibold tracking-tight text-[var(--landing-navy)]">{service.title}</h3>
              <p className="mt-1 text-sm leading-relaxed text-[var(--landing-muted)]">{service.description}</p>
            </article>
          );
        })}
      </div>

      <article className="mx-auto mt-3 grid max-w-7xl overflow-hidden rounded-[28px] bg-[#111] text-white lg:mt-4 lg:grid-cols-[1fr_minmax(16rem,28rem)]">
        <div className="px-6 py-7 sm:px-8">
          <h3 className="text-2xl font-semibold tracking-[-0.03em]">Real-time tracking</h3>
          <p className="mt-2 max-w-md text-sm leading-relaxed text-white/65 sm:text-base">
            Track your driver live, from pickup through to dropoff.
          </p>
        </div>
        <div className="relative mx-4 mb-4 h-40 overflow-hidden rounded-[22px] sm:mx-6 sm:mb-6 lg:m-3 lg:h-auto lg:min-h-40">
          <LandingImage
            src={LANDING_IMAGES.heroTrackingSnippet}
            alt="Live map showing a driver approaching the pickup"
            fill
            className="object-cover"
            sizes="(max-width: 1024px) 100vw, 28rem"
          />
        </div>
      </article>
    </section>
  );
}
