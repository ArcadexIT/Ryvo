'use client';

import { useMemo, useState, type ReactNode } from 'react';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import {
  Bell,
  CircleDot,
  MapPin,
  Plus,
  Radar,
  Search,
  Users,
} from 'lucide-react';
import { Header } from '@/components/layout/header';
import { PageContent } from '@/components/layout/page-content';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Badge } from '@/components/ui/badge';
import { Skeleton } from '@/components/ui/skeleton';
import { SegmentedTabs } from '@/components/ui/segmented-tabs';
import { CoverageMap, type CoveragePin, type CoverageZoneShape } from '@/components/coverage-map';
import { useMapApiKey } from '@/hooks/use-map-api-key';
import { apiFetch, apiMutate } from '@/lib/api';
import { cn, formatDate } from '@/lib/utils';
import { toast } from 'sonner';

interface Zone {
  id: string;
  name: string;
  audience: 'customer' | 'provider' | 'both';
  centerLat: number | string;
  centerLng: number | string;
  radiusKm: number | string;
  isActive: boolean;
}

interface Interest {
  id: string;
  lat: number | string;
  lng: number | string;
  addressLabel?: string | null;
  audience: string;
  notifiedAt?: string | null;
  createdAt: string;
  user?: { fullName?: string; phone?: string };
}

const BIRMINGHAM = { lat: 52.4862, lng: -1.8904 };

const AUDIENCE_LABEL: Record<Zone['audience'], string> = {
  customer: 'Riders',
  provider: 'Drivers',
  both: 'Everyone',
};

function toNumber(value: number | string) {
  return Number(value);
}

function initials(name: string) {
  const parts = name.trim().split(/\s+/).slice(0, 2);
  return parts.map((part) => part[0]?.toUpperCase() ?? '').join('') || '?';
}

