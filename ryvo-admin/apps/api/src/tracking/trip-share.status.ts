const LIVE_STATUSES = new Set([
  'matched',
  'provider_en_route',
  'arrived',
  'in_progress',
]);

export function isLiveShareStatus(status: string) {
  return LIVE_STATUSES.has(status);
}

export function isTerminalShareStatus(status: string) {
  return (
    status === 'completed' ||
    status === 'no_provider_found' ||
    status.startsWith('cancelled')
  );
}
