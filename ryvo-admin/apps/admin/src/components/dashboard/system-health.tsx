'use client';

import { useQuery } from '@tanstack/react-query';
import { apiFetch } from '@/lib/api';
import { Skeleton } from '@/components/ui/skeleton';
import { cn } from '@/lib/utils';

interface HealthService {
  name: string;
  status: 'operational' | 'degraded' | 'down';
}

const ORDER = ['API', 'Database', 'Redis', 'SMS (Twilio)'];

export function SystemHealth() {
  const { data, isLoading, error } = useQuery({
    queryKey: ['dashboard-health'],
    queryFn: async () => {
      const res = await apiFetch<{ services: HealthService[] }>('/admin/dashboard/health');
      return res.data!;
    },
    refetchInterval: 60_000,
  });

  const services = (data?.services ?? [])
    .filter((service) => ORDER.includes(service.name))
    .sort((a, b) => ORDER.indexOf(a.name) - ORDER.indexOf(b.name));

  return (
    <section className="rounded-lg border border-hairline bg-card p-4">
      <h2 className="text-sm font-semibold text-primary">System health</h2>
      {isLoading ? (
        <div className="mt-4 space-y-3">
          {ORDER.map((name) => (
            <Skeleton key={name} className="h-5 w-full" />
          ))}
        </div>
      ) : error ? (
        <p className="mt-4 text-sm text-danger">Health data is unavailable.</p>
      ) : (
        <ul className="mt-4 space-y-3">
          {(services.length ? services : ORDER.map((name) => ({ name, status: 'operational' as const }))).map(
            (service) => (
              <li key={service.name} className="flex items-center gap-3 text-sm">
                <span
                  className={cn(
                    'size-1.5 rounded-full',
                    service.status === 'operational' && 'bg-success',
                    service.status === 'degraded' && 'bg-warning',
                    service.status === 'down' && 'bg-danger',
                  )}
                />
                <span className="flex-1 text-primary">{service.name}</span>
                <span className="text-xs capitalize text-muted">{service.status}</span>
              </li>
            ),
          )}
        </ul>
      )}
    </section>
  );
}
