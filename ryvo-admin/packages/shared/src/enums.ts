export enum UserRole {
  CUSTOMER = 'customer',
  PROVIDER = 'provider',
  ADMIN = 'admin',
}

export enum UserStatus {
  ACTIVE = 'active',
  SUSPENDED = 'suspended',
  PENDING_VERIFICATION = 'pending_verification',
  DELETED = 'deleted',
}

export enum AdminRole {
  SUPER_ADMIN = 'super_admin',
  OPS = 'ops',
  FINANCE = 'finance',
  SUPPORT = 'support',
}

export enum VerificationStatus {
  PENDING = 'pending',
  APPROVED = 'approved',
  REJECTED = 'rejected',
  SUSPENDED = 'suspended',
}

export enum OnlineStatus {
  OFFLINE = 'offline',
  ONLINE = 'online',
  BUSY = 'busy',
}

export enum JobStatus {
  DRAFT = 'draft',
  SEARCHING = 'searching',
  MATCHED = 'matched',
  PROVIDER_EN_ROUTE = 'provider_en_route',
  ARRIVED = 'arrived',
  IN_PROGRESS = 'in_progress',
  COMPLETED = 'completed',
  CANCELLED_BY_CUSTOMER = 'cancelled_by_customer',
  CANCELLED_BY_PROVIDER = 'cancelled_by_provider',
  CANCELLED_BY_ADMIN = 'cancelled_by_admin',
  NO_PROVIDER_FOUND = 'no_provider_found',
  PAYMENT_PENDING = 'payment_pending',
}

export enum BookingType {
  INSTANT = 'instant',
  SCHEDULED = 'scheduled',
}

export enum JobType {
  TAXI = 'taxi',
  BIDDING = 'bidding',
  PARCEL = 'parcel',
}

export enum ParcelSize {
  SMALL = 'small',
  MEDIUM = 'medium',
  LARGE = 'large',
}

export enum JobBidKind {
  ACCEPT = 'accept',
  COUNTER = 'counter',
}

export enum JobBidStatus {
  PENDING = 'pending',
  ACCEPTED = 'accepted',
  REJECTED = 'rejected',
  EXPIRED = 'expired',
  WITHDRAWN = 'withdrawn',
}

export enum ServiceBusinessType {
  TAXI = 'taxi',
  PARCEL = 'parcel',
}

export enum SubscriptionPeriod {
  DAILY = 'daily',
  WEEKLY = 'weekly',
  MONTHLY = 'monthly',
}

export enum DriverSubscriptionStatus {
  PENDING = 'pending',
  ACTIVE = 'active',
  EXPIRED = 'expired',
  CANCELLED = 'cancelled',
}

export enum DriverMonetizationMode {
  COMMISSION = 'commission',
  SUBSCRIPTION = 'subscription',
}

export enum PaymentMethod {
  STRIPE = 'stripe',
  WALLET = 'wallet',
  CASH = 'cash',
}

export enum PaymentStatus {
  PENDING = 'pending',
  HELD = 'held',
  PAID = 'paid',
  FAILED = 'failed',
  REFUNDED = 'refunded',
}

export enum WalletTransactionType {
  TOP_UP = 'top_up',
  JOB_HOLD = 'job_hold',
  JOB_PAYMENT = 'job_payment',
  REFUND = 'refund',
  ADMIN_ADJUSTMENT = 'admin_adjustment',
  PAYOUT = 'payout',
}

export enum DocumentType {
  /** Driver license front side */
  LICENSE = 'license',
  INSURANCE = 'insurance',
  VEHICLE_REGISTRATION = 'vehicle_registration',
  /** Driver license back side (reused; avoids a schema migration) */
  ID_CARD = 'id_card',
  /** Identity selfie for manual match vs license */
  SELFIE = 'selfie',
  /** Proof of service equipment */
  EQUIPMENT_PROOF = 'equipment_proof',
}

