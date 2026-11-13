begin;

-- Bloom uses the existing authenticated users and exercise catalog. Its
-- workout and reward records are separate from Nashaat's points system.
create table public.bloom_settings (
  user_id uuid primary key references auth.users(id) on delete cascade,
  credits_enabled boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.bloom_workout_plans (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  title text not null check (char_length(trim(title)) between 1 and 100),
  source text not null default 'manual' check (source in ('manual', 'ai_generated')),
  scheduled_days smallint[] not null default '{}'
    check (scheduled_days <@ array[1,2,3,4,5,6,7]::smallint[]),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index bloom_workout_plans_user_idx on public.bloom_workout_plans(user_id, created_at desc);

create table public.bloom_plan_exercises (
  plan_id uuid not null references public.bloom_workout_plans(id) on delete cascade,
  exercise_id uuid not null references public.exercises(id) on delete restrict,
  position smallint not null check (position between 0 and 49),
  sets smallint not null default 1 check (sets between 1 and 20),
  target_reps smallint check (target_reps between 1 and 1000),
  target_seconds integer check (target_seconds between 1 and 86400),
  target_weight_kg numeric(7,2) check (target_weight_kg between 0 and 1000),
  target_distance_km numeric(7,2) check (target_distance_km > 0 and target_distance_km <= 1000),
  primary key (plan_id, position),
  unique (plan_id, exercise_id),
  check ((target_reps is null) <> (target_seconds is null)),
  check (target_weight_kg is null or target_reps is not null),
  check (target_distance_km is null or target_seconds is not null)
);

-- Session and ledger writes are reserved for a server-side completion flow.
-- The reward conversion policy is still open in the PRD, so this migration
-- intentionally does not invent a rate or grant clients credit-write access.
create table public.bloom_workout_sessions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  plan_id uuid references public.bloom_workout_plans(id) on delete set null,
  plan_snapshot jsonb not null check (jsonb_typeof(plan_snapshot) = 'array'),
  status text not null default 'in_progress' check (status in ('in_progress', 'completed', 'cancelled')),
  started_at timestamptz not null default now(),
  completed_at timestamptz,
  credits_enabled_at_completion boolean,
  exercise_results jsonb not null default '[]'::jsonb
    check (jsonb_typeof(exercise_results) = 'array'),
  check (completed_at is null or completed_at >= started_at),
  check ((status = 'completed') = (completed_at is not null)),
  check ((status = 'completed') = (credits_enabled_at_completion is not null))
);
create index bloom_workout_sessions_user_idx on public.bloom_workout_sessions(user_id, started_at desc);
create unique index bloom_one_active_workout_per_user on public.bloom_workout_sessions(user_id)
  where status = 'in_progress';

create table public.bloom_credit_ledger (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  workout_session_id uuid references public.bloom_workout_sessions(id) on delete restrict,
  amount_minutes integer not null check (amount_minutes <> 0),
  entry_type text not null check (entry_type in ('earned', 'spent', 'expired', 'adjustment')),
  idempotency_key text not null,
  expires_at timestamptz,
  created_at timestamptz not null default now(),
  unique (user_id, idempotency_key),
  check (
    (entry_type = 'earned' and amount_minutes > 0 and expires_at is not null)
    or (entry_type in ('spent', 'expired') and amount_minutes < 0)
    or entry_type = 'adjustment'
  )
);
create unique index bloom_one_earn_per_session on public.bloom_credit_ledger(workout_session_id)
  where entry_type = 'earned' and workout_session_id is not null;
create index bloom_credit_ledger_user_idx on public.bloom_credit_ledger(user_id, created_at desc);

create table public.bloom_blocking_rules (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  platform text not null check (platform in ('ios', 'android', 'macos')),
  target_type text not null check (target_type in ('app', 'website')),
  target_identifier text not null check (char_length(trim(target_identifier)) between 1 and 500),
  enabled boolean not null default true,
  created_at timestamptz not null default now(),
  unique (user_id, platform, target_type, target_identifier)
);

-- Membership is a parent/child relationship and has no age restriction.
-- Trusted server code will create memberships after an invitation is accepted.
create table public.bloom_households (
  id uuid primary key default gen_random_uuid(),
  owner_user_id uuid not null references auth.users(id) on delete cascade,
  name text not null check (char_length(trim(name)) between 1 and 100),
  created_at timestamptz not null default now()
);
create table public.bloom_household_members (
  household_id uuid not null references public.bloom_households(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role text not null check (role in ('parent', 'child')),
  joined_at timestamptz not null default now(),
  primary key (household_id, user_id)
);
create index bloom_household_members_user_idx on public.bloom_household_members(user_id, household_id);

-- Prices and provider product IDs are configuration, not embedded assumptions.
create table public.bloom_subscription_plans (
  id text primary key check (id in ('basic', 'premium')),
  display_name text not null,
  active boolean not null default true
);
insert into public.bloom_subscription_plans(id, display_name) values
  ('basic', 'Basic'), ('premium', 'Premium');

create table public.bloom_subscription_products (
  id uuid primary key default gen_random_uuid(),
  plan_id text not null references public.bloom_subscription_plans(id),
  scope text not null check (scope in ('individual', 'household')),
  billing_period text not null check (billing_period in ('week', 'month', 'year')),
  provider text not null check (char_length(trim(provider)) > 0),
  provider_product_id text not null,
  active boolean not null default false,
  unique (provider, provider_product_id)
);
create table public.bloom_plan_entitlements (
  plan_id text not null references public.bloom_subscription_plans(id) on delete cascade,
  entitlement_key text not null,
  enabled boolean not null default true,
  primary key (plan_id, entitlement_key)
);
create table public.bloom_subscriptions (
  id uuid primary key default gen_random_uuid(),
  payer_user_id uuid not null references auth.users(id) on delete cascade,
  household_id uuid references public.bloom_households(id) on delete cascade,
  product_id uuid not null references public.bloom_subscription_products(id),
  provider_subscription_id text not null,
  status text not null check (status in ('active', 'grace_period', 'paused', 'expired', 'revoked')),
  current_period_start timestamptz,
  current_period_end timestamptz,
  cancel_at_period_end boolean not null default false,
  created_at timestamptz not null default now(),
  check (current_period_end is null or current_period_start is null or current_period_end >= current_period_start),
  unique (product_id, provider_subscription_id)
);
create table public.bloom_billing_events (
  id uuid primary key default gen_random_uuid(),
  provider text not null,
  provider_event_id text not null,
  event_type text not null,
  subscription_id uuid references public.bloom_subscriptions(id) on delete set null,
  received_at timestamptz not null default now(),
  processed_at timestamptz,
  unique (provider, provider_event_id)
);

alter table public.bloom_settings enable row level security;
alter table public.bloom_workout_plans enable row level security;
alter table public.bloom_plan_exercises enable row level security;
alter table public.bloom_workout_sessions enable row level security;
alter table public.bloom_credit_ledger enable row level security;
alter table public.bloom_blocking_rules enable row level security;
alter table public.bloom_households enable row level security;
alter table public.bloom_household_members enable row level security;
alter table public.bloom_subscription_plans enable row level security;
alter table public.bloom_subscription_products enable row level security;
alter table public.bloom_plan_entitlements enable row level security;
alter table public.bloom_subscriptions enable row level security;
alter table public.bloom_billing_events enable row level security;

revoke all on public.bloom_settings, public.bloom_workout_plans, public.bloom_plan_exercises,
  public.bloom_workout_sessions, public.bloom_credit_ledger, public.bloom_blocking_rules,
  public.bloom_households, public.bloom_household_members, public.bloom_subscription_plans,
  public.bloom_subscription_products, public.bloom_plan_entitlements, public.bloom_subscriptions,
  public.bloom_billing_events from public, anon, authenticated;

grant select, insert, update on public.bloom_settings to authenticated;
grant select, insert, update, delete on public.bloom_workout_plans, public.bloom_plan_exercises,
  public.bloom_blocking_rules to authenticated;
grant select on public.bloom_workout_sessions, public.bloom_credit_ledger,
  public.bloom_households, public.bloom_household_members, public.bloom_subscription_plans,
  public.bloom_subscription_products, public.bloom_plan_entitlements to authenticated;
grant select (id, payer_user_id, household_id, product_id, status, current_period_start,
  current_period_end, cancel_at_period_end, created_at) on public.bloom_subscriptions to authenticated;

create policy bloom_settings_select on public.bloom_settings for select to authenticated
  using (user_id = (select auth.uid()));
create policy bloom_settings_insert on public.bloom_settings for insert to authenticated
  with check (user_id = (select auth.uid()));
create policy bloom_settings_update on public.bloom_settings for update to authenticated
  using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));