export default function CoveragePage() {
  const queryClient = useQueryClient();
  const mapKey = useMapApiKey();
  const [id, setId] = useState<string | undefined>(undefined);
  const [name, setName] = useState('');
  const [audience, setAudience] = useState<'provider'>('provider');
  const [lat, setLat] = useState(BIRMINGHAM.lat);
  const [lng, setLng] = useState(BIRMINGHAM.lng);
  const [radiusKm, setRadiusKm] = useState(15);
  const [isActive, setIsActive] = useState(true);
  const [focusNonce, setFocusNonce] = useState(0);
  const [panel, setPanel] = useState<'zones' | 'requests'>('zones');
  const [requestQuery, setRequestQuery] = useState('');

  const zonesQuery = useQuery({
    queryKey: ['admin-zones'],
    queryFn: async () => (await apiFetch<Zone[]>('/admin/zones')).data ?? [],
  });
  const interestsQuery = useQuery({
    queryKey: ['admin-coverage-interests'],
    queryFn: async () => (await apiFetch<Interest[]>('/admin/coverage-interests')).data ?? [],
  });

  const zones = zonesQuery.data ?? [];
  const interests = interestsQuery.data ?? [];

  const mapZones: CoverageZoneShape[] = useMemo(
    () =>
      zones.map((zone) => ({
        id: zone.id,
        name: zone.name,
        audience: zone.audience,
        centerLat: toNumber(zone.centerLat),
        centerLng: toNumber(zone.centerLng),
        radiusKm: toNumber(zone.radiusKm),
        isActive: zone.isActive,
      })),
    [zones],
  );

  const pins: CoveragePin[] = useMemo(
    () =>
      interests.map((item) => ({
        id: item.id,
        lat: toNumber(item.lat),
        lng: toNumber(item.lng),
        title: item.user?.fullName || item.addressLabel || item.user?.phone || 'Interest',
      })),
    [interests],
  );

  const activeZones = zones.filter((zone) => zone.isActive);
  const coveredKm = activeZones.reduce((sum, zone) => sum + toNumber(zone.radiusKm), 0);
  const waiting = interests.filter((item) => !item.notifiedAt).length;
  const notified = interests.length - waiting;
  const radiusMax = Math.max(80, Math.ceil(radiusKm));

  const visibleInterests = useMemo(() => {
    const query = requestQuery.trim().toLowerCase();
    if (!query) return interests;
    return interests.filter((item) => {
      const haystack = [item.user?.fullName, item.user?.phone, item.addressLabel, item.audience]
        .filter(Boolean)
        .join(' ')
        .toLowerCase();
      return haystack.includes(query);
    });
  }, [interests, requestQuery]);

  function resetForm() {
    setId(undefined);
    setName('');
    setAudience('provider');
    setLat(BIRMINGHAM.lat);
    setLng(BIRMINGHAM.lng);
    setRadiusKm(15);
    setIsActive(true);
    setFocusNonce((n) => n + 1);
  }

  function loadZone(zone: Zone) {
    setId(zone.id);
    setName(zone.name);
    setAudience('provider');
    setLat(toNumber(zone.centerLat));
    setLng(toNumber(zone.centerLng));
    setRadiusKm(toNumber(zone.radiusKm));
    setIsActive(zone.isActive);
    setFocusNonce((n) => n + 1);
    setPanel('zones');
  }

  const save = useMutation({
    mutationFn: () =>
      apiMutate('/admin/zones', 'POST', {
        id,
        name,
        audience,
        centerLat: lat,
        centerLng: lng,
        radiusKm,
        isActive,
      }),
    onSuccess: () => {
      toast.success(id ? 'Zone updated' : 'Zone created');
      queryClient.invalidateQueries({ queryKey: ['admin-zones'] });
      queryClient.invalidateQueries({ queryKey: ['admin-coverage-interests'] });
    },
    onError: (err: Error) => toast.error(err.message),
  });

  return (
    <>
      <Header
        title="Coverage"
        description="Draw driver zones. People waiting for service show up as pins."
        actions={
          id ? (
            <Button variant="outline" size="sm" onClick={resetForm}>
              <Plus className="size-4" strokeWidth={1.75} />
              New zone
            </Button>
          ) : null
        }
      />
      <PageContent className="space-y-4 pb-6">
        <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 xl:grid-cols-4">
          <Metric label="Active zones" value={activeZones.length} caption={`${zones.length} drawn`} tone="emerald" icon={CircleDot} />
          <Metric label="Radius covered" value={`${coveredKm.toFixed(0)} km`} caption="Active zones only" tone="sky" icon={Radar} />
          <Metric label="Waiting" value={waiting} caption="Notify-me requests" tone="amber" icon={Bell} />
          <Metric label="Notified" value={notified} caption={`${interests.length} requests`} tone="violet" icon={Users} />
        </div>

        <div className="grid grid-cols-1 gap-4 xl:grid-cols-12">
          <section className="panel-card relative h-[560px] overflow-hidden p-0 xl:col-span-8">
            {mapKey.isLoading ? (
              <Skeleton className="h-full w-full rounded-none" />
            ) : mapKey.data ? (
              <CoverageMap
                apiKey={mapKey.data}
                zones={mapZones}
                interests={pins}
                draft={{ lat, lng, radiusKm }}
                selectedId={id}
                focusNonce={focusNonce}
                onPick={(nextLat, nextLng) => {
                  setLat(Number(nextLat.toFixed(6)));
                  setLng(Number(nextLng.toFixed(6)));
                }}
                onSelectZone={(zoneId) => {
                  const zone = zones.find((item) => item.id === zoneId);
                  if (zone) loadZone(zone);
                }}
              />
            ) : (
              <div className="flex h-full flex-col items-center justify-center px-6 text-center">
                <span className="mb-3 grid size-11 place-items-center rounded-full bg-chart-1/15 text-chart-1">
                  <MapPin className="size-5" strokeWidth={1.75} />
                </span>
                <p className="text-sm font-medium text-primary">Map key missing</p>
                <p className="mt-1 max-w-xs text-xs text-muted">
                  Add a Google Maps API key in Settings to draw coverage on the map.
                </p>
              </div>
            )}

            <div className="pointer-events-none absolute left-3 top-3 flex flex-wrap gap-1.5">
              <LegendChip color="bg-warning" label="Draft" />
              <LegendChip color="bg-success" label="Live zone" />
              <LegendChip color="bg-danger" label="Notify-me" />
            </div>
          </section>

          <section className="panel-card flex h-auto flex-col p-4 xl:col-span-4 xl:h-[560px]">
            <div className="flex items-start justify-between gap-3">
              <div className="flex items-center gap-2">
                <span className="grid size-8 place-items-center rounded-lg bg-chart-1/15 text-chart-1">
                  <MapPin className="size-4" strokeWidth={1.75} />
                </span>
                <div>
                  <h2 className="text-sm font-semibold text-primary">{id ? 'Edit zone' : 'New zone'}</h2>
                  <p className="text-xs text-muted">
                    {id ? name || 'Selected zone' : 'Click the map or drag the marker'}
                  </p>
                </div>
              </div>
              <Badge variant={isActive ? 'success' : 'secondary'} dot>
                {isActive ? 'Active' : 'Paused'}
              </Badge>
            </div>

            <div className="mt-4 flex-1 space-y-3 overflow-y-auto">
              <Field label="Zone name">
                <Input placeholder="Birmingham centre" value={name} onChange={(e) => setName(e.target.value)} />
              </Field>

              <Field label="Who can be matched">
                <div className="flex h-9 items-center rounded-md bg-input px-3 text-sm text-primary">Drivers</div>
              </Field>

              <div className="grid grid-cols-2 gap-2">
                <Field label="Latitude">
                  <Input
                    type="number"
                    step="0.0001"
                    className="num"
                    value={lat}
                    onChange={(e) => setLat(Number(e.target.value))}
                  />
                </Field>
                <Field label="Longitude">
                  <Input
                    type="number"
                    step="0.0001"
                    className="num"
                    value={lng}
                    onChange={(e) => setLng(Number(e.target.value))}
                  />
                </Field>
              </div>

              <Field label="Radius" hint={`${radiusKm.toFixed(1)} km`}>
                <input
                  type="range"
                  min={0.5}
                  max={radiusMax}
                  step={0.5}
                  value={Math.min(radiusKm, radiusMax)}
                  onChange={(e) => setRadiusKm(Number(e.target.value))}
                  aria-label="Zone radius in kilometres"
                  className="h-1.5 w-full cursor-pointer appearance-none rounded-full bg-input accent-chart-1"
                />
                <Input
                  type="number"
                  min="0.2"
                  step="0.1"
                  className="num mt-2"
                  value={radiusKm}
                  onChange={(e) => setRadiusKm(Number(e.target.value))}
                />
              </Field>

              <Field label="Status">
                <div className="grid grid-cols-2 gap-1 rounded-lg bg-input p-1" role="group" aria-label="Zone status">
                  <button
                    type="button"
                    onClick={() => setIsActive(true)}
                    className={cn(
                      'h-8 rounded-md text-xs font-medium transition-colors',
                      isActive ? 'bg-sheet text-primary' : 'text-muted hover:text-primary',
                    )}
                  >
                    Active
                  </button>
                  <button
                    type="button"
                    onClick={() => setIsActive(false)}
                    className={cn(
                      'h-8 rounded-md text-xs font-medium transition-colors',
                      !isActive ? 'bg-sheet text-primary' : 'text-muted hover:text-primary',
                    )}
                  >
                    Paused
                  </button>
                </div>
              </Field>
            </div>

            <Button className="mt-4 w-full" disabled={!name || save.isPending} loading={save.isPending} onClick={() => save.mutate()}>
              {id ? 'Save zone' : 'Create zone'}
            </Button>
          </section>
        </div>

        <section className="panel-card p-4">
          <div className="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
            <SegmentedTabs
              value={panel}
              onChange={(value) => setPanel(value as 'zones' | 'requests')}
              items={[
                { value: 'zones', label: 'Zones', count: zones.length },
                { value: 'requests', label: 'Notify-me', count: interests.length },
              ]}
            />
            {panel === 'requests' ? (
              <div className="w-full sm:max-w-xs">
                <Input
                  value={requestQuery}
                  onChange={(e) => setRequestQuery(e.target.value)}
                  placeholder="Search name, phone, address"
                  leading={<Search strokeWidth={1.75} />}
                />
              </div>
            ) : null}
          </div>

          <div className="mt-4">
            {panel === 'zones' ? (
              zonesQuery.isLoading ? (
                <div className="space-y-2">
                  <Skeleton className="h-16 w-full rounded-xl" />
                  <Skeleton className="h-16 w-full rounded-xl" />
                </div>
              ) : zones.length === 0 ? (
                <p className="py-8 text-center text-sm text-muted">No coverage zones yet. Draw one on the map.</p>
              ) : (
                <ul className="grid gap-2 md:grid-cols-2">
                  {zones.map((zone) => {
                    const selected = zone.id === id;
                    return (
                      <li key={zone.id}>
                        <button
                          type="button"
                          onClick={() => loadZone(zone)}
                          className={cn(
                            'flex w-full items-center gap-3 rounded-xl border px-3 py-3 text-left transition-colors hover:bg-input',
                            selected ? 'border-2 border-primary bg-input' : 'border-transparent',
                          )}
                        >
                          <span
                            className={cn(
                              'grid size-10 shrink-0 place-items-center rounded-full',
                              zone.isActive ? 'bg-success/10 text-success' : 'bg-input text-muted',
                            )}
                          >
                            <CircleDot className="size-4" strokeWidth={1.75} />
                          </span>
                          <span className="min-w-0 flex-1">
                            <span className="block truncate text-sm font-semibold text-primary">{zone.name}</span>
                            <span className="mt-0.5 block text-xs text-muted">
                              {AUDIENCE_LABEL[zone.audience] ?? zone.audience}
                              <span className="num"> · {toNumber(zone.radiusKm)} km</span>
                            </span>
                          </span>
                          <Badge variant={zone.isActive ? 'success' : 'secondary'} dot>
                            {zone.isActive ? 'Active' : 'Paused'}
                          </Badge>
                        </button>
                      </li>
                    );
                  })}
                </ul>
              )
            ) : interestsQuery.isLoading ? (
              <div className="space-y-2">
                <Skeleton className="h-16 w-full rounded-xl" />
                <Skeleton className="h-16 w-full rounded-xl" />
              </div>
            ) : visibleInterests.length === 0 ? (
              <p className="py-8 text-center text-sm text-muted">
                {interests.length === 0 ? 'No coverage interest pins yet.' : 'No requests match that search.'}
              </p>
            ) : (
              <ul className="grid gap-2 md:grid-cols-2">
                {visibleInterests.map((item) => {
                  const person = item.user?.fullName || 'Unknown user';
                  const place = item.addressLabel || `${toNumber(item.lat).toFixed(4)}, ${toNumber(item.lng).toFixed(4)}`;
                  return (
                    <li key={item.id} className="flex items-center gap-3 rounded-xl px-3 py-3">
                      <span className="grid size-10 shrink-0 place-items-center rounded-full bg-chart-5/15 text-xs font-semibold text-chart-5">
                        {initials(person)}
                      </span>
                      <span className="min-w-0 flex-1">
                        <span className="block truncate text-sm font-semibold text-primary">
                          {person}
                          {item.user?.phone ? <span className="num font-normal text-muted"> · {item.user.phone}</span> : null}
                        </span>
                        <span className="mt-0.5 block truncate text-xs text-muted">
                          {place} · {item.audience}
                        </span>
                      </span>
                      <Badge variant={item.notifiedAt ? 'success' : 'warning'} dot>
                        {item.notifiedAt ? formatDate(item.notifiedAt) : 'Waiting'}
                      </Badge>
                    </li>
                  );
                })}
              </ul>
            )}
          </div>
        </section>
      </PageContent>
    </>
  );
}

