import {
  Controller,
  Get,
  Post,
  Body,
  Param,
  UseGuards,
  Req,
} from '@nestjs/common';
import { ApiTags, ApiBearerAuth } from '@nestjs/swagger';
import { IsString, MaxLength, MinLength } from 'class-validator';
import { JwtAuthGuard, RolesGuard } from '../auth/guards';
import { Roles } from '../auth/roles.decorator';
import { UserRole } from '@ryvo/shared';
import { successResponse } from '../common/utils';
import { ChatService } from './chat.service';

class SendMessageDto {
  @IsString() @MinLength(1) @MaxLength(2000) text!: string;
}

type AuthedReq = { user: { id: string } };

@ApiTags('Customer Chat')
@Controller('customer/jobs')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles(UserRole.CUSTOMER)
@ApiBearerAuth()
export class CustomerChatController {
  constructor(private chat: ChatService) {}

  @Get(':jobId/messages')
  async list(@Req() req: AuthedReq, @Param('jobId') jobId: string) {
    return successResponse(await this.chat.listMessages(jobId, req.user.id, 'customer'));
  }

  @Post(':jobId/messages')
  async send(
    @Req() req: AuthedReq,
    @Param('jobId') jobId: string,
    @Body() dto: SendMessageDto,
  ) {
    return successResponse(
      await this.chat.sendMessage(jobId, req.user.id, 'customer', dto.text),
    );
  }
}

@ApiTags('Provider Chat')
@Controller('provider/jobs')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles(UserRole.PROVIDER)
@ApiBearerAuth()
export class ProviderChatController {
  constructor(private chat: ChatService) {}

  @Get(':jobId/messages')
  async list(@Req() req: AuthedReq, @Param('jobId') jobId: string) {
    return successResponse(await this.chat.listMessages(jobId, req.user.id, 'provider'));
  }

  @Post(':jobId/messages')
  async send(
    @Req() req: AuthedReq,
    @Param('jobId') jobId: string,
    @Body() dto: SendMessageDto,
  ) {
    return successResponse(
      await this.chat.sendMessage(jobId, req.user.id, 'provider', dto.text),
    );
  }
}
