import { supabase } from './supabase';

export type Measurement = 'reps_weight' | 'reps_only' | 'time_only' | 'time_distance';
export type Exercise = {
  id: string;
  name: string;
  description: string | null;
  muscle_group: string | null;
  measurement_type: Measurement;
  instructions: string[] | null;
  media_link: string | null;
  bloom_owner_user_id: string | null;
};
export type PlanExercise = {
  position: number;
  sets: number;
  target_reps: number | null;
  target_seconds: number | null;
  target_weight_kg: number | null;
  target_distance_km: number | null;
  exercise: Pick<Exercise, 'id' | 'name' | 'measurement_type' | 'description' | 'instructions' | 'media_link'> | null;
};
export type WorkoutPlan = {
  id: string;
  title: string;
  created_at: string;
  scheduled_days: number[];
  bloom_plan_exercises: PlanExercise[];
};
export type DraftExercise = { exercise_id: string; sets: number; target: number; weight_kg?: number; distance_km?: number };
export type Subscription = { id: string; status: string; current_period_end: string | null };
export type CreditSettings = {
  credits_enabled: boolean;
  credit_mode: 'easy' | 'hard' | 'super_hard';
  credit_timezone: string;
  earning_strategy: 'rates' | 'goal_analytics';
  reps_per_award: number | null;
  rep_award_minutes: number | null;
  exercise_minutes_per_award: number | null;
  time_award_minutes: number | null;
  super_daily_cap_minutes: number | null;
  weekly_workout_target: number | null;
  weekly_credit_target_minutes: number | null;
};
export type WorkoutHistoryItem = {
  id: string;
  plan_title: string;
  completed_at: string;
  credits_earned_minutes: number;
  exercises_completed: number;
  sets_completed: number;
  reps_completed: number;
  exercise_seconds: number;
  distance_km: number;
  weight_volume_kg: number;
};
export type WorkoutAnalytics = {
  week_start: string;
  week_end: string;
  weekly_workout_target: number | null;
  weekly_credit_target_minutes: number | null;
  workouts_completed: number;
  active_days: number;
  exercise_minutes: number;
  sets_completed: number;
  reps_completed: number;
  distance_km: number;
  weight_volume_kg: number;
  credits_earned_minutes: number;
  planned_workouts: number;
  completed_planned_workouts: number;
  scheduled_days: number;
  rest_days: number;
  missed_planned_workouts: number;
  history: WorkoutHistoryItem[];
};
export const SCHEDULE_DAYS = [
  { label: 'Sun', iso: 7 }, { label: 'Mon', iso: 1 }, { label: 'Tue', iso: 2 },
  { label: 'Wed', iso: 3 }, { label: 'Thu', iso: 4 }, { label: 'Fri', iso: 5 }, { label: 'Sat', iso: 6 },
] as const;
export function formatScheduledDays(days: number[]) {
  const labels = SCHEDULE_DAYS.filter((day) => days.includes(day.iso)).map((day) => day.label);
  return labels.length ? labels.join(' · ') : 'Flexible schedule';
}
export type ActiveWorkout = { id: string; plan_id: string | null; started_at: string };
export type SessionExercise = {
  exercise_id: string;
  name: string;
  measurement_type: Measurement;
  sets: number;
  target_reps: number | null;
  target_seconds: number | null;
  target_weight_kg: number | null;
  target_distance_km: number | null;
  description?: string | null;
  instructions?: string[] | null;
  media_link?: string | null;
};

const EXERCISE_FIELDS = 'id,name,description,muscle_group,measurement_type,instructions,media_link,bloom_owner_user_id';
export type WorkoutSession = ActiveWorkout & {
  plan_title_snapshot: string | null;
  status: 'in_progress' | 'completed' | 'cancelled';
  plan_snapshot: SessionExercise[];
  credits_enabled_at_completion: boolean | null;
  credits_earned_minutes: number;
  active_duration_seconds: number | null;
  timer_started_at: string | null;
};
export type ExerciseResult = {
  exercise_id: string;
  sets_completed: number;
  reps_completed?: number;
  duration_seconds?: number;
  weight_kg?: number;
  distance_km?: number;
};

function client() {
  if (!supabase) throw new Error('Bloom is not configured.');
  return supabase;
}

export async function loadCatalog(targetUserId?: string): Promise<Exercise[]> {
  const db = client();
  const current = targetUserId ? null : await db.rpc('bloom_current_profile');
  if (current?.error) throw current.error;
  const owner = targetUserId ?? current?.data?.profile_id;
  if (!owner) throw new Error('Sign in to view your exercises.');
  if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(owner)) throw new Error('Invalid profile.');
  const { data, error } = await db.from('exercises')
    .select(EXERCISE_FIELDS)
    .or(`is_system.eq.true,bloom_owner_user_id.eq.${owner}`).order('name');
  if (error) throw error;
  return (data ?? []) as Exercise[];
}

export async function loadExercise(id: string): Promise<Exercise | null> {
  const { data, error } = await client().from('exercises')
    .select(EXERCISE_FIELDS)
    .eq('id', id).maybeSingle();
  if (error) throw error;
  return data as Exercise | null;
}

