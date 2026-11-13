begin;

-- Authentication identifies an account; ownership is always the linked Bloom
-- profile. Existing accounts were backfilled with identical IDs.
create function bloom_private.current_profile_id()
returns uuid language sql stable security definer set search_path = pg_catalog, pg_temp as $$
  select a.profile_id from public.bloom_profile_accounts a where a.user_id = auth.uid();
$$;
revoke all on function bloom_private.current_profile_id() from public, anon;
grant execute on function bloom_private.current_profile_id() to authenticated;

create function public.bloom_current_profile()
returns jsonb language plpgsql stable security invoker set search_path = pg_catalog, pg_temp as $$
declare v_profile uuid := bloom_private.current_profile_id();
begin
  if auth.uid() is null or v_profile is null then raise exception 'Profile unavailable'; end if;
  return jsonb_build_object('profile_id', v_profile, 'managed_child', bloom_private.is_managed_child());
end;
$$;
revoke all on function public.bloom_current_profile() from public, anon;
grant execute on function public.bloom_current_profile() to authenticated;

-- Preserve the existing implementations, privileges, and validation while
-- resolving profile ownership instead of treating every sign-in as a profile.
-- The explicit allowlist prevents changes to unrelated installed functions.
do $$
declare
  v_private text[] := array['accept_child_invite','authorize_child_provisioning','cancel_workout','complete_workout',
    'create_child_invite','create_child_pairing_code','create_child_profile','create_custom_exercise','create_household',
    'delete_unpaired_child_profile','finish_usage_session','is_household_member','is_household_parent','is_managed_child',
    'is_parent_of','leave_or_remove_child','parent_adjust_credit','parent_child_balance','set_workout_timer',
    'start_credit_session','start_enforced_credit_session','start_usage_session','start_workout','stop_credit_session','update_workout_plan'];
  v_public text[] := array['bloom_create_plan_for_user','bloom_create_workout_plan','bloom_create_workout_plan_scheduled',
    'bloom_credit_balance','bloom_update_workout_plan','bloom_update_workout_plan_scheduled','bloom_weekly_plan_progress','bloom_workout_analytics'];
  v_function record; v_count integer := 0; v_source text;
begin
  for v_function in select p.oid, p.proname from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where (n.nspname = 'bloom_private' and p.proname = any(v_private))
       or (n.nspname = 'public' and p.proname = any(v_public))
  loop
    v_source := pg_get_functiondef(v_function.oid);
    if position('auth.uid()' in v_source) = 0 then raise exception 'Unexpected Bloom function definition: %', v_function.proname; end if;
    execute replace(v_source, 'auth.uid()', 'bloom_private.current_profile_id()');
    v_count := v_count + 1;
  end loop;
  if v_count <> cardinality(v_private) + cardinality(v_public) then raise exception 'Bloom function set is incomplete or has unexpected overloads'; end if;
end;
$$;

drop policy bloom_settings_select on public.bloom_settings;
create policy bloom_settings_select on public.bloom_settings for select to authenticated using (user_id = (select bloom_private.current_profile_id()));
drop policy bloom_settings_insert on public.bloom_settings;
create policy bloom_settings_insert on public.bloom_settings for insert to authenticated with check (user_id = (select bloom_private.current_profile_id()));
drop policy bloom_settings_update on public.bloom_settings;
create policy bloom_settings_update on public.bloom_settings for update to authenticated
  using (user_id = (select bloom_private.current_profile_id()) and not bloom_private.is_managed_child())
  with check (user_id = (select bloom_private.current_profile_id()) and not bloom_private.is_managed_child());
drop policy bloom_plans_own on public.bloom_workout_plans;
create policy bloom_plans_own on public.bloom_workout_plans for all to authenticated
  using (user_id = (select bloom_private.current_profile_id())) with check (user_id = (select bloom_private.current_profile_id()));
drop policy bloom_plan_exercises_own on public.bloom_plan_exercises;
create policy bloom_plan_exercises_own on public.bloom_plan_exercises for all to authenticated
  using (exists (select 1 from public.bloom_workout_plans p where p.id = plan_id and p.user_id = (select bloom_private.current_profile_id())))
  with check (exists (select 1 from public.bloom_workout_plans p where p.id = plan_id and p.user_id = (select bloom_private.current_profile_id())));
