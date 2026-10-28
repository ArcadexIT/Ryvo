import { SetMetadata } from '@nestjs/common';
import { UserRole } from '@ryvo/shared';

export const ROLES_KEY = 'roles';
export const Roles = (...roles: UserRole[]) => SetMetadata(ROLES_KEY, roles);

export const ADMIN_ROLES_KEY = 'adminRoles';
export const AdminRoles = (...roles: string[]) => SetMetadata(ADMIN_ROLES_KEY, roles);

export const Public = () => SetMetadata('isPublic', true);
