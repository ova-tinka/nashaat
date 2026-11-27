begin;

create table bloom_private.growth_ai_quota_events (
  request_id uuid primary key,
  profile_id uuid not null references public.bloom_profiles(id) on delete cascade,
  module_id text not null check (module_id in ('study', 'read', 'tasks')),
  request_kind text not null check (request_kind in ('task_breakdown', 'study_tutor', 'mock_exam_assess', 'document_help', 'read_reflection')),
  status text not null check (status in ('pending', 'completed', 'failed', 'cleared')),
  created_at timestamptz not null default clock_timestamp(),
  finished_at timestamptz
);

create index growth_ai_quota_events_profile_created_idx
  on bloom_private.growth_ai_quota_events(profile_id, created_at desc);

create index growth_ai_quota_events_profile_pending_idx
  on bloom_private.growth_ai_quota_events(profile_id, created_at desc)
  where status = 'pending';

revoke all on bloom_private.growth_ai_quota_events from public, anon, authenticated;

-- Backfill the active 24-hour quota window from existing request metadata.
insert into bloom_private.growth_ai_quota_events(request_id, profile_id, module_id, request_kind, status, created_at, finished_at)
select id, profile_id, module_id, request_kind, status, created_at, completed_at
from bloom_private.growth_ai_requests
where created_at > clock_timestamp() - interval '24 hours'
on conflict (request_id) do nothing;

create function bloom_private.assert_growth_ai_quota(p_profile_id uuid)
returns void language plpgsql security definer set search_path = pg_catalog, pg_temp as $$
begin
  if (select count(*) from bloom_private.growth_ai_quota_events q
      where q.profile_id = p_profile_id and q.created_at > clock_timestamp() - interval '24 hours') >= 10
    or (select count(*) from bloom_private.growth_ai_quota_events q
      where q.profile_id = p_profile_id and q.created_at > clock_timestamp() - interval '1 minute') >= 2 then
    raise exception 'AI request limit reached';
  end if;
  if exists (select 1 from bloom_private.growth_ai_quota_events q
      where q.profile_id = p_profile_id and q.status = 'pending'
        and q.created_at > clock_timestamp() - interval '2 minutes') then
    raise exception 'An AI request is already running';
  end if;
end;
$$;
revoke all on function bloom_private.assert_growth_ai_quota(uuid) from public, anon, authenticated;

create or replace function bloom_private.begin_growth_ai_request(p_request_id uuid, p_module_id text, p_kind text, p_item_id uuid, p_prompt text)
returns jsonb language plpgsql security definer set search_path = pg_catalog, pg_temp as $$
declare
  v_profile uuid := bloom_private.current_profile_id();
  v_child boolean;
  v_settings public.bloom_growth_ai_settings%rowtype;
  v_task public.bloom_growth_items%rowtype;
begin
  if v_profile is null then raise exception 'Sign in to request a task breakdown'; end if;
  if p_request_id is null or p_module_id <> 'tasks' or p_kind <> 'task_breakdown'
    or p_prompt is null or char_length(trim(p_prompt)) not between 1 and 2000 then raise exception 'Check the AI request'; end if;
  if not bloom_private.has_module_access(v_profile, 'tasks') then raise exception 'Tasks access is not assigned' using errcode = '42501'; end if;
  select * into v_task from public.bloom_growth_items i where i.id = p_item_id and i.profile_id = v_profile
    and i.module_id = 'tasks' and i.item_type = 'task' and i.state = 'active';
  if not found then raise exception 'Choose an active task'; end if;
  select * into v_settings from public.bloom_growth_ai_settings s where s.profile_id = v_profile and s.module_id = 'tasks';
  v_child := bloom_private.is_child_profile(v_profile);
  if not found or not v_settings.sharing_consent or (v_child and not (v_settings.parent_enabled
      and v_settings.parent_sharing_consent and v_settings.minor_eligible_attested))
    or (not v_child and not v_settings.adult_attested) then raise exception 'Task AI consent and eligibility are required'; end if;
  perform pg_advisory_xact_lock(hashtextextended('bloom-growth-ai:' || v_profile::text, 0));
  if exists (select 1 from bloom_private.growth_ai_requests r where r.profile_id = v_profile and r.id = p_request_id)
    or exists (select 1 from bloom_private.growth_ai_quota_events q where q.request_id = p_request_id) then
    raise exception 'This AI request has already been used';
  end if;
  perform bloom_private.assert_growth_ai_quota(v_profile);
  insert into bloom_private.growth_ai_quota_events(request_id, profile_id, module_id, request_kind, status)
    values (p_request_id, v_profile, p_module_id, p_kind, 'pending');
  insert into bloom_private.growth_ai_requests(id, profile_id, module_id, request_kind, item_id, status)
    values (p_request_id, v_profile, p_module_id, p_kind, p_item_id, 'pending');
  return jsonb_build_object('is_child', v_child, 'task', jsonb_build_object('title', left(v_task.title, 120), 'notes', left(v_task.notes, 1000)));