/** Doc types required before a driver can become verification-approved. */
export const REQUIRED_KYC_DOC_TYPES = [
  DocumentType.LICENSE,
  DocumentType.ID_CARD,
  DocumentType.SELFIE,
  DocumentType.VEHICLE_REGISTRATION,
  DocumentType.INSURANCE,
] as const;

export enum DocumentReviewStatus {
  PENDING = 'pending',
  APPROVED = 'approved',
  REJECTED = 'rejected',
}

export enum VehicleTransmission {
  MANUAL = 'manual',
  AUTO = 'auto',
}

export enum VehicleFuelType {
  PETROL = 'petrol',
  DIESEL = 'diesel',
  ELECTRIC = 'electric',
}

export const VEHICLE_TRANSMISSIONS = Object.values(VehicleTransmission);
export const VEHICLE_FUEL_TYPES = Object.values(VehicleFuelType);

export enum JobOfferStatus {
  SENT = 'sent',
  ACCEPTED = 'accepted',
  REJECTED = 'rejected',
  EXPIRED = 'expired',
}

export enum PayoutStatus {
  PENDING = 'pending',
  PROCESSING = 'processing',
  PAID = 'paid',
}

export enum SupportTicketStatus {
  OPEN = 'open',
  IN_PROGRESS = 'in_progress',
  RESOLVED = 'resolved',
  CLOSED = 'closed',
}

export enum SupportPriority {
  LOW = 'low',
  MEDIUM = 'medium',
  HIGH = 'high',
  URGENT = 'urgent',
}

export enum NotificationChannel {
  PUSH = 'push',
  SMS = 'sms',
  EMAIL = 'email',
  IN_APP = 'in_app',
}

export enum CancelledBy {
  CUSTOMER = 'customer',
  PROVIDER = 'provider',
  ADMIN = 'admin',
  SYSTEM = 'system',
}

/** Active ride classes. Exact match against the driver's vehicle. */
export const RIDE_CLASS_SLUGS = {
  RYVO_GO: 'ryvo-go',
  COMFORT: 'comfort',
  XL: 'xl',
} as const;

export const PARCEL_CLASS_SLUGS = {
  PARCEL_BIKE: 'parcel-bike',
  PARCEL_CAR: 'parcel-car',
} as const;

/** Legacy roadside slugs stay so existing rows can be deactivated. */
export const SERVICE_SLUGS = {
  ...RIDE_CLASS_SLUGS,
  ...PARCEL_CLASS_SLUGS,
  JUMP_START: 'jump-start',
  FLAT_TIRE: 'flat-tire',
  FUEL_DELIVERY: 'fuel-delivery',
  TOWING: 'towing',
} as const;

export const PLATFORM_SETTINGS_KEYS = {
  MATCHING_RADIUS_KM: 'matching_radius_km',
  OFFER_TIMEOUT_SEC: 'offer_timeout_sec',
  SEARCH_TIMEOUT_SEC: 'search_timeout_sec',
  DEFAULT_COMMISSION_RATE: 'default_commission_rate',
  SURGE_ENABLED: 'surge_enabled',
  SURGE_MULTIPLIER: 'surge_multiplier',
  MAP_API_KEY: 'map_api_key',
  STRIPE_PUBLISHABLE_KEY: 'stripe_publishable_key',
  PROVIDER_OTP_ENABLED: 'provider_otp_enabled',
  PROVIDER_AGREEMENT_VERSION: 'provider_agreement_version',
  PAYMENT_WALLET_ENABLED: 'payment_wallet_enabled',
  PAYMENT_STRIPE_ENABLED: 'payment_stripe_enabled',
  PAYMENT_CASH_ENABLED: 'payment_cash_enabled',
  CUSTOMER_WALLET_ENABLED: 'customer_wallet_enabled',
  CUSTOMER_CANCEL_FEE_AFTER_MATCH: 'customer_cancel_fee_after_match',
  CUSTOMER_CANCEL_FEE_AFTER_ARRIVED: 'customer_cancel_fee_after_arrived',
  CUSTOMER_CANCEL_FEE_AFTER_START: 'customer_cancel_fee_after_start',
  PROVIDER_CANCEL_PENALTY_AFTER_ACCEPT: 'provider_cancel_penalty_after_accept',
  PROVIDER_CANCEL_PENALTY_AFTER_ARRIVED: 'provider_cancel_penalty_after_arrived',
  PROVIDER_CANCEL_PENALTY_AFTER_START: 'provider_cancel_penalty_after_start',
  VEHICLE_LOOKUP_BASE_URL: 'vehicle_lookup_base_url',
  VEHICLE_LOOKUP_API_KEY: 'vehicle_lookup_api_key',
  CURRENCY: 'currency',
  BID_WINDOW_SEC: 'bid_window_sec',
  BID_MIN_FARE_RATIO: 'bid_min_fare_ratio',
  BID_MAX_FARE_RATIO: 'bid_max_fare_ratio',
  BID_COUNTERS_ENABLED: 'bid_counters_enabled',
  PARCEL_OTP_ENABLED: 'parcel_otp_enabled',
  DRIVER_MONETIZATION_MODE: 'driver_monetization_mode',
  WHATSAPP_BOOKING_ENABLED: 'whatsapp_booking_enabled',
  WHATSAPP_WELCOME_TEXT: 'whatsapp_welcome_text',
} as const;

