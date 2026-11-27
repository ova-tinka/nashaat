begin;

insert into auth.users(id) values ('00000000-0000-0000-0000-000000000801');
insert into public.bloom_settings(user_id, credits_enabled, credit_timezone)
values ('00000000-0000-0000-0000-000000000801', true, 'UTC');

set local role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000801', true);

do $$
declare
  v_ex uuid;
  v_plan uuid;
  v_study uuid;
  v_read uuid;
  v_task uuid;
  v_archived_task uuid;
  v_res jsonb;
  v_dup jsonb;
  v_balance integer;
begin
  v_ex := public.bloom_create_custom_exercise('Offline Pushup', 'Bodyweight', 'reps_only');
  v_plan := public.bloom_create_workout_plan('Offline Plan', jsonb_build_array(
    jsonb_build_object('exercise_id', v_ex, 'sets', 2, 'target', 10)
  ));
  v_study := public.bloom_create_growth_item('study', 'subject', 'Offline Study', '', null, 30, '80000000-0000-0000-0000-000000000001');
  v_read := public.bloom_create_growth_item('read', 'reading', 'Offline Book', '', null, null, '80000000-0000-0000-0000-000000000002');
  v_task := public.bloom_create_growth_item('tasks', 'task', 'Offline Task', '', null, null, '80000000-0000-0000-0000-000000000003');
  v_archived_task := public.bloom_create_growth_item('tasks', 'task', 'Archived Task', '', null, null, '80000000-0000-0000-0000-000000000004');
  perform public.bloom_update_growth_item(v_archived_task, 'Archived Task', '', null, 'archived', 0);

  -- Enable rewards for Study, Read, Tasks.
  perform public.bloom_save_growth_reward_rules('00000000-0000-0000-0000-000000000801', 'study', true, 15, 60, 120, 1, false);
  perform public.bloom_save_growth_reward_rules('00000000-0000-0000-0000-000000000801', 'read', true, 15, 60, 120, 1, false);
  perform public.bloom_save_growth_reward_rules('00000000-0000-0000-0000-000000000801', 'tasks', true, 10, 60, 120, 0, false);

  -- Before sync: balance is 0 and Screen Time spending is blocked.
  v_balance := public.bloom_credit_balance();
  if v_balance <> 0 then
    raise exception 'Expected 0 initial balance, got %', v_balance;
  end if;

  -- 1. Exercise offline workout: accepted as self-reported history, exact duration preserved, 0 automatic credits.
  v_res := public.bloom_sync_offline_workout(
    '81000000-0000-0000-0000-000000000001', v_plan,
    now() - interval '2 hours', now() - interval '1 hour 40 minutes', 1200,
    jsonb_build_array(jsonb_build_object('exercise_id', v_ex, 'sets_completed', 2, 'reps_completed', 10))
  );
  v_dup := public.bloom_sync_offline_workout(
    '81000000-0000-0000-0000-000000000001', v_plan,
    now() - interval '2 hours', now() - interval '1 hour 40 minutes', 1200,
    jsonb_build_array(jsonb_build_object('exercise_id', v_ex, 'sets_completed', 2, 'reps_completed', 10))
  );
  if (v_res->>'duplicate')::boolean or not (v_dup->>'duplicate')::boolean
    or (v_res->>'duration_seconds')::integer <> 1200
    or (v_res->>'credits_earned_minutes')::integer <> 0 then
    raise exception 'Offline workout sync failed: % / %', v_res, v_dup;
  end if;

  -- 2. Study offline session: accepted as self-reported history, 0 time-based credits.
  v_res := public.bloom_sync_offline_growth_session(
    '81000000-0000-0000-0000-000000000002', 'study', v_study,
    '82000000-0000-0000-0000-000000000001', 'Offline Mac',
    now() - interval '90 minutes', now() - interval '70 minutes', 1200
  );
  v_dup := public.bloom_sync_offline_growth_session(
    '81000000-0000-0000-0000-000000000002', 'study', v_study,
    '82000000-0000-0000-0000-000000000001', 'Offline Mac',
    now() - interval '90 minutes', now() - interval '70 minutes', 1200
  );
  if (v_res->>'duplicate')::boolean or not (v_dup->>'duplicate')::boolean
    or (v_res->>'duration_seconds')::integer <> 1200 then
    raise exception 'Offline study sync failed: % / %', v_res, v_dup;
  end if;

  -- 3. Read offline session (even on archived item): accepted, 0 time-based credits.
  perform public.bloom_update_growth_item(v_read, 'Offline Book', '', null, 'archived', 0);
  v_res := public.bloom_sync_offline_growth_session(
    '81000000-0000-0000-0000-000000000003', 'read', v_read,
    '82000000-0000-0000-0000-000000000001', 'Offline Mac',
    now() - interval '60 minutes', now() - interval '45 minutes', 900
  );
  if (v_res->>'duration_seconds')::integer <> 900 then
    raise exception 'Offline read sync failed on archived item';
  end if;

  -- Verify timed offline sessions added 0 automatic time-based credit.
  if public.bloom_credit_balance() <> 0 then
    raise exception 'Offline timed sessions unexpectedly awarded time-based credit: %', public.bloom_credit_balance();
  end if;

  -- 4. Offline task completion: archived task returns archived (0 credit); active task awards normal reward once.
  v_res := public.bloom_sync_offline_task_completion('81000000-0000-0000-0000-000000000004', v_archived_task);
  if v_res->>'status' <> 'archived' or public.bloom_credit_balance() <> 0 then
    raise exception 'Archived offline task awarded credit or wrong status: %', v_res;
  end if;

  v_res := public.bloom_sync_offline_task_completion('81000000-0000-0000-0000-000000000005', v_task);
  v_dup := public.bloom_sync_offline_task_completion('81000000-0000-0000-0000-000000000005', v_task);
  if (v_res->>'duplicate')::boolean or not (v_dup->>'duplicate')::boolean
    or public.bloom_credit_balance() <> 10 then
    raise exception 'Offline task completion reward mismatch: balance=% res=% dup=%', public.bloom_credit_balance(), v_res, v_dup;
  end if;
end $$;

rollback;
