begin;

-- Invitation tokens are bearer secrets; only their hashes are stored.
create table bloom_private.household_invites (
  token_hash bytea primary key,
  household_id uuid not null references public.bloom_households(id) on delete cascade,
  created_by uuid not null references auth.users(id) on delete cascade,
  expires_at timestamptz not null,
  accepted_by uuid references auth.users(id) on delete cascade,
  accepted_at timestamptz,
  check ((accepted_by is null) = (accepted_at is null))
);
revoke all on bloom_private.household_invites from public, anon, authenticated;

create function bloom_private.is_household_member(p_household uuid)
returns boolean language sql stable security definer set search_path = pg_catalog, pg_temp as $$
  select exists (select 1 from public.bloom_household_members m
    where m.household_id = p_household and m.user_id = auth.uid());
$$;
create function bloom_private.is_parent_of(p_child uuid)
returns boolean language sql stable security definer set search_path = pg_catalog, pg_temp as $$
  select exists (
    select 1 from public.bloom_household_members p
    join public.bloom_household_members c on c.household_id = p.household_id
    where p.user_id = auth.uid() and p.role = 'parent' and c.user_id = p_child and c.role = 'child'
  );
$$;
revoke all on function bloom_private.is_household_member(uuid), bloom_private.is_parent_of(uuid) from public, anon;
grant execute on function bloom_private.is_household_member(uuid), bloom_private.is_parent_of(uuid) to authenticated;

create policy bloom_members_read_household on public.bloom_household_members for select to authenticated
  using (bloom_private.is_household_member(household_id));
create policy bloom_settings_parent_select on public.bloom_settings for select to authenticated
  using (bloom_private.is_parent_of(user_id));
create policy bloom_settings_parent_update on public.bloom_settings for update to authenticated
  using (bloom_private.is_parent_of(user_id)) with check (bloom_private.is_parent_of(user_id));
create policy bloom_plans_parent on public.bloom_workout_plans for all to authenticated
  using (bloom_private.is_parent_of(user_id)) with check (bloom_private.is_parent_of(user_id));
create policy bloom_plan_exercises_parent on public.bloom_plan_exercises for all to authenticated
  using (exists (select 1 from public.bloom_workout_plans p where p.id = plan_id and bloom_private.is_parent_of(p.user_id)))
  with check (exists (select 1 from public.bloom_workout_plans p where p.id = plan_id and bloom_private.is_parent_of(p.user_id)));
create policy bloom_workouts_parent_read on public.bloom_workout_sessions for select to authenticated
  using (bloom_private.is_parent_of(user_id));
create policy bloom_ledger_parent_read on public.bloom_credit_ledger for select to authenticated
  using (bloom_private.is_parent_of(user_id));
create policy bloom_credit_sessions_parent_read on public.bloom_credit_sessions for select to authenticated
  using (bloom_private.is_parent_of(user_id));
create policy bloom_blocking_parent on public.bloom_blocking_rules for all to authenticated
  using (bloom_private.is_parent_of(user_id)) with check (bloom_private.is_parent_of(user_id));

-- A parent may edit a child's data, but may not move records to another owner.
revoke update on public.bloom_settings, public.bloom_workout_plans, public.bloom_plan_exercises, public.bloom_blocking_rules from authenticated;
grant update (credits_enabled, credit_mode, credit_timezone, reps_per_award, rep_award_minutes,
  exercise_minutes_per_award, time_award_minutes, super_daily_cap_minutes, updated_at) on public.bloom_settings to authenticated;
grant update (title, source, scheduled_days, updated_at) on public.bloom_workout_plans to authenticated;
grant update (exercise_id, position, sets, target_reps, target_seconds, target_weight_kg, target_distance_km) on public.bloom_plan_exercises to authenticated;
grant update (platform, target_type, target_identifier, enabled) on public.bloom_blocking_rules to authenticated;

-- Both the user and an authorized parent use the same atomic plan validation.
create function public.bloom_create_plan_for_user(p_user_id uuid, p_title text, p_exercises jsonb)
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
    select e.measurement_type::text into v_measurement from public.exercises e where e.id = v_exercise and e.is_system = true;
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
revoke all on function public.bloom_create_plan_for_user(uuid, text, jsonb) from public, anon;
grant execute on function public.bloom_create_plan_for_user(uuid, text, jsonb) to authenticated;
create or replace function public.bloom_create_workout_plan(p_title text, p_exercises jsonb)
returns uuid language sql security invoker set search_path = pg_catalog, pg_temp as $$
  select public.bloom_create_plan_for_user(auth.uid(), p_title, p_exercises);
$$;

create function bloom_private.create_household(p_name text)
returns uuid language plpgsql security definer set search_path = pg_catalog, pg_temp as $$
declare v_user uuid := auth.uid(); v_id uuid;
begin
  if v_user is null then raise exception 'Sign in to create a family'; end if;
  if p_name is null or char_length(trim(p_name)) not between 1 and 100 then raise exception 'Enter a family name'; end if;
  insert into public.bloom_households(owner_user_id, name) values (v_user, trim(p_name)) returning id into v_id;
  insert into public.bloom_household_members(household_id, user_id, role) values (v_id, v_user, 'parent');
  return v_id;
end;
$$;

