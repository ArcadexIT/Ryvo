import {
  Controller,
  Get,
  Patch,
  Post,
  Body,
  Param,
  Query,
  UseGuards,
  Req,
} from '@nestjs/common';
import { ApiTags, ApiBearerAuth } from '@nestjs/swagger';
import { IsEnum, IsNumber, IsOptional, IsString } from 'class-validator';
import { JobsService } from '../jobs/jobs.service';
import { JwtAuthGuard, RolesGuard } from '../auth/guards';
import { Roles } from '../auth/roles.decorator';
import { UserRole, JobStatus } from '@ryvo/shared';
import { successResponse } from '../common/utils';
import { PaginationDto } from '../common/dto/pagination.dto';
import { ProviderJobsService } from './provider-jobs.service';
import { JobStatus as PrismaJobStatus } from '@ryvo/database';

class UpdateJobStatusDto {
  @IsEnum(JobStatus) status!: JobStatus;
  @IsOptional() @IsNumber() lat?: number;
  @IsOptional() @IsNumber() lng?: number;
}

class CancelJobDto {
  @IsOptional() @IsString() reason?: string;
}

class ParcelPhotoDto {
  @IsString() fileUrl!: string;
}

class ParcelDeliverDto {
  @IsOptional() @IsString() fileUrl?: string;
  @IsOptional() @IsString() otp?: string;
}

type ProviderReq = { user: { id: string; provider?: { id: string } } };

@ApiTags('Provider Jobs')
@Controller('provider/jobs')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles(UserRole.PROVIDER)
@ApiBearerAuth()
export class ProviderJobsController {
  constructor(
    private jobs: ProviderJobsService,
    private coreJobs: JobsService,
  ) {}

  @Get('active')
  async active(@Req() req: ProviderReq) {
    return successResponse(await this.jobs.getActive(req.user.provider!.id));
  }

  @Get('history')
  async history(@Req() req: ProviderReq, @Query() query: PaginationDto) {
    const result = await this.jobs.getHistory(req.user.provider!.id, query);
    return successResponse(result.items, undefined, result.meta);
  }

  @Get(':id')
  async detail(@Req() req: ProviderReq, @Param('id') id: string) {
    return successResponse(await this.jobs.getOne(req.user.provider!.id, id));
  }

  @Post(':id/confirm-start')
  async confirmStart(@Req() req: ProviderReq, @Param('id') id: string) {
    return successResponse(
      await this.jobs.confirmStart(req.user.provider!.id, id),
    );
  }

  @Patch(':id/cancel')
  async cancel(
    @Req() req: ProviderReq,
    @Param('id') id: string,
    @Body() dto: CancelJobDto,
  ) {
    return successResponse(
      await this.jobs.cancelJob(req.user.provider!.id, id, dto.reason),
    );
  }

  @Post(':id/parcel/pickup-photo')
  async parcelPickupPhoto(
    @Req() req: ProviderReq,
    @Param('id') id: string,
    @Body() dto: ParcelPhotoDto,
  ) {
    return successResponse(
      await this.coreJobs.setParcelPickupPhoto(id, req.user.provider!.id, dto.fileUrl),
    );
  }

  @Post(':id/parcel/deliver')
  async parcelDeliver(
    @Req() req: ProviderReq,
    @Param('id') id: string,
    @Body() dto: ParcelDeliverDto,
  ) {
    return successResponse(
      await this.coreJobs.deliverParcel(id, req.user.provider!.id, dto),
    );
  }

  @Patch(':id/status')
  async updateStatus(
    @Req() req: ProviderReq,
    @Param('id') id: string,
    @Body() dto: UpdateJobStatusDto,
  ) {
    return successResponse(
      await this.jobs.updateStatus(
        req.user.provider!.id,
        id,
        dto.status as unknown as PrismaJobStatus,
        { lat: dto.lat, lng: dto.lng },
      ),
    );
  }
}
