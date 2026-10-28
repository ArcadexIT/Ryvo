import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  Logger,
  NotFoundException,
  OnModuleDestroy,
  OnModuleInit,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import Stripe from 'stripe';
import { PrismaService } from '../prisma/prisma.service';
import { SettingsService } from '../settings/settings.service';
import { RealtimeService } from '../tracking/realtime.service';
import { NotificationsService } from '../notifications/notifications.service';
import { DriverMonetizationMode } from '@ryvo/shared';

function addPeriod(from: Date, period: 'daily' | 'weekly' | 'monthly') {
  const next = new Date(from);
  if (period === 'daily') next.setDate(next.getDate() + 1);
  else if (period === 'weekly') next.setDate(next.getDate() + 7);
  else next.setMonth(next.getMonth() + 1);
  return next;
}

@Injectable()
export class SubscriptionsService implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(SubscriptionsService.name);
  private stripe: Stripe | null = null;
  private expireTimer?: ReturnType<typeof setInterval>;

  constructor(
    private prisma: PrismaService,
    private settings: SettingsService,
    private realtime: RealtimeService,
    private notifications: NotificationsService,
    private config: ConfigService,
  ) {
    const key = this.config.get<string>('STRIPE_SECRET_KEY')?.trim();
    if (key) this.stripe = new Stripe(key);
  }

  onModuleInit() {
    this.expireTimer = setInterval(() => {
      void this.expireOverdue().catch((err) => this.logger.warn(err));
    }, 60_000);
  }

  onModuleDestroy() {
    if (this.expireTimer) clearInterval(this.expireTimer);
  }

  async listPlans() {
    return this.prisma.driverSubscriptionPlan.findMany({
      where: { isActive: true },
      orderBy: { sortOrder: 'asc' },
    });
  }

  async adminListPlans() {
    return this.prisma.driverSubscriptionPlan.findMany({ orderBy: { sortOrder: 'asc' } });
  }

  async upsertPlan(data: {
    id?: string;
    name: string;
    period: 'daily' | 'weekly' | 'monthly';
    price: number;
    commissionRate?: number;
    isActive?: boolean;
    sortOrder?: number;
  }) {
    if (data.id) {
      return this.prisma.driverSubscriptionPlan.update({
        where: { id: data.id },
        data: {
          name: data.name,
          period: data.period,
          price: data.price,
          commissionRate: data.commissionRate ?? 0,
          isActive: data.isActive ?? true,
          sortOrder: data.sortOrder ?? 0,
        },
      });
    }
    return this.prisma.driverSubscriptionPlan.create({
      data: {
        name: data.name,
        period: data.period,
        price: data.price,
        commissionRate: data.commissionRate ?? 0,
        isActive: data.isActive ?? true,
        sortOrder: data.sortOrder ?? 0,
      },
    });
  }

  async getProviderStatus(providerId: string) {
    await this.expireOverdue();
    const mode = await this.settings.getDriverMonetizationMode();
    const current = await this.prisma.driverSubscription.findFirst({
      where: { providerId, status: 'active', expiresAt: { gt: new Date() } },
      include: { plan: true },
      orderBy: { expiresAt: 'desc' },
    });
    return {
      mode,
      required: mode === DriverMonetizationMode.SUBSCRIPTION,
      active: current,
      canGoOnline: mode === DriverMonetizationMode.COMMISSION || !!current,
    };
  }

  async assertCanGoOnline(providerId: string) {
    const status = await this.getProviderStatus(providerId);
    if (!status.canGoOnline) {
      throw new ForbiddenException(
        'An active driver subscription is required before you can go online.',
      );
    }
  }

  async getActiveCommissionRate(providerId: string, fallbackRate: number) {
    const mode = await this.settings.getDriverMonetizationMode();
    if (mode !== DriverMonetizationMode.SUBSCRIPTION) return fallbackRate;
    const current = await this.prisma.driverSubscription.findFirst({
      where: { providerId, status: 'active', expiresAt: { gt: new Date() } },
      include: { plan: true },
      orderBy: { expiresAt: 'desc' },
    });
    if (!current) return fallbackRate;
    return Number(current.plan.commissionRate);
  }

  async purchase(providerId: string, planId: string) {
    const plan = await this.prisma.driverSubscriptionPlan.findUnique({ where: { id: planId } });
    if (!plan?.isActive) throw new NotFoundException('Plan not found');
    const currency = (await this.settings.getPlatformCurrency()).code.toLowerCase();
    const amount = Math.round(Number(plan.price) * 100);
    if (amount <= 0) throw new BadRequestException('Invalid plan price');

    const subscription = await this.prisma.driverSubscription.create({
      data: {
        providerId,
        planId,
        status: 'pending',
      },
    });

    if (!this.stripe) {
      await this.activate(subscription.id);
      return {
        subscription: await this.prisma.driverSubscription.findUnique({
          where: { id: subscription.id },
          include: { plan: true },
        }),
        clientSecret: null,
        checkoutUrl: null,
      };
    }

    const session = await this.stripe.checkout.sessions.create({
      mode: 'payment',
      line_items: [
        {
          price_data: {
            currency,
            product_data: { name: `Driver ${plan.name} plan` },
            unit_amount: amount,
          },
          quantity: 1,
        },
      ],
      success_url: 'https://ryvo.arcadexit.com/stripe/return?session_id={CHECKOUT_SESSION_ID}',
      cancel_url: 'https://ryvo.arcadexit.com/stripe/refresh',
      client_reference_id: subscription.id,
      metadata: {
        kind: 'driver_subscription',
        subscriptionId: subscription.id,
        providerId,
        planId,
      },
    });

    await this.prisma.driverSubscription.update({
      where: { id: subscription.id },
      data: { stripeCheckoutSessionId: session.id },
    });

    return {
      subscription: await this.prisma.driverSubscription.findUnique({
        where: { id: subscription.id },
        include: { plan: true },
      }),
      clientSecret: null,
      checkoutUrl: session.url,
    };
  }

  async activate(subscriptionId: string) {
    const row = await this.prisma.driverSubscription.findUnique({
      where: { id: subscriptionId },
      include: { plan: true, provider: { select: { userId: true } } },
    });
    if (!row) return;
    if (row.status === 'active' && row.expiresAt && row.expiresAt > new Date()) return;

    const startsAt = new Date();
    const existing = await this.prisma.driverSubscription.findFirst({
      where: {
        providerId: row.providerId,
        status: 'active',
        expiresAt: { gt: startsAt },
        id: { not: subscriptionId },
      },
      orderBy: { expiresAt: 'desc' },
    });
    const base = existing?.expiresAt && existing.expiresAt > startsAt ? existing.expiresAt : startsAt;
    const expiresAt = addPeriod(base, row.plan.period);

    if (existing) {
      await this.prisma.driverSubscription.update({
        where: { id: existing.id },
        data: { status: 'cancelled' },
      });
    }

    await this.prisma.driverSubscription.update({
      where: { id: subscriptionId },
      data: { status: 'active', startsAt, expiresAt },
    });

    void this.notifications.notify({
      userId: row.provider.userId,
      type: 'subscription_active',
      title: 'Subscription active',
      body: `${row.plan.name} plan is active until ${expiresAt.toISOString()}`,
      data: { subscriptionId },
    });
  }

  async handlePaymentIntentSucceeded(intent: Stripe.PaymentIntent) {
    if (intent.metadata?.kind !== 'driver_subscription') return;
    const subscriptionId = intent.metadata.subscriptionId;
    if (!subscriptionId) return;
    await this.activate(subscriptionId);
  }

  async expireOverdue() {
    const now = new Date();
    const expired = await this.prisma.driverSubscription.findMany({
      where: { status: 'active', expiresAt: { lte: now } },
      include: { provider: { select: { id: true, userId: true, onlineStatus: true } } },
    });
    if (!expired.length) return { expired: 0 };

    await this.prisma.driverSubscription.updateMany({
      where: { id: { in: expired.map((row) => row.id) } },
      data: { status: 'expired' },
    });

    const mode = await this.settings.getDriverMonetizationMode();
    if (mode === DriverMonetizationMode.SUBSCRIPTION) {
      for (const row of expired) {
        if (row.provider.onlineStatus === 'online') {
          await this.prisma.provider.update({
            where: { id: row.provider.id },
            data: { onlineStatus: 'offline' },
          });
        }
        void this.notifications.notify({
          userId: row.provider.userId,
          type: 'subscription_expired',
          title: 'Subscription expired',
          body: 'Renew your plan to go online and keep receiving jobs.',
          data: { subscriptionId: row.id },
        });
        this.realtime.emitToProvider(row.provider.id, 'subscription:expired', {
          subscriptionId: row.id,
        });
      }
    }
    return { expired: expired.length };
  }
}
