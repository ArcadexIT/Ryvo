import { type ClassValue, clsx } from 'clsx';
import { twMerge } from 'tailwind-merge';
import { formatPlatformCurrency } from './currency';

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs));
}

export function formatCurrency(amount: number, currency?: string) {
  return formatPlatformCurrency(amount, currency);
}

export function formatDate(value: string | Date) {
  return new Intl.DateTimeFormat('en-MY', {
    dateStyle: 'medium',
    timeStyle: 'short',
  }).format(new Date(value));
}

/** Human-readable provider document labels for KYC review. */
export function formatDocumentType(docType: string) {
  switch (docType) {
    case 'license':
      return 'Driver License (Front)';
    case 'id_card':
      return 'Driver License (Back)';
    case 'vehicle_registration':
      return 'Vehicle Registration';
    case 'insurance':
      return 'Insurance Certificate';
    case 'selfie':
      return 'Identity Selfie';
    case 'equipment_proof':
      return 'Equipment Proof';
    default:
      return docType.replace(/_/g, ' ');
  }
}
