import { router, useFocusEffect } from 'expo-router';
import { useCallback, useState } from 'react';
import { View } from 'react-native';
import BloomBlocking from '../../modules/bloom-blocking/src/BloomBlockingModule';
import type { IosManualFocus as ManualState } from '../../modules/bloom-blocking/src/BloomBlocking.types';
import { useAuth } from '../lib/auth';
import { syncBlockingRules } from '../lib/blocking-rules-sync';
import { Body, Button, ErrorText, Eyebrow, Heading, Label, Panel, Screen, sharedStyles } from './bloom-ui';

export function IosManualFocus() {
  const { profileId } = useAuth();
  const [focus, setFocus] = useState<ManualState | null>(null);
  const [authorized, setAuthorized] = useState(false);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const refresh = useCallback(() => {
    if (!profileId) return;
    try { setAuthorized(BloomBlocking.getStatus().authorized); setFocus(BloomBlocking.getIosManualFocus(profileId)); setError(null); }
    catch { setFocus(null); setError('Could not load this device’s Manual Focus. Sync your profile and try again.'); }
  }, [profileId]);
  useFocusEffect(useCallback(() => { refresh(); }, [refresh]));
  async function retrySync() {
    if (!profileId) return;
    setBusy(true); setError(null);
    try { await syncBlockingRules(profileId, 'ios'); refresh(); }
    catch { setError('Could not sync this device. Check your connection and try again.'); }
    finally { setBusy(false); }
  }
  async function choose() {
    if (!profileId) return;
    setBusy(true); setError(null);
    try {
      if (!BloomBlocking.getStatus().authorized && !(await BloomBlocking.requestAuthorization())) throw new Error('Allow Screen Time access first.');
      await BloomBlocking.presentIosManualPicker(profileId); refresh();
    } catch (cause) { setError(cause instanceof Error ? cause.message : 'Could not choose apps.'); }
    finally { setBusy(false); }
  }
  async function toggle() {
    if (!profileId || !focus) return;
    setBusy(true); setError(null);
    try {
      if (focus.active) await BloomBlocking.stopIosManualFocus(profileId);
      else await BloomBlocking.startIosManualFocus(profileId);
      refresh();
    } catch (cause) { setError(cause instanceof Error ? cause.message : 'Could not update Manual Focus.'); }
    finally { setBusy(false); }
  }
  return <Screen safeAreaTop={false}>
    <View style={sharedStyles.column}><Eyebrow>Focus & Blocking</Eyebrow><Heading>Manual Focus</Heading><Body>Choose what to block with Apple’s Screen Time picker.</Body><Button label="Back" variant="tertiary" onPress={() => router.back()} /></View>
    <Panel><Label>{!focus ? 'Status unavailable' : !authorized ? 'Screen Time permission needed' : focus.active ? 'Manual Focus configured' : 'Manual Focus inactive'}</Label>
      <Body>{focus ? `${focus.appCount} apps · ${focus.websiteCount} websites · ${focus.categoryCount} categories selected` : 'Sync this device to your profile to configure Manual Focus.'}</Body>
      <Body>iOS controls the effective restrictions. Manual Focus uses a separate Screen Time store and runs until stopped; timed sessions are not available here yet.</Body>
      <Body>Existing timed credit reservations continue running while Focus blocks access.</Body>
      <Button label="Choose apps and websites" variant="secondary" onPress={() => void choose()} disabled={busy || !focus} />
      <Button label={focus?.active ? 'End Focus' : 'Start Focus'} onPress={() => void toggle()} busy={busy} disabled={busy || !focus || (!focus.active && (!authorized || focus.appCount + focus.websiteCount + focus.categoryCount === 0))} />
    </Panel>
    {error && <ErrorText>{error}</ErrorText>}
    {!focus && <Button label="Sync device" variant="secondary" onPress={() => void retrySync()} busy={busy} disabled={busy} />}
  </Screen>;
}
