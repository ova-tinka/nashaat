import { unlockHandler, type UnlockDependencies } from './parent-pin.ts';

const parent = '50000000-0000-0000-0000-000000000001';
const child = '50000000-0000-0000-0000-000000000002';
const device = '50000000-0000-0000-0000-000000000003';
const input = { device_id: device, device_secret: 'a'.repeat(64), pin: '123456' };
function assert(value: unknown, message: string): asserts value { if (!value) throw new Error(message); }
function request(token?: string) {
  return new Request('http://localhost/', { method: 'POST', headers: { 'content-type': 'application/json', ...(token ? { authorization: `Bearer ${token}` } : {}) }, body: JSON.stringify(input) });
}
function handler(overrides: Partial<UnlockDependencies> = {}) {
  return unlockHandler({
    authenticate: async () => child,
    verify: async (actualChild) => { assert(actualChild === child, 'Unverified child identity supplied'); return parent; },
    eligibleParent: async () => ({ id: parent, email: 'parent@example.invalid', app_metadata: {} }),
    issueSession: async () => ({ user_id: parent, access_token: 'parent-access', refresh_token: 'parent-refresh' }),
    ...overrides,
  });
}

Deno.test('parent unlock requires an authenticated child and a verified PIN', async () => {
  assert((await handler()(request())).status === 401, 'Missing child token accepted');
  let issued = false;
  const denied = handler({ verify: async () => null, issueSession: async () => { issued = true; throw new Error('must not run'); } });
  assert((await denied(request('child'))).status === 401 && !issued, 'Bad PIN issued a session');
  const response = await handler()(request('child'));
  assert(response.status === 200 && (await response.json()).access_token === 'parent-access', 'Parent session not issued');
  assert(response.headers.get('cache-control') === 'no-store', 'Session can be cached');
});

Deno.test('parent unlock rejects ineligible or mismatched identities without leaking tokens', async () => {
  const ineligible = handler({ eligibleParent: async () => null });
  assert((await ineligible(request('child'))).status === 403, 'Ineligible parent accepted');
  const mismatch = handler({ issueSession: async () => ({ user_id: child, access_token: 'wrong-secret', refresh_token: 'wrong-refresh' }) });
  const response = await mismatch(request('child'));
  assert(response.status === 503 && !(await response.text()).includes('wrong-secret'), 'Wrong session leaked');
});
