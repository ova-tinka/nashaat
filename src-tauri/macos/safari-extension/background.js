import { compileDomains } from './lib/domain-policy.mjs';
import { blockPagePath, buildDynamicRules, findMatchingDomain } from './lib/extension-rules.mjs';

const ALARM_NAME = 'bloom-policy-sync';
const api = typeof browser !== 'undefined' ? browser : chrome;

let lastRuleSignature = null;
let syncInFlight = null;

async function sendNative(message) {
  try {
    const response = await api.runtime.sendNativeMessage('com.focusflow.focusFlowFlutter.safari-extension', message);
    return response || { ok: false, error: 'Could not reach Bloom.' };
  } catch (error) {
    return { ok: false, error: error instanceof Error ? error.message : 'Could not reach Bloom.' };
  }
}

async function applyRules(policy) {
  const rules = buildDynamicRules(policy);
  const signature = JSON.stringify(rules);
  if (signature === lastRuleSignature) return;

  const existing = await api.declarativeNetRequest.getDynamicRules();
  const removeRuleIds = existing.map((rule) => rule.id);
  await api.declarativeNetRequest.updateDynamicRules({
    removeRuleIds,
    addRules: rules,
  });
  lastRuleSignature = signature;
}

async function sweepOpenTabs(policy) {
  if (!policy.enabled) return;
  const combined = policy.accessAllowed
    ? [...new Set(policy.managedDomains || [])]
    : [...new Set([...(policy.blockedDomains || []), ...(policy.managedDomains || [])])];
  if (combined.length === 0) return;

  const managedSet = compileDomains(policy.managedDomains || []);
  const tabs = await api.tabs.query({ url: ['http://*/*', 'https://*/*'] });
  for (const tab of tabs) {
    if (!tab.id || !tab.url) continue;
    const host = findMatchingDomain(tab.url, combined);
    if (!host) continue;
    const targetUrl = api.runtime.getURL(blockPagePath(host, managedSet.has(host)));
    if (tab.url !== targetUrl) {
      await api.tabs.update(tab.id, { url: targetUrl }).catch(() => undefined);
    }
  }
}

async function syncPolicy() {
  if (syncInFlight) return syncInFlight;
  syncInFlight = (async () => {
    const response = await sendNative({ type: 'getPolicy' });
    if (!response.ok) {
      const fallback = {
        connected: false,
        enabled: false,
        blockedDomains: [],
        managedDomains: [],
        accessAllowed: false,
        remainingMillis: 0,
        error: response.error || 'Could not reach Bloom.',
        updatedAt: Date.now(),
      };
      await api.storage.local.set({ bloomStatus: fallback });
      return fallback;
    }

    const policy = {
      connected: true,
      enabled: Boolean(response.enabled),
      blockedDomains: Array.isArray(response.blockedDomains) ? response.blockedDomains : [],
      managedDomains: Array.isArray(response.managedDomains) ? response.managedDomains : [],
      accessAllowed: Boolean(response.accessAllowed),
      remainingMillis: Number(response.remainingMillis) || 0,
      creditsEnabled: Boolean(response.creditsEnabled),
      creditBalanceMinutes: typeof response.creditBalanceMinutes === 'number' ? response.creditBalanceMinutes : null,
      error: null,
      updatedAt: Date.now(),
    };

    await applyRules(policy);
    await sweepOpenTabs(policy);
    await api.storage.local.set({ bloomStatus: policy });
    return policy;
  })();

  try {
    return await syncInFlight;
  } finally {
    syncInFlight = null;
  }
}

api.runtime.onInstalled.addListener(() => {
  api.alarms.create(ALARM_NAME, { periodInMinutes: 1 });
  void syncPolicy();
});

api.runtime.onStartup.addListener(() => {
  api.alarms.create(ALARM_NAME, { periodInMinutes: 1 });
  void syncPolicy();
});

api.alarms.onAlarm.addListener((alarm) => {
  if (alarm.name === ALARM_NAME) {
    void syncPolicy();
  }
});

api.tabs.onActivated.addListener(() => {
  void syncPolicy();
});

api.tabs.onUpdated.addListener((_tabId, changeInfo) => {
  if (changeInfo.url || changeInfo.status === 'loading') {
    void syncPolicy();
  }
});

api.runtime.onMessage.addListener((message, _sender, sendResponse) => {
  if (message?.type === 'openBloom') {
    void sendNative({ type: 'openBloom' }).then(sendResponse);
    return true;
  }
  if (message?.type === 'getStatus') {
    void syncPolicy().then(sendResponse);
    return true;
  }
  return false;
});

void syncPolicy();
