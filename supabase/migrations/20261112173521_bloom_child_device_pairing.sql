begin;

-- Auth may populate admin app metadata after inserting auth.users. The trigger
-- therefore uses this short-lived authorization rather than user metadata.
create table bloom_private.child_provisioning_grants (
  profile_id uuid primary key references public.bloom_child_profiles(profile_id) on delete cascade,
  parent_user_id uuid not null references auth.users(id) on delete cascade,
  expires_at timestamptz not null
);
revoke all on bloom_private.child_provisioning_grants from public, anon, authenticated;

-- A managed profile is provisioned with the same Auth ID, so existing Bloom
-- workout and credit ownership checks continue to apply unchanged.
create or replace function bloom_private.create_profile_for_new_account()
returns trigger language plpgsql security definer set search_path = pg_catalog, pg_temp as $$
declare v_household uuid; v_parent uuid; v_child boolean := false;
begin
  select c.household_id into v_household from public.bloom_child_profiles c where c.profile_id = new.id for update;
  if found then
    select g.parent_user_id into v_parent from bloom_private.child_provisioning_grants g
      where g.profile_id = new.id and g.expires_at > clock_timestamp() for update;
    if not found then raise exception 'Provisioning authorization required'; end if;
    perform 1 from public.bloom_household_members m
      where m.household_id = v_household and m.user_id = v_parent and m.role = 'parent' for share;
    if not found then raise exception 'Parent access required'; end if;
    v_child := true;
  end if;
  if not v_child then insert into public.bloom_profiles(id) values (new.id); end if;
  insert into public.bloom_profile_accounts(user_id, profile_id) values (new.id, new.id);
  if v_child then
    insert into public.bloom_household_members(household_id, user_id, role) values (v_household, new.id, 'child');
    insert into public.bloom_settings(user_id) values (new.id) on conflict (user_id) do nothing;
    delete from bloom_private.child_provisioning_grants where profile_id = new.id;
  end if;
  return new;
end;
$$;

create function bloom_private.is_managed_child()
returns boolean language sql stable security definer set search_path = pg_catalog, pg_temp as $$
  select auth.uid() is not null and exists (select 1 from public.bloom_child_profiles c where c.profile_id = auth.uid());
$$;
revoke all on function bloom_private.is_managed_child() from public, anon;
grant execute on function bloom_private.is_managed_child() to authenticated;
drop policy bloom_settings_update on public.bloom_settings;
create policy bloom_settings_update on public.bloom_settings for update to authenticated
  using (user_id = (select auth.uid()) and not bloom_private.is_managed_child())
  with check (user_id = (select auth.uid()) and not bloom_private.is_managed_child());

-- A managed child cannot escape parent controls by leaving the family.
create or replace function bloom_private.leave_or_remove_child(p_household_id uuid, p_child_id uuid)
returns void language plpgsql security definer set search_path = pg_catalog, pg_temp as $$
declare v_user uuid := auth.uid();
begin
  if v_user is null or (v_user <> p_child_id and not exists (
    select 1 from public.bloom_household_members m where m.household_id = p_household_id
      and m.user_id = v_user and m.role = 'parent'
  )) then raise exception 'Family access required'; end if;
  if exists (select 1 from public.bloom_child_profiles c where c.profile_id = p_child_id and c.household_id = p_household_id) then
    raise exception 'Managed child profiles cannot leave the family here';
  end if;
  delete from public.bloom_household_members m where m.household_id = p_household_id
    and m.user_id = p_child_id and m.role = 'child';
  if not found then raise exception 'Child membership not found'; end if;
end;
$$;

create table bloom_private.child_pairing_codes (
  token_hash bytea primary key,
  profile_id uuid not null references public.bloom_child_profiles(profile_id) on delete cascade,
  household_id uuid not null references public.bloom_households(id) on delete cascade,
  created_by uuid not null references auth.users(id) on delete cascade,
  expires_at timestamptz not null,
  consumed_at timestamptz
);
revoke all on bloom_private.child_pairing_codes from public, anon, authenticated;

create function bloom_private.authorize_child_provisioning(p_profile_id uuid)
returns uuid language plpgsql security definer set search_path = pg_catalog, pg_temp as $$
declare v_household uuid;
begin
  if auth.uid() is null then raise exception 'Parent access required'; end if;
  select c.household_id into v_household from public.bloom_child_profiles c where c.profile_id = p_profile_id for update;
  if not found then raise exception 'Child profile not found'; end if;
  perform 1 from public.bloom_household_members m where m.household_id = v_household
    and m.user_id = auth.uid() and m.role = 'parent' for share;
  if not found then raise exception 'Child profile not found'; end if;
  if not exists (select 1 from auth.users u where u.id = p_profile_id) then
    insert into bloom_private.child_provisioning_grants(profile_id, parent_user_id, expires_at)
      values (p_profile_id, auth.uid(), clock_timestamp() + interval '5 minutes')
      on conflict (profile_id) do update set parent_user_id = excluded.parent_user_id, expires_at = excluded.expires_at;
  end if;
  return p_profile_id;
