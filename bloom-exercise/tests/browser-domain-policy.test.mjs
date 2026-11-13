import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { test } from 'node:test';
import { canonicalHost, compileDomains, setCovers } from '../browser-extension/lib/domain-policy.mjs';

test('browser and native domain policy share the same domain coverage vectors', async () => {
  const vectors = JSON.parse(await readFile(new URL('./fixtures/macos-domain-policy.json', import.meta.url)));
  for (const { rule, address, blocked } of vectors) {
    assert.equal(setCovers(compileDomains([rule]), address), blocked, `${rule} -> ${address}`);
  }
});

test('rules normalize IDNs, preserve specific subdomains, and ignore invalid values', () => {
  assert.equal(canonicalHost('https://BÜCHER.example/'), 'xn--bcher-kva.example');
  assert.deepEqual([...compileDomains(['example.com', 'example.com', 'not a host'])], ['example.com']);
  assert.equal(setCovers(compileDomains(['www.example.com']), 'example.com'), false);
});
