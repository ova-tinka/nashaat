import AsyncStorage from '@react-native-async-storage/async-storage';
import { router, useLocalSearchParams } from 'expo-router';
import { useCallback, useEffect, useRef, useState } from 'react';
import { ActivityIndicator, StyleSheet, Text, TextInput, View } from 'react-native';
import { Body, Button, ErrorText, Eyebrow, Heading, Label, Panel, Screen, sharedStyles } from '../../components/bloom-ui';
import { cancelWorkout, completeWorkout, loadWorkout, setWorkoutTimer, type ExerciseResult, type SessionExercise, type WorkoutSession } from '../../lib/bloom';
import { useBloom } from '../../lib/bloom-context';
import { colors } from '../../theme';

type Entry = { sets: string; value: string; extra: string; timerStartedAt: number | null; timerElapsed: number };
type Draft = Record<string, Entry>;
const emptyEntry = (): Entry => ({ sets: '', value: '', extra: '', timerStartedAt: null, timerElapsed: 0 });
const timed = (exercise: SessionExercise) => exercise.measurement_type === 'time_only' || exercise.measurement_type === 'time_distance';

function readDraft(raw: string | null, exercises: SessionExercise[]): Draft {
  let saved: Record<string, Partial<Entry>> = {};
  try { if (raw) saved = JSON.parse(raw) as Record<string, Partial<Entry>>; } catch { /* Ignore an unreadable local draft. */ }
  return Object.fromEntries(exercises.map((exercise) => {
    const item = saved?.[exercise.exercise_id];
    return [exercise.exercise_id, {
      sets: typeof item?.sets === 'string' ? item.sets : '',
      value: typeof item?.value === 'string' ? item.value : '',
      extra: typeof item?.extra === 'string' ? item.extra : '',
      timerStartedAt: typeof item?.timerStartedAt === 'number' && Number.isFinite(item.timerStartedAt) ? item.timerStartedAt : null,
      timerElapsed: typeof item?.timerElapsed === 'number' && Number.isFinite(item.timerElapsed) ? Math.max(0, item.timerElapsed) : 0,
    }];
  }));
}