end;
$$;

create or replace function bloom_private.finish_growth_ai_request(p_request_id uuid)
returns void language plpgsql security definer set search_path = pg_catalog, pg_temp as $$
begin
  update bloom_private.growth_ai_requests set status = 'completed', completed_at = clock_timestamp()
    where id = p_request_id and status = 'pending';
  if not found then raise exception 'AI request is unavailable'; end if;
  update bloom_private.growth_ai_quota_events set status = 'completed', finished_at = clock_timestamp()
    where request_id = p_request_id and status = 'pending';
end;
$$;

create or replace function bloom_private.fail_growth_ai_request(p_request_id uuid)
returns void language plpgsql security definer set search_path = pg_catalog, pg_temp as $$
begin
  update bloom_private.growth_ai_requests set status = 'failed'
    where id = p_request_id and status = 'pending';
  update bloom_private.growth_ai_quota_events set status = 'failed', finished_at = clock_timestamp()
    where request_id = p_request_id and status = 'pending';
end;
$$;

create or replace function bloom_private.begin_mock_exam_assessment(p_request_id uuid, p_exam_id uuid, p_answers jsonb)
returns jsonb language plpgsql security definer set search_path = pg_catalog, pg_temp as $$
declare
  v_profile uuid := bloom_private.current_profile_id(); v_exam public.bloom_growth_records%rowtype;
  v_settings public.bloom_growth_ai_settings%rowtype; v_child boolean; v_existing bloom_private.growth_ai_requests%rowtype;
  v_questions jsonb;
begin
  if v_profile is null or not bloom_private.has_module_access(v_profile, 'study') then raise exception 'Study access is required' using errcode = '42501'; end if;
  if p_request_id is null or p_exam_id is null or jsonb_typeof(p_answers) <> 'object' or pg_column_size(p_answers) > 16384 then raise exception 'Check the exam answers'; end if;
  select * into v_exam from public.bloom_growth_records r where r.id = p_exam_id and r.profile_id = v_profile
    and r.module_id = 'study' and r.kind = 'exam';
  if not found then raise exception 'Mock exam not found' using errcode = '42501'; end if;
  begin v_questions := (v_exam.body::jsonb)->'questions'; exception when others then raise exception 'Mock exam content is invalid'; end;
  if jsonb_typeof(v_questions) <> 'array' or jsonb_array_length(v_questions) not between 1 and 50 then raise exception 'Mock exam content is invalid'; end if;
  select * into v_settings from public.bloom_growth_ai_settings where profile_id = v_profile and module_id = 'study';
  v_child := bloom_private.is_child_profile(v_profile);
  if not found or not v_settings.sharing_consent or (v_child and not (v_settings.parent_enabled and v_settings.parent_sharing_consent and v_settings.minor_eligible_attested))
    or (not v_child and not v_settings.adult_attested) then raise exception 'Study AI consent and eligibility are required'; end if;
  perform pg_advisory_xact_lock(hashtextextended('bloom-growth-ai:' || v_profile::text, 0));
  select * into v_existing from bloom_private.growth_ai_requests where profile_id = v_profile and id = p_request_id;
  if found then
    if v_existing.request_kind <> 'mock_exam_assess' or v_existing.source_record_id <> p_exam_id or v_existing.response is distinct from p_answers then raise exception 'AI request id was already used'; end if;
    if v_existing.status = 'completed' then return jsonb_build_object('status', 'completed', 'result', v_existing.result); end if;
    raise exception 'This assessment is already in progress';
  end if;
  if exists (select 1 from bloom_private.growth_ai_quota_events q where q.request_id = p_request_id) then
    raise exception 'AI request id was already used';
  end if;
  perform bloom_private.assert_growth_ai_quota(v_profile);
  insert into bloom_private.growth_ai_quota_events(request_id, profile_id, module_id, request_kind, status)
    values (p_request_id, v_profile, 'study', 'mock_exam_assess', 'pending');
  insert into bloom_private.growth_ai_requests(id, profile_id, module_id, request_kind, item_id, source_record_id, response, status)
    values (p_request_id, v_profile, 'study', 'mock_exam_assess', v_exam.item_id, p_exam_id, p_answers, 'pending');
  return jsonb_build_object('status', 'pending', 'is_child', v_child,
    'exam', jsonb_build_object('title', v_exam.title, 'definition', v_exam.body::jsonb,
      'source_reference', coalesce(v_exam.metadata->>'source_reference', '')),
    'questions', v_questions, 'answers', p_answers);
