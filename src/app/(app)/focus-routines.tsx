import { randomUUID } from 'expo-crypto';
import { router, useFocusEffect } from 'expo-router';
import { useCallback, useState } from 'react';
import { Platform, Pressable, StyleSheet, Switch, Text, View } from 'react-native';
import BloomBlocking from '../../../modules/bloom-blocking/src/BloomBlockingModule';
import type { AppCandidate, BlockingStatus } from '../../../modules/bloom-blocking/src/BloomBlocking.types';
import { Body, Button, ErrorText, Eyebrow, Field, Heading, Label, Panel, Screen, sharedStyles } from '../../components/bloom-ui';
import { useAuth } from '../../lib/auth';
import { useBloomTheme } from '../../lib/theme-context';
import { canonicalWebsiteDomain } from '../../lib/website-domain';
import { FocusAppPicker } from '../../components/focus-app-picker';

type RoutineSchedule = { enabled: boolean; startMinute: number; endMinute: number; days: number[] };
type Routine = RoutineSchedule & { id: string; name: string; apps: string[]; websites: string[] };
type Draft = Omit<Routine, 'startMinute' | 'endMinute' | 'websites'> & { start: string; end: string; websites: string };
const dayNames = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
const formatTime = (minute: number) => `${String(Math.floor(minute / 60)).padStart(2, '0')}:${String(minute % 60).padStart(2, '0')}`;
function parseTime(value: string): number | null {
  const match = /^(\d{1,2}):(\d{2})$/.exec(value.trim());
  if (!match) return null;
  const hour = Number(match[1]); const minute = Number(match[2]);
  return hour < 24 && minute < 60 ? hour * 60 + minute : null;
}
function emptyDraft(): Draft { return { id: randomUUID(), name: '', enabled: true, start: '22:00', end: '06:00', days: [], apps: [], websites: '' }; }
function asDraft(routine: Routine): Draft { return { ...routine, start: formatTime(routine.startMinute), end: formatTime(routine.endMinute), websites: routine.websites.join('\n') }; }
function nextActivation(routine: RoutineSchedule, now: Date): Date | null {
  if (!routine.enabled) return null;
  for (let offset = 0; offset <= 7; offset += 1) {
    const date = new Date(now.getFullYear(), now.getMonth(), now.getDate() + offset, Math.floor(routine.startMinute / 60), routine.startMinute % 60);
    if (routine.days.includes(date.getDay()) && date > now) return date;
  }
  return null;
}
function active(routine: RoutineSchedule, date = new Date()) {
  const minute = date.getHours() * 60 + date.getMinutes(); const day = date.getDay();
  return routine.enabled && (routine.startMinute < routine.endMinute
    ? routine.days.includes(day) && minute >= routine.startMinute && minute < routine.endMinute
    : (routine.days.includes(day) && minute >= routine.startMinute) || (routine.days.includes((day + 6) % 7) && minute < routine.endMinute));
}

export default function FocusRoutinesScreen() {
  return Platform.OS === 'ios' ? <IosScheduledFocusScreen /> : <AndroidScheduledFocusScreen />;
}

