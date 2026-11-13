begin;

-- Rates are unset until the user chooses them. Credits stay enabled by default.
alter table public.bloom_settings
  add column credit_mode text not null default 'easy' check (credit_mode in ('easy', 'hard', 'super_hard')),
  add column credit_timezone text not null default 'UTC',
  add column reps_per_award integer,
  add column rep_award_minutes numeric(10, 2),
  add column exercise_minutes_per_award numeric(10, 2),
  add column time_award_minutes numeric(10, 2),
  add column super_daily_cap_minutes numeric(10, 2),
  add constraint bloom_rep_rate_valid check (
    (reps_per_award is null and rep_award_minutes is null) or
    (reps_per_award is not null and rep_award_minutes is not null and reps_per_award between 1 and 1000000 and rep_award_minutes > 0 and rep_award_minutes <= 10080)
  ),
  add constraint bloom_time_rate_valid check (
    (exercise_minutes_per_award is null and time_award_minutes is null) or
    (exercise_minutes_per_award is not null and time_award_minutes is not null and exercise_minutes_per_award > 0 and exercise_minutes_per_award <= 10080 and time_award_minutes > 0 and time_award_minutes <= 10080)
  ),
  add constraint bloom_daily_cap_valid check (
    (super_daily_cap_minutes is null or (super_daily_cap_minutes > 0 and super_daily_cap_minutes <= 1440))
    and (credit_mode <> 'super_hard' or super_daily_cap_minutes is not null)
  );

-- Keep fractional minutes so short workouts do not lose their earnings.
alter table public.bloom_credit_ledger
  alter column amount_minutes type numeric(16, 4) using amount_minutes::numeric;
alter table public.bloom_workout_sessions
  add column credits_earned_minutes numeric(16, 4) not null default 0
    check (credits_earned_minutes >= 0);

create function bloom_private.validate_credit_timezone()
returns trigger language plpgsql security definer set search_path = pg_catalog, pg_temp as $$
begin
  if not exists (select 1 from pg_catalog.pg_timezone_names t where t.name = new.credit_timezone) then
    raise exception 'Choose a valid time zone';
  end if;
  return new;
end;
$$;
revoke all on function bloom_private.validate_credit_timezone() from public, anon, authenticated;
create trigger bloom_validate_credit_timezone
  before insert or update of credit_timezone on public.bloom_settings
  for each row execute function bloom_private.validate_credit_timezone();

create function bloom_private.credit_week_end(p_time timestamptz, p_timezone text)
returns timestamptz language sql stable security invoker set search_path = pg_catalog, pg_temp as $$
  select (date_trunc('week', (p_time at time zone p_timezone) + interval '1 day')
    + interval '6 days') at time zone p_timezone;
$$;
revoke all on function bloom_private.credit_week_end(timestamptz, text) from public, anon, authenticated;

-- Completion is already serialized and validated by bloom_private.complete_workout.
-- This trigger shares its transaction, so a retry cannot award the same session twice.
create function bloom_private.award_workout_credit()
returns trigger language plpgsql security definer set search_path = pg_catalog, pg_temp as $$
declare
  v_settings public.bloom_settings%rowtype;
  v_item jsonb;
  v_exercise jsonb;
  v_total numeric := 0;
  v_expiry timestamptz;
begin
  if new.credits_enabled_at_completion is not true then return new; end if;
  select * into v_settings from public.bloom_settings s where s.user_id = new.user_id;
  if not found then return new; end if;

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
  if v_total <= 0 then return new; end if;
  v_expiry := bloom_private.credit_week_end(new.completed_at, v_settings.credit_timezone);
  insert into public.bloom_credit_ledger(user_id, workout_session_id, amount_minutes, entry_type, idempotency_key, expires_at)
    values (new.user_id, new.id, v_total, 'earned', 'workout:' || new.id::text, v_expiry);
  update public.bloom_workout_sessions set credits_earned_minutes = v_total where id = new.id;
  return new;
end;
$$;
revoke all on function bloom_private.award_workout_credit() from public, anon, authenticated;
create trigger bloom_award_workout_credit
  after update of status on public.bloom_workout_sessions
  for each row when (old.status = 'in_progress' and new.status = 'completed')
  execute function bloom_private.award_workout_credit();

create function public.bloom_credit_balance()
returns numeric language sql stable security invoker set search_path = pg_catalog, pg_temp as $$
  select coalesce(sum(l.amount_minutes), 0)
  from public.bloom_credit_ledger l
  where l.user_id = auth.uid() and l.expires_at > now();
$$;
revoke all on function public.bloom_credit_balance() from public, anon;
grant execute on function public.bloom_credit_balance() to authenticated;

commit;
