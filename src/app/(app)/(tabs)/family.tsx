import { randomUUID } from 'expo-crypto';
import { router, useFocusEffect, type Href } from 'expo-router';
import { useCallback, useRef, useState } from 'react';
import { ActivityIndicator, StyleSheet, Text, View } from 'react-native';
import { Body, Button, ErrorText, Eyebrow, Field, Heading, Label, Panel, Screen, sharedStyles, useIsDesktopLayout } from '../../../components/bloom-ui';
import { useAuth } from '../../../lib/auth';
import { createChildAccountLink, createChildInvite, createFamily, createManagedChildProfile, deleteUnpairedChildProfile, joinFamily, leaveOrRemoveChild, loadFamilies, loadFamilyChildSummary, prepareChildPairing, type Family } from '../../../lib/family';
import { moduleManifest } from '../../../lib/module-manifest';
import { useBloomTheme } from '../../../lib/theme-context';

type FamilyChildSummary = Awaited<ReturnType<typeof loadFamilyChildSummary>>;
type FamilyChildSummaryState = { summary: FamilyChildSummary | null; loading: boolean; error: boolean };

export default function FamilyScreen() {
  const { profileId, refreshProfile } = useAuth();
  const { theme } = useBloomTheme();
  const desktop = useIsDesktopLayout();
  const [families, setFamilies] = useState<Family[]>([]);
  const [familiesProfileId, setFamiliesProfileId] = useState<string | null>(null);
  const [childSummaries, setChildSummaries] = useState<Record<string, FamilyChildSummaryState>>({});
  const summaryRequest = useRef(0);
  const [name, setName] = useState('');
  const [code, setCode] = useState('');
  const [confirmJoin, setConfirmJoin] = useState(false);
  const [invite, setInvite] = useState<{ familyId: string; code: string } | null>(null);
  const [confirmRemoval, setConfirmRemoval] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [newChild, setNewChild] = useState<{ familyId: string; name: string; requestId: string; submitted: boolean } | null>(null);
  const [confirmProfileRemoval, setConfirmProfileRemoval] = useState<string | null>(null);
  const [pendingAccessCode, setPendingAccessCode] = useState<{ type: 'pair' | 'link' | 'invite'; familyId?: string; profileId?: string; displayName: string } | null>(null);
  const [pairing, setPairing] = useState<{ profileId: string; code: string } | null>(null);
  const [accountLink, setAccountLink] = useState<{ profileId: string; code: string } | null>(null);

  const load = useCallback(async () => {
    const request = ++summaryRequest.current;
    if (!profileId) {
      setFamilies([]);
      setFamiliesProfileId(null);
      setChildSummaries({});
      setLoading(false);
      return;
    }
    try {
      const nextFamilies = await loadFamilies();
      if (request !== summaryRequest.current) return;
      setFamilies(nextFamilies);
      setFamiliesProfileId(profileId);
      setError(null);
      const children = [...new Map(nextFamilies.flatMap((family) => family.members
        .filter((member) => member.role === 'child')
        .map((member) => [member.user_id, member] as const))).values()];
      setChildSummaries(Object.fromEntries(children.map((child) => [child.user_id, { summary: null, loading: true, error: false }])));
      void Promise.all(children.map(async (child) => {
        try { return [child.user_id, { summary: await loadFamilyChildSummary(child.user_id), loading: false, error: false }] as const; }
        catch { return [child.user_id, { summary: null, loading: false, error: true }] as const; }
      })).then((results) => {
        if (request === summaryRequest.current) setChildSummaries(Object.fromEntries(results));
      });
    }
    catch { if (request === summaryRequest.current) setError('Could not load your family connections.'); }
    finally { if (request === summaryRequest.current) setLoading(false); }
  }, [profileId]);
  useFocusEffect(useCallback(() => {
    void load();
    return () => { summaryRequest.current += 1; };
  }, [load]));
  const visibleFamilies = familiesProfileId === profileId ? families : [];

  async function create() {
    setBusy(true); setError(null);
    try { await createFamily(name); setName(''); await load(); }
    catch { setError('Could not create the family. Check the name and try again.'); }
    finally { setBusy(false); }
  }
  async function join() {
    if (!confirmJoin || !code.trim()) return;
    setBusy(true); setError(null);
    try { await joinFamily(code); setCode(''); setConfirmJoin(false); await load(); await refreshProfile(); }
    catch { setError('Could not join. Check the invitation code and try again.'); }
    finally { setBusy(false); }
  }
  async function inviteChild(familyId: string) {
    setBusy(true); setError(null);
    try { setInvite({ familyId, code: await createChildInvite(familyId) }); }
    catch { setError('Could not create an invitation.'); }
    finally { setBusy(false); }
  }
  async function remove(familyId: string, childId: string) {
    setBusy(true); setError(null);
    try { await leaveOrRemoveChild(familyId, childId); setConfirmRemoval(null); setInvite(null); await load(); }
    catch { setError('Could not update the family connection.'); }
    finally { setBusy(false); }
  }
  async function createChild() {
    if (!newChild || !newChild.name.trim()) return;
    setBusy(true); setError(null); setNewChild({ ...newChild, submitted: true });
    try { await createManagedChildProfile(newChild.familyId, newChild.name, newChild.requestId); setNewChild(null); await load(); }
    catch { setError('Could not confirm that the child profile was saved. Retry to avoid creating a duplicate.'); }
    finally { setBusy(false); }
  }
  async function removeChildProfile(profileId: string) {
    setBusy(true); setError(null);
    try { await deleteUnpairedChildProfile(profileId); setConfirmProfileRemoval(null); await load(); }
    catch { setError('Could not remove this profile. Refresh the family list and try again.'); }
    finally { setBusy(false); }
  }
  async function pairChild(profileId: string) {
    setBusy(true); setError(null); setPairing(null);
    try { setPairing({ profileId, code: await prepareChildPairing(profileId) }); await load(); }
    catch { setError('Could not prepare pairing. Check your connection and try again.'); }
    finally { setBusy(false); }
  }
  async function linkChildAccount(profileId: string) {
    setBusy(true); setError(null); setAccountLink(null);
    try { setAccountLink({ profileId, code: await createChildAccountLink(profileId) }); }
    catch { setError('Could not create an account link code. Try again.'); }
    finally { setBusy(false); }
  }
  async function createAccessCode() {
    if (!pendingAccessCode) return;
    const action = pendingAccessCode;
    setPendingAccessCode(null);
    if (action.type === 'pair' && action.profileId) await pairChild(action.profileId);
    else if (action.type === 'link' && action.profileId) await linkChildAccount(action.profileId);
    else if (action.type === 'invite' && action.familyId) await inviteChild(action.familyId);
  }

  return <Screen safeAreaTop={false}>
    <View style={sharedStyles.column}><Eyebrow>Family Space · Optional</Eyebrow><Heading>Family connections</Heading><Body>Connect an account or create a child profile. Your My Space stays separate.</Body></View>
    {loading && <ActivityIndicator color={theme.colors.action} />}
    {error && <ErrorText>{error}</ErrorText>}
    {!loading && visibleFamilies.map((family) => {
      const myRole = family.members.find((member) => member.user_id === profileId)?.role;
      const linkedChildren = family.members.filter((member) => member.role === 'child');
      const pendingApprovals = linkedChildren.reduce((count, child) => {
        const summary = childSummaries[child.user_id]?.summary;
        return count + (summary?.pendingCoaching ?? 0) + (summary?.pendingCompetitions ?? 0);
      }, 0);
      const summariesLoading = linkedChildren.some((child) => childSummaries[child.user_id]?.loading);
      const summariesError = linkedChildren.some((child) => childSummaries[child.user_id]?.error);
      const recentActivity = linkedChildren.flatMap((child) => (childSummaries[child.user_id]?.summary?.analytics.history ?? [])
        .map((activity) => ({ ...activity, childName: child.display_name })))
        .sort((left, right) => Date.parse(right.completed_at) - Date.parse(left.completed_at)).slice(0, 5);
      return <Panel key={family.id}>
        <Label>{family.name}</Label>
        {myRole === 'parent' && <View style={[styles.summary, { backgroundColor: theme.colors.surfaceSoft, borderColor: theme.colors.border }]}>
          <Eyebrow>Family overview</Eyebrow>
          <Label>{linkedChildren.length} connected {linkedChildren.length === 1 ? 'child' : 'children'}</Label>
          <Body>{summariesLoading ? 'Checking family requests…' : summariesError
            ? pendingApprovals ? `${pendingApprovals} requests await review; some could not be checked.` : 'Some requests could not be checked. Review each child below.'
            : pendingApprovals ? `${pendingApprovals} coaching and event requests await review` : 'No requests await review'}</Body>
          {recentActivity.length > 0 && <>
            <Eyebrow>Recent Exercise</Eyebrow>
            {recentActivity.slice(0, 2).map((activity) => <Body key={`${activity.id}:${activity.childName}`}>
              {activity.childName} · {activity.plan_title} · {new Date(activity.completed_at).toLocaleDateString()}
            </Body>)}
          </>}
          {recentActivity.length > 0 && summariesError && <Body>Some children’s activity could not be loaded.</Body>}
        </View>}
        {family.members.map((member) => {
          if (family.childProfiles.some((child) => child.profile_id === member.user_id)) return null;
          const isSelf = member.user_id === profileId;
          const canRemove = member.role === 'child' && myRole === 'parent' && !isSelf;
          const removalKey = `${family.id}:${member.user_id}`;
          return <View key={member.user_id} style={sharedStyles.column}>
            <Body>{member.display_name} · {member.role}{isSelf ? ' · you' : ''}</Body>
            {myRole === 'parent' && member.role === 'child' && <FamilyChildOverview childId={member.user_id} name={member.display_name} state={childSummaries[member.user_id]} />}
            {myRole === 'parent' && member.role === 'child' && <Button label={`Manage ${member.display_name}`} secondary onPress={() => router.push({ pathname: '/family-child', params: { childId: member.user_id, name: member.display_name } } as unknown as Href)} />}
            {canRemove && (confirmRemoval === removalKey
              ? <><Body>{`Remove ${member.display_name} from this family?`}</Body><Button label="Confirm removal" secondary onPress={() => void remove(family.id, member.user_id)} busy={busy} /><Button label="Keep connection" secondary onPress={() => setConfirmRemoval(null)} disabled={busy} /></>
              : <Button label={`Remove ${member.display_name}`} secondary onPress={() => setConfirmRemoval(removalKey)} disabled={busy} />)}
          </View>;
        })}
        {myRole === 'parent' && <View style={[styles.childGrid, desktop && styles.desktopChildGrid]}>{family.childProfiles.map((child) => <View key={child.profile_id} style={[sharedStyles.column, styles.childCard, { borderColor: theme.colors.border }, desktop && styles.desktopChildCard]}>
          <Body>{child.display_name} · child profile</Body>
          {family.members.some((member) => member.user_id === child.profile_id && member.role === 'child')
            ? <FamilyChildOverview childId={child.profile_id} name={child.display_name} state={childSummaries[child.profile_id]} />
            : <Body>No child account is connected yet. Module access stays off until the profile is connected and assigned.</Body>}
          <Body>Generate a code to sign this child in on a device. The code expires in 10 minutes and can be used once.</Body>
          {pendingAccessCode?.profileId === child.profile_id && pendingAccessCode.type === 'pair' ? <><Body>Create a one-use, 10-minute pairing code for {pendingAccessCode.displayName}? Anyone with this code can pair a device to the child profile.</Body><Button label="Confirm pairing code" onPress={() => void createAccessCode()} busy={busy} /><Button label="Cancel" secondary onPress={() => setPendingAccessCode(null)} disabled={busy} /></> : <Button label={`Review pairing for ${child.display_name}`} secondary onPress={() => setPendingAccessCode({ type: 'pair', profileId: child.profile_id, displayName: child.display_name })} busy={busy} />}
          {family.members.some((member) => member.user_id === child.profile_id) && <Button label={`Manage ${child.display_name}`} secondary onPress={() => router.push({ pathname: '/family-child', params: { childId: child.profile_id, name: child.display_name } } as unknown as Href)} />}
          {family.members.some((member) => member.user_id === child.profile_id) && (pendingAccessCode?.profileId === child.profile_id && pendingAccessCode.type === 'link' ? <><Body>Create a one-use email-link code for {pendingAccessCode.displayName}? Anyone with the code can link a new sign-in to this child profile for 24 hours.</Body><Button label="Confirm account-link code" onPress={() => void createAccessCode()} busy={busy} /><Button label="Cancel" secondary onPress={() => setPendingAccessCode(null)} disabled={busy} /></> : <Button label={`Review email link for ${child.display_name}`} secondary onPress={() => setPendingAccessCode({ type: 'link', profileId: child.profile_id, displayName: child.display_name })} busy={busy} />)}
          {pairing?.profileId === child.profile_id && <><Body>On the child device, sign out of any parent account, choose “Pair child device,” and enter this code.</Body><Text selectable style={[styles.code, { color: theme.colors.ink }]}>{pairing.code}</Text></>}
          {accountLink?.profileId === child.profile_id && <><Body>Give this one-use code to your child. On the sign-in screen, choose “Link child email account” and create a new account. The code expires in 24 hours.</Body><Text selectable style={[styles.code, { color: theme.colors.ink }]}>{accountLink.code}</Text></>}
          {!family.members.some((member) => member.user_id === child.profile_id) && (confirmProfileRemoval === child.profile_id ? <>
            <Body>Remove this unpaired profile?</Body>
            <Button label="Remove profile" secondary onPress={() => void removeChildProfile(child.profile_id)} busy={busy} />
            <Button label="Keep profile" secondary onPress={() => setConfirmProfileRemoval(null)} disabled={busy} />
          </> : <Button label={`Remove ${child.display_name}'s profile`} secondary onPress={() => setConfirmProfileRemoval(child.profile_id)} disabled={busy} />)}
        </View>)}</View>}
        {myRole === 'parent' && (newChild?.familyId === family.id ? <View style={sharedStyles.column}>
          <Field label="Child's display name" value={newChild.name} onChangeText={(value) => setNewChild({ ...newChild, name: value })} maxLength={100} editable={!busy && !newChild.submitted} />
          <Button label={newChild.submitted ? 'Retry saving profile' : 'Save child profile'} onPress={() => void createChild()} busy={busy} disabled={!newChild.name.trim()} />
          <Button label="Cancel" secondary onPress={() => { setNewChild(null); void load(); }} disabled={busy} />
        </View> : <Button label="Create child profile" secondary onPress={() => setNewChild({ familyId: family.id, name: '', requestId: randomUUID(), submitted: false })} disabled={busy || newChild !== null} />)}
        {myRole === 'parent' && (pendingAccessCode?.familyId === family.id && pendingAccessCode.type === 'invite' ? <><Body>Create a one-use child invitation for {pendingAccessCode.displayName}? Anyone with this code can request to join this family for 24 hours.</Body><Button label="Confirm child invitation" onPress={() => void createAccessCode()} busy={busy} /><Button label="Cancel" secondary onPress={() => setPendingAccessCode(null)} disabled={busy} /></> : <Button label="Review child invitation" onPress={() => setPendingAccessCode({ type: 'invite', familyId: family.id, displayName: family.name })} busy={busy} />)}
        {invite?.familyId === family.id && <><Body>Share this one-use code with the child. It expires in 24 hours.</Body><Text selectable style={[styles.code, { color: theme.colors.ink }]}>{invite.code}</Text></>}
      </Panel>;
    })}
    <Panel><Label>Create a family</Label><Field label="Family name" value={name} onChangeText={setName} maxLength={100} /><Button label="Create family" onPress={() => void create()} busy={busy} disabled={!name.trim()} /></Panel>
    <Panel><Label>Join a family</Label><Body>Enter the invitation code supplied by the parent.</Body><Field label="Invitation code" value={code} onChangeText={(value) => { setCode(value); setConfirmJoin(false); }} autoCapitalize="none" autoCorrect={false} editable={!busy} />
      {!confirmJoin
        ? <Button label="Review family invitation" secondary onPress={() => setConfirmJoin(true)} disabled={!code.trim() || busy} />
        : <View style={sharedStyles.column}>
          <Body>Confirm joining the family linked to the invitation ending in {code.trim().slice(-4)} as a child member. The parent managing that household can manage this profile’s workouts, credits, and blocking rules.</Body>
          <Button label="Confirm joining as child" onPress={() => void join()} busy={busy} />
          <Button label="Keep editing invitation" secondary onPress={() => setConfirmJoin(false)} disabled={busy} />
        </View>}
    </Panel>
    <Button label="Back to profile" secondary onPress={() => router.replace('/settings')} />
  </Screen>;
}

