import MaterialIcons from '@expo/vector-icons/MaterialIcons';
import { router, useLocalSearchParams } from 'expo-router';
import { useEffect, useMemo, useState } from 'react';
import { ActivityIndicator, Modal, Pressable, ScrollView, StyleSheet, View } from 'react-native';
import { Body, Button, ErrorText, Eyebrow, Heading, Label, Panel, Screen, sharedStyles, LocalizedText as Text, LocalizedTextInput as TextInput } from '../../components/bloom-ui';
import { ExerciseArtwork } from '../../components/exercise-artwork';
import { createPlan, createPlanForUser, loadCatalog, loadWorkoutPlan, SCHEDULE_DAYS, updatePlan, updatePlanForUser, type Exercise } from '../../lib/bloom';
import { useBloom } from '../../lib/bloom-context';
import { useBloomTheme } from '../../lib/theme-context';

type Selection = { exercise: Exercise; sets: string; target: string; extra: string };
type Step = 1 | 2;
type ExerciseTypeFilter = 'all' | 'reps' | 'timed';
type ExerciseSort = 'name' | 'muscle';

function isTimed(exercise: Exercise) {
  return exercise.measurement_type === 'time_only' || exercise.measurement_type === 'time_distance';
}

function initialSelection(exercise: Exercise): Selection {
  const timed = isTimed(exercise);
  return { exercise, sets: timed ? '1' : '3', target: timed ? '60' : '10', extra: '' };
}

