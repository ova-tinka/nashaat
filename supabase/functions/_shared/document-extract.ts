import { Unzip, UnzipInflate } from 'npm:fflate@0.8.2';
import { getResolvedPDFJS } from 'npm:unpdf@2.2.3';
import {
  checkByteSize,
  checkTimeBudget,
  DEFAULT_MAX_BYTES,
  DEFAULT_MAX_MS,
  MAX_DOCX_UNCOMPRESSED,
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

  const chunks: Uint8Array[] = [];
  let totalInflated = 0;
  let foundDocXml = false;
  let streamError: Error | null = null;

  const unzip = new Unzip((file) => {
    if (file.name !== 'word/document.xml') return;
    foundDocXml = true;
    file.ondata = (err, data) => {
      if (streamError) return;
      if (err) {
        streamError = new Error('Invalid DOCX archive');
        return;
      }
      totalInflated += data.length;
      if (totalInflated > MAX_DOCX_UNCOMPRESSED) {
        streamError = new Error('DOCX content is too large to process');
        return;
      }
      try {
        checkTimeBudget(startedAt, maxMs, now);
      } catch (e) {
        streamError = e instanceof Error ? e : new Error('Document extraction timed out');
        return;
      }
      if (data.length > 0) chunks.push(data);
    };
    file.start();
  });
  unzip.register(UnzipInflate);
  unzip.push(bytes, true);

  if (streamError) throw streamError;
  if (!foundDocXml) throw new Error('This DOCX file does not contain a readable document');

  const document = new Uint8Array(totalInflated);
  let offset = 0;
  for (const chunk of chunks) {
    document.set(chunk, offset);
    offset += chunk.length;
  }
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
  const pdfjs = await getResolvedPDFJS();
  const task = pdfjs.getDocument({ data: bytes, disableFontFace: true, useSystemFonts: true });
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
