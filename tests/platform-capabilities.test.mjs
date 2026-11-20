import assert from 'node:assert/strict';
import { test } from 'node:test';
import { isMacTauriWebView, isReaderFormatSupported, resolveBloomPlatform } from '../src/lib/platform-capabilities.ts';

test('recognizes the macOS WebView identity', () => {
  assert.equal(isMacTauriWebView('MacIntel', 'Mozilla/5.0'), true);
  assert.equal(isMacTauriWebView('Other', 'Mozilla/5.0 (Macintosh; Intel Mac OS X 14_0)'), true);
});

test('does not route Windows Tauri or a normal browser through macOS commands', () => {
  assert.equal(isMacTauriWebView('Win32', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)'), false);
  assert.equal(isMacTauriWebView('Linux x86_64', 'Mozilla/5.0 (X11; Linux x86_64)'), false);
});

test('maps native and Mac Tauri runtimes to explicit capability platforms', () => {
  assert.equal(resolveBloomPlatform('ios', false), 'ios');
  assert.equal(resolveBloomPlatform('android', false), 'android');
  assert.equal(resolveBloomPlatform('web', true), 'macos');
  assert.equal(resolveBloomPlatform('web', false), 'web');
});

test('reader format availability follows only the declared platform formats', () => {
  const declaredFormats = { web: ['PDF', 'EPUB'] };
  assert.equal(isReaderFormatSupported(declaredFormats, 'web', 'pdf'), true);
  assert.equal(isReaderFormatSupported(declaredFormats, 'web', 'epub'), true);
  assert.equal(isReaderFormatSupported(declaredFormats, 'ios', 'pdf'), false);
  assert.equal(isReaderFormatSupported(declaredFormats, 'android', 'epub'), false);
  assert.equal(isReaderFormatSupported(declaredFormats, 'macos', 'epub'), false);
});
