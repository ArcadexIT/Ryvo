import { Controller, Get, Patch, Body, Param, UseGuards, Req } from '@nestjs/common';
import { ApiTags, ApiBearerAuth } from '@nestjs/swagger';
import { SettingsService } from './settings.service';
import { AdminPermissionGuard, JwtAuthGuard, RolesGuard } from '../auth/guards';
import { RequireAdminModule, Roles } from '../auth/roles.decorator';
import { UserRole } from '@ryvo/shared';
import { successResponse } from '../common/utils';
import { AuditService } from '../audit/audit.service';

@ApiTags('Admin Settings')
@Controller('admin/settings')
@UseGuards(JwtAuthGuard, RolesGuard, AdminPermissionGuard)
@Roles(UserRole.ADMIN)
@RequireAdminModule('settings')
@ApiBearerAuth()
export class SettingsController {
  constructor(
    private settings: SettingsService,
    private audit: AuditService,
  ) {}

  @Get()
  async getAll() {
    return successResponse(await this.settings.getAll());
  }

  /** Full browser key for the admin live map only. The settings list never includes it. */
  @Get('map-key')
  async mapKey() {
    const value = await this.settings.get('map_api_key');
    return successResponse(typeof value === 'string' ? value.trim() : '');
  }

  @Patch(':key')
  async update(
    @Param('key') key: string,
    @Body('value') value: unknown,
    @Req() req: { user: { id: string; adminUser?: { id: string } } },
  ) {
    const old = await this.settings.get(key);
    const result = await this.settings.set(key, value, req.user.id);
    if (req.user.adminUser) {
      await this.audit.log({
        adminId: req.user.adminUser.id,
        action: 'update_setting',
        entityType: 'platform_setting',
        entityId: key,
        oldValues: { value: this.settings.redact(key, old) },
        newValues: { value: this.settings.redact(key, value) },
      });
    }
    return successResponse({ ...result, value: this.settings.redact(key, result.value) });
  }
}
