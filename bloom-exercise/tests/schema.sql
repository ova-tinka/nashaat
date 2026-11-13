-- Run after the Bloom migration in a disposable PostgreSQL database with the
-- Supabase auth roles, auth.uid(), and an exercise catalog. All IDs are test data.
begin;

insert into auth.users(id) values
  ('00000000-0000-0000-0000-000000000001'),
  ('00000000-0000-0000-0000-000000000002'),
  ('00000000-0000-0000-0000-000000000003');
insert into public.exercises(id, name, measurement_type, is_system) values
  ('10000000-0000-0000-0000-000000000001', 'Test repetitions', 'reps_weight', true),
  ('10000000-0000-0000-0000-000000000002', 'Test timer', 'time_distance', true),
  ('10000000-0000-0000-0000-000000000003', 'Test timed exercise', 'time_only', true);
insert into public.bloom_households(id, owner_user_id, name) values
  ('20000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000001', 'Test household');
insert into public.bloom_household_members(household_id, user_id, role) values
  ('20000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000001', 'parent'),
  ('20000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000002', 'child');
insert into public.bloom_subscription_products(id, plan_id, scope, billing_period, provider, provider_product_id, active) values
  ('30000000-0000-0000-0000-000000000001', 'basic', 'household', 'month', 'test', 'test-product', true);
insert into public.bloom_subscriptions(id, payer_user_id, household_id, product_id, provider_subscription_id, status) values
  ('40000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000001', '20000000-0000-0000-0000-000000000001', '30000000-0000-0000-0000-000000000001', 'test-subscription', 'active');

set local role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000001', true);

do $$
declare
  v_plan uuid;
  v_session uuid;
  v_retry uuid;
  v_enabled boolean;
begin
  insert into public.bloom_settings(user_id) values ((select auth.uid()));
  select credits_enabled into v_enabled from public.bloom_settings where user_id = (select auth.uid());
  if v_enabled is distinct from true then raise exception 'Credits must default to enabled'; end if;
  update public.bloom_settings set credits_enabled = false where user_id = (select auth.uid());
  select credits_enabled into v_enabled from public.bloom_settings where user_id = (select auth.uid());
  if v_enabled is distinct from false then raise exception 'Credit setting did not persist'; end if;

  v_plan := public.bloom_create_workout_plan('First plan', '[
    {"exercise_id":"10000000-0000-0000-0000-000000000001","sets":3,"target":10,"weight_kg":12.5},
    {"exercise_id":"10000000-0000-0000-0000-000000000002","sets":1,"target":60,"distance_km":2.5}
  ]'::jsonb);
  perform set_config('bloom.test_plan_id', v_plan::text, true);
  if (select count(*) from public.bloom_plan_exercises where plan_id = v_plan) <> 2 then
    raise exception 'Plan exercises were not created';
  end if;
  if not exists (select 1 from public.bloom_plan_exercises where plan_id = v_plan and target_reps = 10 and target_seconds is null and target_weight_kg = 12.5)
    or not exists (select 1 from public.bloom_plan_exercises where plan_id = v_plan and target_seconds = 60 and target_reps is null and target_distance_km = 2.5) then
    raise exception 'Exercise measurement types were not respected';
  end if;
  begin
    insert into public.bloom_plan_exercises(plan_id, exercise_id, position, sets, target_reps)
      values (v_plan, '10000000-0000-0000-0000-000000000003', 2, 1, 10);
    raise exception using errcode = 'P0002', message = 'Mismatched direct insert was accepted';
  exception when raise_exception then
    if sqlerrm <> 'Targets do not match the exercise type' then raise; end if;
  end;
  select session_id into v_session from public.bloom_start_workout(v_plan);
  select session_id into v_retry from public.bloom_start_workout(v_plan);
  if v_session is distinct from v_retry then raise exception 'Starting a workout was not retry-safe'; end if;
  perform set_config('bloom.test_session_id', v_session::text, true);

  begin
    perform public.bloom_create_workout_plan('Must roll back', '[
      {"exercise_id":"10000000-0000-0000-0000-000000000001","sets":1,"target":10},
      {"exercise_id":"10000000-0000-0000-0000-000000000099","sets":1,"target":10}
    ]'::jsonb);
    raise exception using errcode = 'P0002', message = 'Invalid exercise was accepted';
  exception when raise_exception then
    if sqlerrm <> 'Exercise not found' then raise; end if;
  end;
  if exists (select 1 from public.bloom_workout_plans where title = 'Must roll back') then
    raise exception 'Failed plan was partially saved';
  end if;

  if has_table_privilege('authenticated', 'public.bloom_credit_ledger', 'INSERT')
    or has_table_privilege('authenticated', 'public.bloom_subscriptions', 'INSERT')
    or has_table_privilege('authenticated', 'public.bloom_workout_sessions', 'INSERT')
    or has_column_privilege('authenticated', 'public.bloom_subscriptions', 'provider_subscription_id', 'SELECT') then
    raise exception 'Billing or ledger privileges are too broad';
  end if;
