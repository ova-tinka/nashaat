import assert from 'node:assert/strict';
import test from 'node:test';
import { createChunkedProtectedStorage } from '../src/lib/protected-storage-core.ts';

function memoryStore(initial = {}) {
  const data = new Map(Object.entries(initial));
  return {
    data,
    async getItem(key) {
      return data.has(key) ? (data.get(key) ?? null) : null;
    },
    async setItem(key, value) {
      data.set(key, value);
    },
    async removeItem(key) {
      data.delete(key);
    },
  };
}

test('chunked protected storage splits payloads above 1800 bytes and removes all chunks', async () => {
  const primary = memoryStore();
  const legacy = memoryStore();
  const storage = createChunkedProtectedStorage({ primary, legacy, maxChunkBytes: 1800 });

  const largePayload = JSON.stringify({
    access_token: 'a'.repeat(2100),
    refresh_token: 'r'.repeat(1200),
  });
  await storage.setItem('sb-auth-token', largePayload);

  assert.ok(primary.data.get('sb-auth-token')?.startsWith('__bloom_chunks_v1__:'));
  assert.ok(primary.data.has('sb-auth-token.chunk.0'));
  assert.ok(primary.data.has('sb-auth-token.chunk.1'));
  for (const [k, v] of primary.data.entries()) {
    assert.ok(new TextEncoder().encode(v).length <= 1800, `Chunk ${k} exceeded limit`);
  }

  assert.equal(await storage.getItem('sb-auth-token'), largePayload);
  await storage.removeItem('sb-auth-token');
  assert.equal(primary.data.size, 0);
});

test('protected storage migrates legacy AsyncStorage credentials and deletes the legacy copy', async () => {
  const legacyToken = JSON.stringify({ access_token: 'legacy-jwt', refresh_token: 'legacy-refresh', extra: 'x'.repeat(2200) });
  const primary = memoryStore();
  const legacy = memoryStore({ 'sb-bloom-auth': legacyToken });
  const storage = createChunkedProtectedStorage({ primary, legacy, maxChunkBytes: 1800 });

  const loaded = await storage.getItem('sb-bloom-auth');
  assert.equal(loaded, legacyToken);
  assert.equal(legacy.data.has('sb-bloom-auth'), false, 'Legacy copy must be removed after migration');
  assert.equal(await storage.getItem('sb-bloom-auth'), legacyToken);
});

test('protected storage shrinks chunk count cleanly when overwriting a large value with a small value', async () => {
  const primary = memoryStore();
  const storage = createChunkedProtectedStorage({ primary, maxChunkBytes: 100 });
  await storage.setItem('session', 'x'.repeat(250));
  assert.ok(primary.data.has('session.chunk.2'));

  await storage.setItem('session', 'small');
  assert.equal(await storage.getItem('session'), 'small');
  assert.equal(primary.data.has('session.chunk.0'), false);
  assert.equal(primary.data.has('session.chunk.2'), false);
});
