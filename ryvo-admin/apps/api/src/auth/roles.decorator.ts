import { SetMetadata } from '@nestjs/common';
import { UserRole } from '@ryvo/shared';

export const ROLES_KEY = 'roles';
export const Roles = (...roles: UserRole[]) => SetMetadata(ROLES_KEY, roles);

export const ADMIN_ROLES_KEY = 'adminRoles';
export const AdminRoles = (...roles: string[]) => SetMetadata(ADMIN_ROLES_KEY, roles);

/** Module key from ADMIN_MODULES. Enforced by AdminPermissionGuard. */
export const ADMIN_MODULE_KEY = 'adminModule';
export const RequireAdminModule = (module: string) => SetMetadata(ADMIN_MODULE_KEY, module);

export const Public = () => SetMetadata('isPublic', true);
