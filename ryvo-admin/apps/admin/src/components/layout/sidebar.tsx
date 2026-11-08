'use client';

import Image from 'next/image';
import Link from 'next/link';
import { usePathname } from 'next/navigation';
import { useQuery } from '@tanstack/react-query';
import { PanelLeft } from 'lucide-react';
import { allNavItems, navigation } from '@/lib/navigation';
import { useSidebar } from '@/contexts/sidebar-context';
import { useAuth } from '@/contexts/auth-context';
import { useMediaQuery } from '@/hooks/use-media-query';
import { hasPermission } from '@/lib/permissions';
import { ADMIN_ROLE_LABELS } from '@/lib/permissions';
import { Avatar } from '@/components/ui/avatar';
import { Drawer } from '@/components/ui/drawer';
import { useTheme } from '@/hooks/use-theme';
import {
  Tooltip,
  TooltipContent,
  TooltipProvider,
  TooltipTrigger,
} from '@/components/ui/tooltip';
import { apiFetch, buildQuery } from '@/lib/api';
import { cn } from '@/lib/utils';

function LogoMark({ collapsed, dark }: { collapsed: boolean; dark: boolean }) {
  if (collapsed) {
    return (
      <Image
        src="/logo-mark.png"
        alt="Ryvo"
        width={1085}
        height={895}
        priority
        className="h-8 w-auto"
      />
    );
  }

  return (
    <span className="flex min-w-0 flex-col gap-1 overflow-hidden">
      <Image
        src={dark ? '/logo-wordmark-light.png' : '/logo-wordmark.png'}
        alt="Ryvo"
        width={1415}
        height={360}
        priority
        className="h-7 w-auto"
      />
      <span className="text-[11px] font-semibold uppercase tracking-[0.16em] text-muted">Admin</span>
    </span>
  );
}