end;
$$;

create or replace function bloom_private.finish_mock_exam_assessment(p_request_id uuid, p_assessments jsonb, p_duration_seconds integer)
returns jsonb language plpgsql security definer set search_path = pg_catalog, pg_temp as $$
declare
  v_req bloom_private.growth_ai_requests%rowtype; v_exam public.bloom_growth_records%rowtype;
  v_question jsonb; v_assessment jsonb; v_answer text; v_correct boolean; v_score numeric;
  v_count integer := 0; v_score_sum numeric := 0; v_short_ids text[] := '{}'; v_result jsonb := '[]'::jsonb;
  v_attempt jsonb; v_attempt_id uuid;
begin
  if p_request_id is null or jsonb_typeof(p_assessments) <> 'array' or p_duration_seconds is null or p_duration_seconds not between 0 and 43200 then
    raise exception 'Invalid mock exam assessment'; end if;
  select * into v_req from bloom_private.growth_ai_requests where id = p_request_id and request_kind = 'mock_exam_assess' for update;
  if not found then raise exception 'Assessment is unavailable'; end if;
  if v_req.status = 'completed' and v_req.result is not null then return v_req.result; end if;
  if v_req.status <> 'pending' then raise exception 'Assessment is unavailable'; end if;
  select * into v_exam from public.bloom_growth_records where id = v_req.source_record_id and profile_id = v_req.profile_id and kind = 'exam';
  if not found then raise exception 'Mock exam was deleted'; end if;
  for v_question in select value from jsonb_array_elements((v_exam.body::jsonb)->'questions') loop
    v_count := v_count + 1; v_answer := coalesce(v_req.response->>(v_question->>'id'), '');
    if v_question->>'type' = 'short_answer' then
      v_short_ids := array_append(v_short_ids, v_question->>'id');
      select value into v_assessment from jsonb_array_elements(p_assessments) where value->>'question_id' = v_question->>'id';
      if v_assessment is null then raise exception 'An answer assessment is missing'; end if;
      v_score := (v_assessment->>'score')::numeric;
      if v_score not between 0 and 100 or char_length(coalesce(v_assessment->>'explanation', '')) not between 1 and 1000
        or char_length(coalesce(v_assessment->>'uncertainty', '')) not between 1 and 500 then raise exception 'Invalid answer assessment'; end if;
      v_score_sum := v_score_sum + v_score;
      v_result := v_result || jsonb_build_array(jsonb_build_object('question_id', v_question->>'id', 'answer', v_answer,
        'score', v_score, 'explanation', v_assessment->>'explanation', 'uncertainty', v_assessment->>'uncertainty'));
    else
      v_correct := lower(trim(v_answer)) = lower(trim(v_question->>'expected_answer'));
      v_score_sum := v_score_sum + case when v_correct then 100 else 0 end;
      v_result := v_result || jsonb_build_array(jsonb_build_object('question_id', v_question->>'id', 'answer', v_answer,
        'correct', v_correct, 'expected_answer', v_question->>'expected_answer', 'explanation', v_question->>'explanation'));
    end if;
  end loop;
  if v_count = 0 or jsonb_array_length(p_assessments) <> cardinality(v_short_ids)
    or exists (select 1 from jsonb_array_elements(p_assessments) a where not ((a->>'question_id') = any(v_short_ids))) then
    raise exception 'Mock exam assessment does not match its questions'; end if;
  v_score := round(v_score_sum / v_count, 2);
  v_attempt := jsonb_build_object('score', v_score, 'results', v_result, 'duration_seconds', p_duration_seconds,
    'assessment_scope', 'mixed', 'uncertainty', 'Short-answer scores are AI suggestions. Review each explanation and adjust your rubric if needed.');
  v_attempt_id := md5(p_request_id::text || ':exam-attempt')::uuid;
  insert into public.bloom_growth_records(id, profile_id, module_id, item_id, kind, title, body, metadata, score, request_id)
    values (v_attempt_id, v_req.profile_id, 'study', v_exam.item_id, 'exam_attempt', 'Mock exam · ' || v_exam.title,
      v_attempt::text, jsonb_build_object('exam_id', v_exam.id, 'source_reference', v_exam.metadata->>'source_reference'), v_score, v_attempt_id)
    on conflict (profile_id, request_id) do nothing;
  update bloom_private.growth_ai_requests set status = 'completed', completed_at = clock_timestamp(), result = v_attempt where id = p_request_id;
  update bloom_private.growth_ai_quota_events set status = 'completed', finished_at = clock_timestamp()
    where request_id = p_request_id and status = 'pending';
  return v_attempt || jsonb_build_object('record_id', v_attempt_id);
