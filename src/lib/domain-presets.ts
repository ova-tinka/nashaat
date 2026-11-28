const COMPANION_MAP: Record<string, string[]> = {
  'youtube.com': ['youtu.be', 'm.youtube.com', 'youtube-nocookie.com'],
  'youtu.be': ['youtube.com', 'm.youtube.com', 'youtube-nocookie.com'],
  'x.com': ['twitter.com', 'mobile.twitter.com'],
  'twitter.com': ['x.com', 'mobile.twitter.com'],
  'reddit.com': ['old.reddit.com', 'redd.it'],
  'instagram.com': ['instagr.am'],
  'tiktok.com': ['vm.tiktok.com'],
  'facebook.com': ['fb.com', 'm.facebook.com'],
};

export function normalizeRuleDomain(raw: string): string | null {
  const trimmed = raw.trim().toLowerCase();
  if (!trimmed) return null;
  try {
    const parsed = new URL(trimmed.includes('://') ? trimmed : `https://${trimmed}`);
    const host = parsed.hostname.replace(/\.$/, '').replace(/^www\./, '');
    return host.includes('.') ? host : null;
  } catch {
    return null;
  }
}

export function suggestCompanionDomains(domain: string, existingDomains: string[]): string[] {
  const normalized = normalizeRuleDomain(domain);
  if (!normalized) return [];
  const companions = COMPANION_MAP[normalized];
  if (!companions) return [];

  const existing = new Set(existingDomains.map((item) => normalizeRuleDomain(item) ?? item.trim().toLowerCase()));
  return companions.filter((candidate) => !existing.has(candidate));
}
