import { Injectable, Logger, OnModuleInit } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import {
  App,
  ServiceAccount,
  cert,
  getApps,
  initializeApp,
} from 'firebase-admin/app';
import { getMessaging } from 'firebase-admin/messaging';
import * as fs from 'fs';
import * as path from 'path';

/**
 * Firebase Cloud Messaging wrapper. Initializes from a service account provided
 * via env (`GOOGLE_APPLICATION_CREDENTIALS` file path or
 * `FIREBASE_SERVICE_ACCOUNT_JSON` single-line JSON). All methods fail soft so a
 * missing/invalid config never breaks the request flow.
 */
@Injectable()
export class PushService implements OnModuleInit {
  private readonly logger = new Logger(PushService.name);
  private app?: App;

  constructor(private config: ConfigService) {}

  onModuleInit() {
    const existing = getApps();
    if (existing.length) {
      this.app = existing[0];
      return;
    }

    try {
      const filePath = this.config.get<string>('GOOGLE_APPLICATION_CREDENTIALS');
      const inline = this.config.get<string>('FIREBASE_SERVICE_ACCOUNT_JSON');

      if (filePath?.trim()) {
        const serviceAccount = this.loadServiceAccountFromFile(filePath.trim());
        this.app = initializeApp({ credential: cert(serviceAccount) });
        this.logger.log(
          `FCM initialized from GOOGLE_APPLICATION_CREDENTIALS (${filePath.trim()})`,
        );
      } else if (inline?.trim()) {
        const serviceAccount = this.parseInlineServiceAccount(inline);
        this.app = initializeApp({ credential: cert(serviceAccount) });
        this.logger.log('FCM initialized from inline service account');
      } else {
        this.logger.warn('FCM not configured; push notifications disabled');
      }
    } catch (err) {
      this.logger.error('Failed to initialize FCM; push disabled', err as Error);
    }
  }

  private loadServiceAccountFromFile(filePath: string): ServiceAccount {
    const resolved = this.resolveCredentialsPath(filePath);
    return JSON.parse(fs.readFileSync(resolved, 'utf8')) as ServiceAccount;
  }

  private resolveCredentialsPath(filePath: string): string {
    const normalized = filePath.replace(/^\.\//, '');
    const candidates = [
      path.resolve(process.cwd(), filePath),
      path.resolve(process.cwd(), 'apps/api', normalized),
    ];
    for (const candidate of candidates) {
      if (fs.existsSync(candidate)) return candidate;
    }
    throw new Error(
      `Firebase service account file not found. Tried: ${candidates.join(', ')}`,
    );
  }

  /** Parse JSON from .env — must be a single line; multiline JSON breaks dotenv. */
  private parseInlineServiceAccount(raw: string): ServiceAccount {
    let value = raw.trim();
    if (
      (value.startsWith('"') && value.endsWith('"')) ||
      (value.startsWith("'") && value.endsWith("'"))
    ) {
      value = value.slice(1, -1);
    }
    return JSON.parse(value) as ServiceAccount;
  }

  get enabled(): boolean {
    return !!this.app;
  }

  async sendToToken(
    token: string,
    notification: { title: string; body: string },
    data?: Record<string, string>,
  ): Promise<boolean> {
    if (!this.app || !token) return false;
    try {
      await getMessaging(this.app).send({
        token,
        notification,
        data,
        android: { priority: 'high' },
        apns: {
          headers: {
            'apns-priority': '10',
            'apns-push-type': 'alert',
          },
          payload: {
            aps: {
              alert: {
                title: notification.title,
                body: notification.body,
              },
              sound: 'default',
              badge: 1,
            },
          },
        },
      });
      return true;
    } catch (err) {
      this.logger.warn(`FCM send failed: ${(err as Error).message}`);
      return false;
    }
  }
}
