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

export const NAV_MODULE_MAP: Record<string, AdminModule> = {
  '/': 'dashboard',
  '/live': 'live',
  '/dispatch': 'dispatch',
  '/customers': 'customers',
  '/providers': 'providers',
  '/providers/kyc': 'kyc',
  '/jobs': 'jobs',
  '/finance/payments': 'finance',
  '/finance/wallets': 'finance',
  '/finance/earnings': 'finance',
  '/finance/payouts': 'finance',
  '/pricing/services': 'pricing',
  '/pricing/rules': 'pricing',
  '/pricing/promos': 'pricing',
  '/support': 'support',
  '/cms/banners': 'cms',
  '/cms/faqs': 'cms',
  '/cms/legal': 'cms',
  '/reviews': 'reviews',
  '/notifications': 'notifications',
  '/settings': 'settings',
  '/settings/countries': 'countries',
  '/ops/coverage': 'settings',
  '/ops/training': 'settings',
  '/ops/agreements': 'settings',
  '/admins': 'admins',
  '/roles': 'roles',
  '/audit': 'audit',
};

export const ADMIN_ROLE_LABELS: Record<string, string> = {
  super_admin: 'Super Admin',
  ops: 'Operations',
  finance: 'Finance',
  support: 'Support',
};

export function hasPermission(permissions: string[] | undefined, module: AdminModule): boolean {
  if (!permissions?.length) return true;
  return permissions.includes('*') || permissions.includes(module);
}

export function getModuleForRoute(href: string): AdminModule | undefined {
  if (NAV_MODULE_MAP[href]) return NAV_MODULE_MAP[href];
  const sorted = Object.entries(NAV_MODULE_MAP).sort((a, b) => b[0].length - a[0].length);
  for (const [path, module] of sorted) {
    if (path !== '/' && (href === path || href.startsWith(`${path}/`))) return module;
  }
  return undefined;
}

export function canAccessRoute(permissions: string[] | undefined, href: string): boolean {
  const module = getModuleForRoute(href);
  if (!module) return true;
  return hasPermission(permissions, module);
}
