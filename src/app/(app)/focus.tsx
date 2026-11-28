import { randomUUID } from 'expo-crypto';
import * as SecureStore from 'expo-secure-store';
import { useCallback, useEffect, useState } from 'react';
import { Platform, View } from 'react-native';
import { router, useFocusEffect, useLocalSearchParams } from 'expo-router';
import { Body, Button, Eyebrow, Field, Heading, Label, Panel, Screen, sharedStyles } from '../../components/bloom-ui';
import BloomBlocking from '../../../modules/bloom-blocking/src/BloomBlockingModule';
import type { AppCandidate, BlockingStatus, SafariContentBlockerState, UsageAccess } from '../../../modules/bloom-blocking/src/BloomBlocking.types';
import { useBloom } from '../../lib/bloom-context';
import { useAuth } from '../../lib/auth';
import { cancelEnforcedCreditSession, findUsageSession, finishUsageSession, startEnforcedCreditSession, startUsageSession } from '../../lib/bloom';
import {
  parseUsageReservationRecord,
  prepareOrRecoverUsageReservation,
  reconcileUsageReservation,
  settleUsageReservation,
  type ReservationStorage,
} from '../../lib/credit-session-lifecycle';
import { isMacDesktop } from '../../lib/macos-blocking';
import { MacosFocus } from '../../components/macos-focus';
import { addWebsiteRule, deleteWebsiteRule, loadWebsiteRules, type ChildRule, type WebsiteRule, type WebsiteRuleScope } from '../../lib/family';
import { syncBlockingRules } from '../../lib/blocking-rules-sync';
import type { FocusSettingsSection } from '../../components/focus-section-navigation';
import { AndroidFocusSettings } from '../../components/android-focus-settings';
import { IosFocusSettings } from '../../components/ios-focus-settings';

const emptyStatus: BlockingStatus = { supported: false, authorized: false, active: false, appCount: 0, websiteCount: 0, categoryCount: 0 };
const secureStorage: ReservationStorage = {
  getItem: (k) => SecureStore.getItemAsync(k),
  setItem: (k, v) => SecureStore.setItemAsync(k, v),
  removeItem: (k) => SecureStore.deleteItemAsync(k),
};
type UsageRequest = { requestId: string; deviceKey: string; requestedMillis: number };

