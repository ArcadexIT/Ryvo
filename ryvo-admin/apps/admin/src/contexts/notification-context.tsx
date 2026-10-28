'use client';

import * as React from 'react';
import { useQuery } from '@tanstack/react-query';
import { apiFetch } from '@/lib/api';
import { getAccessToken } from '@/lib/auth';

export interface Notification {
  id: string;
  title: string;
  message: string;
  type: 'info' | 'warning' | 'error' | 'success';
  timestamp: Date;
  read: boolean;
  href?: string;
}

interface ApiNotification {
  id: string;
  title: string;
  message: string;
  type: 'info' | 'warning' | 'error' | 'success';
  timestamp: string;
  href?: string;
}

interface NotificationContextValue {
  notifications: Notification[];
  unreadCount: number;
  markAsRead: (id: string) => void;
  markAllAsRead: () => void;
}

const NotificationContext = React.createContext<NotificationContextValue | null>(null);

export function NotificationProvider({ children }: { children: React.ReactNode }) {
  const [readIds, setReadIds] = React.useState<Set<string>>(new Set());

  const { data } = useQuery({
    queryKey: ['admin-notifications'],
    queryFn: async () => {
      const res = await apiFetch<ApiNotification[]>('/admin/dashboard/notifications?limit=20');
      return res.data ?? [];
    },
    enabled: !!getAccessToken(),
    refetchInterval: 30_000,
    refetchOnWindowFocus: true,
  });

  const notifications: Notification[] = React.useMemo(
    () =>
      (data ?? []).map((n) => ({
        ...n,
        timestamp: new Date(n.timestamp),
        read: readIds.has(n.id),
      })),
    [data, readIds],
  );

  const unreadCount = notifications.filter((n) => !n.read).length;

  const markAsRead = React.useCallback((id: string) => {
    setReadIds((prev) => new Set(prev).add(id));
  }, []);

  const markAllAsRead = React.useCallback(() => {
    setReadIds(new Set((data ?? []).map((n) => n.id)));
  }, [data]);

  return (
    <NotificationContext.Provider
      value={{ notifications, unreadCount, markAsRead, markAllAsRead }}
    >
      {children}
    </NotificationContext.Provider>
  );
}

export function useNotifications() {
  const ctx = React.useContext(NotificationContext);
  if (!ctx) throw new Error('useNotifications must be used within NotificationProvider');
  return ctx;
}
