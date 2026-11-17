import { router, useFocusEffect, useLocalSearchParams } from 'expo-router';
import { useCallback, useState } from 'react';
import { ActivityIndicator, Switch, View } from 'react-native';
import { Body, Button, ErrorText, Eyebrow, Heading, Label, Panel, Screen, sharedStyles } from '../../components/bloom-ui';
import { CoachProposalCard } from '../../components/coach-proposal';
import { loadCatalog, type Exercise } from '../../lib/bloom';
import { decideCoachProposal, loadChildCoaching, setChildCoaching, type ChildCoachStatus, type CoachProposal } from '../../lib/coach';
import { colors } from '../../theme';

export default function ChildCoachingScreen() {
  const { childId, name } = useLocalSearchParams<{ childId: string; name?: string }>();
  const [status, setStatus] = useState<ChildCoachStatus | null>(null);
  const [proposals, setProposals] = useState<CoachProposal[]>([]);
  const [catalog, setCatalog] = useState<Exercise[]>([]);
  const [eligible, setEligible] = useState(false);
  const [consent, setConsent] = useState(false);
  const [busy, setBusy] = useState(false);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [notice, setNotice] = useState<string | null>(null);
  const load = useCallback(async () => {
    try {
      const [data, items] = await Promise.all([loadChildCoaching(childId), loadCatalog(childId)]);
      setStatus(data.status); setProposals(data.proposals); setCatalog(items); setEligible(data.status.eligible); setConsent(data.status.parent_consent); setError(null);
    } catch { setError('Could not load child coaching. Check the family connection and try again.'); }
    finally { setLoading(false); }
  }, [childId]);
  useFocusEffect(useCallback(() => { void load(); }, [load]));
  async function run(action: () => Promise<void>, success: string) {
    setBusy(true); setError(null); setNotice(null);
    try { await action(); await load(); setNotice(success); }
    catch { setError('Could not save this change. The plan may have changed or permission may have been withdrawn.'); }
    finally { setBusy(false); }
  }
  return <Screen>
    <View style={sharedStyles.column}><Eyebrow>Family coaching</Eyebrow><Heading>{name || 'Child coaching'}</Heading><Body>Review workout proposals and manage coaching permission. The child’s full conversation remains private.</Body></View>
    <Button label="Back" secondary onPress={() => router.back()} disabled={busy} />
    {loading && <ActivityIndicator color={colors.accent} />}{error && <ErrorText>{error}</ErrorText>}{notice && <Body>{notice}</Body>}
    {status && <Panel>
      <Label>Coaching {status.enabled ? 'enabled' : 'disabled'}</Label>
      <Body>When coaching is used, the child’s messages, goals, experience, equipment, plans, and recent workouts are sent to Fireworks AI. The child must also agree to sharing. Coaching may remain unavailable until the provider is approved.</Body>
      {!status.enabled && <>
        <View style={sharedStyles.row}><Body>I confirm the child is at least 13 and meets the applicable digital-consent age.</Body><Switch accessibilityLabel="Confirm child age eligibility" value={eligible} onValueChange={setEligible} disabled={busy} /></View>
        <View style={sharedStyles.row}><Body>I consent to this data sharing for the child.</Body><Switch accessibilityLabel="Parent consent to coaching data sharing" value={consent} onValueChange={setConsent} disabled={busy} /></View>
        <Button label="Enable child coaching" onPress={() => void run(() => setChildCoaching(childId, true, eligible, consent), 'Coaching permission saved.')} busy={busy} disabled={!eligible || !consent} />
      </>}
      {status.enabled && <Button label="Disable child coaching" secondary onPress={() => void run(() => setChildCoaching(childId, false, false, false), 'Coaching permission withdrawn.')} busy={busy} />}
    </Panel>}
    {proposals.length > 0 && <><Label>Workout proposals</Label>{proposals.map((proposal) => <CoachProposalCard key={proposal.id} proposal={proposal} catalog={catalog} canApprove busy={busy} onDecision={(approve) => void run(() => decideCoachProposal(proposal.id, approve), approve ? 'Workout plan saved.' : 'Proposal rejected.')} />)}</>}
  </Screen>;
}
