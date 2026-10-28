import { Injectable, CanActivate, ExecutionContext, ForbiddenException } from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { AuthGuard } from '@nestjs/passport';
import { UserRole } from '@ryvo/shared';
import { ROLES_KEY, ADMIN_ROLES_KEY } from './roles.decorator';

@Injectable()
export class JwtAuthGuard extends AuthGuard('jwt') {}

@Injectable()
export class RolesGuard implements CanActivate {
  constructor(private reflector: Reflector) {}

  canActivate(context: ExecutionContext): boolean {
    const requiredRoles = this.reflector.getAllAndOverride<UserRole[]>(ROLES_KEY, [
      context.getHandler(),
      context.getClass(),
    ]);
    if (!requiredRoles?.length) return true;

    const { user } = context.switchToHttp().getRequest();
    if (!user || !requiredRoles.some((role) => this.userHasRole(user, role))) {
      throw new ForbiddenException('Insufficient permissions');
    }
    return true;
  }

  private userHasRole(
    user: { role?: string; customer?: unknown; provider?: unknown; adminUser?: unknown },
    role: UserRole,
  ) {
    if (role === UserRole.ADMIN) return user.role === UserRole.ADMIN || !!user.adminUser;
    if (role === UserRole.CUSTOMER) return !!user.customer;
    if (role === UserRole.PROVIDER) return !!user.provider;
    return user.role === role;
  }
}

@Injectable()
export class AdminRoleGuard implements CanActivate {
  constructor(private reflector: Reflector) {}

  canActivate(context: ExecutionContext): boolean {
    const requiredAdminRoles = this.reflector.getAllAndOverride<string[]>(ADMIN_ROLES_KEY, [
      context.getHandler(),
      context.getClass(),
    ]);
    if (!requiredAdminRoles?.length) return true;

    const { user } = context.switchToHttp().getRequest();
    const adminRole = user?.adminUser?.adminRole;
    if (!adminRole) throw new ForbiddenException('Admin access required');
    if (adminRole === 'super_admin') return true;
    if (!requiredAdminRoles.includes(adminRole)) {
      throw new ForbiddenException('Insufficient admin permissions');
    }
    return true;
  }
}
