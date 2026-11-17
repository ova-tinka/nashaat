import assert from 'node:assert/strict';
import { test } from 'node:test';
import { canonicalWebsiteDomain, MAX_IOS_ALWAYS_WEBSITE_DOMAINS } from '../src/lib/website-domain.ts';

test('matches the documented iOS always-domain filter limit', () => {
  assert.equal(MAX_IOS_ALWAYS_WEBSITE_DOMAINS, 50);
});

test('canonicalizes URLs, paths, ports, case, and trailing dots to a host', () => {
  assert.equal(canonicalWebsiteDomain('  HTTPS://WWW.Example.com:8443/path?q=1  '), 'www.example.com');
  assert.equal(canonicalWebsiteDomain('example.com./some/path'), 'example.com');
});

test('converts internationalized host names to ASCII', () => {
  assert.equal(canonicalWebsiteDomain('https://BÜCHER.example/'), 'xn--bcher-kva.example');
});

test('rejects malformed hosts, credentials, IP addresses, and non-web schemes', () => {
  for (const input of ['', 'example', 'not a host', '127.0.0.1', 'https://user:pass@example.com', 'ftp://example.com']) {
    assert.equal(canonicalWebsiteDomain(input), null, input);
  }
});
