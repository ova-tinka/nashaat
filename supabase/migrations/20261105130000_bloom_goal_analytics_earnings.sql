begin;

alter table public.bloom_settings
  add column earning_strategy text not null default 'rates'
    check (earning_strategy in ('rates', 'goal_analytics')),
  add column weekly_workout_target smallint,
  add column weekly_credit_target_minutes numeric(10, 2),
  add constraint bloom_weekly_goal_valid check (
    (weekly_workout_target is null or weekly_workout_target between 1 and 7)
    and (weekly_credit_target_minutes is null or
      (weekly_credit_target_minutes > 0 and weekly_credit_target_minutes <= 10080))
    and (earning_strategy <> 'goal_analytics' or
      (weekly_workout_target is not null and weekly_credit_target_minutes is not null))
  );

-- Settings remain parent-editable, but account ownership cannot be changed.
revoke update on public.bloom_settings from authenticated;
grant update (credits_enabled, credit_mode, credit_timezone, reps_per_award, rep_award_minutes,
  exercise_minutes_per_award, time_award_minutes, super_daily_cap_minutes,
  earning_strategy, weekly_workout_target, weekly_credit_target_minutes, updated_at)
  on public.bloom_settings to authenticated;

create or replace function bloom_private.award_workout_credit()
returns trigger language plpgsql security definer set search_path = pg_catalog, pg_temp as $$
declare
  v_settings public.bloom_settings%rowtype;
  v_item jsonb;
  v_exercise jsonb;
  v_total numeric := 0;
  v_expiry timestamptz;
  v_plan_count numeric;
  v_result_count numeric;
  v_planned_sets numeric;
  v_completed_sets numeric;
  v_effort_score numeric := 0;
  v_session_score numeric;
  v_week_start timestamptz;
  v_week_earned numeric := 0;
begin
  if new.credits_enabled_at_completion is not true then return new; end if;
  select * into v_settings from public.bloom_settings s where s.user_id = new.user_id for update;
  if not found then return new; end if;

  if v_settings.earning_strategy = 'goal_analytics' then
    v_plan_count := jsonb_array_length(new.plan_snapshot);
    v_result_count := jsonb_array_length(new.exercise_results);
    select coalesce(sum((item->>'sets')::numeric), 0)
      into v_planned_sets from jsonb_array_elements(new.plan_snapshot) item;
    select coalesce(sum((item->>'sets_completed')::numeric), 0)
      into v_completed_sets from jsonb_array_elements(new.exercise_results) item;

    -- Each planned exercise contributes one capped outcome ratio. More work than
    -- the plan never earns extra credit through this strategy.
    for v_item in select value from pg_catalog.jsonb_array_elements(new.exercise_results) loop
      select value into v_exercise from pg_catalog.jsonb_array_elements(new.plan_snapshot)
        where value->>'exercise_id' = v_item->>'exercise_id' limit 1;
      if v_exercise->>'measurement_type' in ('reps_only', 'reps_weight') then
        v_effort_score := v_effort_score + least(1::numeric,
          ((v_item->>'sets_completed')::numeric * (v_item->>'reps_completed')::numeric)
          / nullif((v_exercise->>'sets')::numeric * (v_exercise->>'target_reps')::numeric, 0));
      else
        v_effort_score := v_effort_score + least(1::numeric,
          ((v_item->>'sets_completed')::numeric * (v_item->>'duration_seconds')::numeric)
          / nullif((v_exercise->>'sets')::numeric * (v_exercise->>'target_seconds')::numeric, 0));
      end if;
    end loop;

    -- The target sets a weekly pool; the three transparent session measures are
    -- exercise coverage, completed sets, and performed reps/time against plan.
    v_session_score := (
      least(1::numeric, v_result_count / nullif(v_plan_count, 0))
      + least(1::numeric, v_completed_sets / nullif(v_planned_sets, 0))
      + least(1::numeric, v_effort_score / nullif(v_plan_count, 0))
    ) / 3;
    v_week_start := (date_trunc('week',
      (new.completed_at at time zone v_settings.credit_timezone) + interval '1 day')
      - interval '1 day') at time zone v_settings.credit_timezone;
    v_expiry := bloom_private.credit_week_end(new.completed_at, v_settings.credit_timezone);
    select coalesce(sum(l.amount_minutes), 0) into v_week_earned
      from public.bloom_credit_ledger l
      where l.user_id = new.user_id and l.entry_type = 'earned'
        and l.workout_session_id is not null
        and l.created_at >= v_week_start and l.created_at < v_expiry;
    v_total := round(greatest(0, least(
      v_settings.weekly_credit_target_minutes - v_week_earned,
      v_settings.weekly_credit_target_minutes / v_settings.weekly_workout_target * v_session_score
    )), 4);
  else
    for v_item in select value from pg_catalog.jsonb_array_elements(new.exercise_results) loop
      select value into v_exercise from pg_catalog.jsonb_array_elements(new.plan_snapshot)
        where value->>'exercise_id' = v_item->>'exercise_id' limit 1;
      if v_exercise->>'measurement_type' in ('reps_only', 'reps_weight')
         and v_settings.reps_per_award is not null then
        v_total := v_total + (v_item->>'sets_completed')::numeric * (v_item->>'reps_completed')::numeric
          * v_settings.rep_award_minutes / v_settings.reps_per_award;
      elsif v_exercise->>'measurement_type' in ('time_only', 'time_distance')
         and v_settings.exercise_minutes_per_award is not null then
        v_total := v_total + (v_item->>'sets_completed')::numeric * (v_item->>'duration_seconds')::numeric
          * v_settings.time_award_minutes / (v_settings.exercise_minutes_per_award * 60);
      end if;
    end loop;
    v_total := round(v_total, 4);
    v_expiry := bloom_private.credit_week_end(new.completed_at, v_settings.credit_timezone);
  end if;

  if v_total <= 0 then return new; end if;
  insert into public.bloom_credit_ledger(user_id, workout_session_id, amount_minutes, entry_type, idempotency_key, expires_at)
    values (new.user_id, new.id, v_total, 'earned', 'workout:' || new.id::text, v_expiry);
  update public.bloom_workout_sessions set credits_earned_minutes = v_total where id = new.id;
  return new;
end;
$$;
revoke all on function bloom_private.award_workout_credit() from public, anon, authenticated;

create function public.bloom_workout_analytics(p_user_id uuid default null)
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
    select s.id, s.plan_id, s.completed_at, s.credits_earned_minutes, s.exercise_results,
      coalesce(p.title, 'Workout') as plan_title
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
