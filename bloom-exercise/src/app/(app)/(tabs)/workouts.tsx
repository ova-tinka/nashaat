import { router } from 'expo-router';
import { useState } from 'react';
import { ActivityIndicator, View } from 'react-native';
import { Body, Button, ErrorText, Eyebrow, Heading, Label, Panel, Screen, sharedStyles } from '../../../components/bloom-ui';
import { deletePlan, formatScheduledDays, startWorkout } from '../../../lib/bloom';
import { useBloom } from '../../../lib/bloom-context';
import { colors } from '../../../theme';

export default function WorkoutsScreen() {
  const { plans, activeWorkout, loading, error, refresh } = useBloom();
  const [confirmId, setConfirmId] = useState<string | null>(null);
  const [deleting, setDeleting] = useState(false);
  const [startingId, setStartingId] = useState<string | null>(null);
  const [actionError, setActionError] = useState<string | null>(null);

  async function remove(id: string) {
    setDeleting(true); setActionError(null);
    try { await deletePlan(id); setConfirmId(null); await refresh(); }
    catch { setActionError('Could not delete the plan. Please try again.'); }
    finally { setDeleting(false); }
  }

  async function start(id: string) {
    if (activeWorkout?.plan_id === id) {
      router.push({ pathname: '/session', params: { id: activeWorkout.id } });
      return;
    }
    setStartingId(id); setActionError(null);
    try {
      const sessionId = await startWorkout(id);
      await refresh();
      router.push({ pathname: '/session', params: { id: sessionId } });
    } catch { setActionError('Could not start this workout. Finish or cancel any active workout and try again.'); }
    finally { setStartingId(null); }
  }

  return <Screen>
    <View style={sharedStyles.column}><Eyebrow>Bloom Exercise</Eyebrow><Heading>Your workouts</Heading><Body>Plan your sessions and adjust them as your routine changes.</Body></View>
    <Button label="Create a workout plan" onPress={() => router.push('/new-plan')} />
    {loading && <ActivityIndicator color={colors.accent} />}
    {error && <Panel><ErrorText>{error}</ErrorText><Button label="Try again" secondary onPress={() => void refresh()} /></Panel>}
    {actionError && <ErrorText>{actionError}</ErrorText>}
    {!loading && !error && plans.length === 0 && <Panel><Label>No workout plans yet</Label><Body>Choose exercises and create your first plan.</Body></Panel>}
    {plans.map((plan) => <Panel key={plan.id}>
      <Eyebrow>Workout plan</Eyebrow><Label>{plan.title}</Label><Body>{formatScheduledDays(plan.scheduled_days)}</Body>
      {[...plan.bloom_plan_exercises].sort((a, b) => a.position - b.position).map((item) => <View key={item.position} style={sharedStyles.row}>
        <View style={sharedStyles.grow}><Body>{item.exercise?.name ?? 'Exercise unavailable'}</Body></View>
        <Body>{item.sets} × {item.target_reps !== null ? `${item.target_reps} reps` : `${item.target_seconds} sec`}{item.target_weight_kg !== null ? ` · ${item.target_weight_kg} kg` : ''}{item.target_distance_km !== null ? ` · ${item.target_distance_km} km` : ''}</Body>
      </View>)}
      <Button label={activeWorkout?.plan_id === plan.id ? 'Continue workout' : 'Start workout'} onPress={() => void start(plan.id)} busy={startingId === plan.id} disabled={Boolean(activeWorkout && activeWorkout.plan_id !== plan.id) || Boolean(startingId && startingId !== plan.id)} />
      <Button label="Edit plan" secondary disabled={activeWorkout?.plan_id === plan.id} onPress={() => router.push({ pathname: '/new-plan', params: { planId: plan.id } })} />
      {activeWorkout?.plan_id === plan.id && <Body>Finish or cancel the workout before editing or deleting this plan.</Body>}
      {confirmId === plan.id ? <View style={sharedStyles.column}><Body>Delete this workout plan?</Body><Button label="Delete plan" onPress={() => void remove(plan.id)} busy={deleting} /><Button label="Cancel" secondary onPress={() => setConfirmId(null)} /></View>
        : <Button label="Delete plan" secondary disabled={activeWorkout?.plan_id === plan.id} onPress={() => setConfirmId(plan.id)} />}
    </Panel>)}
  </Screen>;
}
