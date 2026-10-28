import { AdminRole } from '@ryvo/database';

export const ADMIN_MODULES = [
  'dashboard',
  'live',
  'dispatch',
  'customers',
  'providers',
  'kyc',
  'jobs',
  'finance',
  'pricing',
  'support',
  'cms',
  'reviews',
  'notifications',
  'settings',
  'countries',
  'admins',
  'roles',
  'audit',
] as const;

export type AdminModule = (typeof ADMIN_MODULES)[number];

export const DEFAULT_ROLE_PERMISSIONS: Record<AdminRole, AdminModule[]> = {
  super_admin: [...ADMIN_MODULES],
  ops: [
    'dashboard',
    'live',
    'dispatch',
    'customers',
    'providers',
    'kyc',
    'jobs',
    'support',
    'audit',
  ],
  finance: ['dashboard', 'finance', 'pricing', 'audit'],
  support: ['dashboard', 'customers', 'providers', 'jobs', 'support', 'reviews', 'audit'],
};

export function resolveAdminPermissions(
  adminRole: AdminRole,
  custom?: unknown,
  roleOverrides?: Partial<Record<AdminRole, AdminModule[]>>,
): AdminModule[] {
  if (adminRole === 'super_admin') return [...ADMIN_MODULES];
  const customPerms = Array.isArray(custom)
    ? (custom.filter((p) => ADMIN_MODULES.includes(p as AdminModule)) as AdminModule[])
    : [];
  if (customPerms.length) return customPerms;
  return roleOverrides?.[adminRole] ?? DEFAULT_ROLE_PERMISSIONS[adminRole] ?? [];
}

export function hasAdminPermission(permissions: string[], module: string): boolean {
  return permissions.includes('*') || permissions.includes(module);
}

export const ADMIN_ROLE_LABELS: Record<AdminRole, string> = {
  super_admin: 'Super Admin',
  ops: 'Operations',
  finance: 'Finance',
  support: 'Support',
};
