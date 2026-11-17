import { router, useLocalSearchParams, type Href } from 'expo-router';
import { useEffect, useState } from 'react';
import { ActivityIndicator, View } from 'react-native';
import { Body, Button, ErrorText, Eyebrow, Field, Heading, Label, Panel, Screen, sharedStyles } from '../components/bloom-ui';
import { useAuth } from '../lib/auth';
import { acceptCompetitionLink, loadSocialProfile, saveSocialProfile, type SocialProfile } from '../lib/competitions';
import { colors } from '../theme';

export default function CompetitionInviteScreen() {
  const { code } = useLocalSearchParams<{ code?: string }>();
  const { session, loading, profileId, profileLoading, profileError, childProfile } = useAuth();
  const [socialState, setSocialState] = useState<{ profileId: string; value: SocialProfile | null } | null>(null);
  const [name, setName] = useState('');
  const [busy, setBusy] = useState(false);
  const [joined, setJoined] = useState(false);
  const [error, setError] = useState<string | null>(null);
  useEffect(() => {
    let active = true;
    if (profileId) void loadSocialProfile(profileId).then((value) => { if (active) setSocialState({ profileId, value }); }).catch(() => { if (active) setError('Could not load your display name.'); });
    return () => { active = false; };
  }, [profileId]);
  const social = socialState?.profileId === profileId ? socialState.value : undefined;
  async function accept() {
    if (!code || !/^[0-9a-f]{64}$/i.test(code)) { setError('This invitation link is invalid.'); return; }
    if (social === undefined) { setError('Your display name is still loading.'); return; }
    if (social === null && !name.trim()) { setError('Choose a display name to join.'); return; }
    setBusy(true); setError(null);
    try {
      if (social === null) await saveSocialProfile(name, false);
      await acceptCompetitionLink(code); setJoined(true);
    } catch { setError('Could not accept the invitation. It may have expired or the event may be full.'); }
    finally { setBusy(false); }
  }
  return <Screen>
    <View style={sharedStyles.column}><Eyebrow>Competition invitation</Eyebrow><Heading>Move together</Heading><Body>Results use display names and self-reported workouts.</Body></View>
    {(loading || profileLoading) && <ActivityIndicator color={colors.accent} />}
    {profileError && <ErrorText>{profileError}</ErrorText>}{error && <ErrorText>{error}</ErrorText>}
    {!loading && !session && <Panel><Label>Sign in first</Label><Body>After signing in, open the invitation link again.</Body><Button label="Sign in" onPress={() => router.replace('/sign-in')} /></Panel>}
    {session && !profileLoading && profileId && !joined && <Panel><Label>Join competition</Label>
      {social === null && <Field label="Display name" value={name} onChangeText={setName} maxLength={60} />}
      {childProfile && <Body>Your parent must approve your participation.</Body>}
      <Button label="Accept invitation" onPress={() => void accept()} busy={busy} disabled={social === undefined} />
    </Panel>}
    {joined && <Panel><Label>{childProfile ? 'Waiting for parent approval' : 'Invitation accepted'}</Label><Button label="View competitions" onPress={() => router.replace('/competitions' as Href)} /></Panel>}
  </Screen>;
}
