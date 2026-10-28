'use client';

import * as React from 'react';
import { useQuery } from '@tanstack/react-query';
import { apiFetch } from '@/lib/api';
import { getAccessToken, logout as authLogout, fetchAdminProfile, type AdminProfile } from '@/lib/auth';

interface AuthContextValue {
  user: AdminProfile | null;
  isLoading: boolean;
  permissions: string[];
  logout: () => Promise<void>;
  refetch: () => void;
}

const AuthContext = React.createContext<AuthContextValue | null>(null);

export function AuthProvider({ children }: { children: React.ReactNode }) {
  const { data, isLoading, refetch } = useQuery({
    queryKey: ['admin-me'],
    queryFn: fetchAdminProfile,
    enabled: !!getAccessToken(),
    staleTime: 5 * 60_000,
    retry: false,
  });

  const logout = React.useCallback(async () => {
    await authLogout();
  }, []);

  const value: AuthContextValue = {
    user: data ?? null,
    isLoading,
    permissions: data?.permissions ?? [],
    logout,
    refetch: () => {
      void refetch();
    },
  };

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}

export function useAuth() {
  const ctx = React.useContext(AuthContext);
  if (!ctx) throw new Error('useAuth must be used within AuthProvider');
  return ctx;
}
