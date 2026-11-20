begin;

-- Device inventory is private to each Bloom profile. A physical installation
-- can have a separate inventory row in a parent and child profile.
create table public.bloom_devices (
  device_id uuid not null,
  profile_id uuid not null references public.bloom_profiles(id) on delete cascade,
  display_name text not null check (char_length(trim(display_name)) between 1 and 80),
  platform text not null check (platform in ('ios', 'android', 'macos', 'windows', 'web')),
  focus_supported boolean,
  permission_state text not null check (permission_state in ('allowed', 'needs_setup', 'unavailable', 'unknown')),
  blocking_state text not null check (blocking_state in ('on', 'off', 'needs_attention', 'unavailable', 'unknown')),
  selected_target_count integer check (selected_target_count between 0 and 10000),
  first_seen_at timestamptz not null default clock_timestamp(),
  last_seen_at timestamptz not null default clock_timestamp(),
  status_checked_at timestamptz not null default clock_timestamp(),
  updated_at timestamptz not null default clock_timestamp(),
  removed_at timestamptz,
  primary key (profile_id, device_id)
);

create index bloom_devices_profile_last_seen_idx
  on public.bloom_devices(profile_id, last_seen_at desc) where removed_at is null;

alter table public.bloom_devices enable row level security;
revoke all on public.bloom_devices from public, anon, authenticated;
grant select on public.bloom_devices to authenticated;
create policy bloom_devices_read_own on public.bloom_devices for select to authenticated
  using (profile_id = (select bloom_private.current_profile_id()) and removed_at is null);

create function bloom_private.register_device(
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
    permission_state, blocking_state, selected_target_count
  ) values (
    p_device_id, v_profile, trim(p_display_name), p_platform, p_focus_supported,
    p_permission_state, p_blocking_state, p_selected_target_count
  )
  on conflict (profile_id, device_id) do update set
    platform = excluded.platform,
    focus_supported = excluded.focus_supported,
    permission_state = excluded.permission_state,
    blocking_state = excluded.blocking_state,
    selected_target_count = excluded.selected_target_count,
    last_seen_at = clock_timestamp(),
    status_checked_at = clock_timestamp(),
    updated_at = clock_timestamp()
  where d.removed_at is null
  returning true into v_registered;

  -- A removed installation is tombstoned. It stays out of inventory if it
  -- comes online again; users can explicitly add it again with a fresh ID.
  return coalesce(v_registered, false);
end;
$$;

create function bloom_private.list_devices()
returns setof public.bloom_devices language sql stable security definer set search_path = pg_catalog, pg_temp as $$
  select d.* from public.bloom_devices d
  where d.profile_id = bloom_private.current_profile_id() and d.removed_at is null
  order by d.last_seen_at desc, d.device_id;
$$;

create function bloom_private.rename_device(p_device_id uuid, p_display_name text)
returns void language plpgsql security definer set search_path = pg_catalog, pg_temp as $$
declare v_profile uuid := bloom_private.current_profile_id();
begin
  if v_profile is null then raise exception 'Sign in to manage devices'; end if;
  if p_display_name is null or char_length(trim(p_display_name)) not between 1 and 80 then
    raise exception 'Enter a device name between 1 and 80 characters';
  end if;
  update public.bloom_devices set display_name = trim(p_display_name), updated_at = clock_timestamp()
  where profile_id = v_profile and device_id = p_device_id and removed_at is null;
  if not found then raise exception 'Device was not found'; end if;
end;
$$;

create function bloom_private.remove_device(p_device_id uuid)
returns void language plpgsql security definer set search_path = pg_catalog, pg_temp as $$
declare v_profile uuid := bloom_private.current_profile_id();
begin
  if v_profile is null then raise exception 'Sign in to manage devices'; end if;
  update public.bloom_devices set
    display_name = 'Removed device',
    platform = 'web',
    focus_supported = null,
    permission_state = 'unknown',
    blocking_state = 'unknown',
    selected_target_count = null,
    removed_at = clock_timestamp(),
    updated_at = clock_timestamp()
  where profile_id = v_profile and device_id = p_device_id and removed_at is null;
  if not found then raise exception 'Device was not found'; end if;
end;
$$;

revoke all on function bloom_private.register_device(uuid, text, text, boolean, text, text, integer),
  bloom_private.list_devices(), bloom_private.rename_device(uuid, text), bloom_private.remove_device(uuid)
  from public, anon, authenticated;
grant execute on function bloom_private.register_device(uuid, text, text, boolean, text, text, integer),
  bloom_private.list_devices(), bloom_private.rename_device(uuid, text), bloom_private.remove_device(uuid)
  to authenticated;

create function public.bloom_register_device(
  p_device_id uuid, p_display_name text, p_platform text, p_focus_supported boolean,
  p_permission_state text, p_blocking_state text, p_selected_target_count integer
)
returns boolean language sql security invoker set search_path = pg_catalog, pg_temp as $$
  select bloom_private.register_device(p_device_id, p_display_name, p_platform, p_focus_supported,
    p_permission_state, p_blocking_state, p_selected_target_count);
$$;

create function public.bloom_list_devices()
returns setof public.bloom_devices language sql stable security invoker set search_path = pg_catalog, pg_temp as $$
  select * from bloom_private.list_devices();
$$;

create function public.bloom_rename_device(p_device_id uuid, p_display_name text)
returns void language sql security invoker set search_path = pg_catalog, pg_temp as $$
  select bloom_private.rename_device(p_device_id, p_display_name);
$$;

create function public.bloom_remove_device(p_device_id uuid)
returns void language sql security invoker set search_path = pg_catalog, pg_temp as $$
  select bloom_private.remove_device(p_device_id);
$$;

revoke all on function public.bloom_register_device(uuid, text, text, boolean, text, text, integer),
  public.bloom_list_devices(), public.bloom_rename_device(uuid, text), public.bloom_remove_device(uuid)
  from public, anon;
grant execute on function public.bloom_register_device(uuid, text, text, boolean, text, text, integer),
  public.bloom_list_devices(), public.bloom_rename_device(uuid, text), public.bloom_remove_device(uuid)
  to authenticated;

commit;
