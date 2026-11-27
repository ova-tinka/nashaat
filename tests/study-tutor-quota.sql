begin;

insert into auth.users(id) values
  ('00000000-0000-0000-0000-000000000401'),
  ('00000000-0000-0000-0000-000000000402');

insert into public.bloom_settings(user_id, credits_enabled)
values
  ('00000000-0000-0000-0000-000000000401', true),
  ('00000000-0000-0000-0000-000000000402', true);

do $$
begin
  if exists (
    select 1 from information_schema.columns
    where table_schema = 'bloom_private'
      and table_name = 'growth_ai_quota_events'
      and column_name in ('prompt', 'content', 'item_id', 'document_id', 'response', 'result')
  ) then
    raise exception 'Quota table must store only minimal metadata without message or item fields';
  end if;

  if has_table_privilege('authenticated', 'bloom_private.growth_ai_quota_events', 'SELECT')
    or has_function_privilege('authenticated', 'public.bloom_finish_study_tutor_request(uuid, text, text, text)', 'EXECUTE')
    or has_function_privilege('anon', 'public.bloom_finish_study_tutor_request(uuid, text, text, text)', 'EXECUTE') then
    raise exception 'Quota table or finish_study_tutor_request wrapper is exposed to client roles';
  end if;
end $$;

-- Seed subjects and AI consent for both profiles.
set local role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000401', true);
do $$
declare
  v_subject_a uuid;
  v_task_a uuid;
  v_req_inflight uuid := '90000000-0000-0000-0000-000000000411';
  v_req_second uuid := '90000000-0000-0000-0000-000000000412';
  v_req_third uuid := '90000000-0000-0000-0000-000000000413';
begin
  v_subject_a := public.bloom_create_growth_item('study', 'subject', 'Physics', '', null, 60,
    '90000000-0000-0000-0000-000000000401');
  v_task_a := public.bloom_create_growth_item('tasks', 'task', 'Solve kinematics set', '', null, null,
    '90000000-0000-0000-0000-000000000402');
  perform public.bloom_set_growth_ai_preferences('study', true, true);
  perform public.bloom_set_growth_ai_preferences('tasks', true, true);
  perform public.bloom_begin_study_tutor_request(v_req_inflight, v_subject_a, 'What is velocity?');
  perform set_config('bloom.tutor_subject_a', v_subject_a::text, true);
  perform set_config('bloom.tutor_task_a', v_task_a::text, true);
end $$;

-- Profile B starts and finishes a tutor message; clearing Profile A must not affect Profile B.
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000402', true);
do $$
declare
  v_subject_b uuid;
  v_req_b uuid := '90000000-0000-0000-0000-000000000421';
begin
  v_subject_b := public.bloom_create_growth_item('study', 'subject', 'Biology', '', null, 45,
    '90000000-0000-0000-0000-000000000403');
  perform public.bloom_set_growth_ai_preferences('study', true, true);
  perform public.bloom_begin_study_tutor_request(v_req_b, v_subject_b, 'What is mitosis?');
end $$;

reset role;
set local role service_role;
select public.bloom_finish_study_tutor_request(
  '90000000-0000-0000-0000-000000000421',
  'What is mitosis?',
  'Mitosis is cell division producing two genetically identical daughter cells.',
  'General explanation only.'
);

-- Profile A clears conversation while v_req_inflight is still pending.
reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000401', true);
select public.bloom_clear_study_tutor_conversation();

-- In-flight finish for Profile A must see cleared status and insert zero messages.
reset role;
do $$
declare
  v_finish jsonb;
begin
  set local role service_role;
  v_finish := public.bloom_finish_study_tutor_request(
    '90000000-0000-0000-0000-000000000411',
    'What is velocity?',
    'Velocity is speed with a direction.',
    'General explanation only.'
  );
  reset role;
  if v_finish->>'status' <> 'cleared' then
    raise exception 'Expected cleared status for in-flight tutor request, got %', v_finish;
  end if;
  if exists (select 1 from public.bloom_study_tutor_messages where profile_id = '00000000-0000-0000-0000-000000000401') then
    raise exception 'Cleared in-flight tutor request restored messages into history';
  end if;
  if (select count(*) from public.bloom_study_tutor_messages where profile_id = '00000000-0000-0000-0000-000000000402') <> 2 then
    raise exception 'Clearing Profile A affected Profile B messages';
  end if;
end $$;

-- Verify cleared request still counts toward shared quota across entry points (2 per minute).
reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000401', true);
do $$
declare
  v_subject_a uuid := current_setting('bloom.tutor_subject_a')::uuid;
  v_task_a uuid := current_setting('bloom.tutor_task_a')::uuid;
begin
  -- Reusing the cleared request ID must fail.
  begin
    perform public.bloom_begin_study_tutor_request('90000000-0000-0000-0000-000000000411', v_subject_a, 'Retry cleared ID');
    raise exception using errcode = 'P0002', message = 'Cleared request ID was reused';
  exception when raise_exception then if sqlerrm <> 'This AI request has already been used' then raise; end if; end;

  -- Second request across Tasks breakdown uses slot 2 of 2 in the 1-minute window.
  perform public.bloom_begin_growth_ai_request(
    '90000000-0000-0000-0000-000000000412', 'tasks', 'task_breakdown', v_task_a, 'Break down homework'
  );

  -- Third request (Study tutor) must hit the shared 2-per-minute limit because cleared request #1 was preserved.
  begin
    perform public.bloom_begin_study_tutor_request('90000000-0000-0000-0000-000000000413', v_subject_a, 'Should hit quota');
    raise exception using errcode = 'P0002', message = 'Clearing Study Tutor reset the shared AI quota';
  exception when raise_exception then if sqlerrm <> 'AI request limit reached' then raise; end if; end;
end $$;

rollback;
