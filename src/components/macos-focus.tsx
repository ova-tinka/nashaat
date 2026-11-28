import { getAppLocale } from '../lib/locale-context';
import AsyncStorage from '@react-native-async-storage/async-storage';
import { randomUUID } from 'expo-crypto';
import { useCallback, useEffect, useRef, useState, type ReactNode } from 'react';
import { router, useFocusEffect } from 'expo-router';
import { Pressable, ScrollView, StyleSheet, View } from 'react-native';
import MaterialIcons from '@expo/vector-icons/MaterialIcons';
import { Body, Button, ErrorText, Eyebrow, Field, Heading, Label, Panel, Screen, sharedStyles } from './bloom-ui';
import { macCreditMarker, macUsageKey, macosFilter, parseMacCreditMarker, type BrowserProtectionSnapshot, type MacCreditMarker, type MacSelfCheckReport } from '../lib/macos-blocking';
import { suggestCompanionDomains } from '../lib/domain-presets';
import { useAuth } from '../lib/auth';
import { useBloom } from '../lib/bloom-context';
import { findUsageSession, finishUsageSession } from '../lib/bloom';
import type { UsageAccess } from '../../modules/bloom-blocking/src/BloomBlocking.types';
import { matchesMacUsageReservation, parseMacUsageRequest, recoverOrCreateMacUsageRequest } from '../lib/mac-credit-marker';
import type { FocusSettingsSection } from './focus-section-navigation';
import { useBloomTheme } from '../lib/theme-context';

