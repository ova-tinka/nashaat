begin;

-- Existing profiles keep NULL (uncapped until opted in); new profiles default to 120 min/week.
alter table public.bloom_settings
  add column weekly_earning_cap_minutes numeric(10, 2)
  check (weekly_earning_cap_minutes is null or (weekly_earning_cap_minutes > 0 and weekly_earning_cap_minutes <= 10080));

alter table public.bloom_settings
  alter column weekly_earning_cap_minutes set default 120;

create or replace function bloom_private.credit_week_start(p_time timestamptz, p_timezone text)
returns timestamptz language sql stable security invoker set search_path = pg_catalog, pg_temp as $$
  select (date_trunc('week', (p_time at time zone p_timezone) + interval '1 day')
    - interval '1 day') at time zone p_timezone;
$$;
revoke all on function bloom_private.credit_week_start(timestamptz, text) from public, anon, authenticated;

create function bloom_private.save_weekly_earning_cap(p_profile_id uuid, p_weekly_cap_minutes numeric)
returns void language plpgsql security definer set search_path = pg_catalog, pg_temp as $$
declare
  v_actor uuid := bloom_private.current_profile_id();
  v_child boolean;
begin
  if v_actor is null or p_profile_id is null then
    raise exception 'Sign in to update weekly earning limits' using errcode = '42501';
  end if;
  v_child := bloom_private.is_child_profile(p_profile_id);
  if p_profile_id = v_actor then
    if v_child then
      raise exception 'A guardian must update the weekly earning limit for a child profile' using errcode = '42501';
    end if;
  elsif not bloom_private.is_parent_of(p_profile_id) then
    raise exception 'Guardian access required' using errcode = '42501';
  end if;
  if p_weekly_cap_minutes is not null and (p_weekly_cap_minutes <= 0 or p_weekly_cap_minutes > 10080) then
    raise exception 'Weekly earning cap must be between 1 and 10,080 minutes';
  end if;

  update public.bloom_settings
  set weekly_earning_cap_minutes = p_weekly_cap_minutes,
      updated_at = clock_timestamp()
  where user_id = p_profile_id;
  if not found then
    raise exception 'Profile settings not found';
  end if;
end;
$$;

create function public.bloom_save_weekly_earning_cap(p_profile_id uuid, p_weekly_cap_minutes numeric)
returns void language sql security invoker set search_path = pg_catalog, pg_temp as $$
  select bloom_private.save_weekly_earning_cap(p_profile_id, p_weekly_cap_minutes);
$$;

revoke all on function bloom_private.save_weekly_earning_cap(uuid, numeric) from public, anon, authenticated;
grant execute on function bloom_private.save_weekly_earning_cap(uuid, numeric) to authenticated;
revoke all on function public.bloom_save_weekly_earning_cap(uuid, numeric) from public, anon;
grant execute on function public.bloom_save_weekly_earning_cap(uuid, numeric) to authenticated;

create or replace function bloom_private.award_workout_credit()
returns trigger language plpgsql security definer set search_path = pg_catalog, pg_temp as $$
declare
  v_settings public.bloom_settings%rowtype;
  v_item jsonb;
  v_exercise jsonb;
  v_total numeric := 0;
  v_event_time timestamptz;
  v_week_start timestamptz;
  v_expiry timestamptz;
  v_plan_count numeric;
  v_result_count numeric;
  v_planned_sets numeric;
  v_completed_sets numeric;
  v_effort_score numeric := 0;
  v_session_score numeric;
  v_week_earned numeric := 0;
  v_account_week_earned numeric := 0;
