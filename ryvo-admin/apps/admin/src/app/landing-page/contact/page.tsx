import type { Metadata } from 'next';
import { Suspense } from 'react';
import { LandingHeader } from '@/components/landing/landing-header';
import { LandingFooter } from '@/components/landing/landing-footer';
import { LandingContact } from '@/components/landing/landing-contact';

export const metadata: Metadata = {
  title: 'Contact & Support | RYVO',
  description:
    'Get help and support, report an issue or bug, or request deletion of your RYVO account and personal data.',
};

export default function ContactPage() {
  return (
    <>
      <LandingHeader />
      <Suspense fallback={null}>
        <LandingContact />
      </Suspense>
      <LandingFooter />
    </>
  );
}
