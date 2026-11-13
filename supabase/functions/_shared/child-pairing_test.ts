import { pairHandler, provisionHandler, type Identity, type PairDependencies, type ProvisionDependencies } from './child-pairing.ts';

const profile = '40000000-0000-0000-0000-000000000001';
const parent = '40000000-0000-0000-0000-000000000002';
const code = 'a'.repeat(64);
const identity: Identity = { id: profile, email: 'child@example.invalid', app_metadata: { bloom_managed_child: true, bloom_profile_id: profile } };
function assert(value: unknown, message: string): asserts value { if (!value) throw new Error(message); }
function post(body: unknown, token?: string) {
  return new Request('http://localhost/', { method: 'POST', headers: { 'content-type': 'application/json', ...(token ? { authorization: `Bearer ${token}` } : {}) }, body: JSON.stringify(body) });
}
function provision(overrides: Partial<ProvisionDependencies> = {}) {
  let created = false;
  const deps: ProvisionDependencies = {
    authenticate: async () => parent,
    authorize: async () => true,
    findIdentity: async () => created ? identity : null,
    createIdentity: async () => { created = true; return identity; },
    issueCode: async () => code,
    ...overrides,
  };
  return provisionHandler(deps);
}
function pair(overrides: Partial<PairDependencies> = {}) {
  let consumed = false;
  return pairHandler({
    consume: async (hash) => { assert(/^[0-9a-f]{64}$/.test(hash) && hash !== code, 'Raw code reached the database'); if (consumed) return null; consumed = true; return profile; },
    findIdentity: async () => identity,
    issueSession: async () => ({ user_id: profile, access_token: 'child-access', refresh_token: 'child-refresh' }),
    ...overrides,
  });
}

Deno.test('provision requires a parent and validates managed identity', async () => {
  assert((await provision()(post({ profile_id: profile }))).status === 401, 'Missing token accepted');
  assert((await provision({ authorize: async () => false })(post({ profile_id: profile }, 'parent'))).status === 403, 'Outsider provisioned');
  const bad = { ...identity, app_metadata: {} };
  assert((await provision({ findIdentity: async () => bad })(post({ profile_id: profile }, 'parent'))).status === 409, 'Unrelated account was adopted');
  const response = await provision()(post({ profile_id: profile }, 'parent'));
  assert(response.status === 200 && (await response.json()).code === code, 'Authorized parent did not get a code');
  assert(response.headers.get('cache-control') === 'no-store', 'Code response can be cached');
});

Deno.test('pairing consumes a hashed code once and issues only the child session', async () => {
  const handler = pair();
  const response = await handler(post({ code }));
  const value = await response.json();
  assert(response.status === 200 && value.access_token === 'child-access', 'Child session not returned');
  assert((await handler(post({ code }))).status === 400, 'Code was reusable');
  assert((await pair()(post({ code: 'bad' }))).status === 400, 'Malformed code accepted');
  const wrong = pair({ issueSession: async () => ({ user_id: parent, access_token: 'parent-access', refresh_token: 'parent-refresh' }) });
  const failed = await wrong(post({ code }));
  assert(failed.status === 503 && !(await failed.text()).includes('parent-access'), 'Parent session leaked');
});

Deno.test('request size and method are bounded', async () => {
  assert((await pair()(new Request('http://localhost/', { method: 'GET' }))).status === 405, 'Unexpected method accepted');
  assert((await pair()(post({ code: 'a'.repeat(3000) }))).status === 400, 'Oversized body accepted');
});
