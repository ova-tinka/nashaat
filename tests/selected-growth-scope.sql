begin;
insert into auth.users(id) values
  ('00000000-0000-0000-0000-000000000281'),
  ('00000000-0000-0000-0000-000000000282');
insert into public.bloom_settings(user_id, credits_enabled)
values ('00000000-0000-0000-0000-000000000281', true), ('00000000-0000-0000-0000-000000000282', true);
insert into public.bloom_households(id, owner_user_id, name)
values ('90000000-0000-0000-0000-000000000281', '00000000-0000-0000-0000-000000000281', 'Reward test family');
insert into public.bloom_household_members(household_id, user_id, role) values
  ('90000000-0000-0000-0000-000000000281', '00000000-0000-0000-0000-000000000281', 'parent'),
  ('90000000-0000-0000-0000-000000000281', '00000000-0000-0000-0000-000000000282', 'child');
insert into public.bloom_child_module_assignments(profile_id, module_id, assigned, updated_by)
values ('00000000-0000-0000-0000-000000000282', 'tasks', true, '00000000-0000-0000-0000-000000000281');

set local role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000281', true);
do $$
declare
  v_subject uuid;
  v_course uuid;
  v_lesson uuid;
  v_assignment uuid;
  v_project uuid;
  v_milestone uuid;
  v_task uuid;
  v_checklist uuid;
  v_focus uuid;
  v_focus_retry uuid;
  v_record uuid;
  v_record_retry uuid;
  v_ai_request uuid := '90000000-0000-0000-0000-000000000293';
  v_ai_context jsonb;
  v_review_prompt uuid;
  v_next_review uuid;
  v_next_review_retry uuid;
  v_future_review uuid;
  v_weekly_goals jsonb := '[
    {"module_id":"exercise","target_count":3,"active_days":[1,3,5]},
    {"module_id":"study","target_count":120,"active_days":[1,2,3,4,5]},
    {"module_id":"read","target_count":3,"active_days":[2,6]},
    {"module_id":"tasks","target_count":5,"active_days":[1,2,3,4,5]}
  ]'::jsonb;
  v_reward_task uuid;
  v_second_reward_task uuid;
  v_reward_total numeric;
  v_child_reward_task uuid;
  v_child_reward_event uuid;
  v_approved_reward numeric;
  v_growth_session uuid;
  v_reading_item uuid;
  v_sunday date := current_date - extract(dow from current_date)::integer;
  v_duration integer;
  v_weekly_actuals jsonb;
