'use client';

import Image from 'next/image';
import Link from 'next/link';
import { usePathname } from 'next/navigation';
import { useQuery } from '@tanstack/react-query';
import { ChevronRight } from 'lucide-react';
import { allNavItems, navigation } from '@/lib/navigation';
import { useSidebar } from '@/contexts/sidebar-context';
import { useAuth } from '@/contexts/auth-context';
import { useIsMobile } from '@/hooks/use-media-query';
import { hasPermission } from '@/lib/permissions';
import { ADMIN_ROLE_LABELS } from '@/lib/permissions';
import { Avatar } from '@/components/ui/avatar';
import { Badge } from '@/components/ui/badge';
import {
  Tooltip,
  TooltipContent,
  TooltipProvider,
  TooltipTrigger,
} from '@/components/ui/tooltip';
import { apiFetch, buildQuery } from '@/lib/api';
import { cn } from '@/lib/utils';

function LogoMark({ collapsed }: { collapsed: boolean }) {
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
        src="/logo-wordmark-light.png"
        alt="Ryvo"
        width={1415}
        height={360}
        priority
        className="h-7 w-auto"
      />
      <span className="text-[10px] font-semibold tracking-[0.16em] text-sidebar-muted">ADMIN</span>
    </span>
  );
}

export function Sidebar() {
  const pathname = usePathname();
  const { collapsed, toggleCollapsed, mobileOpen, setMobileOpen } = useSidebar();
  const { user, permissions } = useAuth();
  const isMobile = useIsMobile();

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

  const sidebarContent = (
    <>
      <div
        className={cn(
          'flex h-[72px] items-center',
          collapsed && !isMobile ? 'justify-center px-2' : 'px-5',
        )}
      >
        <Link href="/" aria-label="Ryvo Admin" onClick={() => isMobile && setMobileOpen(false)}>
          <LogoMark collapsed={collapsed && !isMobile} />
        </Link>
      </div>

      <nav className="flex-1 overflow-y-auto px-3 py-2">
        {filteredNavigation.map((group, gi) => (
          <div key={group.title || `group-${gi}`} className={cn(gi > 0 && 'mt-5')}>
            {group.title && (!collapsed || isMobile) && (
              <p className="mb-2 px-3 text-[11px] font-semibold uppercase tracking-[0.16em] text-sidebar-muted">
                {group.title}
              </p>
            )}
            <ul className="space-y-1">
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
                      'group relative flex h-10 items-center gap-3 rounded-xl px-3 text-[13px] transition-colors duration-150',
                      active
                        ? 'bg-sidebar-active font-medium text-white'
                        : 'text-sidebar-fg hover:bg-sidebar-hover hover:text-sidebar-strong',
                      collapsed && !isMobile && 'justify-center px-2',
                    )}
                  >
                    <Icon
                      className={cn('h-[18px] w-[18px] shrink-0', active ? 'text-[#3ddc97]' : 'text-sidebar-fg')}
                      strokeWidth={active ? 2.5 : 2}
                    />
                    {(!collapsed || isMobile) && (
                      <>
                        <span className="flex-1 truncate">{item.label}</span>
                        {badge ? (
                          <Badge variant="destructive" className="h-5 min-w-5 justify-center px-1.5">
                            {badge > 99 ? '99+' : badge}
                          </Badge>
                        ) : null}
                      </>
                    )}
                    {collapsed && !isMobile && badge ? (
                      <span className="absolute right-1 top-1 h-2 w-2 rounded-full bg-danger" />
                    ) : null}
                  </Link>
                );

                if (collapsed && !isMobile) {
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

      <div className="p-3">
        <button
          type="button"
          onClick={() => !isMobile && toggleCollapsed()}
          className={cn(
            'flex w-full items-center gap-3 rounded-xl px-2 py-2 text-left transition-colors hover:bg-sidebar-hover',
            collapsed && !isMobile && 'justify-center',
          )}
        >
          <Avatar name={displayName} size="sm" className="bg-[#efe4ff] text-[#7c3aed]" />
          {(!collapsed || isMobile) && (
            <>
              <div className="min-w-0 flex-1">
                <p className="truncate text-sm font-medium text-white">{displayName}</p>
                <p className="truncate text-xs text-sidebar-muted">{displayRole}</p>
              </div>
              {!isMobile && <ChevronRight className="h-4 w-4 text-sidebar-muted" />}
            </>
          )}
        </button>
      </div>
    </>
  );

  if (isMobile) {
    return (
      <>
        {mobileOpen && (
          <div className="fixed inset-0 z-40 lg:hidden">
            <div className="absolute inset-0 bg-black/50" onClick={() => setMobileOpen(false)} />
            <aside className="absolute left-0 top-0 flex h-full w-sidebar flex-col bg-sidebar shadow-xl animate-in slide-in-from-left duration-200">
              {sidebarContent}
            </aside>
          </div>
        )}
        <MobileBottomNav isActive={isActive} />
      </>
    );
  }

  return (
    <TooltipProvider delayDuration={0}>
      <aside
        className={cn(
          'hidden h-full shrink-0 flex-col overflow-hidden bg-sidebar transition-[width] duration-200 ease-in-out lg:flex',
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
    <nav className="fixed bottom-0 left-0 right-0 z-30 flex h-14 items-center justify-around overflow-x-auto border-t border-white/10 bg-sidebar px-1 lg:hidden">
      {mobileItems.map((item) => {
        const Icon = item.icon;
        const active = isActive(item.href);
        return (
          <Link
            key={item.href}
            href={item.href}
            className={cn(
              'flex flex-col items-center gap-0.5 px-2 py-1 text-[10px]',
              active ? 'text-accent' : 'text-sidebar-fg',
            )}
          >
            <Icon className="h-5 w-5" strokeWidth={active ? 2.5 : 2} />
            <span className="truncate max-w-[56px]">{item.label.split(' ')[0]}</span>
          </Link>
        );
      })}
    </nav>
  );
}
