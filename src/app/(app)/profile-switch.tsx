import { router } from 'expo-router';
import { useCallback, useEffect, useState } from 'react';
import { ActivityIndicator, View } from 'react-native';
import { Body, Button, ErrorText, Eyebrow, Field, Heading, Label, Panel, Screen, sharedStyles } from '../../components/bloom-ui';
import { useAuth } from '../../lib/auth';
import { getDevicePin, getSavedChild, registerDevicePin, removeDevicePin, restoreChildSession, unlockParent } from '../../lib/profile-switch';
import { colors } from '../../theme';

export default function ProfileSwitchScreen() {
  const { session, managedChild } = useAuth();
  const [device, setDevice] = useState<Awaited<ReturnType<typeof getDevicePin>>>(null);
  const [hasChild, setHasChild] = useState(false);
  const [loading, setLoading] = useState(true);
  const [busy, setBusy] = useState(false);
  const [pin, setPin] = useState('');
  const [confirm, setConfirm] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [message, setMessage] = useState<string | null>(null);
  const load = useCallback(async () => {
    try {
      const [registered, saved] = await Promise.all([getDevicePin(), getSavedChild()]);
      setDevice(registered); setHasChild(Boolean(saved));
    } catch { setError('Could not access this device’s profile settings.'); }
    finally { setLoading(false); }
  }, []);
  // Restore device-local switching state when the screen mounts.
  // eslint-disable-next-line react-hooks/set-state-in-effect
  useEffect(() => { void load(); }, [load]);

  async function run(action: () => Promise<void>, success?: string) {
    setBusy(true); setError(null); setMessage(null);
    try { await action(); setPin(''); setConfirm(''); await load(); if (success) setMessage(success); }
    catch (caught) { setError(caught instanceof Error ? caught.message : 'Could not switch profiles. Please try again.'); }
    finally { setBusy(false); }
  }
  const parentMode = Boolean(session && (!device || device.parentId === session.user.id));

  return <Screen>
    <View style={sharedStyles.column}><Eyebrow>Family</Eyebrow><Heading>Switch profiles</Heading><Body>A parent PIN authorizes a fresh parent session on this device.</Body></View>
    {loading && <ActivityIndicator color={colors.accent} />}
    {error && <ErrorText>{error}</ErrorText>}{message && <Body>{message}</Body>}
    {!loading && device && !parentMode && <Panel>
      <Label>Switch to parent</Label>
      <Body>Enter the PIN set by your parent on this device. Five incorrect attempts lock the PIN for 15 minutes.</Body>
      <Field label="Parent PIN" value={pin} onChangeText={setPin} keyboardType="number-pad" secureTextEntry maxLength={6} />
      <Button label="Unlock parent" busy={busy} disabled={pin.length !== 6} onPress={() => void run(async () => { await unlockParent(pin); router.replace('/settings'); })} />
    </Panel>}
    {!loading && parentMode && !managedChild && session && <Panel>
      <Label>{device ? 'Change parent PIN' : 'Set a parent PIN'}</Label>
      <Body>Set a six-digit PIN on this device before signing into a child profile. Your parent session is not kept in child mode.</Body>
      <Field label="New parent PIN" value={pin} onChangeText={setPin} keyboardType="number-pad" secureTextEntry maxLength={6} />
      <Field label="Confirm parent PIN" value={confirm} onChangeText={setConfirm} keyboardType="number-pad" secureTextEntry maxLength={6} />
      <Button label="Save PIN" busy={busy} disabled={pin.length !== 6 || pin !== confirm} onPress={() => void run(() => registerDevicePin(session.user.id, pin), 'Parent PIN saved for this device.')} />
      {device && <Button label="Remove this device’s PIN" secondary disabled={busy} onPress={() => void run(() => removeDevicePin(session.user.id), 'Parent PIN removed from this device.')} />}
    </Panel>}
    {!loading && !device && managedChild && <Panel><Label>No parent PIN on this device</Label><Body>A parent can sign in on this device and set a PIN, then pair the child profile again.</Body></Panel>}
    {!loading && parentMode && hasChild && <Panel><Label>Return to child</Label><Body>Switching signs out the parent session on this device before restoring the child session.</Body><Button label="Switch to child" busy={busy} onPress={() => void run(async () => { await restoreChildSession(); router.replace('/'); })} /></Panel>}
    <Button label="Back to profile" secondary onPress={() => router.replace('/settings')} disabled={busy} />
  </Screen>;
}
