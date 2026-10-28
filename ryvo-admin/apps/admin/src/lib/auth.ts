import { apiFetch, apiMutate } from './api';

const TOKEN_KEY = 'ryvo_admin_access_token';
const REFRESH_KEY = 'ryvo_admin_refresh_token';

export interface AuthTokens {
  accessToken: string;
  refreshToken: string;
}

export interface AdminProfile {
  id: string;
  fullName: string;
  phone: string;
  email?: string | null;
  adminRole: string;
  permissions: string[];
  totpEnabled: boolean;
  lastLoginAt?: string | null;
}

export function getAccessToken(): string | null {
  if (typeof window === 'undefined') return null;
  return localStorage.getItem(TOKEN_KEY);
}

export function getRefreshToken(): string | null {
  if (typeof window === 'undefined') return null;
  return localStorage.getItem(REFRESH_KEY);
}

export function setTokens(tokens: AuthTokens): void {
  localStorage.setItem(TOKEN_KEY, tokens.accessToken);
  localStorage.setItem(REFRESH_KEY, tokens.refreshToken);
}

export function clearTokens(): void {
  localStorage.removeItem(TOKEN_KEY);
  localStorage.removeItem(REFRESH_KEY);
}

export function isAuthenticated(): boolean {
  return !!getAccessToken();
}

export async function login(phone: string, password: string): Promise<AuthTokens> {
  const baseUrl = process.env.NEXT_PUBLIC_API_URL ?? 'http://localhost:4000/api/v1';
  const res = await fetch(`${baseUrl}/admin/auth/login`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ phone, password }),
  });

  const json = await res.json();
  if (!res.ok || !json.success) {
    throw new Error(json.message ?? 'Login failed');
  }

  const tokens = json.data as AuthTokens;
  setTokens(tokens);
  return tokens;
}

export async function fetchAdminProfile(): Promise<AdminProfile> {
  const res = await apiFetch<AdminProfile>('/admin/auth/me');
  return res.data!;
}

export async function logout(): Promise<void> {
  const refreshToken = getRefreshToken();
  try {
    if (refreshToken) {
      await apiMutate('/admin/auth/logout', 'POST', { refreshToken });
    }
  } catch {
    // proceed with local logout
  }
  clearTokens();
  if (typeof window !== 'undefined') {
    window.location.href = '/login';
  }
}
