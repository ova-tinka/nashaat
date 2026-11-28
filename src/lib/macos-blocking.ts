import { invoke, isTauri } from '@tauri-apps/api/core';
import { Platform } from 'react-native';
import type { UsageAccess } from '../../modules/bloom-blocking/src/BloomBlocking.types';
import { isMacTauriWebView } from './platform-capabilities';
export { parseMacCreditMarker, type MacCreditMarker } from './mac-credit-marker';

export type BrowserProtectionEntry = {
  id: string;
  name: string;
  installed: boolean;
  nativeBridgeInstalled: boolean;
  externalExtensionConfigured: boolean;
  managedProfileEnforced: boolean;
  extensionHeartbeatFresh: boolean;
  lastHeartbeatMillis: number;
};

export type BrowserProtectionSnapshot = {
  storeExtensionConfigured: boolean;
  storeExtensionId: string;
  browsers: BrowserProtectionEntry[];
  safariBundled: boolean;
  safariEnabled?: boolean | null;
};

export type MacSelfCheckReport = {
  monitorLive: boolean;
  policyBrokerReady: boolean;
  filterProviderHealthy: boolean;
  filterVersion: string;
  accessibilityTrusted: boolean;
  browserProtection: BrowserProtectionSnapshot;
};

type FilterResult = {
  ok: boolean;
  status?: string;
  domains?: string[];
  apps?: string[];
  installedApps?: { apps: { id: string; name: string }[]; truncated: boolean };
  managedApps?: string[];
  managedDomains?: string[];
  managedRuleAccountId?: string;
  appEnabled?: boolean;
  appConfigured?: boolean;
  appService?: string;
  websiteUsageAvailable?: boolean;
  websiteProviderHealthy?: boolean;
  websitePolicyBrokerStatus?: string;
  accessibilityTrusted?: boolean;
  browserName?: string;
  browserAddressStatus?: string;
  browserAutomationStatus?: string;
  supportedBrowsers?: string[];
  browserHideFailed?: boolean;
  appHideFailed?: boolean;
  selectedAppId?: string;
  selectedAppName?: string;
  error?: string;
  elapsedMillis?: number;
  boot?: number;
  remainingMillis?: number;
  usage?: UsageAccess | null;
  browserProtection?: BrowserProtectionSnapshot;
  selfCheck?: MacSelfCheckReport;
};

type FilterTiming = { requestId: string; deviceKey: string; minutes: number; accessToken: string };
export type MacCreditTargets = { websites: boolean; apps: boolean };
export type MacUsageRequest = { sessionId?: string; userId: string; kind?: 'easy' | 'countdown'; requestId?: string; deviceKey?: string; requestedMillis?: number; accessToken?: string };

export function isMacDesktop() {
  if (Platform.OS !== 'web' || !isTauri() || typeof navigator === 'undefined') return false;
  return isMacTauriWebView(navigator.platform, navigator.userAgent);
}

export function macCreditMarker(userId: string) { return `bloom-mac-active:${userId}`; }
export function macUsageKey(userId: string) { return `bloom-mac-usage:${userId}`; }

export type MacosFilterAction =
  | 'activate'
  | 'start'
  | 'stop'
  | 'clearManualDomains'
  | 'cleanupHosts'
  | 'hostsRecoveryStatus'
  | 'hostsPolicyStatus'
  | 'syncHostsManaged'
  | 'enrollHosts'
  | 'startHostsUsage'
  | 'stopHostsUsage'
  | 'clearManualApps'
  | 'status'
  | 'appStatus'
  | 'clock'
  | 'startCreditAccess'
  | 'endCreditAccess'
  | 'activateApps'
  | 'chooseApp'
  | 'listInstalledApps'
  | 'startApps'
  | 'stopApps'
  | 'getUsageAccess'
  | 'startUsageAccess'
  | 'closeUsageAccess'
  | 'clearUsageAccess'
  | 'openAccessibilitySettings'
  | 'openLoginItemsSettings'
  | 'installBrowserBridge'
  | 'installBrowserProtection'
  | 'openBrowserPolicyProfile'
  | 'browserProtectionStatus'
  | 'selfCheck'
  | 'syncDisplayBalance'
  | 'syncManagedRules';

export type MacDisplayBalancePayload = {
  creditsEnabled: boolean;
  balanceMinutes: number;
};

export async function macosFilter(
  action: MacosFilterAction,
  domains?: string[],
  timing?: FilterTiming,
  apps?: string[],
  targets?: MacCreditTargets,
  usage?: MacUsageRequest,
  accountId?: string,
  strict?: boolean,
  displayBalance?: MacDisplayBalancePayload,
) {
  let result: FilterResult;
  try { result = await invoke<FilterResult>('macos_filter', { action, domains, apps, timing, targets, usage, accountId, strict, displayBalance }); }
  catch (cause) { throw new Error(typeof cause === 'string' ? cause : 'Could not contact the macOS filter.'); }
  if (!result.ok) throw new Error(result.error || 'Could not update the macOS filter.');
  return result;
}
