begin;

do $$
declare
  v_week date := ((date_trunc('week', (now() at time zone 'UTC') + interval '1 day') - interval '1 day')::date - 35);
  v_start timestamptz := v_week::timestamp at time zone 'UTC';
  v_parent uuid := '00000000-0000-0000-0000-000000000071';
  v_child uuid := '00000000-0000-0000-0000-000000000072';
  v_household uuid := '70000000-0000-0000-0000-000000000071';
  v_result record;
begin
  if has_function_privilege('anon', 'bloom_private.product_outcomes(date)', 'execute')
    or has_function_privilege('authenticated', 'bloom_private.product_outcomes(date)', 'execute')
    or has_function_privilege('service_role', 'bloom_private.product_outcomes(date)', 'execute') then
    raise exception 'Product outcomes must not be callable by API roles';
  end if;

  insert into auth.users(id) values (v_parent), (v_child);
  insert into public.bloom_settings(user_id, credit_timezone, created_at)
    values (v_parent, 'UTC', v_start + interval '1 hour'), (v_child, 'UTC', v_start + interval '2 hours');
  insert into public.bloom_households(id, owner_user_id, name, created_at)
    values (v_household, v_parent, 'Test household', v_start);
  insert into public.bloom_household_members(household_id, user_id, role, joined_at)
    values (v_household, v_parent, 'parent', v_start), (v_household, v_child, 'child', v_start);
  insert into public.bloom_workout_sessions(user_id, plan_snapshot, status, started_at, completed_at, credits_enabled_at_completion)
    values
      (v_parent, '[]', 'completed', v_start + interval '1 day', v_start + interval '1 day 1 hour', true),
      (v_child, '[]', 'completed', v_start + interval '2 days', v_start + interval '2 days 1 hour', true),
      (v_parent, '[]', 'completed', v_start + interval '22 days', v_start + interval '22 days 1 hour', true);
  insert into public.bloom_credit_ledger(user_id, amount_minutes, entry_type, idempotency_key, expires_at, created_at)
    values
      (v_parent, 60, 'earned', 'report-parent-earned', v_start + interval '6 days', v_start + interval '1 day'),
      (v_parent, -15, 'spent', 'report-parent-spent', v_start + interval '6 days', v_start + interval '2 days'),
      (v_child, 30, 'earned', 'report-child-earned', v_start + interval '6 days', v_start + interval '1 day'),
      (v_child, 10, 'adjustment', 'report-child-adjustment', v_start + interval '6 days', v_start + interval '2 days'),
      (v_child, -5, 'spent', 'report-child-spent', v_start + interval '6 days', v_start + interval '3 days');

  select * into v_result from bloom_private.product_outcomes(v_week) where metric = 'workouts_per_workout_active_user';
  if (v_result.numerator, v_result.denominator, v_result.value) is distinct from (2::numeric, 2::numeric, 1::numeric) then raise exception 'Workout rate incorrect'; end if;
  select * into v_result from bloom_private.product_outcomes(v_week) where metric = 'week_four_workout_retention';
  if (v_result.numerator, v_result.denominator, v_result.value) is distinct from (1::numeric, 2::numeric, 0.5::numeric) then raise exception 'Week-four retention incorrect'; end if;
  select * into v_result from bloom_private.product_outcomes(v_week) where metric = 'first_workout_within_seven_days';
  if (v_result.numerator, v_result.denominator, v_result.value) is distinct from (2::numeric, 2::numeric, 1::numeric) then raise exception 'Activation incorrect'; end if;
  select * into v_result from bloom_private.product_outcomes(v_week) where metric = 'household_workout_participation';
  if (v_result.numerator, v_result.denominator, v_result.value) is distinct from (1::numeric, 1::numeric, 1::numeric) then raise exception 'Household participation incorrect'; end if;
  update public.bloom_household_members set joined_at = v_start + interval '3 days'
    where household_id = v_household and user_id = v_child;
  select * into v_result from bloom_private.product_outcomes(v_week) where metric = 'household_workout_participation';
  if (v_result.numerator, v_result.denominator) is distinct from (0::numeric, 1::numeric) then raise exception 'Pre-membership activity must not count'; end if;
  select * into v_result from bloom_private.product_outcomes(v_week) where metric = 'earned_credit_use';
  if (v_result.numerator, v_result.denominator, v_result.value, v_result.status) is distinct from (15::numeric, 60::numeric, 0.25::numeric, 'partial'::text) then
    raise exception 'Adjusted credit buckets must be excluded';
  end if;
  insert into public.bloom_usage_sessions(user_id, request_id, requested_ms, reserved_ms, started_at, expires_at)
    values (v_parent, '70000000-0000-0000-0000-000000000072', 1000, 1000, v_start + interval '3 days', v_start + interval '6 days');
  select * into v_result from bloom_private.product_outcomes(v_week) where metric = 'earned_credit_use';
  if v_result.status <> 'incomplete' or v_result.value is not null then raise exception 'Unsettled credit buckets must be excluded'; end if;
  if (select count(*) from bloom_private.product_outcomes(v_week) where status = 'not_available' and value is null) <> 3 then
    raise exception 'Missing outcome data must not be reported as zero';
  end if;
  if not exists (select 1 from bloom_private.product_outcomes(v_week + 28) where metric = 'week_four_workout_retention' and status = 'pending' and value is null) then
    raise exception 'Immature cohorts must be marked pending';
  end if;
  begin
    perform bloom_private.product_outcomes(v_week + 1);
    raise exception using errcode = 'P0002', message = 'Non-Sunday week was accepted';
  exception when raise_exception then
    if sqlerrm <> 'Choose a Sunday as the start of the reporting week' then raise; end if;
  end;
end;
$$;

rollback;