create policy bloom_plans_own on public.bloom_workout_plans for all to authenticated
  using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));
create policy bloom_plan_exercises_own on public.bloom_plan_exercises for all to authenticated
  using (exists (select 1 from public.bloom_workout_plans p where p.id = plan_id and p.user_id = (select auth.uid())))
  with check (exists (select 1 from public.bloom_workout_plans p where p.id = plan_id and p.user_id = (select auth.uid())));
create policy bloom_sessions_read on public.bloom_workout_sessions for select to authenticated
  using (user_id = (select auth.uid()));
create policy bloom_ledger_read on public.bloom_credit_ledger for select to authenticated
  using (user_id = (select auth.uid()));
create policy bloom_blocking_own on public.bloom_blocking_rules for all to authenticated
  using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));
create policy bloom_members_read_self on public.bloom_household_members for select to authenticated
  using (user_id = (select auth.uid()));
create policy bloom_households_read on public.bloom_households for select to authenticated
  using (owner_user_id = (select auth.uid()) or exists (
    select 1 from public.bloom_household_members m
    where m.household_id = id and m.user_id = (select auth.uid())
  ));
create policy bloom_subscription_plans_read on public.bloom_subscription_plans for select to authenticated
  using (active);
create policy bloom_subscription_products_read on public.bloom_subscription_products for select to authenticated
  using (active);
