import assert from 'node:assert/strict';
import { test } from 'node:test';
import { blockPagePath, buildDynamicRules, findMatchingDomain } from '../browser-extension/lib/extension-rules.mjs';

test('buildDynamicRules returns empty when disabled or screen time is active for personal domains only', () => {
  assert.deepEqual(buildDynamicRules({ enabled: false, blockedDomains: ['youtube.com'] }), []);
  assert.deepEqual(buildDynamicRules({ enabled: true, blockedDomains: ['youtube.com'], accessAllowed: true }), []);
  const managedDuringAccess = buildDynamicRules({
    enabled: true,
    blockedDomains: ['youtube.com'],
    managedDomains: ['reddit.com'],
    accessAllowed: true,
  });
  assert.deepEqual(
    managedDuringAccess.map((rule) => [rule.condition.urlFilter, rule.action.redirect.extensionPath]),
    [['||reddit.com^', blockPagePath('reddit.com', true)]],
  );
});

test('buildDynamicRules generates deduplicated MV3 redirect rules with managed flag', () => {
  const rules = buildDynamicRules({
    enabled: true,
    blockedDomains: ['youtube.com', 'm.youtube.com', 'youtube.com', 'invalid host'],
    managedDomains: ['reddit.com', 'm.youtube.com'],
    accessAllowed: false,
  });
  assert.equal(rules.length, 3);
  assert.deepEqual(
    rules.map((rule) => [rule.id, rule.condition.urlFilter, rule.action.redirect.extensionPath]),
    [
      [1, '||m.youtube.com^', blockPagePath('m.youtube.com', true)],
      [2, '||reddit.com^', blockPagePath('reddit.com', true)],
      [3, '||youtube.com^', blockPagePath('youtube.com', false)],
    ],
  );
});

test('findMatchingDomain matches domains and subdomains consistently', () => {
  assert.equal(findMatchingDomain('https://www.youtube.com/watch?v=123', ['youtube.com']), 'www.youtube.com');
  assert.equal(findMatchingDomain('https://example.org/', ['youtube.com']), null);
  assert.equal(findMatchingDomain('chrome-extension://abc/blocked.html', ['youtube.com']), null);
});
