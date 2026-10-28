'use client';

import {
  AlertCircle,
  Banknote,
  CheckCircle,
  Shield,
  UserPlus,
  type LucideIcon,
} from 'lucide-react';
import { useQuery } from '@tanstack/react-query';
import Link from 'next/link';
import { apiFetch } from '@/lib/api';
import { cn } from '@/lib/utils';

interface ActivityItem {
  id: string;
  type: 'customer' | 'job' | 'payout' | 'alert' | 'admin';
  message: string;
  timestamp: string;
  href?: string;
}

const TYPE_CONFIG: Record<ActivityItem['type'], { icon: LucideIcon; color: string }> = {
  customer: { icon: UserPlus, color: 'bg-emerald-50 text-emerald-600' },
  job: { icon: CheckCircle, color: 'bg-sky-50 text-sky-600' },
  payout: { icon: Banknote, color: 'bg-violet-50 text-violet-600' },
  alert: { icon: AlertCircle, color: 'bg-rose-50 text-rose-500' },
  admin: { icon: Shield, color: 'bg-amber-50 text-amber-600' },
};

function timeAgo(value: string) {
  const seconds = Math.max(0, (Date.now() - new Date(value).getTime()) / 1000);
  if (seconds < 60) return 'just now';
  const minutes = Math.floor(seconds / 60);
  if (minutes < 60) return `${minutes}m ago`;
  const hours = Math.floor(minutes / 60);
  if (hours < 24) return `${hours}h ago`;
  return `${Math.floor(hours / 24)}d ago`;
}

export function ActivityFeed() {
  const { data, isLoading, error } = useQuery({
    queryKey: ['dashboard-activity'],
    queryFn: async () => {
      const res = await apiFetch<ActivityItem[]>('/admin/dashboard/activity?limit=6');
      return res.data ?? [];
    },
    refetchInterval: 30_000,
  });

  return (
    <section className="flex h-full flex-col rounded-2xl border border-border bg-elevated p-4 shadow-sm">
      <div className="mb-3 flex items-center justify-between">
        <h2 className="text-sm font-semibold text-primary">Recent Activity</h2>
        <Link href="/audit" className="text-xs font-medium text-[#1fa855] hover:underline">
          View all
        </Link>
      </div>
      {isLoading ? (
        <p className="text-sm text-muted">Loading activity...</p>
      ) : error ? (
        <p className="text-sm text-danger">Failed to load activity</p>
      ) : !data?.length ? (
        <p className="text-sm text-muted">No recent activity</p>
      ) : (
        <ul className="space-y-3">
          {data.map((item) => {
            const config = TYPE_CONFIG[item.type];
            const Icon = config.icon;
            const body = (
              <>
                <span className={cn('grid h-9 w-9 shrink-0 place-items-center rounded-full', config.color)}>
                  <Icon className="h-4 w-4" />
                </span>
                <span className="min-w-0">
                  <span className="block truncate text-sm font-medium text-primary">{item.message}</span>
                  <span className="block text-xs text-muted">{timeAgo(item.timestamp)}</span>
                </span>
              </>
            );
            return (
              <li key={item.id}>
                {item.href ? (
                  <Link href={item.href} className="flex items-center gap-3">
                    {body}
                  </Link>
                ) : (
                  <div className="flex items-center gap-3">{body}</div>
                )}
              </li>
            );
          })}
        </ul>
      )}
    </section>
  );
}
