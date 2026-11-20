import { router, useFocusEffect, useLocalSearchParams } from 'expo-router';
import { useCallback, useState } from 'react';
import { ActivityIndicator, Switch, View } from 'react-native';
import { Body, Button, ErrorText, Eyebrow, Heading, Label, Panel, Screen, sharedStyles } from '../../components/bloom-ui';
import { CoachProposalCard } from '../../components/coach-proposal';
import { loadCatalog, type Exercise } from '../../lib/bloom';
import { decideCoachProposal, loadChildCoaching, setChildCoaching, type ChildCoachStatus, type CoachProposal } from '../../lib/coach';
import { useBloomTheme } from '../../lib/theme-context';

export default function ChildCoachingScreen() {
  const { theme } = useBloomTheme();
  const { childId, name } = useLocalSearchParams<{ childId: string; name?: string }>();
  const [status, setStatus] = useState<ChildCoachStatus | null>(null);
  const [proposals, setProposals] = useState<CoachProposal[]>([]);
  const [catalog, setCatalog] = useState<Exercise[]>([]);
  const [eligible, setEligible] = useState(false);
  const [consent, setConsent] = useState(false);
  const [confirmEnable, setConfirmEnable] = useState(false);
  const [confirmDisable, setConfirmDisable] = useState(false);
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
  return <Screen safeAreaTop={false}>
    <View style={sharedStyles.column}><Eyebrow>Family coaching</Eyebrow><Heading>{name || 'Child coaching'}</Heading><Body>Review workout proposals and manage coaching permission. The child’s full conversation remains private.</Body></View>
    <Button label="Back" secondary onPress={() => router.back()} disabled={busy} />
    {loading && <ActivityIndicator color={theme.colors.action} />}{error && <ErrorText>{error}</ErrorText>}{notice && <Body>{notice}</Body>}
    {status && <Panel>
      <Label>Coaching {status.enabled ? 'enabled' : 'disabled'}</Label>
      <Body>When coaching is used, the child’s messages, goals, experience, equipment, plans, and recent workouts are sent to Fireworks AI. The child must also agree to sharing. Coaching may remain unavailable until the provider is approved.</Body>
      {!status.enabled && <>
        <View style={sharedStyles.row}><Body>I confirm the child is at least 13 and meets the applicable digital-consent age.</Body><Switch accessibilityLabel="Confirm child age eligibility" value={eligible} onValueChange={(value) => { setEligible(value); setConfirmEnable(false); }} disabled={busy} /></View>
        <View style={sharedStyles.row}><Body>I consent to this data sharing for the child.</Body><Switch accessibilityLabel="Parent consent to coaching data sharing" value={consent} onValueChange={(value) => { setConsent(value); setConfirmEnable(false); }} disabled={busy} /></View>
        {!confirmEnable
          ? <Button label="Review enabling child coaching" secondary onPress={() => setConfirmEnable(true)} busy={busy} disabled={!eligible || !consent} />
          : <View style={sharedStyles.column}>
            <Body>Confirm enabling coaching for {name || 'this child'}. If used, coaching sends the child’s messages, goals, experience, equipment, workout plans, and recent workouts to Fireworks AI. The child must separately agree before use.</Body>
            <Button label="Confirm coaching permission" onPress={() => { setConfirmEnable(false); void run(() => setChildCoaching(childId, true, eligible, consent), 'Coaching permission saved.'); }} busy={busy} />
            <Button label="Keep coaching off" secondary onPress={() => setConfirmEnable(false)} disabled={busy} />
          </View>}
      </>}
      {status.enabled && (confirmDisable ? <>
        <Body>Confirm disabling future coaching requests for {name || 'this child'} and withdrawing parent consent. The server saves the updated permission.</Body>
        <Button label="Confirm disable coaching" variant="destructive" onPress={() => { setConfirmDisable(false); void run(() => setChildCoaching(childId, false, false, false), 'Coaching permission withdrawn.'); }} busy={busy} />
        <Button label="Keep coaching enabled" variant="secondary" onPress={() => setConfirmDisable(false)} disabled={busy} />
      </> : <Button label="Review disabling child coaching" variant="secondary" onPress={() => setConfirmDisable(true)} busy={busy} />)}
    </Panel>}
    {proposals.length > 0 && <><Label>Workout proposals</Label>{proposals.map((proposal) => <CoachProposalCard key={proposal.id} proposal={proposal} catalog={catalog} canApprove busy={busy} requireConfirmation subjectLabel={name || 'this child'} onDecision={(approve) => void run(() => decideCoachProposal(proposal.id, approve), approve ? 'Workout plan saved.' : 'Proposal rejected.')} />)}</>}
  </Screen>;
}