begin
  perform public.bloom_save_weekly_pillar_goals(v_weekly_goals);
  if (select count(*) from public.bloom_weekly_pillar_goals where profile_id = bloom_private.current_profile_id()) <> 4
    or not exists (select 1 from public.bloom_weekly_pillar_goals where profile_id = bloom_private.current_profile_id()
      and module_id = 'exercise' and target_count = 3 and active_days = array[1,3,5]::smallint[]) then
    raise exception 'Cross-pillar weekly goals did not retain their targets and selected days';
  end if;
  begin
    perform public.bloom_save_weekly_pillar_goals('[{"module_id":"read","target_count":3,"active_days":[0,7]}]'::jsonb);
    raise exception using errcode = 'P0002', message = 'A weekly plan accepted a day outside Sunday-to-Saturday';
  exception when raise_exception then if sqlerrm <> 'Check the module and chosen days' then raise; end if; end;

  v_subject := public.bloom_create_growth_item('study', 'subject', 'Math', '', null, 60,
    '90000000-0000-0000-0000-000000000281');
  v_course := public.bloom_create_growth_child(v_subject, 'course', 'Algebra', '', null,
    '90000000-0000-0000-0000-000000000282');
  v_lesson := public.bloom_create_growth_child(v_course, 'lesson', 'Linear equations', '', null,
    '90000000-0000-0000-0000-000000000283');
  v_assignment := public.bloom_create_growth_child(v_lesson, 'assignment', 'Practice set', '', null,
    '90000000-0000-0000-0000-000000000284');
  begin
    perform public.bloom_save_study_plan(jsonb_build_array(
      jsonb_build_object('item_id', v_assignment, 'day_of_week', 0, 'target_minutes', 50)));
    raise exception using errcode = 'P0002', message = 'Study plan accepted less than the subject target';
  exception when raise_exception then if sqlerrm <> 'Schedule each subject for exactly its weekly target' then raise; end if; end;
  perform public.bloom_save_study_plan(jsonb_build_array(
    jsonb_build_object('item_id', v_assignment, 'day_of_week', 0, 'target_minutes', 20),
    jsonb_build_object('item_id', v_course, 'day_of_week', 3, 'target_minutes', 40)));
  if (select count(*) from public.bloom_study_plan_slots where profile_id = bloom_private.current_profile_id()) <> 2 then
    raise exception 'Study plan did not retain its two chosen sessions';
  end if;
  if v_sunday < current_date then v_sunday := v_sunday + 7; end if;
  perform public.bloom_change_study_occurrence(v_assignment, v_sunday, 'skip', null);
  if not exists (select 1 from public.bloom_study_plan_changes where item_id = v_assignment and original_date = v_sunday and action = 'skip') then
    raise exception 'A skipped Study session was not saved as a schedule change';
  end if;

  v_project := public.bloom_create_growth_project('Spring term', '', current_date + 30,
    '90000000-0000-0000-0000-000000000285');
  v_milestone := public.bloom_create_growth_child(v_project, 'milestone', 'Research', '', current_date + 10,
    '90000000-0000-0000-0000-000000000286');
  v_task := public.bloom_create_growth_child(v_milestone, 'task', 'Find sources', '', current_date + 3,
    '90000000-0000-0000-0000-000000000287');
  v_checklist := public.bloom_create_growth_child(v_task, 'checklist', 'Save citations', '', null,
    '90000000-0000-0000-0000-000000000288');
  perform public.bloom_update_growth_item(v_task, 'Find sources', '', current_date + 3, 'completed', 100);
  if not exists (select 1 from public.bloom_growth_items where id = v_task and state = 'completed')
    or not exists (select 1 from public.bloom_growth_items where id = v_project and state = 'active')
    or not exists (select 1 from public.bloom_growth_items where id = v_milestone and state = 'active')
    or not exists (select 1 from public.bloom_growth_items where id = v_checklist and parent_id = v_task) then
    raise exception 'Completing a nested task changed its parent or lost its checklist';
  end if;
  begin
    perform public.bloom_create_growth_child(v_assignment, 'course', 'Invalid', '', null,
      '90000000-0000-0000-0000-000000000289');
    raise exception using errcode = 'P0002', message = 'Invalid Study hierarchy was accepted';
  exception when raise_exception then if sqlerrm <> 'This item cannot be added under the selected parent' then raise; end if; end;

  v_task := public.bloom_create_growth_item('tasks', 'task', 'Read chapter', '', null, null,
    '90000000-0000-0000-0000-000000000290');
  v_focus := public.bloom_start_task_focus(v_task, '90000000-0000-0000-0000-000000000291');
  v_focus_retry := public.bloom_start_task_focus(v_task, '90000000-0000-0000-0000-000000000291');
  if v_focus is distinct from v_focus_retry then raise exception 'Focus retry created a duplicate task session'; end if;
  select duration_seconds into v_duration from public.bloom_finish_task_focus(v_focus);
  if v_duration is null or not exists (select 1 from public.bloom_growth_items where id = v_task and state = 'active') then
    raise exception 'Focus completion changed task state or did not save server time';
  end if;
  if exists (select 1 from public.bloom_credit_ledger where user_id = auth.uid() and idempotency_key like 'task-focus:%') then
    raise exception 'Focus linked to a task created a second credit reward';
  end if;

  begin
    perform public.bloom_begin_growth_ai_request(v_ai_request, 'tasks', 'task_breakdown', v_task, 'No sensitive content');
    raise exception using errcode = 'P0002', message = 'Task AI request was accepted without consent';
  exception when raise_exception then if sqlerrm <> 'Task AI consent and eligibility are required' then raise; end if; end;
  perform public.bloom_set_growth_ai_preferences('tasks', true, true);
  v_ai_context := public.bloom_begin_growth_ai_request(v_ai_request, 'tasks', 'task_breakdown', v_task, 'Do not save this prompt text');
  if v_ai_context->>'is_child' <> 'false' or v_ai_context->'task'->>'title' <> 'Read chapter'
    or exists (select 1 from information_schema.columns where table_schema = 'bloom_private'
      and table_name = 'growth_ai_requests' and column_name ilike '%prompt%') then
    raise exception 'Task AI context consent or prompt minimization failed';
  end if;
  begin
    perform * from public.bloom_apply_task_breakdown(v_task, '["Read the chapter","Write a short summary"]'::jsonb, v_ai_request);
    raise exception using errcode = 'P0002', message = 'An unfinished AI draft was saved';
  exception when raise_exception then if sqlerrm <> 'Review a completed AI draft before saving steps' then raise; end if; end;
  perform set_config('bloom.ai_request', v_ai_request::text, true);

  v_record := public.bloom_save_growth_record('study', v_subject, 'verification', 'Recall check', 'One useful idea',
    '{"optional_learning_signal":true}'::jsonb, null, null, '90000000-0000-0000-0000-000000000292');
  v_record_retry := public.bloom_save_growth_record('study', v_subject, 'verification', 'Recall check', 'One useful idea',
    '{"optional_learning_signal":true}'::jsonb, null, null, '90000000-0000-0000-0000-000000000292');
  if v_record is distinct from v_record_retry then raise exception 'Growth entry retry created a duplicate'; end if;
  v_review_prompt := public.bloom_save_growth_record('study', v_subject, 'review_prompt', 'Photosynthesis',
    'Explain how plants use light.', '{"interval_days":0}'::jsonb, clock_timestamp() - interval '1 second', null,
    '90000000-0000-0000-0000-000000000294');
  v_next_review := public.bloom_submit_study_review(v_review_prompt, 'Plants turn light into stored chemical energy.', 'hard', 2,
    '90000000-0000-0000-0000-000000000295');
  v_next_review_retry := public.bloom_submit_study_review(v_review_prompt, 'Plants turn light into stored chemical energy.', 'hard', 2,
    '90000000-0000-0000-0000-000000000295');
  if v_next_review is distinct from v_next_review_retry
    or not exists (select 1 from public.bloom_growth_records where id = v_next_review and kind = 'review_prompt'
      and scheduled_at between clock_timestamp() + interval '1 day 23 hours' and clock_timestamp() + interval '2 days 1 hour')
    or (select count(*) from public.bloom_growth_records where kind = 'review_answer' and metadata->>'prompt_id' = v_review_prompt::text) <> 1 then
    raise exception 'Spaced review did not create one retry-safe, scheduled next prompt';
  end if;
  v_future_review := public.bloom_save_growth_record('study', v_subject, 'review_prompt', 'A future prompt', 'Not due yet',
    '{}'::jsonb, clock_timestamp() + interval '1 day', null, '90000000-0000-0000-0000-000000000296');
  begin
    perform public.bloom_submit_study_review(v_future_review, 'Too early', 'remembered', 3, '90000000-0000-0000-0000-000000000297');
    raise exception using errcode = 'P0002', message = 'An early spaced review was accepted';
  exception when raise_exception then if sqlerrm <> 'This review is not due yet' then raise; end if; end;
  if has_table_privilege('authenticated', 'public.bloom_growth_records', 'INSERT')
    or has_table_privilege('authenticated', 'public.bloom_growth_items', 'UPDATE')
    or has_table_privilege('authenticated', 'public.bloom_task_focus_sessions', 'INSERT') then
    raise exception 'Clients can bypass validated growth RPCs';
  end if;

  perform public.bloom_save_growth_reward_rules(bloom_private.current_profile_id(), 'tasks', true, 7, 10, 20, 5, false);
  v_reward_task := public.bloom_create_growth_item('tasks', 'task', 'First reward task', '', null, null,
    '90000000-0000-0000-0000-000000000298');
  perform public.bloom_update_growth_item(v_reward_task, 'First reward task', '', null, 'completed', 100);
  v_second_reward_task := public.bloom_create_growth_item('tasks', 'task', 'Second reward task', '', null, null,
    '90000000-0000-0000-0000-000000000299');
  perform public.bloom_update_growth_item(v_second_reward_task, 'Second reward task', '', null, 'completed', 100);
  select coalesce(sum(amount_minutes), 0) into v_reward_total from public.bloom_credit_ledger
    where user_id = bloom_private.current_profile_id() and growth_module_id = 'tasks' and entry_type = 'earned';
  if v_reward_total <> 10 or (select awarded_minutes from public.bloom_growth_reward_events
      where profile_id = bloom_private.current_profile_id() and source_id = v_second_reward_task) <> 3 then
    raise exception 'Growth task rewards did not obey the per-module daily cap';
  end if;
  perform public.bloom_update_growth_item(v_second_reward_task, 'Second reward task', '', null, 'active', 0);
  perform public.bloom_update_growth_item(v_second_reward_task, 'Second reward task', '', null, 'completed', 100);
  select coalesce(sum(amount_minutes), 0) into v_reward_total from public.bloom_credit_ledger
    where user_id = bloom_private.current_profile_id() and growth_module_id = 'tasks' and entry_type = 'earned';
  if v_reward_total <> 10 or (select count(*) from public.bloom_credit_ledger
      where user_id = bloom_private.current_profile_id() and growth_source_id = v_second_reward_task) <> 1 then
    raise exception 'A repeated task completion awarded a second reward';
  end if;
  begin
    perform public.bloom_save_growth_reward_rules(bloom_private.current_profile_id(), 'tasks', true, 7, 10, 20, 5, true);
    raise exception using errcode = 'P0002', message = 'A personal profile enabled an unavailable parent approval flow';
  exception when raise_exception then if sqlerrm <> 'Check the growth reward rules' then raise; end if; end;

  perform public.bloom_save_growth_reward_rules('00000000-0000-0000-0000-000000000282', 'tasks', true, 4, 10, 20, 5, true);
  perform set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000282', true);
  v_child_reward_task := public.bloom_create_growth_item('tasks', 'task', 'Child reward task', '', null, null,
    '90000000-0000-0000-0000-000000000300');
  perform public.bloom_update_growth_item(v_child_reward_task, 'Child reward task', '', null, 'completed', 100);
  select id into v_child_reward_event from public.bloom_growth_reward_events
    where profile_id = bloom_private.current_profile_id() and source_id = v_child_reward_task and status = 'pending';
  if v_child_reward_event is null or exists (select 1 from public.bloom_credit_ledger
      where user_id = bloom_private.current_profile_id() and growth_source_id = v_child_reward_task) then
    raise exception 'A child reward bypassed parent approval';
  end if;
  perform public.bloom_save_growth_memory(true, array['tasks']::text[], '{"tasks":"Likes small steps."}'::jsonb);
  perform public.bloom_save_weekly_pillar_goals('[{"module_id":"tasks","target_count":4,"active_days":[2,4]}]'::jsonb);
  begin
    perform public.bloom_review_growth_reward(v_child_reward_event, true);
    raise exception using errcode = 'P0002', message = 'A child approved its own reward';
  exception when insufficient_privilege then null; end;
  begin
    perform public.bloom_save_growth_reward_rules(bloom_private.current_profile_id(), 'tasks', true, 4, 10, 20, 5, true);
    raise exception using errcode = 'P0002', message = 'A child changed its own reward settings';
  exception when insufficient_privilege then null; end;
  perform set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000281', true);
  if exists (select 1 from public.bloom_growth_memory where profile_id = '00000000-0000-0000-0000-000000000282') then
    raise exception 'A parent read memory that belongs only to the child';
  end if;
  if exists (select 1 from public.bloom_weekly_pillar_goals where profile_id = '00000000-0000-0000-0000-000000000282') then
    raise exception 'A parent read goals that belong only to an inaccessible child module';
  end if;
  v_approved_reward := public.bloom_review_growth_reward(v_child_reward_event, true);
  if v_approved_reward <> 4 or (select count(*) from public.bloom_credit_ledger
      where user_id = '00000000-0000-0000-0000-000000000282' and growth_source_id = v_child_reward_task) <> 1 then
    raise exception 'A parent-approved growth reward was not added once';
  end if;
  if public.bloom_review_growth_reward(v_child_reward_event, true) <> 4 then
    raise exception 'A reward review retry changed its outcome';
  end if;
  perform public.bloom_save_growth_reward_rules('00000000-0000-0000-0000-000000000281', 'study', true, 5, 10, 20, 0, false);
  v_growth_session := public.bloom_start_growth_session('study', v_subject, '90000000-0000-0000-0000-000000000301',
    'Test device', '90000000-0000-0000-0000-000000000302');
  perform public.bloom_finish_growth_session(v_growth_session);
  if (select awarded_minutes from public.bloom_growth_reward_events where profile_id = bloom_private.current_profile_id()
      and source_type = 'session' and source_id = v_growth_session) is distinct from 5 then
    raise exception 'Completed Study session did not use the shared reward rules';
  end if;
  perform public.bloom_save_growth_reward_rules('00000000-0000-0000-0000-000000000281', 'read', true, 5, 10, 20, 0, false);
  v_reading_item := public.bloom_create_growth_item('read', 'reading', 'Reward test reading', '', null, null,
    '90000000-0000-0000-0000-000000000303');
  v_growth_session := public.bloom_start_growth_session('read', v_reading_item, '90000000-0000-0000-0000-000000000304',
    'Test device', '90000000-0000-0000-0000-000000000305');
  perform public.bloom_finish_growth_session(v_growth_session);
  if (select awarded_minutes from public.bloom_growth_reward_events where profile_id = bloom_private.current_profile_id()
      and source_type = 'session' and source_id = v_growth_session) is distinct from 5 then
    raise exception 'Completed Read session did not use the shared reward rules';
  end if;
  select jsonb_object_agg(module_id, actual_value) into v_weekly_actuals
    from public.bloom_weekly_pillar_actuals();
  if v_weekly_actuals->>'exercise' is null or v_weekly_actuals->>'study' is null
    or (v_weekly_actuals->>'read')::numeric < 1
    or (v_weekly_actuals->>'tasks')::numeric < 1 then
    raise exception 'Weekly actuals did not count completed Study, Read, and Task activity: %', v_weekly_actuals;
  end if;
  perform set_config('bloom.selected_growth_record', v_record::text, true);
