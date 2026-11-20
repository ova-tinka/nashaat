begin;

-- Child access is opt-in by module, and only modules enabled by the server can
-- be assigned. Update module_is_available when a module is ready to ship.
create table public.bloom_child_module_assignments (
  profile_id uuid not null references public.bloom_profiles(id) on delete cascade,
  module_id text not null check (module_id in ('exercise', 'study', 'read', 'tasks')),
  assigned boolean not null,
  updated_by uuid references public.bloom_profiles(id) on delete set null,
  updated_at timestamptz not null default clock_timestamp(),
  primary key (profile_id, module_id)
);

alter table public.bloom_child_module_assignments enable row level security;
revoke all on public.bloom_child_module_assignments from public, anon, authenticated;

create function bloom_private.module_is_available(p_module_id text)
returns boolean language sql immutable security definer set search_path = pg_catalog, pg_temp as $$
  select p_module_id = 'exercise';
$$;
revoke all on function bloom_private.module_is_available(text) from public, anon, authenticated;

create function bloom_private.has_module_access(p_profile_id uuid, p_module_id text)
returns boolean language plpgsql stable security definer set search_path = pg_catalog, pg_temp as $$
declare v_current uuid := bloom_private.current_profile_id();
begin
  if v_current is null or p_profile_id is null or p_module_id is null
    or p_module_id not in ('exercise', 'study', 'read', 'tasks')
    or not bloom_private.module_is_available(p_module_id) then return false; end if;
  if p_profile_id <> v_current and not bloom_private.is_parent_of(p_profile_id) then return false; end if;
  if not bloom_private.is_child_profile(p_profile_id) then return true; end if;
  return exists (
    select 1 from public.bloom_child_module_assignments a
    where a.profile_id = p_profile_id and a.module_id = p_module_id and a.assigned
  );
end;
$$;
revoke all on function bloom_private.has_module_access(uuid, text) from public, anon;
grant execute on function bloom_private.has_module_access(uuid, text) to authenticated;

create function bloom_private.list_my_module_assignments()
returns table(module_id text) language sql stable security definer set search_path = pg_catalog, pg_temp as $$
  select a.module_id from public.bloom_child_module_assignments a
  where a.profile_id = bloom_private.current_profile_id() and a.assigned
    and bloom_private.module_is_available(a.module_id)
  order by a.module_id;
$$;

create function bloom_private.list_child_module_assignments(p_child_profile_id uuid)
returns table(module_id text, assigned boolean, updated_by uuid, updated_at timestamptz)
language plpgsql stable security definer set search_path = pg_catalog, pg_temp as $$
declare v_household uuid; v_parent uuid := bloom_private.current_profile_id();
begin
  if v_parent is null or p_child_profile_id is null then raise exception 'Sign in to manage module access'; end if;
  select coalesce(
    (select c.household_id from public.bloom_child_profiles c where c.profile_id = p_child_profile_id),
    (select m.household_id from public.bloom_household_members m where m.user_id = p_child_profile_id and m.role = 'child' limit 1)
  ) into v_household;
  if v_household is null or not exists (
    select 1 from public.bloom_household_members m
    where m.household_id = v_household and m.user_id = v_parent and m.role = 'parent'
  ) then raise exception 'Parent access required'; end if;

  return query
    select modules.module_id, coalesce(a.assigned, false) and bloom_private.module_is_available(modules.module_id), a.updated_by, a.updated_at
    from unnest(array['exercise', 'study', 'read', 'tasks']::text[]) as modules(module_id)
    left join public.bloom_child_module_assignments a
      on a.profile_id = p_child_profile_id and a.module_id = modules.module_id
    order by array_position(array['exercise', 'study', 'read', 'tasks']::text[], modules.module_id);
end;
$$;

create function bloom_private.set_child_module_assignments(p_child_profile_id uuid, p_module_ids text[])
returns table(module_id text, assigned boolean, updated_by uuid, updated_at timestamptz)
language plpgsql security definer set search_path = pg_catalog, pg_temp as $$
declare v_household uuid; v_parent uuid := bloom_private.current_profile_id();
begin
  if v_parent is null or p_child_profile_id is null then raise exception 'Sign in to manage module access'; end if;
  if p_module_ids is null or cardinality(p_module_ids) > 4
    or exists (select 1 from unnest(p_module_ids) as supplied(id)
      where supplied.id is null or supplied.id not in ('exercise', 'study', 'read', 'tasks'))
    or cardinality(p_module_ids) <> (select count(distinct supplied.id) from unnest(p_module_ids) as supplied(id)) then
    raise exception 'Choose each supported module no more than once';
  end if;
  if exists (select 1 from unnest(p_module_ids) as supplied(id)
    where not bloom_private.module_is_available(supplied.id)) then
    raise exception 'A selected module is not available for assignment';
  end if;

  select c.household_id into v_household from public.bloom_child_profiles c
  where c.profile_id = p_child_profile_id for update;
  if not found then
    select m.household_id into v_household from public.bloom_household_members m
    where m.user_id = p_child_profile_id and m.role = 'child' for update;
  else
    perform 1 from public.bloom_household_members m
    where m.household_id = v_household and m.user_id = p_child_profile_id and m.role = 'child' for share;
  end if;
  if v_household is null then raise exception 'Parent access required'; end if;
  perform 1 from public.bloom_household_members m
    where m.household_id = v_household and m.user_id = v_parent and m.role = 'parent' for share;
  if not found then raise exception 'Parent access required'; end if;

  insert into public.bloom_child_module_assignments as a (profile_id, module_id, assigned, updated_by, updated_at)
  select p_child_profile_id, modules.module_id, modules.module_id = any(p_module_ids), v_parent, clock_timestamp()
  from unnest(array['exercise', 'study', 'read', 'tasks']::text[]) as modules(module_id)
  on conflict on constraint bloom_child_module_assignments_pkey do update set
    assigned = excluded.assigned,
    updated_by = excluded.updated_by,
    updated_at = excluded.updated_at
  where a.assigned is distinct from excluded.assigned or a.updated_by is distinct from excluded.updated_by;

  return query select * from bloom_private.list_child_module_assignments(p_child_profile_id);
