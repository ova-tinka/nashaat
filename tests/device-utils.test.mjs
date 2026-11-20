import test from 'node:test';
import assert from 'node:assert/strict';
import { defaultDeviceName, detectDevicePlatform, deviceInstallationStorageKey, deviceRegistryErrorMessage, isDeviceStale, loadOrCreateDeviceInstallationId, sumKnownTargetCounts, verifiedTargetCount } from '../src/lib/device-utils.ts';

test('device installation identities are profile-scoped', () => {
  const first = deviceInstallationStorageKey('18000000-0000-0000-0000-000000000181');
  const second = deviceInstallationStorageKey('18000000-0000-0000-0000-000000000182');
  assert.notEqual(first, second);
  assert.equal(first, deviceInstallationStorageKey('18000000-0000-0000-0000-000000000181'));
  assert.throws(() => deviceInstallationStorageKey('invalid-profile-id'));
});

test('existing installation identity migrates once, then profiles receive independent identities', async () => {
  const legacyId = '28000000-0000-0000-0000-000000000281';
  const nextProfileId = '28000000-0000-0000-0000-000000000282';
  const storageValues = new Map([['bloom.device-registry.installation.v1', legacyId]]);
  const storage = {
    getItem: async (key) => storageValues.get(key) ?? null,
    setItem: async (key, value) => { storageValues.set(key, value); },
    removeItem: async (key) => { storageValues.delete(key); },
  };

  assert.equal(await loadOrCreateDeviceInstallationId('18000000-0000-0000-0000-000000000181', storage, () => '38000000-0000-0000-0000-000000000381'), legacyId);
  assert.equal(storageValues.has('bloom.device-registry.installation.v1'), false);
  assert.equal(await loadOrCreateDeviceInstallationId('18000000-0000-0000-0000-000000000182', storage, () => nextProfileId), nextProfileId);
  assert.notEqual(
    storageValues.get(deviceInstallationStorageKey('18000000-0000-0000-0000-000000000181')),
    storageValues.get(deviceInstallationStorageKey('18000000-0000-0000-0000-000000000182')),
  );
});

test('same-platform installations get distinct default names', () => {
  assert.notEqual(
    defaultDeviceName('macos', '18000000-0000-0000-0000-000000000181'),
    defaultDeviceName('macos', '18000000-0000-0000-0000-000000000182'),
  );
});

test('current device identity distinguishes native hosts from browser runtime', () => {
  assert.equal(detectDevicePlatform('ios', false), 'ios');
  assert.equal(detectDevicePlatform('android', false), 'android');
  assert.equal(detectDevicePlatform('web', true), 'macos');
  assert.equal(detectDevicePlatform('windows', false), 'windows');
  assert.equal(detectDevicePlatform('web', false), 'web');
});

test('device status becomes stale after 24 hours and malformed timestamps are stale', () => {
  const now = Date.parse('2026-11-18T12:00:00.000Z');
  assert.equal(isDeviceStale('2026-11-17T12:00:01.000Z', now), false);
  assert.equal(isDeviceStale('2026-11-17T11:59:59.000Z', now), true);
  assert.equal(isDeviceStale('not-a-timestamp', now), true);
});

test('unsupported focus status does not invent a selected target count', () => {
  assert.equal(verifiedTargetCount(false, 0), null);
  assert.equal(verifiedTargetCount(null, 4), null);
  assert.equal(verifiedTargetCount(true, 0), 0);
});

test('partial macOS target checks do not report an incomplete total as exact', () => {
  assert.equal(sumKnownTargetCounts(2, null), null);
  assert.equal(sumKnownTargetCounts(2, 3), 5);
  assert.equal(sumKnownTargetCounts(0, 0), 0);
});

test('device registry failures distinguish missing migration and access policy from connection errors', () => {
  assert.match(deviceRegistryErrorMessage({ code: 'PGRST202' }), /device registry migration/);
  assert.match(deviceRegistryErrorMessage({ code: '42883' }), /device registry migration/);
  assert.match(deviceRegistryErrorMessage({ code: '42501' }), /not authorized/);
  assert.match(deviceRegistryErrorMessage(new Error('network unavailable')), /Check your connection/);
});
