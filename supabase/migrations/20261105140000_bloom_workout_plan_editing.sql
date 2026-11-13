begin;

alter table public.bloom_workout_sessions add column plan_title_snapshot text;

create or replace function bloom_private.start_workout(p_plan_id uuid)
returns table(session_id uuid, session_started_at timestamptz)
language plpgsql security definer set search_path = pg_catalog, pg_temp as $$
declare
  v_user_id uuid := auth.uid();
  v_session public.bloom_workout_sessions%rowtype;
  v_plan_title text;
  v_snapshot jsonb;
begin
  if v_user_id is null then raise exception 'Sign in to start a workout'; end if;
  select * into v_session from public.bloom_workout_sessions s
    where s.user_id = v_user_id and s.status = 'in_progress' for update;
  if found then
    if v_session.plan_id is distinct from p_plan_id then raise exception 'Finish or cancel your active workout first'; end if;
    return query select v_session.id, v_session.started_at;
    return;
  end if;

  select p.title into v_plan_title from public.bloom_workout_plans p
    where p.id = p_plan_id and p.user_id = v_user_id for key share;
  if not found then raise exception 'Workout plan not found'; end if;
  select jsonb_agg(jsonb_build_object(
    'exercise_id', e.id, 'name', e.name, 'description', e.description,
    'instructions', coalesce(e.instructions, array[]::text[]), 'media_link', e.media_link,
    'measurement_type', e.measurement_type::text,
    'sets', pe.sets, 'target_reps', pe.target_reps, 'target_seconds', pe.target_seconds,
    'target_weight_kg', pe.target_weight_kg, 'target_distance_km', pe.target_distance_km
  ) order by pe.position) into v_snapshot
  from public.bloom_plan_exercises pe join public.exercises e on e.id = pe.exercise_id
  where pe.plan_id = p_plan_id;
  if v_snapshot is null then raise exception 'Add exercises before starting'; end if;

  insert into public.bloom_workout_sessions(user_id, plan_id, plan_title_snapshot, plan_snapshot)
    values (v_user_id, p_plan_id, v_plan_title, v_snapshot) on conflict do nothing
    returning * into v_session;
  if not found then
    select * into v_session from public.bloom_workout_sessions s
      where s.user_id = v_user_id and s.status = 'in_progress' for update;
    if not found or v_session.plan_id is distinct from p_plan_id then
      raise exception 'Finish or cancel your active workout first';
    end if;
  end if;
  return query select v_session.id, v_session.started_at;
end;
$$;
revoke all on function bloom_private.start_workout(uuid) from public, anon;
grant execute on function bloom_private.start_workout(uuid) to authenticated;

create function bloom_private.update_workout_plan(
  p_user_id uuid, p_plan_id uuid, p_title text, p_exercises jsonb
)
returns uuid language plpgsql security definer set search_path = pg_catalog, pg_temp as $$
declare
  v_item jsonb;
  v_position integer := 0;
  v_exercise_id uuid;
  v_measurement text;
  v_sets integer;
  v_target integer;
  v_weight numeric;
  v_distance numeric;
