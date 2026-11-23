import MaterialIcons from '@expo/vector-icons/MaterialIcons';
import { router, type Href } from 'expo-router';
import { useCallback, useEffect, useMemo, useState } from 'react';
import { ActivityIndicator, I18nManager, Pressable, StyleSheet, View } from 'react-native';
import { Body, Button, ErrorText, Eyebrow, Field, Heading, Label, Panel, Screen, sharedStyles, LocalizedText as Text } from '../../../components/bloom-ui';
import { ExerciseArtwork } from '../../../components/exercise-artwork';
import { createCustomExercise, loadCatalog, type Exercise, type Measurement } from '../../../lib/bloom';
import { useBloomTheme } from '../../../lib/theme-context';

type Filter = 'all' | 'reps' | 'timed';

function isTimed(exercise: Exercise) {
  return exercise.measurement_type === 'time_only' || exercise.measurement_type === 'time_distance';
}

export default function ExerciseLibraryScreen() {
  const { theme } = useBloomTheme();
  const exerciseColors = theme.modules.exercise;
  const [exercises, setExercises] = useState<Exercise[]>([]);
  const [query, setQuery] = useState('');
  const [filter, setFilter] = useState<Filter>('all');
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [creating, setCreating] = useState(false);
  const [saving, setSaving] = useState(false);
  const [name, setName] = useState('');
  const [description, setDescription] = useState('');
  const [measurement, setMeasurement] = useState<Measurement>('reps_only');
  const [formError, setFormError] = useState<string | null>(null);

  const load = useCallback(async () => {
    setLoading(true);
    setError(null);
    try { setExercises(await loadCatalog()); }
    catch { setError('Could not load the exercise library. Check your connection and try again.'); }
    finally { setLoading(false); }
  }, []);

  // Fetch catalog data on screen mount.
  // eslint-disable-next-line react-hooks/set-state-in-effect
  useEffect(() => { void load(); }, [load]);

  const matching = useMemo(() => {
    const term = query.trim().toLowerCase();
    return exercises.filter((exercise) => {
      if (filter === 'timed' && !isTimed(exercise)) return false;
      if (filter === 'reps' && isTimed(exercise)) return false;
      return !term || [exercise.name, exercise.description ?? '', exercise.muscle_group ?? '', ...(exercise.muscle_groups ?? [])]
        .some((value) => value.toLowerCase().includes(term));
    });
  }, [exercises, filter, query]);

  function openExercise(exercise: Exercise) {
    router.push({ pathname: '/exercise/[id]', params: { id: exercise.id } } as unknown as Href);
  }

  async function saveExercise() {
    if (!name.trim() || name.trim().length > 100) { setFormError('Enter a name of up to 100 characters.'); return; }
    setSaving(true); setFormError(null);
    try {
      await createCustomExercise(name, description, measurement);
      setName(''); setDescription(''); setMeasurement('reps_only'); setCreating(false);
      await load();
    } catch { setFormError('Could not save the exercise. Check your connection and try again.'); }
    finally { setSaving(false); }
  }

  return <Screen safeAreaTop={false}>
    <View style={sharedStyles.column}><Eyebrow>Move with confidence</Eyebrow><Heading>Exercise library</Heading><Body>Browse the exercise catalog, read the instructions, and add an exercise straight to a workout plan.</Body></View>
    {creating ? <Panel>
      <Label>New custom exercise</Label>
      <Body>Only you and an authorized parent can see this exercise. It will be available on your devices.</Body>
      <Field label="Exercise name" value={name} onChangeText={setName} maxLength={100} />
      <Field label="Description (optional)" value={description} onChangeText={setDescription} maxLength={1000} multiline />
      <Label>Measurement</Label>
      <View style={styles.filters} accessibilityRole="radiogroup" accessibilityLabel="Exercise measurement">
        {([['reps_only', 'Repetitions'], ['reps_weight', 'Reps and weight'], ['time_only', 'Time'], ['time_distance', 'Time and distance']] as const).map(([value, label]) => <Pressable key={value} accessibilityRole="radio" accessibilityState={{ checked: measurement === value }} onPress={() => setMeasurement(value)} style={[styles.filter, { backgroundColor: theme.colors.surface, borderColor: theme.colors.border }, measurement === value && { backgroundColor: exerciseColors.deep, borderColor: exerciseColors.deep }]}><Text style={[styles.filterText, { color: theme.colors.ink }, measurement === value && { color: '#FFFFFF' }]}>{label}</Text></Pressable>)}
      </View>
      {formError && <ErrorText>{formError}</ErrorText>}
      <Button label="Save exercise" onPress={() => void saveExercise()} busy={saving} />
      <Button label="Cancel" secondary onPress={() => { setCreating(false); setFormError(null); }} disabled={saving} />
    </Panel> : <Button label="Create custom exercise" secondary onPress={() => setCreating(true)} />}
    <Field label="Search exercises" value={query} onChangeText={setQuery} placeholder="Name, description, or muscle group" autoCapitalize="none" />
    <View style={styles.filters} accessibilityRole="radiogroup" accessibilityLabel="Filter by exercise type">
      {([['all', 'All'], ['reps', 'Repetitions'], ['timed', 'Timed']] as const).map(([value, label]) => {
        const selected = filter === value;
        return <Pressable key={value} accessibilityRole="radio" accessibilityState={{ checked: selected }} onPress={() => setFilter(value)} style={[styles.filter, { backgroundColor: theme.colors.surface, borderColor: theme.colors.border }, selected && { backgroundColor: exerciseColors.deep, borderColor: exerciseColors.deep }]}>
          <Text style={[styles.filterText, { color: theme.colors.ink }, selected && { color: '#FFFFFF' }]}>{label}</Text>
        </Pressable>;
      })}
    </View>
    {loading && <ActivityIndicator color={exerciseColors.deep} />}
    {error && <Panel><ErrorText>{error}</ErrorText><Button label="Try again" onPress={() => void load()} /></Panel>}
    {!loading && !error && matching.length === 0 && <Panel><Label>No exercises found</Label><Body>Try a different search or exercise type.</Body></Panel>}
    {!loading && !error && matching.map((exercise) => <Pressable key={exercise.id} onPress={() => openExercise(exercise)} accessibilityRole="button" accessibilityLabel={`View ${exercise.name}`}>
      <Panel>
        <View style={styles.exerciseRow}>
          <ExerciseArtwork exercise={exercise} size="small" />
          <View style={sharedStyles.grow}>
            <Label>{exercise.name}</Label>
            <Body>{exercise.bloom_owner_user_id ? 'Custom exercise' : exercise.muscle_groups?.length ? exercise.muscle_groups.join(' · ') : exercise.muscle_group || (isTimed(exercise) ? 'Timed exercise' : 'Repetition exercise')}</Body>
          </View>
          <MaterialIcons name="chevron-right" color={theme.colors.inkMuted} size={24} style={I18nManager.isRTL ? styles.directionalIcon : undefined} />
        </View>
        {exercise.description && <Body>{exercise.description}</Body>}
        <Body>{isTimed(exercise) ? 'Time-based targets' : exercise.measurement_type === 'reps_weight' ? 'Repetitions and weight targets' : 'Repetition targets'}</Body>
      </Panel>
    </Pressable>)}
  </Screen>;
}

const styles = StyleSheet.create({
  filters: { flexDirection: 'row', gap: 8, flexWrap: 'wrap' },
  exerciseRow: { flexDirection: 'row', alignItems: 'center', gap: 12 },
  filter: { minHeight: 44, paddingHorizontal: 14, justifyContent: 'center', borderWidth: 1, borderRadius: 20 },
  filterText: { fontWeight: '700', fontSize: 13 },
  directionalIcon: { transform: [{ scaleX: -1 }] },
});
