import { getAppLocale } from '../../../lib/locale-context';
import MaterialIcons from '@expo/vector-icons/MaterialIcons';
import { router, useFocusEffect } from 'expo-router';
import { ActivityIndicator, Pressable, StyleSheet, View } from 'react-native';
import { useCallback, useState } from 'react';
import { Body, Button, ErrorText, Eyebrow, Heading, Label, Panel, Screen, sharedStyles, useIsDesktopLayout } from '../../../components/bloom-ui';
import { useAuth } from '../../../lib/auth';
import { useBloom } from '../../../lib/bloom-context';
import { useBloomTheme } from '../../../lib/theme-context';
import { loadGrowthActivity, type GrowthActivityEvent } from '../../../lib/growth-modules';

export default function ActivityScreen() {
  const { workoutAnalytics, loading, error, refresh } = useBloom();
  const { childProfile, assignedModules, profileId } = useAuth();
  const { theme } = useBloomTheme();
  const desktop = useIsDesktopLayout();
  const [selectedId, setSelectedId] = useState<string | null>(null);
  const [focusedId, setFocusedId] = useState<string | null>(null);
  const [growthState, setGrowthState] = useState<{ profileId: string | null; events: GrowthActivityEvent[] | null; failed: boolean }>({ profileId: null, events: null, failed: false });
  const history = workoutAnalytics?.history ?? [];
  const exerciseAssigned = !childProfile || assignedModules.includes('exercise');
  const selected = history.find((item) => item.id === selectedId) ?? history[0] ?? null;
  const growthEvents = growthState.profileId === profileId ? growthState.events : null;
  function retryGrowth() {
    if (!profileId) return;
    setGrowthState({ profileId, events: null, failed: false });
    void loadGrowthActivity(profileId).then((events) => setGrowthState({ profileId, events, failed: false }))
      .catch(() => setGrowthState({ profileId, events: null, failed: true }));
  }
  useFocusEffect(useCallback(() => {
    let active = true;
    if (!profileId) return () => { active = false; };
    void loadGrowthActivity(profileId).then((events) => {
      if (active) setGrowthState({ profileId, events, failed: false });
    }).catch(() => {
      if (active) setGrowthState({ profileId, events: null, failed: true });
    });
    return () => { active = false; };
  }, [profileId]));

  const renderDetails = (item: (typeof history)[number]) => <Panel>
    <Eyebrow>{new Date(item.completed_at).toLocaleDateString(getAppLocale(), { weekday: 'short', month: 'short', day: 'numeric' })}</Eyebrow>
    <Label>{item.plan_title}</Label>
    <View style={sharedStyles.row}><View style={sharedStyles.grow}><Body>Exercises completed</Body></View><Label>{item.exercises_completed}</Label></View>
    <View style={sharedStyles.row}><View style={sharedStyles.grow}><Body>Sets completed</Body></View><Label>{item.sets_completed}</Label></View>
    {item.reps_completed > 0 && <View style={sharedStyles.row}><View style={sharedStyles.grow}><Body>Repetitions</Body></View><Label>{item.reps_completed}</Label></View>}
    {item.exercise_seconds > 0 && <View style={sharedStyles.row}><View style={sharedStyles.grow}><Body>Timed exercise</Body></View><Label>{(item.exercise_seconds / 60).toLocaleString(getAppLocale(), { maximumFractionDigits: 1 })} min</Label></View>}
    {item.distance_km > 0 && <View style={sharedStyles.row}><View style={sharedStyles.grow}><Body>Distance</Body></View><Label>{item.distance_km.toLocaleString(getAppLocale(), { maximumFractionDigits: 2 })} km</Label></View>}
    {item.weight_volume_kg > 0 && <View style={sharedStyles.row}><View style={sharedStyles.grow}><Body>Weight volume</Body></View><Label>{item.weight_volume_kg.toLocaleString(getAppLocale(), { maximumFractionDigits: 1 })} kg</Label></View>}
    {item.credits_earned_minutes > 0 && <View style={sharedStyles.row}><View style={sharedStyles.grow}><Body>Credits earned</Body></View><Label>+{item.credits_earned_minutes.toLocaleString(getAppLocale(), { maximumFractionDigits: 2 })} min</Label></View>}
  </Panel>;

  return <Screen safeAreaTop={false}>
    <View style={sharedStyles.column}>
      <Eyebrow>{childProfile ? 'Child View · Exercise' : 'My Space · Exercise'}</Eyebrow>
      <Heading>Activity</Heading>
      <Body>Your saved activity from across Bloom.</Body>
    </View>
    {childProfile && !exerciseAssigned ? <Panel><Eyebrow>Child View</Eyebrow><Label>No Exercise access</Label><Body>Exercise activity appears here after your guardian assigns the Exercise module.</Body></Panel> : <>
    {loading && <ActivityIndicator color={theme.colors.action} />}
    {error && <Panel><ErrorText>{error}</ErrorText><Button label="Try again" variant="secondary" onPress={() => void refresh()} /></Panel>}
    {!loading && !error && history.length === 0 && <Panel>
      <Eyebrow>Workout history</Eyebrow>
      <Label>No completed workouts yet</Label>
      <Body>When you finish a workout, its recorded activity will appear here.</Body>
      <Button label="View workouts" variant="secondary" onPress={() => router.push('/workouts')} />
    </Panel>}
    {!loading && !error && history.length > 0 && (desktop
      ? <View style={styles.workspace}>
        <View style={styles.list}><Panel>
          <Eyebrow>Workout history · {history.length}</Eyebrow>
          {history.map((item) => <Pressable key={item.id} accessibilityRole="button" accessibilityLabel={`${item.plan_title}, completed ${new Date(item.completed_at).toLocaleDateString(getAppLocale())}`} accessibilityState={{ selected: selected?.id === item.id }} onFocus={() => setFocusedId(item.id)} onBlur={() => setFocusedId(null)} onPress={() => setSelectedId(item.id)} style={[styles.eventChoice, { backgroundColor: selected?.id === item.id ? theme.colors.surfaceTinted : theme.colors.surface, borderColor: focusedId === item.id ? theme.colors.focusRing : theme.colors.border }]}>
            <View style={sharedStyles.grow}><Label>{item.plan_title}</Label><Body>{new Date(item.completed_at).toLocaleDateString(getAppLocale(), { weekday: 'short', month: 'short', day: 'numeric' })} · {item.exercises_completed} exercises · {item.sets_completed} sets</Body></View>
          </Pressable>)}
        </Panel></View>
        <View style={styles.detail}>{selected ? renderDetails(selected) : <Panel><Body>Select a workout to view its recorded details.</Body></Panel>}</View>
      </View>
      : history.map((item) => <View key={item.id}>{renderDetails(item)}</View>))}
    </>}
    {!loading && !error && <Panel>
      <Eyebrow>Study, Read & Tasks</Eyebrow>
      {growthEvents === null && growthState.profileId === profileId && growthState.failed
        ? <><ErrorText>Study, Read and Tasks activity isn’t available right now.</ErrorText><Button label="Retry activity" variant="tertiary" onPress={retryGrowth} /></>
        : growthEvents === null ? <View style={sharedStyles.row}><ActivityIndicator color={theme.colors.action} /><Body>Loading saved activity…</Body></View>
        : growthEvents.length === 0 ? <Body>Completed Study, Read and Tasks activity will appear here when it is available to this profile.</Body>
          : growthEvents.slice(0, 12).map((event) => <View key={event.id} style={styles.growthEvent}>
            <View style={[styles.growthDot, { backgroundColor: theme.modules[event.moduleId].surface }]}>
              <MaterialIcons name={event.moduleId === 'study' ? 'school' : event.moduleId === 'read' ? 'menu-book' : 'check-box'} size={18} color={theme.modules[event.moduleId].deep} />
            </View>
            <View style={sharedStyles.grow}><Label>{event.label}</Label><Body>{event.detail}</Body><Body>{new Date(event.occurredAt).toLocaleString(getAppLocale())}</Body></View>
          </View>)}
    </Panel>}
  </Screen>;
}

const styles = StyleSheet.create({
  workspace: { flexDirection: 'row', alignItems: 'flex-start', gap: 18 },
  list: { flex: 1, minWidth: 300 },
  detail: { flex: 1.6, minWidth: 360 },
  eventChoice: { minHeight: 62, flexDirection: 'row', alignItems: 'center', borderWidth: 1, borderRadius: 12, padding: 12, marginBottom: 8 },
  growthEvent: { flexDirection: 'row', alignItems: 'center', gap: 12, paddingVertical: 10, borderBottomWidth: StyleSheet.hairlineWidth, borderBottomColor: '#E4E8F3' },
  growthDot: { width: 36, height: 36, borderRadius: 12, alignItems: 'center', justifyContent: 'center' },
});