export function MacosFocus({ initialSection, openEarned = false }: {
  initialSection: FocusSettingsSection;
  openEarned?: boolean;
}) {
  const { session, profileId } = useAuth();
  const userId = profileId;
  const { creditsEnabled, creditSettings, creditBalance, refresh, blockingRules, blockingRulesSyncError, blockingRulesSyncedAt, blockingRulesSyncStatus, loading, error: accountError } = useBloom();
  const [sites, setSites] = useState<string[]>([]);
  const [input, setInput] = useState('');
  const [enabled, setEnabled] = useState(false);
  const [websiteCheck, setWebsiteCheck] = useState<'checking' | 'available' | 'unavailable'>('checking');
  const [appCheck, setAppCheck] = useState<'checking' | 'available' | 'unavailable'>('checking');
  const [activationStatus, setActivationStatus] = useState<string>('unknown');
  const [apps, setApps] = useState<string[]>([]);
  const [managedApps, setManagedApps] = useState<string[]>([]);
  const [managedSites, setManagedSites] = useState<string[]>([]);
  const [appInput, setAppInput] = useState('');
  const [appCatalog, setAppCatalog] = useState<{ apps: { id: string; name: string }[]; truncated: boolean } | null>(null);
  const [appSearch, setAppSearch] = useState('');
  const [showAppPicker, setShowAppPicker] = useState(false);
  const [showManualAppEntry, setShowManualAppEntry] = useState(false);
  const [appSettingsOverride, setAppSettingsOverride] = useState<{ section: FocusSettingsSection; expanded: boolean } | null>(null);
  const [websiteSettingsOverride, setWebsiteSettingsOverride] = useState<{ section: FocusSettingsSection; expanded: boolean } | null>(null);
  const showAppSettings = appSettingsOverride?.section === initialSection
    ? appSettingsOverride.expanded : initialSection === 'apps' || initialSection === 'rules';
  const showWebsiteSettings = websiteSettingsOverride?.section === initialSection
    ? websiteSettingsOverride.expanded : initialSection === 'websites' || initialSection === 'rules';
  const [showWebsiteDetails, setShowWebsiteDetails] = useState(false);
  const [showHostsAdvanced, setShowHostsAdvanced] = useState(false);
  const [earnedOverride, setEarnedOverride] = useState<boolean | null>(null);
  const showEarnedAccess = earnedOverride ?? (openEarned || initialSection === 'earned');
  const [companionSuggestions, setCompanionSuggestions] = useState<string[]>([]);
  const [browserProtection, setBrowserProtection] = useState<BrowserProtectionSnapshot | null>(null);
  const [selfCheckReport, setSelfCheckReport] = useState<MacSelfCheckReport | null>(null);
  const [appEnabled, setAppEnabled] = useState(false);
  const [appConfigured, setAppConfigured] = useState(false);
  const [appService, setAppService] = useState('unavailable');
  const [accessibilityTrusted, setAccessibilityTrusted] = useState(false);
  const [browserName, setBrowserName] = useState('');
  const [browserAddressStatus, setBrowserAddressStatus] = useState('inactive');
  const [browserAutomationStatus, setBrowserAutomationStatus] = useState('notRequested');
  const [browserHideFailed, setBrowserHideFailed] = useState(false);
  const [appHideFailed, setAppHideFailed] = useState(false);
  const [supportedBrowsers, setSupportedBrowsers] = useState<string[]>([]);
  const [busy, setBusy] = useState(false);
  const [message, setMessage] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [minutes, setMinutes] = useState('5');
  const [remaining, setRemaining] = useState(0);
  const [creditRecoveryStatus, setCreditRecoveryStatus] = useState<'none' | 'checking' | 'active' | 'blocked' | 'expired' | 'rejected'>('none');
  const countdownWasRunning = useRef(false);
  const loadVersion = useRef(0);
  const protectionCheckVersion = useRef(0);
  const hostsCheckVersion = useRef(0);
  const hostsPolicyVersion = useRef(0);
  const [pending, setPending] = useState<{ requestId: string; deviceKey: string; minutes: number } | null>(null);
  const [usage, setUsage] = useState<UsageAccess | null>(null);
  const [usageRequest, setUsageRequest] = useState<{ requestId: string; deviceKey: string; requestedMillis: number } | null>(null);
  const [usageAvailable, setUsageAvailable] = useState(false);
  const [websiteUsageAvailable, setWebsiteUsageAvailable] = useState(false);
  const [websiteProviderHealthy, setWebsiteProviderHealthy] = useState(false);
  const [hostsRecovery, setHostsRecovery] = useState<'checking' | 'clear' | 'review' | 'busy' | 'unsafe' | 'unavailable'>('checking');
  const [hostsPolicy, setHostsPolicy] = useState<string>('checking');
  const [hostsPolicyAccount, setHostsPolicyAccount] = useState<string | null>(null);
  const [hostsManagedSync, setHostsManagedSync] = useState<{ account: string; status: 'current' | 'pending' } | null>(null);
  const visibleHostsPolicy = hostsPolicyAccount === profileId ? hostsPolicy : 'checking';
  const [websitePolicyBrokerStatus, setWebsitePolicyBrokerStatus] = useState('unknown');
  const pendingKey = `bloom-mac-countdown:${profileId ?? ''}`;
  const usageKey = macUsageKey(profileId ?? '');

  const load = useCallback(async () => {
    const version = ++loadVersion.current;
    try {
      const [website, application, usageResult, browserResult] = await Promise.allSettled([
        macosFilter('status'),
        macosFilter('appStatus'),
        macosFilter('getUsageAccess'),
        macosFilter('browserProtectionStatus'),
      ]);
      if (version !== loadVersion.current) return;
      setWebsiteCheck(website.status === 'fulfilled' ? 'available' : 'unavailable');
      setAppCheck(application.status === 'fulfilled' ? 'available' : 'unavailable');
      if (browserResult.status === 'fulfilled' && browserResult.value.browserProtection) {
        setBrowserProtection(browserResult.value.browserProtection);
      }
      if (website.status === 'rejected' && application.status === 'rejected') throw new Error('Could not check blocking on this Mac.');
      if (website.status === 'fulfilled') { setEnabled(website.value.status === 'enabled'); setSites(website.value.domains ?? []); setManagedSites(website.value.managedDomains ?? []); }
      if (application.status === 'fulfilled') {
        setApps(application.value.apps ?? []);
        setAppEnabled(application.value.appEnabled ?? false);
        setAppConfigured(application.value.appConfigured ?? application.value.appEnabled ?? false);
        setAppService(application.value.appService ?? 'unavailable');
        setWebsiteUsageAvailable(application.value.websiteUsageAvailable ?? false);
        setWebsiteProviderHealthy(application.value.websiteProviderHealthy ?? false);
        setWebsitePolicyBrokerStatus(application.value.websitePolicyBrokerStatus ?? 'unknown');
        setAccessibilityTrusted(application.value.accessibilityTrusted ?? false);
        setBrowserName(application.value.browserName ?? '');
        setBrowserAddressStatus(application.value.browserAddressStatus ?? 'inactive');
        setBrowserAutomationStatus(application.value.browserAutomationStatus ?? 'notRequested');
        setBrowserHideFailed(application.value.browserHideFailed ?? false);
        setAppHideFailed(application.value.appHideFailed ?? false);
        setSupportedBrowsers(application.value.supportedBrowsers ?? []);
        const currentRules = blockingRules.filter((rule) => rule.platform === 'macos');
        const remoteApps = currentRules.filter((rule) => rule.target_type === 'app').map((rule) => rule.target_identifier);
        const remoteSites = currentRules.filter((rule) => rule.target_type === 'website').map((rule) => rule.target_identifier);
        if (blockingRulesSyncError && application.value.managedRuleAccountId === userId) {
          setManagedApps(application.value.managedApps ?? []);
          setManagedSites(website.status === 'fulfilled' ? website.value.managedDomains ?? [] : []);
        } else {
          setManagedApps(remoteApps);
          setManagedSites(remoteSites);
        }
      }
      setUsageAvailable(usageResult.status === 'fulfilled');
      if (usageResult.status === 'fulfilled') setUsage(usageResult.value.usage ?? null);
      setRemaining(Math.max(website.status === 'fulfilled' ? website.value.remainingMillis ?? 0 : 0, application.status === 'fulfilled' ? application.value.remainingMillis ?? 0 : 0));
      if (userId) {
        const marker = parseMacCreditMarker(await AsyncStorage.getItem(macCreditMarker(userId)), userId);
        if (version !== loadVersion.current) return;
        if (marker) setCreditRecoveryStatus((website.status === 'fulfilled' ? website.value.remainingMillis ?? 0 : 0) > 0
          || (application.status === 'fulfilled' ? application.value.remainingMillis ?? 0 : 0) > 0 ? 'active' : 'blocked');
        else setCreditRecoveryStatus('none');
      }
      const storedUsage = await AsyncStorage.getItem(usageKey);
      if (version !== loadVersion.current) return;
      setUsageRequest(parseMacUsageRequest(storedUsage));
      const stored = await AsyncStorage.getItem(pendingKey);
      if (version !== loadVersion.current) return;
      if (stored) {
        const parsed: unknown = JSON.parse(stored);
        if (parsed && typeof parsed === 'object' && 'requestId' in parsed && 'deviceKey' in parsed && 'minutes' in parsed && typeof parsed.requestId === 'string' && typeof parsed.deviceKey === 'string' && typeof parsed.minutes === 'number') setPending({ requestId: parsed.requestId, deviceKey: parsed.deviceKey, minutes: parsed.minutes });
      } else setPending(null);
      if (blockingRulesSyncStatus === 'needsApproval') setMessage('Approve Bloom in macOS Privacy & Security to enforce parent-set rules.');
      else if (blockingRulesSyncStatus === 'needsRestart') setMessage('Restart your Mac to finish enabling parent-set rules.');
      else if (blockingRulesSyncStatus === 'unavailable') setMessage('Enable Bloom’s background monitor in System Settings to enforce parent-set rules.');
    } catch (cause) { if (version === loadVersion.current) setError(cause instanceof Error ? cause.message : 'Could not check website blocking.'); }
  }, [blockingRules, blockingRulesSyncError, blockingRulesSyncStatus, pendingKey, usageKey, userId]);
  useFocusEffect(useCallback(() => { void load(); }, [load]));
  useEffect(() => {
    const timer = setInterval(() => setRemaining((value) => Math.max(0, value - 1000)), 1000);
    return () => clearInterval(timer);
  }, []);
  useEffect(() => {
    const userId = profileId;
    if (!userId) return;
    const onRecovery = (event: Event) => {
      const detail = (event as CustomEvent<{ userId: string; status: typeof creditRecoveryStatus }>).detail;
      if (detail?.userId === userId) setCreditRecoveryStatus(detail.status);
    };
    window.addEventListener('bloom-mac-credit-recovery', onRecovery);
    return () => window.removeEventListener('bloom-mac-credit-recovery', onRecovery);
  }, [profileId]);
  useEffect(() => {
    if (remaining > 0) countdownWasRunning.current = true;
    else if (countdownWasRunning.current) {
      countdownWasRunning.current = false;
      void refresh();
    }
  }, [remaining, refresh]);
  useEffect(() => {
    const onFocus = () => { void load(); };
    window.addEventListener('focus', onFocus);
    return () => window.removeEventListener('focus', onFocus);
  }, [load]);

  async function startScreenTime() {
    const amount = pending?.minutes ?? Number(minutes);
    if (!Number.isFinite(amount) || amount <= 0 || amount > 1440) { setError('Enter a duration between 0 and 1,440 minutes.'); return; }
    if (!profileId || !session?.access_token) { setError('Sign in to use screen time.'); return; }
    setBusy(true); setError(null);
    try {
      if (!enabled && !appEnabled) throw new Error('Start app or website blocking first.');
      const request = pending ?? { requestId: randomUUID(), deviceKey: randomUUID(), minutes: amount };
      if (!pending) { await AsyncStorage.setItem(pendingKey, JSON.stringify(request)); setPending(request); }
      const targets = { websites: enabled, apps: appEnabled };
      const marker: MacCreditMarker = { userId: profileId, ...request, targets, state: 'starting' };
      await AsyncStorage.setItem(macCreditMarker(profileId), JSON.stringify(marker));
      const result = await macosFilter('startCreditAccess', undefined, {
        requestId: request.requestId, deviceKey: request.deviceKey, minutes: request.minutes, accessToken: session.access_token,
      }, undefined, targets, undefined, profileId);
      if (result.status === 'expired') {
        await AsyncStorage.removeItem(macCreditMarker(profileId));
        await AsyncStorage.removeItem(pendingKey); setPending(null); setCreditRecoveryStatus('expired');
        await refresh(); return;
      }
      if (result.status === 'rejected') {
        await AsyncStorage.removeItem(macCreditMarker(profileId));
        setCreditRecoveryStatus('rejected');
        throw new Error('Bloom could not start this screen-time session. Check your balance and active sessions, then try again.');
      }
      if (result.status !== 'allowed') throw new Error('Bloom could not confirm this screen-time session. Please try again.');
      await AsyncStorage.setItem(macCreditMarker(profileId), JSON.stringify({ ...marker, state: 'active' }));
      await AsyncStorage.removeItem(pendingKey); setPending(null);
      setCreditRecoveryStatus('active');
      await load(); await refresh();
    } catch (cause) { setError(cause instanceof Error ? cause.message : 'Could not start screen time. Retry the same request.'); }
    finally { setBusy(false); }
  }

  async function startActualUsage() {
    const userId = profileId;
    const accessToken = session?.access_token;
    const requestedMillis = usageRequest?.requestedMillis ?? Math.floor(Number(minutes) * 60000);
    if (!userId || !accessToken) { setError('Sign in to reserve screen time.'); return; }
    if (!Number.isSafeInteger(requestedMillis) || requestedMillis < 1000 || requestedMillis > 604800000) { setError('Enter an amount between one second and one week.'); return; }
    setBusy(true); setError(null);
    try {
      if ((!appEnabled && !enabled) || !usageAvailable) throw new Error('Start app or website blocking and the background monitor first.');
      if (enabled && !websiteUsageAvailable) throw new Error('Allow Bloom in macOS Accessibility settings before counting website use.');
      const existingUsage = (await macosFilter('getUsageAccess')).usage;
      const request = await recoverOrCreateMacUsageRequest(AsyncStorage, usageKey,
        () => ({ requestId: randomUUID(), deviceKey: randomUUID(), requestedMillis }), !!existingUsage);
      setUsageRequest(request);
      await macosFilter('startUsageAccess', undefined, undefined, undefined, undefined, { userId,
        requestId: request.requestId, deviceKey: request.deviceKey, requestedMillis: request.requestedMillis, accessToken });
      const result = await macosFilter('getUsageAccess'); setUsage(result.usage ?? null);
      await refresh();
    } catch (cause) { setError(cause instanceof Error ? cause.message : 'Could not reserve screen time. Retry the same request.'); }
    finally { setBusy(false); }
  }

  async function finishActualUsage() {
    const userId = profileId;
    if (!userId) { setError('Sign in to finish this screen-time session.'); return; }
    setBusy(true); setError(null);
    try {
      const request = parseMacUsageRequest(await AsyncStorage.getItem(usageKey));
      if (!request) throw new Error('This saved screen-time request is unavailable. Refresh your account and try again.');
      const local = (await macosFilter('getUsageAccess')).usage;
      const existing = await findUsageSession(userId, request.requestId);
      if (!matchesMacUsageReservation(userId, local, existing) || !existing) throw new Error('This screen-time request belongs to a different account or session.');
      const closed = (await macosFilter('closeUsageAccess', undefined, undefined, undefined, undefined, { userId })).usage;
      if (!closed) throw new Error('No screen-time session was found on this Mac.');
      if (closed.sessionId !== existing.id || closed.userId !== userId) throw new Error('The screen-time session changed. Retry sync.');
      setUsage(closed);
      await finishUsageSession(closed.sessionId, request.deviceKey);
      await macosFilter('clearUsageAccess', undefined, undefined, undefined, undefined, { userId, sessionId: closed.sessionId });
      await AsyncStorage.removeItem(usageKey); setUsage(null); setUsageRequest(null);
      await refresh();
    } catch (cause) { setError(cause instanceof Error ? cause.message : 'Could not sync usage. Retry to return unused credits.'); }
    finally { setBusy(false); }
  }

  async function cancelPendingUsage() {
    const userId = profileId;
    if (!userId || !usageRequest) return;
    setBusy(true); setError(null);
    try {
      if ((await macosFilter('getUsageAccess')).usage) throw new Error('Finish the Mac session before clearing this request.');
      const existing = await findUsageSession(userId, usageRequest.requestId);
      if (existing && !existing.settled_at) await finishUsageSession(existing.id, usageRequest.deviceKey);
      await AsyncStorage.removeItem(usageKey); setUsageRequest(null); await refresh();
    } catch (cause) { setError(cause instanceof Error ? cause.message : 'Could not cancel the screen-time request. Connect and try again.'); }
    finally { setBusy(false); }
  }

  async function run(action: 'activate' | 'start' | 'stop' | 'clearManualDomains' | 'clearManualApps' | 'activateApps' | 'startApps' | 'stopApps') {
    setBusy(true); setError(null); setMessage(null);
    try {
      const result = await macosFilter(action, action === 'start' ? sites : undefined, undefined, action === 'startApps' ? apps : undefined);
      if (action === 'activate' || action === 'start') setActivationStatus(result.status ?? 'unknown');
      if (result.status === 'needsApproval') setMessage('Approve Bloom in macOS Privacy & Security, then return here.');
      else if (result.status === 'needsBrokerApproval') setMessage('macOS is waiting for approval of Bloom’s website protection service. Open System Settings → General → Login Items & Extensions, allow Bloom, then try again.');
      else if (result.status === 'needsRestart') setMessage('Restart your Mac to finish enabling the filter.');
      else if (result.status === 'unavailable') throw new Error('The background monitor is unavailable. Check its macOS permission and try again.');
      else if (action === 'activate' || action === 'activateApps') setMessage('Setup checks finished. Confirm the status below before relying on protection.');
      await load();
    } catch (cause) { setError(cause instanceof Error ? cause.message : 'Could not update website blocking.'); }
    finally { setBusy(false); }
  }

  async function openAccessibilitySettings() {
    setBusy(true); setError(null);
    try { await macosFilter('openAccessibilitySettings'); }
    catch (cause) { setError(cause instanceof Error ? cause.message : 'Could not open Accessibility settings.'); }
    finally { setBusy(false); }
  }

  async function openLoginItemsSettings() {
    setBusy(true); setError(null);
    try { await macosFilter('openLoginItemsSettings'); }
    catch (cause) { setError(cause instanceof Error ? cause.message : 'Could not open Login Items & Extensions settings.'); }
    finally { setBusy(false); }
  }

  async function installBrowserBridge() {
    setBusy(true); setError(null); setMessage(null);
    try {
      const result = await macosFilter('installBrowserProtection');
      if (result.browserProtection) setBrowserProtection(result.browserProtection);
      setMessage(result.status === 'installed'
        ? result.browserProtection?.storeExtensionConfigured
          ? 'Browser bridge and all-profile extension config installed for Brave, Chrome, and Edge.'
          : 'Browser bridge registered. Load the unpacked Bloom extension in Brave or Chrome, or configure the Chrome Web Store ID for automatic all-profile install.'
        : 'Could not find a supported browser profile on this Mac.');
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : 'Could not register the browser bridge.');
    } finally {
      setBusy(false);
    }
  }

  async function openBrowserPolicyProfile(strict: boolean) {
    setBusy(true); setError(null); setMessage(null);
    try {
      const result = await macosFilter('openBrowserPolicyProfile', undefined, undefined, undefined, undefined, undefined, undefined, strict);
      if (result.browserProtection) setBrowserProtection(result.browserProtection);
      setMessage(strict
        ? 'Opened the Strict All-Profile Browser Protection profile. Approve it in System Settings → Device Management to enforce Bloom across every Brave, Chrome, and Edge profile (including Private windows).'
        : 'Opened the All-Profile Browser Protection profile. Approve it in System Settings → Device Management to silently install Bloom across every Brave, Chrome, and Edge profile.');
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : 'Could not open the browser protection profile.');
    } finally {
      setBusy(false);
    }
  }

  const refreshProtection = useCallback(async () => {
    const version = ++protectionCheckVersion.current;
    const [website, application] = await Promise.allSettled([macosFilter('status'), macosFilter('appStatus')]);
    if (version !== protectionCheckVersion.current) return;
    setWebsiteCheck(website.status === 'fulfilled' ? 'available' : 'unavailable');
    setAppCheck(application.status === 'fulfilled' ? 'available' : 'unavailable');
    if (website.status === 'fulfilled') setEnabled(website.value.status === 'enabled');
    if (application.status === 'fulfilled') {
      setAppEnabled(application.value.appEnabled ?? false);
      setAppConfigured(application.value.appConfigured ?? application.value.appEnabled ?? false);
      setAppService(application.value.appService ?? 'unavailable');
      setAppHideFailed(application.value.appHideFailed ?? false);
      setWebsiteUsageAvailable(application.value.websiteUsageAvailable ?? false);
      setWebsiteProviderHealthy(application.value.websiteProviderHealthy ?? false);
      setWebsitePolicyBrokerStatus(application.value.websitePolicyBrokerStatus ?? 'unknown');
      setAccessibilityTrusted(application.value.accessibilityTrusted ?? false);
    }
  }, []);

  async function runSelfCheck() {
    setBusy(true); setError(null); setMessage(null);
    try {
      const result = await macosFilter('selfCheck');
      if (result.selfCheck) {
        setSelfCheckReport(result.selfCheck);
        setBrowserProtection(result.selfCheck.browserProtection);
      }
      await refreshProtection();
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : 'Could not complete protection self-check.');
    } finally {
      setBusy(false);
    }
  }

  const refreshHostsRecovery = useCallback(async () => {
    const version = ++hostsCheckVersion.current;
    try {
      const result = await macosFilter('hostsRecoveryStatus');
      if (version !== hostsCheckVersion.current) return;
      const status = result.status;
      setHostsRecovery(status === 'clear' || status === 'review' || status === 'busy' || status === 'unsafe' ? status : 'unavailable');
    } catch {
      if (version === hostsCheckVersion.current) setHostsRecovery('unavailable');
    }
  }, []);

  const refreshHostsPolicy = useCallback(async () => {
    const version = ++hostsPolicyVersion.current;
    if (!profileId) { setHostsPolicy('signedOut'); setHostsPolicyAccount(null); return; }
    try {
      const result = await macosFilter('hostsPolicyStatus', undefined, undefined, undefined, undefined, { userId: profileId });
      if (version === hostsPolicyVersion.current) { setHostsPolicy(result.status ?? 'unavailable'); setHostsPolicyAccount(profileId); }
    } catch {
      if (version === hostsPolicyVersion.current) { setHostsPolicy('unavailable'); setHostsPolicyAccount(profileId); }
    }
  }, [profileId]);

  useEffect(() => {
    // eslint-disable-next-line react-hooks/set-state-in-effect
    void refreshHostsPolicy();
    const interval = setInterval(() => { void refreshHostsPolicy(); }, 15_000);
    return () => { hostsPolicyVersion.current += 1; clearInterval(interval); };
  }, [refreshHostsPolicy]);

  useEffect(() => {
    const token = session?.access_token;
    if (!profileId || !token || (visibleHostsPolicy !== 'enrolled' && visibleHostsPolicy !== 'enrolledEmpty')) return;
    let active = true;
    let inFlight = false;
    const sync = async () => {
      if (inFlight) return;
      inFlight = true;
      try {
        const result = await macosFilter('syncHostsManaged', undefined, undefined, undefined, undefined,
          { userId: profileId, accessToken: token });
        if (active) setHostsManagedSync({ account: profileId, status: result.status === 'updated' || result.status === 'unchanged' ? 'current' : 'pending' });
      } catch {
        if (active) setHostsManagedSync({ account: profileId, status: 'pending' });
      } finally { inFlight = false; }
    };
    void sync();
    const interval = setInterval(() => { void sync(); }, 60_000);
    return () => { active = false; clearInterval(interval); };
  }, [profileId, session?.access_token, visibleHostsPolicy]);

  useEffect(() => {
    const interval = setInterval(() => { void refreshProtection(); }, 5000);
    return () => { protectionCheckVersion.current += 1; clearInterval(interval); };
  }, [refreshProtection]);

  useEffect(() => {
    // The first update follows an asynchronous native service check.
    // eslint-disable-next-line react-hooks/set-state-in-effect
    void refreshHostsRecovery();
    const interval = setInterval(() => { void refreshHostsRecovery(); }, 15_000);
    return () => { hostsCheckVersion.current += 1; clearInterval(interval); };
  }, [refreshHostsRecovery]);

  async function chooseApp() {
    setBusy(true); setError(null);
    try {
      const result = await macosFilter('chooseApp');
      const appId = result.selectedAppId;
      if (appId) { setApps((current) => [...new Set([...current, appId])]); setMessage(`Added ${result.selectedAppName || appId}.`); }
    } catch (cause) { setError(cause instanceof Error ? cause.message : 'Could not choose an app.'); }
    finally { setBusy(false); }
  }

  async function cleanupHosts() {
    setBusy(true); setError(null); setMessage(null);
    try {
      await macosFilter('cleanupHosts');
      setMessage('Bloom-marked hosts entries were removed. Check your website protection status.');
    } catch (cause) { setError(cause instanceof Error ? cause.message : 'Could not confirm hosts cleanup.'); }
    finally { setBusy(false); void refreshHostsRecovery(); void refreshHostsPolicy(); }
  }

  async function enrollHosts() {
    const account = profileId;
    const accessToken = session?.access_token;
    if (!account || !accessToken) { setError('Sign in to enable hosts fallback for this account.'); return; }
    setBusy(true); setError(null); setMessage(null);
    try {
      if (!enabled || sites.length === 0) throw new Error('Start website protection and save at least one website first.');
      if (remaining > 0 || (usage && !usage.closed) || pending || usageRequest) {
        throw new Error('Finish active or pending screen-time access before enabling hosts fallback.');
      }
      const result = await macosFilter('enrollHosts', undefined, undefined, undefined, undefined,
        { userId: account, accessToken });
      if (result.status !== 'enrolled') throw new Error('The hosts service did not confirm enrollment.');
      setMessage('Hosts fallback is enabled for this account.');
      await refreshHostsPolicy();
      await refreshHostsRecovery();
    } catch (cause) { setError(cause instanceof Error ? cause.message : 'Could not enable hosts fallback.'); }
    finally { setBusy(false); }
  }

  async function openAppPicker() {
    setShowAppPicker(true); setAppCatalog(null); setBusy(true); setError(null);
    try {
      const result = await macosFilter('listInstalledApps');
      if (!result.installedApps) throw new Error('Could not load installed apps.');
      setAppCatalog(result.installedApps);
    } catch (cause) { setError(cause instanceof Error ? cause.message : 'Could not load installed apps.'); }
    finally { setBusy(false); }
  }

  const brokerNeedsApproval = websitePolicyBrokerStatus === 'needsApproval';
  const brokerUnavailable = websitePolicyBrokerStatus !== 'active';

  const appSummary = appCheck === 'checking'
    ? 'Checking app protection…'
    : appCheck === 'unavailable'
      ? 'App protection status unavailable'
      : appHideFailed
        ? 'App protection needs attention'
        : appEnabled
          ? 'App protection is on'
          : apps.length + managedApps.length > 0 ? 'Apps selected · protection off' : 'No apps selected';
  const websiteSummary = websiteCheck === 'checking'
    ? 'Checking website protection…'
    : websiteCheck === 'unavailable'
      ? 'Website protection status unavailable'
      : enabled
        ? websiteProviderHealthy ? 'Website protection is on' : 'Website protection needs attention'
        : sites.length + managedSites.length > 0 ? 'Websites selected · protection off' : 'Optional';
  const configuredTargetCount = new Set([...apps, ...managedApps]).size + new Set([...sites, ...managedSites]).size;
  const appActionLabel = !accessibilityTrusted
    ? 'Allow Accessibility access'
    : appService !== 'active'
      ? 'Set up app protection'
      : apps.length === 0
        ? 'Choose apps to block'
        : appEnabled ? 'Turn off app blocking' : 'Turn on app blocking';
  const handleAppAction = () => {
    if (!accessibilityTrusted) { void openAccessibilitySettings(); return; }
    if (appService !== 'active') { void run('activateApps'); return; }
    if (apps.length === 0) { setAppSettingsOverride({ section: initialSection, expanded: true }); void openAppPicker(); return; }
    void run(appEnabled ? 'stopApps' : 'startApps');
  };

  return <Screen safeAreaTop={false}>
    <View style={sharedStyles.column}>
      <Eyebrow>Focus</Eyebrow>
      <Heading>Block distractions</Heading>
      <Body>Choose apps or websites to block on this Mac.</Body>
      <Button label="Back to settings" variant="tertiary" onPress={() => router.replace('/settings')} />
    </View>

    {message && <Body>{message}</Body>}
    {error && <ErrorText>{error}</ErrorText>}
    {blockingRulesSyncError && <ErrorText>{blockingRulesSyncError}</ErrorText>}

    <Panel>
      <Eyebrow>PROTECTION ON THIS MAC</Eyebrow>
      <Label>{appCheck === 'checking' && websiteCheck === 'checking' ? 'Checking status…' : appCheck === 'unavailable' && websiteCheck === 'unavailable' ? 'Protection status unavailable' : appEnabled || enabled ? 'Protection is on' : 'Protection is off'}</Label>
      <Body>Apps: {appCheck === 'available' ? appEnabled ? 'On' : 'Off' : 'Unknown'} · Websites: {websiteCheck === 'available' ? enabled ? 'On' : 'Off' : 'Unknown'}</Body>
      {configuredTargetCount > 0 && <Body>{configuredTargetCount} {configuredTargetCount === 1 ? 'app or website' : 'apps and websites'} selected.</Body>}

      <View style={focusStyles.checklist}>
        <MacChecklistRow
          title="Background monitor"
          detail={appService === 'active' ? 'Running & watching frontmost apps' : appService === 'needsApproval' ? 'Waiting for Login Items approval' : 'Background agent not registered yet'}
          tone={appService === 'active' ? 'ok' : 'warn'}
          badge={appService === 'active' ? 'Active' : appService === 'needsApproval' ? 'Approve' : 'Setup'}
          actionLabel={appService === 'needsApproval' ? 'Login Items' : appService !== 'active' ? 'Set up' : undefined}
          onAction={appService === 'needsApproval' ? () => void openLoginItemsSettings() : appService !== 'active' ? () => void run('activateApps') : undefined}
          disabled={busy}
        />
        <MacChecklistRow
          title="Website policy service"
          detail={websitePolicyBrokerStatus === 'active' ? 'Root policy broker connected' : websitePolicyBrokerStatus === 'needsApproval' ? 'Waiting for Login Items approval' : 'Policy broker not connected yet'}
          tone={websitePolicyBrokerStatus === 'active' ? 'ok' : 'warn'}
          badge={websitePolicyBrokerStatus === 'active' ? 'Active' : websitePolicyBrokerStatus === 'needsApproval' ? 'Approve' : 'Setup'}
          actionLabel={websitePolicyBrokerStatus === 'needsApproval' ? 'Login Items' : websitePolicyBrokerStatus !== 'active' ? 'Set up' : undefined}
          onAction={websitePolicyBrokerStatus === 'needsApproval' ? () => void openLoginItemsSettings() : websitePolicyBrokerStatus !== 'active' ? () => void run('activate') : undefined}
          disabled={busy}
        />
        <MacChecklistRow
          title="Network content filter"
          detail={enabled ? (websiteProviderHealthy ? 'Blocking websites across all browsers & profiles' : 'Filter enabled · waiting for provider heartbeat') : activationStatus === 'active' ? 'Ready to start when websites are saved' : 'System extension setup needed'}
          tone={enabled ? (websiteProviderHealthy ? 'ok' : 'warn') : activationStatus === 'active' ? 'neutral' : 'warn'}
          badge={enabled ? (websiteProviderHealthy ? 'Active' : 'Attention') : activationStatus === 'active' ? 'Ready' : 'Setup'}
          actionLabel={!enabled && activationStatus !== 'active' ? 'Set up' : undefined}
          onAction={!enabled && activationStatus !== 'active' ? () => void run('activate') : undefined}
          disabled={busy}
        />
        <MacChecklistRow
          title="App & website shield"
          detail={accessibilityTrusted ? 'Allowed to show native Bloom Shield overlays' : 'Accessibility permission needed for App & Website Shield'}
          tone={accessibilityTrusted ? 'ok' : 'warn'}
          badge={accessibilityTrusted ? 'Allowed' : 'Permission'}
          actionLabel={!accessibilityTrusted ? 'Allow' : undefined}
          onAction={!accessibilityTrusted ? () => void openAccessibilitySettings() : undefined}
          disabled={busy}
        />
        {(() => {
          const installedBrowsers = browserProtection?.browsers.filter((item) => item.installed) ?? [];
          const anyExtensionActive = installedBrowsers.some((item) => item.extensionHeartbeatFresh || item.managedProfileEnforced);
          const anyBridgeReady = installedBrowsers.some((item) => item.nativeBridgeInstalled);
          const tone: ChecklistTone = anyExtensionActive ? 'ok' : anyBridgeReady ? 'neutral' : 'warn';
          const badge = anyExtensionActive ? 'Active' : anyBridgeReady ? 'Bridge ready' : 'Optional';
          const detail = browserProtection
            ? `${formatBrowserProtectionSummary(browserProtection)} · Native shield covers other profiles & Safari`
            : 'Checking browser bridge status…';
          return (
            <MacChecklistRow
              title="Browser block pages"
              detail={detail}
              tone={tone}
              badge={badge}
              actionLabel={browserProtection && !anyBridgeReady && installedBrowsers.length > 0 ? 'Set up' : undefined}
              onAction={browserProtection && !anyBridgeReady && installedBrowsers.length > 0 ? () => void installBrowserBridge() : undefined}
              disabled={busy}
            />
          );
        })()}
      </View>

      {selfCheckReport && (
        <Body>
          Self-check ({selfCheckReport.filterVersion || 'local'}): Monitor {selfCheckReport.monitorLive ? 'OK' : 'Off'} · Broker {selfCheckReport.policyBrokerReady ? 'OK' : 'Off'} · Filter {selfCheckReport.filterProviderHealthy ? 'OK' : 'Idle'} · Accessibility {selfCheckReport.accessibilityTrusted ? 'OK' : 'Needed'}.
        </Body>
      )}
      {(appHideFailed || (enabled && (!websiteUsageAvailable || !websiteProviderHealthy))) && <Body>One protection service needs attention. Open its section below for the next step.</Body>}
      {blockingRulesSyncedAt && !blockingRulesSyncError && <Body>Family rules last synced {new Date(blockingRulesSyncedAt).toLocaleTimeString(getAppLocale())}.</Body>}
      <Button label={appActionLabel} onPress={handleAppAction} disabled={busy || appCheck !== 'available'} busy={busy} />
      <Button label="Test protection" variant="secondary" onPress={() => void runSelfCheck()} disabled={busy} busy={busy} />
      <Button label="Refresh status" variant="tertiary" onPress={() => void refreshProtection()} />
    </Panel>

    <MacFocusDisclosure title="Apps to block" summary={`${apps.length + managedApps.length} selected · ${appSummary}`} expanded={showAppSettings} onPress={() => setAppSettingsOverride({ section: initialSection, expanded: !showAppSettings })}>
      {showAppSettings && <View style={focusStyles.disclosureBody}>
        <Body>Choose the apps Bloom should block. When a blocked app opens without earned screen time, Bloom overlays a block screen with an option to unlock.</Body>
        {appHideFailed && <Body>A selected app is still running. Bloom may be warning it or trying to close it; protection needs attention until it has quit.</Body>}
        {!accessibilityTrusted && <Body>Use the action above to open Accessibility settings. Bloom needs this permission to block apps.</Body>}
        {appService !== 'active' && <Body>Use the action above to set up Bloom’s background monitor before relying on app blocking.</Body>}
        <Button label={showAppPicker ? 'Refresh installed apps' : 'Choose installed apps'} variant="secondary" onPress={() => void openAppPicker()} busy={busy} />
        {showAppPicker && <View style={focusStyles.disclosureBody}>
          <Field label="Search installed apps" value={appSearch} onChangeText={setAppSearch} autoCapitalize="none" autoCorrect={false} placeholder="Search app names" />
          {!appCatalog && busy && <Body>Loading installed apps…</Body>}
          {!appCatalog && !busy && <Body>Could not load the list. Refresh it or use “App not listed?” below.</Body>}
          {appCatalog && (() => {
            const query = appSearch.trim().toLocaleLowerCase();
            const matches = appCatalog.apps.filter((candidate) => `${candidate.name} ${candidate.id}`.toLocaleLowerCase().includes(query));
            return <>
              {matches.length === 0 ? <Body>No matching apps found. Try another search.</Body> : <ScrollView style={focusStyles.pickerList} nestedScrollEnabled keyboardShouldPersistTaps="handled">
                {matches.slice(0, 50).map((candidate) => {
                  const selected = apps.some((id) => id.toLowerCase() === candidate.id);
                  return <View key={candidate.id} style={focusStyles.pickerRow}>
                    <View style={sharedStyles.grow}><Label>{candidate.name}</Label></View>
                    <Button label={selected ? 'Added' : 'Add'} accessibilityLabel={`${selected ? 'Added' : 'Add'} ${candidate.name}`} variant="secondary" disabled={selected || busy} onPress={() => setApps((current) => [...current, candidate.id])} />
                  </View>;
                })}
              </ScrollView>}
              {matches.length > 50 && <Body>Showing the first 50 matches. Refine your search to see more.</Body>}
              {appCatalog.truncated && <Body>Some apps were not listed.</Body>}
            </>;
          })()}
          <Button label="Close app list" variant="tertiary" onPress={() => setShowAppPicker(false)} />
        </View>}

        {apps.map((app) => {
          const parentRule = managedApps.includes(app);
          const appName = appCatalog?.apps.find((candidate) => candidate.id === app)?.name ?? app;
          return <View key={app} style={sharedStyles.row}>
            <View style={sharedStyles.grow}><Body>{appName}{parentRule ? ' · Family' : ''}</Body></View>
            <Button label="Remove" accessibilityLabel={`Remove ${appName}`} variant="secondary" disabled={busy || parentRule} onPress={() => setApps((current) => current.filter((item) => item !== app))} />
          </View>;
        })}

        <MacFocusDisclosure title="App not listed?" summary="Add it from a folder or enter its app identifier" expanded={showManualAppEntry} onPress={() => setShowManualAppEntry((open) => !open)}>
          {showManualAppEntry && <View style={focusStyles.disclosureBody}>
            <Button label="Choose an app from a folder" variant="secondary" onPress={() => void chooseApp()} busy={busy} />
            <Field label="App identifier" value={appInput} onChangeText={setAppInput} autoCapitalize="none" autoCorrect={false} placeholder="com.example.app" />
            <Button label="Add app" variant="secondary" disabled={!appInput.trim() || busy} onPress={() => { setApps((current) => [...new Set([...current, appInput.trim()])]); setAppInput(''); }} />
          </View>}
        </MacFocusDisclosure>

        <Button label="Save and start app blocking" onPress={() => void run('startApps')} disabled={apps.length === 0 || busy} busy={busy} />
        {appConfigured && managedApps.length === 0 && <Button label="Turn off app blocking" variant="secondary" onPress={() => void run('stopApps')} busy={busy} />}
      </View>}
    </MacFocusDisclosure>

    <MacFocusDisclosure title="Websites to block" summary={`${sites.length + managedSites.length} saved · ${websiteSummary}`} expanded={showWebsiteSettings} onPress={() => setWebsiteSettingsOverride({ section: initialSection, expanded: !showWebsiteSettings })}>
      {showWebsiteSettings && <View style={focusStyles.disclosureBody}>
        <Body>Add domains and start website protection. Website addresses are checked on this Mac.</Body>
        <Label>{websiteCheck === 'checking' ? 'Checking website filter…' : websiteCheck === 'unavailable' ? 'Website filter status unavailable' : enabled ? websiteUsageAvailable && websiteProviderHealthy ? 'Filter active' : 'Filter active · needs attention' : activationStatus === 'active' ? 'Ready to start' : 'Setup needed'}</Label>
        {activationStatus === 'needsApproval' && <Body>Approve Bloom in System Settings → Privacy & Security, then return here.</Body>}
        {(brokerNeedsApproval || activationStatus === 'needsBrokerApproval') && <>
          <Body>Approve Bloom’s website service in System Settings → General → Login Items &amp; Extensions, then try again.</Body>
          <Button label="Open Login Items & Extensions" variant="secondary" onPress={() => void openLoginItemsSettings()} busy={busy} />
        </>}
        {!enabled && websiteCheck === 'available' && !brokerNeedsApproval && activationStatus !== 'needsBrokerApproval' && websitePolicyBrokerStatus === 'unavailable' && appService === 'active' && <>
          <Body>Bloom’s website policy service is not responding yet. Check System Settings → General → Login Items &amp; Extensions and allow Bloom.</Body>
          <Button label="Open Login Items & Extensions" variant="secondary" onPress={() => void openLoginItemsSettings()} busy={busy} />
        </>}
        {activationStatus === 'needsRestart' && <Body>Restart your Mac, then return here to start protection.</Body>}
        {!enabled && activationStatus !== 'active' && <Button label="Set up website protection" variant="secondary" onPress={() => void run('activate')} busy={busy} />}
        <Field label="Website domain" value={input} onChangeText={setInput} autoCapitalize="none" autoCorrect={false} placeholder="example.com" />
        <Button label="Add website" variant="secondary" disabled={!input.trim() || busy} onPress={() => {
          const trimmed = input.trim();
          const nextSites = [...new Set([...sites, trimmed])];
          setSites(nextSites);
          setCompanionSuggestions(suggestCompanionDomains(trimmed, nextSites));
          setInput('');
        }} />
        {companionSuggestions.length > 0 && (
          <View style={sharedStyles.row}>
            <View style={sharedStyles.grow}><Body>Also block related domains: {companionSuggestions.join(', ')}?</Body></View>
            <Button label="Add companions" variant="secondary" disabled={busy} onPress={() => {
              setSites((current) => [...new Set([...current, ...companionSuggestions])]);
              setCompanionSuggestions([]);
            }} />
          </View>
        )}
        {sites.map((site) => {
          const parentRule = managedSites.includes(site);
          return <View key={site} style={sharedStyles.row}>
            <View style={sharedStyles.grow}><Body>{site}{parentRule ? ' · Family' : ''}</Body></View>
            <Button label="Remove" accessibilityLabel={`Remove ${site}`} variant="secondary" disabled={busy || parentRule} onPress={() => setSites((current) => current.filter((item) => item !== site))} />
          </View>;
        })}
        <Button label="Save and start website blocking" onPress={() => void run('start')} disabled={sites.length === 0 || busy} busy={busy} />
        {enabled && managedSites.length === 0 && <Button label="Turn off website blocking" variant="secondary" onPress={() => void run('stop')} busy={busy} />}
        <Label>Browser block page &amp; all-profile Brave/Chrome setup</Label>
        <Body>Network protection already blocks every Brave profile and Private window. Enable the browser extension to show the Bloom block page and redirect already-open tabs.</Body>
        <Button label="Set up browser bridge & extension" variant="secondary" onPress={() => void installBrowserBridge()} busy={busy} />
        {browserProtection?.storeExtensionConfigured ? (
          <>
            <Body>Want zero-prompt, unremovable protection across every Brave, Chrome, and Edge profile (including new profiles)?</Body>
            <Button label="Install All-Profile Browser Profile" variant="secondary" onPress={() => void openBrowserPolicyProfile(false)} busy={busy} />
            <Button label="Install Strict All-Profile (Private Windows)" variant="tertiary" onPress={() => void openBrowserPolicyProfile(true)} busy={busy} />
          </>
        ) : (
          <Body>To deploy automatically across all Brave profiles without Developer Mode, publish the packaged zip in dist/bloom-browser-extension-cws.zip to the Chrome Web Store and build with BLOOM_CHROME_EXTENSION_ID.</Body>
        )}

        <MacFocusDisclosure title="Protection details" summary="Browser coverage, permissions, and service status" expanded={showWebsiteDetails} onPress={() => setShowWebsiteDetails((open) => !open)}>
          {showWebsiteDetails && <View style={focusStyles.disclosureBody}>
            <Body>The filter checks website names macOS exposes. If Bloom cannot read a recognized browser’s address, it may block that whole browser. Other browser and app-created network traffic may not be covered.</Body>
            {enabled && !websiteUsageAvailable && <Body>Website protection is degraded until Bloom’s background monitor and local policy service are ready.</Body>}
            {enabled && !websiteProviderHealthy && <Body>Bloom has not received a recent filter-provider heartbeat. Refresh status before relying on website blocking.</Body>}
            {enabled && brokerUnavailable && <>
              <Button label={brokerNeedsApproval ? 'Check website service approval' : 'Set up website policy service'} variant="secondary" onPress={() => void run('activate')} busy={busy} />
              <Button label="Open Login Items & Extensions" variant="secondary" onPress={() => void openLoginItemsSettings()} busy={busy} />
            </>}
            {enabled && !websiteUsageAvailable && appService !== 'active' && <Button label="Enable background monitor" variant="secondary" onPress={() => void run('activateApps')} busy={busy} />}
            {supportedBrowsers.length > 0 && <Body>Recognized browsers: {supportedBrowsers.join(', ')}.</Body>}
            {browserName && <Body>Last checked: {browserName} · {browserAddressStatus}.</Body>}
            {browserAutomationStatus === 'permissionRequired' && <Body>Allow Bloom under System Settings → Privacy &amp; Security → Automation. Accessibility is used as a fallback when available.</Body>}
            {browserAutomationStatus === 'unavailable' && <Body>Bloom could not read this browser through Automation. It may block the browser while its address is unreadable.</Body>}
            {browserAddressStatus === 'unsupported' && <Body>This browser is not recognized for address checks.</Body>}
            {enabled && browserAddressStatus === 'unreadable' && <Body>Bloom cannot read the active address and website coverage is degraded.</Body>}
            {browserHideFailed && <Body>Bloom could not confirm that the affected browser was hidden.</Body>}
            {!accessibilityTrusted && <Button label="Open Accessibility settings" variant="secondary" onPress={() => void openAccessibilitySettings()} busy={busy} />}
            <Button label="Refresh status" variant="tertiary" onPress={() => void refreshProtection()} />
          </View>}
        </MacFocusDisclosure>

        <MacFocusDisclosure title="Website fallback and recovery" summary="Advanced system settings" expanded={showHostsAdvanced} onPress={() => setShowHostsAdvanced((open) => !open)}>
          {showHostsAdvanced && <View style={focusStyles.disclosureBody}>
            <Body>Hosts fallback and recovery are advanced options. Administrator approval may be required, and changes can affect restrictions for all accounts on this Mac.</Body>
            {visibleHostsPolicy === 'notConfigured' && <Body>Hosts fallback is not configured.</Body>}
            {(visibleHostsPolicy === 'enrolled' || visibleHostsPolicy === 'enrolledEmpty') && <Body>Hosts fallback is configured. This does not confirm website coverage.</Body>}
            {visibleHostsPolicy === 'otherAccount' && <Body>Hosts fallback is configured for another account.</Body>}
            {visibleHostsPolicy === 'needsEnrollment' && <Body>Hosts fallback needs setup for this account.</Body>}
            {visibleHostsPolicy === 'cleanupPending' && <Body>Hosts cleanup is pending.</Body>}
            {hostsManagedSync?.account === profileId && hostsManagedSync.status === 'pending' && <Body>Family rules could not be refreshed. Bloom will retry while you are signed in.</Body>}
            {visibleHostsPolicy === 'unavailable' && <Body>Bloom could not check hosts fallback setup.</Body>}
            {hostsRecovery === 'checking' && <Body>Checking for interrupted hosts updates…</Body>}
            {hostsRecovery === 'review' && <ErrorText>An interrupted or conflicting hosts update needs administrator review. Do not share the files in /private/etc/.bloom-hosts.</ErrorText>}
            {hostsRecovery === 'busy' && <Body>A hosts update is in progress. Check again shortly.</Body>}
            {hostsRecovery === 'unsafe' && <ErrorText>Bloom cannot safely inspect its hosts recovery directory. Ask an administrator to review it.</ErrorText>}
            {hostsRecovery === 'unavailable' && <Body>Bloom cannot check hosts recovery. Enable the background service and try again.</Body>}
            {hostsRecovery === 'clear' && <Body>No interrupted Bloom hosts update needs review.</Body>}
            {(visibleHostsPolicy === 'notConfigured' || visibleHostsPolicy === 'needsEnrollment' || visibleHostsPolicy === 'enrolled' || visibleHostsPolicy === 'enrolledEmpty') && <>
              <Body>{visibleHostsPolicy === 'enrolled' || visibleHostsPolicy === 'enrolledEmpty' ? 'Update fallback rules from saved and family-managed websites.' : 'Add saved and family-managed websites to Bloom’s hosts rules.'}</Body>
              <Button label={visibleHostsPolicy === 'enrolled' || visibleHostsPolicy === 'enrolledEmpty' ? 'Update fallback rules' : 'Enable hosts fallback'} variant="secondary" onPress={() => void enrollHosts()} disabled={!profileId || !session?.access_token || !enabled || sites.length === 0 || remaining > 0 || (!!usage && !usage.closed) || !!pending || !!usageRequest} busy={busy} />
            </>}
            <Button label="Check hosts recovery" variant="secondary" onPress={() => void refreshHostsRecovery()} />
            <Button label="Remove Bloom hosts entries" variant="secondary" onPress={() => void cleanupHosts()} busy={busy} />
          </View>}
        </MacFocusDisclosure>
      </View>}
    </MacFocusDisclosure>

    <MacFocusDisclosure title="Earned screen time" summary={creditSettings ? `${Math.round(creditBalance * 100) / 100} minutes in your shared balance` : 'Optional'} expanded={showEarnedAccess} onPress={() => setEarnedOverride(!showEarnedAccess)}>
      {showEarnedAccess && <View style={focusStyles.disclosureBody}>
        {creditsEnabled && creditSettings ? <>
          {creditRecoveryStatus === 'checking' && <Body>Checking the existing access session. Apps stay blocked until Bloom confirms it is yours and still active.</Body>}
          {creditRecoveryStatus === 'blocked' && <Body>Bloom could not validate the previous countdown. Access remains blocked. Reconnect and reopen Bloom to retry.</Body>}
          {creditRecoveryStatus === 'expired' && <Body>The previous countdown expired. Request a new session to use any remaining balance.</Body>}
          {creditRecoveryStatus === 'rejected' && <Body>This request could not be approved. Check the balance and account before retrying.</Body>}
          {creditSettings.credit_mode === 'easy' ? <>
            <Label>{usage ? `${Math.ceil(usage.remainingMillis / 60000)} minutes left in this screen-time session` : `${Math.round(creditBalance * 100) / 100} minutes available`}</Label>
            <Body>Your reserved minutes keep counting while the selected app or website is idle. If you finish early, unused time returns to your balance.</Body>
            {usage && usage.userId !== profileId ? <Body>Another account has a session on this Mac. Sign in to finish it.</Body> : usage ? <>
              {!usage.closed && usage.verified !== true && <><Body>Bloom needs to verify this session before it can unlock apps.</Body><Button label="Verify session" onPress={() => void startActualUsage()} busy={busy} /></>}
              <Body>{usage.closed ? 'The access window ended. Sync it to settle the session.' : usage.tracking ? 'A selected target is detected.' : 'No selected target is detected. The timer continues while idle.'}</Body>
              <Button label={usage.closed ? 'Sync screen-time session' : 'Finish screen-time session'} onPress={() => void finishActualUsage()} busy={busy} />
            </> : <>
              {usageRequest ? <Body>Retrying your previous request for screen time.</Body> : <Field label="Minutes to unlock" value={minutes} onChangeText={setMinutes} keyboardType="decimal-pad" />}
              <Button label={usageRequest ? 'Retry request' : 'Use screen time'} onPress={() => void startActualUsage()} disabled={!appEnabled && !enabled || !usageAvailable || (enabled && !websiteUsageAvailable)} busy={busy} />
              {usageRequest && <Button label="Cancel request" variant="secondary" onPress={() => void cancelPendingUsage()} busy={busy} />}
            </>}
          </> : <>
            <Label>{remaining > 0 ? `${Math.ceil(remaining / 60000)} minutes left` : `${Math.round(creditBalance * 100) / 100} minutes available`}</Label>
            {pending ? <Body>Retrying the previous request for {pending.minutes} minutes.</Body> : <Field label="Minutes to use" value={minutes} onChangeText={setMinutes} keyboardType="decimal-pad" />}
            <Button label={pending ? 'Retry screen-time request' : 'Use screen time'} onPress={() => void startScreenTime()} disabled={!enabled && !appEnabled || remaining > 0} busy={busy} />
            {pending && <Button label="Clear request" variant="secondary" onPress={() => void AsyncStorage.removeItem(pendingKey).then(() => setPending(null)).catch(() => setError('Could not clear the request.'))} disabled={busy} />}
          </>}
        </> : <>
          <Label>{loading ? 'Loading balance…' : 'Screen time is unavailable'}</Label>
          <Body>{accountError ?? 'Enable credits in account settings to use earned minutes.'}</Body>
          {!loading && <Button label="Try again" variant="secondary" onPress={() => void refresh()} />}
        </>}
      </View>}
    </MacFocusDisclosure>
  </Screen>;
}

