begin;

create or replace function bloom_private.exercise_personal_bests(p_user_id uuid default null)
returns jsonb language plpgsql stable security definer set search_path = pg_catalog, pg_temp as $$
declare
  v_actor uuid := bloom_private.current_profile_id();
  v_target uuid := coalesce(p_user_id, v_actor);
  v_timezone text := 'UTC';
  v_total integer := 0;
  v_dates jsonb := '[]'::jsonb;
  v_bests jsonb := '[]'::jsonb;
begin
  if v_actor is null or v_target is null or (v_target <> v_actor and not bloom_private.is_parent_of(v_target)) then
    raise exception 'Access denied' using errcode = '42501';
  end if;

  select coalesce(nullif(s.credit_timezone, ''), 'UTC')
  into v_timezone
  from public.bloom_settings s
  where s.user_id = v_target;

  v_timezone := coalesce(v_timezone, 'UTC');

  select count(*)::integer,
         coalesce(
           jsonb_agg(distinct to_char((ws.completed_at at time zone v_timezone), 'YYYY-MM-DD'))
             filter (where ws.completed_at is not null),
           '[]'::jsonb
         )
  into v_total, v_dates
  from public.bloom_workout_sessions ws
  where ws.user_id = v_target
    and ws.status = 'completed';

  with completed_rows as (
    select ws.completed_at, ws.plan_snapshot, ws.exercise_results
    from public.bloom_workout_sessions ws
    where ws.user_id = v_target
      and ws.status = 'completed'
      and jsonb_typeof(ws.exercise_results) = 'array'
  ),
  extracted as (
    select
      (res->>'exercise_id')::uuid as exercise_id,
      coalesce(
        snap->>'name',
        (select e.name from public.exercises e where e.id = (res->>'exercise_id')::uuid)
      ) as exercise_name,
      coalesce(
        snap->>'measurement_type',
        (select e.measurement_type::text from public.exercises e where e.id = (res->>'exercise_id')::uuid)
      ) as measurement,
      nullif(res->>'sets_completed', '')::numeric as sets_completed,
      nullif(res->>'reps_completed', '')::numeric as reps_completed,
      nullif(res->>'weight_kg', '')::numeric as weight_kg,
      nullif(res->>'duration_seconds', '')::numeric as duration_seconds,
      nullif(res->>'distance_km', '')::numeric as distance_km,
      cr.completed_at
    from completed_rows cr
    cross join lateral jsonb_array_elements(cr.exercise_results) as res
    left join lateral (
      select p
      from jsonb_array_elements(
        case when jsonb_typeof(cr.plan_snapshot) = 'array' then cr.plan_snapshot else '[]'::jsonb end
      ) as p
      where p->>'exercise_id' = res->>'exercise_id'
      limit 1
    ) as snap_row on true
    cross join lateral (select coalesce(snap_row.p, '{}'::jsonb) as snap) as s
    where (res->>'exercise_id') ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
  ),
  metrics as (
    select exercise_id, exercise_name, measurement, 'Repetitions per set'::text as metric, reps_completed as value, 'reps'::text as unit, completed_at
    from extracted
    where sets_completed > 0 and measurement in ('reps_only', 'reps_weight') and reps_completed > 0
    union all
    select exercise_id, exercise_name, measurement, 'Weight'::text as metric, weight_kg as value, 'kg'::text as unit, completed_at
    from extracted
    where sets_completed > 0 and measurement = 'reps_weight' and weight_kg >= 0
    union all
    select exercise_id, exercise_name, measurement, 'Duration per set'::text as metric, duration_seconds as value, 'sec'::text as unit, completed_at
    from extracted
    where sets_completed > 0 and measurement in ('time_only', 'time_distance') and duration_seconds > 0
    union all
    select exercise_id, exercise_name, measurement, 'Distance per set'::text as metric, distance_km as value, 'km'::text as unit, completed_at
    from extracted
    where sets_completed > 0 and measurement = 'time_distance' and distance_km > 0
  ),
  ranked as (
    select *,
           row_number() over (partition by exercise_id, metric order by value desc, completed_at asc) as rn
    from metrics
    where exercise_name is not null
  )
  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'exerciseId', exercise_id,
        'exerciseName', exercise_name,
        'measurement', measurement,
        'metric', metric,
        'value', value,
        'unit', unit,
        'achievedAt', completed_at
      )
      order by exercise_name, metric
    ),
    '[]'::jsonb
  )
  into v_bests
  from ranked
  where rn = 1;

  return jsonb_build_object(
    'total_completed', coalesce(v_total, 0),
    'bests', coalesce(v_bests, '[]'::jsonb),
    'completed_dates', coalesce(v_dates, '[]'::jsonb)
  );
end;
$$;

create or replace function public.bloom_exercise_personal_bests(p_user_id uuid default null)
returns jsonb language sql stable security invoker set search_path = pg_catalog, pg_temp as $$
  select bloom_private.exercise_personal_bests(p_user_id);
$$;

revoke all on function bloom_private.exercise_personal_bests(uuid), public.bloom_exercise_personal_bests(uuid)
  from public, anon;
grant execute on function bloom_private.exercise_personal_bests(uuid), public.bloom_exercise_personal_bests(uuid)
  to authenticated;

commit;
