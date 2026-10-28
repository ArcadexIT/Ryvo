import Image from 'next/image';
import { BadgeCheck, Bell, MessageCircle, Phone, Star } from 'lucide-react';
import { LANDING_IMAGES } from './images';

export function HeroPhoneMockup() {
  return (
    <figure
      className="hero-phone mx-auto w-[214px] sm:w-[248px] lg:w-[286px]"
      aria-label="RYVO app showing a driver arriving in 6 minutes"
    >
      <div className="hero-phone-bezel">
        <div className="relative flex aspect-[9/19.4] flex-col overflow-hidden rounded-[2rem] bg-[#f4f2ef]">
          <div className="hero-phone-island" aria-hidden />

          <div className="flex items-center justify-between px-5 pb-1 pt-3.5 text-[11px] font-semibold text-[#111]">
            <span>9:41</span>
            <span className="inline-block h-2 w-5 rounded-[2px] border border-[#111]" />
          </div>

          <div className="flex items-center justify-between px-4 pt-1">
            <span className="flex h-8 w-8 items-center justify-center rounded-lg bg-white text-[#111] shadow-sm">
              <span className="flex flex-col gap-[3px]" aria-hidden>
                <span className="h-[1.5px] w-3.5 rounded bg-[#111]" />
                <span className="h-[1.5px] w-3.5 rounded bg-[#111]" />
                <span className="h-[1.5px] w-3.5 rounded bg-[#111]" />
              </span>
            </span>
            <span className="text-[15px] font-extrabold tracking-tight text-[#111]">RYVO</span>
            <span className="flex h-8 w-8 items-center justify-center rounded-lg bg-white shadow-sm">
              <Bell className="h-4 w-4 text-[#111]" strokeWidth={1.75} />
            </span>
          </div>

          <div className="px-5 pt-3">
            <p className="text-[13px] font-semibold text-[#111]">Driver on the way</p>
            <p className="mt-0.5 text-[1.45rem] font-extrabold leading-none tracking-tight text-[#111]">
              Arriving in <span className="text-[var(--landing-orange)]">6</span> min
            </p>
          </div>

          <div className="relative mx-3 mt-3 min-h-0 flex-1 overflow-hidden rounded-[1.35rem]">
            <Image
              src={LANDING_IMAGES.heroMap}
              alt=""
              fill
              className="object-cover"
              sizes="286px"
            />
            <span className="absolute right-[16%] top-[18%] flex flex-col items-center">
              <span className="rounded-full bg-[#111] px-2 py-0.5 text-[9px] font-semibold text-white">
                You
              </span>
              <span className="mt-0.5 h-3.5 w-3.5 rounded-full border-[3px] border-white bg-[var(--landing-orange)] shadow-md" />
            </span>
            <span className="absolute bottom-[36%] left-[20%] flex h-8 w-8 items-center justify-center rounded-full bg-white shadow-md">
              <span className="text-[15px]" aria-hidden>
                🚗
              </span>
            </span>
          </div>

          <div className="relative z-10 -mt-16 mx-3 mb-3 rounded-[1.15rem] bg-white p-3 shadow-[0_12px_32px_-12px_rgba(0,0,0,0.35)]">
            <div className="flex items-center gap-2.5">
              <Image
                src={LANDING_IMAGES.providerAlex}
                alt=""
                width={44}
                height={44}
                className="h-11 w-11 rounded-full object-cover"
              />
              <div className="min-w-0 flex-1">
                <div className="flex items-center justify-between gap-2">
                  <p className="flex items-center gap-1 truncate text-sm font-bold text-[#111]">
                    Alex
                    <BadgeCheck className="h-3.5 w-3.5 shrink-0 fill-[var(--landing-orange)] text-white" />
                  </p>
                  <span className="inline-flex items-center gap-0.5 text-[11px] font-semibold text-[#111]">
                    <Star className="h-3.5 w-3.5 fill-[var(--landing-orange)] text-[var(--landing-orange)]" />
                    4.9 (128)
                  </span>
                </div>
                <p className="truncate text-[11px] text-[#6b6560]">Volkswagen Polo · Grey</p>
                <p className="mt-0.5 inline-block rounded-md bg-[#f3f1ee] px-1.5 py-0.5 font-mono text-[10px] font-semibold tracking-wide text-[#111]">
                  AB12 CDE
                </p>
              </div>
            </div>
            <div className="mt-3 grid grid-cols-2 gap-2">
              <span className="inline-flex h-9 items-center justify-center gap-1.5 rounded-xl bg-[#f3f1ee] text-[12px] font-semibold text-[#111]">
                <Phone className="h-3.5 w-3.5" strokeWidth={2} />
                Call
              </span>
              <span className="inline-flex h-9 items-center justify-center gap-1.5 rounded-xl bg-[#171717] text-[12px] font-semibold text-white">
                <MessageCircle className="h-3.5 w-3.5" strokeWidth={2} />
                Message
              </span>
            </div>
          </div>
        </div>
      </div>
    </figure>
  );
}
