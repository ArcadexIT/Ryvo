import type { Metadata } from 'next';
import { LandingHeader } from '@/components/landing/landing-header';
import { LandingFooter } from '@/components/landing/landing-footer';
import { LandingLegal } from '@/components/landing/landing-legal';

export const metadata: Metadata = {
  title: 'Terms and Conditions | RYVO',
  description:
    'The terms that apply when you use the RYVO website, rider app, and ride platform. This copy is a placeholder pending legal review.',
};

export default function TermsPage() {
  return (
    <>
      <LandingHeader />
      <LandingLegal documentKey="terms" />
      <LandingFooter />
    </>
  );
}
