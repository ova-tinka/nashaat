import { router, type Href } from 'expo-router';
import { useState } from 'react';
import { Linking, Platform, Share, View } from 'react-native';
import { Body, Button, DesktopContent, ErrorText, Eyebrow, Heading, Label, Panel, Screen, sharedStyles } from '../../components/bloom-ui';
import { requestAccountDeletion, requestAccountExport, type AccountExportResult } from '../../lib/account-controls';
import { resetAnalytics, trackEvent } from '../../lib/analytics';
import { useAuth } from '../../lib/auth';
import { clearStoreBilling } from '../../lib/store-billing';

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
      void trackEvent('account_deletion_requested');
      const result = await requestAccountDeletion();
      setConfirmDelete(false);
      if (result.status === 'needs_family_review') {
        setNotice(result.message);
      } else {
        await clearStoreBilling().catch(() => undefined);
        resetAnalytics();
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
        {exportSummary && <View style={sharedStyles.column}>
          <Body>Exported at {new Date(exportSummary.exported_at).toLocaleString()} · {exportSummary.files.length} private file link(s) generated.</Body>
          <Button label="Save / share export JSON" variant="secondary" onPress={() => {
            const serialized = JSON.stringify(exportSummary, null, 2);
            if (Platform.OS === 'web' && typeof document !== 'undefined' && typeof Blob !== 'undefined') {
              const blob = new Blob([serialized], { type: 'application/json' });
              const url = URL.createObjectURL(blob);
              const link = document.createElement('a');
              link.href = url;
              link.download = `bloom-export-${exportSummary.exported_at.slice(0, 10)}.json`;
              link.click();
              setTimeout(() => URL.revokeObjectURL(url), 1000);
            } else {
              void Share.share({ message: serialized, title: 'Bloom personal export' }).catch(() => undefined);
            }
          }} />
          {exportSummary.files.map((file, index) => <Button key={`${file.storage_path}:${index}`} label={`Open file: ${file.storage_path.split('/').pop() ?? `File ${index + 1}`}`} variant="tertiary" onPress={() => void Linking.openURL(file.download_url)} />)}
        </View>}
        {confirmDelete && <View style={sharedStyles.column}>
          <Body>Deleting a personal account revokes all sessions, removes private files, and clears your owned records. This cannot be undone.</Body>
          <Body>Important: Deleting your Bloom account does not automatically cancel an active Apple App Store or Google Play subscription. Cancel any active store subscription separately so you are not billed again.</Body>
          <Button label="Manage subscriptions first" variant="tertiary" disabled={busy} onPress={() => router.push('/subscription' as Href)} />
          <Button label="Confirm account deletion" variant="destructive" busy={busy} onPress={() => void handleDelete()} />
          <Button label="Keep account" variant="secondary" disabled={busy} onPress={() => setConfirmDelete(false)} />
        </View>}
        <Button label="Privacy Policy, Terms & Support" variant="tertiary" onPress={() => router.push('/legal' as Href)} />
        {error && <ErrorText>{error}</ErrorText>}
        {notice && <Body>{notice}</Body>}
      </Panel>}
    </DesktopContent>
  </Screen>;
}
