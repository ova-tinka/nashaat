import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { readFile } from 'node:fs/promises';
import { test } from 'node:test';
import vm from 'node:vm';
import JSZip from 'jszip';
import { buildReadingDocumentHtml, parseReaderMessage } from '../src/lib/reading-reader-html.ts';

async function buildSampleEpubBuffer() {
  const zip = new JSZip();
  zip.file('mimetype', 'application/epub+zip', { compression: 'STORE' });
  zip.file('META-INF/container.xml', `<?xml version="1.0" encoding="UTF-8"?>
<container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
  <rootfiles>
    <rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/>
  </rootfiles>
</container>`);
  zip.file('OEBPS/content.opf', `<?xml version="1.0" encoding="UTF-8"?>
<package xmlns="http://www.idpf.org/2007/opf" version="3.0" unique-identifier="bookid">
  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
    <dc:identifier id="bookid">urn:uuid:11111111-1111-4111-8111-111111111111</dc:identifier>
    <dc:title>Bloom Test Book</dc:title>
    <dc:language>en</dc:language>
    <meta property="dcterms:modified">2026-11-27T00:00:00Z</meta>
  </metadata>
  <manifest>
    <item id="ncx" href="toc.ncx" media-type="application/x-dtbncx+xml"/>
    <item id="ch1" href="ch1.xhtml" media-type="application/xhtml+xml"/>
    <item id="ch2" href="ch2.xhtml" media-type="application/xhtml+xml"/>
  </manifest>
  <spine toc="ncx">
    <itemref idref="ch1"/>
    <itemref idref="ch2"/>
  </spine>
</package>`);
  zip.file('OEBPS/toc.ncx', `<?xml version="1.0" encoding="UTF-8"?>
<ncx xmlns="http://www.daisy.org/z3986/2005/ncx/" version="2005-1">
  <head><meta name="dtb:uid" content="urn:uuid:11111111-1111-4111-8111-111111111111"/></head>
  <docTitle><text>Bloom Test Book</text></docTitle>
  <navMap>
    <navPoint id="np-1" playOrder="1"><navLabel><text>Chapter One</text></navLabel><content src="ch1.xhtml"/></navPoint>
    <navPoint id="np-2" playOrder="2"><navLabel><text>Chapter Two</text></navLabel><content src="ch2.xhtml"/></navPoint>
  </navMap>
</ncx>`);
  zip.file('OEBPS/nav.xhtml', `<?xml version="1.0" encoding="UTF-8"?>
<html xmlns="http://www.w3.org/1999/xhtml" xmlns:epub="http://www.idpf.org/2007/ops">
<head><title>Contents</title></head>
<body>
  <nav epub:type="toc">
    <ol>
      <li><a href="ch1.xhtml">Chapter One</a></li>
      <li><a href="ch2.xhtml">Chapter Two</a></li>
    </ol>
  </nav>
</body>
</html>`);
  zip.file('OEBPS/ch1.xhtml', `<?xml version="1.0" encoding="UTF-8"?>
<html xmlns="http://www.w3.org/1999/xhtml"><head><title>Chapter One</title></head><body><h1>Chapter One</h1><p>First chapter text.</p></body></html>`);
  zip.file('OEBPS/ch2.xhtml', `<?xml version="1.0" encoding="UTF-8"?>
<html xmlns="http://www.w3.org/1999/xhtml"><head><title>Chapter Two</title></head><body><h1>Chapter Two</h1><p>Second chapter text.</p></body></html>`);
  return zip.generateAsync({ type: 'nodebuffer' });
}

test('shipped EPUB bundle matches lockfile metadata and uses patched @xmldom/xmldom', async () => {
  const bundle = await readFile(new URL('../src/assets/epubjs.min.bundle', import.meta.url), 'utf8');
  const meta = JSON.parse(await readFile(new URL('../src/assets/epubjs.bundle.meta.json', import.meta.url), 'utf8'));
  const sha256 = createHash('sha256').update(bundle, 'utf8').digest('hex');

  assert.equal(sha256, meta.sha256);
  assert.match(bundle.slice(0, 200), /@xmldom\/xmldom=0\.8\.15/);
  assert.equal(meta.xmldomVersion, '0.8.15');
  assert.ok(bundle.includes('requireWellFormed'), 'Expected patched @xmldom/xmldom >=0.8.15 code in bundle');
  assert.ok(!bundle.includes('0.7.13'), 'Vulnerable @xmldom/xmldom 0.7.13 marker must not appear');
});

