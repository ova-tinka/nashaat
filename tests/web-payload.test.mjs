import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import test from 'node:test';

test('reader route lazy-loads ReadingDocumentView and reading-reader defers EPUB bundle require', () => {
  const readerRoute = fs.readFileSync(
    path.resolve(process.cwd(), 'src/app/(app)/(tabs)/apps/read/reader/[id].tsx'),
    'utf8',
  );
  const readerLoader = fs.readFileSync(
    path.resolve(process.cwd(), 'src/lib/reading-reader.ts'),
    'utf8',
  );
  assert.ok(readerRoute.includes('lazy('), 'Reader route must lazy-load ReadingDocumentView');
  assert.ok(!readerLoader.split('export async function loadEpubRendererScript')[0].includes('epubjs.min.bundle'),
    'reading-reader top-level must not eagerly require epubjs.min.bundle');
});
