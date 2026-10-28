/**
 * Landing in-page section links use hash anchors so they work on both
 * https://ryvo.arcadexit.com/ and https://ryvo.arcadexit.com/landing-page.
 * Privacy uses a clean path rewritten by middleware on every host.
 */
export const LANDING_HOME = '#home';
export const LANDING_PRIVACY = '/privacy-policy';
export const LANDING_TERMS = '/terms';
export const LANDING_CONTACT = '/contact';

export function landingSection(id: string) {
  return `#${id}`;
}