export default function NewPlanScreen() {
  const { childId, exerciseId, planId } = useLocalSearchParams<{ childId?: string; exerciseId?: string; planId?: string }>();
  const { refresh } = useBloom();
  const { theme } = useBloomTheme();
  const exerciseColors = theme.modules.exercise;
  const [step, setStep] = useState<Step>(1);
  const [title, setTitle] = useState('');
  const [query, setQuery] = useState('');
  const [catalog, setCatalog] = useState<Exercise[]>([]);
  const [selected, setSelected] = useState<Selection[]>([]);
  const [scheduledDays, setScheduledDays] = useState<number[]>([]);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [filtersOpen, setFiltersOpen] = useState(false);
  const [typeFilter, setTypeFilter] = useState<ExerciseTypeFilter>('all');
  const [muscleFilter, setMuscleFilter] = useState<string | null>(null);
  const [sortBy, setSortBy] = useState<ExerciseSort>('name');
  const [infoExercise, setInfoExercise] = useState<Exercise | null>(null);

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
        if (exercise) setSelected([initialSelection(exercise)]);
      }
    })
      .catch(() => { if (active) setError('Could not load the exercise library. Check your connection and try again.'); })
      .finally(() => { if (active) setLoading(false); });
    return () => { active = false; };
  }, [childId, exerciseId, planId]);

  const muscleGroups = useMemo(() => [...new Set(catalog.map((exercise) => exercise.muscle_group?.trim()).filter((group): group is string => Boolean(group)))].sort((a, b) => a.localeCompare(b)), [catalog]);
  const matching = useMemo(() => {
    const term = query.trim().toLocaleLowerCase();
    return catalog.filter((exercise) => {
      if (typeFilter === 'timed' && !isTimed(exercise)) return false;
      if (typeFilter === 'reps' && isTimed(exercise)) return false;
      if (muscleFilter && exercise.muscle_group?.trim() !== muscleFilter) return false;
      return !term || [exercise.name, exercise.description ?? '', exercise.muscle_group ?? '']
        .some((value) => value.toLocaleLowerCase().includes(term));
    }).sort((a, b) => sortBy === 'muscle'
      ? (a.muscle_group ?? '').localeCompare(b.muscle_group ?? '') || a.name.localeCompare(b.name)
      : a.name.localeCompare(b.name));
  }, [catalog, muscleFilter, query, sortBy, typeFilter]);

  const activeFilterCount = Number(typeFilter !== 'all') + Number(muscleFilter !== null);

  function toggle(exercise: Exercise) {
    const alreadySelected = selected.some((item) => item.exercise.id === exercise.id);
    if (!alreadySelected && selected.length >= 50) {
      setError('A plan can contain up to 50 exercises.');
      return;
    }
    setError(null);
    setSelected((current) => {
      if (current.some((item) => item.exercise.id === exercise.id)) {
        return current.filter((item) => item.exercise.id !== exercise.id);
      }
      return [...current, initialSelection(exercise)];
    });
  }

  function update(id: string, field: 'sets' | 'target' | 'extra', value: string) {
    setSelected((current) => current.map((item) => item.exercise.id === id ? { ...item, [field]: value } : item));
  }

  function toggleDay(day: number) {
    setScheduledDays((current) => current.includes(day) ? current.filter((item) => item !== day) : [...current, day]);
  }

  function continueToExercises() {
    if (!title.trim() || title.trim().length > 100) { setError('Enter a plan name of up to 100 characters.'); return; }
    setError(null);
    setStep(2);
  }

  function goBack() {
    if (router.canGoBack()) router.back();
    else router.replace(childId ? '/family' : '/workouts');
  }

  async function save() {
    if (!title.trim() || title.trim().length > 100) { setError('Enter a plan name of up to 100 characters.'); setStep(1); return; }
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
      } else if (childId) {
        await createPlanForUser(childId, title, exercises, scheduledDays);
        router.back();
      } else {
        await createPlan(title, exercises, scheduledDays);
        await refresh();
        router.replace('/workouts');
      }
    } catch { setError('Could not save your plan. Check your connection and try again.'); }
    finally { setSaving(false); }
  }

  function clearFilters() {
    setTypeFilter('all');
    setMuscleFilter(null);
    setSortBy('name');
  }

  return <Screen safeAreaTop={false}>
    <View style={styles.headerRow}>
      <Pressable accessibilityRole="button" accessibilityLabel="Go back" accessibilityHint="Returns to the previous screen."
        hitSlop={6} onPress={goBack} style={({ pressed }) => [styles.backButton, { borderColor: theme.colors.border, backgroundColor: theme.colors.surface }, pressed && styles.pressed]}>
        <MaterialIcons name="arrow-back" size={22} color={exerciseColors.deep} />
      </Pressable>
      <View style={sharedStyles.grow}>
        <Eyebrow>Workout builder</Eyebrow>
        <Heading>{planId ? 'Edit a plan' : 'Create a plan'}</Heading>
      </View>
    </View>

    <View accessibilityRole="tablist" accessibilityLabel="Plan setup steps" style={styles.steps}>
      {([
        { id: 1 as const, label: 'Basic setup' },
        { id: 2 as const, label: 'Exercises' },
      ]).map(({ id, label }) => {
        const active = step === id;
        const canOpen = id === 1 || Boolean(title.trim());
        return <Pressable key={id} accessibilityRole="tab" accessibilityState={{ selected: active, disabled: !canOpen }} disabled={!canOpen}
          accessibilityLabel={`Step ${id}: ${label}${active ? ', current step' : ''}`}
          onPress={() => id === 1 ? setStep(1) : continueToExercises()}
          style={[styles.stepItem, { borderColor: active ? exerciseColors.deep : theme.colors.border, backgroundColor: active ? exerciseColors.surface : theme.colors.surface }]}>
          <View style={[styles.stepNumber, { backgroundColor: active ? exerciseColors.deep : theme.colors.surfaceSoft }]}>
            <Text style={[styles.stepNumberText, { color: active ? '#FFFFFF' : theme.colors.inkMuted }]}>{id}</Text>
          </View>
          <Text style={[styles.stepLabel, { color: active ? exerciseColors.deep : theme.colors.inkMuted }]}>{label}</Text>
        </Pressable>;
      })}
    </View>

    {step === 1 ? <>
      <Panel>
        <View style={styles.nameField}>
          <TextInput accessibilityLabel="Plan name" value={title} onChangeText={setTitle} placeholder="Give your plan a name"
            placeholderTextColor={theme.colors.inkMuted} maxLength={100} returnKeyType="done"
            style={[styles.planNameInput, { color: theme.colors.ink, borderColor: theme.colors.borderStrong, backgroundColor: theme.colors.surface }]} />
        </View>
        <View style={[styles.sectionDivider, { borderColor: theme.colors.border }]} />
        <View style={sharedStyles.column}>
          <Label>Weekly schedule</Label>
          <Body>Choose the days you plan to do this workout. Other days stay flexible for rest or recovery.</Body>
          <View style={styles.days} accessibilityRole="group" accessibilityLabel="Workout days">
            {SCHEDULE_DAYS.map(({ label, iso }) => {
              const selectedDay = scheduledDays.includes(iso);
              return <Pressable key={iso} accessibilityRole="checkbox" accessibilityLabel={label} accessibilityState={{ checked: selectedDay }} onPress={() => toggleDay(iso)}
                style={[styles.dayChoice, { borderColor: selectedDay ? exerciseColors.deep : theme.colors.border, backgroundColor: selectedDay ? exerciseColors.deep : theme.colors.surface }]}>
                <Text style={[styles.dayLabel, { color: selectedDay ? '#FFFFFF' : theme.colors.ink }]}>{label}</Text>
              </Pressable>;
            })}
          </View>
        </View>
      </Panel>
      {error && <ErrorText>{error}</ErrorText>}
      <Button label="Choose exercises" onPress={continueToExercises} disabled={loading} />
      {loading && <ActivityIndicator color={exerciseColors.deep} />}
    </> : <>
      <View style={styles.sectionHeading}>
        <View style={sharedStyles.grow}>
          <Eyebrow>{selected.length} selected</Eyebrow>
          <Heading>Build your workout</Heading>
        </View>
        <Pressable accessibilityRole="button" accessibilityLabel={`Filter and sort exercises${activeFilterCount ? `, ${activeFilterCount} filters active` : ''}`}
          accessibilityHint="Opens exercise type, muscle group, and sorting options." onPress={() => setFiltersOpen(true)}
          style={({ pressed }) => [styles.filterButton, { borderColor: theme.colors.border, backgroundColor: theme.colors.surface }, pressed && styles.pressed]}>
          <MaterialIcons name="tune" size={19} color={exerciseColors.deep} />
          <Text style={[styles.filterButtonText, { color: exerciseColors.deep }]}>Filter & sort{activeFilterCount ? ` · ${activeFilterCount}` : ''}</Text>
        </Pressable>
      </View>

      {selected.length > 0 && <View style={styles.selectedList}>
        {selected.map(({ exercise, sets, target, extra }, index) => <View key={exercise.id} style={[styles.exerciseConfig, { borderColor: theme.colors.border, backgroundColor: theme.colors.surface }]}>
          <View style={styles.exerciseHeading}>
            <ExerciseArtwork exercise={exercise} size="small" />
            <View style={sharedStyles.grow}>
              <Eyebrow>Exercise {index + 1}</Eyebrow>
              <Label>{exercise.name}</Label>
              <Body>{exercise.muscle_group || (isTimed(exercise) ? 'Timed exercise' : 'Repetition exercise')}</Body>
            </View>
            <View style={styles.iconActions}>
              <Pressable accessibilityRole="button" accessibilityLabel={`More information about ${exercise.name}`} accessibilityHint="Opens the exercise image and instructions."
                onPress={() => setInfoExercise(exercise)} style={({ pressed }) => [styles.infoButton, { backgroundColor: exerciseColors.surface }, pressed && styles.pressed]}>
                <MaterialIcons name="help-outline" size={21} color={exerciseColors.deep} />
              </Pressable>
              <Pressable accessibilityRole="button" accessibilityLabel={`Remove ${exercise.name}`} onPress={() => toggle(exercise)}
                style={({ pressed }) => [styles.removeButton, { backgroundColor: theme.colors.surfaceSoft }, pressed && styles.pressed]}>
                <MaterialIcons name="close" size={20} color={theme.colors.inkMuted} />
              </Pressable>
            </View>
          </View>

          <View style={[styles.prescription, { backgroundColor: exerciseColors.surface }]}>
            <View style={styles.prescriptionHeading}>
              <Text style={[styles.prescriptionTitle, { color: exerciseColors.deep }]}>Set your target</Text>
              <Text style={[styles.prescriptionHint, { color: theme.colors.inkMuted }]}>Adjust each movement to your routine</Text>
            </View>
            <View style={styles.stepperRow}>
              <NumberStepper label="Sets" value={sets} onChange={(value) => update(exercise.id, 'sets', value)} unit="sets" min={1} max={20} step={1} decimals={0} />
              <NumberStepper label={isTimed(exercise) ? 'Duration' : 'Repetitions'} value={target} onChange={(value) => update(exercise.id, 'target', value)}
                unit={isTimed(exercise) ? 'sec' : 'reps'} min={1} max={isTimed(exercise) ? 86400 : 1000} step={isTimed(exercise) ? 5 : 1} decimals={0} />
            </View>
            {(exercise.measurement_type === 'reps_weight' || exercise.measurement_type === 'time_distance') && <NumberStepper
              label={exercise.measurement_type === 'reps_weight' ? 'Weight' : 'Distance'} value={extra} onChange={(value) => update(exercise.id, 'extra', value)}
              unit={exercise.measurement_type === 'reps_weight' ? 'kg' : 'km'} min={exercise.measurement_type === 'reps_weight' ? 0 : 0.1} max={1000} step={exercise.measurement_type === 'reps_weight' ? 2.5 : 0.1} decimals={1} optional />}
          </View>
        </View>)}
      </View>}

      <Panel>
        <View style={sharedStyles.column}>
          <View><Eyebrow>Exercise library</Eyebrow><Label>Choose movements</Label></View>
          <TextInput accessibilityLabel="Search exercises" value={query} onChangeText={setQuery} placeholder="Search by name or muscle group"
            placeholderTextColor={theme.colors.inkMuted} autoCapitalize="none" style={[styles.searchInput, { borderColor: theme.colors.borderStrong, color: theme.colors.ink, backgroundColor: theme.colors.surface }]} />
          {loading && <ActivityIndicator color={exerciseColors.deep} />}
          {!loading && matching.length === 0 && <Body>No exercises match these filters. Adjust the search or filter options.</Body>}
          {matching.slice(0, 40).map((exercise) => {
            const added = selected.some((item) => item.exercise.id === exercise.id);
            return <Pressable key={exercise.id} accessibilityRole="checkbox" accessibilityState={{ checked: added }} onPress={() => toggle(exercise)}
              style={[styles.catalogRow, { borderBottomColor: theme.colors.border, backgroundColor: added ? exerciseColors.surface : theme.colors.surface }]}>
              <ExerciseArtwork exercise={exercise} size="small" />
              <View style={sharedStyles.grow}>
                <Label>{exercise.name}</Label>
                <Body>{exercise.muscle_group || (isTimed(exercise) ? 'Timed exercise' : 'Repetition exercise')}</Body>
              </View>
              <View style={[styles.addMarker, { borderColor: added ? exerciseColors.deep : theme.colors.border, backgroundColor: added ? exerciseColors.deep : theme.colors.surface }]}>
                <MaterialIcons name={added ? 'check' : 'add'} size={19} color={added ? '#FFFFFF' : exerciseColors.deep} />
              </View>
            </Pressable>;
          })}
          {matching.length > 40 && <Body>Showing the first 40 results. Search or filter to narrow the list.</Body>}
        </View>
      </Panel>
      {error && <ErrorText>{error}</ErrorText>}
      <View style={styles.footerActions}>
        <Button label="Back to basic setup" variant="secondary" onPress={() => { setError(null); setStep(1); }} disabled={saving} />
        <Button label={planId ? 'Save plan changes' : 'Save workout plan'} onPress={() => void save()} busy={saving} disabled={loading} />
      </View>
    </>}

    <Modal visible={filtersOpen} transparent animationType="slide" onRequestClose={() => setFiltersOpen(false)} statusBarTranslucent>
      <View style={styles.modalFrame}>
        <Pressable accessibilityRole="button" accessibilityLabel="Close exercise filters" style={StyleSheet.absoluteFill} onPress={() => setFiltersOpen(false)} />
        <View style={[styles.filterSheet, { backgroundColor: theme.colors.surface, borderColor: theme.colors.border }]}>
          <View style={styles.sheetHeader}>
            <View style={sharedStyles.grow}><Eyebrow>Exercise library</Eyebrow><Heading>Filter & sort</Heading></View>
            <Pressable accessibilityRole="button" accessibilityLabel="Close" onPress={() => setFiltersOpen(false)} style={[styles.closeButton, { backgroundColor: theme.colors.surfaceSoft }]}>
              <MaterialIcons name="close" size={21} color={theme.colors.inkMuted} />
            </Pressable>
          </View>
          <ScrollView contentContainerStyle={styles.sheetContent}>
            <View style={styles.filterGroup}>
              <Label>Exercise type</Label>
              <View style={styles.filterChips} accessibilityRole="radiogroup" accessibilityLabel="Filter by exercise type">
                {([{ id: 'all', label: 'All types' }, { id: 'reps', label: 'Repetition based' }, { id: 'timed', label: 'Timed' }] as const).map((item) => {
                  const checked = typeFilter === item.id;
                  return <FilterChip key={item.id} label={item.label} selected={checked} onPress={() => setTypeFilter(item.id)} />;
                })}
              </View>
            </View>
            {muscleGroups.length > 0 && <View style={styles.filterGroup}>
              <Label>Muscle group</Label>
              <View style={styles.filterChips} accessibilityRole="radiogroup" accessibilityLabel="Filter by catalog muscle group">
                <FilterChip label="All groups" selected={muscleFilter === null} onPress={() => setMuscleFilter(null)} />
                {muscleGroups.map((group) => <FilterChip key={group} label={group} selected={muscleFilter === group} onPress={() => setMuscleFilter(group)} />)}
              </View>
            </View>}
            <View style={styles.filterGroup}>
              <Label>Sort by</Label>
              <View style={styles.filterChips} accessibilityRole="radiogroup" accessibilityLabel="Sort exercises">
                <FilterChip label="Name A to Z" selected={sortBy === 'name'} onPress={() => setSortBy('name')} />
                <FilterChip label="Muscle group" selected={sortBy === 'muscle'} onPress={() => setSortBy('muscle')} />
              </View>
            </View>
          </ScrollView>
          <View style={styles.sheetFooter}>
            <Button label="Clear filters" variant="secondary" onPress={clearFilters} />
            <Button label={`Show ${matching.length} exercises`} onPress={() => setFiltersOpen(false)} />
          </View>
        </View>
      </View>
    </Modal>

    <Modal visible={infoExercise !== null} transparent animationType="fade" onRequestClose={() => setInfoExercise(null)}>
      <View style={styles.infoModalFrame}>
        <Pressable accessibilityRole="button" accessibilityLabel="Close exercise information" style={StyleSheet.absoluteFill} onPress={() => setInfoExercise(null)} />
        <View style={[styles.infoDialog, { backgroundColor: theme.colors.surface, borderColor: theme.colors.border }]}>
          <ScrollView contentContainerStyle={styles.infoContent}>
            {infoExercise && <>
              <ExerciseArtwork exercise={infoExercise} size="large" />
              <View style={sharedStyles.column}>
                <Eyebrow>{infoExercise.muscle_group || (isTimed(infoExercise) ? 'Timed exercise' : 'Repetition exercise')}</Eyebrow>
                <Heading>{infoExercise.name}</Heading>
                {infoExercise.description && <Body>{infoExercise.description}</Body>}
              </View>
              <View style={sharedStyles.column}>
                <Label>How to do it</Label>
                {infoExercise.instructions?.length ? infoExercise.instructions.map((instruction, index) => <View key={`${infoExercise.id}-step-${index}`} style={styles.instructionRow}>
                  <View style={[styles.instructionNumber, { backgroundColor: exerciseColors.surface }]}><Text style={[styles.instructionNumberText, { color: exerciseColors.deep }]}>{index + 1}</Text></View>
                  <View style={sharedStyles.grow}><Body>{instruction}</Body></View>
                </View>) : <Body>Step-by-step instructions are not available for this exercise yet.</Body>}
              </View>
              <View style={[styles.exerciseInfo, { backgroundColor: exerciseColors.surface }]}>
                <MaterialIcons name="info-outline" size={18} color={exerciseColors.deep} />
                <Body>{infoExercise.measurement_type === 'reps_weight' ? 'Configure repetitions and optional weight for each set.'
                  : infoExercise.measurement_type === 'reps_only' ? 'Configure repetitions for each set.'
                    : infoExercise.measurement_type === 'time_distance' ? 'Configure duration and optional distance for each set.'
                      : 'Configure the duration for each set.'}</Body>
              </View>
            </>}
          </ScrollView>
          <Button label="Done" variant="secondary" onPress={() => setInfoExercise(null)} />
        </View>
      </View>
    </Modal>
  </Screen>;
}

