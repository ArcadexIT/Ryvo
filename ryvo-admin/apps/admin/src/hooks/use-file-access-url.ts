'use client';

import { useQuery } from '@tanstack/react-query';
import { resolveFileAccessUrl } from '@/lib/files';

export function useFileAccessUrl(fileUrl?: string | null) {
  return useQuery({
    queryKey: ['file-access-url', fileUrl],
    queryFn: () => resolveFileAccessUrl(fileUrl!),
    enabled: Boolean(fileUrl),
    staleTime: 50 * 60 * 1000,
  });
}
