import { Injectable, Logger, OnModuleInit } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import twilio = require('twilio');

const OTP_PURPOSE_LABELS: Record<string, string> = {
  register: 'verification',
  reset_password: 'password reset',
  login: 'login',
};

@Injectable()
export class SmsService implements OnModuleInit {
  private readonly logger = new Logger(SmsService.name);
  private client: ReturnType<typeof twilio> | null = null;
  private fromNumber = '';
  private messagingServiceSid = '';
  private whatsappFrom = '';

  constructor(private config: ConfigService) {}

  onModuleInit() {
    const accountSid = this.config.get<string>('TWILIO_ACCOUNT_SID')?.trim();
    const authToken = this.config.get<string>('TWILIO_AUTH_TOKEN')?.trim();
    const fromNumber = this.config.get<string>('TWILIO_PHONE_NUMBER')?.trim() ?? '';
    const messagingServiceSid = this.config.get<string>('TWILIO_MESSAGING_SERVICE_SID')?.trim() ?? '';

    if (!accountSid || !authToken) {
      this.logger.warn(
        'SMS disabled — set TWILIO_ACCOUNT_SID and TWILIO_AUTH_TOKEN in .env to enable Twilio OTP',
      );
      return;
    }

    if (!fromNumber && !messagingServiceSid) {
      this.logger.warn(
        'SMS disabled — set TWILIO_PHONE_NUMBER or TWILIO_MESSAGING_SERVICE_SID in .env',
      );
      return;
    }

    this.client = twilio(accountSid, authToken);
    this.fromNumber = fromNumber;
    this.messagingServiceSid = messagingServiceSid;
    this.whatsappFrom = this.config.get<string>('TWILIO_WHATSAPP_FROM')?.trim() ?? '';
    this.logger.log(
      `SMS enabled (Twilio${messagingServiceSid ? `, messaging service ${messagingServiceSid}` : `, from ${fromNumber}`}${this.whatsappFrom ? `, WhatsApp ${this.whatsappFrom}` : ''})`,
    );
  }

  get enabled(): boolean {
    return this.client != null;
  }

  get whatsappEnabled(): boolean {
    return this.client != null && !!this.whatsappFrom;
  }

  async sendOtp(phone: string, code: string, purpose: string): Promise<void> {
    if (!this.client) {
      throw new Error('Twilio SMS is not configured');
    }

    const label = OTP_PURPOSE_LABELS[purpose] ?? 'verification';
    const body = `Your Ryvo ${label} code is: ${code}. Valid for 5 minutes. Do not share this code.`;

    try {
      await this.client.messages.create({
        body,
        to: phone,
        ...(this.messagingServiceSid
          ? { messagingServiceSid: this.messagingServiceSid }
          : { from: this.fromNumber }),
      });
      this.logger.debug(`OTP SMS sent to ${phone} (${purpose})`);
    } catch (err) {
      const message = (err as Error).message ?? 'Unknown Twilio error';
      this.logger.warn(`OTP SMS to ${phone} failed: ${message}`);
      throw new Error(`Failed to send SMS: ${message}`);
    }
  }

  async sendWhatsApp(phone: string, body: string): Promise<void> {
    if (!this.client || !this.whatsappFrom) {
      this.logger.warn('WhatsApp send skipped — TWILIO_WHATSAPP_FROM is not set');
      return;
    }
    const to = phone.startsWith('whatsapp:') ? phone : `whatsapp:${phone}`;
    const from = this.whatsappFrom.startsWith('whatsapp:')
      ? this.whatsappFrom
      : `whatsapp:${this.whatsappFrom}`;
    try {
      await this.client.messages.create({ body, from, to });
    } catch (err) {
      const message = (err as Error).message ?? 'Unknown Twilio error';
      this.logger.warn(`WhatsApp to ${phone} failed: ${message}`);
    }
  }
}
