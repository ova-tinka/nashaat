import { getAppLocale } from '../lib/locale-context';
import { router, type Href } from 'expo-router';
import MaterialIcons from '@expo/vector-icons/MaterialIcons';
import { useState } from 'react';
import { ActivityIndicator, ImageBackground, Pressable, StyleSheet, View } from 'react-native';
import { Body, Button, ErrorText, Eyebrow, FeatureTile, Heading, Label, Panel, ProgressBar, Screen, sharedStyles, LocalizedText as Text } from './bloom-ui';
import { GrowthModuleScreen } from './growth-module-screen';
import { useBloom } from '../lib/bloom-context';
import { useBloomTheme } from '../lib/theme-context';
import type { ModuleKey } from '../theme';
import { bloomPillarImages } from '../assets/bloom-images';
import { formatScheduledDays, SCHEDULE_DAYS, startWorkout, type WorkoutHistoryItem, type WorkoutPlan } from '../lib/bloom';
import { dateKeyInTimeZone } from '../lib/date-utils';
import { WeeklyPillarPlanner } from './weekly-pillar-planner';
import { ReadModuleScreen } from './read-module-screen';

type ExerciseSection = 'today' | 'plans' | 'progress' | 'more';
const exerciseSections: { id: ExerciseSection; title: string }[] = [
  { id: 'today', title: 'Today' }, { id: 'plans', title: 'Plans' },
  { id: 'progress', title: 'Progress' }, { id: 'more', title: 'More' },
];

export function PillarHomeScreen({ moduleId }: { moduleId: ModuleKey }) {
  if (moduleId === 'exercise') return <ExerciseHomeScreen />;
  if (moduleId === 'read') return <ReadModuleScreen />;
  return <GrowthModuleScreen moduleId={moduleId} />;
}