end;
$$;

create function public.bloom_my_module_assignments()
returns table(module_id text) language sql security invoker set search_path = pg_catalog, pg_temp as $$
  select * from bloom_private.list_my_module_assignments();
$$;

create function public.bloom_child_module_assignments(p_child_profile_id uuid)
returns table(module_id text, assigned boolean, updated_by uuid, updated_at timestamptz)
language sql security invoker set search_path = pg_catalog, pg_temp as $$
  select * from bloom_private.list_child_module_assignments(p_child_profile_id);
$$;

create function public.bloom_set_child_module_assignments(p_child_profile_id uuid, p_module_ids text[])
returns table(module_id text, assigned boolean, updated_by uuid, updated_at timestamptz)
language sql security invoker set search_path = pg_catalog, pg_temp as $$
  select * from bloom_private.set_child_module_assignments(p_child_profile_id, p_module_ids);
$$;

revoke all on function bloom_private.list_my_module_assignments(),
  bloom_private.list_child_module_assignments(uuid), bloom_private.set_child_module_assignments(uuid, text[])
  from public, anon;
grant execute on function bloom_private.list_my_module_assignments(),
  bloom_private.list_child_module_assignments(uuid), bloom_private.set_child_module_assignments(uuid, text[])
  to authenticated;
revoke all on function public.bloom_my_module_assignments(),
  public.bloom_child_module_assignments(uuid), public.bloom_set_child_module_assignments(uuid, text[])
  from public, anon;
grant execute on function public.bloom_my_module_assignments(),
  public.bloom_child_module_assignments(uuid), public.bloom_set_child_module_assignments(uuid, text[])
  to authenticated;

-- The legacy personal wrapper passed auth.uid(), which can differ from the
-- active Bloom profile after account linking. Resolve the active profile here.
create or replace function public.bloom_create_workout_plan(p_title text, p_exercises jsonb)
returns uuid language plpgsql security invoker set search_path = pg_catalog, pg_temp as $$
declare v_profile uuid := bloom_private.current_profile_id();
begin
  if v_profile is null then raise exception 'Sign in to create a workout plan'; end if;
  return public.bloom_create_plan_for_user(v_profile, p_title, p_exercises);
end;
$$;

create function bloom_private.revoke_child_module_assignments_after_unlink()
returns trigger language plpgsql security definer set search_path = pg_catalog, pg_temp as $$
begin
  if old.role = 'child' then
    update public.bloom_child_module_assignments set assigned = false, updated_by = null, updated_at = clock_timestamp()
    where profile_id = old.user_id and (assigned or updated_by is not null);
  end if;
  return old;
end;
$$;
revoke all on function bloom_private.revoke_child_module_assignments_after_unlink() from public, anon, authenticated;
create trigger bloom_revoke_child_modules_after_unlink
  after delete on public.bloom_household_members
  for each row execute function bloom_private.revoke_child_module_assignments_after_unlink();

create function bloom_private.guard_unassigned_child_workout_session()
returns trigger language plpgsql security definer set search_path = pg_catalog, pg_temp as $$
begin
  if new.user_id = bloom_private.current_profile_id()
    and bloom_private.is_child_profile(new.user_id)
    and not bloom_private.has_module_access(new.user_id, 'exercise') then
    raise exception 'Your guardian must assign Exercise before a workout can start' using errcode = '42501';
  end if;
  return new;
end;
$$;
revoke all on function bloom_private.guard_unassigned_child_workout_session() from public, anon, authenticated;
create trigger bloom_require_exercise_assignment_for_workout
  before insert on public.bloom_workout_sessions
  for each row execute function bloom_private.guard_unassigned_child_workout_session();

drop policy bloom_plans_own on public.bloom_workout_plans;
create policy bloom_plans_own on public.bloom_workout_plans for all to authenticated
  using (user_id = (select bloom_private.current_profile_id())
    and bloom_private.has_module_access(user_id, 'exercise'))
  with check (user_id = (select bloom_private.current_profile_id())
    and bloom_private.has_module_access(user_id, 'exercise'));

drop policy bloom_plan_exercises_own on public.bloom_plan_exercises;
create policy bloom_plan_exercises_own on public.bloom_plan_exercises for all to authenticated
  using (exists (select 1 from public.bloom_workout_plans p
    where p.id = plan_id and p.user_id = (select bloom_private.current_profile_id())
      and bloom_private.has_module_access(p.user_id, 'exercise')))
  with check (exists (select 1 from public.bloom_workout_plans p
    where p.id = plan_id and p.user_id = (select bloom_private.current_profile_id())
      and bloom_private.has_module_access(p.user_id, 'exercise')));

drop policy bloom_sessions_read on public.bloom_workout_sessions;
create policy bloom_sessions_read on public.bloom_workout_sessions for select to authenticated
  using (user_id = (select bloom_private.current_profile_id()));

commit;
