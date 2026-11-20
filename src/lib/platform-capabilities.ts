export function isMacTauriWebView(platform: string, userAgent: string) {
  return platform === 'MacIntel' || /Macintosh|Mac OS X/.test(userAgent);
}

export type BloomPlatform = 'ios' | 'android' | 'macos' | 'web';
export type BloomReaderFormat = 'PDF' | 'EPUB';

export function resolveBloomPlatform(platform: string, macTauriApp: boolean): BloomPlatform {
  if (platform === 'ios') return 'ios';
  if (platform === 'android') return 'android';
  if (platform === 'web' && macTauriApp) return 'macos';
  return 'web';
}

export function isReaderFormatSupported(
  formats: Partial<Record<BloomPlatform, readonly BloomReaderFormat[]>>,
  platform: BloomPlatform,
  format: 'pdf' | 'epub',
) {
  return formats[platform]?.includes(format.toUpperCase() as BloomReaderFormat) ?? false;
}
