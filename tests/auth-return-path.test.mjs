import assert from 'node:assert/strict';
import { test } from 'node:test';
import { buildSignInHref, validateInternalReturnPath } from '../src/lib/auth-return-path.ts';

const docId = '7e09a2d3-f94c-47ac-82d6-8b64af1064e1';

test('preserves validated reader destinations through sign-in', () => {
  const readerPath = `/apps/read/reader/${docId}`;
  assert.equal(validateInternalReturnPath(readerPath), readerPath);
  assert.equal(buildSignInHref(readerPath), `/sign-in?next=${encodeURIComponent(readerPath)}`);
  assert.equal(buildSignInHref('/'), '/sign-in');
});

test('rejects open redirects, traversal, control characters, and sign-in loops', () => {
  assert.equal(validateInternalReturnPath('https://evil.example/apps/read'), null);
  assert.equal(validateInternalReturnPath('//evil.example/apps/read'), null);
  assert.equal(validateInternalReturnPath('/apps/../settings'), null);
  assert.equal(validateInternalReturnPath('/apps/read\\evil'), null);
  assert.equal(validateInternalReturnPath('/user@evil.example'), null);
  assert.equal(validateInternalReturnPath('/sign-in'), null);
  assert.equal(validateInternalReturnPath('/sign-in?next=/'), null);
  assert.equal(validateInternalReturnPath('/apps/read\nLocation: https://evil.example'), null);
  assert.equal(buildSignInHref('//evil.example'), '/sign-in');
});
