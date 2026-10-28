import { Controller, Post, Req } from '@nestjs/common';
import { ApiTags } from '@nestjs/swagger';
import { Request } from 'express';
import { WhatsAppService } from './whatsapp.service';

@ApiTags('WhatsApp Webhook')
@Controller('webhooks/whatsapp')
export class WhatsAppController {
  constructor(private whatsapp: WhatsAppService) {}

  @Post()
  async incoming(@Req() req: Request) {
    const body = (req.body ?? {}) as Record<string, string>;
    const from = body.From ?? body.from ?? '';
    const text = body.Body ?? body.body ?? '';
    return this.whatsapp.handleIncoming(from, text);
  }
}
