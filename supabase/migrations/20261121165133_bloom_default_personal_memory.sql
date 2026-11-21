begin;

alter table public.bloom_growth_memory add column automatic_default boolean not null default false;

-- Any explicit update turns the default into a preference that must be preserved.
create function bloom_private.mark_memory_preference_explicit()
returns trigger language plpgsql set search_path = pg_catalog, pg_temp as $$
begin
  new.automatic_default := false;
  return new;
end;
$$;
revoke all on function bloom_private.mark_memory_preference_explicit() from public, anon, authenticated;
create trigger bloom_memory_preference_explicit before update on public.bloom_growth_memory
  for each row execute function bloom_private.mark_memory_preference_explicit();

-- This runs after the existing account/profile trigger. Existing profiles and
-- explicit preferences are untouched. Empty domains mean no memory is shared;
-- each AI feature's separate consent and eligibility checks still apply.
create function bloom_private.initialize_personal_memory()
returns trigger language plpgsql security definer set search_path = pg_catalog, pg_temp as $$
declare v_profile uuid;
begin
  select a.profile_id into v_profile from public.bloom_profile_accounts a where a.user_id = new.id;
  if v_profile is not null and not bloom_private.is_child_profile(v_profile) then
    insert into public.bloom_growth_memory(profile_id, enabled, shared_domains, summaries, automatic_default)
      values (v_profile, true, '{}'::text[], '{}'::jsonb, true)
      on conflict (profile_id) do nothing;
  end if;
  return new;
end;
$$;
revoke all on function bloom_private.initialize_personal_memory() from public, anon, authenticated;
create trigger bloom_initialize_personal_memory after insert on auth.users
  for each row execute function bloom_private.initialize_personal_memory();

-- An untouched, empty automatic default is not user activity during account linking.
create or replace function bloom_private.accept_child_account_link(p_token text)
returns uuid language plpgsql security definer set search_path = pg_catalog, pg_temp as $$
declare
  v_user uuid := auth.uid(); v_request bloom_private.child_account_link_requests%rowtype;
  v_own_profile uuid; v_fk record; v_has_data boolean;
begin
  if v_user is null or p_token is null or p_token !~ '^[0-9a-f]{64}$' then raise exception 'Invalid or expired link code'; end if;
  select * into v_request from bloom_private.child_account_link_requests r
    where r.token_hash = sha256(convert_to(p_token, 'UTF8')) for update;
  if not found then raise exception 'Invalid or expired link code'; end if;
  if v_request.accepted_by = v_user and exists (select 1 from public.bloom_profile_accounts a where a.user_id = v_user and a.profile_id = v_request.profile_id) then
    return v_request.profile_id;
  end if;
  if v_request.accepted_at is not null or v_request.expires_at <= clock_timestamp()
    or v_user = v_request.profile_id or not exists (select 1 from public.bloom_household_members m
      where m.household_id = v_request.household_id and m.user_id = v_request.created_by and m.role = 'parent') then
    raise exception 'Invalid or expired link code';
  end if;
  -- Lock the new account and its default profile against concurrent inserts
  -- while proving that linking cannot replace another account's existing data.
  perform 1 from auth.users u where u.id = v_user and u.email is not null and u.email_confirmed_at is not null
    and not coalesce(u.is_anonymous, false) and coalesce(u.raw_app_meta_data->>'bloom_managed_child', '') <> 'true' for update;
  if not found then raise exception 'A verified email account is required'; end if;
  select a.profile_id into v_own_profile from public.bloom_profile_accounts a where a.user_id = v_user for update;
  if v_own_profile is distinct from v_user then raise exception 'Use a new, unlinked account'; end if;
  perform 1 from public.profiles p where p.id = v_user for update;
  perform 1 from public.bloom_profiles p where p.id = v_own_profile for update;
  if (select count(*) from public.bloom_profile_accounts a where a.profile_id = v_own_profile) <> 1 then
    raise exception 'Use a new, unlinked account';
  end if;
  for v_fk in select distinct n.nspname, c.relname, a.attname
    from pg_constraint f join pg_class c on c.oid = f.conrelid join pg_namespace n on n.oid = c.relnamespace
    join pg_attribute a on a.attrelid = c.oid and a.attnum = f.conkey[1]
    where f.contype = 'f' and cardinality(f.conkey) = 1
      and f.confrelid in ('auth.users'::regclass, 'public.profiles'::regclass, 'public.bloom_profiles'::regclass)
      and n.nspname in ('public', 'bloom_private')
      and not (n.nspname = 'public' and c.relname in ('profiles', 'bloom_profile_accounts'))
  loop
    if v_fk.nspname = 'public' and v_fk.relname = 'bloom_growth_memory' and v_fk.attname = 'profile_id' then
      select exists (select 1 from public.bloom_growth_memory m where m.profile_id = v_user and not m.automatic_default)
        into v_has_data;
    else
      execute format('select exists (select 1 from %I.%I where %I = $1)', v_fk.nspname, v_fk.relname, v_fk.attname)
        into v_has_data using v_user;
    end if;
    if v_has_data then raise exception 'Use a new account with no existing activity'; end if;
  end loop;
  update public.bloom_profile_accounts set profile_id = v_request.profile_id where user_id = v_user;
  delete from public.bloom_profiles where id = v_own_profile;
  update bloom_private.child_account_link_requests set accepted_by = v_user, accepted_at = clock_timestamp()
    where token_hash = v_request.token_hash;
  return v_request.profile_id;
end;
$$;

commit;