end;
$$;

create or replace function bloom_private.begin_document_help_request(p_request_id uuid, p_document_id uuid, p_prompt text)
returns jsonb language plpgsql security definer set search_path = pg_catalog, pg_temp as $$
declare
  v_profile uuid := bloom_private.current_profile_id(); v_doc public.bloom_growth_documents%rowtype;
  v_settings public.bloom_growth_ai_settings%rowtype; v_child boolean; v_existing bloom_private.growth_ai_requests%rowtype;
begin
  if v_profile is null or not bloom_private.has_module_access(v_profile, 'study') then raise exception 'Study access is required' using errcode = '42501'; end if;
  if p_request_id is null or p_document_id is null or p_prompt is null or char_length(trim(p_prompt)) not between 1 and 2000 then raise exception 'Enter a question of up to 2,000 characters'; end if;
  select * into v_doc from public.bloom_growth_documents where id = p_document_id and profile_id = v_profile and module_id = 'study';
  if not found then raise exception 'Study document not found' using errcode = '42501'; end if;
  select * into v_settings from public.bloom_growth_ai_settings where profile_id = v_profile and module_id = 'study';
  v_child := bloom_private.is_child_profile(v_profile);
  if not found or not v_settings.sharing_consent or not v_settings.document_sharing_consent
    or (v_child and not (v_settings.parent_enabled and v_settings.parent_sharing_consent and v_settings.minor_eligible_attested
      and v_settings.document_parent_enabled and v_settings.document_parent_sharing_consent and v_settings.document_minor_eligible_attested))
    or (not v_child and not (v_settings.adult_attested and v_settings.document_adult_attested)) then
    raise exception 'Study document AI consent and eligibility are required';
  end if;
  perform pg_advisory_xact_lock(hashtextextended('bloom-growth-ai:' || v_profile::text, 0));
  select * into v_existing from bloom_private.growth_ai_requests where profile_id = v_profile and id = p_request_id;
  if found then
    if v_existing.request_kind <> 'document_help' or v_existing.document_id <> p_document_id then raise exception 'AI request id was already used'; end if;
    if v_existing.status = 'completed' then return jsonb_build_object('status', 'completed', 'result', v_existing.result); end if;
    raise exception 'This document request is already in progress';
  end if;
  if exists (select 1 from bloom_private.growth_ai_quota_events q where q.request_id = p_request_id) then
    raise exception 'AI request id was already used';
  end if;
  perform bloom_private.assert_growth_ai_quota(v_profile);
  insert into bloom_private.growth_ai_quota_events(request_id, profile_id, module_id, request_kind, status)
    values (p_request_id, v_profile, 'study', 'document_help', 'pending');
  insert into bloom_private.growth_ai_requests(id, profile_id, module_id, request_kind, item_id, document_id, status)
    values (p_request_id, v_profile, 'study', 'document_help', v_doc.item_id, v_doc.id, 'pending');
  return jsonb_build_object('status', 'pending', 'is_child', v_child, 'document_id', v_doc.id, 'storage_path', v_doc.storage_path,
    'file_name', v_doc.file_name, 'format', v_doc.format, 'title', v_doc.title);
