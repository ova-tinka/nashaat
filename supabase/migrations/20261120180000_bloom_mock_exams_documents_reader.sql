begin;

alter table public.bloom_growth_records
  drop constraint bloom_growth_records_kind_check,
  add constraint bloom_growth_records_kind_check check (kind in (
    'verification', 'task_breakdown_draft', 'reading_note', 'reading_annotation', 'vocabulary',
    'practice_question', 'practice_answer', 'review_prompt', 'review_answer', 'exam', 'exam_attempt',
    'reflection', 'achievement', 'reader_position', 'reader_bookmark'
  )),
  drop constraint bloom_growth_records_check,
  add constraint bloom_growth_records_check check (
    (kind in ('verification', 'practice_question', 'practice_answer', 'review_prompt', 'review_answer', 'exam', 'exam_attempt') and module_id = 'study')
    or (kind in ('reading_note', 'reading_annotation', 'vocabulary', 'reflection', 'reader_position', 'reader_bookmark') and module_id = 'read')
    or (kind = 'task_breakdown_draft' and module_id = 'tasks')
    or (kind = 'achievement' and module_id in ('study', 'read', 'tasks'))
  );

alter table bloom_private.growth_ai_requests
  drop constraint growth_ai_requests_request_kind_check,
  add constraint growth_ai_requests_request_kind_check
    check (request_kind in ('task_breakdown', 'study_tutor', 'mock_exam_assess', 'document_help')),
  add column source_record_id uuid references public.bloom_growth_records(id) on delete cascade,
  add column document_id uuid,
  add column response jsonb,
  add column result jsonb;

alter table public.bloom_growth_ai_settings
  add column document_sharing_consent boolean not null default false,
  add column document_adult_attested boolean not null default false,
  add column document_parent_enabled boolean not null default false,
  add column document_minor_eligible_attested boolean not null default false,
  add column document_parent_sharing_consent boolean not null default false,
  add constraint bloom_growth_ai_document_consent_check check (
    (not document_adult_attested or document_sharing_consent)
    and (not document_parent_enabled or (document_minor_eligible_attested and document_parent_sharing_consent))
  );

create table public.bloom_growth_documents (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references public.bloom_profiles(id) on delete cascade,
  module_id text not null check (module_id in ('study', 'read')),
  item_id uuid not null references public.bloom_growth_items(id) on delete cascade,
  title text not null check (char_length(trim(title)) between 1 and 120),
  file_name text not null check (char_length(trim(file_name)) between 1 and 180),
  format text not null check (format in ('pdf', 'docx', 'epub')),
  mime_type text not null check (char_length(mime_type) between 1 and 120),
  byte_size integer not null check (byte_size between 1 and 26214400),
  storage_path text not null unique,
  request_id uuid not null,
  created_at timestamptz not null default clock_timestamp(),
  unique(profile_id, request_id),
  check ((module_id = 'study' and format in ('pdf', 'docx') and byte_size <= 10485760)
    or (module_id = 'read' and format in ('pdf', 'epub')))
);
create index bloom_growth_documents_profile_idx on public.bloom_growth_documents(profile_id, module_id, item_id, created_at desc);
alter table bloom_private.growth_ai_requests
  add constraint growth_ai_requests_document_fk foreign key (document_id)
  references public.bloom_growth_documents(id) on delete cascade;
alter table public.bloom_growth_documents enable row level security;
revoke all on public.bloom_growth_documents from public, anon, authenticated;
grant select on public.bloom_growth_documents to authenticated;
create policy bloom_growth_documents_read on public.bloom_growth_documents for select to authenticated
  using (profile_id = (select bloom_private.current_profile_id()) and bloom_private.has_module_access(profile_id, module_id));

create table public.bloom_document_help_answers (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references public.bloom_profiles(id) on delete cascade,
  document_id uuid not null references public.bloom_growth_documents(id) on delete cascade,
  request_id uuid not null unique,
  question text not null check (char_length(trim(question)) between 1 and 2000),
  answer text not null check (char_length(trim(answer)) between 1 and 4000),
  uncertainty text not null check (char_length(trim(uncertainty)) between 1 and 500),
  citations jsonb not null check (jsonb_typeof(citations) = 'array' and pg_column_size(citations) <= 8192),
  created_at timestamptz not null default clock_timestamp()
);
create index bloom_document_help_answers_profile_idx on public.bloom_document_help_answers(profile_id, document_id, created_at desc);
alter table public.bloom_document_help_answers enable row level security;
revoke all on public.bloom_document_help_answers from public, anon, authenticated;
grant select on public.bloom_document_help_answers to authenticated;
create policy bloom_document_help_answers_read on public.bloom_document_help_answers for select to authenticated
  using (profile_id = (select bloom_private.current_profile_id()) and exists (
    select 1 from public.bloom_growth_documents d where d.id = bloom_document_help_answers.document_id
      and d.profile_id = bloom_document_help_answers.profile_id and d.module_id = 'study'
      and bloom_private.has_module_access(bloom_document_help_answers.profile_id, 'study')
  ));

