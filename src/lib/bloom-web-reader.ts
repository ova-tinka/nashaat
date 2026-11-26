const documentIdPattern = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

export function bloomWebReaderUrl(
  documentId: string,
  configuredOrigin: string | undefined = process.env.EXPO_PUBLIC_BLOOM_WEB_URL,
): string | null {
  if (!documentIdPattern.test(documentId)) return null;
  const value = configuredOrigin?.trim();
  if (!value) return null;

  try {
    const origin = new URL(value);
    const localDevelopment = origin.protocol === 'http:'
      && ['localhost', '127.0.0.1', '::1'].includes(origin.hostname);
    if ((origin.protocol !== 'https:' && !localDevelopment) || !origin.hostname
      || origin.username || origin.password || origin.pathname !== '/' || origin.search || origin.hash) return null;
    return new URL(`/apps/read/reader/${documentId}`, origin.origin).toString();
  } catch {
    return null;
  }
}
