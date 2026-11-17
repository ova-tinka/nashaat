/** Normalize a user-entered URL or host into the canonical domain we store. */
export const MAX_IOS_ALWAYS_WEBSITE_DOMAINS = 50;

export function canonicalWebsiteDomain(value: string): string | null {
  const input = value.trim();
  if (!input || input.length > 2048) return null;

  const hasScheme = /^[a-z][a-z0-9+.-]*:\/\//i.test(input);
  let url: URL;
  try {
    url = new URL(hasScheme ? input : `https://${input}`);
  } catch {
    return null;
  }

  if (!['http:', 'https:'].includes(url.protocol) || url.username || url.password) return null;
  const host = url.hostname.toLowerCase().replace(/\.$/, '');
  if (host.length > 253 || host.includes(':') || /^\d{1,3}(?:\.\d{1,3}){3}$/.test(host)) return null;

  const labels = host.split('.');
  if (labels.length < 2 || labels.some((label) =>
    label.length < 1 || label.length > 63 || !/^[a-z0-9](?:[a-z0-9-]*[a-z0-9])?$/.test(label),
  )) return null;

  return host;
}