end;
$$;

create or replace function bloom_private.finish_document_help_request(
  p_request_id uuid, p_prompt text, p_answer text, p_uncertainty text, p_citations jsonb
) returns jsonb language plpgsql security definer set search_path = pg_catalog, pg_temp as $$
declare v_req bloom_private.growth_ai_requests%rowtype; v_answer_id uuid; v_value jsonb;
begin
  if p_request_id is null or p_prompt is null or char_length(trim(p_prompt)) not between 1 and 2000
    or p_answer is null or char_length(trim(p_answer)) not between 1 and 4000
    or p_uncertainty is null or char_length(trim(p_uncertainty)) not between 1 and 500
    or jsonb_typeof(p_citations) <> 'array' or jsonb_array_length(p_citations) not between 1 and 8 or pg_column_size(p_citations) > 8192 then raise exception 'Invalid document answer'; end if;
  select * into v_req from bloom_private.growth_ai_requests where id = p_request_id and request_kind = 'document_help' for update;
  if not found then raise exception 'Document request is unavailable'; end if;
  if v_req.status = 'completed' and v_req.result is not null then return v_req.result; end if;
  if v_req.status <> 'pending' then raise exception 'Document request is unavailable'; end if;
  for v_value in select value from jsonb_array_elements(p_citations) loop
    if jsonb_typeof(v_value) <> 'object' or char_length(coalesce(v_value->>'reference', '')) not between 1 and 160
      or char_length(coalesce(v_value->>'quote', '')) not between 1 and 500 then raise exception 'Invalid source citation'; end if;
  end loop;
  insert into public.bloom_document_help_answers(profile_id, document_id, request_id, question, answer, uncertainty, citations)
    values (v_req.profile_id, v_req.document_id, p_request_id, trim(p_prompt), trim(p_answer), trim(p_uncertainty), p_citations)
    returning id into v_answer_id;
  v_value := jsonb_build_object('id', v_answer_id, 'answer', trim(p_answer), 'uncertainty', trim(p_uncertainty), 'citations', p_citations);
  update bloom_private.growth_ai_requests set status = 'completed', completed_at = clock_timestamp(), result = v_value where id = p_request_id;
  update bloom_private.growth_ai_quota_events set status = 'completed', finished_at = clock_timestamp()
    where request_id = p_request_id and status = 'pending';
  return v_value;
end;
$$;

create or replace function bloom_private.begin_read_reflection_request(p_request_id uuid, p_item_id uuid)
returns jsonb language plpgsql security definer set search_path = pg_catalog, pg_temp as $$
declare
  v_profile uuid := bloom_private.current_profile_id();
  v_child boolean;
  v_settings public.bloom_growth_ai_settings%rowtype;
  v_item public.bloom_growth_items%rowtype;
  v_request bloom_private.growth_ai_requests%rowtype;
