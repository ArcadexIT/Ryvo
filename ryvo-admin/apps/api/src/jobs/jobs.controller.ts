import {
  Controller,
  Get,
  Post,
  Patch,
  Param,
  Body,
  Query,
  UseGuards,
  Req,
} from '@nestjs/common';
import { ApiTags, ApiBearerAuth } from '@nestjs/swagger';
import { JobsService } from './jobs.service';
import { JwtAuthGuard, RolesGuard } from '../auth/guards';
import { Roles } from '../auth/roles.decorator';
import { CancelledBy, UserRole } from '@ryvo/shared';
import { successResponse } from '../common/utils';
import { PaginationDto } from '../common/dto/pagination.dto';
import { AuditService } from '../audit/audit.service';
import { IsEnum, IsNumber, IsOptional, IsString, IsUUID } from 'class-validator';
import { JobStatus } from '@ryvo/database';

class JobFiltersDto extends PaginationDto {
  @IsOptional() @IsEnum(JobStatus) status?: JobStatus;
  @IsOptional() @IsUUID() customerId?: string;
  @IsOptional() @IsUUID() providerId?: string;
  @IsOptional() @IsString() from?: string;
  @IsOptional() @IsString() to?: string;
}

class UpdateStatusDto {
  @IsEnum(JobStatus) status!: JobStatus;
  @IsOptional() @IsString() note?: string;
}

class AssignProviderDto {
  @IsUUID() providerId!: string;
}

class CancelJobDto {
  @IsOptional() @IsString() reason?: string;
}

class EstimateFareDto {
  @IsUUID() serviceCategoryId!: string;
  @IsNumber() pickupLat!: number;
  @IsNumber() pickupLng!: number;
  @IsOptional() @IsNumber() dropoffLat?: number;
  @IsOptional() @IsNumber() dropoffLng?: number;
}

@ApiTags('Admin Jobs')
@Controller('admin/jobs')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles(UserRole.ADMIN)
@ApiBearerAuth()
export class JobsController {
  constructor(
    private jobs: JobsService,
    private audit: AuditService,
  ) {}

  @Get()
  async list(@Query() query: JobFiltersDto) {
    const result = await this.jobs.findAll(query);
    return successResponse(result.items, undefined, result.meta);
  }

  @Get(':id')
  async detail(@Param('id') id: string) {
    return successResponse(await this.jobs.findOne(id));
  }

  @Get(':id/timeline')
  async timeline(@Param('id') id: string) {
    return successResponse(await this.jobs.getTimeline(id));
  }

  @Get(':id/location-trail')
  async locationTrail(@Param('id') id: string) {
    return successResponse(await this.jobs.getLocationTrail(id));
  }

  @Post('estimate-fare')
  async estimateFare(@Body() dto: EstimateFareDto) {
    return successResponse(await this.jobs.estimateFare(dto));
  }

  @Patch(':id/status')
  async updateStatus(
    @Param('id') id: string,
    @Body() dto: UpdateStatusDto,
    @Req() req: { user: { adminUser?: { id: string } } },
  ) {
    const result = await this.jobs.updateStatus(id, dto.status, { type: 'admin', id: req.user.adminUser?.id }, dto.note);
    if (req.user.adminUser) {
      await this.audit.log({
        adminId: req.user.adminUser.id,
        action: 'update_job_status',
        entityType: 'job',
        entityId: id,
        newValues: { status: dto.status },
      });
    }
    return successResponse(result);
  }

  @Patch(':id/assign-provider')
  async assignProvider(
    @Param('id') id: string,
    @Body() dto: AssignProviderDto,
    @Req() req: { user: { adminUser?: { id: string } } },
  ) {
    const result = await this.jobs.assignProvider(id, dto.providerId, req.user.adminUser?.id);
    if (req.user.adminUser) {
      await this.audit.log({
        adminId: req.user.adminUser.id,
        action: 'assign_provider',
        entityType: 'job',
        entityId: id,
        newValues: dto,
      });
    }
    return successResponse(result);
  }

  @Patch(':id/cancel')
  async cancel(
    @Param('id') id: string,
    @Body() dto: CancelJobDto,
    @Req() req: { user: { adminUser?: { id: string } } },
  ) {
    const result = await this.jobs.cancelJob(id, CancelledBy.ADMIN, dto.reason, req.user.adminUser?.id);
    if (req.user.adminUser) {
      await this.audit.log({
        adminId: req.user.adminUser.id,
        action: 'cancel_job',
        entityType: 'job',
        entityId: id,
        newValues: dto,
      });
    }
    return successResponse(result);
  }
}
