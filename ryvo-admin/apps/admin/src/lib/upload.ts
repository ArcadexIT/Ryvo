import { ApiError, getApiBaseUrl, type ApiResponse } from './api';
import { getAccessToken } from './auth';

export async function uploadAdminFile(file: File, folder: string): Promise<string> {
  const form = new FormData();
  form.append('folder', folder);
  form.append('file', file);
  const token = getAccessToken();
  const res = await fetch(`${getApiBaseUrl()}/admin/files/upload`, {
    method: 'POST',
    headers: token ? { Authorization: `Bearer ${token}` } : {},
    body: form,
  });
  const json = (await res.json()) as ApiResponse<{ fileUrl: string }>;
  if (!res.ok || !json.success || !json.data?.fileUrl) {
    throw new ApiError(json.message ?? 'File upload failed', res.status);
  }
  return json.data.fileUrl;
}
