begin;

create schema if not exists extensions;
create extension if not exists pgcrypto with schema extensions;

create table bloom_private.parent_unlock_devices (
  device_id uuid primary key,
  parent_user_id uuid not null references auth.users(id) on delete cascade,
  secret_hash bytea not null,
  pin_hash text not null,
  failed_attempts integer not null default 0 check (failed_attempts between 0 and 5),
  locked_until timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
revoke all on bloom_private.parent_unlock_devices from public, anon, authenticated;

-- Locate pgcrypto through the extension catalog so existing installations in
-- either public or extensions are handled without changing their search path.
create function bloom_private.pin_crypto_schema()
returns name language sql stable security invoker set search_path = pg_catalog, pg_temp as $$
  select n.nspname from pg_extension e join pg_namespace n on n.oid = e.extnamespace where e.extname = 'pgcrypto';
$$;
revoke all on function bloom_private.pin_crypto_schema() from public, anon, authenticated;

create function bloom_private.register_parent_pin(p_device_id uuid, p_device_secret text, p_pin text)
returns void language plpgsql security definer set search_path = pg_catalog, pg_temp as $$
declare v_hash text; v_owner uuid; v_schema name;
begin
  if auth.uid() is null or bloom_private.is_managed_child() or not exists (
    select 1 from public.bloom_household_members m where m.user_id = auth.uid() and m.role = 'parent'
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
create function public.bloom_register_parent_pin(p_device_id uuid, p_device_secret text, p_pin text)
returns void language sql security invoker set search_path = pg_catalog, pg_temp as $$
  select bloom_private.register_parent_pin(p_device_id, p_device_secret, p_pin);
$$;

create function bloom_private.remove_parent_pin(p_device_id uuid)
returns void language plpgsql security definer set search_path = pg_catalog, pg_temp as $$
begin
  if auth.uid() is null then raise exception 'Parent access required'; end if;
  delete from bloom_private.parent_unlock_devices where device_id = p_device_id and parent_user_id = auth.uid();
end;
$$;
create function public.bloom_remove_parent_pin(p_device_id uuid)
returns void language sql security invoker set search_path = pg_catalog, pg_temp as $$
  select bloom_private.remove_parent_pin(p_device_id);
$$;

-- This service-only function returns NULL on failure so the attempt counter is
-- committed. The Edge function derives p_child_id from a verified Auth JWT.
create function bloom_private.verify_parent_pin(p_child_id uuid, p_device_id uuid, p_device_secret text, p_pin text)
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
    select 1 from public.bloom_household_members p join public.bloom_household_members c on c.household_id = p.household_id
    where p.user_id = v_device.parent_user_id and p.role = 'parent' and c.user_id = p_child_id and c.role = 'child'
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
create function public.bloom_verify_parent_pin(p_child_id uuid, p_device_id uuid, p_device_secret text, p_pin text)
returns uuid language sql security invoker set search_path = pg_catalog, pg_temp as $$
  select bloom_private.verify_parent_pin(p_child_id, p_device_id, p_device_secret, p_pin);
$$;

revoke all on function bloom_private.register_parent_pin(uuid, text, text), bloom_private.remove_parent_pin(uuid),
  public.bloom_register_parent_pin(uuid, text, text), public.bloom_remove_parent_pin(uuid) from public, anon;
grant execute on function bloom_private.register_parent_pin(uuid, text, text), bloom_private.remove_parent_pin(uuid),
  public.bloom_register_parent_pin(uuid, text, text), public.bloom_remove_parent_pin(uuid) to authenticated;
revoke all on function bloom_private.verify_parent_pin(uuid, uuid, text, text), public.bloom_verify_parent_pin(uuid, uuid, text, text)
  from public, anon, authenticated;
grant execute on function bloom_private.verify_parent_pin(uuid, uuid, text, text), public.bloom_verify_parent_pin(uuid, uuid, text, text) to service_role;

commit;