function ExerciseHomeScreen() {
  const { plans, activeWorkout, workoutAnalytics, creditSettings, creditsEnabled, loading, error, refresh } = useBloom();
  const { theme } = useBloomTheme();
  const colors = theme.modules.exercise;
  const [section, setSection] = useState<ExerciseSection>('today');
  const [startingId, setStartingId] = useState<string | null>(null);
  const [actionError, setActionError] = useState<string | null>(null);
  const [referenceDate] = useState(() => new Date());
  const timeZone = creditSettings?.credit_timezone ?? 'UTC';
  const todayKey = dateKeyInTimeZone(referenceDate, timeZone);
  const todayIsoDay = new Date(`${todayKey}T12:00:00.000Z`).getUTCDay() || 7;
  const todayLabel = SCHEDULE_DAYS.find((day) => day.iso === todayIsoDay)?.label ?? 'Today';
  const scheduledToday = plans.filter((plan) => plan.scheduled_days.includes(todayIsoDay));
  const currentPlan = activeWorkout?.plan_id ? plans.find((plan) => plan.id === activeWorkout.plan_id) : undefined;
  const analytics = workoutAnalytics;

  async function startPlan(planId: string) {
    if (activeWorkout) {
      if (activeWorkout.plan_id === planId) router.push({ pathname: '/session', params: { id: activeWorkout.id } });
      return;
    }
    setStartingId(planId);
    setActionError(null);
    try {
      const id = await startWorkout(planId);
      await refresh();
      router.push({ pathname: '/session', params: { id } });
    } catch {
      setActionError('Could not start this workout. Please try again.');
    } finally {
      setStartingId(null);
    }
  }

  function openActiveWorkout() {
    if (activeWorkout) router.push({ pathname: '/session', params: { id: activeWorkout.id } });
  }

  return <Screen safeAreaTop={false}>
    {section === 'today' && <ImageBackground source={bloomPillarImages.exercise} resizeMode="cover" imageStyle={styles.heroImage} style={styles.hero}>
      <View style={styles.heroShade} />
      <View style={styles.heroContent}>
        <View style={styles.heroTopRow}>
          <Text style={styles.heroEyebrow}>Move. Train. Grow.</Text>
          <Pressable accessibilityRole="button" accessibilityLabel="Search the exercise library" accessibilityHint="Opens the exercise library."
            onPress={() => router.push('/library' as Href)} style={({ pressed }) => [styles.heroSearch, pressed && styles.pressed]}>
            <MaterialIcons name="search" size={22} color={colors.deep} />
          </Pressable>
        </View>
        <Text style={styles.heroTitle}>{activeWorkout ? 'Pick up where you left off.' : 'A little movement goes a long way.'}</Text>
        <Text style={styles.heroSubtitle}>{activeWorkout ? 'Your workout is ready to continue.' : 'Build consistency, one workout at a time.'}</Text>
        {!activeWorkout && <Pressable accessibilityRole="button" onPress={() => scheduledToday[0] ? void startPlan(scheduledToday[0].id) : setSection('plans')}
          disabled={Boolean(startingId)} style={({ pressed }) => [styles.heroAction, pressed && styles.pressed]}>
          <Text style={[styles.heroActionText, { color: colors.deep }]}>{scheduledToday[0] ? 'Start today’s workout' : 'View plans'}</Text>
          {startingId ? <ActivityIndicator color={colors.deep} /> : <MaterialIcons name="arrow-forward" size={18} color={colors.deep} />}
        </Pressable>}
      </View>
    </ImageBackground>}

    <View accessibilityRole="tablist" style={[styles.localNav, { backgroundColor: theme.colors.surfaceSoft, borderColor: theme.colors.border }]}>
      {exerciseSections.map((item) => {
        const selected = section === item.id;
        return <Pressable key={item.id} accessibilityRole="tab" accessibilityState={{ selected }} onPress={() => { setActionError(null); setSection(item.id); }}
          style={[styles.localNavItem, selected && { backgroundColor: theme.colors.surface, shadowColor: theme.colors.ink, shadowOpacity: 0.06, shadowRadius: 6, elevation: 1 }]}>
          <Text style={[styles.localNavText, { color: selected ? colors.deep : theme.colors.inkMuted }]}>{item.title}</Text>
        </Pressable>;
      })}
    </View>

    {loading && <ActivityIndicator color={colors.deep} />}
    {error && <Panel>
      <ErrorText>{error}</ErrorText>
      <Body>Your exercise tools stay available while saved activity reconnects.</Body>
      <Button label="Try again" variant="secondary" onPress={() => void refresh()} />
    </Panel>}
    {actionError && <ErrorText>{actionError}</ErrorText>}

    {!loading && !error && section === 'today' && <>
      {activeWorkout && <Panel>
        <View style={styles.sectionTitleRow}>
          <View style={[styles.smallIcon, { backgroundColor: colors.surface }]}><MaterialIcons name="play-arrow" size={20} color={colors.deep} /></View>
          <View style={sharedStyles.grow}><Eyebrow>Workout in progress</Eyebrow><Label>{currentPlan?.title ?? 'Workout'}</Label></View>
          <MaterialIcons name="chevron-right" size={23} color={theme.colors.inkMuted} />
        </View>
        <Button label="Resume workout" onPress={openActiveWorkout} />
      </Panel>}

      {!activeWorkout && <Panel>
        <View style={styles.sectionTitleRow}>
          <View style={[styles.smallIcon, { backgroundColor: colors.surface }]}><MaterialIcons name={scheduledToday.length ? 'fitness-center' : 'self-improvement'} size={20} color={colors.deep} /></View>
          <View style={sharedStyles.grow}><Eyebrow>{todayLabel}</Eyebrow><Label>{scheduledToday.length ? scheduledToday[0].title : 'Rest or move freely'}</Label></View>
        </View>
        {scheduledToday.length > 0 ? <>
          <Body>{scheduledToday[0].bloom_plan_exercises.length} exercises{scheduledToday.length > 1 ? ` · ${scheduledToday.length} plans scheduled` : ''}</Body>
          <View style={styles.exercisePreview}>
            {[...scheduledToday[0].bloom_plan_exercises].sort((a, b) => a.position - b.position).slice(0, 3).map((item) => <View key={item.position} style={styles.previewRow}>
              <View style={[styles.previewDot, { backgroundColor: colors.accent }]} />
              <Text numberOfLines={1} style={[styles.previewText, { color: theme.colors.ink }]}>{item.exercise?.name ?? 'Exercise'}</Text>
            </View>)}
          </View>
          <Button label="Start workout" onPress={() => void startPlan(scheduledToday[0].id)} busy={startingId === scheduledToday[0].id}
            disabled={Boolean(startingId && startingId !== scheduledToday[0].id)} />
        </> : <>
          <Body>No workout is scheduled today. Take a rest day or choose a plan when you’re ready.</Body>
          <Button label={plans.length ? 'Choose a workout' : 'Create a plan'} variant="secondary" onPress={() => plans.length ? setSection('plans') : router.push('/new-plan' as Href)} />
        </>}
      </Panel>}

      {analytics && <>
        <Panel>
          <View style={styles.sectionTitleRow}>
            <View style={sharedStyles.grow}><Eyebrow>This week</Eyebrow><Label>This week’s movement</Label></View>
            <Pressable accessibilityRole="button" accessibilityLabel="View detailed exercise progress" onPress={() => router.push('/progress' as Href)}>
              <MaterialIcons name="arrow-forward" size={20} color={colors.deep} />
            </Pressable>
          </View>
          <View style={styles.summary}>
            <Metric value={analytics.workouts_completed} label="Workouts" />
            <Metric value={analytics.active_days} label="Active days" />
            <Metric value={analytics.planned_workouts > 0 ? `${analytics.completed_planned_workouts}/${analytics.planned_workouts}` : '—'} label="Planned" />
          </View>
        </Panel>

        <WorkoutWeekChart history={analytics.history} timeZone={timeZone} todayKey={todayKey} />
        {creditsEnabled && <Panel>
          <View style={styles.sectionTitleRow}>
            <View style={[styles.smallIcon, { backgroundColor: theme.colors.surfaceTinted }]}><MaterialIcons name="schedule" size={20} color={theme.colors.action} /></View>
            <View style={sharedStyles.grow}><Eyebrow>Bloom credits</Eyebrow><Label>{analytics.credits_earned_minutes} min earned this week</Label></View>
            <Pressable accessibilityRole="button" accessibilityLabel="View credit history" onPress={() => router.push('/credit-history' as Href)}>
              <MaterialIcons name="chevron-right" size={23} color={theme.colors.inkMuted} />
            </Pressable>
          </View>
        </Panel>}
        <RecentWorkout history={analytics.history[0]} timeZone={timeZone} />
      </>}
      {!analytics && <Panel><Eyebrow>Exercise</Eyebrow><Label>Progress will appear here</Label><Body>Complete a workout to start building your history.</Body></Panel>}
    </>}

    {!loading && !error && section === 'plans' && <>
      <View style={styles.sectionTitleRow}>
        <View style={sharedStyles.grow}><Eyebrow>Make room to move</Eyebrow><Heading>Your plans</Heading></View>
        <Pressable accessibilityRole="button" accessibilityLabel="Create workout plan" onPress={() => router.push('/new-plan' as Href)} style={[styles.addButton, { backgroundColor: colors.surface }]}>
          <MaterialIcons name="add" size={22} color={colors.deep} />
        </Pressable>
      </View>
      <Body>Each workout plan has its own scheduled days. Your weekly activity goal lives in Progress.</Body>
      {plans.length === 0 ? <Panel><Label>No workout plans yet</Label><Body>Create a plan to schedule workouts and track each session.</Body><Button label="Create a plan" onPress={() => router.push('/new-plan' as Href)} /></Panel> : plans.map((plan) => <PlanCard key={plan.id} plan={plan} active={activeWorkout?.plan_id === plan.id} activeWorkout={Boolean(activeWorkout)} starting={startingId === plan.id} onStart={() => void startPlan(plan.id)} onEdit={() => router.push({ pathname: '/new-plan', params: { planId: plan.id } })} />)}
      {activeWorkout && <Body>Finish or cancel the active workout before starting a different plan.</Body>}
      <Button label="Manage all plans" variant="secondary" onPress={() => router.push('/workouts' as Href)} />
    </>}

    {!loading && !error && section === 'progress' && <>
      <View style={sharedStyles.column}><Eyebrow>Exercise</Eyebrow><Heading>Your progress</Heading></View>
      {analytics ? <>
        <Panel>
          <View style={styles.sectionTitleRow}><View style={sharedStyles.grow}><Eyebrow>This week</Eyebrow><Label>Workout summary</Label></View><Label>{analytics.workouts_completed}{analytics.weekly_workout_target ? ` / ${analytics.weekly_workout_target}` : ''}</Label></View>
          {analytics.weekly_workout_target !== null && <ProgressBar value={analytics.workouts_completed / Math.max(1, analytics.weekly_workout_target) * 100} label={`${analytics.workouts_completed} of ${analytics.weekly_workout_target} workouts`} color={colors.accent} />}
          <View style={styles.progressStats}>
            <View style={styles.progressStat}><Heading>{analytics.active_days}</Heading><Body>active days</Body></View>
            <View style={styles.progressStat}><Heading>{analytics.sets_completed}</Heading><Body>sets logged</Body></View>
            <View style={styles.progressStat}><Heading>{analytics.reps_completed}</Heading><Body>repetitions</Body></View>
          </View>
          <View style={styles.progressStats}>
            <View style={styles.progressStat}><Label>{analytics.exercise_minutes} min</Label><Body>timed exercise</Body></View>
            <View style={styles.progressStat}><Label>{analytics.distance_km} km</Label><Body>distance</Body></View>
            <View style={styles.progressStat}><Label>{analytics.weight_volume_kg} kg</Label><Body>weight volume</Body></View>
          </View>
        </Panel>
        <WorkoutWeekChart history={analytics.history} timeZone={timeZone} todayKey={todayKey} />
        <Panel><Eyebrow>Recent workout</Eyebrow><RecentWorkout history={analytics.history[0]} compact={false} timeZone={timeZone} /></Panel>
        <Button label="Open full workout history" variant="secondary" onPress={() => router.push('/activity' as Href)} />
      </> : <Panel><Label>No completed workouts yet</Label><Body>Your workout history and records will appear here after your first session.</Body></Panel>}
      <Button label="Detailed progress" variant="tertiary" onPress={() => router.push('/progress' as Href)} />
      <WeeklyPillarPlanner allowedModules={['exercise']} />
    </>}

    {!loading && !error && section === 'more' && <>
      <View><Eyebrow>More</Eyebrow><Heading>Exercise tools</Heading></View>
      <View style={styles.moreGrid}>{[
        { title: 'Exercise library', subtitle: 'Browse movements and instructions', icon: 'search' as const, onPress: () => router.push('/library' as Href) },
        { title: 'Movement coach', subtitle: 'Get help shaping your routine', icon: 'favorite-border' as const, onPress: () => router.push('/coach' as Href) },
        { title: 'Competitions', subtitle: 'Join a friendly challenge', icon: 'emoji-events' as const, onPress: () => router.push('/competitions' as Href) },
        ...(creditsEnabled ? [{ title: 'Credit history', subtitle: 'Review time earned from activity', icon: 'history' as const, onPress: () => router.push('/credit-history' as Href) }] : []),
      ].map((item) => <View key={item.title} style={styles.moreTile}>
        <FeatureTile title={item.title} subtitle={item.subtitle} icon={item.icon} accentColor={colors.deep}
          backgroundColor={colors.surface} onPress={item.onPress} />
      </View>)}</View>
    </>}
  </Screen>;
}

