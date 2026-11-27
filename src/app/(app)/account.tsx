import { router, type Href } from 'expo-router';
import { useState } from 'react';
import { View } from 'react-native';
import { Body, Button, DesktopContent, ErrorText, Eyebrow, Heading, Label, Panel, Screen, sharedStyles } from '../../components/bloom-ui';
import { requestAccountDeletion, requestAccountExport, type AccountExportResult } from '../../lib/account-controls';
import { useAuth } from '../../lib/auth';

export default function AccountScreen() {
  const { session, childProfile } = useAuth();
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [notice, setNotice] = useState<string | null>(null);
  const [exportSummary, setExportSummary] = useState<AccountExportResult | null>(null);
  const [confirmDelete, setConfirmDelete] = useState(false);

  async function handleExport() {
    setBusy(true);
    setError(null);
    setNotice(null);
    try {
      const result = await requestAccountExport();
      setExportSummary(result);
      setNotice('Your personal account export is ready. File links expire after 5 minutes.');
    } catch (caught) {
      setError(caught instanceof Error ? caught.message : 'Could not prepare your account export.');
    } finally {
      setBusy(false);
    }
  }

  async function handleDelete() {
    setBusy(true);
    setError(null);
    setNotice(null);
    try {
      const result = await requestAccountDeletion();
      setConfirmDelete(false);
      if (result.status === 'needs_family_review') {
        setNotice(result.message);
      } else {
        router.replace('/sign-in');
      }
    } catch (caught) {
      setError(caught instanceof Error ? caught.message : 'Could not delete your account.');
    } finally {
      setBusy(false);
    }
  }

  return <Screen safeAreaTop={false}>
    <DesktopContent>
      <View style={sharedStyles.column}>
        <Eyebrow>Profile</Eyebrow>
        <Heading>Account</Heading>
        <Body>Manage your account, privacy, and family spaces.</Body>
        <Button label="Back to profile" variant="tertiary" onPress={() => router.canGoBack() ? router.back() : router.replace('/profile' as Href)} />
      </View>
      <Panel>
        <Label>Account details</Label>
        <Body>{session?.user.email || 'No email address on this account.'}</Body>
        <Body>{childProfile ? 'Child profile' : 'Personal profile'}</Body>
      </Panel>
      <Panel>
        <Label>Privacy</Label>
        <Body>Manage your display name and whether others can find your profile.</Body>
        <Button label="Privacy settings" variant="secondary" onPress={() => router.push('/privacy' as Href)} />
      </Panel>
      {!childProfile && <Panel>
        <Label>Family Space</Label>
        <Body>Manage your family, profiles and permissions.</Body>
        <Button label="Open Family Space" variant="secondary" onPress={() => router.push('/family' as Href)} />
      </Panel>}
      <Panel>
        <Label>Profiles</Label>
        <Button label={childProfile ? 'Switch to parent' : 'Profile switching'} variant="secondary" onPress={() => router.push('/profile-switch' as Href)} />
      </Panel>
      {!childProfile && <Panel>
        <Label>Data export & account deletion</Label>
        <Body>Export your profile data and private files, or delete a personal account after a fresh sign-in. Active Family accounts route through a reviewed request so other family members and their wallets stay protected.</Body>
        <View style={sharedStyles.row}>
          <Button label="Export my data" variant="secondary" busy={busy} onPress={() => void handleExport()} />
          {!confirmDelete && <Button label="Delete account" variant="destructive" disabled={busy} onPress={() => setConfirmDelete(true)} />}
        </View>
        {exportSummary && <Body>Exported at {new Date(exportSummary.exported_at).toLocaleString()} · {exportSummary.files.length} private file link(s) generated.</Body>}
        {confirmDelete && <View style={sharedStyles.column}>
          <Body>Deleting a personal account revokes all sessions, removes private files, and clears your owned records. This cannot be undone.</Body>
          <Button label="Confirm account deletion" variant="destructive" busy={busy} onPress={() => void handleDelete()} />
          <Button label="Keep account" variant="secondary" disabled={busy} onPress={() => setConfirmDelete(false)} />
        </View>}
        {error && <ErrorText>{error}</ErrorText>}
        {notice && <Body>{notice}</Body>}
      </Panel>}
    </DesktopContent>
  </Screen>;
}
