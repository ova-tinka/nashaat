begin;

insert into auth.users(id) values
  ('00000000-0000-0000-0000-000000000501'),
  ('00000000-0000-0000-0000-000000000502'),
  ('00000000-0000-0000-0000-000000000503');

insert into public.bloom_settings(user_id, credits_enabled, credit_timezone, reps_per_award, rep_award_minutes)
values
  ('00000000-0000-0000-0000-000000000501', true, 'America/New_York', 10, 5),
  ('00000000-0000-0000-0000-000000000502', true, 'UTC', 10, 5),
  ('00000000-0000-0000-0000-000000000503', true, 'UTC', 10, 5);

insert into public.bloom_households(id, owner_user_id, name)
values ('90000000-0000-0000-0000-000000000501', '00000000-0000-0000-0000-000000000501', 'Cap family');
insert into public.bloom_household_members(household_id, user_id, role) values
  ('90000000-0000-0000-0000-000000000501', '00000000-0000-0000-0000-000000000501', 'parent'),
  ('90000000-0000-0000-0000-000000000501', '00000000-0000-0000-0000-000000000502', 'child');
insert into public.bloom_child_module_assignments(profile_id, module_id, assigned, updated_by) values
  ('00000000-0000-0000-0000-000000000502', 'tasks', true, '00000000-0000-0000-0000-000000000501'),
  ('00000000-0000-0000-0000-000000000502', 'study', true, '00000000-0000-0000-0000-000000000501');

do $$
declare
  v_week_start timestamptz;
  v_week_end timestamptz;
begin
  if (select weekly_earning_cap_minutes from public.bloom_settings where user_id = '00000000-0000-0000-0000-000000000501') <> 120 then
    raise exception 'New profile did not default to 120 minutes/week';
  end if;

  -- Test DST boundary in America/New_York (Sunday 2026-11-01 fall-back week).
  v_week_start := bloom_private.credit_week_start('2026-11-01T12:00:00Z', 'America/New_York');
  v_week_end := bloom_private.credit_week_end('2026-11-01T12:00:00Z', 'America/New_York');
  if v_week_end <= v_week_start or (v_week_end - v_week_start) < interval '6 days' then
    raise exception 'Invalid DST week range: % to %', v_week_start, v_week_end;
  end if;
end $$;

-- Child cannot edit own cap; unrelated profile cannot edit; parent can edit child cap and personal owner can edit own cap.
set local role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000502', true);
do $$
begin
  begin
    perform public.bloom_save_weekly_earning_cap('00000000-0000-0000-0000-000000000502', 500);
    raise exception using errcode = 'P0002', message = 'Child updated own weekly earning cap';
  exception when insufficient_privilege then null; end;
end $$;

select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000503', true);
do $$
begin
  begin
    perform public.bloom_save_weekly_earning_cap('00000000-0000-0000-0000-000000000501', 10);
    raise exception using errcode = 'P0002', message = 'Unrelated profile updated another account cap';
  exception when insufficient_privilege then null; end;
end $$;

select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000501', true);
do $$
declare
  v_subject uuid;
  v_reading uuid;
  v_task1 uuid;
  v_task2 uuid;
  v_session uuid;
  v_ex_id uuid;
  v_plan_id uuid;
  v_workout_session uuid;
  v_child_task uuid;
  v_child_event uuid;
  v_total numeric;
