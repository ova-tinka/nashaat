import assert from 'node:assert/strict';
import { test } from 'node:test';
import { matchesMacUsageReservation, parseMacCreditMarker, parseMacUsageRequest } from '../src/lib/mac-credit-marker.ts';

const owner = '10000000-0000-4000-8000-000000000001';
const requestId = '20000000-0000-4000-8000-000000000002';
const deviceKey = '30000000-0000-4000-8000-000000000003';
const marker = {
  userId: owner,
  requestId,
  deviceKey,
  minutes: 5,
  targets: { websites: true, apps: false },
  state: 'starting',
};

test('accepts a valid owner-bound countdown marker in starting and active states', () => {
  assert.equal(parseMacCreditMarker(JSON.stringify(marker), owner)?.requestId, requestId);
  assert.equal(parseMacCreditMarker(JSON.stringify({ ...marker, state: 'active' }), owner)?.state, 'active');
});

test('settlement recovery requires the local owner and server session to match', () => {
  const local = { userId: owner, sessionId: requestId };
  assert.equal(matchesMacUsageReservation(owner, local, { id: requestId }), true);
  assert.equal(matchesMacUsageReservation('other', local, { id: requestId }), false);
  assert.equal(matchesMacUsageReservation(owner, local, { id: deviceKey }), false);
  assert.equal(matchesMacUsageReservation(owner, null, { id: requestId }), false);
});

test('rejects malformed, cross-account, expired-shaped, or unbounded countdown markers', () => {
  for (const [raw, userId] of [
    ['{', owner],
    [JSON.stringify(marker), '40000000-0000-4000-8000-000000000004'],
    [JSON.stringify({ ...marker, requestId: 'invalid' }), owner],
    [JSON.stringify({ ...marker, minutes: 0 }), owner],
    [JSON.stringify({ ...marker, minutes: 1441 }), owner],
    [JSON.stringify({ ...marker, targets: { websites: false, apps: false } }), owner],
    [JSON.stringify({ ...marker, state: 'expired' }), owner],
  ]) assert.equal(parseMacCreditMarker(raw, userId), null);
  assert.equal(parseMacCreditMarker(null, owner), null);
});

test('recovers a valid durable Easy request and rejects invalid keys and budgets', () => {
  const request = { requestId, deviceKey, requestedMillis: 60000 };
  assert.deepEqual(parseMacUsageRequest(JSON.stringify(request)), request);
  for (const raw of [null, '{', JSON.stringify({ ...request, deviceKey: '' }),
    JSON.stringify({ ...request, requestId: 'bad' }), JSON.stringify({ ...request, requestedMillis: 0 })]) {
    assert.equal(parseMacUsageRequest(raw), null);
  }
});

test('reservation start reuses the durable request when UI state is stale', async () => {
  const { recoverOrCreateMacUsageRequest } = await import('../src/lib/mac-credit-marker.ts');
  const original = { requestId, deviceKey, requestedMillis: 60000 };
  let stored = JSON.stringify(original);
  const storage = { getItem: async () => stored, setItem: async (_key, value) => { stored = value; } };
  const result = await recoverOrCreateMacUsageRequest(storage, 'owner-key', () => ({
    requestId: '40000000-0000-4000-8000-000000000004', deviceKey, requestedMillis: 120000,
  }));
  assert.deepEqual(result, original);
  assert.deepEqual(JSON.parse(stored), original);
});

test('reservation start refuses to overwrite an invalid saved owner key', async () => {
  const { recoverOrCreateMacUsageRequest } = await import('../src/lib/mac-credit-marker.ts');
  let stored = '{';
  const storage = { getItem: async () => stored, setItem: async (_key, value) => { stored = value; } };
  await assert.rejects(recoverOrCreateMacUsageRequest(storage, 'owner-key', () => ({ requestId, deviceKey, requestedMillis: 60000 })));
  assert.equal(stored, '{');
});


test('an existing native reservation cannot create a replacement owner key', async () => {
  const { recoverOrCreateMacUsageRequest } = await import('../src/lib/mac-credit-marker.ts');
  const storage = { getItem: async () => null, setItem: async () => { throw new Error('unexpected write'); } };
  await assert.rejects(() => recoverOrCreateMacUsageRequest(storage, 'key', () => { throw new Error('unexpected creation'); }, true), /device key/);
});