begin
  if v_profile is null then raise exception 'Sign in to request a reading reflection'; end if;
  if p_request_id is null or p_item_id is null then raise exception 'Choose a reading item'; end if;
  if not bloom_private.has_module_access(v_profile, 'read') then
    raise exception 'Read access is not assigned' using errcode = '42501';
  end if;
  select * into v_item from public.bloom_growth_items i where i.id = p_item_id
    and i.profile_id = v_profile and i.module_id = 'read' and i.item_type = 'reading' and i.state = 'active';
  if not found then raise exception 'Choose an active reading item'; end if;

  select * into v_settings from public.bloom_growth_ai_settings s where s.profile_id = v_profile and s.module_id = 'read';
  v_child := bloom_private.is_child_profile(v_profile);
  if not found or not v_settings.sharing_consent
    or (v_child and not (v_settings.parent_enabled and v_settings.parent_sharing_consent and v_settings.minor_eligible_attested))
    or (not v_child and not v_settings.adult_attested) then
    raise exception 'Reading reflection consent and eligibility are required';
  end if;

  perform pg_advisory_xact_lock(hashtextextended('bloom-growth-ai:' || v_profile::text, 0));
  select * into v_request from bloom_private.growth_ai_requests r where r.id = p_request_id and r.profile_id = v_profile;
  if found then
    if v_request.module_id <> 'read' or v_request.request_kind <> 'read_reflection' or v_request.item_id <> p_item_id then
      raise exception 'This AI request was already used';
    end if;
    if v_request.status = 'completed' and v_request.read_reflection_prompt is not null then
      return jsonb_build_object('status', 'completed', 'response', v_request.read_reflection_prompt);
    end if;
    raise exception 'This AI request has already been processed';
  end if;
  if exists (select 1 from bloom_private.growth_ai_quota_events q where q.request_id = p_request_id) then
    raise exception 'This AI request was already used';
  end if;
  perform bloom_private.assert_growth_ai_quota(v_profile);
  insert into bloom_private.growth_ai_quota_events(request_id, profile_id, module_id, request_kind, status)
    values (p_request_id, v_profile, 'read', 'read_reflection', 'pending');
  insert into bloom_private.growth_ai_requests(id, profile_id, module_id, request_kind, item_id, status)
    values (p_request_id, v_profile, 'read', 'read_reflection', p_item_id, 'pending');
  return jsonb_build_object('status', 'pending', 'is_child', v_child,
    'reading', jsonb_build_object('title', left(v_item.title, 120), 'notes', left(v_item.notes, 1000)));
end;
$$;

create or replace function bloom_private.finish_read_reflection_request(p_request_id uuid, p_prompt text, p_uncertainty text)
returns jsonb language plpgsql security definer set search_path = pg_catalog, pg_temp as $$
declare
  v_request bloom_private.growth_ai_requests%rowtype;
  v_settings public.bloom_growth_ai_settings%rowtype;
  v_child boolean;
  v_response jsonb;
begin
  if p_request_id is null or p_prompt is null or char_length(trim(p_prompt)) not between 1 and 120
    or p_uncertainty is null or char_length(trim(p_uncertainty)) not between 1 and 500 then
    raise exception 'Invalid reading reflection response';
  end if;
  select * into v_request from bloom_private.growth_ai_requests r where r.id = p_request_id
    and r.request_kind = 'read_reflection' for update;
  if not found then raise exception 'Reading reflection request is unavailable'; end if;
  v_child := bloom_private.is_child_profile(v_request.profile_id);
  select * into v_settings from public.bloom_growth_ai_settings s
    where s.profile_id = v_request.profile_id and s.module_id = 'read';
  if not found or not v_settings.sharing_consent
    or (v_child and not (v_settings.parent_enabled and v_settings.parent_sharing_consent and v_settings.minor_eligible_attested))
    or (not v_child and not v_settings.adult_attested)
    or not bloom_private.has_module_access(v_request.profile_id, 'read') then
    raise exception 'Reading reflection consent was withdrawn';
  end if;
  v_response := jsonb_build_object('prompt', trim(p_prompt), 'uncertainty', trim(p_uncertainty));
  if v_request.status = 'completed' then
    if v_request.read_reflection_prompt is distinct from v_response then raise exception 'Reading reflection request was already completed'; end if;
    return v_request.read_reflection_prompt;
  end if;
  if v_request.status <> 'pending' then raise exception 'Reading reflection request is unavailable'; end if;
  update bloom_private.growth_ai_requests set status = 'completed', completed_at = clock_timestamp(), read_reflection_prompt = v_response
    where id = p_request_id;
  update bloom_private.growth_ai_quota_events set status = 'completed', finished_at = clock_timestamp()
    where request_id = p_request_id and status = 'pending';
  return v_response;
