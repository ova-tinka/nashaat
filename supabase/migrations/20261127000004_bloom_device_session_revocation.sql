begin;

-- Retire PIN-based parent token issuance.
delete from bloom_private.parent_unlock_devices;

create or replace function bloom_private.register_parent_pin(p_device_id uuid, p_device_secret text, p_pin text)
returns void language plpgsql security definer set search_path = pg_catalog, pg_temp as $$
begin
  raise exception 'Parent PIN sign-in has been retired. Sign in with your parent account instead.';
end;
$$;

create or replace function bloom_private.verify_parent_pin(p_child_id uuid, p_device_id uuid, p_device_secret text, p_pin text)
returns uuid language plpgsql security definer set search_path = pg_catalog, pg_temp as $$
begin
  return null;
end;
$$;

-- Bind registered devices to verified Auth session IDs and enforce session
-- revocation across Data API RLS, private Storage, and RPCs.
create table if not exists bloom_private.revoked_auth_sessions (
  session_id uuid primary key,
  profile_id uuid not null references public.bloom_profiles(id) on delete cascade,
  device_id uuid,
  revoked_at timestamptz not null default clock_timestamp()
);
revoke all on bloom_private.revoked_auth_sessions from public, anon, authenticated;

create or replace function bloom_private.current_session_id()
returns uuid language plpgsql stable security definer set search_path = pg_catalog, pg_temp as $$
declare
  v_raw text;
begin
  v_raw := coalesce(
    nullif(auth.jwt()->>'session_id', ''),
    nullif(current_setting('request.jwt.claim.session_id', true), '')
  );
  if v_raw is null then
    return null;
  end if;
  return v_raw::uuid;
exception when invalid_text_representation then
  return null;
end;
$$;

create or replace function bloom_private.is_session_revoked(p_session_id uuid)
returns boolean language sql stable security definer set search_path = pg_catalog, pg_temp as $$
  select p_session_id is not null
    and exists (
      select 1
      from bloom_private.revoked_auth_sessions r
      where r.session_id = p_session_id
    );
$$;

create or replace function public.bloom_is_session_revoked(p_session_id uuid)
returns boolean language sql stable security invoker set search_path = pg_catalog, pg_temp as $$
  select bloom_private.is_session_revoked(p_session_id);
$$;

revoke all on function bloom_private.current_session_id() from public, anon;
grant execute on function bloom_private.current_session_id() to authenticated;
revoke all on function bloom_private.is_session_revoked(uuid) from public, anon, authenticated;
grant execute on function bloom_private.is_session_revoked(uuid) to authenticated, service_role;
revoke all on function public.bloom_is_session_revoked(uuid) from public, anon, authenticated;
grant execute on function public.bloom_is_session_revoked(uuid) to service_role;

create or replace function bloom_private.current_profile_id()
returns uuid language sql stable security definer set search_path = pg_catalog, pg_temp as $$
  select a.profile_id
  from public.bloom_profile_accounts a
  where a.user_id = auth.uid()
    and not bloom_private.is_session_revoked(bloom_private.current_session_id());
$$;

alter table public.bloom_devices
  add column if not exists auth_session_id uuid,
  add column if not exists revoked_at timestamptz;

create or replace function bloom_private.register_device(
  p_device_id uuid,
  p_display_name text,
  p_platform text,
  p_focus_supported boolean,
  p_permission_state text,
  p_blocking_state text,
  p_selected_target_count integer
)
returns boolean language plpgsql security definer set search_path = pg_catalog, pg_temp as $$
declare
  v_profile uuid := bloom_private.current_profile_id();
  v_session uuid := bloom_private.current_session_id();
  v_registered boolean;
begin
  if v_profile is null or p_device_id is null then raise exception 'Sign in to manage devices'; end if;
  if p_display_name is null or char_length(trim(p_display_name)) not between 1 and 80 then
    raise exception 'Enter a device name between 1 and 80 characters';
  end if;
  if p_platform not in ('ios', 'android', 'macos', 'windows', 'web') then raise exception 'Unsupported device platform'; end if;
  if p_permission_state not in ('allowed', 'needs_setup', 'unavailable', 'unknown') then raise exception 'Invalid permission state'; end if;
  if p_blocking_state not in ('on', 'off', 'needs_attention', 'unavailable', 'unknown') then raise exception 'Invalid blocking state'; end if;
  if p_selected_target_count is not null and p_selected_target_count not between 0 and 10000 then raise exception 'Invalid selected target count'; end if;

  insert into public.bloom_devices as d (
    device_id, profile_id, display_name, platform, focus_supported,
    permission_state, blocking_state, selected_target_count, auth_session_id
  ) values (
    p_device_id, v_profile, trim(p_display_name), p_platform, p_focus_supported,
    p_permission_state, p_blocking_state, p_selected_target_count, v_session
  )
  on conflict (profile_id, device_id) do update set
    platform = excluded.platform,
    focus_supported = excluded.focus_supported,
    permission_state = excluded.permission_state,
    blocking_state = excluded.blocking_state,
    selected_target_count = excluded.selected_target_count,
    auth_session_id = coalesce(excluded.auth_session_id, d.auth_session_id),
    last_seen_at = clock_timestamp(),
    status_checked_at = clock_timestamp(),
    updated_at = clock_timestamp()
  where d.removed_at is null
  returning true into v_registered;

  return coalesce(v_registered, false);
end;
$$;

create or replace function bloom_private.revoke_device(p_device_id uuid)
returns jsonb language plpgsql security definer set search_path = pg_catalog, pg_temp as $$
declare
  v_profile uuid := bloom_private.current_profile_id();
  v_device public.bloom_devices%rowtype;
begin
  if v_profile is null then raise exception 'Sign in to manage devices'; end if;
  select * into v_device
  from public.bloom_devices d
  where d.profile_id = v_profile
    and d.device_id = p_device_id
    and d.removed_at is null
  for update;
  if not found then raise exception 'Device was not found'; end if;

  if v_device.auth_session_id is not null then
    insert into bloom_private.revoked_auth_sessions(session_id, profile_id, device_id)
    values (v_device.auth_session_id, v_profile, p_device_id)
    on conflict (session_id) do nothing;
  end if;

  update public.bloom_devices set
    display_name = 'Removed device',
    platform = 'web',
    focus_supported = null,
    permission_state = 'unknown',
    blocking_state = 'unknown',
    selected_target_count = null,
    removed_at = clock_timestamp(),
    revoked_at = clock_timestamp(),
    updated_at = clock_timestamp()
  where profile_id = v_profile and device_id = p_device_id and removed_at is null;

  return jsonb_build_object(
    'device_id', p_device_id,
    'session_id', v_device.auth_session_id,
    'revoked', true
  );
end;
$$;

create or replace function bloom_private.remove_device(p_device_id uuid)
returns void language plpgsql security definer set search_path = pg_catalog, pg_temp as $$
begin
  perform bloom_private.revoke_device(p_device_id);
end;
$$;

create or replace function public.bloom_revoke_device(p_device_id uuid)
returns jsonb language sql security invoker set search_path = pg_catalog, pg_temp as $$
  select bloom_private.revoke_device(p_device_id);
$$;

revoke all on function bloom_private.revoke_device(uuid), public.bloom_revoke_device(uuid) from public, anon;
grant execute on function bloom_private.revoke_device(uuid), public.bloom_revoke_device(uuid) to authenticated;

commit;
