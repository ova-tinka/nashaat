const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync } = require('node:child_process');

const REQUIRED_EXTENSION_FILES = [
  'manifest.json',
  'background.js',
  'blocked.html',
  'blocked.css',
  'blocked.js',
  'popup.html',
  'popup.js',
  'lib/domain-policy.mjs',
  'lib/extension-rules.mjs',
  'icons/icon-16.png',
  'icons/icon-32.png',
  'icons/icon-48.png',
  'icons/icon-128.png',
];

function prepareManifestForStore(manifest) {
  const prepared = { ...manifest };
  delete prepared.key;
  return prepared;
}

function copyDirectoryFiltered(sourceDir, targetDir) {
  fs.mkdirSync(targetDir, { recursive: true });
  for (const entry of fs.readdirSync(sourceDir, { withFileTypes: true })) {
    if (entry.name === 'README.md' || entry.name === '.DS_Store') continue;
    const srcPath = path.join(sourceDir, entry.name);
    const dstPath = path.join(targetDir, entry.name);
    if (entry.isDirectory()) {
      copyDirectoryFiltered(srcPath, dstPath);
    } else if (entry.isFile()) {
      fs.copyFileSync(srcPath, dstPath);
    }
  }
}

function packageExtension({ rootDir = path.resolve(__dirname, '..') } = {}) {
  const extensionDir = path.join(rootDir, 'browser-extension');
  const distDir = path.join(rootDir, 'dist');
  const zipPath = path.join(distDir, 'bloom-browser-extension-cws.zip');

  for (const relPath of REQUIRED_EXTENSION_FILES) {
    const fullPath = path.join(extensionDir, relPath);
    if (!fs.existsSync(fullPath)) {
      throw new Error(`Missing required browser extension file: ${relPath}`);
    }
  }

  const manifest = JSON.parse(fs.readFileSync(path.join(extensionDir, 'manifest.json'), 'utf8'));
  const storeManifest = prepareManifestForStore(manifest);

  const stageDir = fs.mkdtempSync(path.join(os.tmpdir(), 'bloom-cws-stage-'));
  try {
    copyDirectoryFiltered(extensionDir, stageDir);
    fs.writeFileSync(path.join(stageDir, 'manifest.json'), `${JSON.stringify(storeManifest, null, 2)}\n`);

    fs.mkdirSync(distDir, { recursive: true });
    if (fs.existsSync(zipPath)) fs.rmSync(zipPath, { force: true });

    const zipResult = spawnSync('/usr/bin/zip', ['-r', '-X', zipPath, '.'], {
      cwd: stageDir,
      encoding: 'utf8',
    });
    if (zipResult.error) throw zipResult.error;
    if (zipResult.status !== 0) {
      throw new Error(`zip failed: ${zipResult.stderr || zipResult.stdout}`);
    }
    return { zipPath, manifest: storeManifest };
  } finally {
    fs.rmSync(stageDir, { recursive: true, force: true });
  }
}

if (require.main === module) {
  const { zipPath } = packageExtension();
  process.stdout.write(`Packaged Chrome Web Store extension at ${zipPath}\n`);
}

module.exports = {
  REQUIRED_EXTENSION_FILES,
  prepareManifestForStore,
  packageExtension,
};
