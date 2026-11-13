begin;

create table public.bloom_child_profiles (
  profile_id uuid primary key references public.bloom_profiles(id) on delete cascade,
  household_id uuid not null references public.bloom_households(id) on delete cascade,
  display_name text not null check (char_length(trim(display_name)) between 1 and 100),
  created_by uuid references auth.users(id) on delete set null,
  request_id uuid not null,
  created_at timestamptz not null default now(),
  unique (household_id, created_by, request_id)
);
create index bloom_child_profiles_household_idx on public.bloom_child_profiles(household_id, created_at);
alter table public.bloom_child_profiles enable row level security;
revoke all on public.bloom_child_profiles from public, anon, authenticated;
grant select on public.bloom_child_profiles to authenticated;

create function bloom_private.is_household_parent(p_household_id uuid)
returns boolean language sql stable security definer set search_path = pg_catalog, pg_temp as $$
  select auth.uid() is not null and exists (
    select 1 from public.bloom_household_members m
    where m.household_id = p_household_id and m.user_id = auth.uid() and m.role = 'parent'
  );
$$;
revoke all on function bloom_private.is_household_parent(uuid) from public, anon;
grant execute on function bloom_private.is_household_parent(uuid) to authenticated;
create policy bloom_child_profiles_parent_read on public.bloom_child_profiles for select to authenticated
  using (bloom_private.is_household_parent(household_id));
create policy bloom_profiles_parent_read on public.bloom_profiles for select to authenticated
  using (exists (select 1 from public.bloom_child_profiles c where c.profile_id = bloom_profiles.id));

create function bloom_private.create_child_profile(p_household_id uuid, p_name text, p_request_id uuid)
returns uuid language plpgsql security definer set search_path = pg_catalog, pg_temp as $$
declare v_profile_id uuid; v_existing_name text; v_user_id uuid := auth.uid();
begin
  if v_user_id is null or p_household_id is null or p_request_id is null then raise exception 'Parent access required'; end if;
  -- Lock the membership while creating or retrying so authorization cannot change mid-operation.
  perform 1 from public.bloom_household_members m
    where m.household_id = p_household_id and m.user_id = v_user_id and m.role = 'parent' for share;
  if not found then raise exception 'Parent access required'; end if;
  if p_name is null or char_length(trim(p_name)) not between 1 and 100 then raise exception 'Enter a name of up to 100 characters'; end if;
  perform pg_advisory_xact_lock(hashtextextended('bloom-child-profile:' || v_user_id::text || ':' || p_household_id::text || ':' || p_request_id::text, 0));
  select c.profile_id, c.display_name into v_profile_id, v_existing_name
    from public.bloom_child_profiles c where c.household_id = p_household_id and c.created_by = v_user_id and c.request_id = p_request_id;
  if found then
    if v_existing_name <> trim(p_name) then raise exception 'Request was already used with a different name'; end if;
    return v_profile_id;
  end if;
  insert into public.bloom_profiles default values returning id into v_profile_id;
  insert into public.bloom_child_profiles(profile_id, household_id, display_name, created_by, request_id)
    values (v_profile_id, p_household_id, trim(p_name), v_user_id, p_request_id);
  return v_profile_id;
end;
$$;

create function bloom_private.delete_unpaired_child_profile(p_profile_id uuid)
returns void language plpgsql security definer set search_path = pg_catalog, pg_temp as $$
declare v_household uuid;
begin
  if auth.uid() is null then raise exception 'Parent access required'; end if;
  select c.household_id into v_household from public.bloom_child_profiles c
    where c.profile_id = p_profile_id for update;
  if not found then raise exception 'Child profile not found'; end if;
  perform 1 from public.bloom_household_members m
    where m.household_id = v_household and m.user_id = auth.uid() and m.role = 'parent' for share;
  if not found then raise exception 'Child profile not found'; end if;
  -- Any future pairing or account-link operation must lock this profile row too.
  perform 1 from public.bloom_profiles p where p.id = p_profile_id for update;
  if exists (select 1 from public.bloom_profile_accounts a where a.profile_id = p_profile_id) then
    raise exception 'A linked profile cannot be deleted here';
  end if;
  delete from public.bloom_profiles where id = p_profile_id;
end;
$$;
revoke all on function bloom_private.create_child_profile(uuid, text, uuid), bloom_private.delete_unpaired_child_profile(uuid) from public, anon;
grant execute on function bloom_private.create_child_profile(uuid, text, uuid), bloom_private.delete_unpaired_child_profile(uuid) to authenticated;

create function public.bloom_create_child_profile(p_household_id uuid, p_name text, p_request_id uuid)
returns uuid language sql security invoker set search_path = pg_catalog, pg_temp as $$
  select bloom_private.create_child_profile(p_household_id, p_name, p_request_id);
$$;
create function public.bloom_delete_unpaired_child_profile(p_profile_id uuid)
returns void language sql security invoker set search_path = pg_catalog, pg_temp as $$
  select bloom_private.delete_unpaired_child_profile(p_profile_id);
$$;
revoke all on function public.bloom_create_child_profile(uuid, text, uuid), public.bloom_delete_unpaired_child_profile(uuid) from public, anon;
grant execute on function public.bloom_create_child_profile(uuid, text, uuid), public.bloom_delete_unpaired_child_profile(uuid) to authenticated;

commit;