insert into storage.buckets(id, name, public, file_size_limit, allowed_mime_types)
values ('bloom-growth-content', 'bloom-growth-content', false, 26214400,
  array['application/pdf', 'application/vnd.openxmlformats-officedocument.wordprocessingml.document', 'application/epub+zip']::text[])
on conflict (id) do update set public = false, file_size_limit = 26214400,
  allowed_mime_types = array['application/pdf', 'application/vnd.openxmlformats-officedocument.wordprocessingml.document', 'application/epub+zip']::text[];

create policy bloom_growth_content_insert on storage.objects for insert to authenticated
  with check (bucket_id = 'bloom-growth-content'
    and (storage.foldername(name))[1] = (select bloom_private.current_profile_id())::text
    and exists (select 1 from public.bloom_growth_documents d where d.profile_id = (select bloom_private.current_profile_id())
      and d.storage_path = name and bloom_private.has_module_access(d.profile_id, d.module_id)));
create policy bloom_growth_content_read on storage.objects for select to authenticated
  using (bucket_id = 'bloom-growth-content'
    and (storage.foldername(name))[1] = (select bloom_private.current_profile_id())::text
    and exists (select 1 from public.bloom_growth_documents d where d.profile_id = (select bloom_private.current_profile_id())
      and d.storage_path = name and bloom_private.has_module_access(d.profile_id, d.module_id)));
create policy bloom_growth_content_delete on storage.objects for delete to authenticated
  using (bucket_id = 'bloom-growth-content'
    and (storage.foldername(name))[1] = (select bloom_private.current_profile_id())::text
    and exists (select 1 from public.bloom_growth_documents d where d.profile_id = (select bloom_private.current_profile_id())
      and d.storage_path = name and bloom_private.has_module_access(d.profile_id, d.module_id)));

create function bloom_private.create_growth_document(
  p_module_id text, p_item_id uuid, p_title text, p_file_name text, p_format text, p_mime_type text,
  p_byte_size integer, p_request_id uuid
) returns jsonb language plpgsql security definer set search_path = pg_catalog, pg_temp as $$
declare
  v_profile uuid := bloom_private.current_profile_id(); v_item public.bloom_growth_items%rowtype;
  v_doc public.bloom_growth_documents%rowtype; v_id uuid; v_path text; v_ext text;
begin
  if v_profile is null then raise exception 'Sign in to add a private document'; end if;
  if p_module_id not in ('study', 'read') or not bloom_private.has_module_access(v_profile, p_module_id) then
    raise exception 'This module is not assigned to the active profile' using errcode = '42501';
  end if;
  if p_request_id is null or p_title is null or char_length(trim(p_title)) not between 1 and 120
    or p_file_name is null or char_length(trim(p_file_name)) not between 1 and 180
    or p_file_name ~ '[[:cntrl:]/\\]' or p_mime_type is null or p_byte_size is null then raise exception 'Check the document details'; end if;
  if (p_module_id = 'study' and (p_format not in ('pdf', 'docx') or p_byte_size not between 1 and 10485760
      or (p_format = 'pdf' and p_mime_type <> 'application/pdf')
      or (p_format = 'docx' and p_mime_type <> 'application/vnd.openxmlformats-officedocument.wordprocessingml.document')))
    or (p_module_id = 'read' and (p_format not in ('pdf', 'epub') or p_byte_size not between 1 and 26214400
      or (p_format = 'pdf' and p_mime_type <> 'application/pdf')
      or (p_format = 'epub' and p_mime_type <> 'application/epub+zip'))) then raise exception 'This format or size is not supported'; end if;
  select * into v_item from public.bloom_growth_items i where i.id = p_item_id and i.profile_id = v_profile
    and i.module_id = p_module_id and i.state <> 'archived';
  if not found or (p_module_id = 'read' and v_item.item_type <> 'reading') then raise exception 'Choose an active item in this module'; end if;
  select * into v_doc from public.bloom_growth_documents d where d.profile_id = v_profile and d.request_id = p_request_id;
  if found then
    if (v_doc.module_id, v_doc.item_id, v_doc.title, v_doc.file_name, v_doc.format, v_doc.byte_size)
      is distinct from (p_module_id, p_item_id, trim(p_title), trim(p_file_name), p_format, p_byte_size) then
      raise exception 'Request was already used for a different document'; end if;
    return jsonb_build_object('id', v_doc.id, 'storage_path', v_doc.storage_path);
  end if;
  v_id := gen_random_uuid();
  v_ext := case p_format when 'pdf' then 'pdf' when 'docx' then 'docx' else 'epub' end;
  v_path := v_profile::text || '/' || p_module_id || '/' || v_id::text || '.' || v_ext;
  insert into public.bloom_growth_documents(id, profile_id, module_id, item_id, title, file_name, format, mime_type, byte_size, storage_path, request_id)
    values (v_id, v_profile, p_module_id, p_item_id, trim(p_title), trim(p_file_name), p_format, p_mime_type, p_byte_size, v_path, p_request_id);
  return jsonb_build_object('id', v_id, 'storage_path', v_path);
