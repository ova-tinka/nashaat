begin;

insert into auth.users(id) values
  ('00000000-0000-0000-0000-000000000021'),
  ('00000000-0000-0000-0000-000000000022'),
  ('00000000-0000-0000-0000-000000000023');
insert into public.exercises(id, name, measurement_type, is_system) values
  ('10000000-0000-0000-0000-000000000021', 'Goal repetitions', 'reps_only', true),
  ('10000000-0000-0000-0000-000000000022', 'Goal timer', 'time_only', true);
insert into public.bloom_households(id, owner_user_id, name)
  values ('20000000-0000-0000-0000-000000000021', '00000000-0000-0000-0000-000000000023', 'Analytics family');
insert into public.bloom_household_members(household_id, user_id, role) values
  ('20000000-0000-0000-0000-000000000021', '00000000-0000-0000-0000-000000000023', 'parent'),
  ('20000000-0000-0000-0000-000000000021', '00000000-0000-0000-0000-000000000021', 'child');

set local role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000021', true);

do $$
declare
  v_plan uuid;
  v_session uuid;
  v_amount numeric;
  v_stats jsonb;
begin
  insert into public.bloom_settings(user_id, credit_timezone) values (auth.uid(), 'Asia/Qatar');
  begin
    update public.bloom_settings set earning_strategy = 'goal_analytics' where user_id = auth.uid();
    raise exception using errcode = 'P0002', message = 'Goal strategy accepted without a goal';
  exception when check_violation then null;
  end;
  update public.bloom_settings set earning_strategy = 'goal_analytics',
    weekly_workout_target = 2, weekly_credit_target_minutes = 20 where user_id = auth.uid();

  v_plan := public.bloom_create_workout_plan('Weekly goal', '[
    {"exercise_id":"10000000-0000-0000-0000-000000000021","sets":2,"target":10},
    {"exercise_id":"10000000-0000-0000-0000-000000000022","sets":1,"target":60}
  ]'::jsonb);

  select session_id into v_session from public.bloom_start_workout(v_plan);
  perform public.bloom_complete_workout(v_session, '[
    {"exercise_id":"10000000-0000-0000-0000-000000000021","sets_completed":2,"reps_completed":10},
    {"exercise_id":"10000000-0000-0000-0000-000000000022","sets_completed":1,"duration_seconds":60}
  ]'::jsonb);
  select amount_minutes into v_amount from public.bloom_credit_ledger where workout_session_id = v_session;
  if v_amount <> 10 then raise exception 'A complete session should earn its share of the weekly goal: %', v_amount; end if;

  select session_id into v_session from public.bloom_start_workout(v_plan);
  perform public.bloom_complete_workout(v_session, '[
    {"exercise_id":"10000000-0000-0000-0000-000000000021","sets_completed":1,"reps_completed":5}
  ]'::jsonb);
  select amount_minutes into v_amount from public.bloom_credit_ledger where workout_session_id = v_session;
  if v_amount <> 3.1944 then raise exception 'Partial completion was not scored from the session outcomes: %', v_amount; end if;

  -- A session that reaches the target must not push this week's goal pool over 20 minutes.
  select session_id into v_session from public.bloom_start_workout(v_plan);
  perform public.bloom_complete_workout(v_session, '[
    {"exercise_id":"10000000-0000-0000-0000-000000000021","sets_completed":2,"reps_completed":10},
    {"exercise_id":"10000000-0000-0000-0000-000000000022","sets_completed":1,"duration_seconds":60}
  ]'::jsonb);
  if public.bloom_credit_balance() <> 20 then raise exception 'Weekly target pool was not capped'; end if;

  select session_id into v_session from public.bloom_start_workout(v_plan);
  perform public.bloom_complete_workout(v_session, '[
    {"exercise_id":"10000000-0000-0000-0000-000000000021","sets_completed":2,"reps_completed":10},
    {"exercise_id":"10000000-0000-0000-0000-000000000022","sets_completed":1,"duration_seconds":60}
  ]'::jsonb);
  if exists (select 1 from public.bloom_credit_ledger where workout_session_id = v_session) then
    raise exception 'A full weekly goal pool granted more credits';
  end if;

  v_stats := public.bloom_workout_analytics();
  if (v_stats->>'workouts_completed')::integer <> 4
    or (v_stats->>'weekly_workout_target')::integer <> 2
    or (v_stats->>'active_days')::integer <> 1
    or (v_stats->>'exercise_minutes')::numeric <> 3
    or (v_stats->>'sets_completed')::integer <> 10
    or (v_stats->>'reps_completed')::integer <> 65
    or (v_stats->>'credits_earned_minutes')::numeric <> 20
    or jsonb_array_length(v_stats->'history') <> 4 then
    raise exception 'Weekly workout analytics are incorrect: %', v_stats;
  end if;
end;
$$;

select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000022', true);
do $$ begin
  begin
    perform public.bloom_workout_analytics('00000000-0000-0000-0000-000000000021');
    raise exception using errcode = 'P0002', message = 'Unrelated account read workout analytics';
  exception when raise_exception then
    if sqlerrm <> 'Family access required' then raise; end if;
  end;
end; $$;

select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000023', true);
do $$ declare v_stats jsonb;
begin
  v_stats := public.bloom_workout_analytics('00000000-0000-0000-0000-000000000021');
  if (v_stats->>'workouts_completed')::integer <> 4 or (v_stats->>'credits_earned_minutes')::numeric <> 20 then
    raise exception 'Parent could not read linked child workout analytics';
  end if;
end; $$;

rollback;
