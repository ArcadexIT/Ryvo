import { Controller, Get, Param, Patch, Body, Query, UseGuards, Req } from '@nestjs/common';
import { ApiTags, ApiBearerAuth } from '@nestjs/swagger';
import { CountriesService } from './countries.service';
import { JwtAuthGuard, RolesGuard } from '../auth/guards';
import { Roles } from '../auth/roles.decorator';
import { UserRole } from '@ryvo/shared';
import { successResponse } from '../common/utils';
import { PaginationDto } from '../common/dto/pagination.dto';
import { AuditService } from '../audit/audit.service';
import { IsBoolean, IsIn, IsOptional } from 'class-validator';

class CountryFiltersDto extends PaginationDto {
  @IsOptional() @IsIn(['active', 'inactive', 'all']) status?: string;
}

class SetActiveDto {
  @IsBoolean() isActive!: boolean;
}

@ApiTags('Admin Countries')
@Controller('admin/countries')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles(UserRole.ADMIN)
@ApiBearerAuth()
export class AdminCountriesController {
  constructor(
    private countries: CountriesService,
    private audit: AuditService,
  ) {}

  @Get()
  async list(@Query() query: CountryFiltersDto) {
    const result = await this.countries.findAll(query);
    return successResponse(result.items, undefined, result.meta);
  }

  @Patch(':id/active')
  async setActive(
    @Param('id') id: string,
    @Body() dto: SetActiveDto,
    @Req() req: { user: { adminUser?: { id: string } } },
  ) {
    const result = await this.countries.setActive(id, dto.isActive);
    if (req.user.adminUser) {
      await this.audit.log({
        adminId: req.user.adminUser.id,
        action: dto.isActive ? 'activate_country' : 'deactivate_country',
        entityType: 'country',
        entityId: id,
        newValues: { isActive: dto.isActive },
      });
    }
    return successResponse(result);
  }
}

@ApiTags('Public Countries')
@Controller('countries')
export class PublicCountriesController {
  constructor(private countries: CountriesService) {}

  @Get()
  async list() {
    return successResponse(await this.countries.listActive());
  }
}
