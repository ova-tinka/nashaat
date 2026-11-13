// Label-boundary matching adapted from Focuser at 14cbfdb. See ../FOCUSER-LICENSE.
// Keep canonicalization and behavior aligned with macos/filter/WebsiteRules.swift.
export function canonicalHost(address) {
  if (typeof address !== 'string') return null;
  const value = address.trim();
  if (!value || [...value].length > 2048 || /\s/u.test(value)) return null;
  try {
    const url = new URL(value.includes('://') ? value : `https://${value}`);
    if (url.protocol !== 'http:' && url.protocol !== 'https:') return null;
    const hostname = url.hostname.toLowerCase();
    const host = hostname.endsWith('.') ? hostname.slice(0, -1) : hostname;
    const labels = host.split('.');
    if (host.length > 253 || labels.length < 2 || labels.some((label) => !label || label.length > 63)) return null;
    return host;
  } catch { return null; }
}

export function setCovers(domains, address) {
  const host = canonicalHost(address);
  if (!host) return false;
  const parts = host.split('.');
  for (let i = 0; i < parts.length; i++) {
    if (domains.has(parts.slice(i).join('.'))) return true;
  }
  return false;
}

export function compileDomains(rules) {
  return new Set(rules.slice(0, 500).map(canonicalHost).filter(Boolean));
}