drop policy bloom_sessions_read on public.bloom_workout_sessions;
create policy bloom_sessions_read on public.bloom_workout_sessions for select to authenticated using (user_id = (select bloom_private.current_profile_id()));
drop policy bloom_ledger_read on public.bloom_credit_ledger;
create policy bloom_ledger_read on public.bloom_credit_ledger for select to authenticated using (user_id = (select bloom_private.current_profile_id()));
drop policy bloom_credit_sessions_read on public.bloom_credit_sessions;
create policy bloom_credit_sessions_read on public.bloom_credit_sessions for select to authenticated using (user_id = (select bloom_private.current_profile_id()));
drop policy bloom_usage_sessions_read on public.bloom_usage_sessions;
create policy bloom_usage_sessions_read on public.bloom_usage_sessions for select to authenticated
  using (user_id = (select bloom_private.current_profile_id()) or bloom_private.is_parent_of(user_id));
drop policy bloom_blocking_child_read on public.bloom_blocking_rules;
create policy bloom_blocking_child_read on public.bloom_blocking_rules for select to authenticated using (user_id = (select bloom_private.current_profile_id()));
drop policy bloom_members_read_self on public.bloom_household_members;
create policy bloom_members_read_self on public.bloom_household_members for select to authenticated using (user_id = (select bloom_private.current_profile_id()));
drop policy bloom_households_read on public.bloom_households;
create policy bloom_households_read on public.bloom_households for select to authenticated
  using (owner_user_id = (select bloom_private.current_profile_id()) or bloom_private.is_household_member(id));
drop policy bloom_subscriptions_read on public.bloom_subscriptions;
create policy bloom_subscriptions_read on public.bloom_subscriptions for select to authenticated
  using (payer_user_id = (select bloom_private.current_profile_id()) or bloom_private.is_household_member(household_id));
drop policy bloom_private_exercise_read on public.exercises;
create policy bloom_private_exercise_read on public.exercises for select to authenticated
  using (bloom_owner_user_id = (select bloom_private.current_profile_id()) or bloom_private.is_parent_of(bloom_owner_user_id));

-- A PIN belongs to an Auth account, while its household membership belongs
-- to a profile. Keep those two identities distinct during PIN verification.
create or replace function bloom_private.register_parent_pin(p_device_id uuid, p_device_secret text, p_pin text)
returns void language plpgsql security definer set search_path = pg_catalog, pg_temp as $$
declare v_hash text; v_owner uuid; v_schema name;
begin
  if auth.uid() is null or bloom_private.is_managed_child() or not exists (
    select 1 from public.bloom_household_members m where m.user_id = bloom_private.current_profile_id() and m.role = 'parent'
  ) then raise exception 'Parent access required'; end if;
  if p_device_id is null or p_device_secret is null or p_device_secret !~ '^[0-9a-f]{64}$'
    or p_pin is null or p_pin !~ '^[0-9]{6}$' then raise exception 'Enter a six-digit PIN'; end if;
  select d.parent_user_id into v_owner from bloom_private.parent_unlock_devices d where d.device_id = p_device_id for update;
  if found and v_owner <> auth.uid() then raise exception 'Device is already registered'; end if;
  v_schema := bloom_private.pin_crypto_schema();
  if v_schema is null then raise exception 'PIN protection unavailable'; end if;
  execute format('select %I.crypt($1, %I.gen_salt(''bf'', 10))', v_schema, v_schema) into v_hash using p_pin;
  insert into bloom_private.parent_unlock_devices(device_id, parent_user_id, secret_hash, pin_hash)
    values (p_device_id, auth.uid(), sha256(convert_to(p_device_secret, 'UTF8')), v_hash)
    on conflict (device_id) do update set secret_hash = excluded.secret_hash, pin_hash = excluded.pin_hash,
      failed_attempts = 0, locked_until = null, updated_at = now()
    where bloom_private.parent_unlock_devices.parent_user_id = auth.uid();
  if not found then raise exception 'Device is already registered'; end if;
end;
$$;

create or replace function bloom_private.verify_parent_pin(p_child_id uuid, p_device_id uuid, p_device_secret text, p_pin text)
returns uuid language plpgsql security definer set search_path = pg_catalog, pg_temp as $$
declare
  v_device bloom_private.parent_unlock_devices%rowtype;
  v_schema name;
  v_valid boolean := false;
  v_attempts integer;
