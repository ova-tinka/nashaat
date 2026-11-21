import type { ModuleKey } from '../theme';
import { supabase } from './supabase';

export type GrowthModuleId = Extract<ModuleKey, 'study' | 'read' | 'tasks'>;
export type GrowthItemType = 'subject' | 'course' | 'lesson' | 'assignment' | 'reading' | 'project' | 'milestone' | 'task' | 'checklist';
export type GrowthItemState = 'active' | 'completed' | 'archived';
export type TaskPriority = 'low' | 'medium' | 'high' | 'urgent';
export type ReadingStatus = 'want_to_read' | 'currently_reading' | 'finished';
export type ReadingKind = 'book' | 'article';

export type GrowthItem = {
  id: string;
  parent_id: string | null;
  module_id: GrowthModuleId;
  item_type: GrowthItemType;
  title: string;
  notes: string;
  state: GrowthItemState;
  completed_at: string | null;
  due_date: string | null;
  target_minutes: number | null;
  progress_percent: number;
  priority: TaskPriority;
  postponed_until: string | null;
  reading_status: ReadingStatus | null;
  reading_kind: ReadingKind | null;
  author: string;
  genre: string;
  page_count: number | null;
  current_page: number | null;
  created_at: string;
  updated_at: string;
};

export type GrowthSession = {
  id: string;
  module_id: 'study' | 'read';
  item_id: string;
  source_device_id: string;
  source_device_name: string;
  request_id: string;
  status: 'in_progress' | 'completed' | 'cancelled';
  started_at: string;
  completed_at: string | null;
  duration_seconds: number | null;
};

export type GrowthRecordKind = 'verification' | 'task_breakdown_draft' | 'reading_note' | 'reading_annotation' | 'vocabulary'
  | 'practice_question' | 'practice_answer' | 'review_prompt' | 'review_answer' | 'exam' | 'exam_attempt' | 'reflection' | 'achievement'
  | 'reader_position' | 'reader_bookmark';
export type GrowthRecord = {
  id: string; module_id: GrowthModuleId; item_id: string | null; kind: GrowthRecordKind; title: string; body: string;
  metadata: Record<string, unknown>; scheduled_at: string | null; score: number | null; created_at: string; updated_at: string;
};
export type GrowthDocument = {
  id: string; profile_id: string; module_id: 'study' | 'read'; item_id: string; title: string;
  file_name: string; format: 'pdf' | 'docx' | 'epub'; mime_type: string; byte_size: number;
  storage_path: string; created_at: string;
};
export type GrowthRecordAttachment = { record_id: string; document_id: string };
export type StudyPlanSlot = { id: string; item_id: string; day_of_week: number; target_minutes: number };
export type StudyPlanChange = { item_id: string; original_date: string; action: 'skip' | 'move'; moved_to_date: string | null };
export type TaskFocusSession = { id: string; task_id: string; request_id: string; status: 'in_progress' | 'completed' | 'cancelled'; started_at: string; completed_at: string | null; duration_seconds: number | null };
export type GrowthRewardRule = {
  profile_id: string; module_id: GrowthModuleId; enabled: boolean; reward_minutes: number;
  daily_cap_minutes: number; weekly_cap_minutes: number; minimum_session_minutes: number;
  require_parent_approval: boolean; updated_at: string | null;
};
export type GrowthRewardEvent = {
  id: string; profile_id: string; module_id: GrowthModuleId; source_type: 'session' | 'task'; source_id: string;
  requested_minutes: number; status: 'pending' | 'awarded' | 'capped' | 'rejected'; awarded_minutes: number;
  created_at: string;
};
export type WeeklyPillarGoal = { profile_id: string; module_id: ModuleKey; target_count: number; unit: 'workouts' | 'minutes' | 'sessions' | 'tasks'; active_days: number[]; updated_at: string };
export type WeeklyPillarActual = { module_id: ModuleKey; actual_value: number };
export function formatGoalDays(activeDays: number[]) {
  const labels = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
  return [...activeDays].sort((left, right) => left - right).map((day) => labels[day]).join(', ');
}
export type GrowthModuleData = { items: GrowthItem[]; sessions: GrowthSession[]; records: GrowthRecord[];
  studyPlan: StudyPlanSlot[]; studyPlanChanges: StudyPlanChange[]; taskFocusSessions: TaskFocusSession[];
  recordAttachments: GrowthRecordAttachment[] };
