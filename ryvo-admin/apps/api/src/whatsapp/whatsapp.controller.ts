import {
  Controller,
  Post,
  Req,
  Headers,
  ForbiddenException,
  BadRequestException,
  Logger,
} from '@nestjs/common';
import { ApiTags } from '@nestjs/swagger';
import { ConfigService } from '@nestjs/config';
import { Request } from 'express';
import twilio = require('twilio');
import { WhatsAppService } from './whatsapp.service';

@ApiTags('WhatsApp Webhook')
@Controller('webhooks/whatsapp')
export class WhatsAppController {
  private readonly logger = new Logger(WhatsAppController.name);

  constructor(
    private whatsapp: WhatsAppService,
    private config: ConfigService,
  ) {}

  @Post()
  async incoming(
    @Req() req: Request,
    @Headers('x-twilio-signature') signature: string | undefined,
  ) {
    const authToken = this.config.get<string>('TWILIO_AUTH_TOKEN')?.trim() ?? '';
    if (!authToken) {
      throw new BadRequestException('Twilio auth token is not configured');
    }
    if (!signature) {
      throw new ForbiddenException('Missing Twilio signature');
    }

    const protocol = (req.headers['x-forwarded-proto'] as string) || req.protocol;
    const host = req.headers['x-forwarded-host'] || req.headers.host;
    const url = `${protocol}://${host}${req.originalUrl}`;
    const params = (req.body ?? {}) as Record<string, string>;

    const valid = twilio.validateRequest(authToken, signature, url, params);
    if (!valid) {
      this.logger.warn(`Rejected WhatsApp webhook with invalid signature for ${url}`);
      throw new ForbiddenException('Invalid Twilio signature');
    }

    const from = params.From ?? params.from ?? '';
    const text = params.Body ?? params.body ?? '';
    return this.whatsapp.handleIncoming(from, text);
  }
}