create policy bloom_plan_entitlements_read on public.bloom_plan_entitlements for select to authenticated
  using (true);
create policy bloom_subscriptions_read on public.bloom_subscriptions for select to authenticated
  using (payer_user_id = (select auth.uid()) or exists (
    select 1 from public.bloom_household_members m
    where m.household_id = bloom_subscriptions.household_id and m.user_id = (select auth.uid())
  ));

-- One call creates a plan and its exercises atomically, under the caller's RLS.
create function public.bloom_create_workout_plan(p_title text, p_exercises jsonb)
returns uuid
language plpgsql
security invoker
set search_path = public, pg_temp
as $$
declare
  v_plan_id uuid;
  v_item jsonb;
  v_position integer := 0;
  v_exercise_id uuid;
  v_measurement text;
  v_sets integer;
  v_target integer;
  v_weight numeric;
  v_distance numeric;
begin
  if (select auth.uid()) is null then
    raise exception 'Sign in to create a workout plan';
  end if;
  if p_title is null or char_length(trim(p_title)) not between 1 and 100 then
    raise exception 'Plan name must be between 1 and 100 characters';
  end if;
  if jsonb_typeof(p_exercises) is distinct from 'array'
    or jsonb_array_length(p_exercises) not between 1 and 50 then
    raise exception 'Choose between 1 and 50 exercises';
  end if;

  insert into public.bloom_workout_plans(user_id, title)
    values ((select auth.uid()), trim(p_title)) returning id into v_plan_id;

  for v_item in select value from jsonb_array_elements(p_exercises) loop
    v_exercise_id := (v_item->>'exercise_id')::uuid;
    v_sets := coalesce((v_item->>'sets')::integer, 1);
    v_target := (v_item->>'target')::integer;
    v_weight := nullif(v_item->>'weight_kg', '')::numeric;
    v_distance := nullif(v_item->>'distance_km', '')::numeric;
    select measurement_type::text into v_measurement from public.exercises
      where id = v_exercise_id and is_system = true;
    if not found then raise exception 'Exercise not found'; end if;
    if v_sets not between 1 and 20 or v_target is null or v_target < 1 then
      raise exception 'Exercise targets must be positive';
    end if;
    if v_weight is not null and (v_measurement <> 'reps_weight' or v_weight < 0 or v_weight > 1000) then
      raise exception 'Invalid weight target';
    end if;
    if v_distance is not null and (v_measurement <> 'time_distance' or v_distance <= 0 or v_distance > 1000) then
      raise exception 'Invalid distance target';
    end if;
    if v_measurement in ('reps_only', 'reps_weight') then
      insert into public.bloom_plan_exercises(plan_id, exercise_id, position, sets, target_reps, target_weight_kg)
        values (v_plan_id, v_exercise_id, v_position, v_sets, v_target, v_weight);
    else
      insert into public.bloom_plan_exercises(plan_id, exercise_id, position, sets, target_seconds, target_distance_km)
        values (v_plan_id, v_exercise_id, v_position, v_sets, v_target, v_distance);
    end if;
    v_position := v_position + 1;
  end loop;
  return v_plan_id;
end;
$$;
revoke all on function public.bloom_create_workout_plan(text, jsonb) from public, anon;
grant execute on function public.bloom_create_workout_plan(text, jsonb) to authenticated;

-- Workout completion uses privileged writes, so the functions that bypass
-- RLS live outside the exposed API schema and check ownership explicitly.
create schema bloom_private;
revoke all on schema bloom_private from public, anon, authenticated;
grant usage on schema bloom_private to authenticated;