/** Currencies the platform can switch to. Clients receive only the active one. */
export const CURRENCY_CODES = ['GBP', 'EUR', 'USD'] as const;
export type CurrencyCode = (typeof CURRENCY_CODES)[number];

export interface PlatformCurrency {
  code: CurrencyCode;
  symbol: string;
  locale: string;
  decimals: number;
}

export const CURRENCIES: Record<CurrencyCode, PlatformCurrency> = {
  GBP: { code: 'GBP', symbol: '£', locale: 'en-GB', decimals: 2 },
  EUR: { code: 'EUR', symbol: '€', locale: 'en-GB', decimals: 2 },
  USD: { code: 'USD', symbol: '$', locale: 'en-US', decimals: 2 },
};

export const DEFAULT_CURRENCY_CODE: CurrencyCode = 'GBP';

export function resolveCurrency(value: unknown): PlatformCurrency {
  const raw = typeof value === 'string' ? value.trim().toUpperCase() : '';
  if (raw in CURRENCIES) return CURRENCIES[raw as CurrencyCode];
  return CURRENCIES[DEFAULT_CURRENCY_CODE];
}

export const DEFAULT_VEHICLE_LOOKUP_BASE_URL =
  'https://api.checkcardetails.co.uk/vehicledata/vehicleregistration';

export interface CustomerPaymentMethodsConfig {
  wallet: boolean;
  stripe: boolean;
  cash: boolean;
}

export interface CustomerAppConfig {
  stripePublishableKey: string | null;
  providerOtpEnabled: boolean;
  customerWalletEnabled: boolean;
  paymentMethods: CustomerPaymentMethodsConfig;
  currency: PlatformCurrency;
  bidMinFareRatio: number;
  bidMaxFareRatio: number;
  bidCountersEnabled: boolean;
  parcelOtpEnabled: boolean;
  whatsappBookingEnabled: boolean;
}

export interface ProviderAppConfig {
  stripePublishableKey: string | null;
  currency: PlatformCurrency;
  monetizationMode: DriverMonetizationMode;
  bidCountersEnabled: boolean;
  parcelOtpEnabled: boolean;
}

export interface ApiResponse<T = unknown> {
  success: boolean;
  data?: T;
  message?: string;
  meta?: PaginationMeta;
}

export interface PaginationMeta {
  page: number;
  limit: number;
  total: number;
  totalPages: number;
}

export interface PaginationQuery {
  page?: number;
  limit?: number;
  search?: string;
  sortBy?: string;
  sortOrder?: 'asc' | 'desc';
}

export const DEFAULT_PAGE = 1;
export const DEFAULT_LIMIT = 20;
export const MAX_LIMIT = 100;
