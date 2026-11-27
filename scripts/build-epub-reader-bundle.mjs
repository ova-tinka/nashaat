#!/usr/bin/env node

import { createHash } from 'node:crypto';
import { readFile, writeFile } from 'node:fs/promises';
import { createRequire } from 'node:module';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import * as esbuild from 'esbuild';

const require = createRequire(import.meta.url);
const rootDir = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const outBundlePath = path.join(rootDir, 'src/assets/epubjs.min.bundle');
const outMetaPath = path.join(rootDir, 'src/assets/epubjs.bundle.meta.json');

const epubjsPkgPath = require.resolve('epubjs/package.json', { paths: [rootDir] });
const epubjsDir = path.dirname(epubjsPkgPath);
const xmldomPkgPath = require.resolve('@xmldom/xmldom/package.json', { paths: [epubjsDir, rootDir] });
const jszipPkgPath = require.resolve('jszip/package.json', { paths: [epubjsDir, rootDir] });

const epubjsPkg = JSON.parse(await readFile(epubjsPkgPath, 'utf8'));
const xmldomPkg = JSON.parse(await readFile(xmldomPkgPath, 'utf8'));
const jszipPkg = JSON.parse(await readFile(jszipPkgPath, 'utf8'));

const [xmldomMajor, xmldomMinor, xmldomPatch] = String(xmldomPkg.version).split('.').map(Number);
const xmldomSafe =
  (xmldomMajor === 0 && xmldomMinor === 8 && xmldomPatch >= 15)
  || (xmldomMajor === 0 && xmldomMinor >= 9)
  || xmldomMajor >= 1;

if (!xmldomSafe) {
  throw new Error(`Refusing to bundle vulnerable @xmldom/xmldom@${xmldomPkg.version}; expected >=0.8.15.`);
}

const banner = `/* bloom-epub-bundle epubjs=${epubjsPkg.version} @xmldom/xmldom=${xmldomPkg.version} jszip=${jszipPkg.version} */`;

const result = await esbuild.build({
  stdin: {
    contents: `
      import JSZip from 'jszip';
      import ePub from 'epubjs';
      if (typeof globalThis.window !== 'undefined') {
        globalThis.window.JSZip = JSZip;
        globalThis.window.ePub = ePub;
      }
      globalThis.JSZip = JSZip;
      globalThis.ePub = ePub;
    `,
    resolveDir: rootDir,
    loader: 'js',
  },
  bundle: true,
  minify: true,
  platform: 'browser',
  format: 'iife',
  target: ['es2018'],
  write: false,
  metafile: true,
  banner: { js: banner },
  alias: {
    path: require.resolve('path-webpack', { paths: [epubjsDir, rootDir] }),
  },
});

const inputs = Object.keys(result.metafile.inputs);
if (!inputs.some((entry) => entry.includes('@xmldom/xmldom'))) {
  throw new Error('Expected @xmldom/xmldom to be bundled into epubjs.min.bundle.');
}

const bundleText = result.outputFiles[0].text;
const sha256 = createHash('sha256').update(bundleText, 'utf8').digest('hex');

await writeFile(outBundlePath, bundleText, 'utf8');
await writeFile(outMetaPath, `${JSON.stringify({
  epubjsVersion: epubjsPkg.version,
  xmldomVersion: xmldomPkg.version,
  jszipVersion: jszipPkg.version,
  sha256,
}, null, 2)}\n`, 'utf8');

console.log(`Built ${path.relative(rootDir, outBundlePath)} (${bundleText.length} bytes, @xmldom/xmldom@${xmldomPkg.version}, sha256=${sha256})`);
