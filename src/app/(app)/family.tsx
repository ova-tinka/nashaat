import { randomUUID } from 'expo-crypto';
import { router, useFocusEffect, type Href } from 'expo-router';
import { useCallback, useState } from 'react';
import { ActivityIndicator, StyleSheet, Text, View } from 'react-native';
import { Body, Button, ErrorText, Eyebrow, Field, Heading, Label, Panel, Screen, sharedStyles } from '../../components/bloom-ui';
import { useAuth } from '../../lib/auth';
import { createChildAccountLink, createChildInvite, createFamily, createManagedChildProfile, deleteUnpairedChildProfile, joinFamily, leaveOrRemoveChild, loadFamilies, prepareChildPairing, type Family } from '../../lib/family';
import { colors } from '../../theme';

export default function FamilyScreen() {
  const { profileId, refreshProfile } = useAuth();
  const [families, setFamilies] = useState<Family[]>([]);
  const [name, setName] = useState('');
  const [code, setCode] = useState('');
  const [invite, setInvite] = useState<{ familyId: string; code: string } | null>(null);
  const [confirmRemoval, setConfirmRemoval] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [newChild, setNewChild] = useState<{ familyId: string; name: string; requestId: string; submitted: boolean } | null>(null);
  const [confirmProfileRemoval, setConfirmProfileRemoval] = useState<string | null>(null);
  const [pairing, setPairing] = useState<{ profileId: string; code: string } | null>(null);
  const [accountLink, setAccountLink] = useState<{ profileId: string; code: string } | null>(null);

  const load = useCallback(async () => {
    try { setFamilies(await loadFamilies()); setError(null); }
    catch { setError('Could not load your family connections.'); }
    finally { setLoading(false); }
  }, []);
  useFocusEffect(useCallback(() => { void load(); }, [load]));

  async function create() {
    setBusy(true); setError(null);
    try { await createFamily(name); setName(''); await load(); }
    catch { setError('Could not create the family. Check the name and try again.'); }
    finally { setBusy(false); }
  }
  async function join() {
    setBusy(true); setError(null);
    try { await joinFamily(code); setCode(''); await load(); await refreshProfile(); }
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

  return <Screen>
    <View style={sharedStyles.column}><Eyebrow>Family</Eyebrow><Heading>Family connections</Heading><Body>Link an existing account or create a child profile for your family.</Body></View>
    {loading && <ActivityIndicator color={colors.accent} />}
    {error && <ErrorText>{error}</ErrorText>}
    {!loading && families.map((family) => {
      const myRole = family.members.find((member) => member.user_id === profileId)?.role;
      return <Panel key={family.id}>
        <Label>{family.name}</Label>
        {family.members.map((member) => {
          if (family.childProfiles.some((child) => child.profile_id === member.user_id)) return null;
          const isSelf = member.user_id === profileId;
          const canRemove = member.role === 'child' && myRole === 'parent' && !isSelf;
          const removalKey = `${family.id}:${member.user_id}`;
          return <View key={member.user_id} style={sharedStyles.column}>
            <Body>{member.display_name} · {member.role}{isSelf ? ' · you' : ''}</Body>
            {myRole === 'parent' && member.role === 'child' && <Button label={`Manage ${member.display_name}`} secondary onPress={() => router.push({ pathname: '/family-child', params: { childId: member.user_id, name: member.display_name } } as unknown as Href)} />}
            {canRemove && (confirmRemoval === removalKey
              ? <><Body>{`Remove ${member.display_name} from this family?`}</Body><Button label="Confirm removal" secondary onPress={() => void remove(family.id, member.user_id)} busy={busy} /><Button label="Keep connection" secondary onPress={() => setConfirmRemoval(null)} disabled={busy} /></>
              : <Button label={`Remove ${member.display_name}`} secondary onPress={() => setConfirmRemoval(removalKey)} disabled={busy} />)}
          </View>;
        })}
        {myRole === 'parent' && family.childProfiles.map((child) => <View key={child.profile_id} style={sharedStyles.column}>
          <Body>{child.display_name} · child profile</Body>
          <Body>Generate a code to sign this child in on a device. The code expires in 10 minutes and can be used once.</Body>
          <Button label={`Pair a device for ${child.display_name}`} secondary onPress={() => void pairChild(child.profile_id)} busy={busy} />
          {family.members.some((member) => member.user_id === child.profile_id) && <Button label={`Manage ${child.display_name}`} secondary onPress={() => router.push({ pathname: '/family-child', params: { childId: child.profile_id, name: child.display_name } } as unknown as Href)} />}
          {family.members.some((member) => member.user_id === child.profile_id) && <Button label="Link a new email account" secondary onPress={() => void linkChildAccount(child.profile_id)} busy={busy} />}
          {pairing?.profileId === child.profile_id && <><Body>On the child device, sign out of any parent account, choose “Pair child device,” and enter this code.</Body><Text selectable style={styles.code}>{pairing.code}</Text></>}
          {accountLink?.profileId === child.profile_id && <><Body>Give this one-use code to your child. On the sign-in screen, choose “Link child email account” and create a new account. The code expires in 24 hours.</Body><Text selectable style={styles.code}>{accountLink.code}</Text></>}
          {!family.members.some((member) => member.user_id === child.profile_id) && (confirmProfileRemoval === child.profile_id ? <>
            <Body>Remove this unpaired profile?</Body>
            <Button label="Remove profile" secondary onPress={() => void removeChildProfile(child.profile_id)} busy={busy} />
            <Button label="Keep profile" secondary onPress={() => setConfirmProfileRemoval(null)} disabled={busy} />
          </> : <Button label={`Remove ${child.display_name}'s profile`} secondary onPress={() => setConfirmProfileRemoval(child.profile_id)} disabled={busy} />)}
        </View>)}
        {myRole === 'parent' && (newChild?.familyId === family.id ? <View style={sharedStyles.column}>
          <Field label="Child's display name" value={newChild.name} onChangeText={(value) => setNewChild({ ...newChild, name: value })} maxLength={100} editable={!busy && !newChild.submitted} />
          <Button label={newChild.submitted ? 'Retry saving profile' : 'Save child profile'} onPress={() => void createChild()} busy={busy} disabled={!newChild.name.trim()} />
          <Button label="Cancel" secondary onPress={() => { setNewChild(null); void load(); }} disabled={busy} />
        </View> : <Button label="Create child profile" secondary onPress={() => setNewChild({ familyId: family.id, name: '', requestId: randomUUID(), submitted: false })} disabled={busy || newChild !== null} />)}
        {myRole === 'parent' && <Button label="Create child invitation" onPress={() => void inviteChild(family.id)} busy={busy} />}
        {invite?.familyId === family.id && <><Body>Share this one-use code with the child. It expires in 24 hours.</Body><Text selectable style={styles.code}>{invite.code}</Text></>}
      </Panel>;
    })}
    <Panel><Label>Create a family</Label><Field label="Family name" value={name} onChangeText={setName} maxLength={100} /><Button label="Create family" onPress={() => void create()} busy={busy} disabled={!name.trim()} /></Panel>
    <Panel><Label>Join a family</Label><Body>Enter the invitation code supplied by the parent.</Body><Field label="Invitation code" value={code} onChangeText={setCode} autoCapitalize="none" autoCorrect={false} /><Button label="Join family" onPress={() => void join()} busy={busy} disabled={!code.trim()} /></Panel>
    <Button label="Back to profile" secondary onPress={() => router.replace('/settings')} />
  </Screen>;
}

const styles = StyleSheet.create({ code: { color: colors.text, fontSize: 15, fontWeight: '700' } });
