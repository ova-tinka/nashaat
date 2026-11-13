import AsyncStorage from '@react-native-async-storage/async-storage';
import { randomUUID } from 'expo-crypto';
import { useCallback, useEffect, useRef, useState } from 'react';
import { router, useFocusEffect } from 'expo-router';
import { ScrollView, StyleSheet, View, useWindowDimensions } from 'react-native';
import { Body, Button, ErrorText, Eyebrow, Field, Heading, Label, Panel, Screen, sharedStyles } from './bloom-ui';
import { macCreditMarker, macUsageKey, macosFilter, parseMacCreditMarker, type MacCreditMarker } from '../lib/macos-blocking';
import { useAuth } from '../lib/auth';
import { useBloom } from '../lib/bloom-context';
import { findUsageSession, finishUsageSession } from '../lib/bloom';
import type { UsageAccess } from '../../modules/bloom-blocking/src/BloomBlocking.types';
import { matchesMacUsageReservation, parseMacUsageRequest, recoverOrCreateMacUsageRequest } from '../lib/mac-credit-marker';

export function MacosFocus() {
  const { session, profileId } = useAuth();
  const userId = profileId;
  const { creditsEnabled, creditSettings, creditBalance, refresh, blockingRules, blockingRulesSyncError, blockingRulesSyncedAt, blockingRulesSyncStatus, loading, error: accountError } = useBloom();
  const { width } = useWindowDimensions();
  const wide = width >= 1100;
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
      const [website, application, usageResult] = await Promise.allSettled([macosFilter('status'), macosFilter('appStatus'), macosFilter('getUsageAccess')]);
      if (version !== loadVersion.current) return;
      setWebsiteCheck(website.status === 'fulfilled' ? 'available' : 'unavailable');
      setAppCheck(application.status === 'fulfilled' ? 'available' : 'unavailable');
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
        throw new Error('The server did not accept this screen-time request. Your saved request can be retried after the balance or session issue is resolved.');
      }
      if (result.status !== 'allowed') throw new Error('The server did not confirm this screen-time session.');
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
    if (!userId) { setError('Sign in to finish this reservation.'); return; }
    setBusy(true); setError(null);
    try {
      const request = parseMacUsageRequest(await AsyncStorage.getItem(usageKey));
      if (!request) throw new Error('The device key for this reservation is unavailable.');
      const local = (await macosFilter('getUsageAccess')).usage;
      const existing = await findUsageSession(userId, request.requestId);
      if (!matchesMacUsageReservation(userId, local, existing) || !existing) throw new Error('The saved reservation does not match this account and session.');
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
    } catch (cause) { setError(cause instanceof Error ? cause.message : 'Could not clear the reservation. Connect and try again.'); }
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

  return <Screen>
    <View style={sharedStyles.column}><Eyebrow>Focus</Eyebrow><Heading>Make space to focus.</Heading><Body>Set up protection on this Mac and use the screen time you earn.</Body></View>
    {message && <Body>{message}</Body>}{error && <ErrorText>{error}</ErrorText>}
    {blockingRulesSyncError && <ErrorText>{blockingRulesSyncError}</ErrorText>}
    <View style={[focusStyles.columns, wide && focusStyles.columnsWide]}>
      <View style={[focusStyles.primaryColumn, wide && focusStyles.flexColumn]}>
    {creditsEnabled && creditSettings && <Panel><Eyebrow>Earned screen time</Eyebrow>
      {creditRecoveryStatus === 'checking' && <Body>Checking the original server session. Protection stays blocked until the same owner and expiry are confirmed.</Body>}
      {creditRecoveryStatus === 'blocked' && <Body>Bloom could not validate the previous countdown. Access remains blocked. Reconnect to the internet and reopen Bloom to retry the same session.</Body>}
      {creditRecoveryStatus === 'expired' && <Body>The previous server countdown has expired. Request a new session to use any remaining balance.</Body>}
      {creditRecoveryStatus === 'rejected' && <Body>The server rejected the saved request. Any existing protection remains in place. Retry it only after checking the balance and account.</Body>}
      {!enabled && !appEnabled && <Body>Start website or app protection before using earned minutes.</Body>}
      {creditBalance <= 0 && !pending && !usageRequest && !usage && remaining <= 0 && <Body>Your balance is empty. Complete a workout to earn minutes.</Body>}
      {creditSettings.credit_mode === 'easy' ? <>
        <Label>{usage ? `${Math.ceil(usage.remainingMillis / 60000)} minutes left in this reservation` : `${Math.round(creditBalance * 100) / 100} minutes in your shared balance`}</Label>
        <Body>Easy is a server-timed access window. Time runs continuously from reservation, including while the selected app or website is idle. Finish early to return the unused portion calculated by the server. Website addresses stay on this Mac.</Body>
        {enabled && !websiteUsageAvailable && <Body>The background monitor or website policy service is not ready, so browser protection is degraded.</Body>}
        {enabled && !accessibilityTrusted && <Body>Accessibility is off. Automation may still read supported browsers. Browser protection may be degraded; Easy time continues to run.</Body>}
        {usage && usage.userId !== profileId ? <Body>Another account has a session on this Mac. Sign in to that account to finish it.</Body> : usage ? <>
          {!usage.closed && usage.verified !== true && <><Body>This session needs server verification before it can grant access.</Body><Button label="Verify existing session" onPress={() => void startActualUsage()} busy={busy} /></>}
          <Body>{usage.closed ? 'This access window has ended. Sync it to settle the server-timed amount.' : usage.tracking ? 'A selected target is currently detected. The access timer runs either way.' : 'No selected target is currently detected. The access timer continues while idle.'}</Body>
          {!usage.closed && usage.verified === true && (visibleHostsPolicy === 'enrolled' || visibleHostsPolicy === 'enrolledEmpty')
            && <Button label="Retry website access" secondary onPress={() => void startActualUsage()} busy={busy} />}
          <Button label={usage.closed ? 'Sync screen-time session' : 'Finish screen-time session'} onPress={() => void finishActualUsage()} busy={busy} />
        </> : <>
          {usageRequest ? <Body>Retrying a previous screen-time reservation.</Body> : <Field label="Minutes to reserve" value={minutes} onChangeText={setMinutes} keyboardType="decimal-pad" />}
          <Button label={usageRequest ? 'Retry reservation' : 'Use screen time'} onPress={() => void startActualUsage()} disabled={(!appEnabled && !enabled) || !usageAvailable || (enabled && !websiteUsageAvailable)} busy={busy} />
          {usageRequest && <Button label="Cancel pending reservation" secondary onPress={() => void cancelPendingUsage()} busy={busy} />}
        </>}
      </> : <>
        <Label>{remaining > 0 ? `${Math.ceil(remaining / 60000)} minutes left` : `${Math.round(creditBalance * 100) / 100} minutes in your shared balance`}</Label>
        <Body>The countdown runs until its scheduled end, including after sign-out, restart, or setup failure. The daily limit may shorten the request.</Body>
        {pending ? <Body>Retrying your previous request for {pending.minutes} minutes.</Body> : <Field label="Minutes to use" value={minutes} onChangeText={setMinutes} keyboardType="decimal-pad" />}
        <Button label={pending ? 'Retry screen-time request' : 'Use screen time'} onPress={() => void startScreenTime()} disabled={(!enabled && !appEnabled) || remaining > 0} busy={busy} />
        {pending && <><Body>Clearing this request does not cancel a countdown that already started.</Body><Button label="Clear request" secondary onPress={() => void AsyncStorage.removeItem(pendingKey).then(() => setPending(null)).catch(() => setError('Could not clear the request.'))} disabled={busy} /></>}
      </>}
    </Panel>}
    {!loading && !creditSettings && <Panel><Eyebrow>Earned screen time</Eyebrow><Label>Balance unavailable</Label><Body>{accountError ?? 'Your screen-time settings could not be loaded.'}</Body><Button label="Try again" secondary onPress={() => void refresh()} /></Panel>}
    {!loading && creditSettings && !creditsEnabled && <Panel><Eyebrow>Earned screen time</Eyebrow><Label>Screen time is unavailable</Label><Body>Enable credits in your account settings to use earned minutes.</Body></Panel>}
        {loading && <Panel><Eyebrow>Earned screen time</Eyebrow><Body>Loading your balance…</Body></Panel>}
      </View>
      <View style={[focusStyles.secondaryColumn, wide && focusStyles.flexColumn]}>
        <Panel><Eyebrow>Movement</Eyebrow><Label>Earn time by moving.</Label><Body>Choose a workout to add to your shared screen-time balance.</Body><Button label="View workouts" secondary onPress={() => router.push('/workouts')} /></Panel>
        <Panel><Eyebrow>Protection on this Mac</Eyebrow>
          <Label>{appCheck === 'checking' ? 'Checking app protection…' : appCheck === 'unavailable' ? 'App protection status unavailable' : appEnabled && !appHideFailed ? 'App protection enabled' : appHideFailed ? 'App protection needs attention' : 'App protection needs setup'}</Label>
          <Body>{websiteCheck === 'checking' ? 'Checking website protection…' : websiteCheck === 'unavailable' || appCheck === 'unavailable' ? 'Website protection status unavailable.' : enabled ? websiteProviderHealthy ? 'Website filter responding · browser coverage is not yet verified.' : 'Website filter configured, but its provider has not reported healthy.' : 'Website filter needs setup.'}</Body>
          <Body>Website filtering can affect other accounts on this Mac. An administrator can change or remove Bloom’s permissions.</Body>
          <Body>Status is checked while Focus is open and when you refresh it here.</Body>
          <Button label="Refresh protection status" secondary onPress={() => void refreshProtection()} />
        </Panel>
      </View>
    </View>
    {(managedApps.length > 0 || managedSites.length > 0) && <Panel><Eyebrow>Parent-set rules</Eyebrow>
      {managedApps.map((app) => <Body key={`app:${app}`}>App · {app}</Body>)}
      {managedSites.map((site) => <Body key={`site:${site}`}>Website · {site}</Body>)}
      <Body>These rules sync from the child account and cannot be removed on this Mac.</Body>
      {blockingRulesSyncedAt && !blockingRulesSyncError && <Body>Last checked {new Date(blockingRulesSyncedAt).toLocaleTimeString()}.</Body>}
      {blockingRulesSyncError && <Body>Bloom could not confirm the latest parent rules. Check protection and try again.</Body>}
    </Panel>}
    <View style={[focusStyles.columns, wide && focusStyles.columnsWide]}>
      <View style={[focusStyles.protectionColumn, wide && focusStyles.flexColumn]}>
    <Panel><Eyebrow>Websites</Eyebrow><Label>{websiteCheck === 'checking' ? 'Checking website filter…' : websiteCheck === 'unavailable' || appCheck === 'unavailable' ? 'Website filter status unavailable' : enabled ? websiteUsageAvailable && websiteProviderHealthy ? 'Enabled · filter responding' : 'Enabled · provider or broker degraded' : activationStatus === 'active' ? websiteUsageAvailable ? 'Ready · website filter' : 'Setup · coverage incomplete' : 'Needs attention · website filter'}</Label>
      <Body>1. Set up the system extension and approve Bloom in Privacy & Security.  2. Add a domain.  3. Start protection and allow the content filter when macOS asks.</Body>
      {activationStatus === 'needsApproval' && <Body>Approval is pending. Open System Settings → Privacy & Security, approve Bloom, then return and set up the filter again.</Body>}
      {brokerNeedsApproval && <Body>macOS is waiting for approval of Bloom’s website protection service. Open System Settings → General → Login Items &amp; Extensions, allow Bloom, then return and set up the filter again.</Body>}
      {activationStatus === 'needsRestart' && <Body>Restart your Mac, then return here to start protection.</Body>}
      <Body>The macOS filter needs system approval. It checks website names provided by macOS or visible in an HTTPS connection on this device. If Bloom cannot read a recognized browser’s active address, it blocks that whole browser until screen time is available.</Body>
      {enabled && !websiteUsageAvailable && <Body>Website protection is degraded until Bloom’s background monitor and local policy service are both ready. Some browsers use encrypted or unidentified network flows that macOS does not expose with a website name.</Body>}
      {enabled && !websiteProviderHealthy && <Body>Bloom has not received a recent filter-provider heartbeat. Check website setup and refresh protection status. This does not prove that browser traffic is blocked.</Body>}
      {enabled && brokerUnavailable && <Button label={brokerNeedsApproval ? 'Check website service approval' : 'Set up website policy service'} secondary onPress={() => void run('activate')} busy={busy} />}
      {enabled && !websiteUsageAvailable && appService !== 'active' && <Button label="Enable background monitor" secondary onPress={() => void run('activateApps')} busy={busy} />}
      {supportedBrowsers.length > 0 && <Body>Recognized browsers: {supportedBrowsers.join(', ')}. Other browsers and some app-created network flows may not be covered.</Body>}
      {browserName && <Body>Last checked browser: {browserName} · address check: {browserAddressStatus}.</Body>}
      {browserAutomationStatus === 'permissionRequired' && <Body>Browser automation permission is off. Allow Bloom Exercise under System Settings → Privacy &amp; Security → Automation. Bloom uses Accessibility as a fallback when available.</Body>}
      {browserAutomationStatus === 'unavailable' && <Body>Bloom could not read this browser through Automation. It will block the whole recognized browser while its address remains unreadable.</Body>}
      {browserAddressStatus === 'unsupported' && <Body>This browser is not in Bloom’s recognized browser list. Website rules can only block hostnames that the macOS filter identifies.</Body>}
      {enabled && browserAddressStatus === 'unreadable' && <Body>Bloom cannot read this browser’s active address. It hides the recognized browser while the address is unreadable and allows network flows whose source app macOS does not identify, so website coverage is degraded and unrelated apps keep network access. An existing connection may continue.</Body>}
      {browserHideFailed && <Body>Bloom could not confirm that the affected browser became hidden. Website protection is degraded until the monitor confirms enforcement.</Body>}
      {!accessibilityTrusted && <><Body>Accessibility is needed to block selected apps and to read Firefox and other browser address fields when Automation is unavailable.</Body><Button label="Open Accessibility settings" secondary onPress={() => void openAccessibilitySettings()} busy={busy} /></>}
      <Button label="Set up website filter" secondary onPress={() => void run('activate')} busy={busy} />
      <Field label="Website domain" value={input} onChangeText={setInput} autoCapitalize="none" autoCorrect={false} placeholder="example.com" />
      <Button label="Add website" secondary disabled={!input.trim() || busy} onPress={() => { setSites((current) => [...new Set([...current, input.trim()])]); setInput(''); }} />
      {sites.map((site) => { const parentRule = managedSites.includes(site); return <View key={site} style={sharedStyles.row}><View style={sharedStyles.grow}><Body>{site}{parentRule ? ' · Parent rule' : ''}</Body></View><Button label="Remove" accessibilityLabel={`Remove ${site}`} secondary disabled={busy || parentRule} onPress={() => setSites((current) => current.filter((item) => item !== site))} /></View>; })}
      {!enabled && sites.some((site) => !managedSites.includes(site)) && <Button label="Clear saved manual domains" secondary onPress={() => void run('clearManualDomains')} busy={busy} />}
      <Button label="Save and start blocking" onPress={() => void run('start')} disabled={sites.length === 0} busy={busy} />
      {enabled && managedSites.length === 0 && <Button label="Stop blocking" secondary onPress={() => void run('stop')} busy={busy} />}
      <Body>For removal or recovery, an administrator can remove Bloom-marked hosts entries. This can affect website restrictions for every account on this Mac.</Body>
      {visibleHostsPolicy === 'notConfigured' && <Body>Hosts fallback is not configured for this Mac.</Body>}
      {(visibleHostsPolicy === 'enrolled' || visibleHostsPolicy === 'enrolledEmpty') && <Body>Hosts fallback is configured for this account. Configuration alone does not confirm website coverage.</Body>}
      {visibleHostsPolicy === 'otherAccount' && <Body>Hosts fallback is configured for another account on this Mac.</Body>}
      {visibleHostsPolicy === 'needsEnrollment' && <Body>Hosts fallback needs setup before it can follow this account.</Body>}
      {visibleHostsPolicy === 'cleanupPending' && <Body>Hosts cleanup is still pending.</Body>}
      {hostsManagedSync?.account === profileId && hostsManagedSync.status === 'pending'
        && (visibleHostsPolicy === 'enrolled' || visibleHostsPolicy === 'enrolledEmpty')
        && <Body>Bloom could not refresh parent-managed hosts rules. It will retry while you are signed in.</Body>}
      {visibleHostsPolicy === 'unavailable' && <Body>Bloom could not check hosts fallback setup for this account.</Body>}
      {hostsRecovery === 'checking' && <Body>Checking for interrupted hosts updates…</Body>}
      {hostsRecovery === 'review' && <ErrorText>An interrupted or conflicting hosts update needs administrator review. Compare the current hosts file with the preserved file in /private/etc/.bloom-hosts before removing the conflict artifact. Do not share their contents.</ErrorText>}
      {hostsRecovery === 'busy' && <Body>A hosts update is in progress. Check again shortly.</Body>}
      {hostsRecovery === 'unsafe' && <ErrorText>Bloom cannot safely inspect its hosts recovery directory. An administrator should review its permissions and links before continuing.</ErrorText>}
      {hostsRecovery === 'unavailable' && <Body>Bloom cannot currently check hosts recovery. Enable its background service and try again before removing Bloom.</Body>}
      {hostsRecovery === 'clear' && <Body>No interrupted Bloom hosts update needs review. This check does not establish website coverage.</Body>}
      {(visibleHostsPolicy === 'notConfigured' || visibleHostsPolicy === 'needsEnrollment'
        || visibleHostsPolicy === 'enrolled' || visibleHostsPolicy === 'enrolledEmpty') && <>
        <Body>{visibleHostsPolicy === 'enrolled' || visibleHostsPolicy === 'enrolledEmpty'
          ? 'Update fallback rules from your saved websites and current parent-managed websites. macOS may ask for administrator approval.'
          : 'Enable this fallback to add saved websites and current parent-managed websites to Bloom’s hosts rules. macOS will ask for administrator approval.'} Parent rules refresh while Focus is open and you are signed in.</Body>
        <Button label={visibleHostsPolicy === 'enrolled' || visibleHostsPolicy === 'enrolledEmpty'
          ? 'Update hosts fallback rules' : 'Enable hosts fallback'} secondary onPress={() => void enrollHosts()}
          disabled={!profileId || !session?.access_token || !enabled || sites.length === 0 || remaining > 0
            || (!!usage && !usage.closed) || !!pending || !!usageRequest} busy={busy} />
      </>}
      <Button label="Check hosts recovery" secondary onPress={() => void refreshHostsRecovery()} />
      <Button label="Remove Bloom hosts entries" secondary onPress={() => void cleanupHosts()} busy={busy} />
    </Panel>
      </View>
      <View style={[focusStyles.protectionColumn, wide && focusStyles.flexColumn]}>
    <Panel><Eyebrow>Apps</Eyebrow><Label>{appCheck === 'checking' ? 'Checking app protection…' : appCheck === 'unavailable' ? 'App protection status unavailable' : appHideFailed ? 'Needs attention · App protection' : appEnabled ? 'Active · App protection' : appService === 'active' && accessibilityTrusted ? 'Ready · App protection' : 'Needs attention · App protection'}</Label>
      {appHideFailed && <Body>A selected app is still running. Bloom may be warning it or trying to close it; protection remains degraded until it has quit.</Body>}
      <Body>1. Choose an installed app.  2. Enable the background monitor and Accessibility.  3. Start protection.</Body>
      {!accessibilityTrusted && <Button label="Open Accessibility settings" secondary onPress={() => void openAccessibilitySettings()} busy={busy} />}
      <Body>Enable Bloom’s background monitor in macOS settings. Already-open selected apps receive a 30-second warning before Bloom asks them to quit. Bloom may force close apps that remain open.</Body>
      <Button label={appService === 'active' ? 'Background monitor enabled' : 'Set up app blocking'} secondary onPress={() => void run('activateApps')} busy={busy} />
      <Button label={showAppPicker ? 'Refresh installed apps' : 'Browse installed apps'} secondary onPress={() => void openAppPicker()} busy={busy} />
      {showAppPicker && <>
        <Field label="Search installed apps" value={appSearch} onChangeText={setAppSearch} autoCapitalize="none" autoCorrect={false} placeholder="App name or bundle identifier" />
        {!appCatalog && busy && <Body>Loading installed apps…</Body>}
        {!appCatalog && !busy && <Body>Could not load the list. Refresh it or choose an app from a folder.</Body>}
        {appCatalog && (() => {
          const query = appSearch.trim().toLocaleLowerCase();
          const matches = appCatalog.apps.filter((candidate) => `${candidate.name} ${candidate.id}`.toLocaleLowerCase().includes(query));
          return <>
            {matches.length === 0 ? <Body>No matching apps found. Try a different search or choose an app from a folder.</Body> : <ScrollView style={focusStyles.pickerList} nestedScrollEnabled keyboardShouldPersistTaps="handled">
              {matches.slice(0, 50).map((candidate) => {
                const selected = apps.some((id) => id.toLowerCase() === candidate.id);
                return <View key={candidate.id} style={focusStyles.pickerRow}><View style={sharedStyles.grow}><Label>{candidate.name}</Label><Body>{candidate.id}</Body></View>
                  <Button label={selected ? 'Added' : 'Add'} accessibilityLabel={`${selected ? 'Added' : 'Add'} ${candidate.name}`} secondary disabled={selected || busy} onPress={() => setApps((current) => [...current, candidate.id])} />
                </View>;
              })}
            </ScrollView>}
            {matches.length > 50 && <Body>Showing the first 50 matches. Refine your search to see more.</Body>}
            {appCatalog.truncated && <Body>Some apps were not listed. Use the folder picker to choose one directly.</Body>}
          </>;
        })()}
        <Button label="Close app picker" secondary onPress={() => setShowAppPicker(false)} />
      </>}
      <Button label="Choose an app from a folder" secondary onPress={() => void chooseApp()} busy={busy} />
      <Field label="App bundle identifier" value={appInput} onChangeText={setAppInput} autoCapitalize="none" autoCorrect={false} placeholder="com.example.app" />
      <Button label="Add app" secondary disabled={!appInput.trim() || busy} onPress={() => { setApps((current) => [...new Set([...current, appInput.trim()])]); setAppInput(''); }} />
      {apps.map((app) => { const parentRule = managedApps.includes(app); return <View key={app} style={sharedStyles.row}><View style={sharedStyles.grow}><Body>{app}{parentRule ? ' · Parent rule' : ''}</Body></View><Button label="Remove" accessibilityLabel={`Remove ${app}`} secondary disabled={busy || parentRule} onPress={() => setApps((current) => current.filter((item) => item !== app))} /></View>; })}
      {!appConfigured && <Button label="Clear saved manual apps" secondary onPress={() => void run('clearManualApps')} busy={busy} />}
      <Button label="Save and start app blocking" onPress={() => void run('startApps')} disabled={apps.length === 0} busy={busy} />
      {appConfigured && managedApps.length === 0 && <Button label="Stop app blocking" secondary onPress={() => void run('stopApps')} busy={busy} />}
    </Panel>
      </View>
    </View>
  </Screen>;
}


const focusStyles = StyleSheet.create({
  columns: { gap: 18 },
  columnsWide: { flexDirection: 'row', alignItems: 'flex-start' },
  primaryColumn: { minWidth: 0, gap: 18 },
  secondaryColumn: { minWidth: 0, gap: 18 },
  protectionColumn: { minWidth: 0 },
  flexColumn: { flex: 1 },
  pickerList: { maxHeight: 320 },
  pickerRow: { flexDirection: 'row', alignItems: 'center', gap: 12, paddingVertical: 8 },
});
