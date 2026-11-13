import { randomUUID } from 'expo-crypto';
import * as SecureStore from 'expo-secure-store';
import { useCallback, useEffect, useState } from 'react';
import { Platform, Pressable, StyleSheet, Text, View } from 'react-native';
import { useFocusEffect } from 'expo-router';
import { Body, Button, ErrorText, Eyebrow, Field, Heading, Label, Panel, Screen, sharedStyles } from '../../../components/bloom-ui';
import BloomBlocking from '../../../../modules/bloom-blocking/src/BloomBlockingModule';
import type { AppCandidate, BlockingStatus, UsageAccess } from '../../../../modules/bloom-blocking/src/BloomBlocking.types';
import { colors } from '../../../theme';
import { useBloom } from '../../../lib/bloom-context';
import { useAuth } from '../../../lib/auth';
import { findUsageSession, finishUsageSession, startEnforcedCreditSession, startUsageSession } from '../../../lib/bloom';
import { isMacDesktop } from '../../../lib/macos-blocking';
import { MacosFocus } from '../../../components/macos-focus';
import type { ChildRule } from '../../../lib/family';

const emptyStatus: BlockingStatus = { supported: false, authorized: false, active: false, appCount: 0, websiteCount: 0, categoryCount: 0 };
type UsageRequest = { requestId: string; deviceKey: string; requestedMillis: number };