end;
$$;

create function bloom_private.delete_growth_document(p_document_id uuid)
returns text language plpgsql security definer set search_path = pg_catalog, pg_temp as $$
declare v_profile uuid := bloom_private.current_profile_id(); v_path text; v_module text;
begin
  if v_profile is null then raise exception 'Sign in to delete this document'; end if;
  select storage_path, module_id into v_path, v_module from public.bloom_growth_documents
    where id = p_document_id and profile_id = v_profile for update;
  if not found or not bloom_private.has_module_access(v_profile, v_module) then raise exception 'Document not found' using errcode = '42501'; end if;
  delete from public.bloom_growth_documents where id = p_document_id and profile_id = v_profile;
  return v_path;
end;
$$;

create function bloom_private.set_document_ai_consent(p_consent boolean, p_adult_attested boolean)
returns void language plpgsql security definer set search_path = pg_catalog, pg_temp as $$
declare v_profile uuid := bloom_private.current_profile_id(); v_child boolean;
begin
  if v_profile is null or not bloom_private.has_module_access(v_profile, 'study') then raise exception 'Study access is required' using errcode = '42501'; end if;
  if p_consent is null or p_adult_attested is null then raise exception 'Choose valid privacy settings'; end if;
  v_child := bloom_private.is_child_profile(v_profile);
  if (v_child and p_adult_attested) or (not v_child and p_consent and not p_adult_attested) then raise exception 'Age eligibility and document consent are required'; end if;
  insert into public.bloom_growth_ai_settings(profile_id, module_id, document_sharing_consent, document_adult_attested)
    values (v_profile, 'study', p_consent, p_consent and p_adult_attested)
    on conflict (profile_id, module_id) do update set document_sharing_consent = excluded.document_sharing_consent,
      document_adult_attested = excluded.document_adult_attested, updated_at = clock_timestamp();
end;
$$;

create function bloom_private.set_child_document_ai_preferences(p_child_id uuid, p_enabled boolean, p_eligible boolean, p_consent boolean)
returns void language plpgsql security definer set search_path = pg_catalog, pg_temp as $$
begin
  if bloom_private.current_profile_id() is null or not bloom_private.is_parent_of(p_child_id) or not bloom_private.is_child_profile(p_child_id) then
    raise exception 'Parent access required' using errcode = '42501';
  end if;
  if p_enabled is null or p_eligible is null or p_consent is null or (p_enabled and (not p_eligible or not p_consent)) then
    raise exception 'Document help requires parent consent and eligibility';
  end if;
  insert into public.bloom_growth_ai_settings(profile_id, module_id, document_parent_enabled, document_minor_eligible_attested, document_parent_sharing_consent)
    values (p_child_id, 'study', p_enabled, p_enabled and p_eligible, p_enabled and p_consent)
    on conflict (profile_id, module_id) do update set document_parent_enabled = excluded.document_parent_enabled,
      document_minor_eligible_attested = excluded.document_minor_eligible_attested,
      document_parent_sharing_consent = excluded.document_parent_sharing_consent, updated_at = clock_timestamp();