begin
  if new.credits_enabled_at_completion is not true then return new; end if;

  -- Serialize all credit-earning awards across all four pillars per profile.
  perform pg_advisory_xact_lock(hashtextextended('bloom-credit-earn:' || new.user_id::text, 0));

  select * into v_settings from public.bloom_settings s where s.user_id = new.user_id for update;
  if not found then return new; end if;

  v_event_time := coalesce(new.completed_at, clock_timestamp());
  v_week_start := bloom_private.credit_week_start(v_event_time, v_settings.credit_timezone);
  v_expiry := bloom_private.credit_week_end(v_event_time, v_settings.credit_timezone);

  if v_settings.earning_strategy = 'goal_analytics' then
    v_plan_count := jsonb_array_length(new.plan_snapshot);
    v_result_count := jsonb_array_length(new.exercise_results);
    select coalesce(sum((item->>'sets')::numeric), 0)
      into v_planned_sets from jsonb_array_elements(new.plan_snapshot) item;
    select coalesce(sum((item->>'sets_completed')::numeric), 0)
      into v_completed_sets from jsonb_array_elements(new.exercise_results) item;

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

    v_session_score := (
      least(1::numeric, v_result_count / nullif(v_plan_count, 0))
      + least(1::numeric, v_completed_sets / nullif(v_planned_sets, 0))
      + least(1::numeric, v_effort_score / nullif(v_plan_count, 0))
    ) / 3;
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
  end if;

  if v_total <= 0 then return new; end if;

  if v_settings.weekly_earning_cap_minutes is not null then
    select coalesce(sum(l.amount_minutes), 0) into v_account_week_earned
      from public.bloom_credit_ledger l
      where l.user_id = new.user_id
        and l.entry_type = 'earned'
        and l.created_at >= v_week_start
        and l.created_at < v_expiry;
    v_total := round(greatest(0, least(v_total, v_settings.weekly_earning_cap_minutes - v_account_week_earned)), 4);
  end if;

  if v_total <= 0 then return new; end if;
  insert into public.bloom_credit_ledger(user_id, workout_session_id, amount_minutes, entry_type, idempotency_key, expires_at, created_at)
    values (new.user_id, new.id, v_total, 'earned', 'workout:' || new.id::text, v_expiry, v_event_time)
    on conflict (user_id, idempotency_key) do nothing;
  update public.bloom_workout_sessions set credits_earned_minutes = v_total where id = new.id;
  return new;
end;
$$;
revoke all on function bloom_private.award_workout_credit() from public, anon, authenticated;

create or replace function bloom_private.award_growth_reward(p_event_id uuid, p_reviewer uuid default null)
returns numeric language plpgsql security definer set search_path = pg_catalog, pg_temp as $$
declare
  v_event public.bloom_growth_reward_events%rowtype;
  v_rule public.bloom_growth_reward_rules%rowtype;
  v_credit public.bloom_settings%rowtype;
  v_event_time timestamptz;
  v_day_start timestamptz;
  v_day_end timestamptz;
  v_week_start timestamptz;
  v_week_end timestamptz;
  v_today_earned numeric := 0;
  v_week_earned numeric := 0;
  v_account_week_earned numeric := 0;
  v_award numeric := 0;
  v_eligible boolean := false;
