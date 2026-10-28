import { apiMutate } from './api';

/** Resolve a stored S3 fileUrl to a short-lived presigned GET URL for preview/download. */
export async function resolveFileAccessUrl(fileUrl: string): Promise<string> {
  if (!fileUrl.startsWith('http://') && !fileUrl.startsWith('https://')) {
    return fileUrl;
  }
  const res = await apiMutate<{ url: string }>('/admin/files/access-url', 'POST', { fileUrl });
  return res.data!.url;
}