export type GrowthOverview = {
  module_id: GrowthModuleId;
  active_items: number;
  completed_items: number;
  sessions_this_week: number;
  minutes_this_week: number;
  average_read_progress: number | null;
  due_today: number;
};
export type GrowthActivityEvent = {
  id: string;
  moduleId: GrowthModuleId;
  label: string;
  detail: string;
  occurredAt: string;
};

function client() {
  if (!supabase) throw new Error('Bloom is not configured.');
  return supabase;
}

export async function loadGrowthModule(profileId: string, moduleId: GrowthModuleId): Promise<GrowthModuleData> {
  const db = client();
  const [items, sessions, records, studyPlan, studyPlanChanges, taskFocusSessions, recordAttachments] = await Promise.all([
    db.from('bloom_growth_items')
      .select('id,parent_id,module_id,item_type,title,notes,state,due_date,target_minutes,progress_percent,priority,postponed_until,reading_status,reading_kind,author,genre,page_count,current_page,completed_at,created_at,updated_at')
      .eq('profile_id', profileId).eq('module_id', moduleId).order('updated_at', { ascending: false }),
    moduleId === 'tasks'
      ? Promise.resolve({ data: [], error: null })
      : db.from('bloom_growth_sessions')
        .select('id,module_id,item_id,source_device_id,source_device_name,request_id,status,started_at,completed_at,duration_seconds')
        .eq('profile_id', profileId).eq('module_id', moduleId).order('started_at', { ascending: false }).limit(50),
    db.from('bloom_growth_records')
      .select('id,module_id,item_id,kind,title,body,metadata,scheduled_at,score,created_at,updated_at')
      .eq('profile_id', profileId).eq('module_id', moduleId).order('created_at', { ascending: false }).limit(100),
    moduleId === 'study'
      ? db.from('bloom_study_plan_slots').select('id,item_id,day_of_week,target_minutes').eq('profile_id', profileId).order('day_of_week')
      : Promise.resolve({ data: [], error: null }),
    moduleId === 'study'
      ? db.from('bloom_study_plan_changes').select('item_id,original_date,action,moved_to_date').eq('profile_id', profileId).order('original_date')
      : Promise.resolve({ data: [], error: null }),
    moduleId === 'tasks'
      ? db.from('bloom_task_focus_sessions').select('id,task_id,request_id,status,started_at,completed_at,duration_seconds').eq('profile_id', profileId).order('started_at', { ascending: false }).limit(30)
      : Promise.resolve({ data: [], error: null }),
    moduleId === 'study'
      ? db.from('bloom_growth_record_attachments').select('record_id,document_id').eq('profile_id', profileId)
      : Promise.resolve({ data: [], error: null }),
  ]);
  for (const result of [items, sessions, records, studyPlan, studyPlanChanges, taskFocusSessions, recordAttachments]) if (result.error) throw result.error;
  return {
    items: (items.data ?? []).map((item) => ({ ...item, progress_percent: Number(item.progress_percent) })) as GrowthItem[],
    sessions: (sessions.data ?? []) as GrowthSession[],
    records: (records.data ?? []) as GrowthRecord[],
    studyPlan: (studyPlan.data ?? []).map((slot) => ({ ...slot, day_of_week: Number(slot.day_of_week), target_minutes: Number(slot.target_minutes) })) as StudyPlanSlot[],
    studyPlanChanges: (studyPlanChanges.data ?? []) as StudyPlanChange[],
    taskFocusSessions: (taskFocusSessions.data ?? []).map((session) => ({ ...session,
      duration_seconds: session.duration_seconds == null ? null : Number(session.duration_seconds) })) as TaskFocusSession[],
    recordAttachments: (recordAttachments.data ?? []) as GrowthRecordAttachment[],
  };
}

