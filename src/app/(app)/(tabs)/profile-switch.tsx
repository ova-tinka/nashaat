import { router, type Href } from 'expo-router';
import { useCallback, useEffect, useState } from 'react';
import { ActivityIndicator, View } from 'react-native';
import { Body, Button, DesktopContent, ErrorText, Eyebrow, Heading, Label, Panel, Screen, sharedStyles } from '../../../components/bloom-ui';
import { useAuth } from '../../../lib/auth';
import { isProtectedStorageSupported } from '../../../lib/protected-storage';
import { beginSwitchToParent, clearLegacyParentPinState, clearSavedChildSession, getSavedChild, restoreChildSession } from '../../../lib/profile-switch';
import { useBloomTheme } from '../../../lib/theme-context';

export default function ProfileSwitchScreen() {
  const { theme } = useBloomTheme();
  const { session, childProfile } = useAuth();
  const [hasChild, setHasChild] = useState(false);
  const [loading, setLoading] = useState(true);
  const [busy, setBusy] = useState(false);
  const [confirmParentSignIn, setConfirmParentSignIn] = useState(false);
  const [confirmChildReturn, setConfirmChildReturn] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [message, setMessage] = useState<string | null>(null);
  const supported = isProtectedStorageSupported();

  const load = useCallback(async () => {
    try {
      await clearLegacyParentPinState();
      const saved = await getSavedChild();
      setHasChild(Boolean(saved));
    } catch {
      setError('Could not access this device’s profile settings.');
    } finally {
      setLoading(false);
    }
  }, []);

  // eslint-disable-next-line react-hooks/set-state-in-effect
  useEffect(() => { void load(); }, [load]);

  async function run(action: () => Promise<void>, success?: string) {
    setBusy(true); setError(null); setMessage(null);
    try {
      await action();
      setConfirmParentSignIn(false);
      setConfirmChildReturn(false);
      await load();
      if (success) setMessage(success);
    } catch (caught) {
      setError(caught instanceof Error ? caught.message : 'Could not switch profiles. Please try again.');
    } finally {
      setBusy(false);
    }
  }

  return <Screen safeAreaTop={false}>
    <DesktopContent maxWidth={760}>
      <View style={sharedStyles.column}>
        <Eyebrow>Family</Eyebrow>
        <Heading>Switch profiles</Heading>
        <Body>Parent switching requires signing in with your parent account and password. PIN-based parent unlock has been retired.</Body>
      </View>
      {loading && <ActivityIndicator color={theme.colors.action} />}
      {error && <ErrorText>{error}</ErrorText>}
      {message && <Body>{message}</Body>}

      {!loading && session && childProfile && <Panel>
        <Label>Switch to parent</Label>
        {confirmParentSignIn ? <View style={sharedStyles.column}>
          <Body>{supported
            ? 'This signs out of the child session locally and keeps a protected quick-return token on this device so you can switch back after signing in as a parent.'
            : 'This signs out of the child session on this browser so you can sign in with your parent account. Pair the child device again to return to Child View.'}</Body>
          <Button
            label="Continue to parent sign-in"
            busy={busy}
            onPress={() => void run(async () => {
              await beginSwitchToParent();
              router.replace('/sign-in?next=%2Fsettings' as Href);
            })}
          />
          <Button label="Stay in child profile" variant="tertiary" disabled={busy} onPress={() => setConfirmParentSignIn(false)} />
        </View> : <>
          <Body>Sign in with your parent email and password (including any configured MFA) to manage family settings.</Body>
          <Button label="Sign in as parent" onPress={() => setConfirmParentSignIn(true)} disabled={busy} />
        </>}
      </Panel>}

      {!loading && session && !childProfile && hasChild && supported && <Panel>
        <Label>Return to child</Label>
        {confirmChildReturn ? <View style={sharedStyles.column}>
          <Body>This ends the parent session on this device and restores the saved child session from protected storage.</Body>
          <Button label="End parent session and switch" variant="destructive" busy={busy} onPress={() => void run(async () => { await restoreChildSession(); router.replace('/'); })} />
          <Button label="Stay in parent profile" variant="tertiary" disabled={busy} onPress={() => setConfirmChildReturn(false)} />
        </View> : <>
          <Body>Switching back to Child View signs out the parent session on this device.</Body>
          <Button label="Review switch to child" secondary disabled={busy} onPress={() => setConfirmChildReturn(true)} />
          <Button label="Forget saved child profile" variant="tertiary" disabled={busy} onPress={() => void run(() => clearSavedChildSession(), 'Saved child profile cleared from this device.')} />
        </>}
      </Panel>}

      {!loading && !childProfile && !hasChild && <Panel>
        <Label>Shared-device switching</Label>
        <Body>To switch into a child profile on a shared device, pair the device from Family Space, then use this screen when switching back to a parent account.</Body>
      </Panel>}

      <Button label="Back to profile" secondary onPress={() => router.replace('/settings')} disabled={busy} />
    </DesktopContent>
  </Screen>;
}
