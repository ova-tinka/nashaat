import { createFireworksJsonProvider } from './ai-provider.ts';

function assert(value: unknown, message: string): asserts value {
  if (!value) throw new Error(message);
}

async function assertRejects(fn: () => Promise<unknown>, pattern: RegExp) {
  let threw = false;
  try {
    await fn();
  } catch (err) {
    threw = true;
    const msg = err instanceof Error ? err.message : String(err);
    assert(pattern.test(msg), `Expected rejection matching ${pattern}, got: ${msg}`);
  }
  assert(threw, `Expected promise to reject ${pattern}`);
}

const sampleRequest = {
  schemaName: 'test_schema',
  schema: { type: 'object' },
  systemPrompt: 'sys',
  userPrompt: 'usr',
  maxTokens: 100,
  temperature: 0.1,
};

Deno.test('createFireworksJsonProvider parses valid structured JSON and enforces bounds', async () => {
  const provider = createFireworksJsonProvider({
    apiKey: 'test-key',
    model: 'test-model',
    fetchImpl: async () => new Response(JSON.stringify({
      choices: [{ finish_reason: 'stop', message: { content: JSON.stringify({ ok: true }) } }],
    }), { status: 200 }),
  });
  const parsed = await provider.completeJson(sampleRequest) as { ok?: boolean };
  assert(parsed.ok === true, 'Expected parsed JSON response');

  const truncated = createFireworksJsonProvider({
    apiKey: 'test-key',
    model: 'test-model',
    fetchImpl: async () => new Response(JSON.stringify({
      choices: [{ finish_reason: 'length', message: { content: '{}' } }],
    }), { status: 200 }),
  });
  await assertRejects(() => truncated.completeJson(sampleRequest), /Invalid provider response/);

  const oversized = createFireworksJsonProvider({
    apiKey: 'test-key',
    model: 'test-model',
    fetchImpl: async () => new Response('x'.repeat(40_000), { status: 200 }),
  });
  await assertRejects(() => oversized.completeJson(sampleRequest), /too large/);

  const unavailable = createFireworksJsonProvider({
    apiKey: 'test-key',
    model: 'test-model',
    fetchImpl: async () => new Response('bad gateway', { status: 502 }),
  });
  await assertRejects(() => unavailable.completeJson(sampleRequest), /Provider unavailable/);
});
