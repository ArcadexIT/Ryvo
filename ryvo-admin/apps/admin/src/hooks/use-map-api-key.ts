'use client';

import { useQuery } from '@tanstack/react-query';
import { apiFetch } from '@/lib/api';

function extractStringValue(value: unknown): string {
  if (typeof value === 'string') return value;
  if (value === null || value === undefined) return '';
  return String(value);
}

export function useMapApiKey() {
  return useQuery({
    queryKey: ['map-api-key'],
    queryFn: async () => {
      const res = await apiFetch<string>('/admin/settings/map-key');
      return extractStringValue(res.data);
    },
    staleTime: 60_000,
  });
}
