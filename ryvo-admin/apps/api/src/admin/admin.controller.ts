import {
  Controller,
  Get,
  Post,
  Patch,
  Delete,
  Param,
  Body,
  Query,
  UseGuards,
  Req,
} from '@nestjs/common';
import { ApiTags, ApiBearerAuth } from '@nestjs/swagger';
import { AdminService } from './admin.service';
import { JwtAuthGuard, RolesGuard, AdminRoleGuard } from '../auth/guards';
import { Roles, AdminRoles } from '../auth/roles.decorator';
import { UserRole } from '@ryvo/shared';
import { successResponse } from '../common/utils';
import { PaginationDto } from '../common/dto/pagination.dto';
import { AuditService } from '../audit/audit.service';
import { SubscriptionsService } from '../subscriptions/subscriptions.service';
import {
  IsEnum,
  IsIn,
  IsNumber,
  IsOptional,
  IsString,
  IsBoolean,
  Min,
} from 'class-validator';
import { AdminRole, DiscountType } from '@ryvo/database';
import type { AdminModule } from './admin-permissions';

class CreateAdminDto {
  @IsString() phone!: string;
  @IsString() fullName!: string;
  @IsOptional() @IsString() email?: string;
  @IsString() password!: string;
  @IsEnum(AdminRole) adminRole!: AdminRole;
}

class UpdateAdminDto {
  @IsOptional() @IsEnum(AdminRole) adminRole?: AdminRole;
  @IsOptional() @IsString() fullName?: string;
  @IsOptional() @IsIn(['active', 'suspended']) status?: 'active' | 'suspended';
}

class ServiceCategoryDto {
  @IsString() name!: string;
  @IsString() slug!: string;
  @IsOptional() @IsString() icon?: string;
  @IsOptional() @IsString() description?: string;
  @IsOptional() @IsIn(['taxi', 'parcel']) businessType?: 'taxi' | 'parcel';
  @IsOptional() @IsNumber() sortOrder?: number;
  @IsOptional() @IsBoolean() isActive?: boolean;
  @IsOptional() @IsNumber() @Min(0) baseFare?: number;
  @IsOptional() @IsNumber() @Min(0) perKmRate?: number;
  @IsOptional() @IsNumber() @Min(0) perMinuteRate?: number;
  @IsOptional() @IsNumber() @Min(0) minFare?: number;
}

class SubscriptionPlanDto {
  @IsOptional() @IsString() id?: string;
  @IsString() name!: string;
  @IsIn(['daily', 'weekly', 'monthly']) period!: 'daily' | 'weekly' | 'monthly';
  @IsNumber() @Min(0) price!: number;
  @IsOptional() @IsNumber() @Min(0) commissionRate?: number;
  @IsOptional() @IsBoolean() isActive?: boolean;
  @IsOptional() @IsNumber() sortOrder?: number;
}

class PricingRuleDto {
  @IsString() serviceCategoryId!: string;
  @IsNumber() @Min(0) baseFare!: number;
  @IsOptional() @IsNumber() perKmRate?: number;
  @IsOptional() @IsNumber() perMinuteRate?: number;
  @IsOptional() @IsNumber() minFare?: number;
  @IsOptional() @IsNumber() surgeMultiplier?: number;
  @IsOptional() @IsString() city?: string;
}

class PromoCodeDto {
  @IsString() code!: string;
  @IsEnum(DiscountType) discountType!: DiscountType;
  @IsNumber() @Min(0) discountValue!: number;
  @IsOptional() @IsNumber() maxUses?: number;
  @IsString() validFrom!: string;
  @IsString() validTo!: string;
}

class UpdatePromoCodeDto {
  @IsOptional() @IsNumber() @Min(0) discountValue?: number;
  @IsOptional() @IsNumber() maxUses?: number;
  @IsOptional() @IsString() validTo?: string;
  @IsOptional() @IsBoolean() isActive?: boolean;
}

class FinanceExportDto {
  @IsIn(['payments', 'earnings', 'payouts']) type!: 'payments' | 'earnings' | 'payouts';
}

class ListExportDto {
  @IsIn(['customers', 'jobs', 'support', 'audit', 'reviews', 'admins', 'promos', 'countries'])
  type!:
    | 'customers'
    | 'jobs'
    | 'support'
    | 'audit'
    | 'reviews'
    | 'admins'
    | 'promos'
    | 'countries';
  @IsOptional() @IsString() search?: string;
  @IsOptional() @IsString() status?: string;
  @IsOptional() @IsString() method?: string;
  @IsOptional() @IsString() priority?: string;
  @IsOptional() @IsString() assignedToId?: string;
  @IsOptional() @IsString() entityType?: string;
  @IsOptional() @IsString() action?: string;
  @IsOptional() @IsString() from?: string;
  @IsOptional() @IsString() to?: string;
  @IsOptional() @IsBoolean() hiddenOnly?: boolean;
}

@ApiTags('Admin Dashboard')
@Controller('admin')
@UseGuards(JwtAuthGuard, RolesGuard, AdminRoleGuard)
@Roles(UserRole.ADMIN)
@ApiBearerAuth()
export class AdminController {
  constructor(
    private admin: AdminService,
    private audit: AuditService,
    private subscriptions: SubscriptionsService,
  ) {}

