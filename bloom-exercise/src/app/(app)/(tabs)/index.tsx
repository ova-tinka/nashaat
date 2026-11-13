import { router } from 'expo-router';
import { ActivityIndicator, View } from 'react-native';
import { Body, Button, ErrorText, Eyebrow, Heading, Label, Panel, Screen, sharedStyles } from '../../../components/bloom-ui';
import { useBloom } from '../../../lib/bloom-context';
import { colors } from '../../../theme';

export default function HomeScreen() {
  const { plans, completedSessions, activeWorkout, creditsEnabled, creditBalance, workoutAnalytics, loading, error, refresh } = useBloom();
  return <Screen>
    <View style={sharedStyles.column}><Eyebrow>Welcome back</Eyebrow><Heading>Your movement, your week.</Heading><Body>Build a routine that fits your life.</Body></View>
    {loading && <ActivityIndicator color={colors.accent} />}
    {error && <Panel><ErrorText>{error}</ErrorText><Button label="Try again" secondary onPress={() => void refresh()} /></Panel>}
    {!loading && !error && <>
      {activeWorkout && <Panel><Eyebrow>In progress</Eyebrow><Label>Your workout is ready to continue.</Label><Button label="Continue workout" onPress={() => router.push({ pathname: '/session', params: { id: activeWorkout.id } })} /></Panel>}
      <Panel><Eyebrow>Your workouts</Eyebrow><View style={sharedStyles.row}><View><Label>{plans.length} {plans.length === 1 ? 'plan' : 'plans'}</Label><Body>{completedSessions} completed {completedSessions === 1 ? 'workout' : 'workouts'}</Body></View><Button label="View workouts" onPress={() => router.push('/workouts')} /></View></Panel>
      <Panel><Eyebrow>Screen-time credits</Eyebrow><Label>{creditsEnabled ? `${creditBalance.toLocaleString(undefined, { maximumFractionDigits: 4 })} minutes available` : 'Credits are turned off'}</Label><Body>Your balance is shared across your devices. Unused credits expire Sunday at midnight in your selected time zone.</Body><Button label="Open focus settings" onPress={() => router.push('/focus')} /><Button label="Refresh balance" secondary onPress={() => void refresh()} /></Panel>
      {workoutAnalytics && <Panel>
        <Eyebrow>This week</Eyebrow>
        <Label>{workoutAnalytics.weekly_workout_target === null ? 'Weekly progress' : `${workoutAnalytics.workouts_completed} of ${workoutAnalytics.weekly_workout_target} workouts`}</Label>
        {workoutAnalytics.planned_workouts > 0 && <Body>{workoutAnalytics.completed_planned_workouts} of {workoutAnalytics.planned_workouts} scheduled workouts complete · {workoutAnalytics.rest_days} rest days</Body>}
        {workoutAnalytics.weekly_credit_target_minutes !== null && <Body>{workoutAnalytics.credits_earned_minutes.toLocaleString(undefined, { maximumFractionDigits: 2 })} of {workoutAnalytics.weekly_credit_target_minutes} goal minutes earned</Body>}
        <View style={sharedStyles.row}><View style={sharedStyles.grow}><Body>Active days</Body></View><Label>{workoutAnalytics.active_days}</Label></View>
        <View style={sharedStyles.row}><View style={sharedStyles.grow}><Body>Timed exercise minutes</Body></View><Label>{workoutAnalytics.exercise_minutes.toLocaleString(undefined, { maximumFractionDigits: 1 })}</Label></View>
        <View style={sharedStyles.row}><View style={sharedStyles.grow}><Body>Sets completed</Body></View><Label>{workoutAnalytics.sets_completed}</Label></View>
        <View style={sharedStyles.row}><View style={sharedStyles.grow}><Body>Repetitions completed</Body></View><Label>{workoutAnalytics.reps_completed}</Label></View>
        {workoutAnalytics.missed_planned_workouts > 0 && <><Body>A scheduled day passed without a workout. That’s okay; you can adjust the plan or leave room for rest.</Body><Button label="Review workout schedule" secondary onPress={() => router.push('/workouts')} /></>}
        {workoutAnalytics.history.length > 0 && <>
          <Eyebrow>Recent workouts</Eyebrow>
          {workoutAnalytics.history.slice(0, 5).map((item) => <View key={item.id} style={sharedStyles.row}>
            <View style={sharedStyles.grow}><Label>{item.plan_title}</Label><Body>{new Date(item.completed_at).toLocaleDateString()} · {item.exercises_completed} exercises · {item.sets_completed} sets</Body></View>
            {item.credits_earned_minutes > 0 && <Body>+{item.credits_earned_minutes.toLocaleString(undefined, { maximumFractionDigits: 2 })} min</Body>}
          </View>)}
        </>}
        {workoutAnalytics.history.length === 0 && <Body>Complete a workout to start building your weekly progress.</Body>}
      </Panel>}
      <Panel><Eyebrow>Plan your week</Eyebrow><Label>Make room for movement and rest.</Label><Body>Choose exercises and build a plan at your own pace.</Body><Button label="Create a plan" secondary onPress={() => router.push('/new-plan')} /></Panel>
    </>}
  </Screen>;
}