type ChecklistTone = 'ok' | 'warn' | 'neutral';

function MacChecklistRow({ title, detail, tone, badge, actionLabel, onAction, disabled }: {
  title: string;
  detail: string;
  tone: ChecklistTone;
  badge: string;
  actionLabel?: string;
  onAction?: () => void;
  disabled?: boolean;
}) {
  const { theme } = useBloomTheme();
  const badgeColor = tone === 'ok' ? theme.colors.successText : tone === 'warn' ? theme.colors.warningText : theme.colors.inkMuted;
  const badgeBorder = tone === 'ok' ? theme.colors.success : tone === 'warn' ? theme.colors.warning : theme.colors.borderStrong;
  return (
    <View style={[focusStyles.checklistRow, { borderColor: theme.colors.border, backgroundColor: theme.colors.surfaceSoft }]}>
      <View style={sharedStyles.grow}>
        <View style={focusStyles.checklistTitleRow}>
          <Label>{title}</Label>
          <View style={[focusStyles.statusBadge, { borderColor: badgeBorder, backgroundColor: theme.colors.surface }]}>
            <Body>{badge}</Body>
          </View>
        </View>
        <Body>{detail}</Body>
      </View>
      {actionLabel && onAction && (
        <Button label={actionLabel} variant="secondary" onPress={onAction} disabled={disabled} />
      )}
      {!actionLabel && (
        <MaterialIcons name={tone === 'ok' ? 'check-circle' : 'info-outline'} size={20} color={badgeColor} />
      )}
    </View>
  );
}

