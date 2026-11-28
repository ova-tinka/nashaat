export type ExtractedSection = { reference: string; text: string };
export type ExtractOptions = {
  maxMs?: number;
  maxBytes?: number;
  now?: () => number;
};

export const MAX_TEXT = 200_000;
export const MAX_PAGES = 400;
export const MAX_DOCX_UNCOMPRESSED = 25 * 1024 * 1024;
export const DEFAULT_MAX_BYTES = 10 * 1024 * 1024;
export const DEFAULT_MAX_MS = 5000;

export function checkTimeBudget(startedAt: number, maxMs: number, now: () => number) {
  if (now() - startedAt > maxMs) {
    throw new Error('Document extraction timed out');
  }
}

export function checkByteSize(bytes: Uint8Array, maxBytes: number) {
  if (!bytes.length || bytes.length > maxBytes) {
    throw new Error('Invalid document size');
  }
}

export function textSize(sections: ExtractedSection[]) {
  return sections.reduce((sum, section) => sum + section.text.length, 0);
}

function safeCodePoint(code: number): string {
  return Number.isInteger(code) && code >= 0 && code <= 0x10FFFF ? String.fromCodePoint(code) : '';
}

function xmlText(value: string) {
  return value.replace(/<w:tab\s*\/?\s*>/g, ' ')
    .replace(/<w:(?:br|cr)\s*\/?\s*>/g, ' ')
    .replace(/<[^>]+>/g, '')
    .replace(/&amp;/g, '&').replace(/&lt;/g, '<').replace(/&gt;/g, '>')
    .replace(/&quot;/g, '"').replace(/&apos;/g, "'")
    .replace(/&#(\d+);/g, (_match, number: string) => safeCodePoint(Number(number)))
    .replace(/&#x([0-9a-f]+);/gi, (_match, number: string) => safeCodePoint(parseInt(number, 16)))
    .replace(/\s+/g, ' ').trim();
}

export function validateDocxArchive(bytes: Uint8Array) {
  // Check the ZIP central directory first so a small upload cannot expand into
  // an unbounded in-memory archive.
  const view = new DataView(bytes.buffer, bytes.byteOffset, bytes.byteLength);
  let end = -1;
  const floor = Math.max(0, bytes.length - 65_557);
  for (let offset = bytes.length - 22; offset >= floor; offset -= 1) {
    if (view.getUint32(offset, true) === 0x06054b50) { end = offset; break; }
  }
  if (end < 0) throw new Error('Invalid DOCX archive');
  const count = view.getUint16(end + 10, true);
  const directorySize = view.getUint32(end + 12, true);
  let offset = view.getUint32(end + 16, true);
  if (!count || count > 1000 || offset + directorySize > end) throw new Error('Invalid DOCX archive');
  let expandedBytes = 0;
  for (let index = 0; index < count; index += 1) {
    if (offset + 46 > bytes.length || view.getUint32(offset, true) !== 0x02014b50) throw new Error('Invalid DOCX archive');
    expandedBytes += view.getUint32(offset + 24, true);
    if (expandedBytes > MAX_DOCX_UNCOMPRESSED) throw new Error('DOCX content is too large to process');
    offset += 46 + view.getUint16(offset + 28, true) + view.getUint16(offset + 30, true) + view.getUint16(offset + 32, true);
  }
}

export function parseDocxXmlSections(
  xml: string,
  options: { startedAt?: number; maxMs?: number; now?: () => number } = {},
): ExtractedSection[] {
  const maxMs = options.maxMs ?? DEFAULT_MAX_MS;
  const now = options.now ?? Date.now;
  const startedAt = options.startedAt ?? now();
  const sections: ExtractedSection[] = [];
  let sectionNumber = 0;
  for (const paragraphMatch of xml.matchAll(/<w:p\b[\s\S]*?<\/w:p>/g)) {
    checkTimeBudget(startedAt, maxMs, now);
    const paragraph = paragraphMatch[0];
    const text = xmlText(paragraph);
    if (!text) continue;
    const heading = /<w:pStyle\b[^>]*\bw:val="(?:Heading|heading)(\d+)"/i.exec(paragraph)?.[1];
    if (heading || sections.length === 0) {
      sectionNumber += 1;
      sections.push({ reference: heading ? `Section ${sectionNumber} · heading` : `Section ${sectionNumber}`, text: '' });
    }
    const current = sections[sections.length - 1];
    current.text = `${current.text}${current.text ? '\n' : ''}${text}`;
    if (textSize(sections) > MAX_TEXT) throw new Error('Document text is too long to process');
  }
  if (!sections.length) throw new Error('No readable text was found in this DOCX file');
  return sections;
}

export function selectRelevantSections(sections: ExtractedSection[], prompt: string, maximum = 8) {
  const terms = [...new Set(prompt.toLocaleLowerCase().match(/[\p{L}\p{N}]{3,}/gu) ?? [])];
  const ranked = sections.map((section) => {
    const text = section.text.toLocaleLowerCase();
    return { ...section, score: terms.reduce((sum, term) => sum + (text.includes(term) ? 1 : 0), 0) };
  }).filter((section) => section.score > 0)
    .sort((left, right) => right.score - left.score || left.reference.localeCompare(right.reference));
  const selected = ranked.slice(0, maximum).map(({ reference, text }) => ({ reference, text: text.slice(0, 5000) }));
  if (!selected.length && sections.length <= maximum) return sections.map(({ reference, text }) => ({ reference, text: text.slice(0, 5000) }));
  return selected;
}
