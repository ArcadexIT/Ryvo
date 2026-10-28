import {
  Controller,
  Get,
  Post,
  Patch,
  Delete,
  Param,
  Body,
  UseGuards,
  Req,
} from '@nestjs/common';
import { ApiTags, ApiBearerAuth } from '@nestjs/swagger';
import { VehiclesService } from './vehicles.service';
import { JwtAuthGuard, RolesGuard } from '../auth/guards';
import { Roles } from '../auth/roles.decorator';
import { UserRole } from '@ryvo/shared';
import { successResponse } from '../common/utils';
import {
  IsBoolean,
  IsIn,
  IsInt,
  IsNotEmpty,
  IsOptional,
  IsString,
  Max,
  MaxLength,
  Min,
} from 'class-validator';
import { Transform } from 'class-transformer';

const trimString = ({ value }: { value: unknown }) =>
  typeof value === 'string' ? value.trim() : value;

class VehicleDto {
  @IsIn(['car', 'motorcycle']) vehicleType!: string;
  @Transform(trimString) @IsString() @IsNotEmpty() @MaxLength(80) make!: string;
  @Transform(trimString) @IsString() @IsNotEmpty() @MaxLength(80) model!: string;
  @IsInt() @Min(1900) @Max(2100) year!: number;
  @Transform(trimString) @IsString() @IsNotEmpty() @MaxLength(32) plateNumber!: string;
  @IsIn(['manual', 'auto']) transmission!: string;
  @IsIn(['petrol', 'diesel', 'electric']) fuelType!: string;
  @IsOptional() @IsString() color?: string;
  @IsOptional() @IsString() engineCapacity?: string;
  @IsOptional() @IsString() photoUrl?: string;
  @IsOptional() @IsBoolean() isDefault?: boolean;
}

class UpdateVehicleDto {
  @IsOptional() @IsIn(['car', 'motorcycle']) vehicleType?: string;
  @IsOptional() @Transform(trimString) @IsString() @IsNotEmpty() @MaxLength(80) make?: string;
  @IsOptional() @Transform(trimString) @IsString() @IsNotEmpty() @MaxLength(80) model?: string;
  @IsOptional() @IsInt() @Min(1900) @Max(2100) year?: number;
  @IsOptional() @Transform(trimString) @IsString() @IsNotEmpty() @MaxLength(32) plateNumber?: string;
  @IsOptional() @IsIn(['manual', 'auto']) transmission?: string;
  @IsOptional() @IsIn(['petrol', 'diesel', 'electric']) fuelType?: string;
  @IsOptional() @IsString() color?: string;
  @IsOptional() @IsString() engineCapacity?: string;
  @IsOptional() @IsString() photoUrl?: string;
  @IsOptional() @IsBoolean() isDefault?: boolean;
}

@ApiTags('Customer Vehicles')
@Controller('customer/vehicles')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles(UserRole.CUSTOMER)
@ApiBearerAuth()
export class CustomerVehiclesController {
  constructor(private vehicles: VehiclesService) {}

  @Get()
  async list(@Req() req: { user: { customer?: { id: string } } }) {
    return successResponse(await this.vehicles.findAll(req.user.customer!.id));
  }

  @Get(':id')
  async detail(
    @Req() req: { user: { customer?: { id: string } } },
    @Param('id') id: string,
  ) {
    return successResponse(await this.vehicles.findOne(req.user.customer!.id, id));
  }

  @Post()
  async create(
    @Req() req: { user: { customer?: { id: string } } },
    @Body() dto: VehicleDto,
  ) {
    return successResponse(await this.vehicles.create(req.user.customer!.id, dto));
  }

  @Patch(':id')
  async update(
    @Req() req: { user: { customer?: { id: string } } },
    @Param('id') id: string,
    @Body() dto: UpdateVehicleDto,
  ) {
    return successResponse(await this.vehicles.update(req.user.customer!.id, id, dto));
  }

  @Delete(':id')
  async remove(
    @Req() req: { user: { customer?: { id: string } } },
    @Param('id') id: string,
  ) {
    return successResponse(await this.vehicles.remove(req.user.customer!.id, id));
  }
}
