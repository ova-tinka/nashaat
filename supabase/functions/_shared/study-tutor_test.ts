import { studyTutorHandler, type StudyTutorDependencies } from './study-tutor.ts';

function assertEquals<T>(actual: T, expected: T) {
  if (actual !== expected) throw new Error(`Expected ${String(expected)}, got ${String(actual)}`);
}

type QuotaEvent = { requestId: string; profileId: string; status: 'pending' | 'completed' | 'failed' | 'cleared'; createdAt: number };
type MessageRow = { requestId: string; profileId: string; role: 'user' | 'assistant'; content: string };

function createStubStore() {
  const quotaEvents: QuotaEvent[] = [];
  const activeRequests = new Map<string, { profileId: string; itemId: string; status: 'pending' | 'completed' | 'failed' }>();
  const messages: MessageRow[] = [];
  const consentByProfile = new Map<string, boolean>([['profile-a', true], ['profile-b', true]]);
  const childByProfile = new Map<string, boolean>([['profile-a', false], ['profile-b', false]]);
  let clock = 1_000_000;

  function tokenToProfile(token: string) {
    if (token === 'token-a') return 'profile-a';
    if (token === 'token-b') return 'profile-b';
    return null;
  }

  function clearHistory(profileId: string) {
    for (let i = messages.length - 1; i >= 0; i -= 1) {
      if (messages[i].profileId === profileId) messages.splice(i, 1);
    }
    for (const [id, req] of activeRequests.entries()) {
      if (req.profileId === profileId) activeRequests.delete(id);
    }
    for (const ev of quotaEvents) {
      if (ev.profileId === profileId && ev.status === 'pending') ev.status = 'cleared';
    }
  }

  function makeDeps(overrides: Partial<StudyTutorDependencies> = {}): StudyTutorDependencies {
    return {
      enabled: true,
      minorsApproved: false,
      authenticate: async (token) => tokenToProfile(token) !== null,
      begin: async (token, requestId, itemId) => {
        const profileId = tokenToProfile(token);
        if (!profileId || !consentByProfile.get(profileId)) {
          return { data: null, errorMessage: 'Study tutor consent and eligibility are required' };
        }
        if (activeRequests.has(requestId) || quotaEvents.some((ev) => ev.requestId === requestId)) {
          return { data: null, errorMessage: 'This AI request has already been used' };
        }
        const dayCount = quotaEvents.filter((ev) => ev.profileId === profileId && ev.createdAt > clock - 86_400_000).length;
        const minCount = quotaEvents.filter((ev) => ev.profileId === profileId && ev.createdAt > clock - 60_000).length;
        if (dayCount >= 10 || minCount >= 2) {
          return { data: null, errorMessage: 'AI request limit reached' };
        }
        if (quotaEvents.some((ev) => ev.profileId === profileId && ev.status === 'pending' && ev.createdAt > clock - 120_000)) {
          return { data: null, errorMessage: 'An AI request is already running' };
        }
        quotaEvents.push({ requestId, profileId, status: 'pending', createdAt: clock });
        activeRequests.set(requestId, { profileId, itemId, status: 'pending' });
        return { data: { is_child: Boolean(childByProfile.get(profileId)), item: { title: 'Algebra', notes: 'Linear equations' } } };
      },
      loadMemory: async () => [],
      finish: async (requestId, prompt, answer) => {
        const ev = quotaEvents.find((item) => item.requestId === requestId);
        const req = activeRequests.get(requestId);
        if (!ev) throw new Error('Study tutor request is unavailable');
        if (ev.status === 'cleared' || !req) return { status: 'cleared' };
        if (!consentByProfile.get(ev.profileId)) {
          ev.status = 'failed';
          req.status = 'failed';
          throw new Error('Study tutor consent was withdrawn');
        }
        ev.status = 'completed';
        req.status = 'completed';
        messages.push({ requestId, profileId: ev.profileId, role: 'user', content: prompt });
        messages.push({ requestId, profileId: ev.profileId, role: 'assistant', content: answer });
        return { status: 'answered' };
      },
      fail: async (requestId) => {
        const ev = quotaEvents.find((item) => item.requestId === requestId);
        const req = activeRequests.get(requestId);
        if (ev && ev.status === 'pending') ev.status = 'failed';
        if (req && req.status === 'pending') req.status = 'failed';
      },
      generate: async () => ({
        answer: 'A linear equation has constant rate of change.',
        answer_scope: 'general',
        uncertainty: 'General explanation only.',
      }),
      ...overrides,
    };
  }

  return {
    quotaEvents,
    messages,
    consentByProfile,
    childByProfile,
    advanceClock: (ms: number) => { clock += ms; },
    clearHistory,
    makeDeps,
  };
}

