const { test } = require('node:test');
const assert = require('node:assert/strict');
const { createCsp } = require('../scripts/desktop-csp.cjs');
const config = require('../src-tauri/tauri.conf.json');

test('the default Tauri policy is restrictive when no build override is supplied', () => {
  const csp = config.app.security.csp;
  assert.match(csp, /script-src 'self'/);
  assert.match(csp, /connect-src 'self' ipc: http:\/\/ipc\.localhost;/);
  assert.doesNotMatch(csp, /unsafe-eval|script-src[^;]*unsafe-inline/);
});

test('production CSP allows only the configured secure service origin', () => {
  const csp = createCsp('https://example.supabase.co', false);
  assert.match(csp, /connect-src 'self' ipc: http:\/\/ipc\.localhost https:\/\/example\.supabase\.co wss:\/\/example\.supabase\.co/);
  assert.match(csp, /script-src 'self'/);
  assert.doesNotMatch(csp, /unsafe-eval|script-src[^;]*unsafe-inline|connect-src[^;]* https:([; ]|$)/);
  assert.match(csp, /object-src 'none'/);
});

test('local test service and development server are explicitly scoped', () => {
  const csp = createCsp('http://127.0.0.1:54321', true);
  assert.match(csp, /http:\/\/127\.0\.0\.1:54321 ws:\/\/127\.0\.0\.1:54321/);
  assert.match(csp, /http:\/\/localhost:8081 ws:\/\/localhost:8081/);
});

test('rejects absent, untrusted, or malformed service origins', () => {
  for (const url of ['', 'http://example.com:80', 'https://example.com/path', 'https://example.com/?token=x', 'https://user@example.com', 'https://example.com:8443']) {
    assert.throws(() => createCsp(url, false));
  }
});
