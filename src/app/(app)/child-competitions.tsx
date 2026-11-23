import { getAppLocale } from '../../lib/locale-context';
import { router, useFocusEffect, useLocalSearchParams } from 'expo-router';
import { useCallback, useState } from 'react';
import { ActivityIndicator, View } from 'react-native';
import { Body, Button, ErrorText, Eyebrow, Heading, Label, Panel, Screen, sharedStyles } from '../../components/bloom-ui';
import { approveChildCompetition, loadChildCompetitions, setChildSearch } from '../../lib/competitions';
import { useBloomTheme } from '../../lib/theme-context';

export default function ChildCompetitionsScreen() {
  const { theme } = useBloomTheme();
  const { childId, name } = useLocalSearchParams<{ childId: string; name?: string }>();
  const [data, setData] = useState<Awaited<ReturnType<typeof loadChildCompetitions>> | null>(null);
  const [loading, setLoading] = useState(true);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [notice, setNotice] = useState<string | null>(null);
  const [pendingDecision, setPendingDecision] = useState<{ competitionId: string; approve: boolean } | null>(null);
  const [pendingSearchConsent, setPendingSearchConsent] = useState<boolean | null>(null);
  const load = useCallback(async () => {
    try { setData(await loadChildCompetitions(childId)); setError(null); }
    catch { setError('Could not load competition permissions. Check the family connection.'); }
    finally { setLoading(false); }
  }, [childId]);
  useFocusEffect(useCallback(() => { void load(); }, [load]));
  async function run(action: () => Promise<void>, success: string) {
    setBusy(true); setError(null); setNotice(null);
    try { await action(); await load(); setNotice(success); }
    catch { setError('Could not save this change. The event may have ended or the request may have changed.'); }
    finally { setBusy(false); }
  }
  return <Screen safeAreaTop={false}>
    <View style={sharedStyles.column}><Eyebrow>Family competitions</Eyebrow><Heading>{name || 'Child competitions'}</Heading><Body>Review participation requests and control search visibility.</Body></View>
    <Button label="Back" secondary onPress={() => router.back()} disabled={busy} />
    {loading && <ActivityIndicator color={theme.colors.action} />}{error && <ErrorText>{error}</ErrorText>}{notice && <Body>{notice}</Body>}
    {data && <>
      <Panel><Label>Search visibility</Label><Body>Your child must also choose to be searchable. Results in approved events use their display name.</Body>
        <View style={sharedStyles.column}><Body>Child search permission: {data.social?.child_search_opt_in ? 'Allowed' : 'Off'}</Body>
          {pendingSearchConsent === null ? <Button label={data.social?.child_search_opt_in ? 'Review turning search off' : 'Review allowing search'} variant="secondary" onPress={() => setPendingSearchConsent(!data.social?.child_search_opt_in)} disabled={busy} /> : <View style={sharedStyles.column}>
            <Body>Confirm {pendingSearchConsent ? 'allowing' : 'turning off'} competition search for {name || 'this child'}? Their display name may appear only if the child also opts in.</Body>
            <Button label={`Confirm search ${pendingSearchConsent ? 'permission' : 'off'}`} onPress={() => { const enabled = pendingSearchConsent; setPendingSearchConsent(null); void run(() => setChildSearch(childId, enabled), 'Search permission saved.'); }} busy={busy} />
            <Button label="Cancel" variant="tertiary" onPress={() => setPendingSearchConsent(null)} disabled={busy} />
          </View>}
        </View>
      </Panel>
      <Label>Requests awaiting your approval</Label>
      {data.requests.length === 0 && <Panel><Body>No pending requests.</Body></Panel>}
      {data.requests.map(({ competition_id, competition }) => <Panel key={competition_id}>
        <Label>{competition?.title ?? 'Competition'}</Label>
        {competition && <Body>{competition.visibility} · {competition.metric === 'minutes' ? 'active workout minutes' : 'completed workouts'} · {new Date(competition.starts_at).toLocaleString(getAppLocale())} – {new Date(competition.ends_at).toLocaleString(getAppLocale())}</Body>}
        <Body>Results use display names and self-reported workouts. Participation begins when you approve it.</Body>
        {pendingDecision?.competitionId === competition_id ? <>
          <Body>Confirm you want to {pendingDecision.approve ? 'approve' : 'decline'} {name || 'this child'}’s participation in {competition?.title ?? 'this competition'}? The server records the decision.</Body>
          <Button label={`Confirm ${pendingDecision.approve ? 'approval' : 'decline'}`} onPress={() => { const approve = pendingDecision.approve; setPendingDecision(null); void run(() => approveChildCompetition(competition_id, childId, approve), approve ? 'Participation approved.' : 'Participation declined.'); }} busy={busy} />
          <Button label="Cancel" variant="secondary" onPress={() => setPendingDecision(null)} disabled={busy} />
        </> : <>
          <Button label="Review approval" onPress={() => setPendingDecision({ competitionId: competition_id, approve: true })} busy={busy} />
          <Button label="Review decline" variant="secondary" onPress={() => setPendingDecision({ competitionId: competition_id, approve: false })} disabled={busy} />
        </>}
      </Panel>)}
    </>}
  </Screen>;
}