end;
$$;

select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000002', true);
do $$
declare v_count integer;
begin
  if exists (select 1 from public.bloom_workout_plans where id = current_setting('bloom.test_plan_id')::uuid) then
    raise exception 'Another user can read the plan';
  end if;
  delete from public.bloom_workout_plans where id = current_setting('bloom.test_plan_id')::uuid;
  get diagnostics v_count = row_count;
  if v_count <> 0 then raise exception 'Another user can delete the plan'; end if;
  if exists (select 1 from public.bloom_settings where user_id = '00000000-0000-0000-0000-000000000001') then
    raise exception 'Another user can read settings';
  end if;
  begin
    perform 1 from public.bloom_start_workout(current_setting('bloom.test_plan_id')::uuid);
    raise exception using errcode = 'P0002', message = 'Another user started the plan';
  exception when raise_exception then
    if sqlerrm <> 'Workout plan not found' then raise; end if;
  end;
  begin
    perform 1 from public.bloom_complete_workout(current_setting('bloom.test_session_id')::uuid, '[]'::jsonb);
    raise exception using errcode = 'P0002', message = 'Another user completed the session';
  exception when raise_exception then
    if sqlerrm <> 'Workout session not found' then raise; end if;
  end;
  if not exists (select 1 from public.bloom_households where id = '20000000-0000-0000-0000-000000000001')
    or not exists (select 1 from public.bloom_subscriptions where id = '40000000-0000-0000-0000-000000000001') then
    raise exception 'Household member cannot read the household subscription';
  end if;
end;
$$;

select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000001', true);
do $$
declare
  v_session uuid := current_setting('bloom.test_session_id')::uuid;
  v_next uuid;
  v_enabled boolean;
begin
  begin
    perform 1 from public.bloom_complete_workout(v_session, '[
      {"exercise_id":"10000000-0000-0000-0000-000000000002","sets_completed":1,"duration_seconds":0}
    ]'::jsonb);
    raise exception using errcode = 'P0002', message = 'Invalid workout result was accepted';
  exception when raise_exception then
    if sqlerrm <> 'Enter completed seconds' then raise; end if;
  end;
  if not exists (select 1 from public.bloom_workout_sessions where id = v_session and status = 'in_progress') then
    raise exception 'Invalid completion changed the session';
  end if;
  select credits_enabled into v_enabled from public.bloom_complete_workout(v_session, '[
    {"exercise_id":"10000000-0000-0000-0000-000000000001","sets_completed":3,"reps_completed":10,"weight_kg":12.5},
    {"exercise_id":"10000000-0000-0000-0000-000000000002","sets_completed":1,"duration_seconds":60,"distance_km":2.5}
  ]'::jsonb);
  if v_enabled is distinct from false then raise exception 'Credit setting was not captured'; end if;
  select credits_enabled into v_enabled from public.bloom_complete_workout(v_session, '[]'::jsonb);
  if v_enabled is distinct from false then raise exception 'Completion retry changed the result'; end if;
  if (select count(*) from public.bloom_workout_sessions where id = v_session and status = 'completed'
    and (exercise_results->0->>'weight_kg')::numeric = 12.5
    and (exercise_results->1->>'distance_km')::numeric = 2.5) <> 1
    or exists (select 1 from public.bloom_credit_ledger where workout_session_id = v_session) then
    raise exception 'Completion duplicated a session or invented credits';
  end if;
  select session_id into v_next from public.bloom_start_workout(current_setting('bloom.test_plan_id')::uuid);
  if v_next = v_session then raise exception 'A completed session was reused'; end if;
  perform public.bloom_cancel_workout(v_next);
  perform public.bloom_cancel_workout(v_next);
  if not exists (select 1 from public.bloom_workout_sessions where id = v_next and status = 'cancelled') then
    raise exception 'Cancellation did not persist';
  end if;
  update public.bloom_settings set credits_enabled = true where user_id = (select auth.uid());
  select session_id into v_next from public.bloom_start_workout(current_setting('bloom.test_plan_id')::uuid);
  select credits_enabled into v_enabled from public.bloom_complete_workout(v_next, '[
    {"exercise_id":"10000000-0000-0000-0000-000000000001","sets_completed":1,"reps_completed":5}
  ]'::jsonb);
  if v_enabled is distinct from true then raise exception 'Enabled credits were not recorded'; end if;
end;
$$;

select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000003', true);
do $$
begin
  if exists (select 1 from public.bloom_households where id = '20000000-0000-0000-0000-000000000001')
    or exists (select 1 from public.bloom_subscriptions where id = '40000000-0000-0000-0000-000000000001') then
    raise exception 'A nonmember can read the household subscription';
  end if;
end;
$$;

rollback;
