export const MAP_API_KEY_SETTING = 'map_api_key';
export const STRIPE_PK_SETTING = 'stripe_publishable_key';
export const VEHICLE_LOOKUP_BASE_URL_SETTING = 'vehicle_lookup_base_url';
export const VEHICLE_LOOKUP_API_KEY_SETTING = 'vehicle_lookup_api_key';
export const DEFAULT_VEHICLE_LOOKUP_BASE_URL =
  'https://api.checkcardetails.co.uk/vehicledata/vehicleregistration';

export const SEARCH_TIMEOUT_SEC_SETTING = 'search_timeout_sec';

export const PAYMENT_WALLET_SETTING = 'payment_wallet_enabled';
export const PAYMENT_STRIPE_SETTING = 'payment_stripe_enabled';
export const PAYMENT_CASH_SETTING = 'payment_cash_enabled';
export const CUSTOMER_WALLET_SETTING = 'customer_wallet_enabled';
export const CURRENCY_SETTING = 'currency';

export const BILLING_TOGGLE_SETTINGS = [
  CUSTOMER_WALLET_SETTING,
  PAYMENT_WALLET_SETTING,
  PAYMENT_STRIPE_SETTING,
  PAYMENT_CASH_SETTING,
] as const;

export const SETTING_LABELS: Record<string, { label: string; description: string; type?: 'number' | 'boolean' | 'text' | 'secret' }> = {
  [CURRENCY_SETTING]: {
    label: 'Platform currency',
    description: 'Currency shown and charged across the admin, customer app, and driver app. Currently pounds for the UK. Changing this does not convert existing balances.',
    type: 'text',
  },
  matching_radius_km: {
    label: 'Matching radius (km)',
    description: 'How far to search for online drivers when a customer requests a ride.',
    type: 'number',
  },
  offer_timeout_sec: {
    label: 'Offer timeout (seconds)',
    description: 'How long a driver has to accept a ride offer before it expires.',
    type: 'number',
  },
  [SEARCH_TIMEOUT_SEC_SETTING]: {
    label: 'Driver search timeout (seconds)',
    description:
      'How long the customer keeps waiting while we look for a driver (after payment) before showing "No drivers available". The system retries nearby drivers roughly every 10s until this time elapses.',
    type: 'number',
  },
  default_commission_rate: {
    label: 'Default commission rate',
    description: 'Platform fee as a decimal (e.g. 0.15 = 15%). Ignored for subscribed drivers when subscription mode is on.',
    type: 'number',
  },
  driver_monetization_mode: {
    label: 'Driver monetization',
    description: 'commission = take a percent of each trip. subscription = drivers pay daily/weekly/monthly to go online.',
    type: 'text',
  },
  bid_window_sec: {
    label: 'Bid window (seconds)',
    description: 'How long a driver bid stays visible to the rider.',
    type: 'number',
  },
  bid_min_fare_ratio: {
    label: 'Minimum bid vs suggested fare',
    description: 'Lowest allowed offer as a fraction of the suggested fare (0.5 = 50%).',
    type: 'number',
  },
  bid_max_fare_ratio: {
    label: 'Maximum bid vs suggested fare',
    description: 'Highest allowed offer as a fraction of the suggested fare (2 = 200%).',
    type: 'number',
  },
  bid_counters_enabled: {
    label: 'Allow driver counter offers',
    description: 'Drivers can bid a different amount instead of only accepting the rider’s price.',
    type: 'boolean',
  },
  parcel_otp_enabled: {
    label: 'Parcel recipient OTP',
    description: 'Require a 4-digit OTP from the recipient before completing a parcel delivery.',
    type: 'boolean',
  },
  whatsapp_booking_enabled: {
    label: 'WhatsApp booking',
    description: 'Let riders book Ride, Bid, or Parcel by messaging the Twilio WhatsApp number.',
    type: 'boolean',
  },
  whatsapp_welcome_text: {
    label: 'WhatsApp welcome text',
    description: 'First message sent when someone says hi on WhatsApp.',
    type: 'text',
  },
  surge_enabled: {
    label: 'Surge pricing enabled',
    description: 'Enable surge multiplier during high demand.',
    type: 'boolean',
  },
  surge_multiplier: {
    label: 'Surge multiplier',
    description: 'Fare multiplier when surge is active (e.g. 1.5).',
    type: 'number',
  },
  [MAP_API_KEY_SETTING]: {
    label: 'Google Maps API key',
    description: 'Used for Live Ops map and admin location views. Enable Maps JavaScript API in Google Cloud Console.',
    type: 'secret',
  },
  [STRIPE_PK_SETTING]: {
    label: 'Stripe publishable key',
    description: 'The pk_live_... or pk_test_... key from your Stripe dashboard. Sent to the mobile app so it can present the Stripe Payment Sheet — this key is safe to expose publicly.',
    type: 'secret',
  },
  provider_otp_enabled: {
    label: 'Driver registration OTP',
    description: 'When enabled, new drivers must verify their phone via SMS OTP after signing up. When disabled, drivers go straight to KYC after registration.',
    type: 'boolean',
  },
  provider_agreement_version: {
    label: 'Driver agreement version',
    description: 'Bump this string when the driver agreement text changes. Drivers must re-accept the new version before using the app.',
    type: 'text',
  },
  [CUSTOMER_WALLET_SETTING]: {
    label: 'Customer wallet feature',
    description: 'Show wallet tab, balance, and top-up in the customer app. Disabling hides all wallet UI.',
    type: 'boolean',
  },
  [PAYMENT_WALLET_SETTING]: {
    label: 'Wallet payments',
    description: 'Allow customers to pay for jobs using their in-app wallet balance. Requires customer wallet to be enabled.',
    type: 'boolean',
  },
  [PAYMENT_STRIPE_SETTING]: {
    label: 'Card payments (Stripe)',
    description: 'Allow customers to pay with credit/debit cards via Stripe Payment Sheet.',
    type: 'boolean',
  },
  [PAYMENT_CASH_SETTING]: {
    label: 'Cash payments',
    description: 'Allow customers to choose pay-with-cash at service time. No funds are held upfront.',
    type: 'boolean',
  },
  customer_cancel_fee_after_match: {
    label: 'Customer cancel fee after match',
    description: 'Amount charged to the customer if they cancel after a driver accepts. Searching/pre-match stays £0.',
    type: 'number',
  },
  customer_cancel_fee_after_arrived: {
    label: 'Customer cancel fee after arrival',
    description: 'Amount charged if the customer cancels after the driver marks arrived.',
    type: 'number',
  },
  customer_cancel_fee_after_start: {
    label: 'Customer cancel fee after start',
    description: 'Amount charged if the customer cancels after the job timer has started.',
    type: 'number',
  },
  provider_cancel_penalty_after_accept: {
    label: 'Driver cancel penalty after accept',
    description: 'Penalty deducted from the driver if they cancel after accepting a job.',
    type: 'number',
  },
  provider_cancel_penalty_after_arrived: {
    label: 'Driver cancel penalty after arrival',
    description: 'Penalty deducted if the driver cancels after marking arrived.',
    type: 'number',
  },
  [VEHICLE_LOOKUP_BASE_URL_SETTING]: {
    label: 'Vehicle lookup API URL',
    description:
      'Check Car Details registration endpoint. The server adds the plate as vrm and the key as apikey. Do not put the key in the URL.',
    type: 'text',
  },
  [VEHICLE_LOOKUP_API_KEY_SETTING]: {
    label: 'Vehicle lookup API key',
    description: 'API key from checkcardetails.co.uk. Required before Find my vehicle works in the customer app.',
    type: 'secret',
  },
  provider_cancel_penalty_after_start: {
    label: 'Driver cancel penalty after start',
    description: 'Penalty deducted if the driver cancels after the job has started.',
    type: 'number',
  },
};
