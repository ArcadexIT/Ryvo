import Image from 'next/image';
import { Facebook, Instagram, Linkedin, Twitter } from 'lucide-react';
import { LANDING_CONTACT, LANDING_HOME, LANDING_PRIVACY, LANDING_TERMS, landingSection } from './paths';

const DRIVER_LINKS = [
  { label: 'How it works', href: landingSection('how-it-works') },
  { label: 'Download the app', href: landingSection('download') },
  { label: 'Ride types', href: landingSection('services') },
  { label: 'Support', href: LANDING_CONTACT },
];

const PROVIDER_LINKS = [
  { label: 'Become a driver', href: landingSection('download') },
  { label: 'Earnings', href: landingSection('benefit') },
  { label: 'Driver app', href: landingSection('download') },
  { label: 'Support', href: LANDING_CONTACT },
];

const COMPANY_LINKS = [
  { label: 'About RYVO', href: LANDING_HOME },
  { label: 'Coverage', href: landingSection('roadmap') },
  { label: 'FAQ', href: landingSection('faq') },
  { label: 'Terms and Conditions', href: LANDING_TERMS },
  { label: 'Privacy Policy', href: LANDING_PRIVACY },
  { label: 'Delete account', href: `${LANDING_CONTACT}?topic=account-deletion` },
  { label: 'Contact', href: LANDING_CONTACT },
];

const SOCIAL = [
  { icon: Facebook, label: 'Facebook', href: landingSection('contact') },
  { icon: Instagram, label: 'Instagram', href: landingSection('contact') },
  { icon: Twitter, label: 'X', href: landingSection('contact') },
  { icon: Linkedin, label: 'LinkedIn', href: landingSection('contact') },
];

function FooterColumn({ title, links }: { title: string; links: { label: string; href: string }[] }) {
  return (
    <div>
      <h3 className="text-[11px] font-semibold uppercase tracking-[0.2em] text-white/45">{title}</h3>
      <ul className="mt-5 space-y-3">
        {links.map((link) => (
          <li key={`${title}-${link.label}`}>
            <a
              href={link.href}
              className="text-sm text-white/70 transition-colors hover:text-[var(--landing-orange)]"
            >
              {link.label}
            </a>
          </li>
        ))}
      </ul>
    </div>
  );
}

export function LandingFooter() {
  return (
    <footer id="contact" className="bg-[#070e18] text-[#fbf8f4]">
      <div className="mx-auto max-w-7xl px-4 py-16 sm:px-6 lg:px-8 lg:py-20">
        <div className="grid gap-12 sm:grid-cols-2 lg:grid-cols-4 lg:gap-10">
          <div>
            <Image
              src="/logo-wordmark-light.png"
              alt="RYVO"
              width={1415}
              height={360}
              className="h-7 w-auto"
            />
            <p className="mt-5 max-w-xs text-sm leading-relaxed text-white/55">
              A fare you can see, and a driver you can track.
            </p>
            <div className="mt-7 flex gap-2.5">
              {SOCIAL.map(({ icon: Icon, label, href }) => (
                <a
                  key={label}
                  href={href}
                  aria-label={label}
                  className="flex h-10 w-10 items-center justify-center rounded-full border border-white/10 text-white/70 transition-colors hover:border-[var(--landing-orange)] hover:text-[var(--landing-orange)]"
                >
                  <Icon className="h-4 w-4" />
                </a>
              ))}
            </div>
          </div>

          <FooterColumn title="Riders" links={DRIVER_LINKS} />
          <FooterColumn title="Drivers" links={PROVIDER_LINKS} />
          <FooterColumn title="Company" links={COMPANY_LINKS} />
        </div>

        <div className="mt-14 flex flex-col items-center justify-between gap-4 border-t border-white/10 pt-8 text-sm text-white/40 sm:flex-row">
          <p>© {new Date().getFullYear()} RYVO. All rights reserved.</p>
          <div className="flex items-center gap-6">
            <a href={LANDING_TERMS} className="transition-colors hover:text-[var(--landing-orange)]">
              Terms
            </a>
            <a href={LANDING_PRIVACY} className="transition-colors hover:text-[var(--landing-orange)]">
              Privacy Policy
            </a>
            <a href={LANDING_CONTACT} className="transition-colors hover:text-[var(--landing-orange)]">
              Contact
            </a>
          </div>
        </div>
      </div>
    </footer>
  );
}
