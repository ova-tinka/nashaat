import { router, useFocusEffect, useLocalSearchParams } from 'expo-router';
import { useCallback, useState } from 'react';
import { ActivityIndicator, Switch, View } from 'react-native';
import { Body, Button, ErrorText, Eyebrow, Heading, Label, Panel, Screen, sharedStyles } from '../../components/bloom-ui';
import { approveChildCompetition, loadChildCompetitions, setChildSearch } from '../../lib/competitions';
import { colors } from '../../theme';

export default function ChildCompetitionsScreen() {
  const { childId, name } = useLocalSearchParams<{ childId: string; name?: string }>();
  const [data, setData] = useState<Awaited<ReturnType<typeof loadChildCompetitions>> | null>(null);
  const [loading, setLoading] = useState(true);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [notice, setNotice] = useState<string | null>(null);
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
  return <Screen>
    <View style={sharedStyles.column}><Eyebrow>Family competitions</Eyebrow><Heading>{name || 'Child competitions'}</Heading><Body>Review participation requests and control search visibility.</Body></View>
    <Button label="Back" secondary onPress={() => router.back()} disabled={busy} />
    {loading && <ActivityIndicator color={colors.accent} />}{error && <ErrorText>{error}</ErrorText>}{notice && <Body>{notice}</Body>}
    {data && <>
      <Panel><Label>Search visibility</Label><Body>Your child must also choose to be searchable. Results in approved events use their display name.</Body>
        <View style={sharedStyles.row}><Body>Allow this child to appear in search</Body><Switch accessibilityLabel="Allow child search visibility" value={data.social?.child_search_opt_in ?? false} disabled={busy} onValueChange={(value) => void run(() => setChildSearch(childId, value), 'Search permission saved.')} /></View>
      </Panel>
      <Label>Requests awaiting your approval</Label>
      {data.requests.length === 0 && <Panel><Body>No pending requests.</Body></Panel>}
      {data.requests.map(({ competition_id, competition }) => <Panel key={competition_id}>
        <Label>{competition?.title ?? 'Competition'}</Label>
        {competition && <Body>{competition.visibility} · {competition.metric === 'minutes' ? 'active workout minutes' : 'completed workouts'} · {new Date(competition.starts_at).toLocaleString()} – {new Date(competition.ends_at).toLocaleString()}</Body>}
        <Body>Results use display names and self-reported workouts. Participation begins when you approve it.</Body>
        <Button label="Approve participation" onPress={() => void run(() => approveChildCompetition(competition_id, childId, true), 'Participation approved.')} busy={busy} />
        <Button label="Decline participation" secondary onPress={() => void run(() => approveChildCompetition(competition_id, childId, false), 'Participation declined.')} disabled={busy} />
      </Panel>)}
    </>}
  </Screen>;
}