  @Get('dashboard/kpis')
  async kpis() {
    return successResponse(await this.admin.getDashboardKpis());
  }

  @Get('dashboard/charts')
  async charts(@Query('days') days?: number) {
    return successResponse(await this.admin.getCharts(Number(days) || 7));
  }

  @Get('dashboard/live')
  async live() {
    return successResponse(await this.admin.getLiveSnapshot());
  }

  @Get('dashboard/activity')
  async activity(@Query('limit') limit?: number) {
    return successResponse(await this.admin.getDashboardActivity(Number(limit) || 10));
  }

  @Get('dashboard/top-providers')
  async topProviders(@Query('limit') limit?: number) {
    return successResponse(await this.admin.getTopProviders(Number(limit) || 5));
  }

  @Get('dashboard/health')
  async health() {
    return successResponse(await this.admin.getDashboardHealth());
  }

  @Get('dashboard/notifications')
  async notifications(@Query('limit') limit?: number) {
    return successResponse(await this.admin.getAdminNotifications(Number(limit) || 20));
  }

  @Get('permissions')
  @AdminRoles('super_admin')
  async permissions() {
    return successResponse(await this.admin.getPermissionsCatalog());
  }

  @Get('roles')
  @AdminRoles('super_admin')
  async roles() {
    return successResponse(await this.admin.getRoles());
  }

  @Patch('roles/:role')
  @AdminRoles('super_admin')
  async updateRole(
    @Param('role') role: AdminRole,
    @Body() body: { permissions: string[] },
    @Req() req: { user: { adminUser?: { id: string } } },
  ) {
    const result = await this.admin.updateRolePermissions(role, body.permissions as AdminModule[]);
    if (req.user.adminUser) {
      await this.audit.log({
        adminId: req.user.adminUser.id,
        action: 'update_role_permissions',
        entityType: 'admin_role',
        entityId: role,
        newValues: body,
      });
    }
    return successResponse(result);
  }

  @Get('reviews')
  async reviews(@Query() query: PaginationDto & { hiddenOnly?: string }) {
    const result = await this.admin.listReviews({
      ...query,
      hiddenOnly: query.hiddenOnly === 'true',
    });
    return successResponse(result.items, undefined, result.meta);
  }

  @Patch('reviews/:id')
  async moderateReview(
    @Param('id') id: string,
    @Body() body: { action: 'hide' | 'unhide' | 'delete' },
    @Req() req: { user: { adminUser?: { id: string } } },
  ) {
    const result = await this.admin.moderateReview(id, body.action);
    if (req.user.adminUser) {
      await this.audit.log({
        adminId: req.user.adminUser.id,
        action: `moderate_review_${body.action}`,
        entityType: 'rating',
        entityId: id,
      });
    }
    return successResponse(result);
  }

  @Get('notifications/broadcasts')
  async broadcasts(@Query() query: PaginationDto) {
    const result = await this.admin.listBroadcasts(query);
    return successResponse(result.items, undefined, result.meta);
  }

  @Post('notifications/broadcast')
  async broadcast(
    @Body() body: { title: string; body: string; audience: 'all' | 'customers' | 'providers' },
    @Req() req: { user: { adminUser?: { id: string } } },
  ) {
    const result = await this.admin.createBroadcast({
      ...body,
      createdBy: req.user.adminUser?.id,
    });
    if (req.user.adminUser) {
      await this.audit.log({
        adminId: req.user.adminUser.id,
        action: 'send_broadcast',
        entityType: 'broadcast',
        entityId: result.id,
        newValues: body,
      });
    }
    return successResponse(result);
  }

  @Get('audit-logs')
  async auditLogs(
    @Query() query: PaginationDto & { entityType?: string; action?: string; from?: string; to?: string },
  ) {
    const result = await this.admin.listAuditLogs(query);
    return successResponse(result.items, undefined, result.meta);
  }

  @Get('users')
  @AdminRoles('super_admin')
  async adminUsers(@Query() query: PaginationDto) {
    const result = await this.admin.listAdminUsers(query);
    return successResponse(result.items, undefined, result.meta);
  }

  @Post('users')
  @AdminRoles('super_admin')
  async createAdmin(
    @Body() dto: CreateAdminDto,
    @Req() req: { user: { adminUser?: { id: string } } },
  ) {
    const result = await this.admin.createAdminUser(dto);
    if (req.user.adminUser) {
      await this.audit.log({
        adminId: req.user.adminUser.id,
        action: 'create_admin_user',
        entityType: 'admin_user',
        entityId: result.id,
        newValues: { adminRole: dto.adminRole, phone: dto.phone },
      });
    }
    return successResponse(result);
  }

  @Patch('users/:id')
  @AdminRoles('super_admin')
  async updateAdmin(
    @Param('id') id: string,
    @Body() dto: UpdateAdminDto,
    @Req() req: { user: { adminUser?: { id: string } } },
  ) {
    const result = await this.admin.updateAdminUser(id, dto);
    if (req.user.adminUser) {
      await this.audit.log({
        adminId: req.user.adminUser.id,
        action: 'update_admin_user',
        entityType: 'admin_user',
        entityId: id,
        newValues: dto,
      });
    }
    return successResponse(result);
  }

