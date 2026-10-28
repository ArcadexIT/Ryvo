import { LandingHeader } from '@/components/landing/landing-header';
import { LandingHero } from '@/components/landing/landing-hero';
import { LandingStats } from '@/components/landing/landing-stats';
import { LandingFeatures } from '@/components/landing/landing-features';
import { LandingAudiences } from '@/components/landing/landing-audiences';
import { LandingServices } from '@/components/landing/landing-services';
import { LandingBenefits } from '@/components/landing/landing-benefits';
import { LandingChecklist } from '@/components/landing/landing-checklist';
import { LandingTestimonials } from '@/components/landing/landing-testimonials';
import { LandingCoverage } from '@/components/landing/landing-coverage';
import { LandingFaq } from '@/components/landing/landing-faq';
import { LandingCta } from '@/components/landing/landing-cta';
import { LandingFooter } from '@/components/landing/landing-footer';

export default function LandingPage() {
  return (
    <>
      <LandingHeader variant="overlay" />
      <main>
        <LandingHero />
        <LandingStats />
        <LandingFeatures />
        <LandingAudiences />
        <LandingServices />
        <LandingBenefits />
        <LandingChecklist />
        <LandingTestimonials />
        <LandingCoverage />
        <LandingFaq />
        <LandingCta />
      </main>
      <LandingFooter />
    </>
  );
}