create function bloom_private.validate_plan_exercise()
returns trigger
language plpgsql
security invoker
set search_path = pg_catalog, pg_temp
as $$
declare v_measurement text;
begin
  select e.measurement_type::text into v_measurement from public.exercises e
    where e.id = new.exercise_id and e.is_system = true;
  if not found then raise exception 'Exercise not found'; end if;
  if v_measurement in ('reps_only', 'reps_weight') then
    if new.target_reps is null or new.target_seconds is not null or new.target_distance_km is not null
      or (v_measurement = 'reps_only' and new.target_weight_kg is not null) then
      raise exception 'Targets do not match the exercise type';
    end if;
  elsif v_measurement in ('time_only', 'time_distance') then
    if new.target_seconds is null or new.target_reps is not null or new.target_weight_kg is not null
      or (v_measurement = 'time_only' and new.target_distance_km is not null) then
      raise exception 'Targets do not match the exercise type';
    end if;
  else
    raise exception 'Unsupported exercise type';
  end if;
  return new;
end;
$$;
revoke all on function bloom_private.validate_plan_exercise() from public, anon;
grant execute on function bloom_private.validate_plan_exercise() to authenticated;
create trigger bloom_plan_exercise_validate before insert or update on public.bloom_plan_exercises
  for each row execute function bloom_private.validate_plan_exercise();

create function bloom_private.start_workout(p_plan_id uuid)
returns table(session_id uuid, session_started_at timestamptz)
language plpgsql
security definer
set search_path = pg_catalog, pg_temp
as $$
declare
  v_user_id uuid := auth.uid();
  v_session public.bloom_workout_sessions%rowtype;
  v_snapshot jsonb;
begin
  if v_user_id is null then raise exception 'Sign in to start a workout'; end if;

  select * into v_session from public.bloom_workout_sessions s
    where s.user_id = v_user_id and s.status = 'in_progress' for update;
  if found then
    if v_session.plan_id is distinct from p_plan_id then
      raise exception 'Finish or cancel your active workout first';
    end if;
    return query select v_session.id, v_session.started_at;
    return;
  end if;

  perform 1 from public.bloom_workout_plans p
    where p.id = p_plan_id and p.user_id = v_user_id for key share;
  if not found then raise exception 'Workout plan not found'; end if;
  select jsonb_agg(jsonb_build_object(
    'exercise_id', e.id, 'name', e.name, 'measurement_type', e.measurement_type::text,
    'sets', pe.sets, 'target_reps', pe.target_reps, 'target_seconds', pe.target_seconds,
    'target_weight_kg', pe.target_weight_kg, 'target_distance_km', pe.target_distance_km
  ) order by pe.position) into v_snapshot
  from public.bloom_plan_exercises pe join public.exercises e on e.id = pe.exercise_id
  where pe.plan_id = p_plan_id;
  if v_snapshot is null then raise exception 'Add exercises before starting'; end if;

  insert into public.bloom_workout_sessions(user_id, plan_id, plan_snapshot)
    values (v_user_id, p_plan_id, v_snapshot) on conflict do nothing
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

create function bloom_private.complete_workout(p_session_id uuid, p_results jsonb)
returns table(session_id uuid, credits_enabled boolean)
language plpgsql
security definer
set search_path = pg_catalog, pg_temp
as $$
declare
  v_user_id uuid := auth.uid();
  v_session public.bloom_workout_sessions%rowtype;
  v_item jsonb;
  v_planned jsonb;
  v_sanitized jsonb := '[]'::jsonb;
  v_exercise_id uuid;
  v_seen uuid[] := '{}';
  v_sets integer;
  v_value integer;
  v_extra numeric;
  v_enabled boolean;