export async function loadReadSessionsSince(profileId: string, startedAfter: string): Promise<GrowthSession[]> {
  const { data, error } = await client().from('bloom_growth_sessions')
    .select('id,module_id,item_id,source_device_id,source_device_name,request_id,status,started_at,completed_at,duration_seconds')
    .eq('profile_id', profileId).eq('module_id', 'read').gte('started_at', startedAfter)
    .order('started_at', { ascending: false }).limit(1000);
  if (error) throw error;
  return (data ?? []).map((session) => ({ ...session,
    duration_seconds: session.duration_seconds == null ? null : Number(session.duration_seconds) })) as GrowthSession[];
}

export async function loadGrowthDocuments(moduleId: 'study' | 'read'): Promise<GrowthDocument[]> {
  const { data, error } = await client().from('bloom_growth_documents')
    .select('id,profile_id,module_id,item_id,title,file_name,format,mime_type,byte_size,storage_path,created_at')
    .eq('module_id', moduleId).order('created_at', { ascending: false }).limit(100);
  if (error) throw error;
  return (data ?? []).map((document) => ({ ...document, byte_size: Number(document.byte_size) })) as GrowthDocument[];
}

export async function createGrowthDocument(args: {
  moduleId: 'study' | 'read'; itemId: string; title: string; fileName: string; format: 'pdf' | 'docx' | 'epub';
  mimeType: string; byteSize: number; requestId: string;
}) {
  const { data, error } = await client().rpc('bloom_create_growth_document', {
    p_module_id: args.moduleId, p_item_id: args.itemId, p_title: args.title, p_file_name: args.fileName,
    p_format: args.format, p_mime_type: args.mimeType, p_byte_size: args.byteSize, p_request_id: args.requestId,
  });
  if (error) throw error;
  if (!data || typeof data.id !== 'string' || typeof data.storage_path !== 'string') throw new Error('Could not prepare the private upload.');
  return { id: data.id as string, storagePath: data.storage_path as string };
}

export async function deleteGrowthDocument(document: Pick<GrowthDocument, 'id' | 'storage_path'>) {
  const db = client();
  const { error: storageError } = await db.storage.from('bloom-growth-content').remove([document.storage_path]);
  if (storageError) throw storageError;
  const { error } = await db.rpc('bloom_delete_growth_document', { p_document_id: document.id });
  if (error) throw error;
}

export async function uploadGrowthDocumentContent(storagePath: string, content: ArrayBuffer, mimeType: string) {
  const { error } = await client().storage.from('bloom-growth-content').upload(storagePath, content, {
    contentType: mimeType,
    upsert: false,
  });
  if (error) throw error;
}

export async function createGrowthDocumentUrl(storagePath: string) {
  const { data, error } = await client().storage.from('bloom-growth-content').createSignedUrl(storagePath, 3600);
  if (error || !data?.signedUrl) throw error ?? new Error('Could not open this private file.');
  return data.signedUrl;
}

export async function saveMockExamAttempt(examId: string, answers: Record<string, string>, durationSeconds: number, requestId: string) {
  const { data, error } = await client().rpc('bloom_submit_mock_exam_objective', {
    p_exam_id: examId, p_answers: answers, p_duration_seconds: durationSeconds, p_request_id: requestId,
  });
  if (error) throw error;
  return data as { record_id: string; score: number; results: unknown[]; duration_seconds: number; assessment_scope: 'objective' };
}

export async function requestMockExamAssessment(requestId: string, examId: string, answers: Record<string, string>, durationSeconds: number) {
  const { data, error } = await client().functions.invoke('bloom-mock-exam-assess', {
    body: { request_id: requestId, exam_id: examId, answers, duration_seconds: durationSeconds },
  });
  if (error || !data || data.status !== 'assessed' || typeof data.score !== 'number' || !Array.isArray(data.results)) {
    throw new Error(typeof data?.error === 'string' ? data.error : 'AI assessment is unavailable or Study consent is incomplete.');
  }
  return data as { status: 'assessed'; record_id: string; score: number; results: unknown[]; duration_seconds: number; assessment_scope: 'mixed'; uncertainty: string };
}

