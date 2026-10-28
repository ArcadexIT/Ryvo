import Image, { type ImageProps } from 'next/image';

/**
 * Landing photos are already resized WebP files in /public.
 * Serving them directly avoids the live image optimizer re-encoding
 * large originals on a cold start.
 */
export function LandingImage(props: ImageProps) {
  return <Image {...props} unoptimized />;
}
