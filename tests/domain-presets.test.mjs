import assert from 'node:assert/strict';
import test from 'node:test';
import { normalizeRuleDomain, suggestCompanionDomains } from '../src/lib/domain-presets.ts';

test('normalizeRuleDomain strips protocol, path, and www', () => {
  assert.equal(normalizeRuleDomain('https://www.YouTube.com/watch?v=123'), 'youtube.com');
  assert.equal(normalizeRuleDomain('reddit.com'), 'reddit.com');
  assert.equal(normalizeRuleDomain('invalid'), null);
});

test('suggestCompanionDomains returns unadded companions for youtube and x', () => {
  assert.deepEqual(
    suggestCompanionDomains('youtube.com', ['youtube.com']),
    ['youtu.be', 'm.youtube.com', 'youtube-nocookie.com'],
  );
  assert.deepEqual(
    suggestCompanionDomains('https://www.youtube.com/shorts', ['youtube.com', 'youtu.be']),
    ['m.youtube.com', 'youtube-nocookie.com'],
  );
  assert.deepEqual(
    suggestCompanionDomains('x.com', ['x.com', 'twitter.com', 'mobile.twitter.com']),
    [],
  );
});
