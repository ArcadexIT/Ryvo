import { Injectable, Logger, OnModuleInit } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { SESClient, SendEmailCommand } from '@aws-sdk/client-ses';
import { SettingsService } from '../settings/settings.service';

export type JobCompletedEmailPayload = {
  jobNumber: string;
  serviceName: string;
  fare: number;
  completedAt: Date;
  customer: { email: string; name: string };
  provider: { email: string; name: string };
  providerNetEarning?: number;
};

/**
 * Transactional email via AWS SES. Reuses the same AWS credentials as S3.
 * Fail-soft: missing config or send errors are logged and never break job flows.
 */
@Injectable()
export class EmailService implements OnModuleInit {
  private readonly logger = new Logger(EmailService.name);
  private ses: SESClient | null = null;
  private fromAddress = '';

  constructor(
    private config: ConfigService,
    private settings: SettingsService,
  ) {}

  onModuleInit() {
    const from = this.config.get<string>('EMAIL_FROM')?.trim();
    const accessKeyId = this.config.get<string>('AWS_ACCESS_KEY_ID')?.trim();
    const secretAccessKey = this.config.get<string>('AWS_SECRET_ACCESS_KEY')?.trim();
    const region = this.config.get<string>('AWS_REGION')?.trim() ?? 'us-east-1';

    if (!from || !accessKeyId || !secretAccessKey) {
      this.logger.warn(
        'Email disabled — set EMAIL_FROM, AWS_ACCESS_KEY_ID, and AWS_SECRET_ACCESS_KEY in .env',
      );
      return;
    }

    this.fromAddress = from;
    this.ses = new SESClient({
      region,
      credentials: { accessKeyId, secretAccessKey },
    });
    this.logger.log(`Email enabled (SES, from ${from}, region ${region})`);
  }

  get enabled(): boolean {
    return this.ses != null;
  }

  async sendJobCompletedEmails(payload: JobCompletedEmailPayload): Promise<void> {
    const currency = await this.settings.getPlatformCurrency();
    const money = (amount: number) => `${currency.symbol}${amount.toFixed(currency.decimals)}`;
    const fareText = money(payload.fare);
    const dateText = payload.completedAt.toLocaleString('en-US', {
      dateStyle: 'medium',
      timeStyle: 'short',
    });

    const tasks: Promise<boolean>[] = [];

    if (payload.customer.email.trim()) {
      tasks.push(
        this.send({
          to: payload.customer.email,
          subject: `Ryvo — Service completed (${payload.jobNumber})`,
          text: [
            `Hi ${payload.customer.name},`,
            '',
            `Your ${payload.serviceName} service (${payload.jobNumber}) was completed on ${dateText}.`,
            `Total: ${fareText}`,
            '',
            'Thank you for using Ryvo!',
          ].join('\n'),
          html: this.wrapHtml(`
          <p>Hi ${this.escape(payload.customer.name)},</p>
          <p>Your <strong>${this.escape(payload.serviceName)}</strong> service
             (<strong>${this.escape(payload.jobNumber)}</strong>) was completed on ${this.escape(dateText)}.</p>
          <p>Total: <strong>${fareText}</strong></p>
          <p>Thank you for using Ryvo!</p>
        `),
        }),
      );
    }

    if (payload.provider.email.trim()) {
      tasks.push(
        this.send({
          to: payload.provider.email,
          subject: `Ryvo — Job completed (${payload.jobNumber})`,
          text: [
            `Hi ${payload.provider.name},`,
            '',
            `You completed ${payload.serviceName} for job ${payload.jobNumber} on ${dateText}.`,
            payload.providerNetEarning != null
              ? `Your earning for this job: ${money(payload.providerNetEarning)}`
              : `Job total: ${fareText}`,
            '',
            'Great work!',
          ].join('\n'),
          html: this.wrapHtml(`
          <p>Hi ${this.escape(payload.provider.name)},</p>
          <p>You completed <strong>${this.escape(payload.serviceName)}</strong>
             for job <strong>${this.escape(payload.jobNumber)}</strong> on ${this.escape(dateText)}.</p>
          ${
            payload.providerNetEarning != null
              ? `<p>Your earning for this job: <strong>${money(payload.providerNetEarning)}</strong></p>`
              : `<p>Job total: <strong>${fareText}</strong></p>`
          }
          <p>Great work!</p>
        `),
        }),
      );
    }

    await Promise.all(tasks);
  }

  async sendPlain(to: string, subject: string, text: string): Promise<boolean> {
    return this.send({ to, subject, text, html: this.wrapHtml(`<p>${this.escape(text).replace(/\n/g, '<br>')}</p>`) });
  }

  private async send(params: {
    to: string;
    subject: string;
    text: string;
    html: string;
  }): Promise<boolean> {
    if (!this.ses || !params.to.trim()) return false;

    try {
      await this.ses.send(
        new SendEmailCommand({
          Source: this.fromAddress,
          Destination: { ToAddresses: [params.to.trim()] },
          Message: {
            Subject: { Data: params.subject, Charset: 'UTF-8' },
            Body: {
              Text: { Data: params.text, Charset: 'UTF-8' },
              Html: { Data: params.html, Charset: 'UTF-8' },
            },
          },
        }),
      );
      this.logger.debug(`Email sent to ${params.to} — ${params.subject}`);
      return true;
    } catch (err) {
      this.logger.warn(`Email to ${params.to} failed: ${(err as Error).message}`);
      return false;
    }
  }

  private wrapHtml(body: string): string {
    return `<!DOCTYPE html><html><body style="font-family:sans-serif;color:#111;line-height:1.5">${body}<p style="color:#666;margin-top:24px">— The Ryvo Team</p></body></html>`;
  }

  private escape(value: string): string {
    return value
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;');
  }
}