export async function setStudyDocumentAiConsent(consent: boolean, adultAttested: boolean) {
  const { error } = await client().rpc('bloom_set_document_ai_consent', { p_consent: consent, p_adult_attested: adultAttested });
  if (error) throw error;
}

export async function requestStudyDocumentHelp(requestId: string, documentId: string, prompt: string) {
  const { data, error } = await client().functions.invoke('bloom-study-document-help', {
    body: { request_id: requestId, document_id: documentId, prompt },
  });
  if (error || !data || data.status !== 'answered' || typeof data.answer !== 'string' || !Array.isArray(data.citations)) {
    throw new Error(typeof data?.error === 'string' ? data.error : 'Source-aware help is unavailable or consent is incomplete.');
  }
  return data as { id: string; answer: string; uncertainty: string; citations: { reference: string; quote: string }[] };
}

export async function loadStudyDocumentAnswers(documentId: string) {
  const { data, error } = await client().from('bloom_document_help_answers')
    .select('id,question,answer,uncertainty,citations,created_at').eq('document_id', documentId)
    .order('created_at', { ascending: false }).limit(20);
  if (error) throw error;
  return (data ?? []) as { id: string; question: string; answer: string; uncertainty: string;
    citations: { reference: string; quote: string }[]; created_at: string }[];
}

export async function loadGrowthActivity(profileId: string): Promise<GrowthActivityEvent[]> {
  const db = client();
  const [items, sessions] = await Promise.all([
    db.from('bloom_growth_items')
      .select('id,module_id,item_type,title,state,completed_at')
      .eq('profile_id', profileId).order('updated_at', { ascending: false }).limit(100),
    db.from('bloom_growth_sessions')
      .select('id,module_id,item_id,started_at,completed_at,duration_seconds')
      .eq('profile_id', profileId).eq('status', 'completed').order('completed_at', { ascending: false }).limit(50),
  ]);
  if (items.error) throw items.error;
  if (sessions.error) throw sessions.error;
  const itemTitles = new Map((items.data ?? []).map((item) => [item.id, item.title]));
  const itemEvents = (items.data ?? []).filter((item) => item.state === 'completed' && item.completed_at).map((item) => ({
    id: `item:${item.id}`,
    moduleId: item.module_id as GrowthModuleId,
    label: item.item_type === 'task' ? 'Task completed' : 'Reading item finished',
    detail: item.title,
    occurredAt: String(item.completed_at),
  }));
  const sessionEvents = (sessions.data ?? []).map((session) => ({
    id: `session:${session.id}`,
    moduleId: session.module_id as GrowthModuleId,
    label: session.module_id === 'study' ? 'Study session' : 'Reading session',
    detail: `${itemTitles.get(session.item_id) ?? 'Activity'} · ${Math.floor(Number(session.duration_seconds ?? 0) / 60)} min`,
    occurredAt: String(session.completed_at ?? session.started_at),
  }));
  return [...itemEvents, ...sessionEvents].sort((left, right) => Date.parse(right.occurredAt) - Date.parse(left.occurredAt));
}

export async function loadGrowthOverview(): Promise<GrowthOverview[]> {
  const { data, error } = await client().rpc('bloom_growth_overview');
  if (error) throw error;
  return (data ?? []).map((row: Record<string, unknown>) => ({
    module_id: row.module_id as GrowthModuleId,
    active_items: Number(row.active_items ?? 0),
    completed_items: Number(row.completed_items ?? 0),
    sessions_this_week: Number(row.sessions_this_week ?? 0),
    minutes_this_week: Number(row.minutes_this_week ?? 0),
    average_read_progress: row.average_read_progress == null ? null : Number(row.average_read_progress),
    due_today: Number(row.due_today ?? 0),
  }));
}

export async function loadWeeklyPillarGoals(): Promise<WeeklyPillarGoal[]> {
  const { data, error } = await client().from('bloom_weekly_pillar_goals')
    .select('profile_id,module_id,target_count,unit,active_days,updated_at').order('module_id');
  if (error) throw error;
  return (data ?? []).map((goal) => ({ ...goal, target_count: Number(goal.target_count),
    active_days: (goal.active_days as number[]).map(Number) })) as WeeklyPillarGoal[];
}

