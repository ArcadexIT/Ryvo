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
import { SupportService } from './support.service';
import { JwtAuthGuard, RolesGuard } from '../auth/guards';
import { Roles } from '../auth/roles.decorator';
import { UserRole } from '@ryvo/shared';
import { successResponse } from '../common/utils';
import { PaginationDto } from '../common/dto/pagination.dto';
import { AuditService } from '../audit/audit.service';
import {
  IsEnum,
  IsOptional,
  IsString,
  IsUUID,
} from 'class-validator';
import { SupportPriority, SupportTicketStatus } from '@ryvo/database';

class TicketFiltersDto extends PaginationDto {
  @IsOptional() @IsEnum(SupportTicketStatus) status?: SupportTicketStatus;
  @IsOptional() @IsEnum(SupportPriority) priority?: SupportPriority;
  @IsOptional() @IsUUID() assignedToId?: string;
}

class CreateTicketDto {
  @IsString() category!: string;
  @IsString() subject!: string;
  @IsString() message!: string;
  @IsOptional() @IsUUID() jobId?: string;
  @IsOptional() @IsEnum(SupportPriority) priority?: SupportPriority;
}

class AddMessageDto {
  @IsString() message!: string;
  @IsOptional() @IsString() attachmentUrl?: string;
}

class AssignTicketDto {
  @IsUUID() adminUserId!: string;
}

class UpdateTicketStatusDto {
  @IsEnum(SupportTicketStatus) status!: SupportTicketStatus;
}

class UpdateTicketPriorityDto {
  @IsEnum(SupportPriority) priority!: SupportPriority;
}

@ApiTags('Admin Support')
@Controller('admin/support/tickets')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles(UserRole.ADMIN)
@ApiBearerAuth()
export class AdminSupportController {
  constructor(
    private support: SupportService,
    private audit: AuditService,
  ) {}

  @Get()
  async list(@Query() query: TicketFiltersDto) {
    const result = await this.support.findAll(query);
    return successResponse(result.items, undefined, result.meta);
  }

  @Get(':id')
  async detail(@Param('id') id: string) {
    return successResponse(await this.support.findOne(id));
  }

  @Patch(':id/assign')
  async assign(
    @Param('id') id: string,
    @Body() dto: AssignTicketDto,
    @Req() req: { user: { adminUser?: { id: string } } },
  ) {
    const result = await this.support.assign(id, dto.adminUserId);
    if (req.user.adminUser) {
      await this.audit.log({
        adminId: req.user.adminUser.id,
        action: 'assign_ticket',
        entityType: 'support_ticket',
        entityId: id,
        newValues: dto,
      });
    }
    return successResponse(result);
  }

  @Patch(':id/unassign')
  async unassign(
    @Param('id') id: string,
    @Req() req: { user: { adminUser?: { id: string } } },
  ) {
    const result = await this.support.unassign(id);
    if (req.user.adminUser) {
      await this.audit.log({
        adminId: req.user.adminUser.id,
        action: 'unassign_ticket',
        entityType: 'support_ticket',
        entityId: id,
      });
    }
    return successResponse(result);
  }

  @Patch(':id/status')
  async updateStatus(
    @Param('id') id: string,
    @Body() dto: UpdateTicketStatusDto,
    @Req() req: { user: { adminUser?: { id: string } } },
  ) {
    const result = await this.support.updateStatus(id, dto.status);
    if (req.user.adminUser) {
      await this.audit.log({
        adminId: req.user.adminUser.id,
        action: 'update_ticket_status',
        entityType: 'support_ticket',
        entityId: id,
        newValues: dto,
      });
    }
    return successResponse(result);
  }

  @Patch(':id/priority')
  async updatePriority(
    @Param('id') id: string,
    @Body() dto: UpdateTicketPriorityDto,
    @Req() req: { user: { adminUser?: { id: string } } },
  ) {
    const result = await this.support.updatePriority(id, dto.priority);
    if (req.user.adminUser) {
      await this.audit.log({
        adminId: req.user.adminUser.id,
        action: 'update_ticket_priority',
        entityType: 'support_ticket',
        entityId: id,
        newValues: dto,
      });
    }
    return successResponse(result);
  }

  @Post(':id/messages')
  async addMessage(
    @Param('id') id: string,
    @Body() dto: AddMessageDto,
    @Req() req: { user: { id: string } },
  ) {
    return successResponse(
      await this.support.addMessage(id, req.user.id, 'admin', dto.message, dto.attachmentUrl),
    );
  }
}

@ApiTags('User Support')
@Controller('support/tickets')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles(UserRole.CUSTOMER, UserRole.PROVIDER)
@ApiBearerAuth()
export class UserSupportController {
  constructor(private support: SupportService) {}

  @Get()
  async list(@Req() req: { user: { id: string } }, @Query() query: PaginationDto) {
    const result = await this.support.findByUser(req.user.id, query);
    return successResponse(result.items, undefined, result.meta);
  }

  @Get(':id')
  async detail(@Req() req: { user: { id: string } }, @Param('id') id: string) {
    return successResponse(await this.support.findOne(id, req.user.id));
  }

  @Post()
  async create(
    @Req() req: { user: { id: string; role: string } },
    @Body() dto: CreateTicketDto,
  ) {
    return successResponse(
      await this.support.create(req.user.id, dto, req.user.role),
    );
  }

  @Post(':id/messages')
  async addMessage(
    @Req() req: { user: { id: string; role: string } },
    @Param('id') id: string,
    @Body() dto: AddMessageDto,
  ) {
    return successResponse(
      await this.support.addMessage(
        id,
        req.user.id,
        req.user.role,
        dto.message,
        dto.attachmentUrl,
        req.user.id,
      ),
    );
  }
}