function formatBrowserProtectionSummary(browserProtection: BrowserProtectionSnapshot): string {
  const installedBrowsers = browserProtection.browsers.filter((item) => item.installed);
  if (installedBrowsers.length === 0) return 'Browsers: No Chromium browser profile detected yet.';
  const summary = installedBrowsers.map((item) => {
    if (item.extensionHeartbeatFresh && item.managedProfileEnforced) return `${item.name} (All-profile locked & active)`;
    if (item.extensionHeartbeatFresh) return `${item.name} (Extension active)`;
    if (item.managedProfileEnforced) return `${item.name} (Managed policy active)`;
    if (item.externalExtensionConfigured) return `${item.name} (Auto-install pending)`;
    if (item.nativeBridgeInstalled) return `${item.name} (Bridge ready)`;
    return `${item.name} (Needs setup)`;
  }).join(' · ');
  const safariText = browserProtection.safariBundled
    ? ` · Safari (${browserProtection.safariEnabled ? 'Active' : 'Enable in Safari Settings'})`
    : '';
  return `Browser block pages · ${summary}${safariText}`;
}

function MacFocusDisclosure({ title, summary, expanded, onPress, children }: {
  title: string;
  summary: string;
  expanded: boolean;
  onPress: () => void;
  children: ReactNode;
}) {
  const { theme } = useBloomTheme();
  return <View style={[focusStyles.disclosure, { borderColor: theme.colors.border, backgroundColor: theme.colors.surface }]}>
    <Pressable
      accessibilityRole="button"
      accessibilityLabel={title}
      accessibilityState={{ expanded }}
      onPress={onPress}
      style={focusStyles.disclosureHeader}>
      <View style={sharedStyles.grow}>
        <Label>{title}</Label>
        <Body>{summary}</Body>
      </View>
      <MaterialIcons name={expanded ? 'expand-less' : 'expand-more'} size={24} color={theme.colors.inkMuted} />
    </Pressable>
    {expanded && <View style={focusStyles.disclosureBody}>{children}</View>}
  </View>;
}

const focusStyles = StyleSheet.create({
  checklist: { gap: 8 },
  checklistRow: { flexDirection: 'row', alignItems: 'center', gap: 12, borderWidth: 1, borderRadius: 12, paddingHorizontal: 12, paddingVertical: 10 },
  checklistTitleRow: { flexDirection: 'row', alignItems: 'center', gap: 8, flexWrap: 'wrap' },
  statusBadge: { borderWidth: 1, borderRadius: 999, paddingHorizontal: 8, paddingVertical: 2 },
  disclosure: { borderWidth: 1, borderRadius: 16, paddingHorizontal: 16, paddingVertical: 12 },
  disclosureHeader: { minHeight: 44, flexDirection: 'row', alignItems: 'center', gap: 12 },
  disclosureBody: { gap: 12, paddingTop: 12 },
  pickerList: { maxHeight: 320 },
  pickerRow: { flexDirection: 'row', alignItems: 'center', gap: 12, paddingVertical: 8 },
});
