'use client';

import { useQuery } from '@tanstack/react-query';
import { apiFetch } from '@/lib/api';
import { MAP_API_KEY_SETTING } from '@/lib/settings-meta';

interface PlatformSetting {
  key: string;
  value: unknown;
}

function extractStringValue(value: unknown): string {
  if (typeof value === 'string') return value;
  if (value === null || value === undefined) return '';
  return String(value);
}

export function useMapApiKey() {
  return useQuery({
    queryKey: ['map-api-key'],
    queryFn: async () => {
      const res = await apiFetch<PlatformSetting[]>('/admin/settings');
      const setting = res.data?.find((s) => s.key === MAP_API_KEY_SETTING);
      return extractStringValue(setting?.value);
    },
    staleTime: 60_000,
  });
}