export async function createCustomExercise(name: string, description: string, measurement: Measurement): Promise<string> {
  const { data, error } = await client().rpc('bloom_create_custom_exercise', {
    p_name: name.trim(), p_description: description.trim(), p_measurement: measurement,
  });
  if (error) throw error;
  if (typeof data !== 'string') throw new Error('Could not create the exercise.');
  return data;
}

export async function loadBloomData(userId: string) {
  const db = client();
  const timezone = Intl.DateTimeFormat().resolvedOptions().timeZone || 'UTC';
  const { error: settingsError } = await db.from('bloom_settings')
    .upsert({ user_id: userId, credit_timezone: timezone }, { onConflict: 'user_id', ignoreDuplicates: true });
  if (settingsError) throw settingsError;

  const [settings, plans, sessions, activeWorkout, subscription, balance, analytics, planProgress] = await Promise.all([
    db.from('bloom_settings').select('credits_enabled,credit_mode,credit_timezone,earning_strategy,reps_per_award,rep_award_minutes,exercise_minutes_per_award,time_award_minutes,super_daily_cap_minutes,weekly_workout_target,weekly_credit_target_minutes').eq('user_id', userId).single(),
    db.from('bloom_workout_plans')
      .select('id,title,created_at,scheduled_days,bloom_plan_exercises(position,sets,target_reps,target_seconds,target_weight_kg,target_distance_km,exercise:exercises(id,name,measurement_type,description,instructions,media_link))')
      .eq('user_id', userId).order('created_at', { ascending: false }),
    db.from('bloom_workout_sessions').select('id', { count: 'exact', head: true })
      .eq('user_id', userId).not('completed_at', 'is', null),
    db.from('bloom_workout_sessions').select('id,plan_id,started_at')
      .eq('user_id', userId).eq('status', 'in_progress').maybeSingle(),
    db.from('bloom_subscriptions').select('id,status,current_period_end')
      .order('created_at', { ascending: false }).limit(1).maybeSingle(),
    db.rpc('bloom_credit_balance'),
    db.rpc('bloom_workout_analytics'),
    db.rpc('bloom_weekly_plan_progress'),
  ]);
  for (const result of [settings, plans, sessions, activeWorkout, subscription, balance, analytics, planProgress]) {
    if (result.error) throw result.error;
  }
  if (!settings.data) throw new Error('Settings are unavailable.');
  return {
    creditsEnabled: settings.data.credits_enabled as boolean,
    creditSettings: settings.data as CreditSettings,
    creditBalance: Number(balance.data ?? 0),
    plans: (plans.data ?? []) as unknown as WorkoutPlan[],
    completedSessions: sessions.count ?? 0,
    activeWorkout: activeWorkout.data as ActiveWorkout | null,
    subscription: subscription.data as Subscription | null,
    workoutAnalytics: { ...(analytics.data as WorkoutAnalytics), ...(planProgress.data as Pick<WorkoutAnalytics, 'planned_workouts' | 'completed_planned_workouts' | 'scheduled_days' | 'rest_days' | 'missed_planned_workouts'>) },
  };
}

export async function startWorkout(planId: string): Promise<string> {
  const { data, error } = await client().rpc('bloom_start_workout', { p_plan_id: planId });
  if (error) throw error;
  const id = data?.[0]?.session_id;
  if (typeof id !== 'string') throw new Error('Workout could not be started.');
  return id;
}

export async function loadWorkout(id: string): Promise<WorkoutSession> {
  const { data, error } = await client().from('bloom_workout_sessions')
    .select('id,plan_id,plan_title_snapshot,started_at,status,plan_snapshot,credits_enabled_at_completion,credits_earned_minutes,active_duration_seconds,timer_started_at')
    .eq('id', id).single();
  if (error) throw error;
  return data as WorkoutSession;
}

export async function loadWorkoutPlan(id: string): Promise<WorkoutPlan> {
  const { data, error } = await client().from('bloom_workout_plans')
    .select('id,title,created_at,scheduled_days,bloom_plan_exercises(position,sets,target_reps,target_seconds,target_weight_kg,target_distance_km,exercise:exercises(id,name,measurement_type,description,instructions,media_link))')
    .eq('id', id).single();
  if (error) throw error;
  return data as unknown as WorkoutPlan;
}

export async function completeWorkout(id: string, results: ExerciseResult[]): Promise<boolean> {
  const { data, error } = await client().rpc('bloom_complete_workout', {
    p_session_id: id,
    p_results: results,
  });
  if (error) throw error;
  const enabled = data?.[0]?.credits_enabled;
  if (typeof enabled !== 'boolean') throw new Error('Workout could not be completed.');
  return enabled;
}

export async function cancelWorkout(id: string) {
  const { error } = await client().rpc('bloom_cancel_workout', { p_session_id: id });
  if (error) throw error;
}

export async function setWorkoutTimer(id: string, running: boolean) {
  const { error } = await client().rpc('bloom_set_workout_timer', { p_session_id: id, p_running: running });
  if (error) throw error;
}

