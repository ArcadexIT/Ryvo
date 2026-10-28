'use client';

import { useMemo, useState } from 'react';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { Header } from '@/components/layout/header';
import { PageContent } from '@/components/layout/page-content';
import { Button } from '@/components/ui/button';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Input } from '@/components/ui/input';
import { Badge } from '@/components/ui/badge';
import { CoverageMap, type CoveragePin, type CoverageZoneShape } from '@/components/coverage-map';
import { useMapApiKey } from '@/hooks/use-map-api-key';
import { apiFetch, apiMutate } from '@/lib/api';
import { formatDate } from '@/lib/utils';
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

function toNumber(value: number | string) {
  return Number(value);
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
        description="Draw service zones for drivers. People who asked to be notified appear as pins."
      />
      <PageContent className="space-y-6">
        <div className="grid gap-6 xl:grid-cols-[minmax(0,1fr)_360px]">
          <Card className="overflow-hidden">
            <div className="h-[420px] bg-surface">
              {mapKey.data ? (
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
                <div className="flex h-full items-center justify-center px-6 text-center text-sm text-muted">
                  Add a Google Maps API key in Settings to draw coverage on the map.
                </div>
              )}
            </div>
          </Card>

          <Card>
            <CardHeader>
              <CardTitle className="text-base">{id ? 'Edit zone' : 'New zone'}</CardTitle>
            </CardHeader>
            <CardContent className="space-y-3">
              <Input placeholder="Zone name" value={name} onChange={(e) => setName(e.target.value)} />
              <select
                className="w-full rounded-md border border-border bg-surface px-3 py-2 text-sm"
                value={audience}
                onChange={() => setAudience('provider')}
              >
                <option value="provider">Drivers</option>
              </select>
              <div className="grid grid-cols-2 gap-2">
                <Input
                  type="number"
                  step="0.0001"
                  value={lat}
                  onChange={(e) => setLat(Number(e.target.value))}
                />
                <Input
                  type="number"
                  step="0.0001"
                  value={lng}
                  onChange={(e) => setLng(Number(e.target.value))}
                />
              </div>
              <Input
                type="number"
                min="0.2"
                step="0.1"
                value={radiusKm}
                onChange={(e) => setRadiusKm(Number(e.target.value))}
              />
              <label className="flex items-center gap-2 text-sm text-secondary">
                <input type="checkbox" checked={isActive} onChange={(e) => setIsActive(e.target.checked)} />
                Active
              </label>
              <div className="flex gap-2">
                <Button
                  disabled={!name || save.isPending}
                  onClick={() => save.mutate()}
                >
                  {id ? 'Save zone' : 'Create zone'}
                </Button>
                {id && (
                  <Button variant="ghost" onClick={resetForm}>
                    New
                  </Button>
                )}
              </div>
              <p className="text-xs text-muted">Click the map or drag the marker to set the zone centre.</p>
            </CardContent>
          </Card>
        </div>

        <Card>
          <CardHeader>
            <CardTitle className="text-base">Zones</CardTitle>
          </CardHeader>
          <CardContent className="space-y-2">
            {zones.length === 0 && <p className="text-sm text-muted">No coverage zones yet.</p>}
            {zones.map((zone) => (
              <button
                key={zone.id}
                type="button"
                className="flex w-full items-center justify-between rounded-md border border-border px-3 py-2 text-left hover:bg-surface"
                onClick={() => loadZone(zone)}
              >
                <div>
                  <p className="text-sm font-medium">{zone.name}</p>
                  <p className="text-xs text-muted">
                    {zone.audience} · {toNumber(zone.radiusKm)} km
                  </p>
                </div>
                <Badge variant={zone.isActive ? 'success' : 'secondary'}>
                  {zone.isActive ? 'Active' : 'Off'}
                </Badge>
              </button>
            ))}
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle className="text-base">Notify-me requests</CardTitle>
          </CardHeader>
          <CardContent className="space-y-2">
            {interests.length === 0 && (
              <p className="text-sm text-muted">No coverage interest pins yet.</p>
            )}
            {interests.map((item) => (
              <div key={item.id} className="rounded-md border border-border px-3 py-2">
                <p className="text-sm font-medium">
                  {item.user?.fullName || 'Unknown user'} · {item.user?.phone}
                </p>
                <p className="text-xs text-muted">
                  {item.addressLabel || `${toNumber(item.lat)}, ${toNumber(item.lng)}`} · {item.audience} ·{' '}
                  {item.notifiedAt ? `Notified ${formatDate(item.notifiedAt)}` : 'Waiting'}
                </p>
              </div>
            ))}
          </CardContent>
        </Card>
      </PageContent>
    </>
  );
}
