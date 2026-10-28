import { Controller, Get, Patch, Post, Param, Body, Query, UseGuards, Req } from '@nestjs/common';
import { ApiTags, ApiBearerAuth } from '@nestjs/swagger';
import { NotificationsService } from './notifications.service';
import { JwtAuthGuard, RolesGuard } from '../auth/guards';
import { Roles } from '../auth/roles.decorator';
import { UserRole } from '@ryvo/shared';
import { successResponse } from '../common/utils';
import { PaginationDto } from '../common/dto/pagination.dto';
import { IsBoolean, IsIn, IsOptional, IsString } from 'class-validator';
import { Transform } from 'class-transformer';

class NotificationQueryDto extends PaginationDto {
  @IsOptional()
  @Transform(({ value }) => value === 'true' || value === true)
  @IsBoolean()
  unreadOnly?: boolean;
}

class FcmTokenDto {
  @IsString() fcmToken!: string;

  @IsOptional()
  @IsIn(['ios', 'android'])
  platform?: 'ios' | 'android';
}

@ApiTags('Notifications')
@Controller('notifications')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles(UserRole.CUSTOMER, UserRole.PROVIDER, UserRole.ADMIN)
@ApiBearerAuth()
export class NotificationsController {
  constructor(private notifications: NotificationsService) {}

  @Get()
  async list(@Req() req: { user: { id: string } }, @Query() query: NotificationQueryDto) {
    const result = await this.notifications.list(req.user.id, query);
    return successResponse(result.items, undefined, result.meta);
  }

  @Patch(':id/read')
  async markRead(@Req() req: { user: { id: string } }, @Param('id') id: string) {
    return successResponse(await this.notifications.markRead(req.user.id, id));
  }

  @Patch('read-all')
  async markAllRead(@Req() req: { user: { id: string } }) {
    return successResponse(await this.notifications.markAllRead(req.user.id));
  }

  @Post('fcm-token')
  async registerFcm(@Req() req: { user: { id: string } }, @Body() dto: FcmTokenDto) {
    return successResponse(
      await this.notifications.registerFcmToken(req.user.id, dto.fcmToken, dto.platform),
    );
  }
}
