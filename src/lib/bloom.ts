import { supabase } from './supabase';
import { calculateExerciseStreak, type ExerciseAchievement, type ExercisePersonalBest, type ExerciseStreak } from './exercise-records';

export type Measurement = 'reps_weight' | 'reps_only' | 'time_only' | 'time_distance';
export type Exercise = {
  id: string;
  name: string;
  description: string | null;
  muscle_group: string | null;
  muscle_groups: string[] | null;
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
  weekly_earning_cap_minutes?: number | null;
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
export type CreditLedgerEntry = {
  id: string;
  amount_minutes: number;
  entry_type: 'earned' | 'spent' | 'expired' | 'adjustment';
  expires_at: string | null;
  created_at: string;
  workout_session_id: string | null;
  growth_module_id: 'study' | 'read' | 'tasks' | null;
  growth_source_type: 'session' | 'task' | null;
};
export const SCHEDULE_DAYS = [
  { label: 'Sun', iso: 7 }, { label: 'Mon', iso: 1 }, { label: 'Tue', iso: 2 },
  { label: 'Wed', iso: 3 }, { label: 'Thu', iso: 4 }, { label: 'Fri', iso: 5 }, { label: 'Sat', iso: 6 },
] as const;
export function formatScheduledDays(days: number[], locale = 'en-GB') {
  const weekdayFormatter = new Intl.DateTimeFormat(locale, { weekday: 'short', timeZone: 'UTC' });
  const labels = SCHEDULE_DAYS.filter((day) => days.includes(day.iso)).map((day) => {
    const weekdayIndex = day.iso === 7 ? 0 : day.iso;
    return weekdayFormatter.format(new Date(Date.UTC(2023, 0, 1 + weekdayIndex, 12)));
  });
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

const EXERCISE_FIELDS = 'id,name,description,muscle_group,muscle_groups,measurement_type,instructions,media_link,bloom_owner_user_id';
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
export type { ExerciseAchievement, ExercisePersonalBest, ExerciseStreak } from './exercise-records';

function client() {
  if (!supabase) throw new Error('Bloom is not configured.');
  return supabase;
}

export async function loadExercisePersonalBests(userId: string, timeZone = 'UTC'): Promise<{ bests: ExercisePersonalBest[]; achievements: ExerciseAchievement[]; streak: ExerciseStreak }> {
  if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(userId)) throw new Error('Invalid profile.');
  const { data, error } = await client().rpc('bloom_exercise_personal_bests', { p_user_id: userId });
  if (error || !data || typeof data !== 'object') throw error ?? new Error('Could not load exercise records.');
  const payload = data as { total_completed?: unknown; bests?: unknown; completed_dates?: unknown };
  const totalCompleted = Number(payload.total_completed ?? 0);
  const bests = Array.isArray(payload.bests) ? (payload.bests as ExercisePersonalBest[]) : [];
  const completedDates = Array.isArray(payload.completed_dates)
    ? payload.completed_dates.map((d) => ({ completed_at: `${String(d)}T12:00:00Z` }))
    : [];
  const streak = calculateExerciseStreak(completedDates, timeZone);
  const milestones = [1, 5, 10, 25, 50, 100].filter((m) => totalCompleted >= m);
  const achievements: ExerciseAchievement[] = milestones
    .reverse()
    .map((count) => ({
      id: `workouts:${count}`,
      title: count === 1 ? 'First completed workout' : `${count} completed workouts`,
      explanation: 'Based on saved, completed workout records.',
      achievedAt: new Date().toISOString(),
    }));
  return { bests, achievements, streak };
}

export async function loadCatalogPage(options: {
  targetUserId?: string;
  limit?: number;
  offset?: number;
  query?: string;
  filter?: 'all' | 'reps' | 'timed';
} = {}): Promise<{ exercises: Exercise[]; hasMore: boolean }> {
  const db = client();
  const current = options.targetUserId ? null : await db.rpc('bloom_current_profile');
  if (current?.error) throw current.error;
  const owner = options.targetUserId ?? current?.data?.profile_id;
  if (!owner) throw new Error('Sign in to view your exercises.');
  if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(owner)) throw new Error('Invalid profile.');
  const limit = Math.max(1, Math.min(100, options.limit ?? 25));
  const offset = Math.max(0, options.offset ?? 0);
  let req = db.from('exercises')
    .select('id,name,description,muscle_group,muscle_groups,measurement_type,media_link,bloom_owner_user_id')
    .or(`is_system.eq.true,bloom_owner_user_id.eq.${owner}`);
  if (options.filter === 'timed') {
    req = req.in('measurement_type', ['time_only', 'time_distance']);
  } else if (options.filter === 'reps') {
    req = req.in('measurement_type', ['reps_only', 'reps_weight']);
  }
  const term = options.query?.trim();
  if (term) {
    const safeTerm = term.replace(/[,%()]/g, ' ').trim();
    if (safeTerm) {
      req = req.or(`name.ilike.%${safeTerm}%,description.ilike.%${safeTerm}%,muscle_group.ilike.%${safeTerm}%`);
    }
  }
  const { data, error } = await req.order('name').range(offset, offset + limit);
  if (error) throw error;
  const rows = ((data ?? []) as unknown as Exercise[]).map((row) => ({ ...row, instructions: row.instructions ?? null }));
  return {
    exercises: rows.slice(0, limit),
    hasMore: rows.length > limit,
  };
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

export async function ensureBloomSettingsInitialized(userId: string): Promise<void> {
  const db = client();
  const existing = await db.from('bloom_settings').select('user_id').eq('user_id', userId).maybeSingle();
  if (existing.error) throw existing.error;
  if (existing.data) return;
  const timezone = Intl.DateTimeFormat().resolvedOptions().timeZone || 'UTC';
  const { error } = await db.from('bloom_settings')
    .upsert({ user_id: userId, credit_timezone: timezone }, { onConflict: 'user_id', ignoreDuplicates: true });
  if (error) throw error;
}

export async function loadWalletSection(userId: string) {
  const db = client();
  const [settings, balance] = await Promise.all([
    db.from('bloom_settings').select('credits_enabled,credit_mode,credit_timezone,earning_strategy,reps_per_award,rep_award_minutes,exercise_minutes_per_award,time_award_minutes,super_daily_cap_minutes,weekly_workout_target,weekly_credit_target_minutes,weekly_earning_cap_minutes').eq('user_id', userId).single(),
    db.rpc('bloom_credit_balance'),
  ]);
  if (settings.error) throw settings.error;
  if (balance.error) throw balance.error;
  if (!settings.data) throw new Error('Settings are unavailable.');
  return {
    creditsEnabled: settings.data.credits_enabled as boolean,
    creditSettings: settings.data as CreditSettings,
    creditBalance: Number(balance.data ?? 0),
  };
}

export async function loadWorkoutsSection(userId: string) {
  const db = client();
  const [plans, sessions, activeWorkout] = await Promise.all([
    db.from('bloom_workout_plans')
      .select('id,title,created_at,scheduled_days,bloom_plan_exercises(position,sets,target_reps,target_seconds,target_weight_kg,target_distance_km,exercise:exercises(id,name,measurement_type,description,instructions,media_link))')
      .eq('user_id', userId).order('created_at', { ascending: false }),
    db.from('bloom_workout_sessions').select('id', { count: 'exact', head: true })
      .eq('user_id', userId).not('completed_at', 'is', null),
    db.from('bloom_workout_sessions').select('id,plan_id,started_at')
      .eq('user_id', userId).eq('status', 'in_progress').maybeSingle(),
  ]);
  for (const result of [plans, sessions, activeWorkout]) {
    if (result.error) throw result.error;
  }
  return {
    plans: (plans.data ?? []) as unknown as WorkoutPlan[],
    completedSessions: sessions.count ?? 0,
    activeWorkout: activeWorkout.data as ActiveWorkout | null,
  };
}

export async function loadAnalyticsSection() {
  const db = client();
  const [analytics, planProgress] = await Promise.all([
    db.rpc('bloom_workout_analytics'),
    db.rpc('bloom_weekly_plan_progress'),
  ]);
  if (analytics.error) throw analytics.error;
  if (planProgress.error) throw planProgress.error;
  return { ...(analytics.data as WorkoutAnalytics), ...(planProgress.data as Pick<WorkoutAnalytics, 'planned_workouts' | 'completed_planned_workouts' | 'scheduled_days' | 'rest_days' | 'missed_planned_workouts'>) };
}

export async function loadBloomData(userId: string) {
  const [wallet, workouts, workoutAnalytics] = await Promise.all([
    loadWalletSection(userId),
    loadWorkoutsSection(userId),
    loadAnalyticsSection(),
  ]);
  return {
    ...wallet,
    ...workouts,
    workoutAnalytics,
  };
}

export async function loadCreditLedger(): Promise<CreditLedgerEntry[]> {
  const { data, error } = await client().from('bloom_credit_ledger')
    .select('id,amount_minutes,entry_type,expires_at,created_at,workout_session_id,growth_module_id,growth_source_type').neq('entry_type', 'usage')
    .order('created_at', { ascending: false }).limit(100);
  if (error) throw error;
  return (data ?? []).map((row) => ({ ...row, amount_minutes: Number(row.amount_minutes) })) as CreditLedgerEntry[];
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

export async function cancelEnforcedCreditSession(requestId: string, deviceKey: string): Promise<void> {
  const { error } = await client().rpc('bloom_cancel_enforced_credit_session', {
    p_request_id: requestId,
    p_device_key: deviceKey,
  });
  if (error) throw error;
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

export async function saveWeeklyEarningCap(profileId: string, weeklyCapMinutes: number | null) {
  const { error } = await client().rpc('bloom_save_weekly_earning_cap', {
    p_profile_id: profileId,
    p_weekly_cap_minutes: weeklyCapMinutes,
  });
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

export async function syncOfflineWorkout(args: {
  activityId: string;
  planId: string | null;
  startedAt: string;
  completedAt: string;
  durationSeconds: number;
  results: ExerciseResult[];
}) {
  const { data, error } = await client().rpc('bloom_sync_offline_workout', {
    p_activity_id: args.activityId,
    p_plan_id: args.planId,
    p_started_at: args.startedAt,
    p_completed_at: args.completedAt,
    p_duration_seconds: args.durationSeconds,
    p_results: args.results,
  });
  if (error) throw error;
  return data as { session_id: string; status: string; duplicate: boolean; credits_earned_minutes: number; duration_seconds: number };
}
