import { coachAccess } from './coach-access.ts';

const user = '60000000-0000-0000-0000-000000000001';
const base = { enabled: true, providerApproved: true, modelVerified: false,
  model: 'test-model', apiKeyPresent: true, testMode: true, testUserId: user,
  testExpiresAt: new Date(Date.now() + 15 * 60 * 1000).toISOString() };

Deno.test('test mode permits only the selected account and fails closed without an ID', () => {
  const access = coachAccess(base);
  if (!access.enabled || !access.permits(user) || access.permits('60000000-0000-0000-0000-000000000002')) {
    throw new Error('Test account restriction failed');
  }
  if (coachAccess({ ...base, testUserId: '' }).enabled || coachAccess({ ...base, testUserId: 'invalid' }).enabled) {
    throw new Error('Missing or invalid test account enabled coaching');
  }
  if (coachAccess({ ...base, testExpiresAt: '' }).enabled
    || coachAccess({ ...base, testExpiresAt: new Date(Date.now() - 1000).toISOString() }).enabled
    || coachAccess({ ...base, testExpiresAt: new Date(Date.now() + 31 * 60 * 1000).toISOString() }).enabled) {
    throw new Error('Invalid test window enabled coaching');
  }
});

Deno.test('normal mode still requires model verification and provider consent', () => {
  if (coachAccess({ ...base, testMode: false }).enabled
    || coachAccess({ ...base, providerApproved: false }).enabled
    || coachAccess({ ...base, apiKeyPresent: false }).enabled) throw new Error('Coach enabled without approval');
  if (!coachAccess({ ...base, testMode: false, modelVerified: true }).permits(user)) {
    throw new Error('Verified normal mode failed');
  }
});
