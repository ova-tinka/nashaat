import { readReflectionHandler, reflectionUncertainty, type ReadReflectionDependencies } from './read-reflection.ts';

const requestId = '61000000-0000-0000-0000-000000000001';
const itemId = '61000000-0000-0000-0000-000000000002';
function assert(value: unknown, message: string): asserts value { if (!value) throw new Error(message); }
function request() {
  return new Request('http://localhost/', { method: 'POST', headers: {
    authorization: 'Bearer test-token', 'content-type': 'application/json',
  }, body: JSON.stringify({ request_id: requestId, item_id: itemId }) });
}
function setup(overrides: Partial<ReadReflectionDependencies> = {}) {
  let generatedContext: unknown;
  let generated = 0;
  let failed = 0;
  let saved: { prompt: string; uncertainty: string } | null = null;
  const handler = readReflectionHandler({
    enabled: true,
    minorsApproved: true,
    authenticate: async () => true,
    begin: async () => ({ status: 'pending', is_child: false, reading: { title: 'A book', notes: 'A note' } }),
    loadMemory: async () => [{ domain: 'study', summary: 'Prefers short prompts.' }],
    finish: async (_id, prompt, uncertainty) => { saved = { prompt, uncertainty }; return saved; },
    fail: async () => { failed += 1; },
    generate: async (context) => { generated += 1; generatedContext = context; return { question: 'What would you like to revisit?' }; },
    ...overrides,
  });
  return { handler, counts: () => ({ generated, failed, saved, generatedContext }) };
}

Deno.test('reading prompt uses only the selected item and explicitly shared memory', async () => {
  const test = setup();
  const response = await test.handler(request());
  const body = await response.json();
  const counts = test.counts();
  assert(response.status === 200 && body.status === 'generated', `Prompt request did not complete: ${response.status} ${JSON.stringify(body)} ${JSON.stringify(counts)}`);
  assert(body.prompt === 'What would you like to revisit?' && body.uncertainty === reflectionUncertainty, 'Prompt label is missing');
  assert(counts.generated === 1 && counts.failed === 0 && counts.saved?.prompt === body.prompt, 'Prompt was not saved');
  assert(JSON.stringify(counts.generatedContext).includes('A book')
    && JSON.stringify(counts.generatedContext).includes('Prefers short prompts.'), 'Selected context was not passed to the provider');
  assert(!JSON.stringify(counts.generatedContext).includes(itemId), 'Persistent item ID reached the provider');
});

Deno.test('completed requests replay the saved prompt without calling the provider', async () => {
  const test = setup({ begin: async () => ({ status: 'completed', response: {
    prompt: 'What stood out?', uncertainty: reflectionUncertainty,
  } }) });
  const response = await test.handler(request());
  const body = await response.json();
  assert(response.status === 200 && body.prompt === 'What stood out?' && test.counts().generated === 0,
    'Completed request was not replayed safely');
});

Deno.test('child prompts stay blocked until provider review and failed requests are closed', async () => {
  const test = setup({ minorsApproved: false, begin: async () => ({ status: 'pending', is_child: true,
    reading: { title: 'A book', notes: '' } }) });
  assert((await test.handler(request())).status === 403 && test.counts().generated === 0 && test.counts().failed === 1,
    'Child prompt reached the provider before approval');
});

Deno.test('contact details and unsafe notes fail closed without provider disclosure', async () => {
  const personal = setup({ begin: async () => ({ status: 'pending', is_child: false,
    reading: { title: 'A book', notes: 'Contact me at reader@example.com' } }) });
  const response = await personal.handler(request());
  assert(response.status === 400 && personal.counts().generated === 0 && personal.counts().failed === 1,
    'Identifying notes reached the provider');

  const unsafe = setup({ begin: async () => ({ status: 'pending', is_child: false,
    reading: { title: 'A book', notes: 'I am thinking about self-harm' } }) });
  assert((await unsafe.handler(request())).status === 400 && unsafe.counts().generated === 0,
    'Unsafe notes reached the provider');
});

Deno.test('invalid model output and malformed memory fail and clear the pending request', async () => {
  const badOutput = setup({ generate: async () => ({ question: 'reader@example.com' }) });
  assert((await badOutput.handler(request())).status === 503 && badOutput.counts().failed === 1,
    'Invalid prompt was saved');
  const badMemory = setup({ loadMemory: async () => [{ domain: 'unknown', summary: 'Bad context' }] });
  assert((await badMemory.handler(request())).status === 503 && badMemory.counts().failed === 1
    && badMemory.counts().generated === 0, 'Malformed shared memory reached the provider');
});