end $$;

reset role;
set local role service_role;
select public.bloom_finish_growth_ai_request(current_setting('bloom.ai_request')::uuid);
reset role;
set local role authenticated;
do $$
declare
  v_tutor_request uuid := '90000000-0000-0000-0000-000000000306';
  v_tutor_context jsonb;
  v_memory_context jsonb;
  v_lesson uuid;
begin
  select id into v_lesson from public.bloom_growth_items where profile_id = bloom_private.current_profile_id()
    and module_id = 'study' and title = 'Linear equations';
  begin
    perform public.bloom_begin_study_tutor_request(v_tutor_request, v_lesson, 'Explain linear equations simply.');
    raise exception using errcode = 'P0002', message = 'Study tutor accepted a question without consent';
  exception when raise_exception then if sqlerrm <> 'Study tutor consent and eligibility are required' then raise; end if; end;
  perform public.bloom_set_growth_ai_preferences('study', true, true);
  perform public.bloom_save_growth_memory(false, array['study', 'read']::text[],
    '{"study":"Likes worked examples.","read":"Prefers short chapters."}'::jsonb);
  if public.bloom_growth_ai_memory_context('study') <> '[]'::jsonb then
    raise exception 'Disabled memory was included in AI context';
  end if;
  perform public.bloom_save_growth_memory(true, array['study', 'read']::text[],
    '{"study":"Likes worked examples.","read":"Prefers short chapters."}'::jsonb);
  v_memory_context := public.bloom_growth_ai_memory_context('study');
  if jsonb_array_length(v_memory_context) <> 2 or not (v_memory_context @>
      '[{"domain":"study","summary":"Likes worked examples."}]'::jsonb) then
    raise exception 'Enabled, domain-limited memory was not returned to the authorized AI context';
  end if;
  v_tutor_context := public.bloom_begin_study_tutor_request(v_tutor_request, v_lesson, 'Explain linear equations simply.');
  if v_tutor_context->>'is_child' <> 'false' or v_tutor_context->'item'->>'title' <> 'Linear equations'
    or exists (select 1 from information_schema.columns where table_schema = 'bloom_private'
      and table_name = 'growth_ai_requests' and column_name ilike '%prompt%')
    or has_table_privilege('authenticated', 'bloom_private.growth_ai_requests', 'SELECT') then
    raise exception 'Study tutor consent or private request minimization failed';
  end if;
  perform set_config('bloom.study_tutor_request', v_tutor_request::text, true);
