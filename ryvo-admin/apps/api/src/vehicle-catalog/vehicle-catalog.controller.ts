import { Controller, Get, Query } from '@nestjs/common';
import { ApiTags } from '@nestjs/swagger';
import { IsIn, IsString } from 'class-validator';
import { successResponse } from '../common/utils';
import { VehicleCatalogService } from './vehicle-catalog.service';

class MakesQueryDto {
  @IsIn(['car', 'motorcycle'])
  type!: string;
}

class ModelsQueryDto {
  @IsIn(['car', 'motorcycle'])
  type!: string;

  @IsString()
  make!: string;
}

@ApiTags('Vehicle Catalog')
@Controller('vehicle-catalog')
export class VehicleCatalogController {
  constructor(private catalog: VehicleCatalogService) {}

  @Get('makes')
  async makes(@Query() query: MakesQueryDto) {
    const items = await this.catalog.getMakes(query.type);
    return successResponse({ items });
  }

  @Get('models')
  async models(@Query() query: ModelsQueryDto) {
    const items = await this.catalog.getModels(query.type, query.make);
    return successResponse({ items });
  }
}