export async function loadWeeklyPillarActuals(): Promise<WeeklyPillarActual[]> {
  const { data, error } = await client().rpc('bloom_weekly_pillar_actuals');
  if (error) throw error;
  return (data ?? []).map((row: Record<string, unknown>) => ({
    module_id: row.module_id as ModuleKey,
    actual_value: Number(row.actual_value ?? 0),
  }));
}

export async function saveWeeklyPillarGoals(goals: Pick<WeeklyPillarGoal, 'module_id' | 'target_count' | 'active_days'>[]) {
  const { error } = await client().rpc('bloom_save_weekly_pillar_goals', { p_goals: goals.map((goal) => ({
    module_id: goal.module_id, target_count: goal.target_count, active_days: goal.active_days,
  })) });
  if (error) throw error;
}

export async function loadGrowthRewards(profileId: string) {
  const db = client();
  const [rules, events] = await Promise.all([
    db.from('bloom_growth_reward_rules')
      .select('profile_id,module_id,enabled,reward_minutes,daily_cap_minutes,weekly_cap_minutes,minimum_session_minutes,require_parent_approval,updated_at')
      .eq('profile_id', profileId),
    db.from('bloom_growth_reward_events')
      .select('id,profile_id,module_id,source_type,source_id,requested_minutes,status,awarded_minutes,created_at')
      .eq('profile_id', profileId).order('created_at', { ascending: false }).limit(30),
  ]);
  if (rules.error) throw rules.error;
  if (events.error) throw events.error;
  return {
    rules: (rules.data ?? []).map((rule) => ({ ...rule,
      reward_minutes: Number(rule.reward_minutes), daily_cap_minutes: Number(rule.daily_cap_minutes),
      weekly_cap_minutes: Number(rule.weekly_cap_minutes), minimum_session_minutes: Number(rule.minimum_session_minutes),
    })) as GrowthRewardRule[],
    events: (events.data ?? []).map((event) => ({ ...event,
      requested_minutes: Number(event.requested_minutes), awarded_minutes: Number(event.awarded_minutes),
    })) as GrowthRewardEvent[],
  };
}

export async function saveGrowthRewardRule(rule: Omit<GrowthRewardRule, 'profile_id' | 'updated_at'> & { profile_id: string }) {
  const { error } = await client().rpc('bloom_save_growth_reward_rules', {
    p_profile_id: rule.profile_id, p_module_id: rule.module_id, p_enabled: rule.enabled,
    p_reward_minutes: rule.reward_minutes, p_daily_cap_minutes: rule.daily_cap_minutes,
    p_weekly_cap_minutes: rule.weekly_cap_minutes, p_minimum_session_minutes: rule.minimum_session_minutes,
    p_require_parent_approval: rule.require_parent_approval,
  });
  if (error) throw error;
}

export async function reviewGrowthReward(eventId: string, approve: boolean) {
  const { data, error } = await client().rpc('bloom_review_growth_reward', { p_event_id: eventId, p_approve: approve });
  if (error) throw error;
  return Number(data ?? 0);
}

export async function createGrowthItem(args: {
  moduleId: GrowthModuleId;
  title: string;
  notes: string;
  dueDate?: string | null;
  targetMinutes?: number | null;
  requestId: string;
}) {
  const itemType: GrowthItemType = args.moduleId === 'study' ? 'subject' : args.moduleId === 'read' ? 'reading' : 'task';
  const { data, error } = await client().rpc('bloom_create_growth_item', {
    p_module_id: args.moduleId,
    p_item_type: itemType,
    p_title: args.title,
    p_notes: args.notes,
    p_due_date: args.dueDate ?? null,
    p_target_minutes: args.targetMinutes ?? null,
    p_request_id: args.requestId,
  });
  if (error) throw error;
  if (typeof data !== 'string') throw new Error('Bloom could not save this item.');
  return data;
}

