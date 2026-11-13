import BloomBlocking from '../../modules/bloom-blocking/src/BloomBlockingModule';
import type { ChildRule } from './family';
import { loadUserBlockingRules } from './family';
import { macosFilter } from './macos-blocking';
import { createBlockingRulesCoordinator } from './blocking-rules-coordinator';

export type BlockingRulesPlatform = ChildRule['platform'];
export type BlockingRulesSyncResult = { rules: ChildRule[]; nativeStatus: string | null };

const coordinator = createBlockingRulesCoordinator();
const scope = (userId: string, platform: BlockingRulesPlatform) => `${platform}:${userId}`;

/** Serialize native writes; never let a stale fetch replace a newer account's rules. */
export async function syncBlockingRules(userId: string, platform: BlockingRulesPlatform): Promise<BlockingRulesSyncResult | null> {
  const result = await coordinator.sync(scope(userId, platform), () => loadUserBlockingRules(userId, platform), async (rules) => {
    const apps = rules.filter((rule) => rule.target_type === 'app').map((rule) => rule.target_identifier);
    const websites = rules.filter((rule) => rule.target_type === 'website').map((rule) => rule.target_identifier);
    if (platform === 'android') {
      await BloomBlocking.setManagedTargets(apps, websites, userId);
      return BloomBlocking.getStatus().serviceHealth ?? null;
    }
    if (platform === 'macos') {
      const native = await macosFilter('syncManagedRules', websites, undefined, apps, undefined, undefined, userId);
      return native.status ?? 'synced';
    }
    return 'deviceSelectionRequired';
  });
  return result ? { rules: result.rules, nativeStatus: result.status } : null;
}

export function cancelBlockingRulesSync(userId: string, platform: BlockingRulesPlatform) {
  coordinator.cancel(scope(userId, platform));
}