begin
  if auth.uid() is null or p_user_id is null
    or (p_user_id <> auth.uid() and not bloom_private.is_parent_of(p_user_id)) then
    raise exception 'Family access required';
  end if;
  if p_title is null or char_length(trim(p_title)) not between 1 and 100 then
    raise exception 'Plan name must be between 1 and 100 characters';
  end if;
  if jsonb_typeof(p_exercises) is distinct from 'array'
    or jsonb_array_length(p_exercises) not between 1 and 50 then
    raise exception 'Choose between 1 and 50 exercises';
  end if;

  perform 1 from public.bloom_workout_plans p
    where p.id = p_plan_id and p.user_id = p_user_id for update;
  if not found then raise exception 'Workout plan not found'; end if;
  if exists (select 1 from public.bloom_workout_sessions s
    where s.plan_id = p_plan_id and s.status = 'in_progress') then
    raise exception 'Finish or cancel the active workout before editing this plan';
  end if;

  update public.bloom_workout_plans set title = trim(p_title), updated_at = now()
    where id = p_plan_id and user_id = p_user_id;
  delete from public.bloom_plan_exercises where plan_id = p_plan_id;

  for v_item in select value from jsonb_array_elements(p_exercises) loop
    v_exercise_id := (v_item->>'exercise_id')::uuid;
    v_sets := coalesce((v_item->>'sets')::integer, 1);
    v_target := (v_item->>'target')::integer;
    v_weight := nullif(v_item->>'weight_kg', '')::numeric;
    v_distance := nullif(v_item->>'distance_km', '')::numeric;
    select e.measurement_type::text into v_measurement from public.exercises e
      where e.id = v_exercise_id and e.is_system = true;
    if not found then raise exception 'Exercise not found'; end if;
    if v_sets not between 1 and 20 or v_target is null or v_target < 1
      or (v_measurement in ('reps_only', 'reps_weight') and v_target > 1000)
      or (v_measurement in ('time_only', 'time_distance') and v_target > 86400) then
      raise exception 'Exercise targets must be positive and within the supported range';
    end if;
    if v_weight is not null and (v_measurement <> 'reps_weight' or v_weight < 0 or v_weight > 1000) then
      raise exception 'Invalid weight target';
    end if;
    if v_distance is not null and (v_measurement <> 'time_distance' or v_distance <= 0 or v_distance > 1000) then
      raise exception 'Invalid distance target';
    end if;
    if v_measurement in ('reps_only', 'reps_weight') then
      insert into public.bloom_plan_exercises(plan_id, exercise_id, position, sets, target_reps, target_weight_kg)
        values (p_plan_id, v_exercise_id, v_position, v_sets, v_target, v_weight);
    else
      insert into public.bloom_plan_exercises(plan_id, exercise_id, position, sets, target_seconds, target_distance_km)
        values (p_plan_id, v_exercise_id, v_position, v_sets, v_target, v_distance);
    end if;
    v_position := v_position + 1;
  end loop;
  return p_plan_id;
end;
$$;
revoke all on function bloom_private.update_workout_plan(uuid, uuid, text, jsonb) from public, anon;
grant execute on function bloom_private.update_workout_plan(uuid, uuid, text, jsonb) to authenticated;

create function public.bloom_update_workout_plan(p_plan_id uuid, p_title text, p_exercises jsonb)
returns uuid language sql security invoker set search_path = pg_catalog, pg_temp as $$
  select bloom_private.update_workout_plan(auth.uid(), p_plan_id, p_title, p_exercises);
$$;
create function public.bloom_update_plan_for_user(p_user_id uuid, p_plan_id uuid, p_title text, p_exercises jsonb)
returns uuid language sql security invoker set search_path = pg_catalog, pg_temp as $$
  select bloom_private.update_workout_plan(p_user_id, p_plan_id, p_title, p_exercises);
$$;
revoke all on function public.bloom_update_workout_plan(uuid, text, jsonb),
  public.bloom_update_plan_for_user(uuid, uuid, text, jsonb) from public, anon;
grant execute on function public.bloom_update_workout_plan(uuid, text, jsonb),
  public.bloom_update_plan_for_user(uuid, uuid, text, jsonb) to authenticated;

create or replace function public.bloom_workout_analytics(p_user_id uuid default null)
returns jsonb language plpgsql stable security invoker set search_path = pg_catalog, pg_temp as $$
declare
  v_user_id uuid := coalesce(p_user_id, auth.uid());
  v_timezone text := 'UTC';
  v_workout_target smallint;
  v_credit_target numeric;
  v_week_start timestamptz;
  v_week_end timestamptz;
  v_workouts integer := 0;
  v_active_days integer := 0;
  v_exercise_minutes numeric := 0;
  v_sets integer := 0;
  v_reps integer := 0;
  v_distance numeric := 0;
  v_weight_volume numeric := 0;
  v_credits numeric := 0;
  v_history jsonb := '[]'::jsonb;
