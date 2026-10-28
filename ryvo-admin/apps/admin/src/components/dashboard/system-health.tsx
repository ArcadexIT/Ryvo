'use client';

import { useQuery } from '@tanstack/react-query';
import { Activity, CheckCircle2, Database, Radio, Server } from 'lucide-react';
import { apiFetch } from '@/lib/api';
import { cn } from '@/lib/utils';

interface HealthService {
  name: string;
  status: 'operational' | 'degraded' | 'down';
}

const ICONS: Record<string, typeof Server> = {
  API: Server,
  Database: Database,
  Redis: Radio,
  'SMS (Twilio)': Activity,
};

const ORDER = ['API', 'Database', 'Redis', 'SMS (Twilio)'];

export function SystemHealth() {
  const { data } = useQuery({
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
  const online = services.length > 0 && services.every((service) => service.status === 'operational');

  return (
    <section className="rounded-2xl bg-[#132033] p-4 text-white shadow-sm">
      <div className="flex items-start justify-between gap-3">
        <div className="flex items-center gap-2">
          <span className="grid h-8 w-8 place-items-center rounded-full bg-[#1fa855]/20 text-[#3ddc97]">
            <CheckCircle2 className="h-4 w-4" />
          </span>
          <div>
            <h2 className="text-sm font-semibold">Platform Health</h2>
            <p className="text-[11px] text-white/55">
              {online ? 'All systems operational' : 'Some systems need attention'}
            </p>
          </div>
        </div>
        <span className="rounded-full bg-[#1fa855]/15 px-2 py-0.5 text-[11px] font-medium text-[#3ddc97]">
          {online ? 'Online' : 'Check'}
        </span>
      </div>
      <ul className="mt-4 space-y-3">
        {(services.length ? services : ORDER.map((name) => ({ name, status: 'operational' as const }))).map((service) => {
          const Icon = ICONS[service.name] ?? Server;
          const ok = service.status === 'operational';
          return (
            <li key={service.name} className="flex items-center gap-3 text-sm">
              <Icon className="h-4 w-4 text-white/70" />
              <span className="flex-1 text-white/90">{service.name}</span>
              <span className={cn('text-xs font-medium', ok ? 'text-[#3ddc97]' : 'text-amber-300')}>
                {ok ? 'Operational' : service.status === 'down' ? 'Down' : 'Degraded'}
              </span>
            </li>
          );
        })}
      </ul>
    </section>
  );
}
