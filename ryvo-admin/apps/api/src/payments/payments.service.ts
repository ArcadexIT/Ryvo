import {
  Injectable,
  NotFoundException,
  BadRequestException,
  Logger,
  OnModuleInit,
  Inject,
  forwardRef,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { PrismaService } from '../prisma/prisma.service';
import { parsePagination, paginateMeta } from '../common/utils';
import { PaginationDto } from '../common/dto/pagination.dto';
import Stripe from 'stripe';
import { PaymentMethod, PaymentStatus, Prisma } from '@ryvo/database';
import { WalletService } from '../wallet/wallet.service';
import { RealtimeService } from '../tracking/realtime.service';
import { MatchingService } from '../matching/matching.service';
import { SettingsService } from '../settings/settings.service';
import { SubscriptionsService } from '../subscriptions/subscriptions.service';

@Injectable()
export class PaymentsService implements OnModuleInit {
  private readonly logger = new Logger(PaymentsService.name);
  private stripe: Stripe | null = null;

  constructor(
    private prisma: PrismaService,
    private config: ConfigService,
    private wallet: WalletService,
    private realtime: RealtimeService,
    private settings: SettingsService,
    @Inject(forwardRef(() => MatchingService))
    private matching: MatchingService,
    @Inject(forwardRef(() => SubscriptionsService))
    private subscriptions: SubscriptionsService,
  ) {}

  onModuleInit() {
    const key = this.config.get<string>('STRIPE_SECRET_KEY')?.trim();
    if (key) {
      this.stripe = new Stripe(key);
      this.logger.log('Stripe payments enabled');
    } else {
      this.logger.warn('STRIPE_SECRET_KEY not set — Stripe card payments disabled');
    }
  }

  private requireStripe(): Stripe {
    if (!this.stripe) {
      throw new BadRequestException(
        'Stripe is not configured on the server. Set STRIPE_SECRET_KEY in apps/api/.env and restart the API.',
      );
    }
    return this.stripe;
  }

  private jobAmount(job: { finalFare: unknown; estimatedFare: unknown }) {
    return Number(job.finalFare ?? job.estimatedFare ?? 0);
  }

  private async assertPaymentMethodEnabled(method: PaymentMethod) {
    let enabled = false;
    switch (method) {
      case 'wallet':
        enabled = await this.settings.isPaymentWalletEnabled();
        break;
      case 'stripe':
        enabled = await this.settings.isPaymentStripeEnabled();
        break;
      case 'cash':
        enabled = await this.settings.isPaymentCashEnabled();
        break;
    }
    if (!enabled) {
      throw new BadRequestException(`${method} payments are currently disabled`);
    }
  }

  async findAll(dto: PaginationDto & { status?: PaymentStatus; method?: PaymentMethod }) {
    const { page, limit, skip } = parsePagination(dto);
    const where: Prisma.PaymentWhereInput = {
      ...(dto.status && { status: dto.status }),
      ...(dto.method && { method: dto.method }),
    };

    const [items, total] = await Promise.all([
      this.prisma.payment.findMany({
        where,
        skip,
        take: limit,
        orderBy: { createdAt: 'desc' },
        include: {
          job: {
            select: {
              id: true,
              jobNumber: true,
              customer: { include: { user: { select: { fullName: true } } } },
            },
          },
        },
      }),
      this.prisma.payment.count({ where }),
    ]);

    return { items, meta: paginateMeta(page, limit, total) };
  }

  async findByJob(jobId: string) {
    const payment = await this.prisma.payment.findUnique({
      where: { jobId },
      include: { job: true },
    });
    if (!payment) throw new NotFoundException('Payment not found');
    return payment;
  }

  private async loadJobForPayment(jobId: string, userId: string) {
    const job = await this.prisma.job.findUnique({
      where: { id: jobId },
      include: { customer: true, payment: true },
    });
    if (!job) throw new NotFoundException('Job not found');
    if (job.customer.userId !== userId) {
      throw new BadRequestException('Job does not belong to this customer');
    }
    return job;
  }

  /** After customer places a hold, start matching or confirm an existing match. */
  async advanceJobAfterHold(jobId: string) {
    const job = await this.prisma.job.findUnique({
      where: { id: jobId },
      include: {
        provider: {
          include: {
            user: { select: { fullName: true, avatarUrl: true, phone: true } },
            vehicles: { take: 1 },
          },
        },
      },
    });
    if (!job || job.status !== 'payment_pending') return job;

    // Pay-before-match: customer paid first, now find a provider.
    if (!job.providerId) {
      const updated = await this.prisma.$transaction(async (tx) => {
        const result = await tx.job.update({
          where: { id: jobId },
          data: { status: 'searching' },
        });
        await tx.jobStatusHistory.create({
          data: {
            jobId,
            fromStatus: 'payment_pending',
            toStatus: 'searching',
            changedByType: 'customer',
          },
        });
        return result;
      });

      this.realtime.emitToJob(jobId, 'job:status', { jobId, status: 'searching' });
      await this.matching.sendOffers(jobId);
      return updated;
    }

    const updated = await this.prisma.$transaction(async (tx) => {
      const result = await tx.job.update({
        where: { id: jobId },
        data: { status: 'matched', matchedAt: job.matchedAt ?? new Date() },
      });
      await tx.jobStatusHistory.create({
        data: {
          jobId,
          fromStatus: 'payment_pending',
          toStatus: 'matched',
          changedByType: 'customer',
        },
      });
      return result;
    });

    const payload = {
      jobId,
      status: 'matched',
      providerId: job.providerId,
      provider: job.provider
        ? {
            id: job.provider.id,
            fullName: job.provider.user.fullName,
            avatarUrl: job.provider.user.avatarUrl,
            phone: job.provider.user.phone,
            ratingAvg: job.provider.ratingAvg,
            currentLat: job.provider.currentLat,
            currentLng: job.provider.currentLng,
            vehicle: job.provider.vehicles[0] ?? null,
          }
        : null,
    };
    this.realtime.emitToJob(jobId, 'job:status', payload);
    this.realtime.emitToJob(jobId, 'job:provider_assigned', payload);

    return updated;
  }

  private async getOrCreateStripeCustomer(userId: string) {
    const stripe = this.requireStripe();
    const customer = await this.prisma.customer.findUnique({
      where: { userId },
      include: { user: { select: { email: true, phone: true, fullName: true } } },
    });
    if (!customer) throw new NotFoundException('Customer profile not found');

    if (customer.stripeCustomerId) {
      return customer.stripeCustomerId;
    }

    const created = await stripe.customers.create({
      email: customer.user.email ?? undefined,
      phone: customer.user.phone,
      name: customer.user.fullName,
      metadata: { userId, customerId: customer.id },
    });

    await this.prisma.customer.update({
      where: { id: customer.id },
      data: { stripeCustomerId: created.id },
    });
    return created.id;
  }

  async createPaymentIntent(jobId: string, amount: number, userId?: string) {
    await this.assertPaymentMethodEnabled('stripe');
    const stripe = this.requireStripe();

    const job = await this.prisma.job.findUnique({ where: { id: jobId } });
    if (!job) throw new NotFoundException('Job not found');

    let stripeCustomerId: string | undefined;
    let ephemeralKey: string | undefined;
    if (userId) {
      stripeCustomerId = await this.getOrCreateStripeCustomer(userId);
      const key = await stripe.ephemeralKeys.create(
        { customer: stripeCustomerId },
        { apiVersion: '2024-06-20' },
      );
      ephemeralKey = key.secret ?? undefined;
    }

    const currency = (await this.settings.getPlatformCurrency()).code.toLowerCase();
    const intent = await stripe.paymentIntents.create({
      amount: Math.round(amount * 100),
      currency,
      metadata: { jobId, jobNumber: job.jobNumber },
      payment_method_types: ['card'],
      capture_method: 'manual',
      ...(stripeCustomerId
        ? { customer: stripeCustomerId, setup_future_usage: 'off_session' }
        : {}),
    });

    const payment = await this.prisma.payment.upsert({
      where: { jobId },
      create: {
        jobId,
        method: 'stripe',
        amount,
        status: 'pending',
        stripePaymentIntentId: intent.id,
      },
      update: {
        amount,
        stripePaymentIntentId: intent.id,
        status: 'pending',
      },
    });

    const clientSecret = intent.client_secret;
    if (!clientSecret) {
      throw new BadRequestException('Stripe did not return a client secret');
    }

    return {
      payment,
      clientSecret,
      customerId: stripeCustomerId,
      ephemeralKey,
    };
  }

  async confirmPayment(jobId: string, paymentIntentId?: string) {
    const payment = await this.findByJob(jobId);

    if (this.stripe) {
      const intentId = paymentIntentId ?? payment.stripePaymentIntentId;
      if (!intentId) {
        throw new BadRequestException('No Stripe payment intent for this job');
      }
      const intent = await this.stripe.paymentIntents.retrieve(intentId);

      // Manual capture → requires_capture; automatic capture → succeeded.
      // Either way funds are secured — advance the job out of payment_pending.
      if (intent.status === 'requires_capture' || intent.status === 'succeeded') {
        const updated = await this.prisma.payment.update({
          where: { jobId },
          data:
            intent.status === 'succeeded'
              ? { status: 'paid', paidAt: new Date() }
              : { status: 'held' },
        });
        await this.advanceJobAfterHold(jobId);
        return updated;
      }

      throw new BadRequestException(`Payment not authorized: ${intent.status}`);
    }

    this.requireStripe();
    return payment;
  }

  /** Place wallet funds on hold when provider is matched (pay in advance). */
  async holdWithWallet(jobId: string, userId: string) {
    await this.assertPaymentMethodEnabled('wallet');
    const job = await this.loadJobForPayment(jobId, userId);

    if (job.payment?.status === 'held' || job.payment?.status === 'paid') {
      // Payment already secured — still advance if the job is stuck on payment_pending.
      await this.advanceJobAfterHold(jobId);
      return job.payment;
    }
    if (job.status !== 'payment_pending') {
      throw new BadRequestException('Job is not awaiting payment');
    }

    const amount = this.jobAmount(job);
    if (amount <= 0) throw new BadRequestException('Invalid job amount');

    await this.wallet.hold(userId, amount, jobId);

    const payment = await this.prisma.payment.upsert({
      where: { jobId },
      create: {
        jobId,
        method: 'wallet',
        amount,
        status: 'held',
      },
      update: {
        method: 'wallet',
        amount,
        status: 'held',
        paidAt: null,
        refundedAt: null,
      },
    });

    await this.advanceJobAfterHold(jobId);
    return payment;
  }

  /** @deprecated Alias for holdWithWallet — customer pays in advance via wallet hold. */
  async payWithWallet(jobId: string, userId: string) {
    return this.holdWithWallet(jobId, userId);
  }

  /** Customer commits to pay cash on service completion (no funds held upfront). */
  async payWithCash(jobId: string, userId: string) {
    await this.assertPaymentMethodEnabled('cash');
    const job = await this.loadJobForPayment(jobId, userId);

    if (job.payment?.status === 'held' || job.payment?.status === 'paid') {
      // Payment already secured — still advance if the job is stuck on payment_pending.
      await this.advanceJobAfterHold(jobId);
      return job.payment;
    }
    if (job.status !== 'payment_pending') {
      throw new BadRequestException('Job is not awaiting payment');
    }

    const amount = this.jobAmount(job);
    if (amount <= 0) throw new BadRequestException('Invalid job amount');

    const payment = await this.prisma.payment.upsert({
      where: { jobId },
      create: {
        jobId,
        method: 'cash',
        amount,
        status: 'held',
      },
      update: {
        method: 'cash',
        amount,
        status: 'held',
        paidAt: null,
        refundedAt: null,
      },
    });

    await this.advanceJobAfterHold(jobId);
    return payment;
  }

  /** Save the rider's payment method when the ride is requested. No charge yet. */
  async recordPendingRidePayment(input: {
    jobId: string;
    userId: string;
    method: PaymentMethod;
    amount: number;
    stripePaymentMethodId?: string;
  }) {
    await this.assertPaymentMethodEnabled(input.method);
    if (input.amount <= 0) throw new BadRequestException('Invalid fare');

    let stripePaymentMethodId = input.stripePaymentMethodId?.trim() || null;
    if (input.method === 'stripe') {
      if (!stripePaymentMethodId) {
        throw new BadRequestException('Save a card before requesting a ride');
      }
      if (this.stripe) {
        const stripeCustomerId = await this.getOrCreateStripeCustomer(input.userId);
        const paymentMethod = await this.stripe.paymentMethods.retrieve(stripePaymentMethodId);
        const owner =
          typeof paymentMethod.customer === 'string'
            ? paymentMethod.customer
            : paymentMethod.customer?.id;
        if (owner && owner !== stripeCustomerId) {
          throw new BadRequestException('That card does not belong to this account');
        }
        if (!owner) {
          await this.stripe.paymentMethods.attach(stripePaymentMethodId, {
            customer: stripeCustomerId,
          });
        }
      }
    }

    if (input.method === 'wallet') {
      const balance = await this.wallet.getBalance(input.userId);
      if (balance.balance < input.amount) {
        throw new BadRequestException('Insufficient wallet balance');
      }
    }

    return this.prisma.payment.upsert({
      where: { jobId: input.jobId },
      create: {
        jobId: input.jobId,
        method: input.method,
        amount: input.amount,
        status: 'pending',
        stripePaymentMethodId,
      },
      update: {
        method: input.method,
        amount: input.amount,
        status: 'pending',
        stripePaymentMethodId,
        paidAt: null,
      },
    });
  }

  /** Create a SetupIntent so the rider can save a card for the end-of-trip charge. */
  async createSetupIntent(userId: string) {
    await this.assertPaymentMethodEnabled('stripe');
    const stripe = this.requireStripe();
    const customerId = await this.getOrCreateStripeCustomer(userId);
    const intent = await stripe.setupIntents.create({
      customer: customerId,
      payment_method_types: ['card'],
      usage: 'off_session',
    });
    const key = await stripe.ephemeralKeys.create(
      { customer: customerId },
      { apiVersion: '2024-06-20' },
    );
    if (!intent.client_secret) {
      throw new BadRequestException('Stripe did not return a client secret');
    }
    return {
      clientSecret: intent.client_secret,
      customerId,
      ephemeralKey: key.secret ?? undefined,
    };
  }

  /**
   * Charge the final fare when the trip ends.
   * A failed card leaves the payment failed and does not undo the completed ride.
   */
  async chargeForCompletedJob(jobId: string) {
    const job = await this.prisma.job.findUnique({
      where: { id: jobId },
      include: { customer: true, payment: true },
    });
    if (!job?.payment) return null;
    if (job.payment.status === 'paid') return job.payment;
    if (job.payment.status === 'held') {
      try {
        return await this.captureForJob(jobId);
      } catch (err) {
        this.logger.warn(`Held capture failed for job ${jobId}: ${(err as Error).message}`);
        return this.prisma.payment.update({
          where: { jobId },
          data: { status: 'failed' },
        });
      }
    }
    if (job.payment.status !== 'pending' && job.payment.status !== 'failed') {
      return job.payment;
    }

    const amount = Number(job.finalFare ?? job.estimatedFare ?? job.payment.amount);
    try {
      if (amount <= 0) {
        return this.prisma.payment.update({
          where: { jobId },
          data: { amount, status: 'paid', paidAt: new Date() },
        });
      }

      if (job.payment.method === 'wallet') {
        await this.wallet.deduct(job.customer.userId, amount, 'job', jobId);
      } else if (job.payment.method === 'stripe') {
        if (!job.payment.stripePaymentMethodId) {
          throw new BadRequestException('No saved card for this ride');
        }
        const stripe = this.requireStripe();
        const stripeCustomerId = await this.getOrCreateStripeCustomer(job.customer.userId);
        const currency = (await this.settings.getPlatformCurrency()).code.toLowerCase();
        const intent = await stripe.paymentIntents.create({
          amount: Math.round(amount * 100),
          currency,
          customer: stripeCustomerId,
          payment_method: job.payment.stripePaymentMethodId,
          off_session: true,
          confirm: true,
          metadata: { jobId, jobNumber: job.jobNumber, charge: 'trip_end' },
        });
        if (intent.status !== 'succeeded') {
          throw new BadRequestException(`Card charge did not succeed: ${intent.status}`);
        }
        return this.prisma.payment.update({
          where: { jobId },
          data: {
            amount,
            status: 'paid',
            paidAt: new Date(),
            stripePaymentIntentId: intent.id,
          },
        });
      }

      return this.prisma.payment.update({
        where: { jobId },
        data: { amount, status: 'paid', paidAt: new Date() },
      });
    } catch (err) {
      this.logger.warn(`End-of-trip charge failed for job ${jobId}: ${(err as Error).message}`);
      return this.prisma.payment.update({
        where: { jobId },
        data: { amount, status: 'failed' },
      });
    }
  }

  /** Capture held funds when the job completes successfully. */
  async captureForJob(jobId: string) {
    const job = await this.prisma.job.findUnique({
      where: { id: jobId },
      include: { customer: true, payment: true },
    });
    if (!job?.payment) return null;

    const payment = job.payment;
    if (payment.status === 'paid') return payment;
    if (payment.status !== 'held') {
      throw new BadRequestException('No held payment to capture for this job');
    }

    const amount = Number(payment.amount);

    if (payment.method === 'wallet') {
      await this.wallet.captureHold(job.customer.userId, amount, jobId);
    } else if (payment.method === 'stripe' && payment.stripePaymentIntentId && this.stripe) {
      const intent = await this.stripe.paymentIntents.capture(payment.stripePaymentIntentId);
      if (intent.status !== 'succeeded') {
        throw new BadRequestException(`Stripe capture failed: ${intent.status}`);
      }
    } else if (payment.method === 'cash') {
      // Cash is collected in person — mark paid when the job completes.
    }

    return this.prisma.payment.update({
      where: { jobId },
      data: { status: 'paid', paidAt: new Date() },
    });
  }

  /** Release held funds when job is cancelled or provider no-shows. */
  async releaseHoldForJob(jobId: string) {
    const job = await this.prisma.job.findUnique({
      where: { id: jobId },
      include: { customer: true, payment: true },
    });
    if (!job?.payment) return null;

    const payment = job.payment;
    if (payment.status !== 'held') return payment;

    const amount = Number(payment.amount);

    if (payment.method === 'wallet') {
      await this.wallet.releaseHold(job.customer.userId, amount, jobId);
    } else if (payment.method === 'stripe' && payment.stripePaymentIntentId && this.stripe) {
      try {
        await this.stripe.paymentIntents.cancel(payment.stripePaymentIntentId);
      } catch (err) {
        this.logger.warn(`Stripe cancel failed for job ${jobId}: ${(err as Error).message}`);
      }
    } else if (payment.method === 'cash') {
      // No funds were held — just close the payment record.
    }

    return this.prisma.payment.update({
      where: { jobId },
      data: { status: 'refunded', refundedAt: new Date(), refundAmount: amount },
    });
  }

  /** Capture a cancellation fee from the hold and refund the remainder. */
  async settleCustomerCancellation(jobId: string, fee: number) {
    const safeFee = Math.max(0, fee);
    if (safeFee <= 0) {
      return this.releaseHoldForJob(jobId);
    }

    const job = await this.prisma.job.findUnique({
      where: { id: jobId },
      include: { customer: true, payment: true },
    });
    if (!job?.payment || job.payment.status !== 'held') {
      return job?.payment ?? null;
    }

    const held = Number(job.payment.amount);
    const captureAmount = Math.min(safeFee, held);
    const refundAmount = Math.max(0, held - captureAmount);

    if (job.payment.method === 'wallet') {
      if (captureAmount > 0) {
        await this.wallet.captureHold(job.customer.userId, captureAmount, jobId);
      }
      if (refundAmount > 0) {
        await this.wallet.releaseHold(job.customer.userId, refundAmount, jobId);
      }
    } else if (job.payment.method === 'stripe' && job.payment.stripePaymentIntentId && this.stripe) {
      try {
        if (captureAmount > 0) {
          await this.stripe.paymentIntents.capture(job.payment.stripePaymentIntentId, {
            amount_to_capture: Math.round(captureAmount * 100),
          });
        } else {
          await this.stripe.paymentIntents.cancel(job.payment.stripePaymentIntentId);
        }
      } catch (err) {
        this.logger.warn(`Stripe cancel settlement failed for job ${jobId}: ${(err as Error).message}`);
      }
    }

    return this.prisma.payment.update({
      where: { jobId },
      data: {
        status: refundAmount > 0 && captureAmount > 0 ? 'refunded' : captureAmount > 0 ? 'paid' : 'refunded',
        paidAt: captureAmount > 0 ? new Date() : undefined,
        refundedAt: refundAmount > 0 ? new Date() : undefined,
        refundAmount: refundAmount > 0 ? refundAmount : undefined,
      },
    });
  }

  async applyProviderPenalty(userId: string, amount: number, jobId: string) {
    if (amount <= 0) return null;
    try {
      return await this.wallet.adminAdjust(
        userId,
        -amount,
        `Cancellation penalty for job ${jobId}`,
      );
    } catch (err) {
      this.logger.warn(`Provider penalty debit failed for ${userId}: ${(err as Error).message}`);
      return null;
    }
  }

  async refund(jobId: string, amount?: number, reason?: string) {
    const payment = await this.findByJob(jobId);
    if (payment.status === 'held') {
      return this.releaseHoldForJob(jobId);
    }
    if (payment.status !== 'paid') {
      throw new BadRequestException('Only paid or held payments can be refunded');
    }

    const refundAmount = amount ?? Number(payment.amount);
    const job = await this.prisma.job.findUnique({
      where: { id: jobId },
      include: { customer: true },
    });

    if (this.stripe && payment.stripePaymentIntentId) {
      await this.stripe.refunds.create({
        payment_intent: payment.stripePaymentIntentId,
        amount: Math.round(refundAmount * 100),
        reason: reason ? 'requested_by_customer' : undefined,
      });
    } else if (payment.method === 'wallet' && job) {
      await this.wallet.credit(
        job.customer.userId,
        refundAmount,
        reason ?? 'Payment refund',
        'job',
        jobId,
      );
    }

    return this.prisma.payment.update({
      where: { jobId },
      data: {
        status: 'refunded',
        refundedAt: new Date(),
        refundAmount,
      },
    });
  }

  async handleStripeWebhook(rawBody: Buffer, signature: string) {
    const webhookSecret = this.config.get<string>('STRIPE_WEBHOOK_SECRET');
    if (!this.stripe || !webhookSecret) {
      throw new BadRequestException('Stripe webhook not configured');
    }

    const event = this.stripe.webhooks.constructEvent(rawBody, signature, webhookSecret);

    switch (event.type) {
      case 'payment_intent.amount_capturable_updated': {
        const intent = event.data.object as Stripe.PaymentIntent;
        const jobId = intent.metadata?.jobId;
        if (jobId && intent.status === 'requires_capture') {
          await this.prisma.payment.updateMany({
            where: { jobId, stripePaymentIntentId: intent.id },
            data: { status: 'held' },
          });
          await this.advanceJobAfterHold(jobId);
        }
        break;
      }
      case 'checkout.session.completed': {
        const session = event.data.object as Stripe.Checkout.Session;
        if (session.metadata?.kind === 'driver_subscription' && session.metadata.subscriptionId) {
          await this.subscriptions.activate(session.metadata.subscriptionId);
        }
        break;
      }
      case 'payment_intent.succeeded': {
        const intent = event.data.object as Stripe.PaymentIntent;
        if (intent.metadata?.kind === 'driver_subscription') {
          await this.subscriptions.handlePaymentIntentSucceeded(intent);
          break;
        }
        const jobId = intent.metadata?.jobId;
        if (jobId) {
          await this.prisma.payment.updateMany({
            where: { jobId, stripePaymentIntentId: intent.id },
            data: { status: 'paid', paidAt: new Date() },
          });
          await this.advanceJobAfterHold(jobId);
        }
        break;
      }
      case 'payment_intent.payment_failed': {
        const intent = event.data.object as Stripe.PaymentIntent;
        const jobId = intent.metadata?.jobId;
        if (jobId) {
          await this.prisma.payment.updateMany({
            where: { jobId },
            data: { status: 'failed' },
          });
        }
        break;
      }
      case 'payment_intent.canceled': {
        const intent = event.data.object as Stripe.PaymentIntent;
        const jobId = intent.metadata?.jobId;
        if (jobId) {
          await this.prisma.payment.updateMany({
            where: { jobId, stripePaymentIntentId: intent.id, status: 'held' },
            data: { status: 'refunded', refundedAt: new Date() },
          });
        }
        break;
      }
      default:
        this.logger.debug(`Unhandled Stripe event: ${event.type}`);
    }

    return { received: true };
  }
}