function AndroidScheduledFocusScreen() {
  const { profileId } = useAuth();
  const { theme } = useBloomTheme();
  const [routines, setRoutines] = useState<Routine[]>([]);
  const [apps, setApps] = useState<AppCandidate[]>([]);
  const [status, setStatus] = useState<BlockingStatus | null>(null);
  const [draft, setDraft] = useState<Draft | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const [now, setNow] = useState(() => new Date());

  const load = useCallback(() => {
    if (Platform.OS !== 'android' || !profileId) return;
    try {
      if (BloomBlocking.getFocusAccount() !== profileId) throw new Error('Connect to sync this device to your account before managing routines.');
      setRoutines(JSON.parse(BloomBlocking.getFocusRoutines(profileId)) as Routine[]);
      setApps(BloomBlocking.getInstalledApps());
      setStatus(BloomBlocking.getStatus());
      setError(null);
    } catch (cause) { setError(cause instanceof Error ? cause.message : 'Could not load routines.'); }
  }, [profileId]);
  useFocusEffect(useCallback(() => {
    load();
    const timer = setInterval(() => {
      setNow(new Date());
      if (Platform.OS === 'android') {
        try { setStatus(BloomBlocking.getStatus()); } catch { setStatus(null); }
      }
    }, 5000);
    return () => clearInterval(timer);
  }, [load]));

  async function persist(next: Routine[]) {
    if (!profileId || BloomBlocking.getFocusAccount() !== profileId) throw new Error('The device account changed. Reopen routines after syncing.');
    await BloomBlocking.saveFocusRoutines(profileId, JSON.stringify(next));
    setRoutines(next);
    setStatus(BloomBlocking.getStatus());
  }
  async function save() {
    if (!draft) return;
    const start = parseTime(draft.start); const end = parseTime(draft.end);
    const rawSites = draft.websites.split(/[\n,]+/).map((site) => site.trim()).filter(Boolean);
    const sites = rawSites.map(canonicalWebsiteDomain);
    if (!draft.name.trim() || draft.name.trim().length > 80 || start === null || end === null || start === end || !draft.days.length || sites.some((site) => !site) || (!draft.apps.length && !sites.length)) {
      setError('Enter a name, different start and end times, days, and at least one app or valid website.'); return;
    }
    setBusy(true); setError(null);
    try {
      const next: Routine = { id: draft.id, name: draft.name.trim(), enabled: draft.enabled, startMinute: start, endMinute: end, days: draft.days, apps: draft.apps, websites: [...new Set(sites as string[])] };
      await persist([...routines.filter((entry) => entry.id !== draft.id), next]);
      setDraft(null);
    } catch (cause) { setError(cause instanceof Error ? cause.message : 'Could not save the routine.'); }
    finally { setBusy(false); }
  }
  async function update(next: Routine[]) {
    setBusy(true); setError(null);
    try { await persist(next); }
    catch (cause) { setError(cause instanceof Error ? cause.message : 'Could not update the routine.'); }
    finally { setBusy(false); }
  }
  const available = Platform.OS === 'android';
  const enforced = status?.authorized && status.serviceConnected === true && !status.scheduleError;
  return <Screen safeAreaTop={false}>
    <View style={sharedStyles.column}><Eyebrow>Focus & Blocking</Eyebrow><Heading>Scheduled Focus</Heading><Body>Routines use this device’s local time. Overlapping routines combine their restrictions.</Body><Body>Current screen-time reservations are timed and continue consuming credits while a routine blocks access.</Body><Button label="Back" variant="tertiary" onPress={() => router.back()} /></View>
    {!available ? <Panel><Body>Scheduled Focus is not available on this device.</Body></Panel> : <>
      <Panel><Label>{enforced ? 'Device service connected' : 'Device enforcement needs attention'}</Label><Body>{enforced ? 'Enabled routines apply on this device while the service remains connected.' : 'Allow Bloom’s Android Accessibility service and keep it running before relying on routines.'}</Body></Panel>
      {error && <ErrorText>{error}</ErrorText>}
      {!draft && <>
        <Button label="Add routine" onPress={() => { setDraft(emptyDraft()); setError(null); }} disabled={busy || !!error} />
        {routines.length === 0 && <Body>No routines yet.</Body>}
        {routines.map((routine) => <Panel key={routine.id}>
          <View style={sharedStyles.row}><View style={sharedStyles.grow}><Label>{routine.name}</Label><Body>{routine.days.map((day) => dayNames[day]).join(', ')} · {formatTime(routine.startMinute)}–{formatTime(routine.endMinute)}{routine.endMinute < routine.startMinute ? ' next day' : ''}</Body></View><Switch accessibilityLabel={`Enable ${routine.name}`} value={routine.enabled} disabled={busy} onValueChange={(enabled) => void update(routines.map((item) => item.id === routine.id ? { ...item, enabled } : item))} /></View>
          <Body>{routine.apps.length} apps · {routine.websites.length} websites{active(routine, now) ? enforced ? ' · Active now' : ' · Scheduled now; enforcement unavailable' : ''}</Body>
          {nextActivation(routine, now) && <Body>Next start: {nextActivation(routine, now)?.toLocaleString()}</Body>}
          <Button label={`Edit ${routine.name}`} variant="secondary" onPress={() => { setDraft(asDraft(routine)); setError(null); }} disabled={busy} />
          <Button label={`Delete ${routine.name}`} variant="tertiary" onPress={() => void update(routines.filter((item) => item.id !== routine.id))} disabled={busy} />
        </Panel>)}
      </>}
      {draft && <Panel>
        <Label>{routines.some((item) => item.id === draft.id) ? 'Edit routine' : 'New routine'}</Label>
        <Field label="Routine name" value={draft.name} onChangeText={(name) => setDraft({ ...draft, name })} maxLength={80} />
        <View style={sharedStyles.row}><View style={sharedStyles.grow}><Field label="Start (24-hour HH:MM)" value={draft.start} onChangeText={(start) => setDraft({ ...draft, start })} /></View><View style={sharedStyles.grow}><Field label="End (24-hour HH:MM)" value={draft.end} onChangeText={(end) => setDraft({ ...draft, end })} /></View></View>
        <Body>When the end is earlier than the start, the routine ends the next day.</Body>
        <Label>Days</Label><View style={styles.days}>{dayNames.map((day, index) => <Pressable key={day} accessibilityRole="checkbox" accessibilityLabel={day} accessibilityState={{ checked: draft.days.includes(index) }} onPress={() => setDraft({ ...draft, days: draft.days.includes(index) ? draft.days.filter((item) => item !== index) : [...draft.days, index].sort() })} style={[styles.day, { borderColor: theme.colors.border, backgroundColor: draft.days.includes(index) ? theme.colors.surfaceTinted : theme.colors.surface }]}><Text style={{ color: theme.colors.ink }}>{day}</Text></Pressable>)}</View>
        <FocusAppPicker apps={apps} selected={draft.apps} onChange={(selected) => setDraft({ ...draft, apps: selected })} />
        <Field label="Websites (one domain per line)" value={draft.websites} onChangeText={(websites) => setDraft({ ...draft, websites })} autoCapitalize="none" autoCorrect={false} multiline />
        <Body>Website checks must be enabled in Focus. Coverage is limited to supported browsers; unreadable addresses are blocked as a whole.</Body>
        <Button label="Save routine" onPress={() => void save()} busy={busy} />
        <Button label="Cancel" variant="secondary" onPress={() => { setDraft(null); setError(null); }} disabled={busy} />
      </Panel>}
    </>}
  </Screen>;
}