function FamilyChildOverview({ childId, name, state }: { childId: string; name: string; state?: FamilyChildSummaryState }) {
  const { theme } = useBloomTheme();
  const summary = state?.summary ?? null;
  const moduleNames = moduleManifest.filter((module) => module.available && summary?.modules.includes(module.id)).map((module) => module.name);
  const pendingCount = (summary?.pendingCoaching ?? 0) + (summary?.pendingCompetitions ?? 0);
  return <View style={[styles.summary, { backgroundColor: theme.colors.surfaceSoft, borderColor: theme.colors.border }]}>
    <Eyebrow>Child overview · {name}</Eyebrow>
    {state?.loading && <ActivityIndicator color={theme.colors.action} />}
    {state?.error && <ErrorText>Could not load this child’s family overview. Refresh to retry.</ErrorText>}
    {summary && <>
      <Body>Assigned modules: {moduleNames.length ? moduleNames.join(', ') : 'None'}</Body>
      <Body>Available screen time: {summary.balance.toLocaleString(undefined, { maximumFractionDigits: 2 })} min</Body>
      <Body>This week: {summary.analytics.weekly_workout_target === null
        ? `${summary.analytics.workouts_completed} workouts completed`
        : `${summary.analytics.workouts_completed} of ${summary.analytics.weekly_workout_target} workouts`}</Body>
      <Label>{pendingCount ? `${pendingCount} requests awaiting review` : 'No pending requests'}</Label>
      {summary.pendingCoaching > 0 && <Body>{summary.pendingCoaching} workout proposals awaiting approval</Body>}
      {summary.pendingCompetitions > 0 && <Body>{summary.pendingCompetitions} event participation requests awaiting approval</Body>}
      {summary.pendingCoaching > 0 && <Button label={`Review ${name}’s workout proposals`} secondary onPress={() => router.push({ pathname: '/child-coaching', params: { childId, name } } as unknown as Href)} />}
      {summary.pendingCompetitions > 0 && <Button label={`Review ${name}’s event requests`} secondary onPress={() => router.push({ pathname: '/child-competitions', params: { childId, name } } as unknown as Href)} />}
      {summary.analytics.history.slice(0, 2).map((activity) => <Body key={activity.id}>
        Recent · {activity.plan_title} · {new Date(activity.completed_at).toLocaleDateString()}
      </Body>)}
    </>}
  </View>;
}

const styles = StyleSheet.create({
  code: { fontSize: 15, fontWeight: '700' },
  childGrid: { gap: 16 },
  desktopChildGrid: { flexDirection: 'row', flexWrap: 'wrap' },
  childCard: { padding: 12, borderRadius: 14, borderWidth: StyleSheet.hairlineWidth },
  desktopChildCard: { flexGrow: 1, flexBasis: '46%', minWidth: 320 },
  summary: { gap: 6, padding: 12, borderRadius: 14, borderWidth: StyleSheet.hairlineWidth },
});