end $$;
reset role;
set local role service_role;
select bloom_private.finish_study_tutor_request(current_setting('bloom.study_tutor_request')::uuid,
  'Explain linear equations simply.', 'A linear equation describes a relationship whose graph is a straight line.',
  'This is a general explanation and may differ from your course materials.');
reset role;
set local role authenticated;
do $$
begin
  if (select count(*) from public.bloom_study_tutor_messages where profile_id = bloom_private.current_profile_id()) <> 2
    or not exists (select 1 from public.bloom_study_tutor_messages where request_id = current_setting('bloom.study_tutor_request')::uuid
      and role = 'assistant' and answer_scope = 'general' and uncertainty is not null) then
    raise exception 'Study tutor conversation was not saved with its general-answer label';
  end if;
  if has_table_privilege('authenticated', 'public.bloom_study_tutor_messages', 'INSERT') then
    raise exception 'Clients can write unverified Study tutor answers';
  end if;
  perform public.bloom_clear_study_tutor_conversation();
  if exists (select 1 from public.bloom_study_tutor_messages where profile_id = bloom_private.current_profile_id()) then
    raise exception 'Clearing the Study tutor did not remove its messages';
  end if;
  perform public.bloom_delete_growth_memory();
  if exists (select 1 from public.bloom_growth_memory where profile_id = bloom_private.current_profile_id()) then
    raise exception 'Deleting memory left the summary stored';
  end if;