function Metric({ value, label }: { value: string | number; label: string }) {
  return <View style={styles.metric}><Text style={styles.metricValue}>{value}</Text><Text style={styles.metricLabel}>{label}</Text></View>;
}

function getWorkoutDays(history: WorkoutHistoryItem[], timeZone: string, todayKey: string) {
  const [year, month, day] = todayKey.split('-').map(Number);
  const byDate = new Map<string, { workouts: number; minutes: number }>();
  for (const item of history) {
    const date = new Date(item.completed_at);
    if (Number.isFinite(date.getTime())) {
      const key = dateKeyInTimeZone(date, timeZone);
      const total = byDate.get(key) ?? { workouts: 0, minutes: 0 };
      total.workouts += 1;
      total.minutes += item.exercise_seconds / 60;
      byDate.set(key, total);
    }
  }
  return Array.from({ length: 7 }, (_, index) => {
    const date = new Date(Date.UTC(year, month - 1, day - 6 + index, 12));
    const key = date.toISOString().slice(0, 10);
    return {
      key,
      label: new Intl.DateTimeFormat(getAppLocale(), { weekday: 'short', timeZone: 'UTC' }).format(date),
      ...(byDate.get(key) ?? { workouts: 0, minutes: 0 }),
    };
  });
}

function WorkoutWeekChart({ history, timeZone, todayKey }: { history: WorkoutHistoryItem[]; timeZone: string; todayKey: string }) {
  const { theme } = useBloomTheme();
  const color = theme.modules.exercise;
  const [metric, setMetric] = useState<'workouts' | 'minutes'>('workouts');
  const days = getWorkoutDays(history, timeZone, todayKey);
  const peak = Math.max(1, ...days.map((day) => day[metric]));
  const total = days.reduce((sum, day) => sum + day[metric], 0);
  const chartLabel = metric === 'workouts' ? 'Workouts' : 'Timed exercise';
  return <Panel>
    <View style={styles.sectionTitleRow}>
      <View style={sharedStyles.grow}><Eyebrow>Last 7 days</Eyebrow><Label>{chartLabel}</Label></View>
      <Label>{metric === 'workouts' ? total : `${total.toLocaleString(getAppLocale(), { maximumFractionDigits: 1 })} min`}</Label>
    </View>
    <View accessibilityRole="tablist" style={[styles.chartSwitch, { backgroundColor: theme.colors.surfaceSoft }]}>
      {([{ id: 'workouts', title: 'Workouts' }, { id: 'minutes', title: 'Timed min' }] as const).map((option) => {
        const selected = metric === option.id;
        return <Pressable key={option.id} accessibilityRole="tab" accessibilityState={{ selected }} onPress={() => setMetric(option.id)}
          style={[styles.chartSwitchItem, selected && { backgroundColor: theme.colors.surface }]}>
          <Text style={[styles.chartSwitchText, { color: selected ? color.deep : theme.colors.inkMuted }]}>{option.title}</Text>
        </Pressable>;
      })}
    </View>
    <View accessibilityRole="image" accessibilityLabel={days.map((day) => `${day.label}: ${metric === 'workouts' ? `${day.workouts} ${day.workouts === 1 ? 'workout' : 'workouts'}` : `${day.minutes.toLocaleString(getAppLocale(), { maximumFractionDigits: 1 })} timed exercise minutes`}`).join(', ')} style={styles.chart}>
      {days.map((day) => <View key={day.key} style={styles.chartDay}>
        <View style={[styles.chartTrack, { backgroundColor: theme.colors.surfaceSoft }]}>
          <View style={{ flex: 1 }} />
          <View style={[styles.chartBar, { height: day[metric] ? `${Math.max(12, day[metric] / peak * 100)}%` : 4, backgroundColor: day.key === todayKey ? color.accent : color.surface }]} />
        </View>
        <Text style={[styles.chartLabel, { color: theme.colors.inkMuted }]}>{day.label}</Text>
      </View>)}
    </View>
  </Panel>;
}

