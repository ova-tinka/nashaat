import { unzipSync } from 'npm:fflate@0.8.2';
import { getDocument } from 'npm:pdfjs-dist@4.10.38/legacy/build/pdf.mjs';
import {
  checkByteSize,
  checkTimeBudget,
  DEFAULT_MAX_BYTES,
  DEFAULT_MAX_MS,
  MAX_PAGES,
  MAX_TEXT,
  parseDocxXmlSections,
  selectRelevantSections,
  textSize,
  validateDocxArchive,
  type ExtractedSection,
  type ExtractOptions,
} from './document-extract-core.ts';

export type { ExtractedSection, ExtractOptions };
export { selectRelevantSections };

export function extractDocxSections(bytes: Uint8Array, options: ExtractOptions = {}): ExtractedSection[] {
  const maxBytes = options.maxBytes ?? DEFAULT_MAX_BYTES;
  const maxMs = options.maxMs ?? DEFAULT_MAX_MS;
  const now = options.now ?? Date.now;
  const startedAt = now();

  checkByteSize(bytes, maxBytes);
  if (bytes.length < 4 || bytes[0] !== 0x50 || bytes[1] !== 0x4b) throw new Error('This file is not a DOCX archive');
  validateDocxArchive(bytes);
  checkTimeBudget(startedAt, maxMs, now);
  const files = unzipSync(bytes);
  const document = files['word/document.xml'];
  if (!document) throw new Error('This DOCX file does not contain a readable document');
  const xml = new TextDecoder('utf-8', { fatal: true }).decode(document);
  return parseDocxXmlSections(xml, { startedAt, maxMs, now });
}

export async function extractPdfSections(bytes: Uint8Array, options: ExtractOptions = {}): Promise<ExtractedSection[]> {
  const maxBytes = options.maxBytes ?? DEFAULT_MAX_BYTES;
  const maxMs = options.maxMs ?? DEFAULT_MAX_MS;
  const now = options.now ?? Date.now;
  const startedAt = now();

  checkByteSize(bytes, maxBytes);
  if (bytes.length < 5 || new TextDecoder().decode(bytes.subarray(0, 5)) !== '%PDF-') throw new Error('This file is not a PDF');
  const task = getDocument({ data: bytes, disableFontFace: true, useSystemFonts: true, isEvalSupported: false });
  const document = await task.promise;
  try {
    if (!document.numPages || document.numPages > MAX_PAGES) throw new Error('PDF page count is outside the supported range');
    const sections: ExtractedSection[] = [];
    for (let pageNumber = 1; pageNumber <= document.numPages; pageNumber += 1) {
      checkTimeBudget(startedAt, maxMs, now);
      const page = await document.getPage(pageNumber);
      const content = await page.getTextContent();
      const text = content.items.map((item) => 'str' in item ? item.str : '').join(' ').replace(/\s+/g, ' ').trim();
      if (text) sections.push({ reference: `Page ${pageNumber}`, text });
      if (textSize(sections) > MAX_TEXT) throw new Error('Document text is too long to process');
      checkTimeBudget(startedAt, maxMs, now);
    }
    if (!sections.length) throw new Error('No selectable text was found. Scanned PDFs are not supported.');
    return sections;
  } finally {
    await task.destroy();
  }
}
