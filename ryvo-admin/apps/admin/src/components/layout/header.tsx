'use client';

import { useEffect, useRef, useState } from 'react';
import { Breadcrumb } from '@/components/layout/breadcrumb';
import { useBreadcrumbs } from '@/hooks/use-breadcrumbs';
import { cn } from '@/lib/utils';

interface HeaderProps {
  title: string;
  description?: string;
  actions?: React.ReactNode;
  breadcrumb?: boolean;
}

export function Header({ title, description, actions, breadcrumb = true }: HeaderProps) {
  const ref = useRef<HTMLDivElement>(null);
  const [scrolled, setScrolled] = useState(false);
  const crumbs = useBreadcrumbs();
  const showCrumb = breadcrumb && crumbs.length > 1;

  useEffect(() => {
    const scroller = ref.current?.nextElementSibling;
    if (!scroller) return;
    const onScroll = () => setScrolled(scroller.scrollTop > 4);
    scroller.addEventListener('scroll', onScroll, { passive: true });
    return () => scroller.removeEventListener('scroll', onScroll);
  }, []);

  return (
    <div
      ref={ref}
      className={cn(
        'sticky top-0 z-20 shrink-0 bg-sheet px-5 py-4 transition-colors duration-150',
        scrolled && 'border-b border-hairline',
      )}
    >
      {showCrumb ? <Breadcrumb className="mb-2 text-xs" /> : null}
      <div className="flex items-start justify-between gap-4">
        <div className="min-w-0">
          <h1 className="page-title truncate">{title}</h1>
          {description ? <p className="mt-1 truncate text-sm text-muted">{description}</p> : null}
        </div>
        {actions ? <div className="flex shrink-0 items-center gap-2">{actions}</div> : null}
      </div>
    </div>
  );
}