begin
  if p_child_id is null or p_device_id is null or p_device_secret is null or p_device_secret !~ '^[0-9a-f]{64}$'
    or p_pin is null or p_pin !~ '^[0-9]{6}$' then return null; end if;
  select * into v_device from bloom_private.parent_unlock_devices d
    where d.device_id = p_device_id and d.secret_hash = sha256(convert_to(p_device_secret, 'UTF8')) for update;
  if not found or not exists (
    select 1 from public.bloom_profile_accounts pa join public.bloom_household_members p on p.user_id = pa.profile_id and p.role = 'parent'
    join public.bloom_household_members c on c.household_id = p.household_id and c.role = 'child'
    join public.bloom_profile_accounts ca on ca.profile_id = c.user_id
    where pa.user_id = v_device.parent_user_id and ca.user_id = p_child_id
  ) then return null; end if;
  if v_device.locked_until is not null and v_device.locked_until > clock_timestamp() then return null; end if;
  v_schema := bloom_private.pin_crypto_schema();
  if v_schema is null then return null; end if;
  execute format('select %I.crypt($1, $2) = $2', v_schema) into v_valid using p_pin, v_device.pin_hash;
  if v_valid then
    update bloom_private.parent_unlock_devices set failed_attempts = 0, locked_until = null, updated_at = clock_timestamp()
      where device_id = p_device_id;
    return v_device.parent_user_id;
  end if;
  v_attempts := case when v_device.locked_until is not null then 1 else v_device.failed_attempts + 1 end;
  update bloom_private.parent_unlock_devices set failed_attempts = v_attempts,
    locked_until = case when v_attempts >= 5 then clock_timestamp() + interval '15 minutes' else null end,
    updated_at = clock_timestamp() where device_id = p_device_id;
  return null;
end;
$$;

create table bloom_private.child_account_link_requests (
  token_hash bytea primary key,
  profile_id uuid not null references public.bloom_child_profiles(profile_id) on delete cascade,
  household_id uuid not null references public.bloom_households(id) on delete cascade,
  created_by uuid not null references auth.users(id) on delete cascade,
  expires_at timestamptz not null,
  accepted_by uuid references auth.users(id) on delete cascade,
  accepted_at timestamptz,
  check ((accepted_by is null) = (accepted_at is null))
);
revoke all on bloom_private.child_account_link_requests from public, anon, authenticated;

create function bloom_private.create_child_account_link(p_profile_id uuid)
returns text language plpgsql security definer set search_path = pg_catalog, pg_temp as $$
declare v_household uuid; v_parent uuid := bloom_private.current_profile_id(); v_token text;
begin
  if v_parent is null then raise exception 'Parent access required'; end if;
  select c.household_id into v_household from public.bloom_child_profiles c where c.profile_id = p_profile_id for update;
  if not found then raise exception 'Child profile not found'; end if;
  perform 1 from public.bloom_household_members m where m.household_id = v_household and m.user_id = v_parent and m.role = 'parent' for share;
  if not found then raise exception 'Child profile not found'; end if;
  if not exists (select 1 from auth.users u join public.bloom_profile_accounts a on a.user_id = u.id
    join public.bloom_household_members m on m.user_id = u.id and m.household_id = v_household and m.role = 'child'
    where u.id = p_profile_id and a.profile_id = p_profile_id and u.raw_app_meta_data->>'bloom_managed_child' = 'true') then
    raise exception 'Pair the child profile before linking an email account';
  end if;
  update bloom_private.child_account_link_requests set expires_at = clock_timestamp()
    where profile_id = p_profile_id and accepted_at is null and expires_at > clock_timestamp();
  v_token := replace(gen_random_uuid()::text, '-', '') || replace(gen_random_uuid()::text, '-', '');
  insert into bloom_private.child_account_link_requests(token_hash, profile_id, household_id, created_by, expires_at)
    values (sha256(convert_to(v_token, 'UTF8')), p_profile_id, v_household, v_parent, clock_timestamp() + interval '24 hours');
  return v_token;
end;
$$;
create function public.bloom_create_child_account_link(p_profile_id uuid)
returns text language sql security invoker set search_path = pg_catalog, pg_temp as $$
  select bloom_private.create_child_account_link(p_profile_id);
$$;

create function bloom_private.accept_child_account_link(p_token text)
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
    execute format('select exists (select 1 from %I.%I where %I = $1)', v_fk.nspname, v_fk.relname, v_fk.attname)
      into v_has_data using v_user;
    if v_has_data then raise exception 'Use a new account with no existing activity'; end if;
  end loop;
  update public.bloom_profile_accounts set profile_id = v_request.profile_id where user_id = v_user;
  delete from public.bloom_profiles where id = v_own_profile;
  update bloom_private.child_account_link_requests set accepted_by = v_user, accepted_at = clock_timestamp()
    where token_hash = v_request.token_hash;
  return v_request.profile_id;
end;
$$;
create function public.bloom_accept_child_account_link(p_token text)
returns uuid language sql security invoker set search_path = pg_catalog, pg_temp as $$
  select bloom_private.accept_child_account_link(p_token);
$$;
revoke all on function bloom_private.create_child_account_link(uuid), bloom_private.accept_child_account_link(text),
  public.bloom_create_child_account_link(uuid), public.bloom_accept_child_account_link(text) from public, anon;
grant execute on function bloom_private.create_child_account_link(uuid), bloom_private.accept_child_account_link(text),
  public.bloom_create_child_account_link(uuid), public.bloom_accept_child_account_link(text) to authenticated;

commit;
