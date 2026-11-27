begin;
insert into auth.users(id) values
  ('00000000-0000-0000-0000-000000000401'),
  ('00000000-0000-0000-0000-000000000402');
insert into public.bloom_settings(user_id, credits_enabled) values
  ('00000000-0000-0000-0000-000000000401', true),
  ('00000000-0000-0000-0000-000000000402', true);

set local role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000401', true);
do $$
declare
  v_item uuid;
  v_objective_exam uuid;
  v_ai_exam uuid;
  v_attempt jsonb;
  v_retry jsonb;
  v_context jsonb;
  v_document_item uuid;
  v_document jsonb;
  v_document_id uuid;
  v_document_path text;
  v_verification_id uuid;
  v_text_verification_id uuid;
  v_deleted_record_id uuid;
  v_retry_verification_id uuid;
begin
  v_item := public.bloom_create_growth_item('study', 'subject', 'Exam subject', '', null, 60,
    '90000000-0000-0000-0000-000000000401');
  v_objective_exam := public.bloom_save_growth_record('study', v_item, 'exam', 'Objective check',
    '{"version":1,"time_limit_minutes":10,"questions":[{"id":"mc1","type":"multiple_choice","prompt":"Which is correct?","options":["A","B"],"expected_answer":"A","explanation":"A is correct."},{"id":"tf1","type":"true_false","prompt":"The sky is green.","expected_answer":"false","explanation":"It is not green."}]}',
    '{"source_reference":"Unit 1 notes"}'::jsonb, null, null, '90000000-0000-0000-0000-000000000402');
  v_attempt := public.bloom_submit_mock_exam_objective(v_objective_exam, '{"mc1":"A","tf1":"true"}'::jsonb, 44,
    '90000000-0000-0000-0000-000000000403');
  v_retry := public.bloom_submit_mock_exam_objective(v_objective_exam, '{"mc1":"A","tf1":"true"}'::jsonb, 44,
    '90000000-0000-0000-0000-000000000403');
  if (v_attempt->>'score')::numeric <> 50 or v_attempt->>'assessment_scope' <> 'objective'
    or v_attempt->>'record_id' <> v_retry->>'record_id'
    or (select count(*) from public.bloom_growth_records where kind = 'exam_attempt'
      and metadata->>'exam_id' = v_objective_exam::text) <> 1 then
    raise exception 'Objective mock exam scoring or retry handling is incorrect';
  end if;

  v_ai_exam := public.bloom_save_growth_record('study', v_item, 'exam', 'Short answer check',
    '{"version":1,"time_limit_minutes":10,"questions":[{"id":"sa1","type":"short_answer","prompt":"What does a chloroplast do?","expected_answer":"It converts light into stored chemical energy.","rubric":"Mention converting light energy into chemical energy.","explanation":"Chloroplasts capture light for photosynthesis."}]}',
    '{"source_reference":"Biology unit 2"}'::jsonb, null, null, '90000000-0000-0000-0000-000000000404');
  begin
    perform public.bloom_begin_mock_exam_assessment('90000000-0000-0000-0000-000000000405', v_ai_exam,
      '{"sa1":"It turns light into chemical energy."}'::jsonb);
    raise exception using errcode = 'P0002', message = 'AI exam assessment was accepted without consent';
  exception when raise_exception then
    if sqlerrm <> 'Study AI consent and eligibility are required' then raise; end if;
  end;
  perform public.bloom_set_growth_ai_preferences('study', true, true);
  v_context := public.bloom_begin_mock_exam_assessment('90000000-0000-0000-0000-000000000405', v_ai_exam,
    '{"sa1":"It turns light into chemical energy."}'::jsonb);
  if v_context->>'status' <> 'pending' or v_context->'exam'->>'source_reference' <> 'Biology unit 2'
    or not (v_context->'questions' @> '[{"id":"sa1","rubric":"Mention converting light energy into chemical energy."}]'::jsonb) then
    raise exception 'The AI assessment context lost its source-linked answer rubric';
  end if;
  if has_function_privilege('authenticated', 'public.bloom_finish_mock_exam_assessment(uuid,jsonb,integer)', 'EXECUTE') then
    raise exception 'A client can forge an AI mock exam result';
  end if;
  perform set_config('bloom.test_exam_request', '90000000-0000-0000-0000-000000000405', true);
  perform set_config('bloom.test_ai_exam', v_ai_exam::text, true);

  perform set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000402', true);
  v_document_item := public.bloom_create_growth_item('study', 'subject', 'Document subject', '', null, 30,
    '90000000-0000-0000-0000-000000000406');
  v_document := public.bloom_create_growth_document('study', v_document_item, 'Science notes', 'science-notes.pdf',
    'pdf', 'application/pdf', 1200, '90000000-0000-0000-0000-000000000407');
  v_document_id := (v_document->>'id')::uuid;
  v_document_path := v_document->>'storage_path';
  insert into storage.objects(bucket_id, name) values ('bloom-growth-content', v_document_path);
  perform public.bloom_confirm_growth_document(v_document_id);
  v_verification_id := public.bloom_save_study_verification(v_document_item, 'Lab report artifact', '', v_document_id,
    '90000000-0000-0000-0000-000000000410');
  v_retry_verification_id := public.bloom_save_study_verification(v_document_item, 'Lab report artifact', '', v_document_id,
    '90000000-0000-0000-0000-000000000410');
  if v_verification_id <> v_retry_verification_id
    or not exists (select 1 from public.bloom_growth_record_attachments where record_id = v_verification_id and document_id = v_document_id)
    or (select metadata->>'artifact_only' from public.bloom_growth_records where id = v_verification_id) <> 'true' then
    raise exception 'Study artifact attachment was not saved atomically or idempotently';
  end if;
  v_text_verification_id := public.bloom_save_study_verification(v_document_item, 'Recall check', 'One useful idea', v_document_id,
    '90000000-0000-0000-0000-000000000411');
  perform public.bloom_update_study_verification(v_text_verification_id, 'Recall check', 'One useful idea', null);
  if exists (select 1 from public.bloom_growth_record_attachments where record_id = v_text_verification_id)
    or (select metadata->>'artifact_only' from public.bloom_growth_records where id = v_text_verification_id) <> 'false' then
    raise exception 'Editing a Study verification did not update its artifact link';
  end if;
  v_deleted_record_id := public.bloom_save_study_verification(v_document_item, 'Delete test', 'One answer', v_document_id,
    '90000000-0000-0000-0000-000000000413');
  perform set_config('bloom.test_verification_id', v_verification_id::text, true);
  perform set_config('bloom.test_text_verification_id', v_text_verification_id::text, true);
  perform set_config('bloom.test_deleted_record_id', v_deleted_record_id::text, true);
  begin
    perform public.bloom_set_document_ai_consent(true, false);
    raise exception using errcode = 'P0002', message = 'Document sharing consent was accepted without eligibility';
  exception when raise_exception then
    if sqlerrm <> 'Age eligibility and document consent are required' then raise; end if;
  end;
  perform public.bloom_set_document_ai_consent(true, true);
  begin
    perform public.bloom_begin_document_help_request('90000000-0000-0000-0000-000000000408', v_document_id,
      'Where does water freeze?');
    raise exception using errcode = 'P0002', message = 'Document help was accepted without Study AI consent';
  exception when raise_exception then
    if sqlerrm <> 'Study document AI consent and eligibility are required' then raise; end if;
  end;
  perform public.bloom_set_growth_ai_preferences('study', true, true);
  v_context := public.bloom_begin_document_help_request('90000000-0000-0000-0000-000000000408', v_document_id,
    'Where does water freeze?');
  if v_context->>'status' <> 'pending' or v_context->>'storage_path' <> v_document_path
    or v_context->>'format' <> 'pdf' then raise exception 'Private Study document context is incomplete'; end if;
  if has_function_privilege('authenticated', 'public.bloom_finish_document_help_request(uuid,text,text,text,jsonb)', 'EXECUTE') then
    raise exception 'A client can forge source-aware document answers';
  end if;
  if has_function_privilege('authenticated', 'bloom_private.set_study_record_artifact(uuid,uuid)', 'EXECUTE')
    or has_table_privilege('authenticated', 'public.bloom_growth_record_attachments', 'INSERT') then
    raise exception 'Clients can write Study artifact links outside the protected verification RPC';
  end if;
  perform set_config('bloom.test_document_request', '90000000-0000-0000-0000-000000000408', true);
  perform set_config('bloom.test_document_id', v_document_id::text, true);
  perform set_config('bloom.test_document_path', v_document_path, true);
