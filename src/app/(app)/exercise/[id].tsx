import { router, useLocalSearchParams } from 'expo-router';
import { useCallback, useEffect, useState } from 'react';
import { ActivityIndicator, Linking, View } from 'react-native';
import { Body, Button, ErrorText, Eyebrow, Heading, Label, Panel, Screen, sharedStyles } from '../../../components/bloom-ui';
import { loadExercise, type Exercise } from '../../../lib/bloom';
import { colors } from '../../../theme';

function safeMediaUrl(value: string | null) {
  if (!value) return null;
  try {
    const parsed = new URL(value);
    return parsed.protocol === 'https:' && parsed.hostname && !parsed.username && !parsed.password ? parsed.toString() : null;
  } catch { return null; }
}

function measurementLabel(exercise: Exercise) {
  switch (exercise.measurement_type) {
    case 'reps_weight': return 'Repetitions and weight';
    case 'reps_only': return 'Repetitions';
    case 'time_only': return 'Time';
    case 'time_distance': return 'Time and distance';
  }
}

export default function ExerciseDetailScreen() {
  const { id } = useLocalSearchParams<{ id?: string }>();
  const [exercise, setExercise] = useState<Exercise | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [mediaError, setMediaError] = useState<string | null>(null);
  const [openingMedia, setOpeningMedia] = useState(false);

  const load = useCallback(async () => {
    if (!id) { setExercise(null); setError('This exercise could not be found.'); setLoading(false); return; }
    setLoading(true);
    setError(null);
    try {
      const item = await loadExercise(id);
      setExercise(item);
      if (!item) setError('This exercise could not be found.');
    } catch { setError('Could not load this exercise. Check your connection and try again.'); }
    finally { setLoading(false); }
  }, [id]);

  // Fetch this catalog record when its route becomes active.
  // eslint-disable-next-line react-hooks/set-state-in-effect
  useEffect(() => { void load(); }, [load]);

  async function openMedia() {
    const url = safeMediaUrl(exercise?.media_link ?? null);
    if (!url) { setMediaError('A secure exercise demonstration is not available.'); return; }
    setOpeningMedia(true);
    setMediaError(null);
    try { await Linking.openURL(url); }
    catch { setMediaError('Could not open the exercise demonstration on this device.'); }
    finally { setOpeningMedia(false); }
  }

  const mediaUrl = safeMediaUrl(exercise?.media_link ?? null);

  return <Screen>
    <Button label="Back to exercise library" secondary onPress={() => router.back()} />
    {loading && <ActivityIndicator color={colors.accent} />}
    {!loading && error && <Panel><ErrorText>{error}</ErrorText><Button label="Try again" onPress={() => void load()} /></Panel>}
    {!loading && exercise && <>
      <View style={sharedStyles.column}><Eyebrow>{exercise.muscle_group || 'Exercise'}</Eyebrow><Heading>{exercise.name}</Heading><Body>{measurementLabel(exercise)} · use a comfortable range and steady movement.</Body></View>
      {exercise.description && <Panel><Eyebrow>About this exercise</Eyebrow><Body>{exercise.description}</Body></Panel>}
      <Panel><Eyebrow>Instructions</Eyebrow>
        {exercise.instructions?.length ? exercise.instructions.map((instruction, index) => <View key={`${exercise.id}-${index}`} style={sharedStyles.row}>
          <Label>{index + 1}.</Label><View style={sharedStyles.grow}><Body>{instruction}</Body></View>
        </View>) : <Body>Written instructions are not available for this exercise yet.</Body>}
      </Panel>
      {(exercise.measurement_type === 'reps_weight' || exercise.measurement_type === 'time_distance') && <Panel><Eyebrow>What to record</Eyebrow><Body>{exercise.measurement_type === 'reps_weight' ? 'Record repetitions and the weight used for each set.' : 'Record time and, when available, the distance covered.'}</Body></Panel>}
      <Panel><Eyebrow>Demonstration</Eyebrow>
        {mediaUrl ? <><Body>Open the linked demonstration in your device’s browser.</Body><Button label="Open demonstration" onPress={() => void openMedia()} busy={openingMedia} /></>
          : <Body>No secure demonstration link is available for this exercise.</Body>}
        {mediaError && <ErrorText>{mediaError}</ErrorText>}
      </Panel>
      <Button label="Add to a workout plan" onPress={() => router.push({ pathname: '/new-plan', params: { exerciseId: exercise.id } })} />
    </>}
  </Screen>;
}
