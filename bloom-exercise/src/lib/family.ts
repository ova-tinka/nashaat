import { supabase } from './supabase';
import type { CreditSettings, WorkoutAnalytics, WorkoutPlan } from './bloom';

export type FamilyMember = { user_id: string; role: 'parent' | 'child'; display_name: string };
export type ManagedChildProfile = { profile_id: string; household_id: string; display_name: string };
export type Family = { id: string; name: string; members: FamilyMember[]; childProfiles: ManagedChildProfile[] };

function client() {
  if (!supabase) throw new Error('Bloom is not configured.');
  return supabase;
}

export async function loadFamilies(): Promise<Family[]> {
  const db = client();
  const { data, error } = await db.from('bloom_households').select('id,name').order('created_at');
  if (error) throw error;
  return Promise.all((data ?? []).map(async (family) => {
    const [members, profiles] = await Promise.all([
      db.rpc('bloom_family_members', { p_household_id: family.id }),
      db.from('bloom_child_profiles').select('profile_id,household_id,display_name').eq('household_id', family.id).order('created_at'),
    ]);
    if (members.error) throw members.error;
    if (profiles.error) throw profiles.error;
    return { id: family.id as string, name: family.name as string, members: (members.data ?? []) as FamilyMember[], childProfiles: (profiles.data ?? []) as ManagedChildProfile[] };
  }));
}

export async function createManagedChildProfile(familyId: string, name: string, requestId: string): Promise<string> {
  const { data, error } = await client().rpc('bloom_create_child_profile', { p_household_id: familyId, p_name: name.trim(), p_request_id: requestId });
  if (error) throw error;
  if (typeof data !== 'string') throw new Error('Could not create the profile.');
  return data;
}

export async function deleteUnpairedChildProfile(profileId: string) {
  const { error } = await client().rpc('bloom_delete_unpaired_child_profile', { p_profile_id: profileId });
  if (error) throw error;
}

export async function prepareChildPairing(profileId: string): Promise<string> {
  const { data, error } = await client().functions.invoke('bloom-provision-child', { body: { profile_id: profileId } });
  if (error) throw error;
  if (typeof data?.code !== 'string' || !/^[0-9a-f]{64}$/.test(data.code)) throw new Error('Could not prepare pairing.');
  return data.code;
}

export async function createChildAccountLink(profileId: string): Promise<string> {
  const { data, error } = await client().rpc('bloom_create_child_account_link', { p_profile_id: profileId });
  if (error) throw error;
  if (typeof data !== 'string' || !/^[0-9a-f]{64}$/.test(data)) throw new Error('Could not create the link code.');
  return data;
}

export async function createFamily(name: string) {
  const { error } = await client().rpc('bloom_create_household', { p_name: name.trim() });
  if (error) throw error;
}

export async function createChildInvite(familyId: string): Promise<string> {
  const { data, error } = await client().rpc('bloom_create_child_invite', { p_household_id: familyId });
  if (error) throw error;
  if (typeof data !== 'string') throw new Error('Could not create an invitation.');
  return data;
}

export async function joinFamily(code: string) {
  const { error } = await client().rpc('bloom_accept_child_invite', { p_token: code.trim() });
  if (error) throw error;
}

export async function leaveOrRemoveChild(familyId: string, childId: string) {
  const { error } = await client().rpc('bloom_leave_or_remove_child', { p_household_id: familyId, p_child_id: childId });
  if (error) throw error;
}

export type ChildRule = { id: string; platform: 'ios' | 'android' | 'macos'; target_type: 'app' | 'website'; target_identifier: string };

export async function loadUserBlockingRules(userId: string, platform: ChildRule['platform']): Promise<ChildRule[]> {
  const { data, error } = await client().from('bloom_blocking_rules')
    .select('id,platform,target_type,target_identifier')
    .eq('user_id', userId).eq('platform', platform).eq('enabled', true).order('created_at');
  if (error) throw error;
  return (data ?? []) as ChildRule[];
}

export async function loadChild(childId: string) {
  const db = client();
  const [settings, balance, plans, rules, workoutAnalytics, planProgress] = await Promise.all([
    db.from('bloom_settings').select('credits_enabled,credit_mode,credit_timezone,earning_strategy,reps_per_award,rep_award_minutes,exercise_minutes_per_award,time_award_minutes,super_daily_cap_minutes,weekly_workout_target,weekly_credit_target_minutes').eq('user_id', childId).maybeSingle(),
    db.rpc('bloom_parent_child_balance', { p_child_id: childId }),
    db.from('bloom_workout_plans').select('id,title,created_at,scheduled_days,bloom_plan_exercises(position,sets,target_reps,target_seconds,target_weight_kg,target_distance_km,exercise:exercises(id,name,measurement_type,description,instructions,media_link))').eq('user_id', childId).order('created_at', { ascending: false }),
    db.from('bloom_blocking_rules').select('id,platform,target_type,target_identifier').eq('user_id', childId).order('created_at'),
    db.rpc('bloom_workout_analytics', { p_user_id: childId }),
    db.rpc('bloom_weekly_plan_progress', { p_user_id: childId }),
  ]);
  for (const result of [settings, balance, plans, rules, workoutAnalytics, planProgress]) if (result.error) throw result.error;
  if (!settings.data) throw new Error('The child needs to open Bloom before settings can be managed.');
  return { settings: settings.data as CreditSettings, balance: Number(balance.data ?? 0), plans: (plans.data ?? []) as unknown as WorkoutPlan[], rules: (rules.data ?? []) as ChildRule[], workoutAnalytics: { ...(workoutAnalytics.data as WorkoutAnalytics), ...(planProgress.data as Pick<WorkoutAnalytics, 'planned_workouts' | 'completed_planned_workouts' | 'scheduled_days' | 'rest_days' | 'missed_planned_workouts'>) } };
}

export async function adjustChildCredit(childId: string, requestId: string, minutes: number, reason: string) {
  const { error } = await client().rpc('bloom_parent_adjust_credit', { p_child_id: childId, p_request_id: requestId, p_minutes: minutes, p_reason: reason.trim() });
  if (error) throw error;
}

export async function addChildRule(childId: string, platform: ChildRule['platform'], type: ChildRule['target_type'], identifier: string) {
  const { error } = await client().from('bloom_blocking_rules').insert({ user_id: childId, platform, target_type: type, target_identifier: identifier.trim() });
  if (error) throw error;
}

export async function deleteChildRule(childId: string, id: string) {
  const { data, error } = await client().from('bloom_blocking_rules').delete().eq('user_id', childId).eq('id', id).select('id').maybeSingle();
  if (error) throw error;
  if (!data) throw new Error('Rule was not found.');
}
