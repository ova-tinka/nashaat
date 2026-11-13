begin;

create function bloom_private.validate_weekday_schedule()
returns trigger language plpgsql security invoker set search_path = pg_catalog, pg_temp as $$
declare
  v_unique_count integer;
begin
  if new.scheduled_days is null or cardinality(new.scheduled_days) > 7 then
    raise exception 'Choose up to seven workout days';
  end if;
  select count(distinct schedule_day)::integer into v_unique_count
    from unnest(new.scheduled_days) as days(schedule_day);
  if v_unique_count <> cardinality(new.scheduled_days) then
    raise exception 'A workout day can only be selected once';
  end if;
  return new;
end;
$$;
revoke all on function bloom_private.validate_weekday_schedule() from public, anon, authenticated;
create trigger bloom_validate_weekday_schedule
  before insert or update of scheduled_days on public.bloom_workout_plans
  for each row execute function bloom_private.validate_weekday_schedule();

create function public.bloom_create_workout_plan_scheduled(
  p_title text, p_exercises jsonb, p_scheduled_days smallint[]
)
returns uuid language plpgsql security invoker set search_path = public, pg_temp as $$
declare v_plan_id uuid;
begin
  v_plan_id := public.bloom_create_workout_plan(p_title, p_exercises);
  update public.bloom_workout_plans set scheduled_days = coalesce(p_scheduled_days, '{}'::smallint[])
    where id = v_plan_id and user_id = auth.uid();
  if not found then raise exception 'Workout plan not found'; end if;
  return v_plan_id;
end;
$$;

create function public.bloom_create_plan_for_user_scheduled(
  p_user_id uuid, p_title text, p_exercises jsonb, p_scheduled_days smallint[]
)
returns uuid language plpgsql security invoker set search_path = public, pg_temp as $$
declare v_plan_id uuid;
begin
  v_plan_id := public.bloom_create_plan_for_user(p_user_id, p_title, p_exercises);
  update public.bloom_workout_plans set scheduled_days = coalesce(p_scheduled_days, '{}'::smallint[])
    where id = v_plan_id and user_id = p_user_id;
  if not found then raise exception 'Workout plan not found'; end if;
  return v_plan_id;
end;
$$;

create function public.bloom_update_workout_plan_scheduled(
  p_plan_id uuid, p_title text, p_exercises jsonb, p_scheduled_days smallint[]
)
returns uuid language plpgsql security invoker set search_path = public, pg_temp as $$
declare v_plan_id uuid;
begin
  v_plan_id := public.bloom_update_workout_plan(p_plan_id, p_title, p_exercises);
  update public.bloom_workout_plans set scheduled_days = coalesce(p_scheduled_days, '{}'::smallint[])
    where id = v_plan_id and user_id = auth.uid();
  if not found then raise exception 'Workout plan not found'; end if;
  return v_plan_id;
end;
$$;

create function public.bloom_update_plan_for_user_scheduled(
  p_user_id uuid, p_plan_id uuid, p_title text, p_exercises jsonb, p_scheduled_days smallint[]
)
returns uuid language plpgsql security invoker set search_path = public, pg_temp as $$
declare v_plan_id uuid;
begin
  v_plan_id := public.bloom_update_plan_for_user(p_user_id, p_plan_id, p_title, p_exercises);
  update public.bloom_workout_plans set scheduled_days = coalesce(p_scheduled_days, '{}'::smallint[])
    where id = v_plan_id and user_id = p_user_id;
  if not found then raise exception 'Workout plan not found'; end if;
  return v_plan_id;
end;
$$;

revoke all on function public.bloom_create_workout_plan_scheduled(text, jsonb, smallint[]),
  public.bloom_create_plan_for_user_scheduled(uuid, text, jsonb, smallint[]),
  public.bloom_update_workout_plan_scheduled(uuid, text, jsonb, smallint[]),
  public.bloom_update_plan_for_user_scheduled(uuid, uuid, text, jsonb, smallint[])
  from public, anon;
grant execute on function public.bloom_create_workout_plan_scheduled(text, jsonb, smallint[]),
  public.bloom_create_plan_for_user_scheduled(uuid, text, jsonb, smallint[]),
  public.bloom_update_workout_plan_scheduled(uuid, text, jsonb, smallint[]),
  public.bloom_update_plan_for_user_scheduled(uuid, uuid, text, jsonb, smallint[])
  to authenticated;

create function public.bloom_weekly_plan_progress(p_user_id uuid default null)
returns jsonb language plpgsql stable security invoker set search_path = pg_catalog, pg_temp as $$
declare
  v_user_id uuid := coalesce(p_user_id, auth.uid());
  v_timezone text := 'UTC';
  v_local_week_start date;
  v_week_start timestamptz;
  v_week_end timestamptz;
  v_today date;
  v_planned_workouts integer := 0;
  v_completed_planned integer := 0;
  v_scheduled_days integer := 0;
  v_missed_planned integer := 0;
begin
  if auth.uid() is null then raise exception 'Sign in to view weekly plan progress'; end if;
  if v_user_id is null or (v_user_id <> auth.uid() and not bloom_private.is_parent_of(v_user_id)) then
    raise exception 'Family access required';
  end if;

  select s.credit_timezone into v_timezone from public.bloom_settings s where s.user_id = v_user_id;
  v_timezone := coalesce(v_timezone, 'UTC');
  v_local_week_start := (date_trunc('week', (now() at time zone v_timezone) + interval '1 day')
    - interval '1 day')::date;
  v_today := (now() at time zone v_timezone)::date;
  v_week_start := v_local_week_start::timestamp at time zone v_timezone;
  v_week_end := (v_local_week_start + 7)::timestamp at time zone v_timezone;

  with plan_slots as (
    select p.id as plan_id, v_local_week_start + day_offset as planned_date
    from public.bloom_workout_plans p
    cross join generate_series(0, 6) as days(day_offset)
    where p.user_id = v_user_id
      and extract(isodow from (v_local_week_start + day_offset))::smallint = any(p.scheduled_days)
  ), completed_slots as (
    select distinct s.plan_id, (s.completed_at at time zone v_timezone)::date as completed_date
    from public.bloom_workout_sessions s
    where s.user_id = v_user_id and s.status = 'completed'
      and s.completed_at >= v_week_start and s.completed_at < v_week_end and s.plan_id is not null
  )
  select count(*)::integer,
    (count(*) filter (where exists (
      select 1 from completed_slots c where c.plan_id = p.plan_id and c.completed_date = p.planned_date
    )))::integer,
    count(distinct p.planned_date)::integer,
    (count(*) filter (where p.planned_date < v_today and not exists (
      select 1 from completed_slots c where c.plan_id = p.plan_id and c.completed_date = p.planned_date
    )))::integer
    into v_planned_workouts, v_completed_planned, v_scheduled_days, v_missed_planned
  from plan_slots p;

  return jsonb_build_object(
    'planned_workouts', coalesce(v_planned_workouts, 0),
    'completed_planned_workouts', coalesce(v_completed_planned, 0),
    'scheduled_days', coalesce(v_scheduled_days, 0),
    'missed_planned_workouts', coalesce(v_missed_planned, 0),
    'rest_days', case when coalesce(v_planned_workouts, 0) = 0 then 0 else 7 - coalesce(v_scheduled_days, 0) end
  );
end;
$$;
revoke all on function public.bloom_weekly_plan_progress(uuid) from public, anon;
grant execute on function public.bloom_weekly_plan_progress(uuid) to authenticated;

commit;