end;
$$;

create function bloom_private.get_child_document_ai_status(p_child_id uuid)
returns jsonb language plpgsql stable security definer set search_path = pg_catalog, pg_temp as $$
declare v_settings public.bloom_growth_ai_settings%rowtype;
begin
  if bloom_private.current_profile_id() is null or not bloom_private.is_parent_of(p_child_id) or not bloom_private.is_child_profile(p_child_id) then
    raise exception 'Parent access required' using errcode = '42501';
  end if;
  select * into v_settings from public.bloom_growth_ai_settings where profile_id = p_child_id and module_id = 'study';
  return jsonb_build_object('enabled', coalesce(v_settings.document_parent_enabled, false),
    'eligible', coalesce(v_settings.document_minor_eligible_attested, false),
    'parent_consent', coalesce(v_settings.document_parent_sharing_consent, false));
end;
$$;

create function bloom_private.begin_mock_exam_assessment(p_request_id uuid, p_exam_id uuid, p_answers jsonb)
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
  if (select count(*) from bloom_private.growth_ai_requests r where r.profile_id = v_profile and r.created_at > clock_timestamp() - interval '24 hours') >= 10
    or (select count(*) from bloom_private.growth_ai_requests r where r.profile_id = v_profile and r.created_at > clock_timestamp() - interval '1 minute') >= 2
    or exists (select 1 from bloom_private.growth_ai_requests r where r.profile_id = v_profile and r.status = 'pending'
      and r.created_at > clock_timestamp() - interval '2 minutes') then raise exception 'AI request limit reached'; end if;
  insert into bloom_private.growth_ai_requests(id, profile_id, module_id, request_kind, item_id, source_record_id, response, status)
    values (p_request_id, v_profile, 'study', 'mock_exam_assess', v_exam.item_id, p_exam_id, p_answers, 'pending');
  return jsonb_build_object('status', 'pending', 'is_child', v_child,
    'exam', jsonb_build_object('title', v_exam.title, 'definition', v_exam.body::jsonb,
      'source_reference', coalesce(v_exam.metadata->>'source_reference', '')),
    'questions', v_questions, 'answers', p_answers);
end;
$$;

create function bloom_private.save_mock_exam_objective(p_exam_id uuid, p_answers jsonb, p_duration_seconds integer, p_request_id uuid)
returns jsonb language plpgsql security definer set search_path = pg_catalog, pg_temp as $$
declare
  v_profile uuid := bloom_private.current_profile_id(); v_exam public.bloom_growth_records%rowtype;
  v_question jsonb; v_answer text; v_correct boolean; v_count integer := 0; v_score_sum numeric := 0;
  v_results jsonb := '[]'::jsonb; v_record_id uuid; v_body text; v_score numeric;
begin
  if v_profile is null or not bloom_private.has_module_access(v_profile, 'study') then raise exception 'Study access is required' using errcode = '42501'; end if;
  if p_request_id is null or jsonb_typeof(p_answers) <> 'object' or pg_column_size(p_answers) > 16384
    or p_duration_seconds is null or p_duration_seconds not between 0 and 43200 then raise exception 'Check the exam attempt'; end if;
  select * into v_exam from public.bloom_growth_records r where r.id = p_exam_id and r.profile_id = v_profile and r.module_id = 'study' and r.kind = 'exam';
  if not found then raise exception 'Mock exam not found' using errcode = '42501'; end if;
  for v_question in select value from jsonb_array_elements((v_exam.body::jsonb)->'questions') loop
    if v_question->>'type' not in ('multiple_choice', 'true_false') then raise exception 'Use AI assessment for short-answer questions'; end if;
    v_count := v_count + 1; v_answer := coalesce(p_answers->>(v_question->>'id'), '');
    v_correct := lower(trim(v_answer)) = lower(trim(v_question->>'expected_answer'));
    v_score_sum := v_score_sum + case when v_correct then 100 else 0 end;
    v_results := v_results || jsonb_build_array(jsonb_build_object('question_id', v_question->>'id', 'answer', v_answer,
      'correct', v_correct, 'expected_answer', v_question->>'expected_answer', 'explanation', v_question->>'explanation'));
  end loop;
  if v_count = 0 or v_count > 50 then raise exception 'Mock exam content is invalid'; end if;
  v_score := round(v_score_sum / v_count, 2);
  v_body := jsonb_build_object('results', v_results, 'duration_seconds', p_duration_seconds, 'assessment_scope', 'objective')::text;
  v_record_id := md5(p_request_id::text || ':exam-attempt')::uuid;
  insert into public.bloom_growth_records(id, profile_id, module_id, item_id, kind, title, body, metadata, score, request_id)
    values (v_record_id, v_profile, 'study', v_exam.item_id, 'exam_attempt', 'Mock exam · ' || v_exam.title,
      v_body, jsonb_build_object('exam_id', p_exam_id, 'source_reference', v_exam.metadata->>'source_reference'), v_score, v_record_id)
    on conflict (profile_id, request_id) do nothing;
  return jsonb_build_object('record_id', v_record_id, 'score', v_score, 'results', v_results,
    'duration_seconds', p_duration_seconds, 'assessment_scope', 'objective');
