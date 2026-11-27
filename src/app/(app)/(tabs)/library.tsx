import MaterialIcons from '@expo/vector-icons/MaterialIcons';
import { router, type Href } from 'expo-router';
import { useCallback, useEffect, useState } from 'react';
import { ActivityIndicator, FlatList, I18nManager, Pressable, StyleSheet, View } from 'react-native';
import { Body, Button, ErrorText, Eyebrow, Field, Heading, Label, LocalizedText as Text, Panel, Screen, sharedStyles, useIsDesktopColumns } from '../../../components/bloom-ui';
import { ExerciseArtwork } from '../../../components/exercise-artwork';
import { createCustomExercise, loadCatalogPage, loadExercise, type Exercise, type Measurement } from '../../../lib/bloom';
import { useBloomTheme } from '../../../lib/theme-context';

type Filter = 'all' | 'reps' | 'timed';
const PAGE_SIZE = 25;

function isTimed(exercise: Exercise) {
  return exercise.measurement_type === 'time_only' || exercise.measurement_type === 'time_distance';
}

export default function ExerciseLibraryScreen() {
  const { theme } = useBloomTheme();
  const exerciseColors = theme.modules.exercise;
  const desktopColumns = useIsDesktopColumns();
  const [exercises, setExercises] = useState<Exercise[]>([]);
  const [hasMore, setHasMore] = useState(false);
  const [loadingMore, setLoadingMore] = useState(false);
  const [selectedId, setSelectedId] = useState<string | null>(null);
  const [selectedDetail, setSelectedDetail] = useState<Exercise | null>(null);
  const [focusedId, setFocusedId] = useState<string | null>(null);
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

  const loadFirstPage = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const page = await loadCatalogPage({ limit: PAGE_SIZE, offset: 0, query, filter });
      setExercises(page.exercises);
      setHasMore(page.hasMore);
    } catch {
      setError('Could not load the exercise library. Check your connection and try again.');
    } finally {
      setLoading(false);
    }
  }, [filter, query]);

  // Fetch catalog data when filter/query changes.
  // eslint-disable-next-line react-hooks/set-state-in-effect
  useEffect(() => { void loadFirstPage(); }, [loadFirstPage]);

  useEffect(() => {
    let active = true;
    if (!selectedId || !desktopColumns) {
      return () => { active = false; };
    }
    void loadExercise(selectedId).then((detail) => {
      if (active && detail) setSelectedDetail(detail);
    }).catch(() => undefined);
    return () => { active = false; };
  }, [desktopColumns, selectedId]);

  async function loadNextPage() {
    if (loadingMore || !hasMore) return;
    setLoadingMore(true);
    try {
      const page = await loadCatalogPage({ limit: PAGE_SIZE, offset: exercises.length, query, filter });
      setExercises((current) => [...current, ...page.exercises]);
      setHasMore(page.hasMore);
    } catch {
      setError('Could not load more exercises. Check your connection and try again.');
    } finally {
      setLoadingMore(false);
    }
  }

  const selectedExercise = selectedDetail?.id === selectedId
    ? selectedDetail
    : exercises.find((exercise) => exercise.id === selectedId) ?? null;

  function openExercise(exercise: Exercise) {
    router.push({ pathname: '/exercise/[id]', params: { id: exercise.id } } as unknown as Href);
  }

  async function saveExercise() {
    if (!name.trim() || name.trim().length > 100) { setFormError('Enter a name of up to 100 characters.'); return; }
    setSaving(true); setFormError(null);
    try {
      await createCustomExercise(name, description, measurement);
      setName(''); setDescription(''); setMeasurement('reps_only'); setCreating(false);
      await loadFirstPage();
    } catch { setFormError('Could not save the exercise. Check your connection and try again.'); }
    finally { setSaving(false); }
  }

  return <Screen safeAreaTop={false}>
    <View style={sharedStyles.column}><Eyebrow>Move with confidence</Eyebrow><Heading>Exercise library</Heading><Body>Browse the exercise catalog, read the instructions, and add an exercise straight to a workout plan.</Body></View>
    <View style={[styles.libraryWorkspace, desktopColumns && styles.libraryWorkspaceDesktop]}>
    <View style={[styles.catalogColumn, desktopColumns && styles.catalogColumnDesktop]}>
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
    {error && <Panel><ErrorText>{error}</ErrorText><Button label="Try again" onPress={() => void loadFirstPage()} /></Panel>}
    {!loading && !error && exercises.length === 0 && <Panel><Label>No exercises found</Label><Body>Try a different search or exercise type.</Body></Panel>}
    {!loading && !error && exercises.length > 0 && <FlatList
      data={exercises}
      keyExtractor={(exercise) => exercise.id}
      scrollEnabled={false}
      initialNumToRender={12}
      maxToRenderPerBatch={12}
      windowSize={5}
      renderItem={({ item: exercise }) => (
        <Pressable
          onPress={() => desktopColumns ? setSelectedId(exercise.id) : openExercise(exercise)}
          accessibilityRole="button"
          accessibilityLabel={`${desktopColumns ? 'Select' : 'View'} ${exercise.name}`}
          accessibilityState={{ selected: selectedId === exercise.id }}
          onFocus={() => setFocusedId(exercise.id)}
          onBlur={() => setFocusedId((current) => current === exercise.id ? null : current)}
          style={[styles.exerciseChoice, { borderColor: focusedId === exercise.id ? theme.colors.focusRing : selectedId === exercise.id && desktopColumns ? exerciseColors.deep : 'transparent' }]}
        >
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
        </Pressable>
      )}
      ListFooterComponent={hasMore ? <Button label={loadingMore ? 'Loading…' : 'Load more exercises'} secondary busy={loadingMore} onPress={() => void loadNextPage()} /> : undefined}
    />}
    </View>
    {desktopColumns && <View style={styles.detailColumn}>
      <Panel>
        {selectedExercise ? <>
          <ExerciseArtwork exercise={selectedExercise} size="large" />
          <View style={sharedStyles.column}>
            <Eyebrow>{selectedExercise.muscle_groups?.length ? selectedExercise.muscle_groups.join(' · ') : selectedExercise.muscle_group || 'Exercise'}</Eyebrow>
            <Heading>{selectedExercise.name}</Heading>
            <Body>{isTimed(selectedExercise) ? 'Time-based targets' : selectedExercise.measurement_type === 'reps_weight' ? 'Repetitions and weight targets' : 'Repetition targets'}</Body>
          </View>
          {selectedExercise.description && <View style={sharedStyles.column}><Label>About this exercise</Label><Body>{selectedExercise.description}</Body></View>}
          <View style={sharedStyles.column}>
            <Label>Instructions</Label>
            {selectedExercise.instructions?.length ? selectedExercise.instructions.map((instruction, index) => <View key={`${selectedExercise.id}-${index}`} style={sharedStyles.row}>
              <Label>{index + 1}.</Label><View style={sharedStyles.grow}><Body>{instruction}</Body></View>
            </View>) : <Body>Written instructions are not available for this exercise yet.</Body>}
          </View>
          <Button label="Add to a workout plan" onPress={() => router.push({ pathname: '/new-plan', params: { exerciseId: selectedExercise.id } })} />
          <Button label="Open full exercise details" secondary onPress={() => openExercise(selectedExercise)} />
        </> : <View style={sharedStyles.column}><Eyebrow>Exercise details</Eyebrow><Label>Select a movement</Label><Body>Choose an exercise from the catalog to review its instructions and add it to a plan.</Body></View>}
      </Panel>
    </View>}
    </View>
  </Screen>;
}

const styles = StyleSheet.create({
  libraryWorkspace: { gap: 16 },
  libraryWorkspaceDesktop: { flexDirection: 'row', alignItems: 'flex-start' },
  catalogColumn: { minWidth: 0 },
  catalogColumnDesktop: { flex: 1, minWidth: 320 },
  detailColumn: { flex: 1.05, minWidth: 340 },
  exerciseChoice: { borderWidth: 2, borderRadius: 22, marginBottom: 8 },
  filters: { flexDirection: 'row', gap: 8, flexWrap: 'wrap' },
  exerciseRow: { flexDirection: 'row', alignItems: 'center', gap: 12 },
  filter: { minHeight: 44, paddingHorizontal: 14, justifyContent: 'center', borderWidth: 1, borderRadius: 20 },
  filterText: { fontWeight: '700', fontSize: 13 },
  directionalIcon: { transform: [{ scaleX: -1 }] },
});
