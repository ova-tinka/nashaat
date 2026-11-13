import { NativeModule, requireNativeModule } from 'expo';
import type { AppCandidate, BlockingStatus, ManagedTargets, UsageAccess } from './BloomBlocking.types';

declare class BloomBlockingNativeModule extends NativeModule {
  getStatus(): BlockingStatus;
  requestAuthorization(): Promise<boolean>;
  presentPicker(): Promise<{ appCount: number; websiteCount: number; categoryCount: number; cancelled: boolean }>;
  getInstalledApps(): AppCandidate[];
  getSelectedApps(): string[];
  getManagedTargets(): ManagedTargets;
  getWebsites(): string[];
  getWebsiteConsent(): boolean;
  requestAccessibilityPermission(): Promise<boolean>;
  saveApps(packageIds: string[]): Promise<void>;
  saveWebsites(addresses: string[]): Promise<void>;
  setManagedTargets(packageIds: string[], addresses: string[], accountId: string): Promise<void>;
  setWebsiteConsent(enabled: boolean): Promise<void>;
  startBlocking(): Promise<void>;
  stopBlocking(): Promise<void>;
  getCreditClock(): { elapsedMillis: number; boot: number };
  getCreditAccessRemaining(): number;
  getUsageAccess(): UsageAccess | null;
  startUsageAccess(sessionId: string, userId: string, budgetMillis: number, expiryMillis: number, requestElapsedMillis: number, requestBoot: number): Promise<void>;
  closeUsageAccess(userId: string): Promise<UsageAccess | null>;
  clearUsageAccess(userId: string, sessionId: string): Promise<void>;
  startCreditAccess(durationMillis: number, requestElapsedMillis: number, requestBoot: number): Promise<void>;
  endCreditAccess(): Promise<void>;
}

export default requireNativeModule<BloomBlockingNativeModule>('BloomBlocking');
