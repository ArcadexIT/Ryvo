'use client';

import { useQuery } from '@tanstack/react-query';
import Link from 'next/link';
import { apiFetch } from '@/lib/api';
import { Skeleton } from '@/components/ui/skeleton';
import { Timeline } from '@/components/ui/timeline';

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
    <section className="flex h-full flex-col rounded-lg border border-hairline bg-card p-4">
      <div className="mb-3 flex items-center justify-between">
        <h2 className="text-sm font-semibold text-primary">Recent activity</h2>
        <Link href="/audit" className="text-xs font-medium text-success hover:underline">
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
        <Timeline
          items={(data ?? []).map((item) => ({
            id: item.id,
            title: item.message,
            meta: timeAgo(item.timestamp),
          }))}
        />
      )}
    </section>
  );
}
