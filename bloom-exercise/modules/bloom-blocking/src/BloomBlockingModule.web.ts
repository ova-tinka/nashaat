import { registerWebModule, NativeModule } from 'expo';

class BloomBlockingWebModule extends NativeModule {
  getStatus() { return { supported: false, authorized: false, active: false, appCount: 0, websiteCount: 0, categoryCount: 0 }; }
  async requestAuthorization() { return false; }
  async presentPicker() { return { appCount: 0, websiteCount: 0, categoryCount: 0, cancelled: true }; }
  getInstalledApps() { return []; }
  getSelectedApps() { return []; }
  getManagedTargets() { return { apps: [], websites: [], accountId: null }; }
  getWebsites() { return []; }
  getWebsiteConsent() { return false; }
  async requestAccessibilityPermission() { return false; }
  async saveApps(_packageIds: string[]) {}
  async saveWebsites(_addresses: string[]) {}
  async setManagedTargets(_packageIds: string[], _addresses: string[], _accountId: string) {}
  async setWebsiteConsent(_enabled: boolean) {}
  async startBlocking() { throw new Error('Blocking is unavailable in a web browser.'); }
  async stopBlocking() {}
  getCreditClock() { return { elapsedMillis: 0, boot: -1 }; }
  getCreditAccessRemaining() { return 0; }
  getUsageAccess() { return null; }
  async startUsageAccess(_sessionId: string, _userId: string, _budgetMillis: number, _expiryMillis: number, _requestElapsedMillis: number, _requestBoot: number) { throw new Error('Usage tracking is unavailable in a web browser.'); }
  async closeUsageAccess(_userId: string) { return null; }
  async clearUsageAccess(_userId: string, _sessionId: string) {}
  async startCreditAccess(_durationMillis: number, _requestElapsedMillis: number, _requestBoot: number) { throw new Error('Credit access is unavailable in a web browser.'); }
  async endCreditAccess() {}
}

export default registerWebModule(BloomBlockingWebModule, 'BloomBlocking');
