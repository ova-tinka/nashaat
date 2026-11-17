import type { MacCreditTargets } from './macos-blocking';

export type MacUsageRequest = { requestId: string; deviceKey: string; requestedMillis: number };

export function parseMacUsageRequest(raw: string | null): MacUsageRequest | null {
  try {
    const value = raw ? JSON.parse(raw) : null;
    const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
    if (!value || typeof value.requestId !== 'string' || !uuid.test(value.requestId)
      || typeof value.deviceKey !== 'string' || !uuid.test(value.deviceKey)
      || !Number.isSafeInteger(value.requestedMillis) || value.requestedMillis < 1000 || value.requestedMillis > 604800000) return null;
    return { requestId: value.requestId, deviceKey: value.deviceKey, requestedMillis: value.requestedMillis };
  } catch { return null; }
}

/** Read the durable owner before creating a request: component state can lag storage. */
export async function recoverOrCreateMacUsageRequest(
  storage: { getItem(key: string): Promise<string | null>; setItem(key: string, value: string): Promise<void> },
  key: string,
  create: () => MacUsageRequest,
  requireExisting = false,
): Promise<MacUsageRequest> {
  const raw = await storage.getItem(key);
  if (raw !== null) {
    const saved = parseMacUsageRequest(raw);
    if (!saved) throw new Error('The saved reservation key is invalid. Contact support before creating another reservation.');
    return saved;
  }
  if (requireExisting) throw new Error('The device key for this reservation is unavailable.');
  const request = create();
  await storage.setItem(key, JSON.stringify(request));
  return request;
}

export function matchesMacUsageReservation(userId: string, local: { userId: string; sessionId: string } | null | undefined, server: { id: string } | null): boolean {
  return !!local && local.userId === userId && !!server && server.id === local.sessionId;
}

export type MacCreditMarker = {
  userId: string;
  requestId: string;
  deviceKey: string;
  minutes: number;
  targets: MacCreditTargets;
  state: 'starting' | 'active';
};

export function parseMacCreditMarker(raw: string | null, userId: string): MacCreditMarker | null {
  if (!raw) return null;
  try {
    const value: unknown = JSON.parse(raw);
    if (!value || typeof value !== 'object') return null;
    const item = value as Partial<MacCreditMarker>;
    const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
    if (item.userId !== userId || typeof item.requestId !== 'string' || !uuid.test(item.requestId)
      || typeof item.deviceKey !== 'string' || !uuid.test(item.deviceKey)
      || typeof item.minutes !== 'number' || !Number.isFinite(item.minutes) || item.minutes <= 0 || item.minutes > 1440
      || !item.targets || typeof item.targets !== 'object'
      || typeof item.targets.websites !== 'boolean' || typeof item.targets.apps !== 'boolean'
      || (!item.targets.websites && !item.targets.apps)
      || (item.state !== 'starting' && item.state !== 'active')) return null;
    return item as MacCreditMarker;
  } catch { return null; }
}
