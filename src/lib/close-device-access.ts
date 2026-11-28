import AsyncStorage from '@react-native-async-storage/async-storage';
import { Platform } from 'react-native';
import BloomBlocking from '../../modules/bloom-blocking/src/BloomBlockingModule';
import { finishBlockingRulesSync } from './blocking-rules-sync';
import { isMacDesktop, macCreditMarker, macUsageKey, macosFilter, type MacCreditTargets } from './macos-blocking';
import { clearStoreBilling } from './store-billing';

// Close account-bound access before replacing or ending an Auth session.
export async function closeDeviceAccess(userId: string) {
  await clearStoreBilling().catch(() => undefined);
  if (isMacDesktop()) {
    if (await AsyncStorage.getItem(macUsageKey(userId))) {
      const usage = (await macosFilter('getUsageAccess')).usage;
      if (usage?.userId === userId) await macosFilter('closeUsageAccess', undefined, undefined, undefined, undefined, { userId });
    }
    const marker = macCreditMarker(userId);
    const stored = await AsyncStorage.getItem(marker);
    if (stored) {
      const parsed: unknown = JSON.parse(stored);
      const targets: unknown = parsed && typeof parsed === 'object' && 'targets' in parsed ? parsed.targets : parsed;
      if (!targets || typeof targets !== 'object' || !('websites' in targets) || !('apps' in targets)
        || typeof targets.websites !== 'boolean' || typeof targets.apps !== 'boolean') throw new Error('Invalid credit session.');
      await macosFilter('endCreditAccess', undefined, undefined, undefined,
        { websites: targets.websites, apps: targets.apps } as MacCreditTargets, undefined, userId);
      await AsyncStorage.removeItem(marker);
    }
  }
  if (Platform.OS === 'android' || Platform.OS === 'ios') {
    const usage = BloomBlocking.getUsageAccess();
    if (usage?.userId === userId) await BloomBlocking.closeUsageAccess(userId);
    await BloomBlocking.endCreditAccess();
    if (Platform.OS === 'android' || Platform.OS === 'ios') {
      await finishBlockingRulesSync(userId, Platform.OS);
      // Older native builds have no independent Manual Focus account state.
      if (typeof BloomBlocking.clearFocusAccount === 'function') await BloomBlocking.clearFocusAccount(userId);
    }
  }
}