end;
$$;

create or replace function bloom_private.begin_study_tutor_request(p_request_id uuid, p_item_id uuid, p_prompt text)
returns jsonb language plpgsql security definer set search_path = pg_catalog, pg_temp as $$
declare
  v_profile uuid := bloom_private.current_profile_id();
  v_child boolean;
  v_settings public.bloom_growth_ai_settings%rowtype;
  v_item public.bloom_growth_items%rowtype;
begin
  if v_profile is null then raise exception 'Sign in to use the Study tutor'; end if;
  if p_request_id is null or p_item_id is null or p_prompt is null
    or char_length(trim(p_prompt)) not between 1 and 2000 then raise exception 'Enter a question of up to 2,000 characters'; end if;
  if not bloom_private.has_module_access(v_profile, 'study') then raise exception 'Study access is not assigned' using errcode = '42501'; end if;
  select * into v_item from public.bloom_growth_items i where i.id = p_item_id and i.profile_id = v_profile
    and i.module_id = 'study' and i.state <> 'archived';
  if not found then raise exception 'Choose a Study item'; end if;
  select * into v_settings from public.bloom_growth_ai_settings s where s.profile_id = v_profile and s.module_id = 'study';
  v_child := bloom_private.is_child_profile(v_profile);
  if not found or not v_settings.sharing_consent or (v_child and not (v_settings.parent_enabled
      and v_settings.parent_sharing_consent and v_settings.minor_eligible_attested))
    or (not v_child and not v_settings.adult_attested) then
    raise exception 'Study tutor consent and eligibility are required';
  end if;
  perform pg_advisory_xact_lock(hashtextextended('bloom-growth-ai:' || v_profile::text, 0));
  if exists (select 1 from bloom_private.growth_ai_requests r where r.profile_id = v_profile and r.id = p_request_id)
    or exists (select 1 from bloom_private.growth_ai_quota_events q where q.request_id = p_request_id) then
    raise exception 'This AI request has already been used';
  end if;
  perform bloom_private.assert_growth_ai_quota(v_profile);
  insert into bloom_private.growth_ai_quota_events(request_id, profile_id, module_id, request_kind, status)
    values (p_request_id, v_profile, 'study', 'study_tutor', 'pending');
  insert into bloom_private.growth_ai_requests(id, profile_id, module_id, request_kind, item_id, status)
    values (p_request_id, v_profile, 'study', 'study_tutor', p_item_id, 'pending');
  return jsonb_build_object('is_child', v_child,
    'item', jsonb_build_object('title', left(v_item.title, 120), 'notes', left(v_item.notes, 1000)));
end;
$$;

create or replace function bloom_private.clear_study_tutor_conversation()
returns void language plpgsql security definer set search_path = pg_catalog, pg_temp as $$
declare v_profile uuid := bloom_private.current_profile_id();
begin
  if v_profile is null then raise exception 'Sign in to clear this conversation'; end if;
  if not bloom_private.has_module_access(v_profile, 'study') then raise exception 'Study access is not assigned' using errcode = '42501'; end if;
  perform pg_advisory_xact_lock(hashtextextended('bloom-growth-ai:' || v_profile::text, 0));
  delete from public.bloom_study_tutor_messages where profile_id = v_profile;
  delete from bloom_private.growth_ai_requests where profile_id = v_profile and request_kind = 'study_tutor';
  update bloom_private.growth_ai_quota_events
    set status = 'cleared', finished_at = coalesce(finished_at, clock_timestamp())
    where profile_id = v_profile and request_kind = 'study_tutor' and status = 'pending';
end;
$$;