export default function WorkoutSessionScreen() {
  const { id } = useLocalSearchParams<{ id?: string }>();
  const { refresh } = useBloom();
  const [session, setSession] = useState<WorkoutSession | null>(null);
  const [draft, setDraft] = useState<Draft>({});
  const [draftReady, setDraftReady] = useState(false);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [draftError, setDraftError] = useState<string | null>(null);
  const [confirmCancel, setConfirmCancel] = useState(false);
  const [now, setNow] = useState(0);
  const writes = useRef<Promise<void>>(Promise.resolve());
  const clearing = useRef(false);
  const draftKey = id ? `bloom-workout-draft:${id}` : '';

  const load = useCallback(async () => {
    if (!id) { setError('Workout session not found.'); setLoading(false); return; }
    clearing.current = false;
    setLoading(true); setError(null); setDraftReady(false);
    try {
      const data = await loadWorkout(id);
      setSession(data); setNow(Date.now());
      if (data.status === 'in_progress') {
        let raw: string | null = null;
        try { raw = await AsyncStorage.getItem(`bloom-workout-draft:${id}`); }
        catch { setDraftError('Progress could not be restored on this device.'); }
        setDraft(readDraft(raw, data.plan_snapshot));
        setDraftReady(true);
      }
    } catch { setError('Could not load this workout. Check your connection and try again.'); }
    finally { setLoading(false); }
  }, [id]);

  // Loading a session synchronizes the screen with the server and local draft.
  // eslint-disable-next-line react-hooks/set-state-in-effect
  useEffect(() => { void load(); }, [load]);
  useEffect(() => {
    if (!draftReady || !draftKey || clearing.current || session?.status !== 'in_progress') return;
    const serialized = JSON.stringify(draft);
    writes.current = writes.current.catch(() => {}).then(() => AsyncStorage.setItem(draftKey, serialized)).catch(() => {
      setDraftError('Progress could not be saved on this device.');
    });
  }, [draft, draftKey, draftReady, session?.status]);

  const timerRunning = Boolean(session?.timer_started_at) || Object.values(draft).some((entry) => entry.timerStartedAt !== null);
  useEffect(() => {
    if (!timerRunning) return;
    const timer = setInterval(() => setNow(Date.now()), 1000);
    return () => clearInterval(timer);
  }, [timerRunning]);

  function update(exerciseId: string, field: 'sets' | 'value' | 'extra', value: string) {
    setDraft((current) => ({ ...current, [exerciseId]: { ...(current[exerciseId] ?? emptyEntry()), [field]: value } }));
  }
  function toggleTimer(exerciseId: string) {
    const timestamp = Date.now();
    setNow(timestamp);
    setDraft((current) => {
      const entry = current[exerciseId] ?? emptyEntry();
      if (entry.timerStartedAt !== null) {
        const seconds = entry.timerElapsed + Math.max(0, Math.floor((timestamp - entry.timerStartedAt) / 1000));
        return { ...current, [exerciseId]: { ...entry, value: String(seconds), timerElapsed: seconds, timerStartedAt: null } };
      }
      const initial = Number(entry.value);
      return { ...current, [exerciseId]: { ...entry, timerElapsed: Number.isFinite(initial) && initial > 0 ? Math.floor(initial) : 0, timerStartedAt: timestamp } };
    });
  }
  async function clearDraft() {
    clearing.current = true;
    await writes.current.catch(() => {});
    try { await AsyncStorage.removeItem(draftKey); } catch { /* The server result is already saved. */ }
  }

  async function toggleWorkoutTimer() {
    if (!id || !session) return;
    setSaving(true); setError(null);
    try {
      await setWorkoutTimer(id, !session.timer_started_at);
      setSession(await loadWorkout(id));
      setNow(Date.now());
    } catch {
      // The request may have succeeded even if its response was lost.
      try { setSession(await loadWorkout(id)); setNow(Date.now()); } catch { /* Preserve the displayed state until retry. */ }
      setError('Could not update the workout timer. Check your connection and try again.');
    } finally { setSaving(false); }
  }

  async function finish() {
    if (!session || !id) return;
    const results: ExerciseResult[] = [];
    for (const exercise of session.plan_snapshot) {
      const entry = draft[exercise.exercise_id] ?? emptyEntry();
      const hasValue = Boolean(entry.sets.trim() || entry.value.trim() || entry.extra.trim() || entry.timerStartedAt !== null);
      if (!hasValue) continue;
      const sets = Number(entry.sets);
      const value = entry.timerStartedAt !== null
        ? entry.timerElapsed + Math.max(0, Math.floor((Date.now() - entry.timerStartedAt) / 1000))
        : Number(entry.value);
      const extra = entry.extra.trim() === '' ? undefined : Number(entry.extra);
      if (!Number.isSafeInteger(sets) || sets < 1 || sets > 20 || !Number.isSafeInteger(value) || value < 1 || value > (timed(exercise) ? 86400 : 1000) || (extra !== undefined && (!Number.isFinite(extra) || extra < 0 || extra > 1000 || (exercise.measurement_type === 'time_distance' && extra === 0)))) {
        setError(`Check the completed values for ${exercise.name}.`); return;
      }
      results.push({ exercise_id: exercise.exercise_id, sets_completed: sets,
        ...(timed(exercise) ? { duration_seconds: value } : { reps_completed: value }),
        ...(exercise.measurement_type === 'reps_weight' && extra !== undefined ? { weight_kg: extra } : {}),
        ...(exercise.measurement_type === 'time_distance' && extra !== undefined ? { distance_km: extra } : {}),
      });
    }
    if (results.length === 0) { setError('Log at least one exercise before finishing.'); return; }
    setSaving(true); setError(null);
    try {
      await completeWorkout(id, results);
      const completed = await loadWorkout(id);
      setDraftReady(false);
      await clearDraft();
      setSession(completed);
      await refresh();
    } catch { setError('Could not save the workout. Your entries are still on this screen; try again.'); }
    finally { setSaving(false); }
  }

  async function cancel() {
    if (!id) return;
    setSaving(true); setError(null);
    try { await cancelWorkout(id); setDraftReady(false); await clearDraft(); await refresh(); router.replace('/workouts'); }
    catch { setError('Could not cancel the workout. Please try again.'); }
    finally { setSaving(false); }
  }

  return <Screen>
    <View style={sharedStyles.column}><Eyebrow>Workout session</Eyebrow><Heading>{session?.status === 'completed' ? 'Workout saved' : 'Your workout'}</Heading></View>
    {loading && <ActivityIndicator color={colors.accent} />}
    {!loading && !session && <Panel><ErrorText>{error ?? 'Workout session not found.'}</ErrorText><Button label="Try again" onPress={() => void load()} /><Button label="Back to workouts" secondary onPress={() => router.replace('/workouts')} /></Panel>}
    {session?.status === 'completed' && <Panel><Label>Your workout is recorded.</Label><Body>{!session.credits_enabled_at_completion ? 'Screen-time credits were turned off for this workout.' : Number(session.credits_earned_minutes) > 0 ? `You earned ${Number(session.credits_earned_minutes).toLocaleString(undefined, { maximumFractionDigits: 4 })} minutes of screen time.` : 'No screen-time credits were earned. Review your earning strategy in Profile.'}</Body><Button label="Back to workouts" onPress={() => router.replace('/workouts')} /></Panel>}
    {session?.status === 'cancelled' && <Panel><Label>This workout was cancelled.</Label><Button label="Back to workouts" onPress={() => router.replace('/workouts')} /></Panel>}
    {session?.status === 'in_progress' && <>
      <Body>Log the exercises you completed. Your entries stay on this device until you finish or cancel.</Body>
      <Panel>
        <Label>Workout timer</Label>
        <Body>{session.active_duration_seconds === null ? 'Start the timer to record active workout time.' : `Active time: ${Math.floor((Number(session.active_duration_seconds) + (session.timer_started_at ? Math.max(0, (now - Date.parse(session.timer_started_at)) / 1000) : 0)) / 60)} min ${Math.floor((Number(session.active_duration_seconds) + (session.timer_started_at ? Math.max(0, (now - Date.parse(session.timer_started_at)) / 1000) : 0)) % 60)} sec${session.timer_started_at ? '' : ' · paused'}`}</Body>
        <Body>Pause during breaks. Time is self-reported and the display is approximate while running.</Body>
        <Button label={session.timer_started_at ? 'Pause workout timer' : session.active_duration_seconds === null ? 'Start workout timer' : 'Resume workout timer'} secondary onPress={() => void toggleWorkoutTimer()} disabled={saving} />
      </Panel>
      {session.plan_snapshot.map((exercise) => {
        const entry = draft[exercise.exercise_id] ?? emptyEntry();
        const seconds = entry.timerElapsed + (entry.timerStartedAt === null ? 0 : Math.max(0, Math.floor((now - entry.timerStartedAt) / 1000)));
        return <Panel key={exercise.exercise_id}>
          <Label>{exercise.name}</Label><Body>Planned: {exercise.sets} × {timed(exercise) ? `${exercise.target_seconds} seconds` : `${exercise.target_reps} reps`}{exercise.target_weight_kg !== null ? ` · ${exercise.target_weight_kg} kg` : ''}{exercise.target_distance_km !== null ? ` · ${exercise.target_distance_km} km` : ''}</Body>
          {exercise.description && <Body>{exercise.description}</Body>}
          {(exercise.instructions ?? []).map((instruction, index) => <Body key={`${exercise.exercise_id}-instruction-${index}`}>{index + 1}. {instruction}</Body>)}
          <View style={styles.inputs}><View style={styles.inputGroup}><Text style={styles.inputLabel}>Sets completed</Text><TextInput accessibilityLabel={`${exercise.name} sets completed`} value={entry.sets} onChangeText={(value) => update(exercise.exercise_id, 'sets', value)} keyboardType="number-pad" style={styles.input} /></View><View style={styles.inputGroup}><Text style={styles.inputLabel}>{timed(exercise) ? 'Seconds per set' : 'Reps per set'}</Text><TextInput accessibilityLabel={`${exercise.name} ${timed(exercise) ? 'seconds' : 'repetitions'} completed`} value={entry.timerStartedAt !== null ? String(seconds) : entry.value} onChangeText={(value) => update(exercise.exercise_id, 'value', value)} editable={entry.timerStartedAt === null} keyboardType="number-pad" style={styles.input} /></View></View>
          {timed(exercise) && <Button label={entry.timerStartedAt === null ? 'Start timer' : 'Pause timer'} secondary onPress={() => toggleTimer(exercise.exercise_id)} />}
          {(exercise.measurement_type === 'reps_weight' || exercise.measurement_type === 'time_distance') && <View style={styles.inputGroup}><Text style={styles.inputLabel}>{exercise.measurement_type === 'reps_weight' ? 'Weight in kg (optional)' : 'Distance in km (optional)'}</Text><TextInput accessibilityLabel={`${exercise.name} ${exercise.measurement_type === 'reps_weight' ? 'weight' : 'distance'}`} value={entry.extra} onChangeText={(value) => update(exercise.exercise_id, 'extra', value)} keyboardType="decimal-pad" style={styles.input} /></View>}
        </Panel>;
      })}
      {draftError && <ErrorText>{draftError}</ErrorText>}{error && <ErrorText>{error}</ErrorText>}
      <Button label="Finish workout" onPress={() => void finish()} busy={saving} disabled={!draftReady} />
      {confirmCancel ? <Panel><Label>Cancel this workout?</Label><Body>Your unsaved entries will be removed.</Body><Button label="Cancel workout" onPress={() => void cancel()} busy={saving} /><Button label="Keep workout" secondary onPress={() => setConfirmCancel(false)} /></Panel> : <Button label="Cancel workout" secondary onPress={() => setConfirmCancel(true)} disabled={saving} />}
      <Button label="Back to workouts" secondary onPress={() => router.replace('/workouts')} disabled={saving} />
    </>}
  </Screen>;
}

const styles = StyleSheet.create({
  inputs: { flexDirection: 'row', gap: 12 },
  inputGroup: { flex: 1, gap: 6 },
  inputLabel: { color: colors.body, fontSize: 12 },
  input: { minHeight: 44, borderWidth: 1, borderColor: colors.border, borderRadius: 10, paddingHorizontal: 12, color: colors.text, backgroundColor: colors.background, fontSize: 16 },
});
