'use client';

import { useQuery } from '@tanstack/react-query';
import { AuthGuard } from '@/components/auth-guard';
import { Sidebar } from '@/components/layout/sidebar';
import { Topbar } from '@/components/layout/topbar';
import { apiFetch } from '@/lib/api';
import { applyPlatformCurrency } from '@/lib/currency';
import { CURRENCY_SETTING } from '@/lib/settings-meta';

function useSyncPlatformCurrency() {
  const { data } = useQuery({
    queryKey: ['settings'],
    queryFn: async () => {
      const res = await apiFetch<{ key: string; value: unknown }[]>('/admin/settings');
      return res.data ?? [];
    },
    staleTime: 60_000,
  });
  applyPlatformCurrency(data?.find((setting) => setting.key === CURRENCY_SETTING)?.value);
}

export default function DashboardLayout({ children }: { children: React.ReactNode }) {
  useSyncPlatformCurrency();
  return (
    <AuthGuard>
      <div className="flex h-screen overflow-hidden bg-base">
        <Sidebar />
        <div className="flex min-w-0 flex-1 flex-col overflow-hidden bg-base">
          <Topbar />
          <main className="flex flex-1 flex-col overflow-hidden pb-14 lg:pb-0">{children}</main>
        </div>
      </div>
    </AuthGuard>
  );
}
