import type { Metadata } from 'next';
import { StripeHandoff } from '../stripe-handoff';

export const metadata: Metadata = {
  title: 'Continue payout setup | RYVO',
  description: 'The Stripe setup link expired. Continue from the Ryvo Driver app.',
};

export default function StripeRefreshPage() {
  return (
    <StripeHandoff
      title="Continue in the app"
      body="This setup link has expired. Opening the Ryvo Driver app so you can continue from your wallet."
      appLink="ryvodriver://wallet"
    />
  );
}
