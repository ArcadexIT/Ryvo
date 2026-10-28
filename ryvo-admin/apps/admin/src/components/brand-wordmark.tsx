import Image from 'next/image';
import { cn } from '@/lib/utils';

export function BrandWordmark({
  className,
  priority = false,
}: {
  className?: string;
  priority?: boolean;
}) {
  return (
    <>
      <Image
        src="/logo-wordmark.png"
        alt="Ryvo"
        width={1415}
        height={360}
        priority={priority}
        className={cn('w-auto dark:hidden', className)}
      />
      <Image
        src="/logo-wordmark-light.png"
        alt=""
        aria-hidden
        width={1415}
        height={360}
        priority={priority}
        className={cn('hidden w-auto dark:block', className)}
      />
    </>
  );
}
