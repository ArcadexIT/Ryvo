/** Keep in sync with CURRENCIES in packages/shared/src/enums.ts. */
export const CURRENCY_OPTIONS = [
  { code: 'GBP', symbol: '£', locale: 'en-GB', decimals: 2 },
  { code: 'EUR', symbol: '€', locale: 'en-GB', decimals: 2 },
  { code: 'USD', symbol: '$', locale: 'en-US', decimals: 2 },
] as const;

export type AdminCurrencyCode = (typeof CURRENCY_OPTIONS)[number]['code'];

const DEFAULT_CURRENCY = CURRENCY_OPTIONS[0];

let activeCurrency: (typeof CURRENCY_OPTIONS)[number] = DEFAULT_CURRENCY;

function matchCurrency(value: unknown) {
  const code = typeof value === 'string' ? value.trim().toUpperCase() : '';
  return CURRENCY_OPTIONS.find((option) => option.code === code);
}

/** Point every admin money label at the platform currency loaded once in the dashboard layout. */
export function applyPlatformCurrency(value: unknown) {
  activeCurrency = matchCurrency(value) ?? DEFAULT_CURRENCY;
}

export function getActiveCurrencyCode() {
  return activeCurrency.code;
}

export function formatPlatformCurrency(amount: number, currency?: string) {
  const option = (currency ? matchCurrency(currency) : undefined) ?? activeCurrency;
  return new Intl.NumberFormat(option.locale, {
    style: 'currency',
    currency: option.code,
    minimumFractionDigits: option.decimals,
    maximumFractionDigits: option.decimals,
  }).format(amount);
}