begin
  if v_user_id is null then raise exception 'Sign in to complete a workout'; end if;
  select * into v_session from public.bloom_workout_sessions s
    where s.id = p_session_id and s.user_id = v_user_id for update;
  if not found then raise exception 'Workout session not found'; end if;
  if v_session.status = 'completed' then
    return query select v_session.id, v_session.credits_enabled_at_completion;
    return;
  end if;
  if v_session.status <> 'in_progress' then raise exception 'Workout was cancelled'; end if;
  if jsonb_typeof(p_results) is distinct from 'array' then
    raise exception 'Workout results must be an array';
  end if;
  if jsonb_array_length(p_results) not between 1 and 50 then
    raise exception 'Log at least one exercise';
  end if;
  for v_item in select value from jsonb_array_elements(p_results) loop
    v_exercise_id := (v_item->>'exercise_id')::uuid;
    if v_exercise_id is null or v_exercise_id = any(v_seen) then
      raise exception 'Each exercise can only be logged once';
    end if;
    v_seen := array_append(v_seen, v_exercise_id);
    select value into v_planned from jsonb_array_elements(v_session.plan_snapshot)
      where value->>'exercise_id' = v_exercise_id::text limit 1;
    if v_planned is null then raise exception 'Exercise is not in this workout'; end if;
    v_sets := (v_item->>'sets_completed')::integer;
    if v_sets is null or v_sets not between 1 and 20 then raise exception 'Enter completed sets'; end if;
    if v_planned->>'measurement_type' in ('reps_only', 'reps_weight') then
      v_value := (v_item->>'reps_completed')::integer;
      if v_value is null or v_value not between 1 and 1000 then raise exception 'Enter completed repetitions'; end if;
      v_extra := nullif(v_item->>'weight_kg', '')::numeric;
      if v_extra is not null and (v_planned->>'measurement_type' <> 'reps_weight' or v_extra < 0 or v_extra > 1000) then
        raise exception 'Invalid completed weight';
      end if;
      v_sanitized := v_sanitized || jsonb_build_array(jsonb_strip_nulls(jsonb_build_object(
        'exercise_id', v_exercise_id, 'sets_completed', v_sets, 'reps_completed', v_value, 'weight_kg', v_extra
      )));
    else
      v_value := (v_item->>'duration_seconds')::integer;
      if v_value is null or v_value not between 1 and 86400 then raise exception 'Enter completed seconds'; end if;
      v_extra := nullif(v_item->>'distance_km', '')::numeric;
      if v_extra is not null and (v_planned->>'measurement_type' <> 'time_distance' or v_extra <= 0 or v_extra > 1000) then
        raise exception 'Invalid completed distance';
      end if;
      v_sanitized := v_sanitized || jsonb_build_array(jsonb_strip_nulls(jsonb_build_object(
        'exercise_id', v_exercise_id, 'sets_completed', v_sets, 'duration_seconds', v_value, 'distance_km', v_extra
      )));
    end if;
  end loop;

  select coalesce((select s.credits_enabled from public.bloom_settings s where s.user_id = v_user_id), true)
    into v_enabled;
  update public.bloom_workout_sessions s set status = 'completed', completed_at = clock_timestamp(),
    exercise_results = v_sanitized, credits_enabled_at_completion = v_enabled
    where s.id = v_session.id;
  return query select v_session.id, v_enabled;
end;
$$;

create function bloom_private.cancel_workout(p_session_id uuid)
returns void
language plpgsql
security definer
set search_path = pg_catalog, pg_temp
as $$
declare
  v_user_id uuid := auth.uid();
  v_status text;
begin
  if v_user_id is null then raise exception 'Sign in to cancel a workout'; end if;
  select s.status into v_status from public.bloom_workout_sessions s
    where s.id = p_session_id and s.user_id = v_user_id for update;
  if not found then raise exception 'Workout session not found'; end if;
  if v_status = 'completed' then raise exception 'Completed workouts cannot be cancelled'; end if;
  update public.bloom_workout_sessions s set status = 'cancelled' where s.id = p_session_id;
end;
$$;

revoke all on function bloom_private.start_workout(uuid),
  bloom_private.complete_workout(uuid, jsonb), bloom_private.cancel_workout(uuid)
  from public, anon;
grant execute on function bloom_private.start_workout(uuid),
  bloom_private.complete_workout(uuid, jsonb), bloom_private.cancel_workout(uuid)
  to authenticated;

create function public.bloom_start_workout(p_plan_id uuid)
returns table(session_id uuid, session_started_at timestamptz)
language sql security invoker set search_path = pg_catalog, pg_temp
as $$ select * from bloom_private.start_workout(p_plan_id); $$;
create function public.bloom_complete_workout(p_session_id uuid, p_results jsonb)
returns table(session_id uuid, credits_enabled boolean)
language sql security invoker set search_path = pg_catalog, pg_temp
as $$ select * from bloom_private.complete_workout(p_session_id, p_results); $$;
create function public.bloom_cancel_workout(p_session_id uuid)
returns void language sql security invoker set search_path = pg_catalog, pg_temp
as $$ select bloom_private.cancel_workout(p_session_id); $$;
revoke all on function public.bloom_start_workout(uuid),
  public.bloom_complete_workout(uuid, jsonb), public.bloom_cancel_workout(uuid)
  from public, anon;
grant execute on function public.bloom_start_workout(uuid),
  public.bloom_complete_workout(uuid, jsonb), public.bloom_cancel_workout(uuid)
  to authenticated;

commit;
