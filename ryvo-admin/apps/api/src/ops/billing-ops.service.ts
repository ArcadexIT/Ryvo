import { BadRequestException, Injectable, Logger, NotFoundException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { Prisma } from '@ryvo/database';
import { DEFAULT_VEHICLE_LOOKUP_BASE_URL, PLATFORM_SETTINGS_KEYS } from '@ryvo/shared';
import { PrismaService } from '../prisma/prisma.service';
import { EmailService } from '../email/email.service';
import { SettingsService } from '../settings/settings.service';
import Stripe from 'stripe';

/** Providers are individuals and often have no website. Stripe accepts this instead of a URL. */
const PROVIDER_PAYOUT_DESCRIPTION =
  'Independent provider of roadside assistance booked through RYVO, such as jump-starts, tyre changes, fuel delivery and lockouts.';

@Injectable()
export class BillingOpsService {
  private readonly logger = new Logger(BillingOpsService.name);

  constructor(
    private prisma: PrismaService,
    private email: EmailService,
    private settings: SettingsService,
    private config: ConfigService,
  ) {}

  private stripe(): Stripe | null {
    const key = this.stripeKey();
    if (!key) return null;
    return new Stripe(key);
  }

  private stripeKey(): string | null {
    const key = this.config.get<string>('STRIPE_SECRET_KEY')?.trim();
    return key || null;
  }

  /** Accounts v2. The platform rejects Accounts v1 creation. */
  private async stripeV2<T>(method: 'GET' | 'POST', path: string, body?: Record<string, unknown>): Promise<T> {
    const key = this.stripeKey();
    if (!key) throw new BadRequestException('Stripe is not configured on the server.');
    const res = await fetch(`https://api.stripe.com${path}`, {
      method,
      headers: {
        Authorization: `Bearer ${key}`,
        'Stripe-Version': '2026-09-30.endive',
        ...(body ? { 'Content-Type': 'application/json' } : {}),
      },
      body: body ? JSON.stringify(body) : undefined,
    });
    const payload = (await res.json().catch(() => null)) as
      | (T & { error?: { message?: string }; message?: string })
      | null;
    if (!res.ok) {
      const message =
        payload && typeof payload === 'object' && payload.error?.message
          ? payload.error.message
          : payload && typeof payload === 'object' && typeof payload.message === 'string'
            ? payload.message
            : 'Stripe request failed';
      throw new BadRequestException(message);
    }
    return payload as T;
  }

  async issueForCompletedJob(jobId: string) {
    const existing = await this.prisma.invoice.findUnique({ where: { jobId } });
    if (existing) return existing;
    const job = await this.prisma.job.findUnique({
      where: { id: jobId },
      include: {
        payment: true,
        serviceCategory: { select: { name: true } },
        customer: { include: { user: { select: { email: true, fullName: true } } } },
      },
    });
    if (!job || job.status !== 'completed') return null;
    const total = Number(job.finalFare ?? job.estimatedFare ?? job.payment?.amount ?? 0);
    const count = await this.prisma.invoice.count();
    const invoice = await this.prisma.invoice.create({
      data: {
        invoiceNumber: `INV-${String(count + 1).padStart(6, '0')}`,
        jobId,
        paymentId: job.payment?.id,
        customerId: job.customerId,
        email: job.customer.user.email,
        total,
      },
    });
    const to = job.customer.user.email?.trim();
    if (to && this.email.enabled) {
      const currency = await this.settings.getPlatformCurrency();
      const sent = await this.email.sendPlain(
        to,
        `RYVO invoice ${invoice.invoiceNumber}`,
        [
          `Hi ${job.customer.user.fullName},`,
          '',
          `Invoice ${invoice.invoiceNumber} for ${job.serviceCategory.name} (${job.jobNumber}).`,
          `Total: ${currency.symbol}${total.toFixed(currency.decimals)}`,
        ].join('\n'),
      );
      if (sent) {
        await this.prisma.invoice.update({
          where: { id: invoice.id },
          data: { sentAt: new Date() },
        });
      }
    }
    return invoice;
  }

  async listForCustomer(customerId: string) {
    return this.prisma.invoice.findMany({
      where: { customerId },
      orderBy: { issuedAt: 'desc' },
      include: customerInvoiceInclude,
    });
  }

  async getForCustomer(customerId: string, invoiceId: string) {
    const invoice = await this.prisma.invoice.findFirst({
      where: { id: invoiceId, customerId },
      include: customerInvoiceInclude,
    });
    if (!invoice) throw new NotFoundException('Invoice not found');
    return invoice;
  }

  async listAll() {
    return this.prisma.invoice.findMany({
      orderBy: { issuedAt: 'desc' },
      take: 200,
      include: {
        customer: { include: { user: { select: { fullName: true, email: true, phone: true } } } },
        job: { select: { jobNumber: true } },
      },
    });
  }

  async createConnectLink(providerId: string, refreshUrl: string, returnUrl: string) {
    if (!this.stripeKey()) throw new BadRequestException('Stripe is not configured on the server.');
    const provider = await this.prisma.provider.findUnique({
      where: { id: providerId },
      include: { user: { select: { email: true, fullName: true } } },
    });
    if (!provider) throw new BadRequestException('Driver not found');
    let accountId = provider.stripeAccountId;
    if (!accountId) {
      const email = provider.user.email?.trim();
      if (!email) {
        throw new BadRequestException('Add an email address in your profile before setting up Stripe payouts.');
      }
      const account = await this.stripeV2<{ id: string }>('POST', '/v2/core/accounts', {
        ...(email ? { contact_email: email } : {}),
        display_name: provider.user.fullName?.trim() || provider.businessName?.trim() || 'RYVO driver',
        dashboard: 'express',
        defaults: {
          responsibilities: {
            fees_collector: 'application',
            losses_collector: 'application',
          },
          profile: { product_description: PROVIDER_PAYOUT_DESCRIPTION },
        },
        identity: { country: 'gb', entity_type: 'individual' },
        configuration: {
          recipient: {
            capabilities: {
              stripe_balance: {
                stripe_transfers: { requested: true },
              },
            },
          },
        },
        metadata: { providerId },
      });
      accountId = account.id;
      await this.prisma.provider.update({
        where: { id: providerId },
        data: { stripeAccountId: accountId },
      });
    }
    await this.stripeV2('POST', `/v2/core/accounts/${encodeURIComponent(accountId)}`, {
      defaults: {
        profile: { product_description: PROVIDER_PAYOUT_DESCRIPTION },
      },
    });
    const link = await this.stripeV2<{ url: string }>('POST', '/v2/core/account_links', {
      account: accountId,
      use_case: {
        type: 'account_onboarding',
        account_onboarding: {
          refresh_url: refreshUrl,
          return_url: returnUrl,
        },
      },
    });
    return { url: link.url, stripeAccountId: accountId };
  }

  async connectStatus(providerId: string) {
    const provider = await this.prisma.provider.findUnique({
      where: { id: providerId },
      select: { stripeAccountId: true },
    });
    if (!provider?.stripeAccountId || !this.stripeKey()) {
      return { connected: false, payoutsEnabled: false, stripeAccountId: provider?.stripeAccountId ?? null };
    }
    const account = await this.stripeV2<{
      configuration?: {
        recipient?: {
          capabilities?: {
            stripe_balance?: { stripe_transfers?: { status?: string } };
          };
        };
      };
    }>(
      'GET',
      `/v2/core/accounts/${encodeURIComponent(provider.stripeAccountId)}?include=configuration.recipient`,
    );
    const status =
      account.configuration?.recipient?.capabilities?.stripe_balance?.stripe_transfers?.status;
    return {
      connected: true,
      payoutsEnabled: status === 'active',
      stripeAccountId: provider.stripeAccountId,
    };
  }

  async transferPayout(payoutId: string) {
    const stripe = this.stripe();
    if (!stripe) throw new BadRequestException('Stripe is not configured on the server.');
    const payout = await this.prisma.payout.findUnique({
      where: { id: payoutId },
      include: { provider: true },
    });
    if (!payout) throw new BadRequestException('Payout not found');
    if (!payout.provider.stripeAccountId) {
      throw new BadRequestException('Driver has not completed Stripe onboarding.');
    }
    const currency = (await this.settings.getPlatformCurrency()).code.toLowerCase();
    const transfer = await stripe.transfers.create({
      amount: Math.round(Number(payout.amount) * 100),
      currency,
      destination: payout.provider.stripeAccountId,
      metadata: { payoutId },
    });
    return transfer.id;
  }

  async lookupVehicle(registration: string) {
    const plate = registration.replace(/\s+/g, '').toUpperCase();
    if (plate.length < 2) throw new BadRequestException('Enter a registration');
    const [baseSetting, keySetting] = await Promise.all([
      this.settings.get(PLATFORM_SETTINGS_KEYS.VEHICLE_LOOKUP_BASE_URL),
      this.settings.get(PLATFORM_SETTINGS_KEYS.VEHICLE_LOOKUP_API_KEY),
    ]);
    const base = readSettingString(baseSetting) || DEFAULT_VEHICLE_LOOKUP_BASE_URL;
    const key = readSettingString(keySetting);
    if (!key) {
      throw new BadRequestException(
        'Vehicle lookup is not configured. Add the API key in admin settings under Integrations.',
      );
    }
    let url: URL;
    try {
      url = buildVehicleLookupUrl(base, key, plate);
    } catch {
      throw new BadRequestException('Vehicle lookup URL is invalid. Check the URL in admin settings.');
    }
    let res: Response;
    try {
      res = await fetch(url, { signal: AbortSignal.timeout(12_000) });
    } catch (error) {
      this.logger.warn(`Vehicle lookup request failed: ${error instanceof Error ? error.name : 'unknown'}`);
      throw new BadRequestException('Vehicle lookup failed. Enter the details manually.');
    }
    if (!res.ok) {
      this.logger.warn(`Vehicle lookup failed ${res.status}`);
      if (res.status === 401 || res.status === 403) {
        throw new BadRequestException('Vehicle lookup API key was rejected. Check the key in admin settings.');
      }
      throw new BadRequestException('Vehicle lookup failed. Check the registration or enter the details manually.');
    }
    const body = (await res.json()) as unknown;
    const mapped = mapVehicleLookup(plate, body);
    if (!mapped.make) {
      throw new BadRequestException('No vehicle found for that registration. Enter the details manually.');
    }
    return mapped;
  }
}

const customerInvoiceInclude = {
  job: {
    select: {
      jobNumber: true,
      pickupAddress: true,
      dropoffAddress: true,
      completedAt: true,
      serviceCategory: { select: { name: true, slug: true, icon: true } },
      vehicle: {
        select: { make: true, model: true, year: true, plateNumber: true, color: true },
      },
      provider: { select: { user: { select: { fullName: true } } } },
    },
  },
  payment: { select: { method: true, status: true, paidAt: true } },
  customer: { select: { user: { select: { fullName: true, email: true, phone: true } } } },
} satisfies Prisma.InvoiceInclude;

function readSettingString(value: unknown): string {
  if (typeof value === 'string') return value.trim();
  if (typeof value === 'number') return String(value);
  return '';
}

function buildVehicleLookupUrl(base: string, apiKey: string, plate: string): URL {
  const url = new URL(base.trim());
  for (const param of ['apikey', 'vrm', 'registration']) {
    url.searchParams.delete(param);
  }
  url.searchParams.set('apikey', apiKey);
  url.searchParams.set('vrm', plate);
  return url;
}

function mapVehicleLookup(plate: string, body: unknown) {
  const record = asRecord(body);
  const data = asRecord(record?.data) ?? record ?? {};
  const rawModel = pickString(data, ['model', 'Model']);
  const explicitTransmission = pickString(data, ['transmission', 'Transmission']);
  const { model, transmission } = splitTransmission(rawModel, explicitTransmission);
  return {
    plateNumber: pickString(data, ['registrationNumber', 'RegistrationNumber', 'vrm', 'VRM']) || plate,
    make: titleCase(pickString(data, ['make', 'Make'])),
    model: titleCase(model),
    year: Number(data.year ?? data.yearOfManufacture ?? data.YearOfManufacture ?? 0) || null,
    fuelType: normalizeFuel(pickString(data, ['fuelType', 'fuel', 'FuelType'])),
    transmission,
    vehicleType: normalizeVehicleType(data),
    color: titleCase(pickString(data, ['colour', 'color', 'Colour'])),
    engineCapacity: pickString(data, [
      'engineCapacity',
      'EngineCapacity',
      'engineSize',
      'EngineSize',
      'cylinderCapacity',
      'CylinderCapacity',
    ]),
  };
}

function asRecord(value: unknown): Record<string, unknown> | null {
  if (!value || typeof value !== 'object' || Array.isArray(value)) return null;
  return value as Record<string, unknown>;
}

function pickString(data: Record<string, unknown>, keys: string[]): string {
  for (const key of keys) {
    const value = data[key];
    if (typeof value === 'string' && value.trim()) return value.trim();
    if (typeof value === 'number' && Number.isFinite(value)) return String(value);
  }
  return '';
}

function normalizeFuel(raw: string): 'petrol' | 'diesel' | 'electric' | null {
  const value = raw.toLowerCase();
  if (!value) return null;
  if (value.includes('hybrid')) return value.includes('diesel') ? 'diesel' : 'petrol';
  if (value.includes('diesel')) return 'diesel';
  if (value.includes('petrol') || value.includes('gasoline')) return 'petrol';
  if (value.includes('electric')) return 'electric';
  return null;
}

function splitTransmission(model: string, explicit: string): { model: string; transmission: 'manual' | 'auto' | null } {
  const source = `${explicit} ${model}`.toLowerCase();
  let transmission: 'manual' | 'auto' | null = null;
  if (/\bmanual\b/.test(source)) transmission = 'manual';
  else if (/\bauto(matic)?\b/.test(source)) transmission = 'auto';
  const cleaned = model.replace(/\b(automatic|auto|manual)\b/gi, '').replace(/\s{2,}/g, ' ').trim();
  return { model: cleaned || model.trim(), transmission };
}

function normalizeVehicleType(data: Record<string, unknown>): 'car' | 'motorcycle' {
  const approval = pickString(data, ['typeApproval', 'TypeApproval']).toUpperCase();
  const wheelplan = pickString(data, ['wheelplan', 'Wheelplan']).toUpperCase();
  const body = pickString(data, ['bodyType', 'BodyType', 'vehicleType']).toLowerCase();
  if (approval.startsWith('L') || body.includes('motorcycle') || body.includes('moped') || wheelplan.includes('2 WHEEL')) {
    return 'motorcycle';
  }
  return 'car';
}

function titleCase(value: string): string {
  if (!value) return '';
  return value
    .split(/\s+/)
    .filter(Boolean)
    .map((word) => {
      if (/^[A-Z0-9]{1,4}$/.test(word)) return word;
      const lower = word.toLowerCase();
      return lower.charAt(0).toUpperCase() + lower.slice(1);
    })
    .join(' ');
}