end;
$$;
create function public.bloom_authorize_child_provisioning(p_profile_id uuid)
returns uuid language sql security invoker set search_path = pg_catalog, pg_temp as $$
  select bloom_private.authorize_child_provisioning(p_profile_id);
$$;

create function bloom_private.create_child_pairing_code(p_profile_id uuid)
returns text language plpgsql security definer set search_path = pg_catalog, pg_temp as $$
declare v_household uuid; v_token text;
begin
  perform bloom_private.authorize_child_provisioning(p_profile_id);
  select c.household_id into v_household from public.bloom_child_profiles c where c.profile_id = p_profile_id for update;
  if not exists (select 1 from auth.users u join public.bloom_profile_accounts a on a.user_id = u.id
    join public.bloom_household_members m on m.user_id = u.id and m.household_id = v_household and m.role = 'child'
    where u.id = p_profile_id and a.profile_id = p_profile_id
      and u.raw_app_meta_data->>'bloom_managed_child' = 'true'
      and u.raw_app_meta_data->>'bloom_profile_id' = p_profile_id::text) then
    raise exception 'Child identity is not ready';
  end if;
  update bloom_private.child_pairing_codes set consumed_at = clock_timestamp()
    where profile_id = p_profile_id and consumed_at is null;
  v_token := replace(gen_random_uuid()::text, '-', '') || replace(gen_random_uuid()::text, '-', '');
  insert into bloom_private.child_pairing_codes(token_hash, profile_id, household_id, created_by, expires_at)
    values (sha256(convert_to(v_token, 'UTF8')), p_profile_id, v_household, auth.uid(), clock_timestamp() + interval '10 minutes');
  return v_token;
end;
$$;
create function public.bloom_create_child_pairing_code(p_profile_id uuid)
returns text language sql security invoker set search_path = pg_catalog, pg_temp as $$
  select bloom_private.create_child_pairing_code(p_profile_id);
$$;

-- This endpoint accepts only a SHA-256 digest and is callable only by the Edge
-- service. The bearer code is consumed before any child session is issued.
create function bloom_private.consume_child_pairing_code(p_hash text)
returns uuid language plpgsql security definer set search_path = pg_catalog, pg_temp as $$
declare v_code bloom_private.child_pairing_codes%rowtype;
begin
  if p_hash is null or p_hash !~ '^[0-9a-f]{64}$' then raise exception 'Invalid or expired pairing code'; end if;
  select * into v_code from bloom_private.child_pairing_codes c where c.token_hash = decode(p_hash, 'hex') for update;
  if not found or v_code.consumed_at is not null or v_code.expires_at <= clock_timestamp()
    or not exists (select 1 from public.bloom_household_members m where m.household_id = v_code.household_id
      and m.user_id = v_code.created_by and m.role = 'parent')
    or not exists (select 1 from public.bloom_child_profiles c join auth.users u on u.id = c.profile_id
      join public.bloom_profile_accounts a on a.user_id = u.id and a.profile_id = c.profile_id
      join public.bloom_household_members m on m.user_id = c.profile_id and m.household_id = c.household_id and m.role = 'child'
      where c.profile_id = v_code.profile_id and c.household_id = v_code.household_id
        and u.raw_app_meta_data->>'bloom_managed_child' = 'true' and u.raw_app_meta_data->>'bloom_profile_id' = c.profile_id::text)
    then raise exception 'Invalid or expired pairing code'; end if;
  update bloom_private.child_pairing_codes set consumed_at = clock_timestamp() where token_hash = v_code.token_hash;
  return v_code.profile_id;
end;
$$;
create function public.bloom_consume_child_pairing_code(p_hash text)
returns uuid language sql security invoker set search_path = pg_catalog, pg_temp as $$
  select bloom_private.consume_child_pairing_code(p_hash);
$$;

revoke all on function bloom_private.authorize_child_provisioning(uuid), bloom_private.create_child_pairing_code(uuid),
  public.bloom_authorize_child_provisioning(uuid), public.bloom_create_child_pairing_code(uuid) from public, anon;
grant execute on function bloom_private.authorize_child_provisioning(uuid), bloom_private.create_child_pairing_code(uuid),
  public.bloom_authorize_child_provisioning(uuid), public.bloom_create_child_pairing_code(uuid) to authenticated;
revoke all on function bloom_private.consume_child_pairing_code(text), public.bloom_consume_child_pairing_code(text)
  from public, anon, authenticated;
grant usage on schema bloom_private to service_role;
grant execute on function bloom_private.consume_child_pairing_code(text), public.bloom_consume_child_pairing_code(text) to service_role;

commit;
