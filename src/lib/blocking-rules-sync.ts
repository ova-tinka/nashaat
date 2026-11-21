import BloomBlocking from '../../modules/bloom-blocking/src/BloomBlockingModule';
import type { ChildRule } from './family';
import { loadUserBlockingRules, loadWebsiteRules } from './family';
import { canonicalWebsiteDomain } from './website-domain';
import { macosFilter } from './macos-blocking';
import { createBlockingRulesCoordinator } from './blocking-rules-coordinator';

export type BlockingRulesPlatform = ChildRule['platform'];
export type BlockingRulesSyncResult = { rules: ChildRule[]; nativeStatus: string | null };

const coordinator = createBlockingRulesCoordinator();
const scope = (userId: string, platform: BlockingRulesPlatform) => `${platform}:${userId}`;

/** Serialize native writes; never let a stale fetch replace a newer account's rules. */
export async function syncBlockingRules(userId: string, platform: BlockingRulesPlatform): Promise<BlockingRulesSyncResult | null> {
  const result = await coordinator.sync(scope(userId, platform), async () => {
    const [rules, websiteRules] = await Promise.all([
      loadUserBlockingRules(userId, platform),
      platform === 'ios' ? loadWebsiteRules(userId) : Promise.resolve([]),
    ]);
    return { rules, websiteRules };
  }, async ({ rules, websiteRules }) => {
    const apps = rules.filter((rule) => rule.target_type === 'app').map((rule) => rule.target_identifier);
    const websiteIdentifiers = rules.filter((rule) => rule.target_type === 'website').map((rule) => rule.target_identifier);
    const websites = platform === 'ios'
      ? websiteIdentifiers.flatMap((value) => { const domain = canonicalWebsiteDomain(value); return domain ? [domain] : []; })
      : websiteIdentifiers;
    if (platform === 'android') {
      await BloomBlocking.setFocusAccount(userId);
      await BloomBlocking.setManagedTargets(apps, websites, userId);
      return BloomBlocking.getStatus().serviceHealth ?? null;
    }
    if (platform === 'macos') {
      const native = await macosFilter('syncManagedRules', websites, undefined, apps, undefined, undefined, userId);
      return native.status ?? 'synced';
    }
    await BloomBlocking.setFocusAccount(userId);
    const always = websiteRules.filter((rule) => rule.scope === 'always').map((rule) => rule.domain);
    const focus = [...websites, ...websiteRules.filter((rule) => rule.scope === 'focus').map((rule) => rule.domain)];
    const websiteStatus = await BloomBlocking.setSafariWebsiteRules(always, focus, userId);
    return websiteStatus.authorizationRequired ? 'websiteRulesAuthorizationRequired' : 'websiteRulesApplied';
  });
  return result ? { rules: result.rules.rules, nativeStatus: result.status } : null;
}

export function cancelBlockingRulesSync(userId: string, platform: BlockingRulesPlatform) {
  coordinator.cancel(scope(userId, platform));
}

/** Wait for an already-started native write before clearing account-local state. */
export async function finishBlockingRulesSync(userId: string, platform: BlockingRulesPlatform) {
  await coordinator.cancelAndWait(scope(userId, platform));
}