function Field({ label, hint, children }: { label: string; hint?: string; children: ReactNode }) {
  return (
    <div>
      <span className="mb-1.5 flex items-baseline justify-between gap-3 text-xs font-medium text-secondary">
        {label}
        {hint ? <span className="num font-normal text-muted">{hint}</span> : null}
      </span>
      {children}
    </div>
  );
}

function LegendChip({ color, label }: { color: string; label: string }) {
  return (
    <span className="inline-flex items-center gap-1.5 rounded-full border border-hairline bg-sheet px-2.5 py-1 text-xs font-medium text-primary">
      <span className={cn('size-2 rounded-full', color)} />
      {label}
    </span>
  );
}

function Metric({
  label,
  value,
  caption,
  tone,
  icon: Icon,
}: {
  label: string;
  value: string | number;
  caption: string;
  tone: 'emerald' | 'sky' | 'violet' | 'amber';
  icon: typeof CircleDot;
}) {
  const tones = {
    emerald: { wash: 'stat-wash-emerald', ink: 'text-chart-1' },
    sky: { wash: 'stat-wash-sky', ink: 'text-chart-2' },
    violet: { wash: 'stat-wash-violet', ink: 'text-chart-4' },
    amber: { wash: 'stat-wash-amber', ink: 'text-chart-3' },
  }[tone];

  return (
    <div className={cn('flex items-center gap-3 rounded-[18px] border border-white/70 p-4', tones.wash)}>
      <span className={cn('grid size-10 shrink-0 place-items-center rounded-full bg-white/85', tones.ink)}>
        <Icon className="size-[18px]" strokeWidth={1.75} />
      </span>
      <span className="min-w-0">
        <span className="num block text-[26px] font-bold leading-none tracking-tight text-primary">{value}</span>
        <span className="mt-1 block text-xs text-muted">{label}</span>
        <span className="mt-0.5 block truncate text-[11px] text-muted">{caption}</span>
      </span>
    </div>
  );
}