end $$;
do $$ declare v_task uuid; v_request uuid := current_setting('bloom.ai_request')::uuid;
begin
  select id into v_task from public.bloom_growth_items where title = 'Read chapter' and item_type = 'task' and profile_id = bloom_private.current_profile_id();
  if (select count(*) from public.bloom_apply_task_breakdown(v_task, '["Read the chapter","Write a short summary"]'::jsonb, v_request)) <> 2 then
    raise exception 'Approved task breakdown did not save two checklist steps';
  end if;
  if (select count(*) from public.bloom_growth_items where parent_id = v_task and item_type = 'checklist') <> 2 then
    raise exception 'Approved steps are not attached to the selected task';
  end if;
  begin
    perform * from public.bloom_apply_task_breakdown(v_task, '["Changed step"]'::jsonb, v_request);
    raise exception using errcode = 'P0002', message = 'An approved AI draft was reused with changed steps';
  exception when raise_exception then if sqlerrm <> 'This draft was already approved with different steps' then raise; end if; end;
  if has_table_privilege('authenticated', 'bloom_private.growth_ai_requests', 'SELECT') then
    raise exception 'Clients can read private AI request metadata';
  end if;
end $$;

select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000282', true);
do $$ begin
  if exists (select 1 from public.bloom_growth_records where id = current_setting('bloom.selected_growth_record')::uuid) then
    raise exception 'Another profile can read private learning records';
  end if;
  begin
    perform public.bloom_delete_growth_record(current_setting('bloom.selected_growth_record')::uuid);
    raise exception using errcode = 'P0002', message = 'Another profile deleted a private learning record';
  exception when insufficient_privilege then null; end;
end $$;
rollback;