end $$;

select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000401', true);
do $$
declare
  v_item uuid;
begin
  select id into v_item from public.bloom_growth_items
    where profile_id = bloom_private.current_profile_id() and module_id = 'study' and title = 'Exam subject';
  begin
    perform public.bloom_save_study_verification(v_item, 'Cross-profile attachment', '',
      current_setting('bloom.test_document_id')::uuid, '90000000-0000-0000-0000-000000000412');
    raise exception using errcode = 'P0002', message = 'Cross-profile Study artifact attachment was accepted';
  exception when insufficient_privilege then
    null;
  end;
  if exists (select 1 from public.bloom_growth_records where profile_id = bloom_private.current_profile_id()
    and title = 'Cross-profile attachment') then raise exception 'Rejected artifact attachment left a partial Study record'; end if;
  if exists (select 1 from public.bloom_growth_record_attachments where record_id = current_setting('bloom.test_verification_id')::uuid) then
    raise exception 'Another profile read a private Study artifact link';
  end if;
end $$;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000402', true);

reset role;
set local role service_role;
do $$
declare
  v_result jsonb;
begin
  v_result := public.bloom_finish_mock_exam_assessment(current_setting('bloom.test_exam_request')::uuid,
    '[{"question_id":"sa1","score":90,"explanation":"This captures the main idea.","uncertainty":"The rubric is short, so review the wording."}]'::jsonb, 52);
  if (v_result->>'score')::numeric <> 90 or v_result->>'assessment_scope' <> 'mixed'
    or v_result->>'uncertainty' is null then raise exception 'AI mock exam assessment did not retain its uncertainty'; end if;
  v_result := public.bloom_finish_document_help_request(current_setting('bloom.test_document_request')::uuid,
    'Where does water freeze?', 'At zero degrees Celsius.', 'This answer uses the cited passage.',
    '[{"reference":"Page 1","quote":"Water freezes at zero degrees Celsius."}]'::jsonb);
  if v_result->>'answer' <> 'At zero degrees Celsius.' or jsonb_array_length(v_result->'citations') <> 1 then
    raise exception 'Source-aware help did not retain its citation'; end if;
