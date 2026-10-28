import { landingSection } from './paths';

/** App Store listings are not live yet — those badges still scroll to the download section. */
export const STORE_LINKS = {
  customer: {
    appStore: landingSection('download'),
    playStore: 'https://play.google.com/store/apps/details?id=com.ryvo.customer',
  },
  provider: {
    appStore: landingSection('download'),
    playStore: 'https://play.google.com/store/apps/details?id=com.ryvo.driver',
  },
} as const;