export default function FocusScreen() {
  const { profileId } = useAuth();
  const userId = profileId;
  const { creditsEnabled, creditSettings, creditBalance, refresh, blockingRules, blockingRulesSyncError, blockingRulesSyncedAt } = useBloom();
  const [status, setStatus] = useState(emptyStatus);
  const [apps, setApps] = useState<AppCandidate[]>([]);
  const [selected, setSelected] = useState<string[]>([]);
  const [websites, setWebsites] = useState<string[]>([]);
  const [websiteConsent, setWebsiteConsent] = useState(false);
  const [websiteInput, setWebsiteInput] = useState('');
  const [managedRulesState, setManagedRulesState] = useState<{ userId: string; rules: ChildRule[] } | null>(null);
  const [loading, setLoading] = useState(true);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [minutes, setMinutes] = useState('5');
  const [remaining, setRemaining] = useState(0);
  const [pending, setPending] = useState<{ requestId: string; deviceKey: string; minutes: number } | null>(null);
  const [usage, setUsage] = useState<UsageAccess | null>(null);
  const [usageRequest, setUsageRequest] = useState<UsageRequest | null>(null);
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
      setRemaining(BloomBlocking.getCreditAccessRemaining());
      if (Platform.OS === 'android' || Platform.OS === 'ios') {
        setUsage(BloomBlocking.getUsageAccess());
        const usageStored = await SecureStore.getItemAsync(usageKey);
        if (usageStored) {
          const parsed: unknown = JSON.parse(usageStored);
          if (parsed && typeof parsed === 'object' && 'requestId' in parsed && 'deviceKey' in parsed && 'requestedMillis' in parsed && typeof parsed.requestId === 'string' && typeof parsed.deviceKey === 'string' && typeof parsed.requestedMillis === 'number') {
            setUsageRequest({ requestId: parsed.requestId, deviceKey: parsed.deviceKey, requestedMillis: parsed.requestedMillis });
          }
        } else setUsageRequest(null);
        if (Platform.OS === 'android') {
          const [installed, saved, savedWebsites, consent] = await Promise.all([BloomBlocking.getInstalledApps(), BloomBlocking.getSelectedApps(), BloomBlocking.getWebsites(), BloomBlocking.getWebsiteConsent()]);
          setApps(installed);
          setSelected(saved.filter((id) => installed.some((app) => app.id === id)));
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
      setError(null);
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
      const request = pending ?? { requestId: randomUUID(), deviceKey: randomUUID(), minutes: amount };
      if (!pending) { await SecureStore.setItemAsync(pendingKey, JSON.stringify(request)); setPending(request); }
      const clock = BloomBlocking.getCreditClock();
      if (clock.boot < 0) throw new Error('Could not verify this device’s uptime.');
      const availableMillis = await startEnforcedCreditSession(request.requestId, request.deviceKey, request.minutes);
      await BloomBlocking.startCreditAccess(availableMillis, clock.elapsedMillis, clock.boot);
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
      const request = usageRequest ?? { requestId: randomUUID(), deviceKey: randomUUID(), requestedMillis };
      if (!usageRequest) { await SecureStore.setItemAsync(usageKey, JSON.stringify(request)); setUsageRequest(request); }
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
    if (!userId || !usageRequest) { setError('The device key for this reservation is unavailable.'); return; }
    setBusy(true); setError(null);
    try {
      const closed = await BloomBlocking.closeUsageAccess(userId);
      if (!closed) throw new Error('No screen-time session was found on this device.');
      setUsage(closed);
      await finishUsageSession(closed.sessionId, usageRequest.deviceKey);
      await BloomBlocking.clearUsageAccess(userId, closed.sessionId);
      await SecureStore.deleteItemAsync(usageKey);
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
      setError(cause instanceof Error ? cause.message : 'Could not clear the reservation. Connect and try again.');
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

  async function saveSelection() {
    setBusy(true); setError(null);
    try {
      await BloomBlocking.saveApps(selected);
      await load();
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : 'Could not save your selected apps.');
    } finally { setBusy(false); }
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
        if (!status.authorized) {
          const authorized = await BloomBlocking.requestAuthorization();
          if (!authorized) { setError('Screen Time access is required to start blocking.'); return; }
        }
        let current = await BloomBlocking.getStatus();
        if (current.appCount + current.websiteCount + current.categoryCount === 0) {
          const selection = await BloomBlocking.presentPicker();
          if (selection.cancelled) return;
          current = await BloomBlocking.getStatus();
        }
        if (current.appCount + current.websiteCount + current.categoryCount === 0) { setError('Choose at least one app, website, or category before starting a focus session.'); return; }
        await BloomBlocking.startBlocking();
      } else if (Platform.OS === 'android') {
        if (!status.authorized) {
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

  function toggleApp(id: string) {
    setSelected((current) => current.includes(id) ? current.filter((item) => item !== id) : [...current, id]);
  }

  const nativePlatform = Platform.OS === 'ios' || Platform.OS === 'android';
  if (isMacDesktop()) return <MacosFocus />;
  return <Screen>
    <View style={sharedStyles.column}>
      <Eyebrow>Focus</Eyebrow>
      <Heading>App and website blocking</Heading>
      <Body>Choose the distractions you want out of reach while you focus.</Body>
    </View>

    {!nativePlatform ? <Panel>
      <Label>Blocking is not connected on this platform yet.</Label>
      <Body>Use the Bloom iOS or Android app to set up device blocking. macOS enforcement through Tauri is still to be built.</Body>
    </Panel> : <>
      {managedRules.length > 0 && <Panel>
        <Eyebrow>Parent-set blocking rules</Eyebrow>
        <Label>{managedRules.length} rules for this device</Label>
        {blockingRulesSyncedAt && !blockingRulesSyncError && <Body>Last refreshed {new Date(blockingRulesSyncedAt).toLocaleTimeString()}.</Body>}
        {Platform.OS === 'ios' ? <Body>Apple requires app and website targets to be selected on this device. Account rules use names that Apple does not expose to Bloom, so they cannot be applied automatically. Select the required targets in Apple’s picker below.</Body> : <>
          {managedRules.map((rule) => <Body key={rule.id}>{rule.target_type === 'app' ? 'App' : 'Website'} · {rule.target_identifier}</Body>)}
          {managedRules.some((rule) => rule.target_type === 'website') && !websiteConsent && <Body>Enable website checks below before starting these parent-set website rules.</Body>}
        </>}
      </Panel>}
      <Panel>
        <Eyebrow>{Platform.OS === 'ios' ? 'iPhone and iPad' : 'Android device'}</Eyebrow>
        <Label>{loading ? 'Checking device access…' : status.active ? Platform.OS === 'android' && status.serviceConnected === false ? 'Blocking service needs attention' : 'Focus blocking is on' : 'Focus blocking is off'}</Label>
        <Body>{Platform.OS === 'ios'
          ? 'Apple’s Screen Time controls block selected apps and web domains on this device.'
          : 'Bloom blocks selected apps and checks website addresses in supported browsers while focus blocking is on.'}</Body>
        {Platform.OS === 'ios' && !status.authorized && <Body>Screen Time access is not enabled yet. Allow it on this iPhone or iPad, then select the apps and websites on this device.</Body>}
        {Platform.OS === 'ios' && status.authorized && status.appCount + status.websiteCount + status.categoryCount === 0 && <Body>Screen Time is authorized, but no targets are selected. Choose them on this device to finish setup.</Body>}
        {Platform.OS === 'ios' && <Button label="Choose apps and websites" secondary onPress={() => void chooseTargets()} busy={busy} disabled={loading} />}
        {Platform.OS === 'ios' && status.appCount + status.websiteCount + status.categoryCount > 0 && <Body>{status.appCount} apps · {status.websiteCount} websites · {status.categoryCount} categories selected</Body>}
        {Platform.OS === 'android' && !status.authorized && <>
          <Body>Android grants Bloom access to screen content. Bloom checks the open app and, only if you enable website checks below, the address field in supported browsers. Website addresses are checked on this device.</Body>
          <Button label="Allow app blocking" secondary onPress={() => void requestAndroidAccess()} busy={busy} />
        </>}
        {Platform.OS === 'android' && status.active && status.serviceConnected === false && <>
          <Body>The Accessibility service is not responding, so app and website blocking may be inactive. Open Android Accessibility settings and turn Bloom back on.</Body>
          <Button label="Open Accessibility settings" secondary onPress={() => void requestAndroidAccess()} busy={busy} />
        </>}
        <Button label={status.active && Platform.OS === 'android' && managedRules.length > 0 ? 'Parent rules stay on' : status.active ? 'Stop blocking' : 'Start focus blocking'} onPress={() => void toggleBlocking()} busy={busy} disabled={loading || (Platform.OS === 'android' && !status.authorized) || (Platform.OS === 'android' && status.active && managedRules.length > 0)} />
      </Panel>

      {(Platform.OS === 'android' || Platform.OS === 'ios') && creditsEnabled && creditSettings && <Panel>
        <Eyebrow>Earned screen time</Eyebrow>
        {creditSettings.credit_mode === 'easy' ? <>
          <Label>{usage ? `${Math.ceil(usage.remainingMillis / 60000)} minutes left in this reservation` : `${Math.round(creditBalance * 100) / 100} minutes in your shared balance`}</Label>
          <Body>Easy is a server-timed access window. Time runs continuously from reservation, including while the selected target is idle. Finish early to return the unused portion calculated by the server.</Body>
          {usage && usage.userId !== profileId ? <Body>Another account has a session on this device. Sign in to that account to finish it.</Body> : usage ? <>
            <Body>{usage.closed ? 'This access window has ended. Sync it to settle the server-timed amount.' : usage.tracking ? 'A selected target is currently detected. The access timer runs either way.' : 'No selected target is currently detected. The access timer continues while idle.'}</Body>
            <Button label={usage.closed ? 'Sync screen-time session' : 'Finish screen-time session'} onPress={() => void finishActualUsage()} busy={busy} />
          </> : <>
            {usageRequest ? <Body>Retrying a previous screen-time reservation.</Body> : <Field label="Minutes to reserve" value={minutes} onChangeText={setMinutes} keyboardType="decimal-pad" />}
            <Button label={usageRequest ? 'Retry reservation' : 'Use screen time'} onPress={() => void startActualUsage()} busy={busy} disabled={loading} />
            {usageRequest && <Button label="Cancel pending reservation" secondary onPress={() => void cancelPendingUsage()} busy={busy} />}
          </>}
        </> : <>
          <Label>{remaining > 0 ? `${Math.ceil(remaining / 60000)} minutes left on this device` : `${Math.round(creditBalance * 100) / 100} minutes in your shared balance`}</Label>
          <Body>Start blocking first. The countdown runs until its scheduled end, even if you sign out, restart, or device setup fails. The daily limit may shorten your request.</Body>
          {pending ? <Body>Retrying your previous request for {pending.minutes} minutes.</Body> : <Field label="Minutes to use" value={minutes} onChangeText={setMinutes} keyboardType="decimal-pad" />}
          <Button label={pending ? 'Retry screen-time request' : 'Use screen time'} onPress={() => void startScreenTime()} busy={busy} disabled={loading || remaining > 0} />
          {pending && <><Body>Clearing the request does not cancel a countdown that has already started.</Body><Button label="Clear request" secondary disabled={busy} onPress={() => void SecureStore.deleteItemAsync(pendingKey).then(() => setPending(null)).catch(() => setError('Could not clear the request.'))} /></>}
        </>}
      </Panel>}

      {Platform.OS === 'android' && <Panel>
        <Eyebrow>Blocked apps</Eyebrow>
        <Label>Choose apps for focus time</Label>
        {apps.length === 0 && <Body>No launchable apps were found on this device.</Body>}
        {apps.map((app) => {
          const parentRequired = managedRules.some((rule) => rule.target_type === 'app' && rule.target_identifier === app.id);
          const checked = parentRequired || selected.includes(app.id);
          return <Pressable key={app.id} accessibilityRole="checkbox" accessibilityState={{ checked, disabled: parentRequired }} onPress={() => toggleApp(app.id)} disabled={parentRequired} style={styles.appRow}>
            <Text style={styles.appName}>{app.name}{parentRequired ? ' · Parent rule' : ''}</Text>
            <Text style={[styles.check, checked && styles.checked]}>{checked ? '✓' : ''}</Text>
          </Pressable>;
        })}
        <Button label="Save app selection" secondary onPress={() => void saveSelection()} busy={busy} disabled={loading} />
      </Panel>}
      {Platform.OS === 'android' && <Panel>
        <Eyebrow>Blocked websites</Eyebrow>
        <Label>Choose websites for focus time</Label>
        <Body>Bloom checks supported browser addresses on this device. If it cannot read the address in a recognized browser, it blocks the whole browser. Other browsers and in-app browsers are not covered.</Body>
        {status.supportedBrowsers?.length ? <Body>Recognized browsers: {status.supportedBrowsers.join(', ')}.</Body> : null}
        <Button label={websiteConsent && managedRules.some((rule) => rule.target_type === 'website') ? 'Website checks required by parent' : websiteConsent ? 'Turn off website checks' : 'Enable website checks'} secondary onPress={() => void changeWebsiteConsent(!websiteConsent)} busy={busy} disabled={websiteConsent && managedRules.some((rule) => rule.target_type === 'website')} />
        {websiteConsent && <>
        <Field label="Website domain" value={websiteInput} onChangeText={setWebsiteInput} autoCapitalize="none" autoCorrect={false} keyboardType="url" placeholder="example.com" />
        <Button label="Add website" secondary onPress={() => void saveWebsites([...websites, websiteInput])} disabled={!websiteInput.trim()} busy={busy} />
        {websites.map((site) => <View key={site} style={sharedStyles.row}>
          <Body>{site}</Body>
          <Button label={`Remove ${site}`} secondary onPress={() => void saveWebsites(websites.filter((item) => item !== site))} busy={busy} />
        </View>)}
        </>}
      </Panel>}
    </>}

    {(blockingRulesSyncError || error) && <ErrorText>{blockingRulesSyncError || error}</ErrorText>}
  </Screen>;
}

const styles = StyleSheet.create({
  appRow: { minHeight: 48, flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', borderBottomWidth: StyleSheet.hairlineWidth, borderColor: colors.border, paddingVertical: 8 },
  appName: { color: colors.text, fontSize: 15, flex: 1 },
  check: { width: 24, height: 24, borderWidth: 1, borderColor: colors.muted, borderRadius: 6, textAlign: 'center', color: colors.accentInk, overflow: 'hidden' },
  checked: { backgroundColor: colors.accent, borderColor: colors.accent, fontWeight: '800' },
});