end $$;

reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000401', true);
do $$
declare
  v_count integer;
begin
  if (select count(*) from public.bloom_growth_records where kind = 'exam_attempt'
      and metadata->>'exam_id' = current_setting('bloom.test_ai_exam')) <> 1 then
    raise exception 'Completed AI mock exam was not saved in Study history'; end if;
  if exists (select 1 from public.bloom_growth_documents where id = current_setting('bloom.test_document_id')::uuid) then
    raise exception 'Another profile read a private Study document'; end if;
  if exists (select 1 from public.bloom_growth_record_attachments where record_id = current_setting('bloom.test_verification_id')::uuid) then
    raise exception 'Another profile read a private Study artifact link'; end if;
  delete from storage.objects where bucket_id = 'bloom-growth-content'
    and name = current_setting('bloom.test_document_path');
  get diagnostics v_count = row_count;
  if v_count <> 0 then raise exception 'Another profile deleted a private Study document'; end if;
end $$;

select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000402', true);
do $$
declare
  v_count integer;
  v_path text;
begin
  if not exists (select 1 from public.bloom_growth_documents where id = current_setting('bloom.test_document_id')::uuid)
    or not exists (select 1 from public.bloom_document_help_answers where document_id = current_setting('bloom.test_document_id')::uuid
      and question = 'Where does water freeze?') then raise exception 'Document owner could not read private help history'; end if;
  if not exists (select 1 from public.bloom_growth_record_attachments where record_id = current_setting('bloom.test_verification_id')::uuid
      and document_id = current_setting('bloom.test_document_id')::uuid)
    or exists (select 1 from public.bloom_growth_record_attachments where record_id = current_setting('bloom.test_text_verification_id')::uuid) then
    raise exception 'Document owner could not read the correct Study artifact links'; end if;
  perform public.bloom_delete_growth_record(current_setting('bloom.test_deleted_record_id')::uuid);
  if exists (select 1 from public.bloom_growth_record_attachments where record_id = current_setting('bloom.test_deleted_record_id')::uuid)
    or not exists (select 1 from public.bloom_growth_record_attachments where record_id = current_setting('bloom.test_verification_id')::uuid) then
    raise exception 'Deleting a Study reflection did not cascade its artifact link'; end if;
  delete from storage.objects where bucket_id = 'bloom-growth-content'
    and name = current_setting('bloom.test_document_path');
  get diagnostics v_count = row_count;
  if v_count <> 1 then raise exception 'Document owner could not delete their private Storage object'; end if;
  v_path := public.bloom_delete_growth_document(current_setting('bloom.test_document_id')::uuid);
  if v_path <> current_setting('bloom.test_document_path')
    or exists (select 1 from public.bloom_growth_documents where id = current_setting('bloom.test_document_id')::uuid)
    or exists (select 1 from public.bloom_growth_record_attachments where document_id = current_setting('bloom.test_document_id')::uuid)
    or exists (select 1 from public.bloom_document_help_answers where document_id = current_setting('bloom.test_document_id')::uuid) then
    raise exception 'Document deletion did not clear its private content, artifact links, and answer history'; end if;
end $$;
reset role;
do $$
begin
  if exists (select 1 from bloom_private.growth_ai_requests where id = current_setting('bloom.test_document_request')::uuid) then
    raise exception 'Deleting the document left its AI answer cached'; end if;
end $$;
rollback;
