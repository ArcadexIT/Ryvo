import type { Metadata } from 'next';
import { LandingHeader } from '@/components/landing/landing-header';
import { LandingFooter } from '@/components/landing/landing-footer';
import { LandingLegal } from '@/components/landing/landing-legal';

export const metadata: Metadata = {
  title: 'Privacy Policy | RYVO',
  description:
    'How Ryvo Ltd collects, uses, stores, discloses and protects personal information when you use the RYVO website, rider app, driver app, and related services.',
};

export default function PrivacyPolicyPage() {
  return (
    <>
      <LandingHeader />
      <LandingLegal documentKey="privacy" />
      <LandingFooter />
    </>
  );
}