test('web reader view preserves sandbox="allow-scripts" without allow-same-origin', async () => {
  const source = await readFile(new URL('../src/components/reading-document-view.web.tsx', import.meta.url), 'utf8');
  assert.match(source, /sandbox:\s*['"]allow-scripts['"]/);
  assert.ok(!source.includes('allow-same-origin'));
});

test('buildReadingDocumentHtml and parseReaderMessage support PDF pages, EPUB CFIs, and safe errors', async () => {
  const bundle = await readFile(new URL('../src/assets/epubjs.min.bundle', import.meta.url), 'utf8');
  const pdfHtml = buildReadingDocumentHtml({
    format: 'pdf',
    sourceUrl: 'https://example.test/sample.pdf',
    initialPage: 4,
    backgroundColor: '#ffffff',
    textColor: '#111111',
  });
  assert.match(pdfHtml, /https:\/\/example\.test\/sample\.pdf#page=4/);

  const epubHtml = buildReadingDocumentHtml({
    format: 'epub',
    sourceUrl: 'https://example.test/sample.epub',
    epubScript: bundle,
    initialCfi: 'epubcfi(/6/4!/4/2/1:0)',
    initialPercent: 50,
    backgroundColor: '#ffffff',
    textColor: '#111111',
  });
  assert.match(epubHtml, /epubcfi\(\/6\/4!\/4\/2\/1:0\)/);
  assert.match(epubHtml, /aria-label="Table of contents"/);

  assert.deepEqual(
    parseReaderMessage(JSON.stringify({ source: 'bloom-reader', type: 'location', cfi: 'epubcfi(/6/2!/4)', percent: 42.5 })),
    { cfi: 'epubcfi(/6/2!/4)', percent: 42.5 },
  );
  assert.deepEqual(
    parseReaderMessage(JSON.stringify({ source: 'bloom-reader', type: 'error', message: 'Could not open this EPUB.' })),
    { error: 'Could not open this EPUB.' },
  );
  assert.equal(parseReaderMessage('not-json'), null);
});

test('shipped EPUB bundle parses chapters, resolves spine CFI, and rejects corrupted EPUBs via @xmldom/xmldom', async () => {
  const bundle = await readFile(new URL('../src/assets/epubjs.min.bundle', import.meta.url), 'utf8');
  const epubBuffer = await buildSampleEpubBuffer();
  const validArrayBuffer = epubBuffer.buffer.slice(epubBuffer.byteOffset, epubBuffer.byteOffset + epubBuffer.byteLength);
  const badBytes = Buffer.from('not-a-valid-epub-archive', 'utf8');
  const badArrayBuffer = badBytes.buffer.slice(badBytes.byteOffset, badBytes.byteOffset + badBytes.byteLength);

  const sandbox = {
    window: null,
    self: null,
    globalThis: null,
    URL,
    Blob,
    TextDecoder,
    TextEncoder,
    Uint8Array,
    ArrayBuffer,
    DataView,
    setTimeout,
    clearTimeout,
    console,
    atob: (value) => Buffer.from(value, 'base64').toString('binary'),
    btoa: (value) => Buffer.from(value, 'binary').toString('base64'),
    DOMParser: undefined,
    navigator: { userAgent: 'node-vm' },
    document: { createElement: () => ({}) },
  };
  sandbox.window = sandbox;
  sandbox.self = sandbox;
  sandbox.globalThis = sandbox;

  vm.runInNewContext(bundle, sandbox, { filename: 'epubjs.min.bundle' });
  assert.equal(typeof sandbox.ePub, 'function');

  const book = sandbox.ePub(validArrayBuffer);
  await book.ready;
  assert.equal(book.packaging.metadata.title, 'Bloom Test Book');
  const navigation = await book.loaded.navigation;
  assert.equal(navigation.toc.length, 2);
  assert.equal(navigation.toc[0].label.trim(), 'Chapter One');
  assert.equal(navigation.toc[1].label.trim(), 'Chapter Two');

  const ch2 = book.spine.get('ch2.xhtml');
  assert.ok(ch2, 'Expected Chapter Two in EPUB spine');
  assert.ok(typeof ch2.cfiBase === 'string' && ch2.cfiBase.length > 0, 'Expected valid cfiBase for Chapter Two');

  const invalidBook = sandbox.ePub();
  await assert.rejects(() => invalidBook.open(badArrayBuffer));
});