function NumberStepper({ label, value, onChange, unit, min, max, step, decimals, optional = false }: {
  label: string; value: string; onChange: (value: string) => void; unit: string;
  min: number; max: number; step: number; decimals: number; optional?: boolean;
}) {
  const { theme } = useBloomTheme();
  const accent = theme.modules.exercise;
  function adjust(direction: -1 | 1) {
    if (optional && !value.trim() && direction < 0) return;
    const current = Number(value);
    const base = Number.isFinite(current) && value.trim() ? current : min - (optional ? step : 0);
    const next = Math.max(min, Math.min(max, base + step * direction));
    onChange(String(Number(next.toFixed(decimals))));
  }
  return <View style={styles.stepper}>
    <View style={styles.stepperLabelRow}>
      <Text style={[styles.stepperLabel, { color: theme.colors.ink }]}>{label}</Text>
      {optional && <Text style={[styles.optional, { color: theme.colors.inkMuted }]}>Optional</Text>}
    </View>
    <View style={[styles.stepperControl, { backgroundColor: theme.colors.surface, borderColor: theme.colors.border }]}>
      <Pressable accessibilityRole="button" accessibilityLabel={`Decrease ${label.toLowerCase()}`} onPress={() => adjust(-1)}
        style={({ pressed }) => [styles.stepperButton, { backgroundColor: theme.colors.surfaceSoft }, pressed && styles.pressed]}>
        <MaterialIcons name="remove" size={19} color={accent.deep} />
      </Pressable>
      <TextInput accessibilityLabel={optional ? `${label}, optional` : label} value={value} onChangeText={onChange}
        keyboardType={decimals ? 'decimal-pad' : 'number-pad'} selectTextOnFocus
        placeholder={optional ? '—' : String(min)} placeholderTextColor={theme.colors.inkMuted}
        style={[styles.stepperInput, { color: theme.colors.ink }]} />
      <Text style={[styles.stepperUnit, { color: theme.colors.inkMuted }]}>{unit}</Text>
      <Pressable accessibilityRole="button" accessibilityLabel={`Increase ${label.toLowerCase()}`} onPress={() => adjust(1)}
        style={({ pressed }) => [styles.stepperButton, { backgroundColor: accent.surface }, pressed && styles.pressed]}>
        <MaterialIcons name="add" size={19} color={accent.deep} />
      </Pressable>
    </View>
  </View>;
}