drop function if exists bloom_private.finish_study_tutor_request(uuid, text, text, text);
create function bloom_private.finish_study_tutor_request(
  p_request_id uuid, p_prompt text, p_answer text, p_uncertainty text
) returns jsonb language plpgsql security definer set search_path = pg_catalog, pg_temp as $$
declare
  v_quota bloom_private.growth_ai_quota_events%rowtype;
  v_request bloom_private.growth_ai_requests%rowtype;
  v_settings public.bloom_growth_ai_settings%rowtype;
  v_child boolean;
begin
  if p_request_id is null or p_prompt is null or char_length(trim(p_prompt)) not between 1 and 2000
    or p_answer is null or char_length(trim(p_answer)) not between 1 and 4000
    or p_uncertainty is null or char_length(p_uncertainty) > 500 then raise exception 'Invalid tutor response'; end if;
  select * into v_quota from bloom_private.growth_ai_quota_events q
    where q.request_id = p_request_id and q.request_kind = 'study_tutor';
  if not found then raise exception 'Study tutor request is unavailable'; end if;

  -- Serialize with clear_study_tutor_conversation() on the owning profile.
  perform pg_advisory_xact_lock(hashtextextended('bloom-growth-ai:' || v_quota.profile_id::text, 0));

  select * into v_quota from bloom_private.growth_ai_quota_events q
    where q.request_id = p_request_id and q.request_kind = 'study_tutor' for update;
  select * into v_request from bloom_private.growth_ai_requests r
    where r.id = p_request_id and r.request_kind = 'study_tutor' for update;

  if v_quota.status = 'cleared' or v_request.id is null then
    return jsonb_build_object('status', 'cleared');
  end if;
  if v_quota.status <> 'pending' or v_request.status <> 'pending' then
    raise exception 'Study tutor request is unavailable';
  end if;

  v_child := bloom_private.is_child_profile(v_request.profile_id);
  select * into v_settings from public.bloom_growth_ai_settings s
    where s.profile_id = v_request.profile_id and s.module_id = 'study';
  if not found or not v_settings.sharing_consent
    or (v_child and not (v_settings.parent_enabled and v_settings.parent_sharing_consent and v_settings.minor_eligible_attested))
    or (not v_child and not v_settings.adult_attested)
    or (v_child and not exists (
      select 1 from public.bloom_child_module_assignments a
      where a.profile_id = v_request.profile_id and a.module_id = 'study' and a.assigned
    )) then
    update bloom_private.growth_ai_requests set status = 'failed' where id = p_request_id and status = 'pending';
    update bloom_private.growth_ai_quota_events set status = 'failed', finished_at = clock_timestamp()
      where request_id = p_request_id and status = 'pending';
    raise exception 'Study tutor consent was withdrawn';
  end if;

  update bloom_private.growth_ai_requests set status = 'completed', completed_at = clock_timestamp()
    where id = p_request_id;
  update bloom_private.growth_ai_quota_events set status = 'completed', finished_at = clock_timestamp()
    where request_id = p_request_id;
  insert into public.bloom_study_tutor_messages(profile_id, item_id, request_id, role, content)
    values (v_request.profile_id, v_request.item_id, p_request_id, 'user', trim(p_prompt));
  insert into public.bloom_study_tutor_messages(profile_id, item_id, request_id, role, content, answer_scope, uncertainty)
    values (v_request.profile_id, v_request.item_id, p_request_id, 'assistant', trim(p_answer), 'general', trim(p_uncertainty));
  return jsonb_build_object('status', 'answered');
end;
$$;

create or replace function public.bloom_finish_study_tutor_request(
  p_request_id uuid, p_prompt text, p_answer text, p_uncertainty text
) returns jsonb language sql security invoker set search_path = pg_catalog, pg_temp as $$
  select bloom_private.finish_study_tutor_request(p_request_id, p_prompt, p_answer, p_uncertainty);
$$;

revoke all on function bloom_private.finish_study_tutor_request(uuid, text, text, text) from public, anon, authenticated;
grant execute on function bloom_private.finish_study_tutor_request(uuid, text, text, text) to service_role;
revoke all on function public.bloom_finish_study_tutor_request(uuid, text, text, text) from public, anon, authenticated;
grant execute on function public.bloom_finish_study_tutor_request(uuid, text, text, text) to service_role;

commit;