  @Get('pricing/categories')
  @AdminRoles('super_admin', 'finance')
  async categories() {
    return successResponse(await this.admin.listServiceCategories());
  }

  @Post('pricing/categories')
  @AdminRoles('super_admin', 'finance')
  async createCategory(@Body() dto: ServiceCategoryDto) {
    return successResponse(await this.admin.createServiceCategory(dto));
  }

  @Patch('pricing/categories/:id')
  @AdminRoles('super_admin', 'finance')
  async updateCategory(@Param('id') id: string, @Body() dto: ServiceCategoryDto) {
    return successResponse(await this.admin.updateServiceCategory(id, dto));
  }

  @Delete('pricing/categories/:id')
  @AdminRoles('super_admin', 'finance')
  async deleteCategory(@Param('id') id: string) {
    return successResponse(await this.admin.deleteServiceCategory(id));
  }

  @Get('subscriptions/plans')
  @AdminRoles('super_admin', 'finance')
  async subscriptionPlans() {
    return successResponse(await this.subscriptions.adminListPlans());
  }

  @Post('subscriptions/plans')
  @AdminRoles('super_admin', 'finance')
  async upsertSubscriptionPlan(@Body() dto: SubscriptionPlanDto) {
    return successResponse(await this.subscriptions.upsertPlan(dto));
  }

  @Get('pricing/rules')
  @AdminRoles('super_admin', 'finance')
  async pricingRules(@Query('serviceCategoryId') serviceCategoryId?: string) {
    return successResponse(await this.admin.listPricingRules(serviceCategoryId));
  }

  @Post('pricing/rules')
  @AdminRoles('super_admin', 'finance')
  async createPricingRule(@Body() dto: PricingRuleDto) {
    return successResponse(await this.admin.createPricingRule(dto));
  }

  @Patch('pricing/rules/:id')
  @AdminRoles('super_admin', 'finance')
  async updatePricingRule(@Param('id') id: string, @Body() dto: PricingRuleDto) {
    return successResponse(await this.admin.updatePricingRule(id, dto));
  }

  @Get('pricing/promo-codes')
  @AdminRoles('super_admin', 'finance')
  async promoCodes(@Query() query: PaginationDto) {
    const result = await this.admin.listPromoCodes(query);
    return successResponse(result.items, undefined, result.meta);
  }

  @Post('pricing/promo-codes')
  @AdminRoles('super_admin', 'finance')
  async createPromoCode(@Body() dto: PromoCodeDto) {
    return successResponse(await this.admin.createPromoCode(dto));
  }

  @Patch('pricing/promo-codes/:id')
  @AdminRoles('super_admin', 'finance')
  async updatePromoCode(@Param('id') id: string, @Body() dto: UpdatePromoCodeDto) {
    return successResponse(await this.admin.updatePromoCode(id, dto));
  }

  @Get('finance/payments')
  @AdminRoles('super_admin', 'finance')
  async payments(@Query() query: PaginationDto) {
    const result = await this.admin.listPayments(query);
    return successResponse(result.items, undefined, result.meta);
  }

  @Get('finance/earnings')
  @AdminRoles('super_admin', 'finance')
  async earnings(@Query() query: PaginationDto & { providerId?: string }) {
    const result = await this.admin.listEarnings(query);
    return successResponse(result.items, undefined, result.meta);
  }

  @Get('finance/payouts')
  @AdminRoles('super_admin', 'finance')
  async payouts(@Query() query: PaginationDto & { providerId?: string; status?: string }) {
    const result = await this.admin.listPayouts(query);
    return successResponse(result.items, undefined, result.meta);
  }

  @Get('finance/payouts/summary')
  @AdminRoles('super_admin', 'finance')
  async payoutSummary() {
    return successResponse(await this.admin.getPayoutSummary());
  }

  @Patch('finance/payouts/:id/process')
  @AdminRoles('super_admin', 'finance')
  async processPayout(
    @Param('id') id: string,
    @Req() req: { user: { adminUser?: { id: string } } },
  ) {
    const result = await this.admin.processPayout(id);
    if (req.user.adminUser) {
      await this.audit.log({
        adminId: req.user.adminUser.id,
        action: 'process_payout',
        entityType: 'payout',
        entityId: id,
      });
    }
    return successResponse(result);
  }

  @Patch('finance/payouts/:id/reject')
  @AdminRoles('super_admin', 'finance')
  async rejectPayout(@Param('id') id: string) {
    return successResponse(await this.admin.rejectPayout(id));
  }

  @Post('finance/export')
  @AdminRoles('super_admin', 'finance')
  async exportFinance(@Body() dto: FinanceExportDto) {
    return successResponse(await this.admin.exportFinanceCsv(dto.type));
  }

  @Post('export/list')
  async exportList(@Body() dto: ListExportDto) {
    const { type, ...filters } = dto;
    return successResponse(await this.admin.exportListCsv(type, filters));
  }
}