export default function FocusScreen() {
  const params = useLocalSearchParams<{ section?: string }>();
  const { profileId, childProfile } = useAuth();
  const userId = profileId;
  const { creditsEnabled, creditSettings, creditBalance, refresh, blockingRules, blockingRulesSyncError, blockingRulesSyncedAt } = useBloom();
  const [status, setStatus] = useState(emptyStatus);
  const [apps, setApps] = useState<AppCandidate[]>([]);
  const [selected, setSelected] = useState<string[]>([]);
  const [savedSelected, setSavedSelected] = useState<string[]>([]);
  const [websites, setWebsites] = useState<string[]>([]);
  const [websiteConsent, setWebsiteConsent] = useState(false);
  const [websiteInput, setWebsiteInput] = useState('');
  const [websiteRuleScope, setWebsiteRuleScope] = useState<WebsiteRuleScope>('focus');
  const section: FocusSettingsSection = isFocusSection(params.section) ? params.section : 'focus';
  const [websiteRules, setWebsiteRules] = useState<WebsiteRule[]>([]);
  const [safariBlocker, setSafariBlocker] = useState<SafariContentBlockerState | null>(null);
  const [managedRulesState, setManagedRulesState] = useState<{ userId: string; rules: ChildRule[] } | null>(null);
  const [loading, setLoading] = useState(true);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [minutes, setMinutes] = useState('5');
  const [remaining, setRemaining] = useState(0);
  const [pending, setPending] = useState<{ requestId: string; deviceKey: string; minutes: number } | null>(null);
  const [usage, setUsage] = useState<UsageAccess | null>(null);
  const [usageRequest, setUsageRequest] = useState<UsageRequest | null>(null);
  const [showEarnedAccess, setShowEarnedAccess] = useState(false);
  const pendingKey = `bloom-countdown-${profileId ?? ''}`;
  const usageKey = `bloom-usage-${profileId ?? ''}`;
  const managedRules = blockingRulesSyncError && managedRulesState
    && managedRulesState.userId === (userId ?? '')
    ? managedRulesState.rules
    : blockingRules.filter((rule) => rule.platform === Platform.OS);

  const load = useCallback(async () => {
    if (Platform.OS !== 'ios' && Platform.OS !== 'android') {
      setStatus(emptyStatus);
      setLoading(false);
      return;
    }
    try {
      const nextStatus = await BloomBlocking.getStatus();
      setStatus(nextStatus);
      let loadError: string | null = null;
      if (Platform.OS === 'ios' && userId) {
        const [rulesResult, blockerResult] = await Promise.allSettled([
          loadWebsiteRules(userId),
          BloomBlocking.getSafariContentBlockerState(),
        ]);
        if (rulesResult.status === 'fulfilled') setWebsiteRules(rulesResult.value);
        else {
          setWebsiteRules([]);
          loadError = 'Could not load saved website rules. Check your connection and try again.';
        }
        setSafariBlocker(blockerResult.status === 'fulfilled' ? blockerResult.value : null);
      } else if (Platform.OS === 'ios') {
        setWebsiteRules([]);
        setSafariBlocker(await BloomBlocking.getSafariContentBlockerState());
      }
      setRemaining(BloomBlocking.getCreditAccessRemaining());
      if (Platform.OS === 'android' || Platform.OS === 'ios') {
        const nativeUsage = BloomBlocking.getUsageAccess();
        setUsage(nativeUsage);
        const usageStored = await SecureStore.getItemAsync(usageKey);
        const parsedUsage = parseUsageReservationRecord(usageStored, userId ?? undefined);
        setUsageRequest(parsedUsage ? { requestId: parsedUsage.requestId, deviceKey: parsedUsage.deviceKey, requestedMillis: parsedUsage.requestedMillis } : null);
        if (userId) {
          const reconciled = await reconcileUsageReservation({
            storage: secureStorage,
            key: usageKey,
            userId,
            nativeSession: nativeUsage,
            findServerSession: findUsageSession,
          }).catch(() => null);
          if (reconciled?.status === 'recovery_key_missing' && reconciled.message) loadError = reconciled.message;
          else if (reconciled?.status === 'settled_cleanup') setUsageRequest(null);
        }
        if (Platform.OS === 'android') {
          const [installed, saved, savedWebsites, consent] = await Promise.all([BloomBlocking.getInstalledApps(), BloomBlocking.getSelectedApps(), BloomBlocking.getWebsites(), BloomBlocking.getWebsiteConsent()]);
          setApps(installed);
          const availableSelection = saved.filter((id) => installed.some((app) => app.id === id));
          setSelected(availableSelection);
          setSavedSelected(availableSelection);
          setWebsites(savedWebsites);
          setWebsiteConsent(consent);
          const localRules = BloomBlocking.getManagedTargets();
          if (blockingRulesSyncError && localRules.accountId === userId) {
            setManagedRulesState({ userId: userId ?? '', rules: [
              ...localRules.apps.map((target_identifier, index) => ({ id: `cached-app-${index}`, platform: 'android' as const, target_type: 'app' as const, target_identifier })),
              ...localRules.websites.map((target_identifier, index) => ({ id: `cached-site-${index}`, platform: 'android' as const, target_type: 'website' as const, target_identifier })),
            ] });
          }
        }
      }
      if (Platform.OS === 'ios' || Platform.OS === 'android') {
        const stored = await SecureStore.getItemAsync(pendingKey);
        if (stored) {
          const parsed: unknown = JSON.parse(stored);
          if (parsed && typeof parsed === 'object' && 'requestId' in parsed && 'deviceKey' in parsed && 'minutes' in parsed && typeof parsed.requestId === 'string' && typeof parsed.deviceKey === 'string' && typeof parsed.minutes === 'number') setPending({ requestId: parsed.requestId, deviceKey: parsed.deviceKey, minutes: parsed.minutes });
        } else setPending(null);
      }
      setError(loadError);
    } catch {
      setError('Could not read this device’s blocking settings. Rebuild the native app and try again.');
    } finally {
      setLoading(false);
    }
  }, [blockingRulesSyncError, pendingKey, userId, usageKey]);

  useFocusEffect(useCallback(() => { void load(); }, [load]));

  useEffect(() => {
    if (Platform.OS !== 'android' && Platform.OS !== 'ios') return;
    const timer = setInterval(() => { try { setRemaining(BloomBlocking.getCreditAccessRemaining()); setUsage(BloomBlocking.getUsageAccess()); } catch { /* Native build is not installed. */ } }, 1000);
    return () => clearInterval(timer);
  }, []);

  useEffect(() => {
    if (Platform.OS !== 'android') return;
    const timer = setInterval(() => { try { setStatus(BloomBlocking.getStatus()); } catch { /* Keep the last known device status. */ } }, 5000);
    return () => clearInterval(timer);
  }, []);

  async function startScreenTime() {
    const amount = pending?.minutes ?? Number(minutes);
    if (!Number.isFinite(amount) || amount <= 0 || amount > 1440) { setError('Enter a duration between 0 and 1,440 minutes.'); return; }
    setBusy(true); setError(null);
    try {
      const current = await BloomBlocking.getStatus();
      if (!current.active || !current.authorized) throw new Error('Start blocking and allow device access first.');
      if (Platform.OS === 'android' && (!profileId || BloomBlocking.getFocusAccount() !== profileId)) throw new Error('Sync this device to your profile before using screen time.');
      const request = pending ?? { requestId: randomUUID(), deviceKey: randomUUID(), minutes: amount };
      if (!pending) { await SecureStore.setItemAsync(pendingKey, JSON.stringify(request)); setPending(request); }
      const clock = BloomBlocking.getCreditClock();
      if (clock.boot < 0) throw new Error('Could not verify this device’s uptime.');
      const reconcileFailedStart = async (clearNativeAccess: boolean) => {
        try {
          if (clearNativeAccess) await BloomBlocking.endCreditAccess();
          await cancelEnforcedCreditSession(request.requestId, request.deviceKey);
          await SecureStore.deleteItemAsync(pendingKey);
          setPending(null);
        } catch {
          throw new Error('Screen-time request could not be confirmed. Retry to reconcile the saved request before starting another session.');
        }
      };
      let availableMillis: number;
      try {
        availableMillis = await startEnforcedCreditSession(request.requestId, request.deviceKey, request.minutes);
      } catch (startError) {
        await reconcileFailedStart(false);
        throw startError;
      }
      try {
        if (Platform.OS === 'android' && profileId) await BloomBlocking.startCreditAccessForAccount(profileId, availableMillis, clock.elapsedMillis, clock.boot);
        else await BloomBlocking.startCreditAccess(availableMillis, clock.elapsedMillis, clock.boot);
      } catch (activationError) {
        await reconcileFailedStart(true);
        throw activationError;
      }
      await SecureStore.deleteItemAsync(pendingKey);
      setPending(null);
      setRemaining(BloomBlocking.getCreditAccessRemaining());
      await refresh();
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : 'Could not start screen time. Retry the same request.');
    } finally { setBusy(false); }
  }

  async function startActualUsage() {
    const userId = profileId;
    const requestedMillis = usageRequest?.requestedMillis ?? Math.floor(Number(minutes) * 60000);
    const maximum = Platform.OS === 'ios' ? 7200000 : 604800000;
    if (!userId || !Number.isSafeInteger(requestedMillis) || requestedMillis < 1000 || requestedMillis > maximum) { setError(Platform.OS === 'ios' ? 'Enter an amount between one second and two hours.' : 'Enter an amount between one second and one week.'); return; }
    setBusy(true); setError(null);
    try {
      const current = await BloomBlocking.getStatus();
      if (!current.active || !current.authorized) throw new Error(Platform.OS === 'ios' ? 'Start blocking and allow Screen Time access first.' : 'Start blocking and allow Accessibility access first.');
      if (Platform.OS === 'android' && BloomBlocking.getFocusAccount() !== userId) throw new Error('Sync this device to your profile before using screen time.');
      const existingUsage = BloomBlocking.getUsageAccess();
      const request = await prepareOrRecoverUsageReservation(
        secureStorage,
        usageKey,
        userId,
        () => ({ requestId: randomUUID(), deviceKey: randomUUID(), requestedMillis }),
        Boolean(existingUsage),
      );
      setUsageRequest({ requestId: request.requestId, deviceKey: request.deviceKey, requestedMillis: request.requestedMillis });
      const clock = BloomBlocking.getCreditClock();
      if (clock.boot < 0) throw new Error('Could not verify this device’s uptime.');
      const reserved = await startUsageSession(request.requestId, request.deviceKey, request.requestedMillis);
      await BloomBlocking.startUsageAccess(reserved.sessionId, userId, reserved.budgetMillis, reserved.expiryMillis, clock.elapsedMillis, clock.boot);
      setUsage(BloomBlocking.getUsageAccess());
      await refresh();
    } catch (cause) {
      try { setUsage(BloomBlocking.getUsageAccess()); } catch { /* Keep the original setup error. */ }
      setError(cause instanceof Error ? cause.message : 'Could not reserve screen time. Retry the same request.');
    } finally { setBusy(false); }
  }

  async function finishActualUsage() {
    const userId = profileId;
    if (!userId) { setError('This saved screen-time request is unavailable. Refresh your account and try again.'); return; }
    setBusy(true); setError(null);
    try {
      await settleUsageReservation({
        storage: secureStorage,
        key: usageKey,
        userId,
        getNativeSession: async () => BloomBlocking.getUsageAccess(),
        closeNativeSession: async (uid) => {
          const closed = await BloomBlocking.closeUsageAccess(uid);
          if (!closed) throw new Error('No screen-time session was found on this device.');
          setUsage(closed);
          return closed;
        },
        clearNativeSession: async (uid, sid) => {
          await BloomBlocking.clearUsageAccess(uid, sid);
        },
        findServerSession: findUsageSession,
        finishServerSession: finishUsageSession,
      });
      setUsage(null); setUsageRequest(null);
      await refresh();
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : 'Could not sync usage. Retry to return unused credits.');
    } finally { setBusy(false); }
  }

  async function cancelPendingUsage() {
    if (!usageRequest || !profileId) return;
    setBusy(true); setError(null);
    try {
      if (BloomBlocking.getUsageAccess()) throw new Error('Finish the device session before clearing this request.');
      const existing = await findUsageSession(profileId, usageRequest.requestId);
      if (existing && !existing.settled_at) await finishUsageSession(existing.id, usageRequest.deviceKey);
      await SecureStore.deleteItemAsync(usageKey);
      setUsageRequest(null);
      await refresh();
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : 'Could not cancel the screen-time request. Connect and try again.');
    } finally { setBusy(false); }
  }

  async function chooseTargets() {
    setBusy(true); setError(null);
    try {
      if (!status.authorized) {
        const authorized = await BloomBlocking.requestAuthorization();
        if (!authorized) {
          setError('Screen Time access was not granted. Allow it in the system prompt to continue.');
          return;
        }
      }
      await BloomBlocking.presentPicker();
      await load();
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : 'Could not open the system app and website picker.');
    } finally { setBusy(false); }
  }

  async function saveSelection(): Promise<boolean> {
    setBusy(true); setError(null);
    try {
      await BloomBlocking.saveApps(selected);
      const saved = (await BloomBlocking.getSelectedApps()).filter((id) => apps.some((app) => app.id === id));
      setSelected(saved);
      setSavedSelected(saved);
      await load();
      return true;
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : 'Could not save your selected apps.');
      return false;
    } finally { setBusy(false); }
  }

  function cancelSelection() {
    setSelected(savedSelected);
    setError(null);
  }

  async function requestAndroidAccess() {
    try {
      await BloomBlocking.requestAccessibilityPermission();
      setError(null);
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : 'Could not open Android Accessibility settings.');
    }
  }

  async function saveWebsites(next: string[]) {
    setBusy(true); setError(null);
    try {
      await BloomBlocking.saveWebsites(next);
      setWebsites(await BloomBlocking.getWebsites());
      setStatus(await BloomBlocking.getStatus());
      setWebsiteInput('');
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : 'Enter a valid website domain.');
    } finally { setBusy(false); }
  }

  async function saveSafariWebsiteRule() {
    if (!userId) { setError('Sign in to save website rules.'); return; }
    setBusy(true); setError(null);
    try {
      if (websiteRuleScope === 'always' && !status.authorized) {
        const authorized = await BloomBlocking.requestAuthorization();
        if (!authorized) {
          setError('Allow Screen Time access to apply always-blocked websites on this iPhone.');
          return;
        }
        setStatus(await BloomBlocking.getStatus());
      }
      await addWebsiteRule(userId, websiteRuleScope, websiteInput);
      const nextRules = await loadWebsiteRules(userId);
      setWebsiteRules(nextRules);
      const synced = await syncBlockingRules(userId, 'ios');
      if (!synced) throw new Error('Could not apply the latest website rules to this iPhone.');
      if (synced.nativeStatus === 'websiteRulesAuthorizationRequired') {
        setError('The website rule was saved, but Screen Time access is needed to apply the Always filter on this iPhone.');
      }
      setSafariBlocker(await BloomBlocking.getSafariContentBlockerState());
      setWebsiteInput('');
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : 'Could not save this website rule.');
    } finally { setBusy(false); }
  }

  async function authorizeAlwaysWebsiteRules() {
    if (!userId) return;
    setBusy(true); setError(null);
    try {
      const authorized = await BloomBlocking.requestAuthorization();
      if (!authorized) {
        setError('Allow Screen Time access to apply the Always website rules on this iPhone.');
        return;
      }
      setStatus(await BloomBlocking.getStatus());
      const synced = await syncBlockingRules(userId, 'ios');
      if (!synced || synced.nativeStatus === 'websiteRulesAuthorizationRequired') {
        throw new Error('Could not apply the Always website rules on this iPhone.');
      }
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : 'Could not apply the Always website rules on this iPhone.');
    } finally { setBusy(false); }
  }

  async function removeSafariWebsiteRule(rule: WebsiteRule) {
    if (!userId) return;
    setBusy(true); setError(null);
    try {
      await deleteWebsiteRule(userId, rule.id);
      setWebsiteRules(await loadWebsiteRules(userId));
      const synced = await syncBlockingRules(userId, 'ios');
      if (!synced) throw new Error('Could not apply the updated website rules to this iPhone.');
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : 'Could not remove this website rule.');
    } finally { setBusy(false); }
  }

  async function changeWebsiteConsent(enabled: boolean) {
    setBusy(true); setError(null);
    try {
      await BloomBlocking.setWebsiteConsent(enabled);
      setWebsiteConsent(await BloomBlocking.getWebsiteConsent());
      setStatus(await BloomBlocking.getStatus());
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : 'Could not update website checks.');
    } finally { setBusy(false); }
  }

  async function toggleBlocking() {
    setBusy(true); setError(null);
    try {
      if (status.active) {
        await BloomBlocking.stopBlocking();
      } else if (Platform.OS === 'ios') {
        let current = await BloomBlocking.getStatus();
        const hasAppleTargets = current.appCount + current.websiteCount + current.categoryCount > 0;
        const hasFocusWebsites = websiteRules.some((rule) => rule.scope === 'focus')
          || managedRules.some((rule) => rule.platform === 'ios' && rule.target_type === 'website');
        const safariFocusReady = hasFocusWebsites && safariBlocker?.enabled === true;
        if (!current.authorized && (hasAppleTargets || !safariFocusReady)) {
          const authorized = await BloomBlocking.requestAuthorization();
          if (!authorized) { setError('Screen Time access is required to start blocking.'); return; }
          current = await BloomBlocking.getStatus();
        }
        if (current.appCount + current.websiteCount + current.categoryCount === 0 && !hasFocusWebsites && current.authorized) {
          const selection = await BloomBlocking.presentPicker();
          if (selection.cancelled) return;
          current = await BloomBlocking.getStatus();
        }
        const hasTargets = current.appCount + current.websiteCount + current.categoryCount > 0;
        if (!hasTargets && !safariFocusReady) {
          setError(hasFocusWebsites ? 'Enable Bloom under Settings → Safari → Extensions before starting Safari website blocking.' : 'Choose an app or add a Focus website before starting a focus session.');
          return;
        }
        if (hasTargets && !current.authorized) { setError('Allow Screen Time access to block the selected apps.'); return; }
        await BloomBlocking.startBlocking();
      } else if (Platform.OS === 'android') {
        if (!status.authorized || status.serviceConnected !== true) {
          await requestAndroidAccess();
          return;
        }
        await BloomBlocking.saveApps(selected);
        const current = await BloomBlocking.getStatus();
        if (current.appCount + current.websiteCount === 0) { setError('Choose at least one app or website to block.'); return; }
        await BloomBlocking.startBlocking();
      }
      await load();
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : 'Could not update blocking on this device.');
    } finally { setBusy(false); }
  }

  const earnedAccessContent = creditsEnabled && creditSettings ? <Panel>
    <Eyebrow>Shared balance</Eyebrow>
    {creditSettings.credit_mode === 'easy' ? <>
      <Label>{usage ? `${Math.ceil(usage.remainingMillis / 60000)} minutes left in this screen-time session` : `${Math.round(creditBalance * 100) / 100} minutes available`}</Label>
      {usage && usage.userId !== profileId ? <Body>Another account has a session on this device. Sign in to that account to finish it.</Body> : usage ? <>
        <Body>{usage.closed ? 'This screen-time session has ended. Update your balance.' : 'Your minutes keep counting while the selected app is idle.'}</Body>
        <Button label={usage.closed ? 'Update balance' : 'Finish screen-time session'} onPress={() => void finishActualUsage()} busy={busy} />
      </> : <>
        {usageRequest ? <Body>Retrying your previous request for screen time.</Body> : <Field label="Minutes to unlock" value={minutes} onChangeText={setMinutes} keyboardType="decimal-pad" />}
        <Button label={usageRequest ? 'Retry request' : 'Use screen time'} onPress={() => void startActualUsage()} busy={busy} disabled={loading} />
        {usageRequest && <Button label="Cancel request" variant="secondary" onPress={() => void cancelPendingUsage()} busy={busy} />}
      </>}
    </> : <>
      <Label>{remaining > 0 ? `${Math.ceil(remaining / 60000)} minutes left on this device` : `${Math.round(creditBalance * 100) / 100} minutes available`}</Label>
      {pending ? <Body>Retrying a previous request for {pending.minutes} minutes.</Body> : <Field label="Minutes to use" value={minutes} onChangeText={setMinutes} keyboardType="decimal-pad" />}
      <Button label={pending ? 'Retry screen-time request' : 'Use screen time'} onPress={() => void startScreenTime()} busy={busy} disabled={loading || remaining > 0} />
      {pending && <Button label="Clear request" variant="secondary" disabled={busy} onPress={() => void SecureStore.deleteItemAsync(pendingKey).then(() => setPending(null)).catch(() => setError('Could not clear the request.'))} />}
    </>}
  </Panel> : <Body>Screen-time credits are not enabled for this account.</Body>;

  if (isMacDesktop()) return <MacosFocus initialSection={section} openEarned={params.section === 'earned'} />;
  if (Platform.OS === 'android') {
    const managedApps = managedRules.filter((rule) => rule.platform === 'android' && rule.target_type === 'app').map((rule) => rule.target_identifier);
    const managedWebsites = managedRules.filter((rule) => rule.platform === 'android' && rule.target_type === 'website').map((rule) => rule.target_identifier);
    return <AndroidFocusSettings
      key={section}
      status={status}
      loading={loading}
      busy={busy}
      error={error}
      syncError={blockingRulesSyncError}
      apps={apps}
      selected={selected}
      managedApps={managedApps}
      managedWebsites={managedWebsites}
      websiteConsent={websiteConsent}
      websites={websites}
      websiteInput={websiteInput}
      initialSection={section}
      showEarnedAccess={showEarnedAccess}
      earnedAccessContent={earnedAccessContent}
      onBack={() => router.canGoBack() ? router.back() : router.replace('/settings')}
      onChangeSelected={setSelected}
      onSaveSelection={saveSelection}
      onCancelSelection={cancelSelection}
      onEnableAccessibility={() => void requestAndroidAccess()}
      onToggleBlocking={() => void toggleBlocking()}
      onToggleWebsiteChecks={(enabled) => void changeWebsiteConsent(enabled)}
      onChangeWebsiteInput={setWebsiteInput}
      onAddWebsite={() => void saveWebsites([...websites, websiteInput])}
      onRemoveWebsite={(website) => void saveWebsites(websites.filter((item) => item !== website))}
      onToggleEarnedAccess={() => setShowEarnedAccess((visible) => !visible)}
    />;
  }
  if (Platform.OS === 'ios') return <IosFocusSettings
    key={section}
    status={status}
    loading={loading}
    busy={busy}
    error={error}
    syncError={blockingRulesSyncError}
    websiteRules={websiteRules}
    managedRules={managedRules}
    userId={userId}
    safariBlocker={safariBlocker}
    websiteInput={websiteInput}
    websiteRuleScope={websiteRuleScope}
    blockingRulesSyncedAt={blockingRulesSyncedAt}
    childProfile={childProfile}
    initialSection={section}
    showEarnedAccess={showEarnedAccess}
    earnedAccessContent={earnedAccessContent}
    onBack={() => router.canGoBack() ? router.back() : router.replace('/settings')}
    onChooseTargets={() => void chooseTargets()}
    onToggleBlocking={() => void toggleBlocking()}
    onAuthorizeAlwaysWebsites={() => void authorizeAlwaysWebsiteRules()}
    onRemoveWebsiteRule={(rule) => void removeSafariWebsiteRule(rule)}
    onWebsiteInputChange={setWebsiteInput}
    onWebsiteScopeChange={setWebsiteRuleScope}
    onSaveWebsiteRule={() => void saveSafariWebsiteRule()}
    onRecheckSafari={() => void BloomBlocking.getSafariContentBlockerState().then(setSafariBlocker).catch(() => { setSafariBlocker(null); setError('Could not check the Safari extension state.'); })}
    onToggleEarnedAccess={() => setShowEarnedAccess((visible) => !visible)}
    onManageFamilyRules={() => router.push('/family')}
  />;

  return <Screen safeAreaTop={false}>
    <View style={sharedStyles.column}>
      <Eyebrow>Focus</Eyebrow>
      <Heading>Blocking settings</Heading>
      <Body>Native blocking controls are unavailable in this browser. Open Bloom on iPhone, Android, or Mac to manage on-device protection.</Body>
      <Button label="Back to settings" variant="tertiary" onPress={() => router.replace('/settings')} />
    </View>
  </Screen>;
}

function isFocusSection(value: unknown): value is FocusSettingsSection {
  return value === 'focus' || value === 'apps' || value === 'websites' || value === 'rules' || value === 'earned';
}
