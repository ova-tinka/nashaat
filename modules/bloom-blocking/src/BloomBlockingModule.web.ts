import { registerWebModule, NativeModule } from 'expo';

class BloomBlockingWebModule extends NativeModule {
  async setFocusAccount(_accountId: string) {}
  getFocusAccount() { return null; }
  async clearFocusAccount(_accountId: string) {}
  getFocusRoutines(_accountId: string) { return '[]'; }
  async saveFocusRoutines(_accountId: string, _raw: string) { throw new Error('Scheduled Focus is unavailable on this platform.'); }
  getStatus() { return { supported: false, authorized: false, active: false, appCount: 0, websiteCount: 0, categoryCount: 0 }; }
  async requestAuthorization() { return false; }
  async presentPicker() { return { appCount: 0, websiteCount: 0, categoryCount: 0, cancelled: true }; }
  getIosManualFocus(_accountId: string) { throw new Error('Manual Focus is unavailable on this platform.'); }
  getIosFocusRoutines(_accountId: string) { throw new Error('Scheduled Focus is unavailable on this platform.'); }
  getIosFocusRoutineSelection(_accountId: string, _routineId: string) { throw new Error('Scheduled Focus is unavailable on this platform.'); }
  async presentIosFocusRoutinePicker(_accountId: string, _routineId: string) { throw new Error('Scheduled Focus is unavailable on this platform.'); }
  async saveIosFocusRoutine(_accountId: string, _raw: string) { throw new Error('Scheduled Focus is unavailable on this platform.'); }
  async deleteIosFocusRoutine(_accountId: string, _routineId: string) { throw new Error('Scheduled Focus is unavailable on this platform.'); }
  async presentIosManualPicker(_accountId: string) { throw new Error('Manual Focus is unavailable on this platform.'); }
  async startIosManualFocus(_accountId: string) { throw new Error('Manual Focus is unavailable on this platform.'); }
  async stopIosManualFocus(_accountId: string) { throw new Error('Manual Focus is unavailable on this platform.'); }
  getManualFocus(_accountId: string) { throw new Error('Manual Focus is unavailable on this platform.'); }
  async saveManualFocus(_accountId: string, _raw: string) { throw new Error('Manual Focus is unavailable on this platform.'); }
  async startManualFocus(_accountId: string, _durationMillis: number) { throw new Error('Manual Focus is unavailable on this platform.'); }
  async stopManualFocus(_accountId: string) { throw new Error('Manual Focus is unavailable on this platform.'); }
  getAppAccessDecision(_accountId: string, _packageId: string) { throw new Error('Blocking explanations are unavailable on this platform.'); }
  getWebsiteAccessDecision(_accountId: string, _address: string) { throw new Error('Blocking explanations are unavailable on this platform.'); }
  getInstalledApps() { return []; }
  getSelectedApps() { return []; }
  getManagedTargets() { return { apps: [], websites: [], accountId: null }; }
  getWebsites() { return []; }
  getWebsiteConsent() { return false; }
  async getSafariContentBlockerState() { return { bundled: false, stateAvailable: false, enabled: false }; }
  async requestAccessibilityPermission() { return false; }
  async saveApps(_packageIds: string[]) {}
  async saveWebsites(_addresses: string[]) {}
  async setManagedTargets(_packageIds: string[], _addresses: string[], _accountId: string) {}
  async setWebsiteConsent(_enabled: boolean) {}
  async setSafariWebsiteRules(_alwaysDomains: string[], _focusDomains: string[], _accountId: string) { return { alwaysApplied: false, authorizationRequired: false, alwaysDomainCount: 0 }; }
  async startBlocking() { throw new Error('Blocking is unavailable in a web browser.'); }
  async stopBlocking() {}
  getCreditClock() { return { elapsedMillis: 0, boot: -1 }; }
  getCreditAccessRemaining() { return 0; }
  getUsageAccess() { return null; }
  async startUsageAccess(_sessionId: string, _userId: string, _budgetMillis: number, _expiryMillis: number, _requestElapsedMillis: number, _requestBoot: number) { throw new Error('Usage tracking is unavailable in a web browser.'); }
  async closeUsageAccess(_userId: string) { return null; }
  async clearUsageAccess(_userId: string, _sessionId: string) {}
  async startCreditAccessForAccount(_accountId: string, _durationMillis: number, _requestElapsedMillis: number, _requestBoot: number) { throw new Error('Credit access is unavailable in a web browser.'); }
  async startCreditAccess(_durationMillis: number, _requestElapsedMillis: number, _requestBoot: number) { throw new Error('Credit access is unavailable in a web browser.'); }
  async endCreditAccess() {}
}

export default registerWebModule(BloomBlockingWebModule, 'BloomBlocking');
