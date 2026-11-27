begin;

-- Disposable accounts: personal user, family parent, and family child.
insert into auth.users(id, email, email_confirmed_at) values
  ('00000000-0000-0000-0000-000000000991', 'e2e-personal@example.invalid', now()),
  ('00000000-0000-0000-0000-000000000992', 'e2e-parent@example.invalid', now()),
  ('00000000-0000-0000-0000-000000000993', 'e2e-child@example.invalid', now());

insert into public.bloom_settings(user_id, credits_enabled, credit_mode, credit_timezone, weekly_earning_cap_minutes)
values
  ('00000000-0000-0000-0000-000000000991', true, 'easy', 'UTC', 60);

-- 1. Personal account: start sessions across all 4 pillars.
set local role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000991', true);
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-000000000991","session_id":"99000000-0000-0000-0000-000000000001"}', true);

do $$
declare
  v_ex uuid;
  v_plan uuid;
  v_workout uuid;
  v_study uuid;
  v_read uuid;
  v_task uuid;
  v_study_sess uuid;
  v_read_sess uuid;
begin
  if not public.bloom_register_device('99100000-0000-0000-0000-000000000001', 'Mac Primary', 'macos', true, 'allowed', 'on', 2) then
    raise exception 'Device 1 registration failed';
  end if;

  -- Pillar 1: Exercise workout earning credits.
  v_ex := public.bloom_create_custom_exercise('E2E Squat', 'Bodyweight', 'reps_only');
  v_plan := public.bloom_create_workout_plan('E2E Plan', jsonb_build_array(
    jsonb_build_object('exercise_id', v_ex, 'sets', 2, 'target', 10)
  ));
  select session_id into v_workout from public.bloom_start_workout(v_plan);
  perform public.bloom_complete_workout(v_workout, jsonb_build_array(
    jsonb_build_object('exercise_id', v_ex, 'sets_completed', 2, 'reps_completed', 10)
  ));

  -- Enable rewards on Study, Read, Tasks.
  perform public.bloom_save_growth_reward_rules('00000000-0000-0000-0000-000000000991', 'study', true, 15, 60, 120, 1, false);
  perform public.bloom_save_growth_reward_rules('00000000-0000-0000-0000-000000000991', 'read', true, 15, 60, 120, 1, false);
  perform public.bloom_save_growth_reward_rules('00000000-0000-0000-0000-000000000991', 'tasks', true, 10, 60, 120, 0, false);

  -- Start Pillar 2 (Study) & Pillar 3 (Read) sessions.
  v_study := public.bloom_create_growth_item('study', 'subject', 'E2E Biology', '', null, 30, '99200000-0000-0000-0000-000000000001');
  v_study_sess := public.bloom_start_growth_session('study', v_study, '99100000-0000-0000-0000-000000000001', 'Mac Primary', '99200000-0000-0000-0000-000000000002');
  v_read := public.bloom_create_growth_item('read', 'reading', 'E2E Book', '', null, null, '99200000-0000-0000-0000-000000000003');
  v_read_sess := public.bloom_start_growth_session('read', v_read, '99100000-0000-0000-0000-000000000001', 'Mac Primary', '99200000-0000-0000-0000-000000000004');
  v_task := public.bloom_create_growth_item('tasks', 'task', 'E2E Task', '', null, null, '99200000-0000-0000-0000-000000000005');

  perform set_config('bloom.e2e_study_sess', v_study_sess::text, true);
  perform set_config('bloom.e2e_read_sess', v_read_sess::text, true);
  perform set_config('bloom.e2e_task', v_task::text, true);
end $$;

-- Advance session start times with superuser role, then finish & spend as authenticated.
reset role;
update public.bloom_growth_sessions
set started_at = clock_timestamp() - interval '10 minutes'
where id in (current_setting('bloom.e2e_study_sess')::uuid, current_setting('bloom.e2e_read_sess')::uuid);

set local role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000991', true);
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-000000000991","session_id":"99000000-0000-0000-0000-000000000001"}', true);

do $$
declare
  v_usage_id uuid;
begin
  perform public.bloom_finish_growth_session(current_setting('bloom.e2e_study_sess')::uuid);
  perform public.bloom_finish_growth_session(current_setting('bloom.e2e_read_sess')::uuid);
  perform public.bloom_update_growth_item(current_setting('bloom.e2e_task')::uuid, 'E2E Task', '', null, 'completed', 100);

  if public.bloom_credit_balance() <= 0 or public.bloom_credit_balance() > 60 then
    raise exception 'Unexpected credit balance after 4 pillars: %', public.bloom_credit_balance();
  end if;

  -- Screen Time spending & idempotent settlement.
  select session_id into v_usage_id
  from public.bloom_start_usage_session(
    '99300000-0000-0000-0000-000000000001',
    '99400000-0000-0000-0000-000000000001',
    300000
  );
  perform public.bloom_finish_usage_session(
    v_usage_id,
    '99400000-0000-0000-0000-000000000001'
  );
end $$;

-- 2. Second device sync + revocation of Device 1.
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-000000000991","session_id":"99000000-0000-0000-0000-000000000002"}', true);
do $$ begin
  if not public.bloom_register_device('99100000-0000-0000-0000-000000000002', 'Phone Secondary', 'ios', true, 'allowed', 'on', 1) then
    raise exception 'Device 2 registration failed';
  end if;
  if (select count(*) from public.bloom_list_devices()) <> 2 then
    raise exception 'Expected 2 synced devices';
  end if;
  perform public.bloom_revoke_device('99100000-0000-0000-0000-000000000001');
  if (select count(*) from public.bloom_list_devices()) <> 1 then
    raise exception 'Revoked device remained in active list';
  end if;
end $$;

-- 3. Family household creation, child invite/assignment, and parent/child isolation.
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000992', true);
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-000000000992","session_id":"99000000-0000-0000-0000-000000000003"}', true);
select set_config('bloom.e2e_house', public.bloom_create_household('E2E Family')::text, true);
select set_config('bloom.e2e_invite', public.bloom_create_child_invite(current_setting('bloom.e2e_house')::uuid), true);

select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000993', true);
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-000000000993","session_id":"99000000-0000-0000-0000-000000000004"}', true);
select public.bloom_accept_child_invite(current_setting('bloom.e2e_invite'));

select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000992', true);
select * from public.bloom_set_child_module_assignments('00000000-0000-0000-0000-000000000993', array['exercise', 'study']::text[]);

select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000993', true);
do $$ begin
  if exists (select 1 from public.bloom_workout_plans where user_id = '00000000-0000-0000-0000-000000000991') then
    raise exception 'Child read unrelated personal account workout plan';
  end if;
end $$;

reset role;
do $$ begin
  if not exists (select 1 from public.bloom_child_module_assignments where profile_id = '00000000-0000-0000-0000-000000000993' and module_id = 'study' and assigned = true) then
    raise exception 'Child assignment missing';
  end if;
end $$;

rollback;
