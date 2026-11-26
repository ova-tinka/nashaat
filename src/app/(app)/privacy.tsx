import { router, useFocusEffect } from 'expo-router';
import { useCallback, useState } from 'react';
import { ActivityIndicator, Switch, View } from 'react-native';
import { Body, Button, DesktopContent, ErrorText, Eyebrow, Field, Heading, Label, Panel, Screen, sharedStyles } from '../../components/bloom-ui';
import { useAuth } from '../../lib/auth';
import { loadSocialProfile, saveSocialProfile } from '../../lib/competitions';
import { useBloomTheme } from '../../lib/theme-context';

export default function PrivacyScreen() {
  const { profileId, childProfile } = useAuth();
  const { theme } = useBloomTheme();
  const [name, setName] = useState('');
  const [searchable, setSearchable] = useState(false);
  const [parentOptIn, setParentOptIn] = useState(false);
  const [loading, setLoading] = useState(true);
  const [loaded, setLoaded] = useState(false);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [notice, setNotice] = useState<string | null>(null);
  const load = useCallback(async () => {
    if (!profileId) return;
    setLoading(true); setError(null);
    try {
      const social = await loadSocialProfile(profileId);
      setName(social?.display_name ?? ''); setSearchable(social?.searchable ?? false); setParentOptIn(social?.child_search_opt_in ?? false); setLoaded(true);
    } catch { setLoaded(false); setError('Could not load your privacy settings. Try again.'); }
    finally { setLoading(false); }
  }, [profileId]);
  useFocusEffect(useCallback(() => { void load(); }, [load]));
  async function save() {
    if (!name.trim()) { setError('Enter a display name.'); return; }
    setBusy(true); setError(null); setNotice(null);
    try { await saveSocialProfile(name, searchable); setNotice('Privacy settings saved.'); await load(); }
    catch { setError('Could not save your privacy settings. Check your connection and permissions.'); }
    finally { setBusy(false); }
  }
  return <Screen safeAreaTop={false}>
    <DesktopContent maxWidth={760}>
    <View style={sharedStyles.column}><Eyebrow>Account</Eyebrow><Heading>Privacy</Heading><Body>Choose how others can find your profile.</Body><Button label="Back to account" variant="tertiary" onPress={() => router.back()} /></View>
    {loading && <ActivityIndicator color={theme.colors.action} />}
    {error && <ErrorText>{error}</ErrorText>}{notice && <Body>{notice}</Body>}
    {!loading && loaded && <Panel><Label>Display name and search</Label><Body>Your display name appears in competition results. Search is optional.{childProfile ? ' A parent must also allow search before you appear in results.' : ''}</Body>
      <Field label="Display name" value={name} onChangeText={setName} maxLength={60} editable={!busy} />
      <View style={sharedStyles.row}><View style={sharedStyles.grow}><Label>Allow people to find me</Label><Body>{searchable ? 'Your profile can appear in search when permitted.' : 'Your profile is hidden from people search.'}</Body></View><Switch accessibilityLabel="Allow people to find me" value={searchable} onValueChange={setSearchable} disabled={busy} /></View>
      {childProfile && <Body>Parent search permission: {parentOptIn ? 'enabled' : 'not enabled'}.</Body>}
      <Button label="Save privacy settings" onPress={() => void save()} disabled={busy || !name.trim()} busy={busy} />
    </Panel>}
    {error && !loading && <Button label="Retry" variant="secondary" onPress={() => void load()} />}
    </DesktopContent>
  </Screen>;
}