export async function createGrowthChild(args: {
  parentId: string; itemType: Exclude<GrowthItemType, 'subject' | 'reading' | 'project' | 'task'> | 'project' | 'task';
  title: string; notes: string; dueDate?: string | null; requestId: string;
}) {
  const { data, error } = await client().rpc('bloom_create_growth_child', {
    p_parent_id: args.parentId, p_item_type: args.itemType, p_title: args.title, p_notes: args.notes,
    p_due_date: args.dueDate ?? null, p_request_id: args.requestId,
  });
  if (error) throw error;
  if (typeof data !== 'string') throw new Error('Bloom could not save this item.');
  return data;
}

export async function createGrowthProject(args: { title: string; notes: string; dueDate?: string | null; requestId: string }) {
  const { data, error } = await client().rpc('bloom_create_growth_project', {
    p_title: args.title, p_notes: args.notes, p_due_date: args.dueDate ?? null, p_request_id: args.requestId,
  });
  if (error) throw error;
  if (typeof data !== 'string') throw new Error('Bloom could not save this project.');
  return data;
}

export async function saveStudyPlan(entries: { itemId: string; dayOfWeek: number; targetMinutes: number }[]) {
  const { error } = await client().rpc('bloom_save_study_plan', { p_entries: entries.map((entry) => ({
    item_id: entry.itemId, day_of_week: entry.dayOfWeek, target_minutes: entry.targetMinutes,
  })) });
  if (error) throw error;
}

export async function changeStudyOccurrence(itemId: string, originalDate: string, action: 'skip' | 'move', movedToDate?: string) {
  const { error } = await client().rpc('bloom_change_study_occurrence', {
    p_item_id: itemId, p_original_date: originalDate, p_action: action, p_moved_to_date: movedToDate ?? null,
  });
  if (error) throw error;
}

export async function startTaskFocus(taskId: string, requestId: string) {
  const { data, error } = await client().rpc('bloom_start_task_focus', { p_task_id: taskId, p_request_id: requestId });
  if (error) throw error;
  if (typeof data !== 'string') throw new Error('Bloom could not start Focus.');
  return data;
}

export async function finishTaskFocus(sessionId: string, cancel = false) {
  const { data, error } = await client().rpc('bloom_finish_task_focus', { p_session_id: sessionId, p_cancel: cancel });
  if (error) throw error;
  if (cancel) return { durationSeconds: null, completedAt: null };
  const result = data?.[0];
  if (!result || typeof result.duration_seconds !== 'number') throw new Error('Bloom could not finish Focus.');
  return { durationSeconds: result.duration_seconds, completedAt: String(result.completed_at) };
}

export async function saveGrowthRecord(args: {
  moduleId: GrowthModuleId; itemId?: string | null; kind: GrowthRecordKind; title: string; body: string;
  metadata?: Record<string, unknown>; scheduledAt?: string | null; score?: number | null; requestId: string;
}) {
  const { data, error } = await client().rpc('bloom_save_growth_record', {
    p_module_id: args.moduleId, p_item_id: args.itemId ?? null, p_kind: args.kind, p_title: args.title,
    p_body: args.body, p_metadata: args.metadata ?? {}, p_scheduled_at: args.scheduledAt ?? null,
    p_score: args.score ?? null, p_request_id: args.requestId,
  });
  if (error) throw error;
  if (typeof data !== 'string') throw new Error('Bloom could not save this entry.');
  return data;
}

export async function updateGrowthRecord(recordId: string, title: string, body: string, metadata: Record<string, unknown>) {
  const { error } = await client().rpc('bloom_update_growth_record', { p_record_id: recordId, p_title: title, p_body: body, p_metadata: metadata });
  if (error) throw error;
}

export async function saveStudyVerification(itemId: string, title: string, body: string, documentId: string | null, requestId: string) {
  const { data, error } = await client().rpc('bloom_save_study_verification', {
    p_item_id: itemId,
    p_title: title,
    p_body: body,
    p_document_id: documentId,
    p_request_id: requestId,
  });
  if (error) throw error;
  if (typeof data !== 'string') throw new Error('Bloom could not save this Study verification.');
  return data;
}

