begin;

insert into auth.users(id) values
  ('00000000-0000-0000-0000-000000000031'),
  ('00000000-0000-0000-0000-000000000032');
insert into public.exercises(id, name, description, instructions, media_link, measurement_type, is_system) values
  ('10000000-0000-0000-0000-000000000031', 'Plan edit exercise', 'Move with control.', array['Start in a stable position.', 'Return to rest.'], 'https://example.test/demo', 'reps_only', true);

set local role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000031', true);

do $$
declare
  v_plan uuid;
  v_session uuid;
  v_snapshot jsonb;
  v_title text;
begin
  v_plan := public.bloom_create_workout_plan('Original plan', '[
    {"exercise_id":"10000000-0000-0000-0000-000000000031","sets":2,"target":8}
  ]'::jsonb);
  select session_id into v_session from public.bloom_start_workout(v_plan);
  begin
    perform public.bloom_update_workout_plan(v_plan, 'Changed while active', '[
      {"exercise_id":"10000000-0000-0000-0000-000000000031","sets":3,"target":10}
    ]'::jsonb);
    raise exception using errcode = 'P0002', message = 'Active plan was editable';
  exception when raise_exception then
    if sqlerrm <> 'Finish or cancel the active workout before editing this plan' then raise; end if;
  end;
  perform public.bloom_cancel_workout(v_session);

  perform public.bloom_update_workout_plan(v_plan, 'Updated plan', '[
    {"exercise_id":"10000000-0000-0000-0000-000000000031","sets":3,"target":10}
  ]'::jsonb);
  if not exists (select 1 from public.bloom_workout_plans where id = v_plan and title = 'Updated plan')
    or not exists (select 1 from public.bloom_plan_exercises where plan_id = v_plan and sets = 3 and target_reps = 10) then
    raise exception 'Workout plan edit was not saved';
  end if;

  select session_id into v_session from public.bloom_start_workout(v_plan);
  select plan_title_snapshot, plan_snapshot into v_title, v_snapshot
    from public.bloom_workout_sessions where id = v_session;
  if v_title <> 'Updated plan' or v_snapshot->0->>'description' <> 'Move with control.'
    or v_snapshot->0->'instructions'->>0 <> 'Start in a stable position.'
    or v_snapshot->0->>'media_link' <> 'https://example.test/demo'
    or (v_snapshot->0->>'target_reps')::integer <> 10 then
    raise exception 'Workout session did not preserve its plan and exercise guidance';
  end if;
end;
$$;

select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000032', true);
do $$ begin
  begin
    perform public.bloom_update_plan_for_user(
      '00000000-0000-0000-0000-000000000031',
      (select id from public.bloom_workout_plans where user_id = '00000000-0000-0000-0000-000000000031' limit 1),
      'Unauthorized', '[{"exercise_id":"10000000-0000-0000-0000-000000000031","sets":1,"target":1}]'::jsonb
    );
    raise exception using errcode = 'P0002', message = 'Unrelated account edited a workout plan';
  exception when raise_exception then
    if sqlerrm <> 'Family access required' then raise; end if;
  end;
end; $$;

rollback;