export function Sidebar() {
  const pathname = usePathname();
  const { collapsed, toggleCollapsed, mobileOpen, setMobileOpen } = useSidebar();
  const { user, permissions } = useAuth();
  const { theme } = useTheme();
  const isMobile = useMediaQuery('(max-width: 1023px)');

  const filteredNavigation = navigation
    .map((group) => ({
      ...group,
      items: group.items.filter(
        (item) => !item.module || hasPermission(permissions, item.module as import('@/lib/permissions').AdminModule),
      ),
    }))
    .filter((group) => group.items.length > 0);

  const displayName = user?.fullName ?? 'Admin';
  const displayRole = user?.adminRole
    ? (ADMIN_ROLE_LABELS[user.adminRole] ?? user.adminRole)
    : 'Admin';

  const { data: kycCount } = useQuery({
    queryKey: ['kyc-pending-count'],
    queryFn: async () => {
      const res = await apiFetch<{ summary?: { documents: number } }>(
        `/admin/providers/kyc/pending${buildQuery({ page: 1, limit: 1 })}`,
      );
      return res.data?.summary?.documents ?? res.meta?.total ?? 0;
    },
    staleTime: 15_000,
    refetchInterval: 30_000,
  });

  const canFinance = hasPermission(permissions, 'finance');
  const { data: payoutSummary } = useQuery({
    queryKey: ['finance-payouts-summary'],
    queryFn: async () => {
      const res = await apiFetch<{
        pending: { count: number; amount: number };
        processing: { count: number; amount: number };
        paid: { count: number; amount: number };
      }>('/admin/finance/payouts/summary');
      return (
        res.data ?? {
          pending: { count: 0, amount: 0 },
          processing: { count: 0, amount: 0 },
          paid: { count: 0, amount: 0 },
        }
      );
    },
    enabled: canFinance,
    staleTime: 15_000,
    refetchInterval: 30_000,
  });
  const payoutCount = payoutSummary?.pending.count ?? 0;

  const isActive = (href: string) => {
    if (href === '/') return pathname === '/';
    const matches = pathname === href || pathname.startsWith(`${href}/`);
    if (!matches) return false;
    const coveredByChild = allNavItems.some(
      (item) =>
        item.href !== href &&
        item.href.startsWith(`${href}/`) &&
        (pathname === item.href || pathname.startsWith(`${item.href}/`)),
    );
    return !coveredByChild;
  };

  const rail = collapsed && !isMobile;

  const sidebarContent = (
    <>
      <div className={cn('flex h-16 items-center', rail ? 'justify-center px-2' : 'px-4')}>
        <Link href="/" aria-label="Ryvo Admin" onClick={() => isMobile && setMobileOpen(false)}>
          <LogoMark collapsed={rail} dark={theme === 'dark'} />
        </Link>
      </div>

      <nav className="flex-1 overflow-y-auto px-3 py-2">
        {filteredNavigation.map((group, gi) => (
          <div key={group.title || `group-${gi}`} className={cn(gi > 0 && 'mt-5')}>
            {group.title && !rail && (
              <p className="mb-1 px-3 text-[11px] font-semibold uppercase tracking-[0.14em] text-muted">
                {group.title}
              </p>
            )}
            <ul className="space-y-0.5">
              {group.items.map((item) => {
                const Icon = item.icon;
                const active = isActive(item.href);
                const badge =
                  item.href === '/providers/kyc' && kycCount
                    ? kycCount
                    : item.href === '/finance/payouts' && payoutCount
                      ? payoutCount
                      : item.badge;

                const link = (
                  <Link
                    href={item.href}
                    onClick={() => isMobile && setMobileOpen(false)}
                    className={cn(
                      'relative flex h-10 items-center gap-3 rounded-full px-3 text-sm transition-colors duration-150',
                      active
                        ? 'bg-primary font-medium text-primary-fg'
                        : 'text-muted hover:bg-input hover:text-primary',
                      rail && 'justify-center px-2',
                    )}
                  >
                    <Icon className="size-4 shrink-0" strokeWidth={1.75} />
                    {!rail && (
                      <>
                        <span className="flex-1 truncate">{item.label}</span>
                        {badge ? (
                          <span
                            className={cn(
                              'num grid h-5 min-w-5 place-items-center rounded-full px-1.5 text-[11px] font-medium',
                              active ? 'bg-primary-fg/15 text-primary-fg' : 'bg-input text-primary',
                            )}
                          >
                            {badge > 99 ? '99+' : badge}
                          </span>
                        ) : null}
                      </>
                    )}
                    {rail && badge ? (
                      <span className="absolute right-1.5 top-1.5 size-1.5 rounded-full bg-warning" />
                    ) : null}
                  </Link>
                );

                if (rail) {
                  return (
                    <li key={item.href}>
                      <Tooltip delayDuration={0}>
                        <TooltipTrigger asChild>{link}</TooltipTrigger>
                        <TooltipContent side="right">
                          {badge ? `${item.label} (${badge > 99 ? '99+' : badge})` : item.label}
                        </TooltipContent>
                      </Tooltip>
                    </li>
                  );
                }

                return <li key={item.href}>{link}</li>;
              })}
            </ul>
          </div>
        ))}
      </nav>

      <div className={cn('border-t border-hairline p-3', rail && 'px-2')}>
        <div className={cn('flex items-center gap-2', rail && 'flex-col')}>
          <div className={cn('flex min-w-0 flex-1 items-center gap-2', rail && 'justify-center')}>
            <Avatar name={displayName} size="sm" />
            {!rail && (
              <div className="min-w-0">
                <p className="truncate text-sm font-medium text-primary">{displayName}</p>
                <p className="truncate text-xs text-muted">{displayRole}</p>
              </div>
            )}
          </div>
          {!isMobile && (
            <button
              type="button"
              onClick={toggleCollapsed}
              aria-label={collapsed ? 'Expand sidebar' : 'Collapse sidebar'}
              className="grid size-8 place-items-center rounded-md text-muted transition-colors duration-150 hover:bg-input hover:text-primary"
            >
              <PanelLeft className={cn('size-4', collapsed && 'rotate-180')} strokeWidth={1.75} />
            </button>
          )}
        </div>
      </div>
    </>
  );

  if (isMobile) {
    return (
      <>
        <Drawer
          open={mobileOpen}
          onClose={() => setMobileOpen(false)}
          title="Menu"
          side="left"
          hideHeader
          className="max-w-[280px]"
        >
          <div className="flex h-full flex-col">{sidebarContent}</div>
        </Drawer>
        <MobileBottomNav isActive={isActive} />
      </>
    );
  }

  return (
    <TooltipProvider delayDuration={0}>
      <aside
        className={cn(
          'hidden h-full shrink-0 flex-col overflow-hidden bg-canvas transition-[width] duration-200 ease-out lg:flex',
          collapsed ? 'w-sidebar-collapsed' : 'w-sidebar',
        )}
      >
        {sidebarContent}
      </aside>
    </TooltipProvider>
  );
}

const MOBILE_NAV_HREFS = [
  '/',
  '/dispatch',
  '/jobs',
  '/providers',
  '/finance/payments',
  '/support',
  '/notifications',
  '/settings',
];

function MobileBottomNav({
  isActive,
}: {
  isActive: (href: string) => boolean;
}) {
  const { permissions } = useAuth();
  const mobileItems = MOBILE_NAV_HREFS.map((href) => allNavItems.find((item) => item.href === href))
    .filter((item): item is (typeof allNavItems)[number] => Boolean(item))
    .filter(
      (item) => !item.module || hasPermission(permissions, item.module as import('@/lib/permissions').AdminModule),
    );

  return (
    <nav className="fixed bottom-0 left-0 right-0 z-30 flex h-14 items-center justify-around overflow-x-auto border-t border-hairline bg-sheet px-1 lg:hidden">
      {mobileItems.map((item) => {
        const Icon = item.icon;
        const active = isActive(item.href);
        return (
          <Link
            key={item.href}
            href={item.href}
            className={cn(
              'flex flex-col items-center gap-0.5 px-2 py-1 text-[11px]',
              active ? 'text-primary' : 'text-muted',
            )}
          >
            <Icon className="size-4" strokeWidth={1.75} />
            <span className="max-w-[56px] truncate">{item.label.split(' ')[0]}</span>
          </Link>
        );
      })}
    </nav>
  );
}
