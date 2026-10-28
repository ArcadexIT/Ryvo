'use client';

import { useMemo } from 'react';
import { usePathname } from 'next/navigation';
import { routeLabels } from '@/lib/navigation';

export interface BreadcrumbItem {
  label: string;
  href: string;
}

export function useBreadcrumbs(): BreadcrumbItem[] {
  const pathname = usePathname();

  return useMemo(() => {
    if (pathname === '/') {
      return [{ label: 'Overview', href: '/' }];
    }

    const segments = pathname.split('/').filter(Boolean);
    const crumbs: BreadcrumbItem[] = [{ label: 'Overview', href: '/' }];

    let path = '';
    for (const segment of segments) {
      path += `/${segment}`;
      const label = routeLabels[segment] ?? segment.charAt(0).toUpperCase() + segment.slice(1);
      crumbs.push({ label, href: path });
    }

    return crumbs;
  }, [pathname]);
}
