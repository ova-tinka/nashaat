import { router, useFocusEffect } from 'expo-router';
import { useCallback, useRef, useState } from 'react';
import { ActivityIndicator, Share, Switch, Text, View } from 'react-native';
import { Body, Button, ErrorText, Eyebrow, Field, Heading, Label, Panel, Screen, sharedStyles } from '../../components/bloom-ui';
import { useAuth } from '../../lib/auth';
import { localCompetitionDate, parseCompetitionDate } from '../../lib/competition-dates';
import { acceptCompetitionLink, acceptFriendInvite, competitionResults, createCompetitionLink, inviteFriend, joinPublicCompetition,
  loadCompetitionHome, publishCompetition, removeFriend, respondFriend, saveCompetition, saveSocialProfile, searchPeople, sendFriendRequest,
  type Competition, type CompetitionResult, type Person } from '../../lib/competitions';
import { colors } from '../../theme';

type Home = Awaited<ReturnType<typeof loadCompetitionHome>>;
function initialDate(days: number) { const date = new Date(); date.setDate(date.getDate() + days); date.setHours(9, 0, 0, 0); return localCompetitionDate(date); }

export default function CompetitionsScreen() {
  const { profileId, childProfile } = useAuth();
  const [home, setHome] = useState<Home | null>(null);
  const [name, setName] = useState('');
  const [searchable, setSearchable] = useState(false);
  const [search, setSearch] = useState('');
  const [people, setPeople] = useState<Person[]>([]);
  const [title, setTitle] = useState('');
  const [description, setDescription] = useState('');
  const [metric, setMetric] = useState<Competition['metric']>('workouts');
  const [visibility, setVisibility] = useState<Competition['visibility']>('private');
  const [capacity, setCapacity] = useState('2');
  const [starts, setStarts] = useState(() => initialDate(1));
  const [ends, setEnds] = useState(() => initialDate(8));
  const [editing, setEditing] = useState<string | null>(null);
  const [inviteCode, setInviteCode] = useState('');
  const [link, setLink] = useState<{ id: string; value: string } | null>(null);
  const [results, setResults] = useState<Record<string, CompetitionResult[]>>({});
  const [loading, setLoading] = useState(true);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [notice, setNotice] = useState<string | null>(null);
  const [now, setNow] = useState(() => Date.now());
  const initialized = useRef(false);

  const load = useCallback(async () => {
    if (!profileId) return;
    try {
      const data = await loadCompetitionHome(profileId); setHome(data);
      if (!initialized.current) { setName(data.social?.display_name ?? ''); setSearchable(data.social?.searchable ?? false); initialized.current = true; }
    } catch { setError('Could not load competitions. Check your connection and try again.'); }
    finally { setLoading(false); }
  }, [profileId]);
  useFocusEffect(useCallback(() => { void load(); setNow(Date.now()); const timer = setInterval(() => setNow(Date.now()), 60000); return () => clearInterval(timer); }, [load]));
  async function run(action: () => Promise<void>, success?: string) {
    setBusy(true); setError(null); setNotice(null);
    try { await action(); await load(); if (success) setNotice(success); }
    catch { setError('Could not complete this action. Check the details, permissions, and event dates, then try again.'); }
    finally { setBusy(false); }
  }
  async function saveEvent() {
    const start = parseCompetitionDate(starts); const end = parseCompetitionDate(ends); const max = Number(capacity);
    if (!title.trim() || !start || !end || !Number.isInteger(max) || max < 2 || max > 100 || new Date(end) <= new Date(start)) {
      setError('Enter a title, valid local dates, and 2–100 participants. The end must follow the start.'); return;
    }
    await run(async () => {
      await saveCompetition({ title, description, metric, visibility, max, starts: start, ends: end }, editing ?? undefined);
      setTitle(''); setDescription(''); setEditing(null); setVisibility('private');
    }, editing ? 'Draft updated.' : visibility === 'public' ? 'Public draft created.' : 'Private competition created.');
  }
  function editDraft(event: Competition) {
    setEditing(event.id); setTitle(event.title); setDescription(event.description); setMetric(event.metric); setVisibility('public');
    setCapacity(String(event.max_participants)); setStarts(localCompetitionDate(new Date(event.starts_at))); setEnds(localCompetitionDate(new Date(event.ends_at)));
  }
  async function findPeople() {
    if (search.trim().length < 2) { setError('Enter at least two characters to search.'); return; }
    setBusy(true); setError(null);
    try { setPeople(await searchPeople(search)); }
    catch { setError('Could not search for people.'); }
    finally { setBusy(false); }
  }
  async function showResults(eventId: string) {
    setBusy(true); setError(null);
    try { const next = await competitionResults(eventId); setResults((current) => ({ ...current, [eventId]: next })); await load(); }
    catch { setError('Could not load competition results.'); }
    finally { setBusy(false); }
  }

  return <Screen>
    <View style={sharedStyles.column}><Eyebrow>Move together</Eyebrow><Heading>Competitions</Heading><Body>Workouts and active minutes are self-reported. Events award recognition and winner badges only.</Body></View>
    <Button label="Back to profile" secondary onPress={() => router.replace('/settings')} disabled={busy} />
    {loading && <ActivityIndicator color={colors.accent} />}{error && <ErrorText>{error}</ErrorText>}{notice && <Body>{notice}</Body>}
    {home && <>
      <Panel><Label>Display name and search</Label><Body>Results show your display name. Search is optional.{childProfile ? ' A parent must also opt in before you appear in search.' : ''}</Body>
        <Field label="Display name" value={name} onChangeText={setName} maxLength={60} />
        <View style={sharedStyles.row}><Body>Allow people to find me</Body><Switch accessibilityLabel="Allow people to find me" value={searchable} onValueChange={setSearchable} disabled={busy} /></View>
        {childProfile && <Body>Parent search permission: {home.social?.child_search_opt_in ? 'enabled' : 'not enabled'}</Body>}
        <Button label="Save display name" onPress={() => void run(() => saveSocialProfile(name, searchable), 'Display name saved.')} disabled={!name.trim()} busy={busy} />
      </Panel>
      <Panel><Label>Friends</Label><Field label="Search display names" value={search} onChangeText={setSearch} maxLength={60} /><Button label="Search" secondary onPress={() => void findPeople()} busy={busy} />
        {people.map((person) => <View key={person.profile_id} style={sharedStyles.column}><Body>{person.display_name}</Body><Button label={`Send friend request to ${person.display_name}`} secondary disabled={busy} onPress={() => void run(() => sendFriendRequest(person.profile_id), 'Friend request sent.')} /></View>)}
        {home.friends.map((friend) => <View key={friend.id} style={sharedStyles.column}><Body>{friend.display_name} · {friend.status}{friend.status === 'pending' ? friend.incoming ? ' · received' : ' · sent' : ''}</Body>
          {friend.status === 'pending' && friend.incoming && <><Button label="Accept friend" secondary onPress={() => void run(() => respondFriend(friend.id, true), 'Friend added.')} disabled={busy} /><Button label="Decline" secondary onPress={() => void run(() => respondFriend(friend.id, false), 'Request declined.')} disabled={busy} /></>}
          {friend.status === 'accepted' && <Button label={`Remove ${friend.display_name}`} secondary onPress={() => void run(() => removeFriend(friend.id), 'Friend removed.')} disabled={busy} />}
        </View>)}
      </Panel>
      <Panel><Label>{editing ? 'Edit public draft' : 'Create a competition'}</Label>
        <Body>Dates and times use this device’s time zone. Choose two participants for one-to-one, or up to 100 for a group.</Body>
        <Field label="Title" value={title} onChangeText={setTitle} maxLength={100} /><Field label="Description (optional)" value={description} onChangeText={setDescription} maxLength={1000} multiline />
        <Field label="Starts (YYYY-MM-DD HH:mm)" value={starts} onChangeText={setStarts} autoCapitalize="none" /><Field label="Ends (YYYY-MM-DD HH:mm)" value={ends} onChangeText={setEnds} autoCapitalize="none" />
        <Field label="Maximum participants" value={capacity} onChangeText={setCapacity} keyboardType="number-pad" />
        <Label>Scoring</Label>{(['workouts', 'minutes'] as const).map((choice) => <Button key={choice} label={`${metric === choice ? '✓ ' : ''}${choice === 'workouts' ? 'Completed workouts' : 'Active workout minutes'}`} secondary onPress={() => setMetric(choice)} disabled={busy} />)}
        {home.admin && !editing && <><Label>Visibility</Label>{(['private', 'public'] as const).map((choice) => <Button key={choice} label={`${visibility === choice ? '✓ ' : ''}${choice === 'public' ? 'Public draft' : 'Private event'}`} secondary onPress={() => setVisibility(choice)} disabled={busy} />)}</>}
        <Button label={editing ? 'Save draft' : visibility === 'public' ? 'Create public draft' : 'Create private event'} onPress={() => void saveEvent()} busy={busy} />
        {editing && <Button label="Cancel editing" secondary onPress={() => { setEditing(null); setTitle(''); setDescription(''); setVisibility('private'); }} disabled={busy} />}
      </Panel>
      <Panel><Label>Join with an invitation code</Label><Field label="Invitation code" value={inviteCode} onChangeText={setInviteCode} autoCapitalize="none" autoCorrect={false} maxLength={64} /><Button label="Join competition" secondary onPress={() => void run(async () => { await acceptCompetitionLink(inviteCode); setInviteCode(''); }, 'Invitation accepted.')} disabled={busy || !inviteCode.trim()} /></Panel>
      {home.badges.length > 0 && <Panel><Label>Winner badges</Label>{home.badges.map((badge) => <Body key={badge.competition_id}>🏅 {badge.title}</Body>)}</Panel>}
      <Label>Events</Label>
      {home.events.length === 0 && <Panel><Body>No events available yet.</Body></Panel>}
      {home.events.map((event) => {
        const membership = home.participation.find((item) => item.competition_id === event.id);
        const invited = home.invites.some((item) => item.competition_id === event.id);
        const owner = event.owner_profile_id === profileId;
        const ended = new Date(event.ends_at).getTime() <= now;
        return <Panel key={event.id}>
          <Label>{event.title} · {event.visibility} · {event.status}</Label>{event.description && <Body>{event.description}</Body>}
          <Body>{new Date(event.starts_at).toLocaleString()} – {new Date(event.ends_at).toLocaleString()} · {event.metric === 'workouts' ? 'completed workouts' : 'active workout minutes'} · up to {event.max_participants} people</Body>
          <Body>Only saved workouts completed during the event after approval count. For minutes, the workout must also start after the event and approval; pause the timer during breaks.</Body>
          {membership && <Body>Your participation: {membership.status === 'pending_parent' ? 'waiting for parent approval' : membership.status}</Body>}
          {event.status === 'draft' && home.admin && <><Button label="Edit draft" secondary onPress={() => editDraft(event)} disabled={busy} /><Button label="Publish public event" onPress={() => void run(() => publishCompetition(event.id), 'Public event published.')} busy={busy} /></>}
          {event.status === 'published' && !ended && event.visibility === 'public' && !membership && <Button label="Join public event" onPress={() => void run(() => joinPublicCompetition(event.id), childProfile ? 'Request sent to your parent.' : 'Joined competition.')} busy={busy} />}
          {event.status === 'published' && !ended && invited && !membership && <Button label="Accept friend invitation" onPress={() => void run(() => acceptFriendInvite(event.id), childProfile ? 'Request sent to your parent.' : 'Joined competition.')} busy={busy} />}
          {event.status === 'published' && owner && event.visibility === 'private' && !ended && <>
            <Button label="Create invitation link" secondary onPress={() => void run(async () => { setLink({ id: event.id, value: await createCompetitionLink(event.id) }); })} disabled={busy} />
            {link?.id === event.id && <><Text selectable style={{ color: colors.text }}>{link.value}</Text><Button label="Share link" secondary onPress={() => { void Share.share({ message: link.value }).catch(() => setError('Could not open sharing. You can select and copy the link.')); }} disabled={busy} /></>}
            {home.friends.filter((friend) => friend.status === 'accepted').map((friend) => <Button key={friend.id} label={`Invite ${friend.display_name}`} secondary onPress={() => void run(() => inviteFriend(event.id, friend.profile_id), 'Invitation sent in Bloom.')} disabled={busy} />)}
          </>}
          {event.status === 'published' && <Button label="View results" secondary onPress={() => void showResults(event.id)} disabled={busy} />}
          {results[event.id]?.map((row, index) => <Body key={`${row.placement}-${index}`}>#{row.placement} · {row.display_name}{row.is_self ? ' (you)' : ''} · {row.score} {event.metric === 'minutes' ? 'min' : 'workouts'}{row.winner ? ' 🏅' : ''}</Body>)}
          {results[event.id]?.length === 0 && <Body>No approved participants yet.</Body>}
        </Panel>;
      })}
    </>}
  </Screen>;
}
