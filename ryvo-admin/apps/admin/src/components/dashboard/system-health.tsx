'use client';

import { useQuery } from '@tanstack/react-query';
import { Shield } from 'lucide-react';
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
    <section className="panel-card p-4">
      <h2 className="inline-flex items-center gap-2 text-sm font-semibold text-primary">
        <span className="grid size-8 place-items-center rounded-lg bg-chart-1/15 text-chart-1">
          <Shield className="size-4" strokeWidth={1.75} />
        </span>
        System health
      </h2>
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
                <span
                  className={cn(
                    'rounded-full border px-2 py-0.5 text-[11px] font-medium capitalize',
                    service.status === 'operational' && 'border-success/40 text-success',
                    service.status === 'degraded' && 'border-warning/50 text-warning',
                    service.status === 'down' && 'border-danger/40 text-danger',
                  )}
                >
                  {service.status}
                </span>
              </li>
            ),
          )}
        </ul>
      )}
    </section>
  );
}
