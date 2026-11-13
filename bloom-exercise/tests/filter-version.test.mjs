import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import test from 'node:test';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const metadata = JSON.parse(readFileSync(resolve(root, 'package.json'), 'utf8'));
const plist = readFileSync(resolve(root, 'src-tauri/macos/filter/Info.plist'), 'utf8');

function plistValue(key) {
  const escapedKey = key.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  const match = plist.match(new RegExp(`<key>${escapedKey}</key><string>([^<]+)</string>`));
  assert.ok(match, `Info.plist must contain ${key}`);
  return match[1];
}

function compareVersions(left, right) {
  const a = left.split('.').map(Number);
  const b = right.split('.').map(Number);
  for (let index = 0; index < Math.max(a.length, b.length); index += 1) {
    const difference = (a[index] ?? 0) - (b[index] ?? 0);
    if (difference !== 0) return Math.sign(difference);
  }
  return 0;
}

test('system extension version advances beyond the installed version and stays separate from app version', () => {
  assert.match(metadata.bloomFilterVersion, /^\d+(?:\.\d+){0,2}$/);
  assert.equal(plistValue('CFBundleShortVersionString'), metadata.bloomFilterVersion);
  assert.equal(plistValue('CFBundleVersion'), metadata.bloomFilterVersion);
  assert.equal(metadata.version, '0.1.0');
  assert.ok(compareVersions(metadata.bloomFilterVersion, '1.1.0') > 0);
});