type IosRoutine = RoutineSchedule & { id: string; name: string; appCount: number; websiteCount: number; categoryCount: number; active: boolean };
type IosDraft = { id: string; name: string; enabled: boolean; start: string; end: string; days: number[] };
function emptyIosDraft(): IosDraft { return { id: randomUUID(), name: '', enabled: true, start: '22:00', end: '06:00', days: [] }; }
function iosDraft(routine: IosRoutine): IosDraft { return { id: routine.id, name: routine.name, enabled: routine.enabled, start: formatTime(routine.startMinute), end: formatTime(routine.endMinute), days: routine.days }; }

function IosScheduledFocusScreen() {
  const { profileId } = useAuth();
  const { theme } = useBloomTheme();
  const [routines, setRoutines] = useState<IosRoutine[]>([]);
  const [status, setStatus] = useState<BlockingStatus | null>(null);
  const [selection, setSelection] = useState<{ appCount: number; websiteCount: number; categoryCount: number } | null>(null);
  const [draft, setDraft] = useState<IosDraft | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const [now, setNow] = useState(() => new Date());

  const load = useCallback(() => {
    if (Platform.OS !== 'ios' || !profileId) return;
    try {
      if (BloomBlocking.getFocusAccount() !== profileId) throw new Error('Sync this device to your profile before managing routines.');
      setRoutines(JSON.parse(BloomBlocking.getIosFocusRoutines(profileId)) as IosRoutine[]);
      setStatus(BloomBlocking.getStatus());
      setError(null);
    } catch (cause) { setError(cause instanceof Error ? cause.message : 'Could not load routines.'); }
  }, [profileId]);

  useFocusEffect(useCallback(() => {
    load();
    const timer = setInterval(() => { setNow(new Date()); load(); }, 5000);
    return () => clearInterval(timer);
  }, [load]));

  async function authorize() {
    setBusy(true); setError(null);
    try {
      if (!await BloomBlocking.requestAuthorization()) throw new Error('Screen Time permission was not granted.');
      load();
    } catch (cause) { setError(cause instanceof Error ? cause.message : 'Could not request Screen Time permission.'); }
    finally { setBusy(false); }
  }

  async function chooseApps(routineId: string) {
    if (!profileId) return;
    setBusy(true); setError(null);
    try {
      if (!BloomBlocking.getStatus().authorized && !await BloomBlocking.requestAuthorization()) throw new Error('Allow Screen Time access before choosing apps.');
      await BloomBlocking.presentIosFocusRoutinePicker(profileId, routineId);
      setSelection(BloomBlocking.getIosFocusRoutineSelection(profileId, routineId));
    } catch (cause) { setError(cause instanceof Error ? cause.message : 'Could not choose apps and websites.'); }
    finally { setBusy(false); }
  }

  async function persist(next: IosRoutine | IosDraft) {
    if (!profileId) throw new Error('Sign in before saving a routine.');
    const startMinute = 'startMinute' in next ? next.startMinute : parseTime(next.start);
    const endMinute = 'endMinute' in next ? next.endMinute : parseTime(next.end);
    if (startMinute === null || endMinute === null) throw new Error('Enter valid start and end times.');
    await BloomBlocking.saveIosFocusRoutine(profileId, JSON.stringify({
      id: next.id, name: next.name, enabled: next.enabled,
      startMinute, endMinute, days: next.days,
    }));
    setRoutines(JSON.parse(BloomBlocking.getIosFocusRoutines(profileId)) as IosRoutine[]);
  }

  async function saveDraft() {
    if (!draft) return;
    const start = parseTime(draft.start); const end = parseTime(draft.end);
    const duration = start === null || end === null ? 0 : (end - start + 1440) % 1440;
    if (!draft.name.trim() || draft.name.trim().length > 80 || start === null || end === null || duration < 15 || draft.days.length === 0) {
      setError('Enter a name, a duration of at least 15 minutes, and at least one day.'); return;
    }
    const selected = profileId ? BloomBlocking.getIosFocusRoutineSelection(profileId, draft.id) : null;
    if (!selected || selected.appCount + selected.websiteCount + selected.categoryCount === 0) { setError('Choose at least one app, website, or category.'); return; }
    setBusy(true); setError(null);
    try {
      await persist(draft);
      setDraft(null); setSelection(null); load();
    } catch (cause) { setError(cause instanceof Error ? cause.message : 'Could not save the routine.'); }
    finally { setBusy(false); }
  }

  async function updateRoutine(next: IosRoutine) {
    setBusy(true); setError(null);
    try { await persist(next); load(); }
    catch (cause) { setError(cause instanceof Error ? cause.message : 'Could not update the routine.'); }
    finally { setBusy(false); }
  }

  async function removeRoutine(routineId: string) {
    if (!profileId) return;
    setBusy(true); setError(null);
    try { await BloomBlocking.deleteIosFocusRoutine(profileId, routineId); load(); }
    catch (cause) { setError(cause instanceof Error ? cause.message : 'Could not delete the routine.'); }
    finally { setBusy(false); }
  }

  const enforced = status?.authorized && !status.scheduleError;
  return <Screen safeAreaTop={false}>
    <View style={sharedStyles.column}>
      <Eyebrow>Focus & Blocking</Eyebrow><Heading>Scheduled Focus</Heading>
      <Body>Routines use this device’s local time. Overlapping routines combine their restrictions, including routines that run across midnight. iOS supports up to 18 enabled routines, each at least 15 minutes long.</Body>
      <Button label="Back" variant="tertiary" onPress={() => router.back()} />
    </View>
    <Panel>
      <Label>{!status ? 'Schedule status unavailable' : enforced ? 'Schedules ready on this device' : 'Device enforcement needs attention'}</Label>
      <Body>{status?.scheduleError ? 'One or more routines could not be registered with Screen Time. Reopen Bloom and check permission.' : 'iOS applies each routine with its own Screen Time rule, so one routine ending does not clear another.'}</Body>
      {!status?.authorized && <Button label="Allow Screen Time" variant="secondary" onPress={() => void authorize()} busy={busy} disabled={busy} />}
    </Panel>
    {error && <ErrorText>{error}</ErrorText>}
    {!draft && <>
      <Button label="Add routine" onPress={() => { setDraft(emptyIosDraft()); setSelection(null); setError(null); }} disabled={busy || !!error || !profileId} />
      {routines.length === 0 && <Body>No routines yet.</Body>}
      {routines.map((routine) => {
        const next = nextActivation(routine, now);
        return <Panel key={routine.id}>
          <View style={sharedStyles.row}>
            <View style={sharedStyles.grow}><Label>{routine.name}</Label><Body>{routine.days.map((day) => dayNames[day]).join(', ')} · {formatTime(routine.startMinute)}–{formatTime(routine.endMinute)}{routine.endMinute < routine.startMinute ? ' next day' : ''}</Body></View>
            <Switch accessibilityLabel={`Enable ${routine.name}`} value={routine.enabled} disabled={busy} onValueChange={(enabled) => void updateRoutine({ ...routine, enabled })} />
          </View>
          <Body>{routine.appCount} apps · {routine.websiteCount} websites · {routine.categoryCount} categories{routine.active ? enforced ? ' · Active now' : ' · Scheduled now; enforcement unavailable' : ''}</Body>
          {routine.enabled && !routine.active && next && <Body>Next start: {next.toLocaleString()}</Body>}
          <Button label={`Choose apps for ${routine.name}`} variant="secondary" onPress={() => void chooseApps(routine.id)} disabled={busy} />
          <Button label={`Edit ${routine.name}`} variant="secondary" onPress={() => { setDraft(iosDraft(routine)); setSelection({ appCount: routine.appCount, websiteCount: routine.websiteCount, categoryCount: routine.categoryCount }); setError(null); }} disabled={busy} />
          <Button label={`Delete ${routine.name}`} variant="tertiary" onPress={() => void removeRoutine(routine.id)} disabled={busy} />
        </Panel>;
      })}
    </>}
    {draft && <Panel>
      <Label>{routines.some((item) => item.id === draft.id) ? 'Edit routine' : 'New routine'}</Label>
      <Field label="Routine name" value={draft.name} onChangeText={(name) => setDraft({ ...draft, name })} maxLength={80} />
      <View style={sharedStyles.row}><View style={sharedStyles.grow}><Field label="Start (24-hour HH:MM)" value={draft.start} onChangeText={(start) => setDraft({ ...draft, start })} /></View><View style={sharedStyles.grow}><Field label="End (24-hour HH:MM)" value={draft.end} onChangeText={(end) => setDraft({ ...draft, end })} /></View></View>
      <Body>When the end is earlier than the start, the routine ends the next day. Schedules follow this device’s local time zone.</Body>
      <Label>Days</Label><View style={styles.days}>{dayNames.map((day, index) => <Pressable key={day} accessibilityRole="checkbox" accessibilityLabel={day} accessibilityState={{ checked: draft.days.includes(index) }} onPress={() => setDraft({ ...draft, days: draft.days.includes(index) ? draft.days.filter((item) => item !== index) : [...draft.days, index].sort() })} style={[styles.day, { borderColor: theme.colors.border, backgroundColor: draft.days.includes(index) ? theme.colors.surfaceTinted : theme.colors.surface }]}><Text style={{ color: theme.colors.ink }}>{day}</Text></Pressable>)}</View>
      <Button label={`Choose apps and websites${selection ? ` · ${selection.appCount + selection.websiteCount + selection.categoryCount} selected` : ''}`} variant="secondary" onPress={() => void chooseApps(draft.id)} busy={busy} disabled={busy} />
      <Button label="Save routine" onPress={() => void saveDraft()} busy={busy} disabled={busy || !status?.authorized} />
      <Button label="Cancel" variant="secondary" onPress={() => { setDraft(null); setError(null); }} disabled={busy} />
    </Panel>}
  </Screen>;
}
const styles = StyleSheet.create({ days: { flexDirection: 'row', flexWrap: 'wrap', gap: 6 }, day: { minHeight: 44, minWidth: 44, alignItems: 'center', justifyContent: 'center', borderWidth: 1, borderRadius: 10, paddingHorizontal: 8 } });
