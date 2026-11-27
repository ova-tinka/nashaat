import { invoke, isTauri } from '@tauri-apps/api/core';
import { Platform } from 'react-native';
import type { UsageAccess } from '../../modules/bloom-blocking/src/BloomBlocking.types';
import { isMacTauriWebView } from './platform-capabilities';
export { parseMacCreditMarker, type MacCreditMarker } from './mac-credit-marker';

type FilterResult = { ok: boolean; status?: string; domains?: string[]; apps?: string[]; installedApps?: { apps: { id: string; name: string }[]; truncated: boolean }; managedApps?: string[]; managedDomains?: string[]; managedRuleAccountId?: string; appEnabled?: boolean; appConfigured?: boolean; appService?: string; websiteUsageAvailable?: boolean; websiteProviderHealthy?: boolean; websitePolicyBrokerStatus?: string; accessibilityTrusted?: boolean; browserName?: string; browserAddressStatus?: string; browserAutomationStatus?: string; supportedBrowsers?: string[]; browserHideFailed?: boolean; appHideFailed?: boolean; selectedAppId?: string; selectedAppName?: string; error?: string; elapsedMillis?: number; boot?: number; remainingMillis?: number; usage?: UsageAccess | null };
type FilterTiming = { requestId: string; deviceKey: string; minutes: number; accessToken: string };
export type MacCreditTargets = { websites: boolean; apps: boolean };
export type MacUsageRequest = { sessionId?: string; userId: string; kind?: 'easy' | 'countdown'; requestId?: string; deviceKey?: string; requestedMillis?: number; accessToken?: string };

export function isMacDesktop() {
  if (Platform.OS !== 'web' || !isTauri() || typeof navigator === 'undefined') return false;
  return isMacTauriWebView(navigator.platform, navigator.userAgent);
}

export function macCreditMarker(userId: string) { return `bloom-mac-active:${userId}`; }
export function macUsageKey(userId: string) { return `bloom-mac-usage:${userId}`; }


type MacosFilterAction =
  | 'activate' | 'start' | 'stop' | 'clearManualDomains' | 'cleanupHosts' | 'hostsRecoveryStatus'
  | 'hostsPolicyStatus' | 'syncHostsManaged' | 'enrollHosts' | 'startHostsUsage' | 'stopHostsUsage'
  | 'clearManualApps' | 'status' | 'appStatus' | 'clock' | 'startCreditAccess' | 'endCreditAccess'
  | 'activateApps' | 'chooseApp' | 'listInstalledApps' | 'startApps' | 'stopApps'
  | 'getUsageAccess' | 'startUsageAccess' | 'closeUsageAccess' | 'clearUsageAccess'
  | 'openAccessibilitySettings' | 'syncManagedRules';

function typedCommandForAction(action: MacosFilterAction): string {
  switch (action) {
    case 'status':
    case 'appStatus':
    case 'clock':
    case 'hostsRecoveryStatus':
    case 'hostsPolicyStatus':
    case 'openAccessibilitySettings':
      return 'macos_blocking_status';
    case 'activate':
    case 'start':
    case 'stop':
    case 'clearManualDomains':
    case 'cleanupHosts':
    case 'syncHostsManaged':
    case 'enrollHosts':
    case 'syncManagedRules':
      return 'macos_manage_website_rules';
    case 'activateApps':
    case 'chooseApp':
    case 'listInstalledApps':
    case 'startApps':
    case 'stopApps':
    case 'clearManualApps':
      return 'macos_manage_app_rules';
    case 'startCreditAccess':
    case 'endCreditAccess':
      return 'macos_credit_session';
    case 'getUsageAccess':
    case 'startUsageAccess':
    case 'closeUsageAccess':
    case 'clearUsageAccess':
    case 'startHostsUsage':
    case 'stopHostsUsage':
      return 'macos_usage_session';
  }
}

export async function macosFilter(action: MacosFilterAction, domains?: string[], timing?: FilterTiming, apps?: string[], targets?: MacCreditTargets, usage?: MacUsageRequest, accountId?: string) {
  let result: FilterResult;
  const command = typedCommandForAction(action);
  try { result = await invoke<FilterResult>(command, { action, domains, apps, timing, targets, usage, accountId }); }
  catch (cause) { throw new Error(typeof cause === 'string' ? cause : 'Could not contact the macOS filter.'); }
  if (!result.ok) throw new Error(result.error || 'Could not update the macOS filter.');
  return result;
}
