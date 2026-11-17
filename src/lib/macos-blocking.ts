import { invoke, isTauri } from '@tauri-apps/api/core';
import { Platform } from 'react-native';
import type { UsageAccess } from '../../modules/bloom-blocking/src/BloomBlocking.types';
export { parseMacCreditMarker, type MacCreditMarker } from './mac-credit-marker';

type FilterResult = { ok: boolean; status?: string; domains?: string[]; apps?: string[]; installedApps?: { apps: { id: string; name: string }[]; truncated: boolean }; managedApps?: string[]; managedDomains?: string[]; managedRuleAccountId?: string; appEnabled?: boolean; appConfigured?: boolean; appService?: string; websiteUsageAvailable?: boolean; websiteProviderHealthy?: boolean; websitePolicyBrokerStatus?: string; accessibilityTrusted?: boolean; browserName?: string; browserAddressStatus?: string; browserAutomationStatus?: string; supportedBrowsers?: string[]; browserHideFailed?: boolean; appHideFailed?: boolean; selectedAppId?: string; selectedAppName?: string; error?: string; elapsedMillis?: number; boot?: number; remainingMillis?: number; usage?: UsageAccess | null };
type FilterTiming = { requestId: string; deviceKey: string; minutes: number; accessToken: string };
export type MacCreditTargets = { websites: boolean; apps: boolean };
export type MacUsageRequest = { sessionId?: string; userId: string; kind?: 'easy' | 'countdown'; requestId?: string; deviceKey?: string; requestedMillis?: number; accessToken?: string };

export function isMacDesktop() {
  return Platform.OS === 'web' && isTauri();
}

export function macCreditMarker(userId: string) { return `bloom-mac-active:${userId}`; }
export function macUsageKey(userId: string) { return `bloom-mac-usage:${userId}`; }


export async function macosFilter(action: 'activate' | 'start' | 'stop' | 'clearManualDomains' | 'cleanupHosts' | 'hostsRecoveryStatus' | 'hostsPolicyStatus' | 'syncHostsManaged' | 'enrollHosts' | 'startHostsUsage' | 'stopHostsUsage' | 'clearManualApps' | 'status' | 'appStatus' | 'clock' | 'startCreditAccess' | 'endCreditAccess' | 'activateApps' | 'chooseApp' | 'listInstalledApps' | 'startApps' | 'stopApps' | 'getUsageAccess' | 'startUsageAccess' | 'closeUsageAccess' | 'clearUsageAccess' | 'openAccessibilitySettings' | 'syncManagedRules', domains?: string[], timing?: FilterTiming, apps?: string[], targets?: MacCreditTargets, usage?: MacUsageRequest, accountId?: string) {
  let result: FilterResult;
  try { result = await invoke<FilterResult>('macos_filter', { action, domains, apps, timing, targets, usage, accountId }); }
  catch (cause) { throw new Error(typeof cause === 'string' ? cause : 'Could not contact the macOS filter.'); }
  if (!result.ok) throw new Error(result.error || 'Could not update the macOS filter.');
  return result;
}