begin
  if auth.uid() is null then raise exception 'Sign in to view workout analytics'; end if;
  if v_user_id is null or (v_user_id <> auth.uid() and not bloom_private.is_parent_of(v_user_id)) then
    raise exception 'Family access required';
  end if;

  select s.credit_timezone, s.weekly_workout_target, s.weekly_credit_target_minutes
    into v_timezone, v_workout_target, v_credit_target
    from public.bloom_settings s where s.user_id = v_user_id;
  v_timezone := coalesce(v_timezone, 'UTC');
  v_week_start := (date_trunc('week', (now() at time zone v_timezone) + interval '1 day')
    - interval '1 day') at time zone v_timezone;
  v_week_end := ((v_week_start at time zone v_timezone) + interval '7 days') at time zone v_timezone;

  with completed as (
    select s.id, s.plan_id, s.plan_title_snapshot, s.completed_at, s.credits_earned_minutes, s.exercise_results,
      coalesce(p.title, s.plan_title_snapshot, 'Workout') as plan_title
    from public.bloom_workout_sessions s
    left join public.bloom_workout_plans p on p.id = s.plan_id
    where s.user_id = v_user_id and s.status = 'completed'
      and s.completed_at >= v_week_start - interval '28 days' and s.completed_at < v_week_end
  ), per_session as (
    select c.id, c.plan_title, c.completed_at, c.credits_earned_minutes,
      count(r.item)::integer as exercises_completed,
      coalesce(sum((r.item->>'sets_completed')::numeric), 0)::integer as sets_completed,
      coalesce(sum((r.item->>'sets_completed')::numeric * (r.item->>'reps_completed')::numeric), 0)::integer as reps_completed,
      coalesce(sum((r.item->>'sets_completed')::numeric * (r.item->>'duration_seconds')::numeric), 0)::integer as exercise_seconds,
      coalesce(sum((r.item->>'sets_completed')::numeric * (r.item->>'distance_km')::numeric), 0) as distance_km,
      coalesce(sum((r.item->>'sets_completed')::numeric * (r.item->>'reps_completed')::numeric * (r.item->>'weight_kg')::numeric), 0) as weight_volume_kg
    from completed c
    left join lateral pg_catalog.jsonb_array_elements(c.exercise_results) r(item) on true
    group by c.id, c.plan_title, c.completed_at, c.credits_earned_minutes
  )
  select
    (count(*) filter (where p.completed_at >= v_week_start and p.completed_at < v_week_end))::integer,
    (count(distinct (p.completed_at at time zone v_timezone)::date)
      filter (where p.completed_at >= v_week_start and p.completed_at < v_week_end))::integer,
    coalesce(round(sum(p.exercise_seconds) filter (where p.completed_at >= v_week_start and p.completed_at < v_week_end) / 60.0, 2), 0),
    coalesce(sum(p.sets_completed) filter (where p.completed_at >= v_week_start and p.completed_at < v_week_end), 0)::integer,
    coalesce(sum(p.reps_completed) filter (where p.completed_at >= v_week_start and p.completed_at < v_week_end), 0)::integer,
    coalesce(sum(p.distance_km) filter (where p.completed_at >= v_week_start and p.completed_at < v_week_end), 0),
    coalesce(sum(p.weight_volume_kg) filter (where p.completed_at >= v_week_start and p.completed_at < v_week_end), 0),
    coalesce(sum(p.credits_earned_minutes) filter (where p.completed_at >= v_week_start and p.completed_at < v_week_end), 0),
    coalesce((select jsonb_agg(jsonb_build_object(
      'id', recent.id, 'plan_title', recent.plan_title, 'completed_at', recent.completed_at,
      'credits_earned_minutes', recent.credits_earned_minutes, 'exercises_completed', recent.exercises_completed,
      'sets_completed', recent.sets_completed, 'reps_completed', recent.reps_completed,
      'exercise_seconds', recent.exercise_seconds, 'distance_km', recent.distance_km,
      'weight_volume_kg', recent.weight_volume_kg
    ) order by recent.completed_at desc) from (select * from per_session order by completed_at desc limit 20) recent), '[]'::jsonb)
  into v_workouts, v_active_days, v_exercise_minutes, v_sets, v_reps, v_distance, v_weight_volume, v_credits, v_history
  from per_session p;

  return jsonb_build_object(
    'week_start', v_week_start, 'week_end', v_week_end,
    'weekly_workout_target', v_workout_target, 'weekly_credit_target_minutes', v_credit_target,
    'workouts_completed', coalesce(v_workouts, 0), 'active_days', coalesce(v_active_days, 0),
    'exercise_minutes', coalesce(v_exercise_minutes, 0), 'sets_completed', coalesce(v_sets, 0),
    'reps_completed', coalesce(v_reps, 0), 'distance_km', coalesce(v_distance, 0),
    'weight_volume_kg', coalesce(v_weight_volume, 0), 'credits_earned_minutes', coalesce(v_credits, 0),
    'history', coalesce(v_history, '[]'::jsonb)
  );
end;
$$;
revoke all on function public.bloom_workout_analytics(uuid) from public, anon;
grant execute on function public.bloom_workout_analytics(uuid) to authenticated;

commit;