begin
  -- Opt-out (null) and opt-in (15 min/week) for personal owner.
  perform public.bloom_save_weekly_earning_cap('00000000-0000-0000-0000-000000000501', null);
  if (select weekly_earning_cap_minutes from public.bloom_settings where user_id = '00000000-0000-0000-0000-000000000501') is not null then
    raise exception 'Could not clear weekly earning cap';
  end if;
  perform public.bloom_save_weekly_earning_cap('00000000-0000-0000-0000-000000000501', 15);

  -- Parent sets child cap to 10 min/week.
  perform public.bloom_save_weekly_earning_cap('00000000-0000-0000-0000-000000000502', 10);

  -- Configure Study, Read, and Tasks rules (each 6 min per completion, per-pillar cap 60/week).
  perform public.bloom_save_growth_reward_rules('00000000-0000-0000-0000-000000000501', 'study', true, 6, 60, 60, 0, false);
  perform public.bloom_save_growth_reward_rules('00000000-0000-0000-0000-000000000501', 'read', true, 6, 60, 60, 0, false);
  perform public.bloom_save_growth_reward_rules('00000000-0000-0000-0000-000000000501', 'tasks', true, 6, 60, 60, 0, false);

  -- 1) Exercise earns 5 min (total = 5/15).
  v_ex_id := public.bloom_create_custom_exercise('Cap Pushup', 'Test exercise', 'reps_only');
  v_plan_id := public.bloom_create_plan_for_user(
    '00000000-0000-0000-0000-000000000501',
    'Cap Plan',
    jsonb_build_array(jsonb_build_object('exercise_id', v_ex_id, 'sets', 1, 'target', 10))
  );
  select session_id into v_workout_session from public.bloom_start_workout(v_plan_id);
  perform public.bloom_complete_workout(
    v_workout_session,
    jsonb_build_array(jsonb_build_object('exercise_id', v_ex_id, 'sets_completed', 1, 'reps_completed', 10))
  );

  -- 2) Study earns 6 min (total = 11/15).
  v_subject := public.bloom_create_growth_item('study', 'subject', 'Cap Study', '', null, 30, '90000000-0000-0000-0000-000000000511');
  v_session := public.bloom_start_growth_session('study', v_subject, '90000000-0000-0000-0000-000000000512', 'Test', '90000000-0000-0000-0000-000000000513');
  perform public.bloom_finish_growth_session(v_session);

  -- 3) Read gets partial award of 4 min (15 - 11 = 4, total = 15/15).
  v_reading := public.bloom_create_growth_item('read', 'reading', 'Cap Read', '', null, null, '90000000-0000-0000-0000-000000000514');
  v_session := public.bloom_start_growth_session('read', v_reading, '90000000-0000-0000-0000-000000000515', 'Test', '90000000-0000-0000-0000-000000000516');
  perform public.bloom_finish_growth_session(v_session);

  -- 4) Tasks earns 0 (capped at 15/15), and Focus on task earns 0.
  v_task1 := public.bloom_create_growth_item('tasks', 'task', 'Cap Task 1', '', null, null, '90000000-0000-0000-0000-000000000517');
  v_task2 := public.bloom_start_task_focus(v_task1, '90000000-0000-0000-0000-000000000518');
  perform public.bloom_finish_task_focus(v_task2);
  perform public.bloom_update_growth_item(v_task1, 'Cap Task 1', '', null, 'completed', 100);

  select coalesce(sum(amount_minutes), 0) into v_total
  from public.bloom_credit_ledger
  where user_id = '00000000-0000-0000-0000-000000000501' and entry_type = 'earned';

  if v_total <> 15 then
    raise exception 'Account-wide weekly cap failed: expected 15 total earned across pillars, got %', v_total;
  end if;

  -- Child wallet is independent (0 earned so far) and enforces delayed parent approval against child's 10-min cap.
  perform public.bloom_save_growth_reward_rules('00000000-0000-0000-0000-000000000502', 'tasks', true, 12, 60, 60, 0, true);
  perform set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000502', true);
  v_child_task := public.bloom_create_growth_item('tasks', 'task', 'Child Cap Task', '', null, null, '90000000-0000-0000-0000-000000000519');
  perform public.bloom_update_growth_item(v_child_task, 'Child Cap Task', '', null, 'completed', 100);
  select id into v_child_event from public.bloom_growth_reward_events
  where profile_id = '00000000-0000-0000-0000-000000000502' and source_id = v_child_task;

  perform set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000501', true);
  if public.bloom_review_growth_reward(v_child_event, true) <> 10 then
    raise exception 'Delayed parent approval did not clamp child reward to 10-minute account cap';
  end if;
end $$;

rollback;