function makeRequest(token: string, requestId: string, prompt = 'Explain linear equations') {
  return new Request('http://localhost/bloom-study-tutor', {
    method: 'POST',
    headers: { authorization: `Bearer ${token}`, 'content-type': 'application/json' },
    body: JSON.stringify({ request_id: requestId, item_id: '11111111-1111-4111-8111-111111111111', prompt }),
  });
}

Deno.test('clearing removes messages, preserves quota, and drops an in-flight answer without restoring history', async () => {
  const store = createStubStore();
  let releaseProvider!: () => void;
  const providerWait = new Promise<void>((resolve) => { releaseProvider = resolve; });

  const handler = studyTutorHandler(store.makeDeps({
    generate: async () => {
      await providerWait;
      return { answer: 'Late answer after clear', answer_scope: 'general', uncertainty: 'General only.' };
    },
  }));

  const req1 = '00000000-0000-4000-8000-000000000001';
  const inFlight = handler(makeRequest('token-a', req1));
  await new Promise((resolve) => setTimeout(resolve, 10));

  store.clearHistory('profile-a');
  releaseProvider();

  const res1 = await inFlight;
  assertEquals(res1.status, 200);
  assertEquals((await res1.json()).status, 'cleared');
  assertEquals(store.messages.length, 0);
  assertEquals(store.quotaEvents.length, 1);

  // Second request within 1 minute succeeds (2/min limit), third is rejected because cleared request still counts!
  const fastHandler = studyTutorHandler(store.makeDeps());
  const req2 = '00000000-0000-4000-8000-000000000002';
  const req3 = '00000000-0000-4000-8000-000000000003';
  const res2 = await fastHandler(makeRequest('token-a', req2));
  assertEquals(res2.status, 200);
  const res2Body = await res2.json();
  assertEquals(res2Body.status, 'answered');
  assertEquals(res2Body.answer_scope, 'general');

  const res3 = await fastHandler(makeRequest('token-a', req3));
  assertEquals(res3.status, 429);
});

Deno.test('concurrent requests, duplicate request retries, consent checks, and profile isolation are enforced', async () => {
  const store = createStubStore();
  let releaseFirst!: () => void;
  const firstWait = new Promise<void>((resolve) => { releaseFirst = resolve; });

  const handler = studyTutorHandler(store.makeDeps({
    generate: async () => {
      await firstWait;
      return { answer: 'First answer', answer_scope: 'general', uncertainty: 'General only.' };
    },
  }));

  const reqA1 = '00000000-0000-4000-8000-000000000011';
  const reqA2 = '00000000-0000-4000-8000-000000000012';
  const reqB1 = '00000000-0000-4000-8000-000000000021';

  const pA1 = handler(makeRequest('token-a', reqA1));
  await new Promise((resolve) => setTimeout(resolve, 10));

  // Concurrent request for same profile A is rejected with 409.
  const resA2 = await handler(makeRequest('token-a', reqA2));
  assertEquals(resA2.status, 409);

  // Profile B is isolated and can run while Profile A is pending; clearing A does not clear B.
  const pB1 = handler(makeRequest('token-b', reqB1));
  await new Promise((resolve) => setTimeout(resolve, 10));
  store.clearHistory('profile-a');
  releaseFirst();

  const [resA1, resB1] = await Promise.all([pA1, pB1]);
  assertEquals((await resA1.json()).status, 'cleared');
  assertEquals((await resB1.json()).status, 'answered');
  assertEquals(store.messages.filter((m) => m.profileId === 'profile-a').length, 0);
  assertEquals(store.messages.filter((m) => m.profileId === 'profile-b').length, 2);

  // Retry with same request_id is rejected.
  const fastHandler = studyTutorHandler(store.makeDeps());
  const retryB = await fastHandler(makeRequest('token-b', reqB1));
  assertEquals(retryB.status, 409);

  // Consent check: profile A without consent is rejected.
  store.consentByProfile.set('profile-a', false);
  const noConsent = await fastHandler(makeRequest('token-a', '00000000-0000-4000-8000-000000000013'));
  assertEquals(noConsent.status, 403);

  // Child profile blocked when minorsApproved is false.
  store.consentByProfile.set('profile-a', true);
  store.childByProfile.set('profile-a', true);
  const childBlocked = await fastHandler(makeRequest('token-a', '00000000-0000-4000-8000-000000000014'));
  assertEquals(childBlocked.status, 403);
});
