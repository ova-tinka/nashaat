import { router, useFocusEffect } from 'expo-router';
import { useCallback, useState } from 'react';
import { Platform, View } from 'react-native';
import BloomBlocking from '../../../modules/bloom-blocking/src/BloomBlockingModule';
import type { AppCandidate, BlockingStatus } from '../../../modules/bloom-blocking/src/BloomBlocking.types';
import { Body, Button, ErrorText, Eyebrow, Field, Heading, Label, Panel, Screen, sharedStyles } from '../../components/bloom-ui';
import { FocusAppPicker } from '../../components/focus-app-picker';
import { useAuth } from '../../lib/auth';
import { canonicalWebsiteDomain } from '../../lib/website-domain';
import { IosManualFocus } from '../../components/ios-manual-focus';

type ManualFocus = { apps: string[]; websites: string[]; active: boolean; remainingMillis: number | null };
export default function ManualFocusScreen() {
  return Platform.OS === 'ios' ? <IosManualFocus /> : <AndroidManualFocus />;
}

function AndroidManualFocus() {
  const { profileId } = useAuth();
  const [focus, setFocus] = useState<ManualFocus | null>(null);
  const [status, setStatus] = useState<BlockingStatus | null>(null);
  const [apps, setApps] = useState<AppCandidate[]>([]);
  const [selected, setSelected] = useState<string[]>([]);
  const [websites, setWebsites] = useState('');
  const [duration, setDuration] = useState('');
  const [editing, setEditing] = useState(false);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const refresh = useCallback(() => {
    if (Platform.OS !== 'android' || !profileId) return;
    try {
      const next = JSON.parse(BloomBlocking.getManualFocus(profileId)) as ManualFocus;
      setFocus(next); setStatus(BloomBlocking.getStatus()); setError(null);
    } catch (cause) { setFocus(null); setStatus(null); setError(cause instanceof Error ? cause.message : 'Could not load Manual Focus.'); }
  }, [profileId]);
  useFocusEffect(useCallback(() => {
    refresh();
    if (Platform.OS === 'android') {
      try { setApps(BloomBlocking.getInstalledApps()); } catch { /* Native status reports unavailable. */ }
    }
    const timer = setInterval(() => {
      if (Platform.OS !== 'android' || !profileId) return;
      try { setFocus(JSON.parse(BloomBlocking.getManualFocus(profileId)) as ManualFocus); setStatus(BloomBlocking.getStatus()); } catch { setStatus(null); }
    }, 5000);
    return () => clearInterval(timer);
  }, [profileId, refresh]));

  function edit() { if (!focus) return; setSelected(focus.apps); setWebsites(focus.websites.join('\n')); setEditing(true); setError(null); }
  async function save() {
    if (!profileId) return;
    const raw = websites.split(/[\n,]+/).map((site) => site.trim()).filter(Boolean);
    const domains = raw.map(canonicalWebsiteDomain);
    if (domains.some((site) => !site) || (!selected.length && !domains.length)) { setError('Choose at least one app or valid website.'); return; }
    setBusy(true); setError(null);
    try { await BloomBlocking.saveManualFocus(profileId, JSON.stringify({ apps: selected, websites: [...new Set(domains as string[])] })); setEditing(false); refresh(); }
    catch (cause) { setError(cause instanceof Error ? cause.message : 'Could not save Manual Focus.'); }
    finally { setBusy(false); }
  }
  async function toggle() {
    if (!profileId || !focus) return;
    const minutes = duration.trim() === '' ? 0 : Number(duration);
    if (!focus.active && (!Number.isInteger(minutes) || minutes < 0 || minutes > 10080)) { setError('Enter a whole number of minutes up to 10,080, or leave it blank.'); return; }
    setBusy(true); setError(null);
    try {
      if (focus.active) await BloomBlocking.stopManualFocus(profileId);
      else await BloomBlocking.startManualFocus(profileId, minutes * 60000);
      refresh();
    } catch (cause) { setError(cause instanceof Error ? cause.message : 'Could not update Manual Focus.'); }
    finally { setBusy(false); }
  }
  const connected = status?.authorized && status.serviceConnected === true && !status.manualFocusError;
  return <Screen safeAreaTop={false}>
    <View style={sharedStyles.column}><Eyebrow>Focus & Blocking</Eyebrow><Heading>Manual Focus</Heading><Body>Block your chosen apps and websites whenever you want to focus.</Body><Button label="Back" variant="tertiary" onPress={() => router.back()} /></View>
    {Platform.OS !== 'android' ? <Panel><Body>Independent Manual Focus is not available on this device. Existing Focus controls remain available where supported.</Body></Panel> : <>
      <Panel>
        <Label>{!focus ? 'Status unavailable' : !connected ? 'Device enforcement needs attention' : focus.active ? 'Manual Focus active' : 'Manual Focus inactive'}</Label>
        <Body>{focus ? `${focus.apps.length} apps · ${focus.websites.length} websites selected` : 'Sync this device to your account to configure Manual Focus.'}</Body>
        {focus?.active && <Body>{focus.remainingMillis === null ? 'Runs until you stop it.' : `${Math.ceil(focus.remainingMillis / 60000)} minutes remaining.`}</Body>}
        {!connected && <Body>Allow the Android Accessibility service and keep it connected before relying on blocking.</Body>}
        <Body>Scheduled and parent restrictions continue independently. Existing timed credit reservations keep running while Focus blocks access.</Body>
        {!focus?.active && <Field label="Duration in minutes (optional)" value={duration} onChangeText={setDuration} keyboardType="number-pad" placeholder="Until stopped" />}
        <Button label={focus?.active ? 'End Focus' : 'Start Focus'} onPress={() => void toggle()} disabled={!focus || busy || (!focus.active && !connected)} busy={busy} />
        <Button label="Choose apps and websites" variant="secondary" onPress={edit} disabled={!focus || busy} />
      </Panel>
      {error && <ErrorText>{error}</ErrorText>}
      {editing && <Panel>
        <Label>Manual Focus targets</Label>
        <FocusAppPicker apps={apps} selected={selected} onChange={setSelected} />
        <Field label="Websites (one domain per line)" value={websites} onChangeText={setWebsites} multiline autoCapitalize="none" autoCorrect={false} />
        <Body>Website checks must be enabled in Focus. Supported browsers with unreadable addresses are blocked as a whole.</Body>
        <Button label="Save selection" onPress={() => void save()} busy={busy} />
        <Button label="Cancel" variant="secondary" onPress={() => { setEditing(false); setError(null); }} disabled={busy} />
      </Panel>}
    </>}
  </Screen>;
}
