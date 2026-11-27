import fs from 'node:fs';
import path from 'node:path';
import zlib from 'node:zlib';

const distDir = path.resolve(process.cwd(), 'dist');
const indexPath = path.join(distDir, 'index.html');

if (!fs.existsSync(indexPath)) {
  throw new Error('dist/index.html is missing. Run npm run build:web first.');
}

const indexHtml = fs.readFileSync(indexPath, 'utf8');
const scriptMatches = [...indexHtml.matchAll(/<script[^>]+src="([^"]+)"/g)].map((m) => m[1]);
if (scriptMatches.length === 0) {
  throw new Error('No initial script tags found in dist/index.html.');
}

let totalRawBytes = 0;
let totalGzipBytes = 0;

for (const src of scriptMatches) {
  const rel = src.replace(/^\//, '');
  const fullPath = path.join(distDir, rel);
  if (!fs.existsSync(fullPath)) {
    throw new Error(`Referenced entry script missing: ${fullPath}`);
  }
  const content = fs.readFileSync(fullPath);
  const text = content.toString('utf8');
  if (text.includes('bloom-epub-bundle') || text.includes('epubjs.min.bundle')) {
    throw new Error(`Initial web route script ${rel} unexpectedly includes EPUB renderer code.`);
  }
  const gzipped = zlib.gzipSync(content, { level: 9 });
  totalRawBytes += content.byteLength;
  totalGzipBytes += gzipped.byteLength;
  console.log(`Initial script ${rel}: raw=${(content.byteLength / 1024).toFixed(1)} KiB, gzip=${(gzipped.byteLength / 1024).toFixed(1)} KiB`);
}

if (indexHtml.includes('bloom-epub-bundle') || indexHtml.includes('epubjs.min.bundle')) {
  throw new Error('dist/index.html unexpectedly references EPUB renderer assets.');
}

console.log(`Initial web JS total: raw=${(totalRawBytes / 1024).toFixed(1)} KiB, gzip=${(totalGzipBytes / 1024).toFixed(1)} KiB (EPUB renderer excluded from initial route).`);
