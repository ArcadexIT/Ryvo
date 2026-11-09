'use client';

import { useQuery } from '@tanstack/react-query';
import Link from 'next/link';
import { Clock, Zap } from 'lucide-react';
import { apiFetch } from '@/lib/api';
import { Skeleton } from '@/components/ui/skeleton';

interface ActivityItem {
  id: string;
  type: 'customer' | 'job' | 'payout' | 'alert' | 'admin';
  message: string;
  timestamp: string;
  href?: string;
}

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
    <section className="panel-card flex h-full flex-col p-4">
      <div className="mb-3 flex items-center justify-between">
        <h2 className="inline-flex items-center gap-2 text-sm font-semibold text-primary">
          <span className="grid size-8 place-items-center rounded-lg bg-chart-3/15 text-chart-3">
            <Zap className="size-4" strokeWidth={1.75} />
          </span>
          Recent activity
        </h2>
        <Link href="/audit" className="text-xs font-medium text-chart-1 hover:underline">
          View all
        </Link>
      </div>
      {isLoading ? (
        <div className="space-y-3">
          {Array.from({ length: 4 }).map((_, index) => (
            <Skeleton key={index} className="h-10 w-full" />
          ))}
        </div>
      ) : error ? (
        <p className="text-sm text-danger">Activity is unavailable.</p>
      ) : (
        <ul className="space-y-3">
          {(data ?? []).map((item) => (
            <li key={item.id} className="flex items-start gap-3">
              <Clock className="mt-0.5 size-4 shrink-0 text-muted" strokeWidth={1.75} />
              <div className="min-w-0">
                <p className="truncate text-sm text-primary">{item.message}</p>
                <p className="text-xs text-muted">{timeAgo(item.timestamp)}</p>
              </div>
            </li>
          ))}
        </ul>
      )}
    </section>
  );
}
