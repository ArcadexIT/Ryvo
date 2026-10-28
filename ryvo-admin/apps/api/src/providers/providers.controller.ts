import { Controller, Delete, Get, Param, Patch, Body, Query, UseGuards, Req } from '@nestjs/common';
import { ApiTags, ApiBearerAuth } from '@nestjs/swagger';
import { ProvidersService } from './providers.service';
import { JwtAuthGuard, RolesGuard } from '../auth/guards';
import { Roles } from '../auth/roles.decorator';
import { UserRole } from '@ryvo/shared';
import { successResponse } from '../common/utils';
import { PaginationDto } from '../common/dto/pagination.dto';
import { AuditService } from '../audit/audit.service';
import { IsIn, IsNumber, IsOptional, IsString, Min, Max } from 'class-validator';

class ReviewDocumentDto {
  @IsIn(['approved', 'rejected'])
  status!: 'approved' | 'rejected';
  @IsOptional() @IsString() rejectionReason?: string;
}

class CommissionDto {
  @IsNumber() @Min(0) @Max(1) commissionRate!: number;
}

class VerificationStatusDto {
  @IsIn(['pending', 'approved', 'rejected', 'suspended'])
  verificationStatus!: 'pending' | 'approved' | 'rejected' | 'suspended';
}

@ApiTags('Admin Providers')
@Controller('admin/providers')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles(UserRole.ADMIN)
@ApiBearerAuth()
export class ProvidersController {
  constructor(private providers: ProvidersService, private audit: AuditService) {}

  @Get()
  async list(@Query() query: PaginationDto & { verificationStatus?: string; onlineStatus?: string }) {
    const result = await this.providers.findAll(query);
    return successResponse(result.items, undefined, result.meta);
  }

  @Get('kyc/pending')
  async kycPending(@Query() query: PaginationDto) {
    const result = await this.providers.getKycPending(query);
    return successResponse(
      { providers: result.items, summary: result.summary },
      undefined,
      result.meta,
    );
  }

  @Get(':id')
  async detail(@Param('id') id: string) {
    return successResponse(await this.providers.findOne(id));
  }

  @Patch('documents/:docId/review')
  async reviewDocument(@Param('docId') docId: string, @Body() dto: ReviewDocumentDto, @Req() req: { user: { adminUser?: { id: string } } }) {
    const result = await this.providers.reviewDocument(docId, req.user.adminUser!.id, dto);
    await this.audit.log({ adminId: req.user.adminUser!.id, action: 'review_document', entityType: 'provider_document', entityId: docId, newValues: dto });
    return successResponse(result);
  }

  @Patch(':id/force-offline')
  async forceOffline(@Param('id') id: string, @Req() req: { user: { adminUser?: { id: string } } }) {
    const result = await this.providers.forceOffline(id);
    if (req.user.adminUser) await this.audit.log({ adminId: req.user.adminUser.id, action: 'force_offline', entityType: 'provider', entityId: id });
    return successResponse(result);
  }

  @Patch(':id/commission')
  async updateCommission(@Param('id') id: string, @Body() dto: CommissionDto, @Req() req: { user: { adminUser?: { id: string } } }) {
    const result = await this.providers.updateCommission(id, dto.commissionRate);
    if (req.user.adminUser) await this.audit.log({ adminId: req.user.adminUser.id, action: 'update_commission', entityType: 'provider', entityId: id, newValues: dto });
    return successResponse(result);
  }

  @Patch(':id/verification-status')
  async updateVerificationStatus(
    @Param('id') id: string,
    @Body() dto: VerificationStatusDto,
    @Req() req: { user: { adminUser?: { id: string } } },
  ) {
    const result = await this.providers.updateVerificationStatus(id, dto.verificationStatus);
    if (req.user.adminUser) {
      await this.audit.log({
        adminId: req.user.adminUser.id,
        action: 'update_verification_status',
        entityType: 'provider',
        entityId: id,
        newValues: dto,
      });
    }
    return successResponse(result);
  }

  @Delete(':id')
  async remove(
    @Param('id') id: string,
    @Req() req: { user: { adminUser?: { id: string } } },
  ) {
    const result = await this.providers.remove(id);
    if (req.user.adminUser) {
      await this.audit.log({
        adminId: req.user.adminUser.id,
        action: 'delete_provider',
        entityType: 'provider',
        entityId: id,
        oldValues: { fullName: result.fullName, phone: result.phone },
      });
    }
    return successResponse(result);
  }
}