function RecentWorkout({ history, compact = true, timeZone = 'UTC' }: { history?: WorkoutHistoryItem; compact?: boolean; timeZone?: string }) {
  const { theme } = useBloomTheme();
  if (!history) return <View style={styles.recentEmpty}><Body>No completed workouts yet</Body></View>;
  const date = new Date(history.completed_at);
  return <Pressable accessibilityRole="button" accessibilityLabel={`Open workout history. ${history.plan_title}`} onPress={() => router.push('/activity' as Href)} style={[styles.recentWorkout, compact && { paddingHorizontal: 0, paddingVertical: 0 }]}>
    <View style={[styles.smallIcon, { backgroundColor: theme.modules.exercise.surface }]}><MaterialIcons name="fitness-center" size={19} color={theme.modules.exercise.deep} /></View>
    <View style={sharedStyles.grow}><Label>{history.plan_title}</Label><Body>{Number.isFinite(date.getTime()) ? new Intl.DateTimeFormat(getAppLocale(), { dateStyle: 'medium', timeZone }).format(date) : 'Completed'} · {history.exercises_completed} exercises</Body></View>
    <MaterialIcons name="chevron-right" size={22} color={theme.colors.inkMuted} />
  </Pressable>;
}

function PlanCard({ plan, active, activeWorkout, starting, onStart, onEdit }: {
  plan: WorkoutPlan; active: boolean; activeWorkout: boolean; starting: boolean; onStart: () => void; onEdit: () => void;
}) {
  const { theme } = useBloomTheme();
  const sorted = [...plan.bloom_plan_exercises].sort((a, b) => a.position - b.position);
  return <Panel>
    <View style={styles.sectionTitleRow}>
      <View style={[styles.smallIcon, { backgroundColor: theme.modules.exercise.surface }]}><MaterialIcons name="fitness-center" size={19} color={theme.modules.exercise.deep} /></View>
      <View style={sharedStyles.grow}><Eyebrow>{sorted.length} {sorted.length === 1 ? 'exercise' : 'exercises'}</Eyebrow><Label>{plan.title}</Label></View>
      <Pressable accessibilityRole="button" accessibilityLabel={`Edit ${plan.title}`} onPress={onEdit} style={styles.iconAction}><MaterialIcons name="edit" size={18} color={theme.modules.exercise.deep} /></Pressable>
    </View>
    <Body>{formatScheduledDays(plan.scheduled_days, getAppLocale())}</Body>
    {sorted.length > 0 && <Text style={[styles.planPreview, { color: theme.colors.inkMuted }]} numberOfLines={2}>{sorted.slice(0, 3).map((item) => item.exercise?.name ?? 'Exercise').join(' · ')}</Text>}
    <Button label={active ? 'Continue workout' : 'Start workout'} onPress={onStart} busy={starting} disabled={activeWorkout && !active} />
  </Panel>;
}

