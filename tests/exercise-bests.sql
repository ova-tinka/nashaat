begin;

insert into auth.users(id) values ('00000000-0000-0000-0000-000000000951');
insert into public.bloom_settings(user_id, credits_enabled, credit_timezone)
values ('00000000-0000-0000-0000-000000000951', false, 'UTC');

set local role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000951', true);
select set_config('bloom.best_ex', public.bloom_create_custom_exercise('Bench Press', 'Strength', 'reps_weight')::text, true);
reset role;

-- Insert 1,050 completed sessions where the oldest session (#1, outside newest 1,000) holds the true lifetime bests (99 reps, 120 kg).
insert into public.bloom_workout_sessions(
  user_id,
  plan_snapshot,
  status,
  started_at,
  completed_at,
  credits_enabled_at_completion,
  exercise_results
)
select
  '00000000-0000-0000-0000-000000000951'::uuid,
  jsonb_build_array(jsonb_build_object(
    'exercise_id', current_setting('bloom.best_ex'),
    'name', 'Bench Press',
    'measurement_type', 'reps_weight'
  )),
  'completed',
  now() - ((1051 - g) * interval '1 hour'),
  now() - ((1051 - g) * interval '1 hour') + interval '15 minutes',
  false,
  jsonb_build_array(jsonb_build_object(
    'exercise_id', current_setting('bloom.best_ex'),
    'sets_completed', 3,
    'reps_completed', case when g = 1 then 99 else 10 end,
    'weight_kg', case when g = 1 then 120 else 40 end
  ))
from generate_series(1, 1050) as g;

set local role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000951', true);
do $$
declare
  v_res jsonb;
  v_reps numeric;
  v_weight numeric;
begin
  v_res := public.bloom_exercise_personal_bests();
  if (v_res->>'total_completed')::integer <> 1050 then
    raise exception 'Expected 1050 completed workouts, got %', v_res->>'total_completed';
  end if;
  select (b->>'value')::numeric into v_reps
  from jsonb_array_elements(v_res->'bests') b
  where b->>'metric' = 'Repetitions per set';
  select (b->>'value')::numeric into v_weight
  from jsonb_array_elements(v_res->'bests') b
  where b->>'metric' = 'Weight';
  if v_reps <> 99 or v_weight <> 120 then
    raise exception 'Server personal bests missed oldest session beyond 1,000 rows: reps=% weight=%', v_reps, v_weight;
  end if;
end $$;

rollback;
