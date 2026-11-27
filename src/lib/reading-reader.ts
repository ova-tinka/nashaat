import { Asset } from 'expo-asset';
import { File as ExpoFile } from 'expo-file-system';
export { buildReadingDocumentHtml, parseReaderMessage, type ReadingLocation } from './reading-reader-html';

// Expo Metro resolves this inert text bundle as an asset module identifier.
// eslint-disable-next-line @typescript-eslint/no-require-imports
const epubRendererAsset = require('../assets/epubjs.min.bundle') as number;
let epubRendererPromise: Promise<string> | null = null;

export async function loadEpubRendererScript() {
  if (!epubRendererPromise) {
    epubRendererPromise = (async () => {
      const asset = Asset.fromModule(epubRendererAsset);
      await asset.downloadAsync();
      if (asset.localUri?.startsWith('file://')) return new ExpoFile(asset.localUri).text();
      const response = await fetch(asset.localUri ?? asset.uri);
      if (!response.ok) throw new Error('Could not load the bundled EPUB reader.');
      return response.text();
    })().catch((error) => {
      epubRendererPromise = null;
      throw error;
    });
  }
  return epubRendererPromise;
}