const styles = StyleSheet.create({
  hero: { minHeight: 184, borderRadius: 28, overflow: 'hidden', justifyContent: 'flex-end', padding: 20 },
  heroImage: { borderRadius: 28 },
  heroShade: { ...StyleSheet.absoluteFill, backgroundColor: 'rgba(17, 29, 44, 0.42)' },
  heroContent: { gap: 7, alignItems: 'flex-start' },
  heroTopRow: { width: '100%', minHeight: 44, flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', gap: 12 },
  heroSearch: { width: 44, height: 44, alignItems: 'center', justifyContent: 'center', borderRadius: 22, backgroundColor: 'rgba(255,255,255,0.96)' },
  heroEyebrow: { color: '#F4F7FC', fontSize: 11, lineHeight: 16, fontWeight: '800', letterSpacing: 1.2, textTransform: 'uppercase' },
  heroTitle: { color: '#FFFFFF', fontSize: 24, lineHeight: 29, fontWeight: '800', maxWidth: 430 },
  heroSubtitle: { color: '#F4F7FC', fontSize: 14, lineHeight: 19 },
  heroAction: { minHeight: 42, marginTop: 3, paddingHorizontal: 14, borderRadius: 16, backgroundColor: '#FFFFFF', flexDirection: 'row', alignItems: 'center', justifyContent: 'center', gap: 8 },
  heroActionText: { fontSize: 13, lineHeight: 18, fontWeight: '800' },
  localNav: { flexDirection: 'row', borderWidth: 1, borderRadius: 18, padding: 4, gap: 3 },
  localNavItem: { flex: 1, minHeight: 40, alignItems: 'center', justifyContent: 'center', borderRadius: 14, paddingHorizontal: 4 },
  localNavText: { fontSize: 13, fontWeight: '700' },
  sectionTitleRow: { flexDirection: 'row', alignItems: 'center', gap: 12 },
  smallIcon: { width: 38, height: 38, borderRadius: 13, alignItems: 'center', justifyContent: 'center' },
  summary: { flexDirection: 'row', gap: 4 },
  metric: { flex: 1, gap: 4, paddingTop: 8 },
  metricValue: { color: '#141B35', fontSize: 26, lineHeight: 32, fontWeight: '800', fontVariant: ['tabular-nums'] },
  metricLabel: { color: '#71809B', fontSize: 12, lineHeight: 17, fontWeight: '600' },
  exercisePreview: { gap: 8, paddingVertical: 4 },
  previewRow: { flexDirection: 'row', alignItems: 'center', gap: 9 },
  previewDot: { width: 7, height: 7, borderRadius: 4 },
  previewText: { flex: 1, fontSize: 14, lineHeight: 19, fontWeight: '600' },
  chart: { height: 112, flexDirection: 'row', alignItems: 'stretch', gap: 10, paddingTop: 8 },
  chartDay: { flex: 1, gap: 7, alignItems: 'center' },
  chartSwitch: { alignSelf: 'flex-start', flexDirection: 'row', padding: 3, borderRadius: 12, gap: 2 },
  chartSwitchItem: { minHeight: 32, alignItems: 'center', justifyContent: 'center', paddingHorizontal: 10, borderRadius: 9 },
  chartSwitchText: { fontSize: 11, lineHeight: 15, fontWeight: '700' },
  chartTrack: { width: '100%', flex: 1, borderRadius: 10, alignItems: 'center', overflow: 'hidden', justifyContent: 'flex-end' },
  chartBar: { width: '100%', borderRadius: 10, minHeight: 4 },
  chartLabel: { fontSize: 11, lineHeight: 14, fontWeight: '600' },
  recentWorkout: { flexDirection: 'row', alignItems: 'center', gap: 12, paddingVertical: 8 },
  recentEmpty: { paddingVertical: 4 },
  progressStats: { flexDirection: 'row', gap: 8, paddingTop: 3 },
  progressStat: { flex: 1, gap: 2 },
  addButton: { width: 44, height: 44, borderRadius: 16, alignItems: 'center', justifyContent: 'center', borderWidth: 1, borderColor: '#DCE8DF' },
  iconAction: { width: 40, height: 40, alignItems: 'center', justifyContent: 'center', borderRadius: 14 },
  planPreview: { fontSize: 13, lineHeight: 18 },
  moreGrid: { flexDirection: 'row', flexWrap: 'wrap', gap: 12 },
  moreTile: { flexGrow: 1, flexBasis: '46%', minWidth: 142 },
  pressed: { opacity: 0.82 },
});