begin
  select * into v_event from public.bloom_growth_reward_events e where e.id = p_event_id for update;
  if not found or v_event.status <> 'pending' then return coalesce(v_event.awarded_minutes, 0); end if;

  -- Serialize all credit-earning awards across all four pillars per profile.
  perform pg_advisory_xact_lock(hashtextextended('bloom-credit-earn:' || v_event.profile_id::text, 0));

  select * into v_rule from public.bloom_growth_reward_rules r
    where r.profile_id = v_event.profile_id and r.module_id = v_event.module_id for share;
  select * into v_credit from public.bloom_settings s where s.user_id = v_event.profile_id for share;
  if not found or not v_credit.credits_enabled or not coalesce(v_rule.enabled, false)
    or (v_rule.require_parent_approval and p_reviewer is null)
    or (p_reviewer is not null and not v_rule.require_parent_approval) then
    update public.bloom_growth_reward_events set status = 'rejected', reviewed_by = p_reviewer,
      reviewed_at = case when p_reviewer is null then null else clock_timestamp() end where id = p_event_id;
    return 0;
  end if;

  if v_event.source_type = 'session' then
    select s.completed_at into v_event_time from public.bloom_growth_sessions s
      where s.id = v_event.source_id and s.profile_id = v_event.profile_id
        and s.module_id = v_event.module_id and s.status = 'completed'
        and s.duration_seconds >= v_rule.minimum_session_minutes * 60;
    v_eligible := found;
  else
    select i.completed_at into v_event_time from public.bloom_growth_items i
      where i.id = v_event.source_id and i.profile_id = v_event.profile_id
        and i.module_id = v_event.module_id and i.module_id = 'tasks'
        and i.item_type = 'task' and i.state = 'completed';
    v_eligible := found;
  end if;
  if not v_eligible or v_event_time is null then
    update public.bloom_growth_reward_events set status = 'rejected', reviewed_by = p_reviewer,
      reviewed_at = case when p_reviewer is null then null else clock_timestamp() end where id = p_event_id;
    return 0;
  end if;

  v_event_time := least(v_event_time, v_event.created_at);
  v_day_start := date_trunc('day', v_event_time at time zone v_credit.credit_timezone) at time zone v_credit.credit_timezone;
  v_day_end := v_day_start + interval '1 day';
  v_week_start := bloom_private.credit_week_start(v_event_time, v_credit.credit_timezone);
  v_week_end := bloom_private.credit_week_end(v_event_time, v_credit.credit_timezone);
  if v_week_end <= clock_timestamp() then
    update public.bloom_growth_reward_events set status = 'capped', reviewed_by = p_reviewer,
      reviewed_at = case when p_reviewer is null then null else clock_timestamp() end where id = p_event_id;
    return 0;
  end if;

  select coalesce(sum(l.amount_minutes), 0) into v_today_earned from public.bloom_credit_ledger l
    where l.user_id = v_event.profile_id and l.entry_type = 'earned'
      and l.growth_module_id = v_event.module_id and l.created_at >= v_day_start and l.created_at < v_day_end;
  select coalesce(sum(l.amount_minutes), 0) into v_week_earned from public.bloom_credit_ledger l
    where l.user_id = v_event.profile_id and l.entry_type = 'earned'
      and l.growth_module_id = v_event.module_id and l.created_at >= v_week_start and l.created_at < v_week_end;

  v_award := round(greatest(0, least(v_event.requested_minutes, v_rule.reward_minutes,
    v_rule.daily_cap_minutes - v_today_earned, v_rule.weekly_cap_minutes - v_week_earned)), 2);

  if v_credit.weekly_earning_cap_minutes is not null and v_award > 0 then
    select coalesce(sum(l.amount_minutes), 0) into v_account_week_earned
      from public.bloom_credit_ledger l
      where l.user_id = v_event.profile_id
        and l.entry_type = 'earned'
        and l.created_at >= v_week_start
        and l.created_at < v_week_end;
    v_award := round(greatest(0, least(v_award, v_credit.weekly_earning_cap_minutes - v_account_week_earned)), 2);
  end if;

  if v_award <= 0 then
    update public.bloom_growth_reward_events set status = 'capped', reviewed_by = p_reviewer,
      reviewed_at = case when p_reviewer is null then null else clock_timestamp() end where id = p_event_id;
    return 0;
  end if;

  insert into public.bloom_credit_ledger(user_id, amount_minutes, entry_type, idempotency_key, expires_at,
    created_at, growth_module_id, growth_source_type, growth_source_id)
  values (v_event.profile_id, v_award, 'earned',
    'growth:' || v_event.module_id || ':' || v_event.source_type || ':' || v_event.source_id::text,
    v_week_end, v_event_time, v_event.module_id, v_event.source_type, v_event.source_id)
  on conflict (user_id, idempotency_key) do nothing;
  if not found then
    select l.amount_minutes into v_award from public.bloom_credit_ledger l
      where l.user_id = v_event.profile_id and l.idempotency_key =
        'growth:' || v_event.module_id || ':' || v_event.source_type || ':' || v_event.source_id::text;
  end if;
  update public.bloom_growth_reward_events set status = 'awarded', awarded_minutes = v_award,
    reviewed_by = p_reviewer, reviewed_at = case when p_reviewer is null then null else clock_timestamp() end
    where id = p_event_id;
  return v_award;
end;
$$;
revoke all on function bloom_private.award_growth_reward(uuid, uuid) from public, anon, authenticated;

commit;
