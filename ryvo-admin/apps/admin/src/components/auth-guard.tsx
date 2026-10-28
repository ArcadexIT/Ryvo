'use client';

import { useEffect, useState } from 'react';
import { usePathname, useRouter } from 'next/navigation';
import { isAuthenticated } from '@/lib/auth';
import { canAccessRoute } from '@/lib/permissions';
import { useAuth } from '@/contexts/auth-context';

export function AuthGuard({ children }: { children: React.ReactNode }) {
  const router = useRouter();
  const pathname = usePathname();
  const { permissions, isLoading } = useAuth();
  const [ready, setReady] = useState(false);

  useEffect(() => {
    if (!isAuthenticated()) {
      router.replace('/login');
      return;
    }
    if (isLoading) return;

    if (!canAccessRoute(permissions, pathname)) {
      router.replace('/');
      return;
    }

    setReady(true);
  }, [router, pathname, permissions, isLoading]);

  if (!ready) {
    return (
      <div className="flex h-screen items-center justify-center bg-base">
        <p className="text-sm text-muted">Checking authentication...</p>
      </div>
    );
  }

  return <>{children}</>;
}
