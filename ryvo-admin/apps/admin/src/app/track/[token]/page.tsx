import type { Metadata } from 'next';
import { TrackTripView } from '@/components/track/track-trip-view';

export const metadata: Metadata = {
  title: 'Follow trip · Ryvo',
  robots: { index: false, follow: false },
};

export default function TrackTripPage({ params }: { params: { token: string } }) {
  return <TrackTripView token={params.token} />;
}
