import { supabase } from './supabase';

export type GrowthAiPreferences = {
  sharing_consent: boolean; adult_attested: boolean; parent_enabled: boolean;
  minor_eligible_attested: boolean; parent_sharing_consent: boolean;
  document_sharing_consent: boolean; document_adult_attested: boolean; document_parent_enabled: boolean;
  document_minor_eligible_attested: boolean; document_parent_sharing_consent: boolean;
};
export type TaskBreakdownDraft = { requestId: string; reply: string; steps: string[] };
export type StudyTutorMessage = {
  id: string; profile_id: string; item_id: string; request_id: string; role: 'user' | 'assistant';
  content: string; answer_scope: 'general' | null; uncertainty: string | null; created_at: string;
};
export type ReadReflectionPrompt = { prompt: string; uncertainty: string };
export type ChildGrowthAiStatus = { enabled: boolean; eligible: boolean; parent_consent: boolean };

function client() {
  if (!supabase) throw new Error('Bloom is not configured.');
  return supabase;
}

export async function loadGrowthAiPreferences(profileId: string, moduleId: 'study' | 'read' | 'tasks') {
  const { data, error } = await client().from('bloom_growth_ai_settings')
    .select('sharing_consent,adult_attested,parent_enabled,minor_eligible_attested,parent_sharing_consent,document_sharing_consent,document_adult_attested,document_parent_enabled,document_minor_eligible_attested,document_parent_sharing_consent')
    .eq('profile_id', profileId).eq('module_id', moduleId).maybeSingle();
  if (error) throw error;
  return data as GrowthAiPreferences | null;
}

export async function saveGrowthAiPreferences(moduleId: 'study' | 'read' | 'tasks', consent: boolean, adultAttested: boolean) {
  const { error } = await client().rpc('bloom_set_growth_ai_preferences', {
    p_module_id: moduleId, p_consent: consent, p_adult_attested: adultAttested,
  });
  if (error) throw error;
}

export async function saveChildGrowthAiPreferences(childId: string, moduleId: 'study' | 'read' | 'tasks', enabled: boolean, eligible: boolean, consent: boolean) {
  const { error } = await client().rpc('bloom_set_child_growth_ai_preferences', {
    p_child_id: childId, p_module_id: moduleId, p_enabled: enabled, p_eligible: eligible, p_consent: consent,
  });
  if (error) throw error;
}

export async function loadChildDocumentAiStatus(childId: string): Promise<ChildGrowthAiStatus> {
  const { data, error } = await client().rpc('bloom_get_child_document_ai_status', { p_child_id: childId });
  if (error) throw error;
  return (data ?? { enabled: false, eligible: false, parent_consent: false }) as ChildGrowthAiStatus;
}

export async function saveChildDocumentAiPreferences(childId: string, enabled: boolean, eligible: boolean, consent: boolean) {
  const { error } = await client().rpc('bloom_set_child_document_ai_preferences', {
    p_child_id: childId, p_enabled: enabled, p_eligible: eligible, p_consent: consent,
  });
  if (error) throw error;
}

export async function requestTaskBreakdown(requestId: string, itemId: string, prompt: string): Promise<TaskBreakdownDraft> {
  const { data, error } = await client().functions.invoke('bloom-growth-ai', {
    body: { request_id: requestId, item_id: itemId, prompt },
  });
  if (error || !data || data.status !== 'draft' || typeof data.reply !== 'string' || !Array.isArray(data.steps)
    || data.steps.some((step: unknown) => typeof step !== 'string')) throw new Error('Task AI is not available or consent is incomplete.');
  return { requestId, reply: data.reply, steps: data.steps as string[] };
}

export async function approveTaskBreakdown(taskId: string, steps: string[], requestId: string) {
  const { data, error } = await client().rpc('bloom_apply_task_breakdown', { p_task_id: taskId, p_steps: steps, p_request_id: requestId });
  if (error) throw error;
  return (data ?? []) as string[];
}

export async function requestStudyTutor(requestId: string, itemId: string, prompt: string) {
  const { data, error } = await client().functions.invoke('bloom-study-tutor', {
    body: { request_id: requestId, item_id: itemId, prompt },
  });
  if (error || !data || data.status !== 'answered' || typeof data.answer !== 'string'
    || data.answer_scope !== 'general' || typeof data.uncertainty !== 'string') {
    throw new Error(typeof data?.error === 'string' ? data.error : 'Study tutor is not available or consent is incomplete.');
  }
  return { answer: data.answer, answerScope: 'general' as const, uncertainty: data.uncertainty };
}

export async function requestReadingReflection(requestId: string, itemId: string): Promise<ReadReflectionPrompt> {
  const { data, error } = await client().functions.invoke('bloom-read-reflection', {
    body: { request_id: requestId, item_id: itemId },
  });
  if (error || !data || data.status !== 'generated' || typeof data.prompt !== 'string'
    || typeof data.uncertainty !== 'string') {
    throw new Error(typeof data?.error === 'string' ? data.error : 'Reading reflection prompts are unavailable or consent is incomplete.');
  }
  return { prompt: data.prompt, uncertainty: data.uncertainty };
}

export async function loadStudyTutorMessages(profileId: string): Promise<StudyTutorMessage[]> {
  const { data, error } = await client().from('bloom_study_tutor_messages')
    .select('id,profile_id,item_id,request_id,role,content,answer_scope,uncertainty,created_at')
    .eq('profile_id', profileId).order('created_at', { ascending: true }).limit(100);
  if (error) throw error;
  return (data ?? []) as StudyTutorMessage[];
}

export async function clearStudyTutorConversation() {
  const { error } = await client().rpc('bloom_clear_study_tutor_conversation');
  if (error) throw error;
}

export async function loadChildGrowthAiStatus(childId: string, moduleId: 'study' | 'read' | 'tasks') {
  const { data, error } = await client().rpc('bloom_get_child_growth_ai_status', {
    p_child_id: childId, p_module_id: moduleId,
  });
  if (error) throw error;
  return (data ?? { enabled: false, eligible: false, parent_consent: false }) as ChildGrowthAiStatus;
}