create function bloom_private.create_child_invite(p_household_id uuid)
returns text language plpgsql security definer set search_path = pg_catalog, pg_temp as $$
declare v_user uuid := auth.uid(); v_token text := gen_random_uuid()::text;
begin
  if v_user is null or not exists (select 1 from public.bloom_household_members m
    where m.household_id = p_household_id and m.user_id = v_user and m.role = 'parent') then
    raise exception 'Parent access required';
  end if;
  insert into bloom_private.household_invites(token_hash, household_id, created_by, expires_at)
    values (sha256(convert_to(v_token, 'UTF8')), p_household_id, v_user, clock_timestamp() + interval '24 hours');
  return v_token;
end;
$$;

create function bloom_private.accept_child_invite(p_token text)
returns uuid language plpgsql security definer set search_path = pg_catalog, pg_temp as $$
declare v_user uuid := auth.uid(); v_invite bloom_private.household_invites%rowtype; v_token text := lower(trim(p_token));
begin
  if v_user is null then raise exception 'Sign in to join a family'; end if;
  if v_token is null or v_token !~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then
    raise exception 'Invalid or expired invitation';
  end if;
  select * into v_invite from bloom_private.household_invites i
    where i.token_hash = sha256(convert_to(v_token, 'UTF8')) for update;
  if not found then raise exception 'Invalid or expired invitation'; end if;
  if v_invite.accepted_by = v_user then
    if exists (select 1 from public.bloom_household_members m where m.household_id = v_invite.household_id
      and m.user_id = v_user and m.role = 'child') then return v_invite.household_id; end if;
    raise exception 'Invalid or expired invitation';
  end if;
  if v_invite.accepted_by is not null or v_invite.expires_at <= clock_timestamp() or not exists (
    select 1 from public.bloom_household_members m where m.household_id = v_invite.household_id
      and m.user_id = v_invite.created_by and m.role = 'parent'
  ) then raise exception 'Invalid or expired invitation'; end if;
  if exists (select 1 from public.bloom_household_members m where m.household_id = v_invite.household_id and m.user_id = v_user) then
    raise exception 'You already belong to this family';
  end if;
  insert into public.bloom_household_members(household_id, user_id, role) values (v_invite.household_id, v_user, 'child');
  update bloom_private.household_invites set accepted_by = v_user, accepted_at = clock_timestamp()
    where token_hash = v_invite.token_hash;
  return v_invite.household_id;
end;
$$;

create function bloom_private.leave_or_remove_child(p_household_id uuid, p_child_id uuid)
returns void language plpgsql security definer set search_path = pg_catalog, pg_temp as $$
declare v_user uuid := auth.uid();
begin
  if v_user is null or (v_user <> p_child_id and not exists (
    select 1 from public.bloom_household_members m where m.household_id = p_household_id
      and m.user_id = v_user and m.role = 'parent'
  )) then raise exception 'Family access required'; end if;
  delete from public.bloom_household_members m where m.household_id = p_household_id
    and m.user_id = p_child_id and m.role = 'child';
  if not found then raise exception 'Child membership not found'; end if;
end;
$$;

create function bloom_private.family_members(p_household_id uuid)
returns table(user_id uuid, role text, display_name text)
language sql stable security definer set search_path = pg_catalog, pg_temp as $$
  select m.user_id, m.role, coalesce(nullif(trim(p.first_name), ''), nullif(trim(p.username), ''), 'Family member')
  from public.bloom_household_members m
  left join public.profiles p on p.id = m.user_id
  where m.household_id = p_household_id and bloom_private.is_household_member(p_household_id)
  order by m.joined_at, m.user_id;
$$;

revoke all on function bloom_private.create_household(text), bloom_private.create_child_invite(uuid),
  bloom_private.accept_child_invite(text), bloom_private.leave_or_remove_child(uuid, uuid), bloom_private.family_members(uuid) from public, anon;
grant execute on function bloom_private.create_household(text), bloom_private.create_child_invite(uuid),
  bloom_private.accept_child_invite(text), bloom_private.leave_or_remove_child(uuid, uuid), bloom_private.family_members(uuid) to authenticated;

create function public.bloom_create_household(p_name text) returns uuid language sql security invoker set search_path = pg_catalog, pg_temp
  as $$ select bloom_private.create_household(p_name); $$;
create function public.bloom_create_child_invite(p_household_id uuid) returns text language sql security invoker set search_path = pg_catalog, pg_temp
  as $$ select bloom_private.create_child_invite(p_household_id); $$;
create function public.bloom_accept_child_invite(p_token text) returns uuid language sql security invoker set search_path = pg_catalog, pg_temp
  as $$ select bloom_private.accept_child_invite(p_token); $$;
create function public.bloom_leave_or_remove_child(p_household_id uuid, p_child_id uuid) returns void language sql security invoker set search_path = pg_catalog, pg_temp
  as $$ select bloom_private.leave_or_remove_child(p_household_id, p_child_id); $$;
create function public.bloom_family_members(p_household_id uuid) returns table(user_id uuid, role text, display_name text)
  language sql security invoker set search_path = pg_catalog, pg_temp as $$ select * from bloom_private.family_members(p_household_id); $$;
revoke all on function public.bloom_create_household(text), public.bloom_create_child_invite(uuid),
  public.bloom_accept_child_invite(text), public.bloom_leave_or_remove_child(uuid, uuid), public.bloom_family_members(uuid) from public, anon;
grant execute on function public.bloom_create_household(text), public.bloom_create_child_invite(uuid),
  public.bloom_accept_child_invite(text), public.bloom_leave_or_remove_child(uuid, uuid), public.bloom_family_members(uuid) to authenticated;

commit;
