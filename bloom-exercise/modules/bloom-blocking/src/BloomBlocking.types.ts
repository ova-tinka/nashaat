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
};

export type AppCandidate = { id: string; name: string };

export type ManagedTargets = { apps: string[]; websites: string[]; accountId?: string | null };

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
