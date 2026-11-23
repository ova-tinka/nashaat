import { getAppLocale } from '../../../lib/locale-context';
import { router, useFocusEffect, type Href } from 'expo-router';
import { ActivityIndicator, StyleSheet, View } from 'react-native';
import { useCallback, useState } from 'react';
import { Body, Button, ErrorText, Eyebrow, Heading, Label, Panel, ProgressBar, Screen, sharedStyles, useIsDesktopLayout } from '../../../components/bloom-ui';
import { useAuth } from '../../../lib/auth';
import { useBloom } from '../../../lib/bloom-context';
import { useBloomTheme } from '../../../lib/theme-context';
import { loadGrowthOverview, type GrowthOverview } from '../../../lib/growth-modules';
import { loadExercisePersonalBests, type ExerciseAchievement, type ExercisePersonalBest, type ExerciseStreak } from '../../../lib/bloom';
import { WeeklyPillarPlanner } from '../../../components/weekly-pillar-planner';
import { moduleManifest } from '../../../lib/module-manifest';

export default function ProgressScreen() {
  const { workoutAnalytics, creditSettings, loading, error, refresh } = useBloom();
  const { childProfile, assignedModules, profileId } = useAuth();
  const { theme } = useBloomTheme();
  const [growthState, setGrowthState] = useState<{ profileId: string | null; rows: GrowthOverview[] | null }>({ profileId: null, rows: null });
  const [exerciseRecords, setExerciseRecords] = useState<{ profileId: string | null; bests: ExercisePersonalBest[]; achievements: ExerciseAchievement[] | null; streak: ExerciseStreak | null }>({ profileId: null, bests: [], achievements: null, streak: null });
  const desktop = useIsDesktopLayout();
  const exerciseColor = theme.modules.exercise.deep;
  const exerciseAssigned = !childProfile || assignedModules.includes('exercise');
  const plannerModules = childProfile ? assignedModules : moduleManifest.filter((module) => module.available).map((module) => module.id);
  const analytics = workoutAnalytics;
  const workoutTarget = analytics?.weekly_workout_target;
  const creditTarget = analytics?.weekly_credit_target_minutes;
  const growthRows = growthState.profileId === profileId ? growthState.rows : null;
  useFocusEffect(useCallback(() => {
    let active = true;
    if (!profileId) return () => { active = false; };
    void loadGrowthOverview().then((rows) => {
      if (active) setGrowthState({ profileId, rows });
    }).catch(() => {
      if (active) setGrowthState({ profileId, rows: null });
    });
    return () => { active = false; };
  }, [profileId]));
  useFocusEffect(useCallback(() => {
    let active = true;
    if (!profileId || !exerciseAssigned) return () => { active = false; };
    void loadExercisePersonalBests(profileId, creditSettings?.credit_timezone ?? 'UTC').then((result) => {
      if (active) setExerciseRecords({ profileId, bests: result.bests, achievements: result.achievements, streak: result.streak });
    }).catch(() => {
      if (active) setExerciseRecords({ profileId, bests: [], achievements: null, streak: null });
    });
    return () => { active = false; };
  }, [creditSettings?.credit_timezone, exerciseAssigned, profileId]));
  const records = exerciseRecords.profileId === profileId ? exerciseRecords : null;

  return <Screen safeAreaTop={false}>
    <View style={sharedStyles.column}>
      <Eyebrow>{childProfile ? 'Child View · Exercise' : 'My Space · Exercise'}</Eyebrow>
      <Heading>Your progress</Heading>
      <Body>See the activity Bloom has recorded across your available modules.</Body>
    </View>
    {growthRows && growthRows.length > 0 && <Panel>
      <Eyebrow>Activity across Bloom</Eyebrow>
      <View style={[styles.growthGrid, desktop && styles.desktopGrowthGrid]}>
        {growthRows.map((row) => <View key={row.module_id} style={[styles.growthMetric, desktop && styles.desktopGrowthMetric]}>
          <Eyebrow>{row.module_id === 'study' ? 'Study' : row.module_id === 'read' ? 'Read' : 'Tasks'}</Eyebrow>
          {row.module_id === 'study' ? <>
            <Label>{row.minutes_this_week} min focused</Label>
            <Body>{row.sessions_this_week} completed {row.sessions_this_week === 1 ? 'session' : 'sessions'} · {row.active_items} subjects</Body>
          </> : row.module_id === 'read' ? <>
            <Label>{row.active_items} in progress</Label>
            {row.average_read_progress !== null && <ProgressBar value={row.average_read_progress} label={`Average reading progress ${row.average_read_progress}%`} color={theme.modules.read.deep} />}
            <Body>{row.completed_items} finished · {row.sessions_this_week} sessions this week</Body>
          </> : <>
            <Label>{row.active_items} open · {row.completed_items} completed</Label>
            <Body>{row.due_today} due or overdue</Body>
          </>}
        </View>)}
      </View>
      <Body>Study and reading time are server-timed. New module activities do not earn credits until their server rules are configured.</Body>
    </Panel>}
    {plannerModules.length > 0 && <WeeklyPillarPlanner allowedModules={plannerModules} />}
    {childProfile && !exerciseAssigned ? <Panel><Eyebrow>Child View</Eyebrow><Label>No Exercise access</Label><Body>Exercise progress appears here after your guardian assigns the Exercise module.</Body></Panel> : <>
    {loading && <ActivityIndicator color={theme.colors.action} />}
    {error && <Panel><ErrorText>{error}</ErrorText><Button label="Try again" variant="secondary" onPress={() => void refresh()} /></Panel>}
    {!loading && !error && analytics && <>
      <View style={[styles.metricsGrid, desktop && styles.desktopMetricsGrid]}>
      <View style={[styles.metricColumn, desktop && styles.desktopMetricColumn]}><Panel>
        <Eyebrow>This week</Eyebrow>
        <Label>{workoutTarget == null ? `${analytics.workouts_completed} completed ${analytics.workouts_completed === 1 ? 'workout' : 'workouts'}` : `${analytics.workouts_completed} of ${workoutTarget} workouts`}</Label>
        {workoutTarget != null && <ProgressBar value={analytics.workouts_completed / Math.max(1, workoutTarget) * 100} label={`${analytics.workouts_completed} of ${workoutTarget} workouts`} color={exerciseColor} />}
        <View style={sharedStyles.row}><View style={sharedStyles.grow}><Body>Active days</Body></View><Label>{analytics.active_days} of 7</Label></View>
        {analytics.planned_workouts > 0 && <View style={sharedStyles.row}><View style={sharedStyles.grow}><Body>Scheduled workouts completed</Body></View><Label>{analytics.completed_planned_workouts} of {analytics.planned_workouts}</Label></View>}
        {analytics.missed_planned_workouts > 0 && <Body>{analytics.missed_planned_workouts} scheduled {analytics.missed_planned_workouts === 1 ? 'workout has' : 'workouts have'} passed. Rest and schedule changes are part of building a routine.</Body>}
      </Panel></View>
      <View style={[styles.metricColumn, desktop && styles.desktopMetricColumn]}><Panel>
        <Eyebrow>Movement</Eyebrow>
        <View style={sharedStyles.row}><View style={sharedStyles.grow}><Body>Timed exercise</Body></View><Label>{analytics.exercise_minutes.toLocaleString(getAppLocale(), { maximumFractionDigits: 1 })} min</Label></View>
        <View style={sharedStyles.row}><View style={sharedStyles.grow}><Body>Sets completed</Body></View><Label>{analytics.sets_completed.toLocaleString(getAppLocale())}</Label></View>
        <View style={sharedStyles.row}><View style={sharedStyles.grow}><Body>Repetitions completed</Body></View><Label>{analytics.reps_completed.toLocaleString(getAppLocale())}</Label></View>
        <View style={sharedStyles.row}><View style={sharedStyles.grow}><Body>Distance</Body></View><Label>{analytics.distance_km.toLocaleString(getAppLocale(), { maximumFractionDigits: 2 })} km</Label></View>
        <View style={sharedStyles.row}><View style={sharedStyles.grow}><Body>Weight volume</Body></View><Label>{analytics.weight_volume_kg.toLocaleString(getAppLocale(), { maximumFractionDigits: 1 })} kg</Label></View>
      </Panel></View>
      {creditTarget !== null && creditTarget !== undefined && <View style={[styles.metricColumn, desktop && styles.desktopMetricColumn]}><Panel>
        <Eyebrow>Shared screen-time credits</Eyebrow>
        <Label>{analytics.credits_earned_minutes.toLocaleString(getAppLocale(), { maximumFractionDigits: 2 })} of {creditTarget} goal minutes</Label>
        <ProgressBar value={analytics.credits_earned_minutes / Math.max(1, creditTarget) * 100} label={`${analytics.credits_earned_minutes} of ${creditTarget} goal minutes`} color={theme.colors.action} />
        <Body>Credits are shown from the server-confirmed workout analytics.</Body>
      </Panel></View>}
      </View>
      {records?.streak && <Panel>
        <Eyebrow>Workout streak</Eyebrow>
        <View style={sharedStyles.row}>
          <View style={sharedStyles.grow}><Body>Current streak</Body><Label>{records.streak.currentDays} {records.streak.currentDays === 1 ? 'day' : 'days'}</Label></View>
          <View style={sharedStyles.grow}><Body>Longest streak</Body><Label>{records.streak.longestDays} {records.streak.longestDays === 1 ? 'day' : 'days'}</Label></View>
        </View>
        <Body>Days count in your screen-time profile’s time zone and require a completed workout.</Body>
      </Panel>}
      {records?.achievements && <Panel>
        <Eyebrow>Personal bests by completed workout</Eyebrow>
        <Body>Records show the best saved result for each exercise and measurement. Repetitions and duration are per set; distance is in kilometers; added weight is in kilograms.</Body>
        {records.bests.length === 0 ? <Body>Personal bests will appear after a completed workout.</Body> : records.bests.map((best) => <View key={`${best.exerciseId}:${best.metric}`} style={sharedStyles.row}>
          <View style={sharedStyles.grow}><Label>{best.exerciseName} · {best.metric}</Label><Body>Recorded {new Date(best.achievedAt).toLocaleDateString(getAppLocale())}</Body></View>
          <Label>{best.value.toLocaleString(getAppLocale(), { maximumFractionDigits: 2 })} {best.unit}</Label>
        </View>)}
        <Label>Achievement history</Label>
        {records.achievements.length === 0 ? <Body>Achievements will appear after completed workouts.</Body> : records.achievements.map((achievement) => <View key={achievement.id} style={sharedStyles.column}>
          <Label>{achievement.title}</Label><Body>{achievement.explanation} · {new Date(achievement.achievedAt).toLocaleDateString(getAppLocale())}</Body>
        </View>)}
      </Panel>}
    </>}
    {!loading && !error && !analytics && <Panel>
      <Eyebrow>Exercise</Eyebrow>
      <Label>Progress will appear here</Label>
      <Body>Finish a workout to start building your exercise history.</Body>
    </Panel>}
    {!loading && !error && analytics?.history.length === 0 && <Panel>
      <Eyebrow>Workout history</Eyebrow>
      <Label>No completed workouts yet</Label>
      <Body>Your activity will appear here after your first completed workout.</Body>
      <Button label="View workouts" variant="secondary" onPress={() => router.push('/workouts')} />
    </Panel>}
    {analytics && analytics.history.length > 0 && <Button label="Open activity history" variant="secondary" onPress={() => router.push('/activity' as Href)} />}
    </>}
  </Screen>;
}

const styles = StyleSheet.create({
  growthGrid: { gap: 14 },
  desktopGrowthGrid: { flexDirection: 'row', flexWrap: 'wrap' },
  growthMetric: { gap: 6 },
  desktopGrowthMetric: { flex: 1, flexBasis: 180, minWidth: 180 },
  metricsGrid: { gap: 16 },
  desktopMetricsGrid: { flexDirection: 'row', flexWrap: 'wrap', alignItems: 'stretch' },
  metricColumn: { width: '100%' },
  desktopMetricColumn: { flex: 1, flexBasis: '46%', minWidth: 320 },
});
