export type BlockingStatus = {
  supported: boolean;
  authorized: boolean;
  active: boolean;
  appCount: number;
  websiteCount: number;
  categoryCount: number;
  serviceConnected?: boolean;
  serviceHealth?: 'connected' | 'stopped' | 'serviceUnavailable' | 'permissionRequired';
  supportedBrowsers?: string[];
  scheduledActiveCount?: number;
  scheduleError?: boolean;
  manualFocusActive?: boolean;
  manualFocusError?: boolean;
};

export type IosManualFocus = { appCount: number; websiteCount: number; categoryCount: number; active: boolean };
export type IosFocusRoutineSelection = { appCount: number; websiteCount: number; categoryCount: number };

export type AppAccessDecision = { blocked: boolean; reasons: string[]; enforceable: boolean };

export type AppCandidate = { id: string; name: string; icon?: string };

export type ManagedTargets = { apps: string[]; websites: string[]; accountId?: string | null };
export type SafariContentBlockerState = { bundled: boolean; stateAvailable: boolean; enabled: boolean };
export type WebsiteRuleSyncStatus = {
  alwaysApplied: boolean;
  authorizationRequired: boolean;
  alwaysDomainCount: number;
};

export type UsageAccess = {
  sessionId: string;
  userId: string;
  budgetMillis: number;
  usedMillis: number;
  remainingMillis: number;
  closed: boolean;
  tracking: boolean;
  verified?: boolean;
};
