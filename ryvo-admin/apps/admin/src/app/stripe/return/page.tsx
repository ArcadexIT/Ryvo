import type { Metadata } from 'next';
import { StripeHandoff } from '../stripe-handoff';

export const metadata: Metadata = {
  title: 'Payout setup complete | RYVO',
  description: 'Stripe payout setup is finished. Return to the Ryvo Driver app.',
};

export default function StripeReturnPage() {
  return (
    <StripeHandoff
      title="Payout setup complete"
      body="Your Stripe details were submitted. Opening your wallet in the Ryvo Driver app."
      appLink="ryvodriver://wallet"
    />
  );
}
