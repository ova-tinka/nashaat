import { canonicalHost, compileDomains, setCovers } from './domain-policy.mjs';

export function blockPagePath(host, managed = false) {
  return `/blocked.html?host=${encodeURIComponent(host)}&managed=${managed ? '1' : '0'}`;
}

export function buildDynamicRules({ enabled, blockedDomains = [], managedDomains = [], accessAllowed = false }) {
  if (!enabled) return [];
  const managedSet = compileDomains(managedDomains);
  const sourceDomains = accessAllowed ? managedDomains : [...blockedDomains, ...managedDomains];
  const combined = [...compileDomains(sourceDomains)].sort().slice(0, 500);
  return combined.map((domain, index) => ({
    id: index + 1,
    priority: 1,
    action: {
      type: 'redirect',
      redirect: {
        extensionPath: blockPagePath(domain, managedSet.has(domain)),
      },
    },
    condition: {
      urlFilter: `||${domain}^`,
      resourceTypes: ['main_frame'],
    },
  }));
}

export function findMatchingDomain(url, blockedDomains = []) {
  const host = canonicalHost(url);
  if (!host) return null;
  const compiled = compileDomains(blockedDomains);
  return setCovers(compiled, host) ? host : null;
}