end;
$$;

create function bloom_private.finish_mock_exam_assessment(p_request_id uuid, p_assessments jsonb, p_duration_seconds integer)
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
  return v_attempt || jsonb_build_object('record_id', v_attempt_id);
end;
$$;

create function bloom_private.begin_document_help_request(p_request_id uuid, p_document_id uuid, p_prompt text)
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
  if (select count(*) from bloom_private.growth_ai_requests r where r.profile_id = v_profile and r.created_at > clock_timestamp() - interval '24 hours') >= 10
    or (select count(*) from bloom_private.growth_ai_requests r where r.profile_id = v_profile and r.created_at > clock_timestamp() - interval '1 minute') >= 2
    or exists (select 1 from bloom_private.growth_ai_requests r where r.profile_id = v_profile and r.status = 'pending'
      and r.created_at > clock_timestamp() - interval '2 minutes') then raise exception 'AI request limit reached'; end if;
  insert into bloom_private.growth_ai_requests(id, profile_id, module_id, request_kind, item_id, document_id, status)
    values (p_request_id, v_profile, 'study', 'document_help', v_doc.item_id, v_doc.id, 'pending');
  return jsonb_build_object('status', 'pending', 'is_child', v_child, 'document_id', v_doc.id, 'storage_path', v_doc.storage_path,
    'file_name', v_doc.file_name, 'format', v_doc.format, 'title', v_doc.title);
end;
$$;

