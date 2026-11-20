import { router, useLocalSearchParams } from 'expo-router';
import { useEffect, useMemo, useState } from 'react';
import { ActivityIndicator, Pressable, StyleSheet, Text, TextInput, View } from 'react-native';
import { Body, Button, ErrorText, Eyebrow, Field, Heading, Label, Panel, Screen, sharedStyles } from '../../components/bloom-ui';
import { createPlan, createPlanForUser, loadCatalog, loadWorkoutPlan, SCHEDULE_DAYS, updatePlan, updatePlanForUser, type Exercise } from '../../lib/bloom';
import { useBloom } from '../../lib/bloom-context';
import { useBloomTheme } from '../../lib/theme-context';

type Selection = { exercise: Exercise; sets: string; target: string; extra: string };

function isTimed(exercise: Exercise) {
  return exercise.measurement_type === 'time_only' || exercise.measurement_type === 'time_distance';
}

export default function NewPlanScreen() {
  const { childId, exerciseId, planId } = useLocalSearchParams<{ childId?: string; exerciseId?: string; planId?: string }>();
  const { refresh } = useBloom();
  const { theme } = useBloomTheme();
  const [title, setTitle] = useState('');
  const [query, setQuery] = useState('');
  const [catalog, setCatalog] = useState<Exercise[]>([]);
  const [selected, setSelected] = useState<Selection[]>([]);
  const [scheduledDays, setScheduledDays] = useState<number[]>([]);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    let active = true;
    void Promise.all([loadCatalog(childId), planId ? loadWorkoutPlan(planId) : Promise.resolve(null)]).then(([items, plan]) => {
      if (!active) return;
      setCatalog(items);
      if (plan) {
        setTitle(plan.title);
        setScheduledDays(plan.scheduled_days ?? []);
        setSelected([...plan.bloom_plan_exercises].sort((a, b) => a.position - b.position).flatMap((item) => {
          const exercise = items.find((candidate) => candidate.id === item.exercise?.id);
          if (!exercise) return [];
          return [{ exercise, sets: String(item.sets), target: String(item.target_reps ?? item.target_seconds ?? 1), extra: String(item.target_weight_kg ?? item.target_distance_km ?? '') }];
        }));
      } else if (exerciseId) {
        const exercise = items.find((item) => item.id === exerciseId);
        if (exercise) setSelected([{ exercise, sets: isTimed(exercise) ? '1' : '3', target: isTimed(exercise) ? '60' : '10', extra: '' }]);
      }
    })
      .catch(() => { if (active) setError('Could not load the exercise library. Check your connection and try again.'); })
      .finally(() => { if (active) setLoading(false); });
    return () => { active = false; };
  }, [childId, exerciseId, planId]);

  const matching = useMemo(() => {
    const term = query.trim().toLowerCase();
    return catalog.filter((exercise) => exercise.name.toLowerCase().includes(term));
  }, [catalog, query]);

  function toggle(exercise: Exercise) {
    setError(null);
    setSelected((current) => {
      if (current.some((item) => item.exercise.id === exercise.id)) {
        return current.filter((item) => item.exercise.id !== exercise.id);
      }
      if (current.length >= 50) return current;
      return [...current, { exercise, sets: isTimed(exercise) ? '1' : '3', target: isTimed(exercise) ? '60' : '10', extra: '' }];
    });
  }

  function update(id: string, field: 'sets' | 'target' | 'extra', value: string) {
    setSelected((current) => current.map((item) => item.exercise.id === id ? { ...item, [field]: value } : item));
  }

  function toggleDay(day: number) {
    setScheduledDays((current) => current.includes(day) ? current.filter((item) => item !== day) : [...current, day]);
  }

  async function save() {
    if (!title.trim() || title.trim().length > 100) { setError('Enter a plan name of up to 100 characters.'); return; }
    if (selected.length === 0) { setError('Choose at least one exercise.'); return; }
    const entries = selected.map((item) => ({ exercise_id: item.exercise.id, sets: Number(item.sets), target: Number(item.target), timed: isTimed(item.exercise), measurement: item.exercise.measurement_type, extra: item.extra.trim() === '' ? undefined : Number(item.extra) }));
    if (entries.some((item) => !Number.isSafeInteger(item.sets) || item.sets < 1 || item.sets > 20 || !Number.isSafeInteger(item.target) || item.target < 1 || item.target > (item.timed ? 86400 : 1000) || (item.extra !== undefined && (!Number.isFinite(item.extra) || item.extra > 1000 || item.extra < 0 || (item.measurement === 'time_distance' && item.extra === 0))))) {
      setError('Use 1–20 sets and a positive target for each exercise.'); return;
    }
    setSaving(true); setError(null);
    try {
      const exercises = entries.map(({ exercise_id, sets, target, measurement, extra }) => ({ exercise_id, sets, target, ...(measurement === 'reps_weight' && extra !== undefined ? { weight_kg: extra } : {}), ...(measurement === 'time_distance' && extra !== undefined ? { distance_km: extra } : {}) }));
      if (planId) {
        if (childId) await updatePlanForUser(childId, planId, title, exercises, scheduledDays);
        else await updatePlan(planId, title, exercises, scheduledDays);
        if (childId) router.back();
        else { await refresh(); router.replace('/workouts'); }
      }
      else if (childId) { await createPlanForUser(childId, title, exercises, scheduledDays); router.back(); }
      else { await createPlan(title, exercises, scheduledDays); await refresh(); router.replace('/workouts'); }
    } catch { setError('Could not save your plan. Check your connection and try again.'); }
    finally { setSaving(false); }
  }

  return <Screen safeAreaTop={false}>
    <View style={sharedStyles.column}><Eyebrow>Workout builder</Eyebrow><Heading>{planId ? 'Edit a plan' : 'Create a plan'}</Heading><Body>Choose exercises and set a target for each one.</Body></View>
    <Button label={childId ? 'Back to family' : 'Back to workouts'} secondary onPress={() => childId ? router.back() : router.replace('/workouts')} />
    <Panel><Field label="Plan name" value={title} onChangeText={setTitle} placeholder="e.g. Full body" maxLength={100} /></Panel>
    <Panel><Eyebrow>Weekly schedule</Eyebrow><Body>Choose the days you plan to do this workout. Unselected days remain rest or flexible days.</Body><View style={styles.days}>{SCHEDULE_DAYS.map(({ label, iso }) => {
      const selectedDay = scheduledDays.includes(iso);
      return <Pressable key={iso} accessibilityRole="checkbox" accessibilityState={{ checked: selectedDay }} onPress={() => toggleDay(iso)} style={[styles.dayChoice, { borderColor: theme.colors.border, backgroundColor: theme.colors.surface }, selectedDay && { borderColor: theme.colors.action, backgroundColor: theme.colors.action }]}><Text style={[styles.dayLabel, { color: theme.colors.ink }, selectedDay && { color: theme.colors.onAction }]}>{label}</Text></Pressable>;
    })}</View></Panel>
    {selected.length > 0 && <Panel><Eyebrow>Selected · {selected.length}</Eyebrow>
      {selected.map(({ exercise, sets, target, extra }) => <View key={exercise.id} style={[styles.selected, { borderBottomColor: theme.colors.border }]}>
        <View style={sharedStyles.row}><View style={sharedStyles.grow}><Label>{exercise.name}</Label></View><Pressable accessibilityRole="button" onPress={() => toggle(exercise)}><Text style={[styles.remove, { color: theme.colors.dangerText }]}>Remove</Text></Pressable></View>
        {exercise.description && <Body>{exercise.description}</Body>}
        {(exercise.instructions ?? []).map((instruction, index) => <Body key={`${exercise.id}-instruction-${index}`}>{index + 1}. {instruction}</Body>)}
        <View style={styles.inputs}><View style={styles.inputGroup}><Text style={[styles.inputLabel, { color: theme.colors.inkMuted }]}>Sets</Text><TextInput accessibilityLabel={`${exercise.name} sets`} value={sets} onChangeText={(value) => update(exercise.id, 'sets', value)} keyboardType="number-pad" style={[styles.input, { color: theme.colors.ink, backgroundColor: theme.colors.surface, borderColor: theme.colors.border }]} /></View><View style={styles.inputGroup}><Text style={[styles.inputLabel, { color: theme.colors.inkMuted }]}>{isTimed(exercise) ? 'Seconds per set' : 'Reps per set'}</Text><TextInput accessibilityLabel={`${exercise.name} ${isTimed(exercise) ? 'seconds' : 'repetitions'} per set`} value={target} onChangeText={(value) => update(exercise.id, 'target', value)} keyboardType="number-pad" style={[styles.input, { color: theme.colors.ink, backgroundColor: theme.colors.surface, borderColor: theme.colors.border }]} /></View></View>
        {(exercise.measurement_type === 'reps_weight' || exercise.measurement_type === 'time_distance') && <View style={styles.inputGroup}><Text style={[styles.inputLabel, { color: theme.colors.inkMuted }]}>{exercise.measurement_type === 'reps_weight' ? 'Weight in kg (optional)' : 'Distance in km (optional)'}</Text><TextInput accessibilityLabel={`${exercise.name} ${exercise.measurement_type === 'reps_weight' ? 'weight in kilograms' : 'distance in kilometres'}`} value={extra} onChangeText={(value) => update(exercise.id, 'extra', value)} keyboardType="decimal-pad" style={[styles.input, { color: theme.colors.ink, backgroundColor: theme.colors.surface, borderColor: theme.colors.border }]} /></View>}
      </View>)}
    </Panel>}
    <Panel><Eyebrow>Exercise library</Eyebrow><Field label="Search exercises" value={query} onChangeText={setQuery} placeholder="Search by name" autoCapitalize="none" />
      {loading && <ActivityIndicator color={theme.colors.action} />}
      {!loading && matching.length === 0 && <Body>No exercises found.</Body>}
      {matching.slice(0, 40).map((exercise) => {
        const added = selected.some((item) => item.exercise.id === exercise.id);
        return <Pressable key={exercise.id} accessibilityRole="checkbox" accessibilityState={{ checked: added }} onPress={() => toggle(exercise)} style={[styles.catalogRow, { borderBottomColor: theme.colors.border }]}>
          <View style={sharedStyles.grow}><Label>{exercise.name}</Label><Body>{exercise.muscle_group || (isTimed(exercise) ? 'Timed exercise' : 'Repetition exercise')}</Body>{exercise.description && <Body>{exercise.description}</Body>}</View>
          <Text style={[styles.choice, { color: added ? theme.colors.successText : theme.colors.action }]}>{added ? 'Added' : 'Add'}</Text>
        </Pressable>;
      })}
      {matching.length > 40 && <Body>Showing the first 40 results. Search to narrow the list.</Body>}
    </Panel>
    {error && <ErrorText>{error}</ErrorText>}
    <Button label={planId ? 'Save plan changes' : 'Save workout plan'} onPress={() => void save()} busy={saving} disabled={loading} />
  </Screen>;
}

const styles = StyleSheet.create({
  selected: { gap: 10, paddingBottom: 14, borderBottomWidth: StyleSheet.hairlineWidth },
  remove: { fontWeight: '700', padding: 8 },
  inputs: { flexDirection: 'row', gap: 12 },
  days: { flexDirection: 'row', flexWrap: 'wrap', gap: 8 },
  dayChoice: { minWidth: 48, minHeight: 44, alignItems: 'center', justifyContent: 'center', borderWidth: 1, borderRadius: 10 },
  dayLabel: { fontSize: 13, fontWeight: '700' },
  inputGroup: { flex: 1, gap: 6 },
  inputLabel: { fontSize: 12 },
  input: { minHeight: 44, borderWidth: 1, borderRadius: 10, paddingHorizontal: 12, fontSize: 16 },
  catalogRow: { minHeight: 55, flexDirection: 'row', alignItems: 'center', gap: 12, paddingVertical: 9, borderBottomWidth: StyleSheet.hairlineWidth },
  choice: { fontWeight: '800', padding: 8 },
});
