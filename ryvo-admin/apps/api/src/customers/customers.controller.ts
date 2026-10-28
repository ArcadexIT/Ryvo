import { Controller, Delete, Get, Param, Patch, Body, Query, UseGuards, Req } from '@nestjs/common';
import { ApiTags, ApiBearerAuth } from '@nestjs/swagger';
import { CustomersService } from './customers.service';
import { JwtAuthGuard, RolesGuard } from '../auth/guards';
import { Roles } from '../auth/roles.decorator';
import { UserRole } from '@ryvo/shared';
import { successResponse } from '../common/utils';
import { PaginationDto } from '../common/dto/pagination.dto';
import { AuditService } from '../audit/audit.service';
import { IsIn, IsOptional, IsString } from 'class-validator';

class CustomerFiltersDto extends PaginationDto {
  @IsOptional() @IsString() status?: string;
}

class UpdateStatusDto {
  @IsIn(['active', 'suspended'])
  status!: 'active' | 'suspended';
}

@ApiTags('Admin Customers')
@Controller('admin/customers')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles(UserRole.ADMIN)
@ApiBearerAuth()
export class CustomersController {
  constructor(
    private customers: CustomersService,
    private audit: AuditService,
  ) {}

  @Get()
  async list(@Query() query: CustomerFiltersDto) {
    const result = await this.customers.findAll(query);
    return successResponse(result.items, undefined, result.meta);
  }

  @Get(':id')
  async detail(@Param('id') id: string) {
    return successResponse(await this.customers.findOne(id));
  }

  @Patch(':id/status')
  async updateStatus(
    @Param('id') id: string,
    @Body() dto: UpdateStatusDto,
    @Req() req: { user: { adminUser?: { id: string } } },
  ) {
    const result = await this.customers.updateStatus(id, dto.status);
    if (req.user.adminUser) {
      await this.audit.log({
        adminId: req.user.adminUser.id,
        action: 'update_customer_status',
        entityType: 'customer',
        entityId: id,
        newValues: { status: dto.status },
      });
    }
    return successResponse(result);
  }

  @Delete(':id')
  async remove(
    @Param('id') id: string,
    @Req() req: { user: { adminUser?: { id: string } } },
  ) {
    const result = await this.customers.remove(id);
    if (req.user.adminUser) {
      await this.audit.log({
        adminId: req.user.adminUser.id,
        action: 'delete_customer',
        entityType: 'customer',
        entityId: id,
        oldValues: { fullName: result.fullName, phone: result.phone },
      });
    }
    return successResponse(result);
  }
}