create function bloom_private.finish_document_help_request(
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
  return v_value;
end;
$$;

create function public.bloom_create_growth_document(p_module_id text, p_item_id uuid, p_title text, p_file_name text,
  p_format text, p_mime_type text, p_byte_size integer, p_request_id uuid)
returns jsonb language sql security invoker set search_path = pg_catalog, pg_temp as $$
  select bloom_private.create_growth_document(p_module_id, p_item_id, p_title, p_file_name, p_format, p_mime_type, p_byte_size, p_request_id);
$$;
create function public.bloom_delete_growth_document(p_document_id uuid)
returns text language sql security invoker set search_path = pg_catalog, pg_temp as $$ select bloom_private.delete_growth_document(p_document_id); $$;
create function public.bloom_set_document_ai_consent(p_consent boolean, p_adult_attested boolean)
returns void language sql security invoker set search_path = pg_catalog, pg_temp as $$ select bloom_private.set_document_ai_consent(p_consent, p_adult_attested); $$;
create function public.bloom_set_child_document_ai_preferences(p_child_id uuid, p_enabled boolean, p_eligible boolean, p_consent boolean)
returns void language sql security invoker set search_path = pg_catalog, pg_temp as $$ select bloom_private.set_child_document_ai_preferences(p_child_id, p_enabled, p_eligible, p_consent); $$;
create function public.bloom_get_child_document_ai_status(p_child_id uuid)
returns jsonb language sql security invoker set search_path = pg_catalog, pg_temp as $$ select bloom_private.get_child_document_ai_status(p_child_id); $$;
create function public.bloom_begin_mock_exam_assessment(p_request_id uuid, p_exam_id uuid, p_answers jsonb)
returns jsonb language sql security invoker set search_path = pg_catalog, pg_temp as $$ select bloom_private.begin_mock_exam_assessment(p_request_id, p_exam_id, p_answers); $$;
create function public.bloom_submit_mock_exam_objective(p_exam_id uuid, p_answers jsonb, p_duration_seconds integer, p_request_id uuid)
returns jsonb language sql security invoker set search_path = pg_catalog, pg_temp as $$ select bloom_private.save_mock_exam_objective(p_exam_id, p_answers, p_duration_seconds, p_request_id); $$;
create function public.bloom_begin_document_help_request(p_request_id uuid, p_document_id uuid, p_prompt text)
returns jsonb language sql security invoker set search_path = pg_catalog, pg_temp as $$ select bloom_private.begin_document_help_request(p_request_id, p_document_id, p_prompt); $$;
create function public.bloom_finish_mock_exam_assessment(p_request_id uuid, p_assessments jsonb, p_duration_seconds integer)
returns jsonb language sql security invoker set search_path = pg_catalog, pg_temp as $$ select bloom_private.finish_mock_exam_assessment(p_request_id, p_assessments, p_duration_seconds); $$;
create function public.bloom_finish_document_help_request(p_request_id uuid, p_prompt text, p_answer text, p_uncertainty text, p_citations jsonb)
returns jsonb language sql security invoker set search_path = pg_catalog, pg_temp as $$ select bloom_private.finish_document_help_request(p_request_id, p_prompt, p_answer, p_uncertainty, p_citations); $$;

revoke all on function bloom_private.create_growth_document(text, uuid, text, text, text, text, integer, uuid), bloom_private.delete_growth_document(uuid),
  bloom_private.set_document_ai_consent(boolean, boolean), bloom_private.set_child_document_ai_preferences(uuid, boolean, boolean, boolean),
  bloom_private.get_child_document_ai_status(uuid), bloom_private.begin_mock_exam_assessment(uuid, uuid, jsonb),
  bloom_private.save_mock_exam_objective(uuid, jsonb, integer, uuid), bloom_private.finish_mock_exam_assessment(uuid, jsonb, integer),
  bloom_private.begin_document_help_request(uuid, uuid, text), bloom_private.finish_document_help_request(uuid, text, text, text, jsonb)
  from public, anon, authenticated;
grant execute on function bloom_private.create_growth_document(text, uuid, text, text, text, text, integer, uuid), bloom_private.delete_growth_document(uuid),
  bloom_private.set_document_ai_consent(boolean, boolean), bloom_private.set_child_document_ai_preferences(uuid, boolean, boolean, boolean),
  bloom_private.get_child_document_ai_status(uuid), bloom_private.begin_mock_exam_assessment(uuid, uuid, jsonb),
  bloom_private.save_mock_exam_objective(uuid, jsonb, integer, uuid), bloom_private.begin_document_help_request(uuid, uuid, text) to authenticated;
grant execute on function bloom_private.finish_mock_exam_assessment(uuid, jsonb, integer),
  bloom_private.finish_document_help_request(uuid, text, text, text, jsonb) to service_role;

revoke all on function public.bloom_create_growth_document(text, uuid, text, text, text, text, integer, uuid),
  public.bloom_delete_growth_document(uuid), public.bloom_set_document_ai_consent(boolean, boolean),
  public.bloom_set_child_document_ai_preferences(uuid, boolean, boolean, boolean), public.bloom_get_child_document_ai_status(uuid),
  public.bloom_begin_mock_exam_assessment(uuid, uuid, jsonb), public.bloom_submit_mock_exam_objective(uuid, jsonb, integer, uuid),
  public.bloom_begin_document_help_request(uuid, uuid, text), public.bloom_finish_mock_exam_assessment(uuid, jsonb, integer),
  public.bloom_finish_document_help_request(uuid, text, text, text, jsonb) from public, anon, authenticated;
grant execute on function public.bloom_create_growth_document(text, uuid, text, text, text, text, integer, uuid),
  public.bloom_delete_growth_document(uuid), public.bloom_set_document_ai_consent(boolean, boolean),
  public.bloom_set_child_document_ai_preferences(uuid, boolean, boolean, boolean), public.bloom_get_child_document_ai_status(uuid),
  public.bloom_begin_mock_exam_assessment(uuid, uuid, jsonb), public.bloom_submit_mock_exam_objective(uuid, jsonb, integer, uuid),
  public.bloom_begin_document_help_request(uuid, uuid, text) to authenticated;
grant execute on function public.bloom_finish_mock_exam_assessment(uuid, jsonb, integer),
  public.bloom_finish_document_help_request(uuid, text, text, text, jsonb) to service_role;
grant execute on function bloom_private.finish_mock_exam_assessment(uuid, jsonb, integer),
  bloom_private.finish_document_help_request(uuid, text, text, text, jsonb) to service_role;

commit;
