import assert from 'node:assert/strict';
import { test } from 'node:test';
import {
  parseUsageReservationRecord,
  prepareOrRecoverUsageReservation,
  reconcileUsageReservation,
  resolveEnforcementConfirmation,
  settleUsageReservation,
} from '../src/lib/credit-session-lifecycle.ts';
import { deviceSupportMatrix } from '../src/lib/device-support-matrix.ts';

function memoryStorage(initial = {}) {
  const map = new Map(Object.entries(initial));
  return {
    async getItem(key) { return map.get(key) ?? null; },
    async setItem(key, value) { map.set(key, value); },
    async removeItem(key) { map.delete(key); },
  };
}

const userId = '11111111-1111-4111-8111-111111111111';
const requestId = '22222222-2222-4222-8222-222222222222';
const deviceKey = '33333333-3333-4333-8333-333333333333';
const sessionId = '44444444-4444-4444-8444-444444444444';
const key = `bloom-usage:${userId}`;

test('persists owning request before reservation and reuses it across retries', async () => {
  const storage = memoryStorage();
  const created = await prepareOrRecoverUsageReservation(
    storage,
    key,
    userId,
    () => ({ requestId, deviceKey, requestedMillis: 300_000 }),
    false,
  );
  assert.equal(created.requestId, requestId);
  assert.equal(created.deviceKey, deviceKey);
  assert.equal(created.state, 'pending');

  const retried = await prepareOrRecoverUsageReservation(
    storage,
    key,
    userId,
    () => ({
      requestId: '55555555-5555-4555-8555-555555555555',
      deviceKey: '66666666-6666-4666-8666-666666666666',
      requestedMillis: 600_000,
    }),
    false,
  );
  assert.equal(retried.requestId, requestId);
  assert.equal(retried.deviceKey, deviceKey);
});

test('migrates legacy stored reservation without userId and surfaces recovery_key_missing when key is lost', async () => {
  const legacy = parseUsageReservationRecord(JSON.stringify({ requestId, deviceKey, requestedMillis: 120_000 }), userId);
  assert.ok(legacy);
  assert.equal(legacy.userId, userId);

  const storage = memoryStorage();
  const outcome = await reconcileUsageReservation({
    storage,
    key,
    userId,
    nativeSession: { sessionId, userId },
    findServerSession: async () => ({ id: sessionId, settled_at: null }),
  });
  assert.equal(outcome.status, 'recovery_key_missing');
});

test('reconciles unsettled server session after local expiry and settles once', async () => {
  const storage = memoryStorage({
    [key]: JSON.stringify({ userId, requestId, deviceKey, requestedMillis: 300_000, sessionId, state: 'active' }),
  });
  const pendingOutcome = await reconcileUsageReservation({
    storage,
    key,
    userId,
    nativeSession: null,
    findServerSession: async () => ({ id: sessionId, settled_at: null }),
  });
  assert.equal(pendingOutcome.status, 'pending_server_settlement');
  assert.equal(pendingOutcome.serverSessionId, sessionId);

  let serverFinishCalls = 0;
  let clearedSession = '';
  const settled = await settleUsageReservation({
    storage,
    key,
    userId,
    getNativeSession: async () => null,
    closeNativeSession: async () => null,
    clearNativeSession: async (_u, id) => { clearedSession = id; },
    findServerSession: async () => ({ id: sessionId, settled_at: null }),
    finishServerSession: async () => { serverFinishCalls += 1; },
  });
  assert.equal(settled.settledSessionId, sessionId);
  assert.equal(serverFinishCalls, 1);
  assert.equal(clearedSession, sessionId);
  assert.equal(await storage.getItem(key), null);
});

test('reports actual enforcement confirmation and explicit unsupported platforms', () => {
  assert.equal(
    resolveEnforcementConfirmation({
      platform: 'macos',
      configured: true,
      authorized: true,
      active: true,
      providerHealthy: true,
      brokerAcknowledged: true,
      hideFailed: false,
    }).confirmed,
    true,
  );

  const hideFailed = resolveEnforcementConfirmation({
    platform: 'macos',
    configured: true,
    authorized: true,
    active: true,
    providerHealthy: true,
    brokerAcknowledged: true,
    hideFailed: true,
  });
  assert.equal(hideFailed.confirmed, false);
  assert.equal(hideFailed.status, 'degraded');

  const windowsStatus = resolveEnforcementConfirmation({
    platform: 'windows',
    configured: false,
    authorized: false,
    active: false,
  });
  assert.equal(windowsStatus.confirmed, false);
  assert.equal(windowsStatus.status, 'unsupported');
  assert.equal(deviceSupportMatrix.windows.appBlocking, 'unsupported');
  assert.equal(deviceSupportMatrix.macos.physicalVerification, 'open_device_verification');
});
