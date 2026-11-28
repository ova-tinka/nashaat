import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import test from 'node:test';
import { createRequire } from 'node:module';

const require = createRequire(import.meta.url);
const { prepareManifestForStore, REQUIRED_EXTENSION_FILES } = require('../scripts/package-browser-extension.cjs');

test('prepareManifestForStore removes local dev key while keeping required extension metadata', () => {
  const manifestPath = path.resolve(import.meta.dirname, '..', 'browser-extension', 'manifest.json');
  const raw = JSON.parse(fs.readFileSync(manifestPath, 'utf8'));
  assert.ok(raw.key, 'source manifest should retain local dev key for unpacked dev loads');

  const packaged = prepareManifestForStore(raw);
  assert.equal('key' in packaged, false);
  assert.equal(packaged.manifest_version, 3);
  assert.ok(packaged.icons?.['128']);
  assert.ok(Array.isArray(packaged.permissions) && packaged.permissions.includes('declarativeNetRequest'));
});

test('all required browser extension assets exist on disk', () => {
  const extDir = path.resolve(import.meta.dirname, '..', 'browser-extension');
  for (const rel of REQUIRED_EXTENSION_FILES) {
    assert.equal(fs.existsSync(path.join(extDir, rel)), true, `Missing ${rel}`);
  }
});
