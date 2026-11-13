import assert from 'node:assert/strict';
import { test } from 'node:test';
import { formatDiagnosticFailure } from '../src/lib/diagnostic-error.ts';

test('diagnostic errors preserve safe PostgREST codes while redacting credentials and personal values', () => {
  const result = formatDiagnosticFailure({
    code: '42501',
    message: 'permission denied for https://db.example.test/table Bearer secret-value eyJabcdefghijk.abcdefghijk.abcdefghijk user@example.com sb_secret_super-secret api_key=another-secret',
  });
  assert.equal(result.code, '42501');
  assert.equal(result.message.includes('secret-value'), false);
  assert.equal(result.message.includes('abcdefghijk'), false);
  assert.equal(result.message.includes('db.example.test'), false);
  assert.equal(result.message.includes('user@example.com'), false);
  assert.equal(result.message.includes('super-secret'), false);
  assert.equal(result.message.includes('another-secret'), false);
  assert.match(result.message, /permission denied/);
});

test('diagnostic error output is bounded and ignores unsafe code strings', () => {
  const result = formatDiagnosticFailure({ code: 'unexpected code with value', message: 'x'.repeat(500) });
  assert.equal(result.code, null);
  assert.equal(result.message.length, 220);
});

test('unknown diagnostic failures use a safe fallback', () => {
  assert.deepEqual(formatDiagnosticFailure({ secret: 'do not expose' }), {
    code: null,
    message: 'The request failed without an error message.',
  });
});
