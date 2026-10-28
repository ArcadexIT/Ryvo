import type { Metadata } from 'next';
import '@/components/landing/landing.css';
import { LandingThemeLock } from '@/components/landing/landing-theme-lock';
import { LANDING_IMAGES } from '@/components/landing/images';

export const metadata: Metadata = {
  title: 'RYVO — Request a ride. A driver accepts.',
  description:
    'On-demand rides. Set pickup and dropoff, see the fare, track your driver, and pay when the trip ends.',
  icons: {
    icon: '/logo.png',
    shortcut: '/logo.png',
    apple: '/logo.png',
  },
};

const landingThemeScript = `
(function() {
  try {
    var root = document.documentElement;
    root.setAttribute('data-theme', 'light');
    root.classList.remove('dark');
    root.classList.add('light');
    root.style.colorScheme = 'light';
  } catch (e) {}
})();
`;

export default function LandingPageLayout({ children }: { children: React.ReactNode }) {
  return (
    <>
      <script dangerouslySetInnerHTML={{ __html: landingThemeScript }} />
      <link
        rel="preload"
        as="image"
        href={LANDING_IMAGES.heroMobile}
        media="(max-width: 1023px)"
        fetchPriority="high"
      />
      <link
        rel="preload"
        as="image"
        href={LANDING_IMAGES.hero}
        media="(min-width: 1024px)"
        fetchPriority="high"
      />
      <div className="ryvo-landing min-h-screen" data-theme="light">
        <LandingThemeLock />
        {children}
      </div>
    </>
  );
}
