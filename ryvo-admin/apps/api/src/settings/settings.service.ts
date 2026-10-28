import { BadRequestException, Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import {
  CURRENCIES,
  CustomerAppConfig,
  DriverMonetizationMode,
  PLATFORM_SETTINGS_KEYS,
  PlatformCurrency,
  ProviderAppConfig,
  resolveCurrency,
} from '@ryvo/shared';

@Injectable()
export class SettingsService {
  constructor(private prisma: PrismaService) {}

  async get(key: string) {
    const setting = await this.prisma.platformSetting.findUnique({ where: { key } });
    return setting?.value;
  }

  async getAll() {
    return this.prisma.platformSetting.findMany();
  }

  async set(key: string, value: unknown, updatedBy?: string) {
    if (key === PLATFORM_SETTINGS_KEYS.CURRENCY) {
      const code = typeof value === 'string' ? value.trim().toUpperCase() : '';
      if (!(code in CURRENCIES)) {
        throw new BadRequestException('Unsupported currency');
      }
      value = code;
    }
    return this.prisma.platformSetting.upsert({
      where: { key },
      update: { value: value as object, updatedBy: updatedBy ?? null },
      create: { key, value: value as object, updatedBy },
    });
  }

  private isTruthy(val: unknown, defaultValue = true): boolean {
    if (val === false || val === 'false') return false;
    if (val === true || val === 'true') return true;
    return defaultValue;
  }

  async isSurgeEnabled() {
    const val = await this.get(PLATFORM_SETTINGS_KEYS.SURGE_ENABLED);
    return this.isTruthy(val, false);
  }

  async getSurgeMultiplier() {
    const val = await this.get(PLATFORM_SETTINGS_KEYS.SURGE_MULTIPLIER);
    const n = Number(val ?? 1);
    if (!Number.isFinite(n) || n <= 0) return 1;
    return n;
  }

  async isAdminAlertEnabled(key: string) {
    return this.isTruthy(await this.get(key), true);
  }

  async getMatchingRadiusKm() {
    const val = await this.get(PLATFORM_SETTINGS_KEYS.MATCHING_RADIUS_KM);
    return Number(val ?? 15);
  }

  async getOfferTimeoutSec() {
    const val = await this.get(PLATFORM_SETTINGS_KEYS.OFFER_TIMEOUT_SEC);
    return Number(val ?? 30);
  }

  /** How long to keep searching for a provider before giving up (seconds). */
  async getSearchTimeoutSec() {
    const val = await this.get(PLATFORM_SETTINGS_KEYS.SEARCH_TIMEOUT_SEC);
    const n = Number(val ?? 60);
    return Number.isFinite(n) && n > 0 ? n : 60;
  }

  async getDefaultCommissionRate() {
    const val = await this.get(PLATFORM_SETTINGS_KEYS.DEFAULT_COMMISSION_RATE);
    return Number(val ?? 0.15);
  }

  async isProviderOtpEnabled() {
    const val = await this.get(PLATFORM_SETTINGS_KEYS.PROVIDER_OTP_ENABLED);
    return this.isTruthy(val, true);
  }

  async getProviderAgreementVersion(): Promise<string> {
    const val = await this.get(PLATFORM_SETTINGS_KEYS.PROVIDER_AGREEMENT_VERSION);
    if (typeof val === 'string' && val.trim()) return val.trim();
    if (typeof val === 'number') return String(val);
    return '1';
  }

  async isCustomerWalletEnabled() {
    const val = await this.get(PLATFORM_SETTINGS_KEYS.CUSTOMER_WALLET_ENABLED);
    return this.isTruthy(val, false);
  }

  async isPaymentWalletEnabled() {
    if (!(await this.isCustomerWalletEnabled())) return false;
    const val = await this.get(PLATFORM_SETTINGS_KEYS.PAYMENT_WALLET_ENABLED);
    return this.isTruthy(val, false);
  }

  async isPaymentStripeEnabled() {
    const val = await this.get(PLATFORM_SETTINGS_KEYS.PAYMENT_STRIPE_ENABLED);
    return this.isTruthy(val, true);
  }

  async isPaymentCashEnabled() {
    const val = await this.get(PLATFORM_SETTINGS_KEYS.PAYMENT_CASH_ENABLED);
    return this.isTruthy(val, false);
  }

  async getNumber(key: string, fallback = 0) {
    const val = await this.get(key);
    const n = Number(val ?? fallback);
    return Number.isFinite(n) ? n : fallback;
  }

  async getCustomerCancelFee(status: string) {
    if (status === 'arrived') {
      return this.getNumber(PLATFORM_SETTINGS_KEYS.CUSTOMER_CANCEL_FEE_AFTER_ARRIVED);
    }
    if (status === 'in_progress') {
      return this.getNumber(PLATFORM_SETTINGS_KEYS.CUSTOMER_CANCEL_FEE_AFTER_START);
    }
    if (status === 'matched' || status === 'provider_en_route') {
      return this.getNumber(PLATFORM_SETTINGS_KEYS.CUSTOMER_CANCEL_FEE_AFTER_MATCH);
    }
    return 0;
  }

  async getProviderCancelPenalty(status: string) {
    if (status === 'arrived') {
      return this.getNumber(PLATFORM_SETTINGS_KEYS.PROVIDER_CANCEL_PENALTY_AFTER_ARRIVED);
    }
    if (status === 'in_progress') {
      return this.getNumber(PLATFORM_SETTINGS_KEYS.PROVIDER_CANCEL_PENALTY_AFTER_START);
    }
    if (status === 'matched' || status === 'provider_en_route') {
      return this.getNumber(PLATFORM_SETTINGS_KEYS.PROVIDER_CANCEL_PENALTY_AFTER_ACCEPT);
    }
    return 0;
  }

  async getPlatformCurrency(): Promise<PlatformCurrency> {
    const val = await this.get(PLATFORM_SETTINGS_KEYS.CURRENCY);
    return resolveCurrency(val);
  }

  async getBidWindowSec() {
    const n = await this.getNumber(PLATFORM_SETTINGS_KEYS.BID_WINDOW_SEC, 120);
    return n > 0 ? n : 120;
  }

  async getBidMinFareRatio() {
    const n = await this.getNumber(PLATFORM_SETTINGS_KEYS.BID_MIN_FARE_RATIO, 0.5);
    return n > 0 ? n : 0.5;
  }

  async getBidMaxFareRatio() {
    const n = await this.getNumber(PLATFORM_SETTINGS_KEYS.BID_MAX_FARE_RATIO, 2);
    return n > 0 ? n : 2;
  }

  async areBidCountersEnabled() {
    return this.isTruthy(await this.get(PLATFORM_SETTINGS_KEYS.BID_COUNTERS_ENABLED), true);
  }

  async isParcelOtpEnabled() {
    return this.isTruthy(await this.get(PLATFORM_SETTINGS_KEYS.PARCEL_OTP_ENABLED), true);
  }

  async getDriverMonetizationMode(): Promise<DriverMonetizationMode> {
    const val = await this.get(PLATFORM_SETTINGS_KEYS.DRIVER_MONETIZATION_MODE);
    return val === DriverMonetizationMode.SUBSCRIPTION
      ? DriverMonetizationMode.SUBSCRIPTION
      : DriverMonetizationMode.COMMISSION;
  }

  async isWhatsAppBookingEnabled() {
    return this.isTruthy(await this.get(PLATFORM_SETTINGS_KEYS.WHATSAPP_BOOKING_ENABLED), false);
  }

  async getWhatsAppWelcomeText() {
    const val = await this.get(PLATFORM_SETTINGS_KEYS.WHATSAPP_WELCOME_TEXT);
    if (typeof val === 'string' && val.trim()) return val.trim();
    return 'Hi, this is RYVO. Reply with Ride, Bid, or Parcel to book without the app.';
  }

  async getCustomerAppConfig(): Promise<CustomerAppConfig> {
    const [
      stripePublishableKey,
      providerOtpEnabled,
      customerWalletEnabled,
      wallet,
      stripe,
      cash,
      currency,
      bidMinFareRatio,
      bidMaxFareRatio,
      bidCountersEnabled,
      parcelOtpEnabled,
      whatsappBookingEnabled,
    ] = await Promise.all([
      this.get(PLATFORM_SETTINGS_KEYS.STRIPE_PUBLISHABLE_KEY),
      this.isProviderOtpEnabled(),
      this.isCustomerWalletEnabled(),
      this.isPaymentWalletEnabled(),
      this.isPaymentStripeEnabled(),
      this.isPaymentCashEnabled(),
      this.getPlatformCurrency(),
      this.getBidMinFareRatio(),
      this.getBidMaxFareRatio(),
      this.areBidCountersEnabled(),
      this.isParcelOtpEnabled(),
      this.isWhatsAppBookingEnabled(),
    ]);

    return {
      stripePublishableKey:
        typeof stripePublishableKey === 'string' && stripePublishableKey.trim()
          ? stripePublishableKey.trim()
          : null,
      providerOtpEnabled,
      customerWalletEnabled,
      paymentMethods: { wallet, stripe, cash },
      currency,
      bidMinFareRatio,
      bidMaxFareRatio,
      bidCountersEnabled,
      parcelOtpEnabled,
      whatsappBookingEnabled,
    };
  }

  async getProviderAppConfig(): Promise<ProviderAppConfig> {
    const [stripePublishableKey, currency, monetizationMode, bidCountersEnabled, parcelOtpEnabled] =
      await Promise.all([
        this.get(PLATFORM_SETTINGS_KEYS.STRIPE_PUBLISHABLE_KEY),
        this.getPlatformCurrency(),
        this.getDriverMonetizationMode(),
        this.areBidCountersEnabled(),
        this.isParcelOtpEnabled(),
      ]);
    return {
      stripePublishableKey:
        typeof stripePublishableKey === 'string' && stripePublishableKey.trim()
          ? stripePublishableKey.trim()
          : null,
      currency,
      monetizationMode,
      bidCountersEnabled,
      parcelOtpEnabled,
    };
  }
}
