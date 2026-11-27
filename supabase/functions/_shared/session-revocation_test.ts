import { extractJwtSessionId, revokeDeviceHandler, type RevokeDeviceDependencies } from './session-revocation.ts';

function assert(value: unknown, message: string): asserts value {
  if (!value) throw new Error(message);
}

function makeJwt(payload: Record<string, unknown>): string {
  const encode = (value: unknown) => btoa(JSON.stringify(value)).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
  return `${encode({ alg: 'HS256', typ: 'JWT' })}.${encode(payload)}.signature`;
}

function makeRequest(deviceId: string, token?: string) {
  return new Request('http://localhost/', {
    method: 'POST',
    headers: { 'content-type': 'application/json', ...(token ? { authorization: `Bearer ${token}` } : {}) },
    body: JSON.stringify({ device_id: deviceId }),
  });
}

Deno.test('extractJwtSessionId extracts valid UUID session_id and rejects malformed tokens', () => {
  const sid = '55000000-0000-0000-0000-000000000001';
  assert(extractJwtSessionId(makeJwt({ sub: 'user-1', session_id: sid })) === sid, 'Expected valid session_id');
  assert(extractJwtSessionId(makeJwt({ sub: 'user-1', session_id: 'not-a-uuid' })) === null, 'Expected null for invalid session_id');
  assert(extractJwtSessionId('invalid.token') === null, 'Expected null for malformed JWT');
});

Deno.test('revokeDeviceHandler rejects revoked or unauthenticated callers with 401', async () => {
  let called = false;
  const handler = revokeDeviceHandler({
    authenticate: async () => null,
    revokeDevice: async () => {
      called = true;
      return { sessionId: null };
    },
    invalidateAuthSession: async () => {},
  });
  const res = await handler(makeRequest('55100000-0000-0000-0000-000000000001', 'revoked-token'));
  assert(res.status === 401 && !called, 'Revoked token must be rejected before RPC');
});

Deno.test('revokeDeviceHandler invalidates only the revoked device session', async () => {
  const invalidated: Array<{ userId: string; sessionId: string }> = [];
  const deps: RevokeDeviceDependencies = {
    authenticate: async () => ({ userId: '00000000-0000-0000-0000-000000000551' }),
    revokeDevice: async () => ({ sessionId: '55000000-0000-0000-0000-000000000001' }),
    invalidateAuthSession: async (userId, sessionId) => {
      invalidated.push({ userId, sessionId });
    },
  };
  const res = await revokeDeviceHandler(deps)(makeRequest('55100000-0000-0000-0000-000000000001', 'active-token'));
  assert(res.status === 200, `Expected 200, got ${res.status}`);
  assert(invalidated.length === 1 && invalidated[0].sessionId === '55000000-0000-0000-0000-000000000001', 'Expected target session invalidation');
});

Deno.test('revokeDeviceHandler rejects foreign device IDs with 404 and skips session invalidation', async () => {
  let invalidated = false;
  const handler = revokeDeviceHandler({
    authenticate: async () => ({ userId: '00000000-0000-0000-0000-000000000552' }),
    revokeDevice: async () => {
      throw new Error('Device was not found');
    },
    invalidateAuthSession: async () => {
      invalidated = true;
    },
  });
  const res = await handler(makeRequest('55100000-0000-0000-0000-000000000001', 'active-token'));
  assert(res.status === 404 && !invalidated, 'Foreign device must return 404 without invalidating sessions');
});
