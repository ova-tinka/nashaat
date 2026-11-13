begin;

alter table public.exercises add column bloom_owner_user_id uuid references auth.users(id) on delete cascade;
alter table public.exercises add constraint bloom_custom_exercise_owner_check
  check (bloom_owner_user_id is null or is_system = false);
-- Different users may independently choose the same name.
alter table public.exercises drop constraint if exists exercises_name_key;
create unique index bloom_shared_exercise_name on public.exercises(name) where bloom_owner_user_id is null;

alter table public.exercises enable row level security;
drop policy if exists "Exercise catalog is publicly readable" on public.exercises;
create policy bloom_shared_exercise_read on public.exercises for select to anon, authenticated
  using (bloom_owner_user_id is null);
create policy bloom_private_exercise_read on public.exercises for select to authenticated
  using (bloom_owner_user_id = (select auth.uid()) or bloom_private.is_parent_of(bloom_owner_user_id));
revoke insert, update, delete on public.exercises from public, anon, authenticated;

create function bloom_private.create_custom_exercise(p_name text, p_description text, p_measurement text)
returns uuid language plpgsql security definer set search_path = pg_catalog, pg_temp as $$
declare v_id uuid;
begin
  if auth.uid() is null then raise exception 'Sign in to create an exercise'; end if;
  if p_name is null or char_length(trim(p_name)) not between 1 and 100 then
    raise exception 'Enter an exercise name of up to 100 characters';
  end if;
  if char_length(coalesce(p_description, '')) > 1000 then raise exception 'Description is too long'; end if;
  if p_measurement is null or p_measurement not in ('reps_only', 'reps_weight', 'time_only', 'time_distance') then
    raise exception 'Invalid measurement type';
  end if;
  insert into public.exercises(id, name, description, measurement_type, is_system, bloom_owner_user_id)
  values (gen_random_uuid(), trim(p_name), nullif(trim(p_description), ''),
    (jsonb_populate_record(null::public.exercises, jsonb_build_object('measurement_type', p_measurement))).measurement_type,
    false, auth.uid()) returning id into v_id;
  return v_id;
end;
$$;
revoke all on function bloom_private.create_custom_exercise(text, text, text) from public, anon;
grant execute on function bloom_private.create_custom_exercise(text, text, text) to authenticated;
create function public.bloom_create_custom_exercise(p_name text, p_description text, p_measurement text)
returns uuid language sql security invoker set search_path = pg_catalog, pg_temp as $$
  select bloom_private.create_custom_exercise(p_name, p_description, p_measurement);
$$;
revoke all on function public.bloom_create_custom_exercise(text, text, text) from public, anon;
grant execute on function public.bloom_create_custom_exercise(text, text, text) to authenticated;

-- Validate custom exercises against the plan owner, including parent-edited plans.
create or replace function public.bloom_create_plan_for_user(p_user_id uuid, p_title text, p_exercises jsonb)
returns uuid language plpgsql security invoker set search_path = pg_catalog, pg_temp as $$
declare
  v_plan uuid; v_item jsonb; v_position integer := 0; v_exercise uuid; v_measurement text;
  v_sets integer; v_target integer; v_weight numeric; v_distance numeric;
begin
  if auth.uid() is null or p_user_id is null or (p_user_id <> auth.uid() and not bloom_private.is_parent_of(p_user_id)) then
    raise exception 'Family access required';
  end if;
  if p_title is null or char_length(trim(p_title)) not between 1 and 100 then raise exception 'Plan name must be between 1 and 100 characters'; end if;
  if jsonb_typeof(p_exercises) is distinct from 'array' or jsonb_array_length(p_exercises) not between 1 and 50 then
    raise exception 'Choose between 1 and 50 exercises';
  end if;
  insert into public.bloom_workout_plans(user_id, title) values (p_user_id, trim(p_title)) returning id into v_plan;
  for v_item in select value from jsonb_array_elements(p_exercises) loop
    v_exercise := (v_item->>'exercise_id')::uuid;
    v_sets := coalesce((v_item->>'sets')::integer, 1);
    v_target := (v_item->>'target')::integer;
    v_weight := nullif(v_item->>'weight_kg', '')::numeric;
    v_distance := nullif(v_item->>'distance_km', '')::numeric;
    select e.measurement_type::text into v_measurement from public.exercises e where e.id = v_exercise and (e.is_system = true or e.bloom_owner_user_id = p_user_id);
    if not found then raise exception 'Exercise not found'; end if;
    if v_sets not between 1 and 20 or v_target is null or v_target < 1 then raise exception 'Exercise targets must be positive'; end if;
    if v_weight is not null and (v_measurement <> 'reps_weight' or v_weight < 0 or v_weight > 1000) then raise exception 'Invalid weight target'; end if;
    if v_distance is not null and (v_measurement <> 'time_distance' or v_distance <= 0 or v_distance > 1000) then raise exception 'Invalid distance target'; end if;
    if v_measurement in ('reps_only', 'reps_weight') then
      insert into public.bloom_plan_exercises(plan_id, exercise_id, position, sets, target_reps, target_weight_kg)
        values (v_plan, v_exercise, v_position, v_sets, v_target, v_weight);
    else
      insert into public.bloom_plan_exercises(plan_id, exercise_id, position, sets, target_seconds, target_distance_km)
        values (v_plan, v_exercise, v_position, v_sets, v_target, v_distance);
    end if;
    v_position := v_position + 1;
  end loop;
  return v_plan;
end;
$$;

create or replace function bloom_private.update_workout_plan(
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
      where e.id = v_exercise_id and (e.is_system = true or e.bloom_owner_user_id = p_user_id);
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

create or replace function bloom_private.validate_plan_exercise()
returns trigger
language plpgsql
security invoker
set search_path = pg_catalog, pg_temp
as $$
declare v_measurement text;
begin
  select e.measurement_type::text into v_measurement from public.exercises e
    where e.id = new.exercise_id and (e.is_system = true or e.bloom_owner_user_id = (
      select p.user_id from public.bloom_workout_plans p where p.id = new.plan_id
    ));
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

commit;
