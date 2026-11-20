import type { DevicePlatform } from './devices';

const deviceProfileIdPattern = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const deviceIdPattern = deviceProfileIdPattern;
const legacyDeviceInstallationKey = 'bloom.device-registry.installation.v1';

export type DeviceIdentityStorage = {
  getItem(key: string): Promise<string | null>;
  setItem(key: string, value: string): Promise<void>;
  removeItem(key: string): Promise<void>;
};

export function deviceInstallationStorageKey(profileId: string) {
  if (!deviceProfileIdPattern.test(profileId)) throw new Error('A valid Bloom profile is required.');
  return `bloom.device-registry.installation.v1.${profileId.toLowerCase()}`;
}

export function verifiedTargetCount(focusSupported: boolean | null, count: number | null) {
  return focusSupported === true ? count : null;
}

export function sumKnownTargetCounts(...counts: (number | null)[]) {
  return counts.every((count) => typeof count === 'number' && Number.isFinite(count) && count >= 0)
    ? counts.reduce<number>((sum, count) => sum + (count ?? 0), 0)
    : null;
}

export function deviceRegistryErrorMessage(error: unknown) {
  const code = typeof error === 'object' && error !== null && 'code' in error
    ? String((error as { code?: unknown }).code ?? '')
    : '';
  if (code === 'PGRST202' || code === '42883') {
    return 'The device registry service is not installed on this Bloom server yet. Apply the device registry migration, then refresh.';
  }
  if (code === '42501') {
    return 'This profile is not authorized to sync its device list. Check the device access policy, then refresh.';
  }
  if (code === 'PGRST301' || code === '401') {
    return 'Your Bloom session expired. Sign in again, then refresh the device list.';
  }
  return 'Could not sync this profile’s device list. Check your connection and try again.';
}

export async function loadOrCreateDeviceInstallationId(profileId: string, storage: DeviceIdentityStorage, createId: () => string) {
  const key = deviceInstallationStorageKey(profileId);
  const stored = await storage.getItem(key);
  if (stored && deviceIdPattern.test(stored)) return stored;

  const legacy = await storage.getItem(legacyDeviceInstallationKey);
  if (legacy && deviceIdPattern.test(legacy)) {
    await storage.setItem(key, legacy);
    await storage.removeItem(legacyDeviceInstallationKey);
    return legacy;
  }

  const generated = createId();
  if (!deviceIdPattern.test(generated)) throw new Error('Could not create a valid installation identifier.');
  await storage.setItem(key, generated);
  return generated;
}

export function defaultDeviceName(platform: DevicePlatform, deviceId: string) {
  const names: Record<DevicePlatform, string> = {
    ios: 'iPhone or iPad',
    android: 'Android device',
    macos: 'Mac',
    windows: 'Windows PC',
    web: 'Web browser',
  };
  return `${names[platform]} · ${deviceId.slice(-6).toUpperCase()}`;
}

export function detectDevicePlatform(platformOS: string, macDesktop: boolean): DevicePlatform {
  if (macDesktop) return 'macos';
  if (platformOS === 'ios' || platformOS === 'android' || platformOS === 'windows') return platformOS;
  return 'web';
}

export function isDeviceStale(lastSeenAt: string, now = Date.now()) {
  const timestamp = Date.parse(lastSeenAt);
  return !Number.isFinite(timestamp) || now - timestamp > 24 * 60 * 60 * 1000;
}
