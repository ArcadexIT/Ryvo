import type { Metadata } from 'next';
import { TrackTripView } from '@/components/track/track-trip-view';

export const metadata: Metadata = {
  title: 'Follow trip · Ryvo',
  robots: { index: false, follow: false },
};

export default async function TrackTripPage({
  params,
}: {
  params: Promise<{ token: string }>;
}) {
  const { token } = await params;
  return <TrackTripView token={token} />;
}
