import {
  checkByteSize,
  parseDocxXmlSections,
  selectRelevantSections,
  validateDocxArchive,
} from './document-extract-core.ts';

function assert(value: unknown, message: string): asserts value {
  if (!value) throw new Error(message);
}

function assertThrows(fn: () => unknown, pattern: RegExp) {
  let threw = false;
  try {
    fn();
  } catch (err) {
    threw = true;
    const msg = err instanceof Error ? err.message : String(err);
    assert(pattern.test(msg), `Expected error matching ${pattern}, got: ${msg}`);
  }
  assert(threw, `Expected function to throw ${pattern}`);
}

Deno.test('parseDocxXmlSections extracts headings/paragraphs and selects relevant excerpts', () => {
  const xml = `<?xml version="1.0" encoding="UTF-8"?>
    <w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
      <w:body>
        <w:p><w:pPr><w:pStyle w:val="Heading1"/></w:pPr><w:r><w:t>Photosynthesis</w:t></w:r></w:p>
        <w:p><w:r><w:t>Chloroplasts convert light energy into chemical energy.</w:t></w:r></w:p>
        <w:p><w:pPr><w:pStyle w:val="Heading1"/></w:pPr><w:r><w:t>Gravity</w:t></w:r></w:p>
        <w:p><w:r><w:t>Objects attract each other proportionally to mass.</w:t></w:r></w:p>
      </w:body>
    </w:document>`;
  const sections = parseDocxXmlSections(xml);
  assert(sections.length === 2, `Expected 2 sections, got ${sections.length}`);
  const relevant = selectRelevantSections(sections, 'How do chloroplasts work?');
  assert(relevant.length === 1 && relevant[0].text.includes('Chloroplasts'), 'Expected chloroplast section');
});

Deno.test('document extraction guards reject empty, oversized, and malformed archives', () => {
  assertThrows(() => checkByteSize(new Uint8Array(0), 100), /Invalid document size/);
  assertThrows(() => checkByteSize(new Uint8Array(200), 100), /Invalid document size/);
  assertThrows(() => validateDocxArchive(new TextEncoder().encode('not-a-zip')), /Invalid DOCX archive/);
});

Deno.test('parseDocxXmlSections enforces extraction time budget', () => {
  const xml = `<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body>
    <w:p><w:r><w:t>First</w:t></w:r></w:p>
    <w:p><w:r><w:t>Second</w:t></w:r></w:p>
  </w:body></w:document>`;
  let ticks = 0;
  assertThrows(
    () => parseDocxXmlSections(xml, { startedAt: 0, maxMs: 5000, now: () => (ticks++ === 0 ? 0 : 6000) }),
    /timed out/,
  );
});

Deno.test('parseDocxXmlSections ignores out-of-range numeric XML entities without throwing', () => {
  const xml = `<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body>
    <w:p><w:r><w:t>Valid &#65; and invalid &#99999999; &#x110000; text</w:t></w:r></w:p>
  </w:body></w:document>`;
  const sections = parseDocxXmlSections(xml);
  assert(sections.length === 1 && sections[0].text === 'Valid A and invalid text', `Unexpected text: ${sections[0]?.text}`);
});
