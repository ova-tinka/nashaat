begin;

insert into auth.users(id) values ('00000000-0000-0000-0000-000000000041');
insert into public.exercises(id, name, measurement_type, is_system) values
  ('10000000-0000-0000-0000-000000000041', 'Scheduled exercise', 'reps_only', true);

set local role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000041', true);

do $$
declare
  v_today smallint := extract(isodow from (now() at time zone 'UTC'))::smallint;
  v_next_day smallint := case when extract(isodow from (now() at time zone 'UTC'))::integer = 7 then 1 else extract(isodow from (now() at time zone 'UTC'))::smallint + 1 end;
  v_previous_day smallint := case when extract(isodow from (now() at time zone 'UTC'))::integer = 1 then 7 else extract(isodow from (now() at time zone 'UTC'))::smallint - 1 end;
  v_plan uuid;
  v_session uuid;
  v_progress jsonb;
begin
  insert into public.bloom_settings(user_id, credit_timezone) values (auth.uid(), 'UTC');
  v_plan := public.bloom_create_workout_plan_scheduled('Scheduled plan', '[
    {"exercise_id":"10000000-0000-0000-0000-000000000041","sets":2,"target":8}
  ]'::jsonb, array[v_today, v_next_day]);

  if not exists (select 1 from public.bloom_workout_plans where id = v_plan and scheduled_days = array[v_today, v_next_day]) then
    raise exception 'Workout schedule was not saved';
  end if;
  begin
    update public.bloom_workout_plans set scheduled_days = array[v_today, v_today] where id = v_plan;
    raise exception using errcode = 'P0002', message = 'Duplicate scheduled day was accepted';
  exception when raise_exception then
    if sqlerrm <> 'A workout day can only be selected once' then raise; end if;
  end;

  select session_id into v_session from public.bloom_start_workout(v_plan);
  perform public.bloom_complete_workout(v_session, '[
    {"exercise_id":"10000000-0000-0000-0000-000000000041","sets_completed":2,"reps_completed":8}
  ]'::jsonb);
  v_progress := public.bloom_weekly_plan_progress();
  if (v_progress->>'planned_workouts')::integer <> 2
    or (v_progress->>'completed_planned_workouts')::integer <> 1
    or (v_progress->>'scheduled_days')::integer <> 2
    or (v_progress->>'rest_days')::integer <> 5 then
    raise exception 'Weekly plan progress is incorrect: %', v_progress;
  end if;

  perform public.bloom_update_workout_plan_scheduled(v_plan, 'Updated schedule', '[
    {"exercise_id":"10000000-0000-0000-0000-000000000041","sets":3,"target":10}
  ]'::jsonb, array[v_next_day]);
  if not exists (select 1 from public.bloom_workout_plans where id = v_plan and scheduled_days = array[v_next_day] and title = 'Updated schedule')
    or not exists (select 1 from public.bloom_plan_exercises where plan_id = v_plan and sets = 3 and target_reps = 10) then
    raise exception 'Workout schedule was not updated with the plan';
  end if;
  v_progress := public.bloom_weekly_plan_progress();
  if (v_progress->>'planned_workouts')::integer <> 1
    or (v_progress->>'completed_planned_workouts')::integer <> 0
    or (v_progress->>'scheduled_days')::integer <> 1
    or (v_progress->>'rest_days')::integer <> 6 then
    raise exception 'Updated weekly plan progress is incorrect: %', v_progress;
  end if;

  perform public.bloom_update_workout_plan_scheduled(v_plan, 'Earlier schedule', '[
    {"exercise_id":"10000000-0000-0000-0000-000000000041","sets":3,"target":10}
  ]'::jsonb, array[v_previous_day]);
  v_progress := public.bloom_weekly_plan_progress();
  if (v_progress->>'planned_workouts')::integer <> 1
    or (v_progress->>'completed_planned_workouts')::integer <> 0
    or (v_progress->>'scheduled_days')::integer <> 1
    or (v_progress->>'missed_planned_workouts')::integer <> 1
    or (v_progress->>'rest_days')::integer <> 6 then
    raise exception 'Missed schedule recovery metric is incorrect: %', v_progress;
  end if;
end;
$$;

rollback;
