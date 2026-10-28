'use client';

import Link from 'next/link';
import { Star } from 'lucide-react';
import { useQuery } from '@tanstack/react-query';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Avatar } from '@/components/ui/avatar';
import { CardSkeleton } from '@/components/ui/skeleton';
import { apiFetch } from '@/lib/api';
import { formatCurrency } from '@/lib/utils';

interface TopProvider {
  id: string;
  name: string;
  jobs: number;
  rating: number;
  earnings: number;
}

export function TopProviders() {
  const { data, isLoading, error } = useQuery({
    queryKey: ['dashboard-top-providers'],
    queryFn: async () => {
      const res = await apiFetch<TopProvider[]>('/admin/dashboard/top-providers?limit=5');
      return res.data ?? [];
    },
    refetchInterval: 120_000,
  });

  return (
    <Card className="h-full border-0">
      <CardHeader className="flex flex-row items-center justify-between">
        <CardTitle className="text-base">Top drivers</CardTitle>
        <Link href="/providers" className="text-xs text-accent hover:underline">
          View all
        </Link>
      </CardHeader>
      <CardContent>
        {isLoading ? (
          <CardSkeleton />
        ) : error ? (
          <p className="text-sm text-danger">Failed to load providers</p>
        ) : !data?.length ? (
          <p className="text-sm text-muted">No provider data yet</p>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full text-sm">
              <thead>
                <tr className="border-b border-border text-left text-xs text-muted">
                  <th className="pb-2 font-medium">Driver</th>
                  <th className="pb-2 font-medium">Rides</th>
                  <th className="pb-2 font-medium">Rating</th>
                  <th className="pb-2 text-right font-medium">Earnings</th>
                </tr>
              </thead>
              <tbody>
                {data.map((p) => (
                  <tr key={p.id} className="border-b border-border last:border-0">
                    <td className="py-2.5">
                      <Link href={`/providers/${p.id}`} className="flex items-center gap-2 hover:text-accent">
                        <Avatar name={p.name} size="sm" />
                        <span className="font-medium text-primary">{p.name}</span>
                      </Link>
                    </td>
                    <td className="py-2.5 text-secondary">{p.jobs}</td>
                    <td className="py-2.5">
                      <span className="inline-flex items-center gap-0.5 text-secondary">
                        <Star className="h-3 w-3 fill-warning text-warning" />
                        {p.rating.toFixed(1)}
                      </span>
                    </td>
                    <td className="py-2.5 text-right font-medium text-primary">
                      {formatCurrency(p.earnings)}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </CardContent>
    </Card>
  );
}