export async function startEnforcedCreditSession(requestId: string, deviceKey: string, minutes: number): Promise<number> {
  const { data, error } = await client().rpc('bloom_start_enforced_credit_session', { p_request_id: requestId, p_device_key: deviceKey, p_minutes: minutes });
  if (error) throw new Error(error.message || 'Could not start screen time. Retry the same request.');
  const remaining = Number(data?.[0]?.remaining_ms);
  if (!Number.isFinite(remaining) || remaining < 0) throw new Error('Could not read the screen-time session.');
  return remaining;
}

export async function startUsageSession(requestId: string, deviceKey: string, requestedMillis: number) {
  const { data, error } = await client().rpc('bloom_start_usage_session', { p_request_id: requestId, p_device_key: deviceKey, p_requested_ms: requestedMillis });
  if (error) throw error;
  const row = data?.[0];
  const budgetMillis = Number(row?.reserved_ms);
  const expiryMillis = Number(row?.expiry_remaining_ms);
  if (typeof row?.session_id === 'string' && expiryMillis === 0) throw new Error('That screen-time reservation has ended. Request a new access window.');
  if (typeof row?.session_id !== 'string' || !Number.isSafeInteger(budgetMillis) || budgetMillis < 1000 || !Number.isSafeInteger(expiryMillis) || expiryMillis < 1) throw new Error('Could not read the screen-time reservation.');
  return { sessionId: row.session_id as string, budgetMillis, expiryMillis };
}

export async function finishUsageSession(sessionId: string, deviceKey: string) {
  const { error } = await client().rpc('bloom_finish_usage_session', { p_session_id: sessionId, p_device_key: deviceKey });
  if (error) throw error;
}

export async function findUsageSession(userId: string, requestId: string) {
  const { data, error } = await client().from('bloom_usage_sessions').select('id,settled_at').eq('user_id', userId).eq('request_id', requestId).maybeSingle();
  if (error) throw error;
  return data as { id: string; settled_at: string | null } | null;
}

export async function createPlan(title: string, exercises: DraftExercise[], scheduledDays: number[] = []) {
  const { error } = await client().rpc('bloom_create_workout_plan_scheduled', {
    p_title: title.trim(), p_exercises: exercises, p_scheduled_days: scheduledDays,
  });
  if (error) throw error;
}

export async function createPlanForUser(userId: string, title: string, exercises: DraftExercise[], scheduledDays: number[] = []) {
  const { error } = await client().rpc('bloom_create_plan_for_user_scheduled', {
    p_user_id: userId, p_title: title.trim(), p_exercises: exercises, p_scheduled_days: scheduledDays,
  });
  if (error) throw error;
}

export async function updatePlan(planId: string, title: string, exercises: DraftExercise[], scheduledDays: number[] = []) {
  const { error } = await client().rpc('bloom_update_workout_plan_scheduled', {
    p_plan_id: planId, p_title: title.trim(), p_exercises: exercises, p_scheduled_days: scheduledDays,
  });
  if (error) throw error;
}

export async function updatePlanForUser(userId: string, planId: string, title: string, exercises: DraftExercise[], scheduledDays: number[] = []) {
  const { error } = await client().rpc('bloom_update_plan_for_user_scheduled', {
    p_user_id: userId, p_plan_id: planId, p_title: title.trim(), p_exercises: exercises, p_scheduled_days: scheduledDays,
  });
  if (error) throw error;
}

export async function deletePlan(id: string) {
  const { data, error } = await client().from('bloom_workout_plans').delete().eq('id', id).select('id').maybeSingle();
  if (error) throw error;
  if (!data) throw new Error('Plan was not found.');
}

export async function updateCredits(userId: string, enabled: boolean) {
  const { error } = await client().from('bloom_settings')
    .update({ credits_enabled: enabled, updated_at: new Date().toISOString() })
    .eq('user_id', userId).select('credits_enabled').single();
  if (error) throw error;
}

export async function updateCreditRules(userId: string, settings: Omit<CreditSettings, 'credits_enabled'>) {
  const { error } = await client().from('bloom_settings')
    .update({ ...settings, updated_at: new Date().toISOString() })
    .eq('user_id', userId).select('user_id').single();
  if (error) throw error;
}

export async function loadWorkoutAnalytics(userId?: string): Promise<WorkoutAnalytics> {
  const db = client();
  const [analytics, planProgress] = await Promise.all([
    db.rpc('bloom_workout_analytics', { p_user_id: userId ?? null }),
    db.rpc('bloom_weekly_plan_progress', { p_user_id: userId ?? null }),
  ]);
  if (analytics.error) throw analytics.error;
  if (planProgress.error) throw planProgress.error;
  if (!analytics.data || typeof analytics.data !== 'object' || !planProgress.data || typeof planProgress.data !== 'object') throw new Error('Workout analytics are unavailable.');
  return { ...(analytics.data as WorkoutAnalytics), ...(planProgress.data as Pick<WorkoutAnalytics, 'planned_workouts' | 'completed_planned_workouts' | 'scheduled_days' | 'rest_days' | 'missed_planned_workouts'>) };
}
