import { unlockHandler } from './parent-pin.ts';

const parent = '50000000-0000-0000-0000-000000000001';
const child = '50000000-0000-0000-0000-000000000002';
const device = '50000000-0000-0000-0000-000000000003';
const input = { device_id: device, device_secret: 'a'.repeat(64), pin: '123456' };

function assert(value: unknown, message: string): asserts value {
  if (!value) throw new Error(message);
}

function request(token?: string) {
  return new Request('http://localhost/', {
    method: 'POST',
    headers: { 'content-type': 'application/json', ...(token ? { authorization: `Bearer ${token}` } : {}) },
    body: JSON.stringify(input),
  });
}

Deno.test('retired parent PIN endpoint returns 410 and never issues a parent session', async () => {
  let issued = false;
  const handler = unlockHandler({
    authenticate: async () => child,
    verify: async () => parent,
    eligibleParent: async () => ({ id: parent, email: 'parent@example.invalid', app_metadata: {} }),
    issueSession: async () => {
      issued = true;
      return { user_id: parent, access_token: 'parent-access', refresh_token: 'parent-refresh' };
    },
  });
  const response = await handler(request('child'));
  assert(response.status === 410, `Expected 410, got ${response.status}`);
  assert(response.headers.get('cache-control') === 'no-store', 'Expected no-store cache-control');
  assert(!issued, 'Retired PIN endpoint must never issue a session');
  const payload = await response.json() as { error?: string };
  assert(typeof payload.error === 'string' && payload.error.includes('retired'), 'Expected retired message');
});
