import { Controller, Get, Post, Body, Query, Param, UseGuards, Req } from '@nestjs/common';
import { ApiTags, ApiBearerAuth } from '@nestjs/swagger';
import { RatingsService } from './ratings.service';
import { JwtAuthGuard, RolesGuard } from '../auth/guards';
import { Roles } from '../auth/roles.decorator';
import { UserRole } from '@ryvo/shared';
import { successResponse } from '../common/utils';
import { PaginationDto } from '../common/dto/pagination.dto';
import { IsInt, IsOptional, IsString, IsUUID, Max, Min } from 'class-validator';

class CreateRatingDto {
  @IsUUID() jobId!: string;
  @IsInt() @Min(1) @Max(5) score!: number;
  @IsOptional() @IsString() comment?: string;
}

@ApiTags('Ratings')
@Controller()
@UseGuards(JwtAuthGuard, RolesGuard)
@ApiBearerAuth()
export class RatingsController {
  constructor(private ratings: RatingsService) {}

  @Post('customer/ratings')
  @Roles(UserRole.CUSTOMER)
  async createAsCustomer(@Req() req: { user: { id: string } }, @Body() dto: CreateRatingDto) {
    return successResponse(await this.ratings.create(req.user.id, dto));
  }

  @Post('provider/ratings')
  @Roles(UserRole.PROVIDER)
  async createAsProvider(@Req() req: { user: { id: string } }, @Body() dto: CreateRatingDto) {
    return successResponse(await this.ratings.create(req.user.id, dto));
  }

  @Get('customer/ratings')
  @Roles(UserRole.CUSTOMER)
  async listCustomer(@Req() req: { user: { id: string } }, @Query() query: PaginationDto) {
    const result = await this.ratings.getForUser(req.user.id, query);
    return successResponse(result.items, undefined, result.meta);
  }

  @Get('provider/ratings')
  @Roles(UserRole.PROVIDER)
  async listProvider(@Req() req: { user: { id: string } }, @Query() query: PaginationDto) {
    const result = await this.ratings.getForUser(req.user.id, query);
    return successResponse(result.items, undefined, result.meta);
  }

  @Get('ratings/job/:jobId')
  @Roles(UserRole.CUSTOMER, UserRole.PROVIDER, UserRole.ADMIN)
  async byJob(@Param('jobId') jobId: string) {
    return successResponse(await this.ratings.getByJob(jobId));
  }
}