function FilterChip({ label, selected, onPress }: { label: string; selected: boolean; onPress: () => void }) {
  const { theme } = useBloomTheme();
  const accent = theme.modules.exercise;
  return <Pressable accessibilityRole="radio" accessibilityState={{ checked: selected }} onPress={onPress}
    style={[styles.filterChip, { borderColor: selected ? accent.deep : theme.colors.border, backgroundColor: selected ? accent.surface : theme.colors.surface }]}>
    <Text style={[styles.filterChipText, { color: selected ? accent.deep : theme.colors.ink }]}>{label}</Text>
  </Pressable>;
}

const styles = StyleSheet.create({
  headerRow: { flexDirection: 'row', alignItems: 'center', gap: 12 },
  backButton: { width: 44, height: 44, alignItems: 'center', justifyContent: 'center', borderWidth: 1, borderRadius: 15 },
  steps: { flexDirection: 'row', gap: 10 },
  stepItem: { flex: 1, minHeight: 54, flexDirection: 'row', alignItems: 'center', gap: 9, borderWidth: 1, borderRadius: 16, paddingHorizontal: 12 },
  stepNumber: { width: 27, height: 27, alignItems: 'center', justifyContent: 'center', borderRadius: 14 },
  stepNumberText: { fontSize: 13, fontWeight: '800' },
  stepLabel: { flexShrink: 1, fontSize: 13, fontWeight: '700' },
  nameField: { minHeight: 52, justifyContent: 'center' },
  planNameInput: { minHeight: 52, borderWidth: 1, borderRadius: 14, paddingHorizontal: 15, fontSize: 16, fontWeight: '600' },
  sectionDivider: { borderTopWidth: StyleSheet.hairlineWidth, marginVertical: 2 },
  days: { flexDirection: 'row', flexWrap: 'wrap', gap: 8 },
  dayChoice: { minWidth: 48, minHeight: 44, alignItems: 'center', justifyContent: 'center', borderWidth: 1, borderRadius: 13, paddingHorizontal: 10 },
  dayLabel: { fontSize: 13, fontWeight: '700' },
  sectionHeading: { flexDirection: 'row', alignItems: 'center', gap: 12 },
  filterButton: { minHeight: 44, flexDirection: 'row', alignItems: 'center', justifyContent: 'center', gap: 6, borderWidth: 1, borderRadius: 14, paddingHorizontal: 12 },
  filterButtonText: { fontSize: 12, fontWeight: '800' },
  selectedList: { gap: 12 },
  exerciseConfig: { gap: 13, borderWidth: 1, borderRadius: 22, padding: 13 },
  exerciseHeading: { flexDirection: 'row', alignItems: 'center', gap: 11 },
  iconActions: { gap: 6 },
  infoButton: { width: 40, height: 40, alignItems: 'center', justifyContent: 'center', borderRadius: 14 },
  removeButton: { width: 40, height: 40, alignItems: 'center', justifyContent: 'center', borderRadius: 14 },
  prescription: { gap: 11, borderRadius: 17, padding: 12 },
  prescriptionHeading: { gap: 2 },
  prescriptionTitle: { fontSize: 14, lineHeight: 19, fontWeight: '800' },
  prescriptionHint: { fontSize: 11, lineHeight: 16 },
  stepperRow: { flexDirection: 'row', gap: 8 },
  stepper: { flex: 1, minWidth: 0, gap: 6 },
  stepperLabelRow: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', gap: 4 },
  stepperLabel: { fontSize: 12, lineHeight: 16, fontWeight: '700' },
  optional: { fontSize: 10, lineHeight: 14, fontWeight: '600' },
  stepperControl: { minHeight: 48, flexDirection: 'row', alignItems: 'center', gap: 3, borderWidth: 1, borderRadius: 14, padding: 3 },
  stepperButton: { width: 38, height: 40, alignItems: 'center', justifyContent: 'center', borderRadius: 11 },
  stepperInput: { flex: 1, minWidth: 24, height: 40, paddingHorizontal: 0, textAlign: 'center', fontSize: 17, fontWeight: '800', fontVariant: ['tabular-nums'] },
  stepperUnit: { fontSize: 10, fontWeight: '700' },
  catalogRow: { minHeight: 78, flexDirection: 'row', alignItems: 'center', gap: 12, paddingVertical: 8, borderBottomWidth: StyleSheet.hairlineWidth, borderRadius: 14, paddingHorizontal: 7 },
  addMarker: { width: 36, height: 36, alignItems: 'center', justifyContent: 'center', borderWidth: 1, borderRadius: 13 },
  searchInput: { minHeight: 48, borderWidth: 1, borderRadius: 14, paddingHorizontal: 14, fontSize: 16 },
  footerActions: { gap: 8 },
  modalFrame: { flex: 1, justifyContent: 'flex-end', backgroundColor: 'rgba(9, 17, 32, 0.46)' },
  filterSheet: { maxHeight: '88%', borderTopLeftRadius: 28, borderTopRightRadius: 28, borderWidth: 1, paddingHorizontal: 20, paddingTop: 22, paddingBottom: 26, gap: 18 },
  sheetHeader: { flexDirection: 'row', alignItems: 'center', gap: 12 },
  closeButton: { width: 42, height: 42, alignItems: 'center', justifyContent: 'center', borderRadius: 15 },
  sheetContent: { gap: 20, paddingBottom: 4 },
  filterGroup: { gap: 10 },
  filterChips: { flexDirection: 'row', flexWrap: 'wrap', gap: 8 },
  filterChip: { minHeight: 42, justifyContent: 'center', borderWidth: 1, borderRadius: 999, paddingHorizontal: 13 },
  filterChipText: { fontSize: 13, fontWeight: '700' },
  sheetFooter: { gap: 8, paddingTop: 10 },
  infoModalFrame: { flex: 1, justifyContent: 'center', padding: 18, backgroundColor: 'rgba(9, 17, 32, 0.54)' },
  infoDialog: { maxHeight: '90%', borderWidth: 1, borderRadius: 26, padding: 16, gap: 14 },
  infoContent: { gap: 16, paddingBottom: 8 },
  instructionRow: { flexDirection: 'row', alignItems: 'flex-start', gap: 10 },
  instructionNumber: { width: 26, height: 26, alignItems: 'center', justifyContent: 'center', borderRadius: 13 },
  instructionNumberText: { fontSize: 12, fontWeight: '800' },
  exerciseInfo: { flexDirection: 'row', alignItems: 'flex-start', gap: 9, borderRadius: 14, padding: 12 },
  pressed: { opacity: 0.8 },
});
