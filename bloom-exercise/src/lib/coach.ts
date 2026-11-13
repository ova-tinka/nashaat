import { supabase } from './supabase';

export type CoachSettings = { sharing_consent: boolean; adult_attested: boolean; parent_enabled: boolean;
  parent_sharing_consent: boolean; minor_eligible_attested: boolean; goals: string;
  experience: 'beginner' | 'intermediate' | 'experienced'; equipment: string[] };
export type CoachMessage = { id: string; request_id: string; role: 'user' | 'assistant'; content: string; created_at: string };
export type CoachExercise = { exercise_id?: string | null; custom?: { name: string; description: string; measurement_type: string } | null;
  sets: number; target: number; weight_kg?: number | null; distance_km?: number | null };
export type CoachProposal = { id: string; profile_id: string; status: 'pending' | 'approved' | 'rejected'; created_at: string;
  proposal: { title: string; explanation: string; plan_id?: string; scheduled_days: number[]; exercises: CoachExercise[] } };
export type ChildCoachStatus = { enabled: boolean; eligible: boolean; parent_consent: boolean };
function client() { if (!supabase) throw new Error('Bloom is not configured.'); return supabase; }

export async function loadCoach(profileId: string) {
  const db = client();
  const [settings, messages, proposals] = await Promise.all([
    db.from('bloom_coach_settings').select('sharing_consent,adult_attested,parent_enabled,parent_sharing_consent,minor_eligible_attested,goals,experience,equipment').eq('profile_id', profileId).maybeSingle(),
    db.from('bloom_coach_messages').select('id,request_id,role,content,created_at').eq('profile_id', profileId).order('created_at', { ascending: false }).limit(50),
    db.from('bloom_coach_proposals').select('id,profile_id,status,created_at,proposal').eq('profile_id', profileId).order('created_at', { ascending: false }).limit(30),
  ]);
  for (const result of [settings, messages, proposals]) if (result.error) throw result.error;
  return { settings: settings.data as CoachSettings | null, messages: ((messages.data ?? []) as CoachMessage[]).reverse(), proposals: (proposals.data ?? []) as CoachProposal[] };
}
export async function saveCoachPreferences(consent: boolean, adult: boolean, goals: string, experience: CoachSettings['experience'], equipment: string[]) {
  const { error } = await client().rpc('bloom_set_coach_preferences', { p_consent: consent, p_adult_attested: adult,
    p_goals: goals.trim(), p_experience: experience, p_equipment: equipment });
  if (error) throw error;
}
export async function sendCoachRequest(requestId: string, kind: 'chat' | 'weekly', prompt: string) {
  const { error } = await client().functions.invoke('bloom-coach', { body: { request_id: requestId, kind, prompt } });
  if (error) throw error;
}
export async function clearCoachConversation() {
  const { error } = await client().rpc('bloom_clear_coach_conversation');
  if (error) throw error;
}
export async function decideCoachProposal(id: string, approve: boolean) {
  const { error } = await client().rpc('bloom_decide_coach_proposal', { p_proposal_id: id, p_approve: approve });
  if (error) throw error;
}
export async function loadChildCoaching(childId: string) {
  const db = client();
  const [status, proposals] = await Promise.all([
    db.rpc('bloom_child_coaching_status', { p_child_id: childId }),
    db.rpc('bloom_child_coach_proposals', { p_child_id: childId }),
  ]);
  if (status.error) throw status.error;
  if (proposals.error) throw proposals.error;
  return { status: status.data as ChildCoachStatus, proposals: (proposals.data ?? []) as CoachProposal[] };
}
export async function setChildCoaching(childId: string, enabled: boolean, eligible: boolean, consent: boolean) {
  const { error } = await client().rpc('bloom_set_child_coaching', { p_child_id: childId, p_enabled: enabled, p_eligible: eligible, p_consent: consent });
  if (error) throw error;
}
