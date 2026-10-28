'use client';

import { useEffect, useState } from 'react';
import { useRouter } from 'next/navigation';
import { Command } from 'cmdk';
import {
  Search,
  LayoutDashboard,
  Truck,
  Briefcase,
  Settings,
  ArrowRight,
} from 'lucide-react';
import { allNavItems } from '@/lib/navigation';
import { useDebounce } from '@/hooks/use-debounce';
import { apiFetch, buildQuery } from '@/lib/api';

interface CommandPaletteProps {
  open: boolean;
  onClose: () => void;
}

interface SearchResult {
  id: string;
  label: string;
  sublabel?: string;
  href: string;
  type: 'page' | 'customer' | 'provider' | 'job';
}

export function CommandPalette({ open, onClose }: CommandPaletteProps) {
  const router = useRouter();
  const [query, setQuery] = useState('');
  const debouncedQuery = useDebounce(query, 300);
  const [results, setResults] = useState<SearchResult[]>([]);
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    if (!open) {
      setQuery('');
      setResults([]);
    }
  }, [open]);

  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if (e.key === 'Escape') onClose();
    };
    if (open) window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, [open, onClose]);

  useEffect(() => {
    if (!debouncedQuery.trim()) {
      setResults([]);
      return;
    }

    const q = debouncedQuery.toLowerCase();
    const pageResults: SearchResult[] = allNavItems
      .filter(
        (item) =>
          item.label.toLowerCase().includes(q) ||
          item.keywords?.some((k) => k.includes(q)),
      )
      .map((item) => ({
        id: item.href,
        label: item.label,
        sublabel: 'Navigate',
        href: item.href,
        type: 'page' as const,
      }));

    setResults(pageResults);
    setLoading(true);

    Promise.all([
      apiFetch<{ id: string; user: { fullName: string; phone: string } }[]>(
        `/admin/providers${buildQuery({ page: 1, limit: 5, search: debouncedQuery })}`,
      ).catch(() => ({ data: [] as { id: string; user: { fullName: string; phone: string } }[] })),
      apiFetch<{ id: string; referenceNo?: string; status: string }[]>(
        `/admin/jobs${buildQuery({ page: 1, limit: 5, search: debouncedQuery })}`,
      ).catch(() => ({ data: [] as { id: string; referenceNo?: string; status: string }[] })),
    ])
      .then(([providers, jobs]) => {
        const apiResults: SearchResult[] = [
          ...(providers.data ?? []).map((p) => ({
            id: p.id,
            label: p.user.fullName,
            sublabel: p.user.phone,
            href: `/providers/${p.id}`,
            type: 'provider' as const,
          })),
          ...(jobs.data ?? []).map((j) => ({
            id: j.id,
            label: j.referenceNo ?? j.id.slice(0, 8),
            sublabel: j.status,
            href: `/jobs/${j.id}`,
            type: 'job' as const,
          })),
        ];
        setResults([...pageResults, ...apiResults]);
      })
      .finally(() => setLoading(false));
  }, [debouncedQuery]);

  function navigate(href: string) {
    router.push(href);
    onClose();
  }

  if (!open) return null;

  return (
    <div className="fixed inset-0 z-[100] flex items-start justify-center pt-[15vh]">
      <div
        className="absolute inset-0 bg-black/50 backdrop-blur-sm animate-in fade-in-0 duration-150"
        onClick={onClose}
      />
      <Command
        className="animate-in fade-in-0 zoom-in-95 relative z-10 w-full max-w-lg overflow-hidden rounded-xl border border-border bg-elevated shadow-xl duration-150"
        shouldFilter={false}
      >
        <div className="flex items-center gap-2 border-b border-border px-4">
          <Search className="h-4 w-4 shrink-0 text-muted" />
          <Command.Input
            value={query}
            onValueChange={setQuery}
            placeholder="Search pages, drivers, jobs..."
            className="flex h-12 w-full bg-transparent text-sm text-primary outline-none placeholder:text-muted"
          />
          <kbd className="hidden rounded border border-border bg-surface px-1.5 py-0.5 text-[10px] text-muted sm:inline">
            ESC
          </kbd>
        </div>
        <Command.List className="max-h-80 overflow-y-auto p-2">
          {!query && (
            <Command.Group heading="Quick navigation">
              <NavItem icon={LayoutDashboard} label="Overview" onSelect={() => navigate('/')} />
              <NavItem icon={Truck} label="Drivers" onSelect={() => navigate('/providers')} />
              <NavItem icon={Briefcase} label="Trips" onSelect={() => navigate('/jobs')} />
              <NavItem icon={Settings} label="Settings" onSelect={() => navigate('/settings')} />
            </Command.Group>
          )}
          {loading && query && (
            <div className="px-4 py-6 text-center text-sm text-muted">Searching...</div>
          )}
          {!loading && query && results.length === 0 && (
            <Command.Empty className="px-4 py-6 text-center text-sm text-muted">
              No results found.
            </Command.Empty>
          )}
          {results.length > 0 && (
            <Command.Group heading="Results">
              {results.map((r) => (
                <Command.Item
                  key={`${r.type}-${r.id}`}
                  value={r.id}
                  onSelect={() => navigate(r.href)}
                  className="flex cursor-pointer items-center gap-3 rounded-md px-3 py-2 text-sm text-primary aria-selected:bg-surface"
                >
                  <ResultIcon type={r.type} />
                  <div className="flex-1">
                    <p className="font-medium">{r.label}</p>
                    {r.sublabel && <p className="text-xs text-muted">{r.sublabel}</p>}
                  </div>
                  <ArrowRight className="h-3.5 w-3.5 text-muted" />
                </Command.Item>
              ))}
            </Command.Group>
          )}
        </Command.List>
      </Command>
    </div>
  );
}

function NavItem({
  icon: Icon,
  label,
  onSelect,
}: {
  icon: React.ComponentType<{ className?: string }>;
  label: string;
  onSelect: () => void;
}) {
  return (
    <Command.Item
      onSelect={onSelect}
      className="flex cursor-pointer items-center gap-3 rounded-md px-3 py-2 text-sm text-primary aria-selected:bg-surface"
    >
      <Icon className="h-4 w-4 text-muted" />
      {label}
    </Command.Item>
  );
}

function ResultIcon({ type }: { type: SearchResult['type'] }) {
  const icons = {
    page: LayoutDashboard,
    customer: Truck,
    provider: Truck,
    job: Briefcase,
  };
  const Icon = icons[type];
  return <Icon className="h-4 w-4 text-accent" />;
}