export async function updateStudyVerification(recordId: string, title: string, body: string, documentId: string | null) {
  const { error } = await client().rpc('bloom_update_study_verification', {
    p_record_id: recordId,
    p_title: title,
    p_body: body,
    p_document_id: documentId,
  });
  if (error) throw error;
}

export async function deleteGrowthRecord(recordId: string) {
  const { error } = await client().rpc('bloom_delete_growth_record', { p_record_id: recordId });
  if (error) throw error;
}

export async function submitStudyReview(promptId: string, response: string, rating: 'hard' | 'remembered' | 'easy', nextDays: number, requestId: string) {
  const { data, error } = await client().rpc('bloom_submit_study_review', {
    p_prompt_id: promptId, p_response: response, p_rating: rating, p_next_days: nextDays, p_request_id: requestId,
  });
  if (error) throw error;
  if (typeof data !== 'string') throw new Error('Bloom could not schedule the next review.');
  return data;
}

export async function updateGrowthItem(item: GrowthItem, update: {
  title?: string;
  notes?: string;
  dueDate?: string | null;
  state?: GrowthItemState;
  progressPercent?: number;
}) {
  const { error } = await client().rpc('bloom_update_growth_item', {
    p_item_id: item.id,
    p_title: update.title ?? item.title,
    p_notes: update.notes ?? item.notes,
    p_due_date: update.dueDate === undefined ? item.due_date : update.dueDate,
    p_state: update.state ?? item.state,
    p_progress_percent: update.progressPercent ?? item.progress_percent,
  });
  if (error) throw error;
}

export async function updateGrowthTaskMetadata(itemId: string, priority: TaskPriority, postponedUntil: string | null) {
  const { error } = await client().rpc('bloom_update_task_metadata', {
    p_item_id: itemId,
    p_priority: priority,
    p_postponed_until: postponedUntil,
  });
  if (error) throw error;
}

export async function updateGrowthReadingDetails(itemId: string, details: {
  author: string; genre: string; pageCount: number | null; currentPage: number | null; status: ReadingStatus; readingKind?: ReadingKind;
}) {
  const { error } = await client().rpc('bloom_update_reading_details_v2', {
    p_item_id: itemId,
    p_author: details.author,
    p_genre: details.genre,
    p_page_count: details.pageCount,
    p_current_page: details.currentPage,
    p_reading_status: details.status,
    p_reading_kind: details.readingKind ?? null,
  });
  if (error) throw error;
}

export async function startGrowthSession(moduleId: 'study' | 'read', itemId: string, sourceDevice: { deviceId: string; displayName: string }, requestId: string) {
  const { data, error } = await client().rpc('bloom_start_growth_session', {
    p_module_id: moduleId, p_item_id: itemId, p_source_device_id: sourceDevice.deviceId,
    p_source_device_name: sourceDevice.displayName, p_request_id: requestId,
  });
  if (error) throw error;
  if (typeof data !== 'string') throw new Error('Bloom could not start this session.');
  return data;
}

export async function finishGrowthSession(sessionId: string) {
  const { data, error } = await client().rpc('bloom_finish_growth_session', { p_session_id: sessionId });
  if (error) throw error;
  const result = data?.[0];
  if (!result || typeof result.duration_seconds !== 'number') throw new Error('Bloom could not finish this session.');
  return { durationSeconds: result.duration_seconds, completedAt: String(result.completed_at) };
}

export async function cancelGrowthSession(sessionId: string) {
  const { error } = await client().rpc('bloom_cancel_growth_session', { p_session_id: sessionId });
  if (error) throw error;
}

export function formatElapsed(seconds: number) {
  const safeSeconds = Number.isFinite(seconds) ? Math.max(0, Math.floor(seconds)) : 0;
  const hours = Math.floor(safeSeconds / 3600);
  const minutes = Math.floor((safeSeconds % 3600) / 60);
  const remainder = safeSeconds % 60;
  return hours ? `${hours}:${String(minutes).padStart(2, '0')}:${String(remainder).padStart(2, '0')}`
    : `${String(minutes).padStart(2, '0')}:${String(remainder).padStart(2, '0')}`;
}
