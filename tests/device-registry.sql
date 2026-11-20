begin;

insert into auth.users(id) values
  ('00000000-0000-0000-0000-000000000181'),
  ('00000000-0000-0000-0000-000000000182');

set local role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000181', true);
do $$ begin
  if not public.bloom_register_device('18000000-0000-0000-0000-000000000181', 'Mac · A181', 'macos', true, 'allowed', 'on', 3)
    or not public.bloom_register_device('18000000-0000-0000-0000-000000000182', 'Mac · A182', 'macos', true, 'needs_setup', 'off', 0) then
    raise exception 'Profile device registration failed';
  end if;
  if (select count(*) from public.bloom_list_devices()) <> 2 then raise exception 'Same-type devices were not kept distinct'; end if;
  if (select count(distinct device_id) from public.bloom_list_devices()) <> 2 then raise exception 'Device IDs were not distinct'; end if;
  if (select count(*) from public.bloom_devices) <> 2 then raise exception 'Profile could not read its own devices'; end if;
  if has_table_privilege('authenticated', 'public.bloom_devices', 'INSERT')
    or has_table_privilege('authenticated', 'public.bloom_devices', 'UPDATE')
    or has_table_privilege('authenticated', 'public.bloom_devices', 'DELETE') then
    raise exception 'Client can mutate device records outside the authorized functions';
  end if;
  if has_function_privilege('anon', 'public.bloom_list_devices()', 'EXECUTE')
    or has_function_privilege('anon', 'public.bloom_remove_device(uuid)', 'EXECUTE') then
    raise exception 'Anonymous callers can access the device registry';
  end if;
  begin
    perform public.bloom_register_device('18000000-0000-0000-0000-000000000183', 'Invalid', 'linux', false, 'allowed', 'off', 0);
    raise exception using errcode = 'P0002', message = 'Invalid platform was accepted';
  exception when raise_exception then if sqlerrm <> 'Unsupported device platform' then raise; end if; end;
  begin
    perform public.bloom_register_device('18000000-0000-0000-0000-000000000183', 'Invalid', 'web', false, 'allowed', 'off', 10001);
    raise exception using errcode = 'P0002', message = 'Unbounded target count was accepted';
  exception when raise_exception then if sqlerrm <> 'Invalid selected target count' then raise; end if; end;
end $$;

select public.bloom_rename_device('18000000-0000-0000-0000-000000000182', 'Study Mac');
do $$ begin
  if (select display_name from public.bloom_list_devices() where device_id = '18000000-0000-0000-0000-000000000182') <> 'Study Mac' then
    raise exception 'Device rename was not saved';
  end if;
end $$;

select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000182', true);
do $$ begin
  if (select count(*) from public.bloom_list_devices()) <> 0 or (select count(*) from public.bloom_devices) <> 0 then
    raise exception 'Another profile can read the device inventory';
  end if;
  begin
    perform public.bloom_rename_device('18000000-0000-0000-0000-000000000181', 'Stolen');
    raise exception using errcode = 'P0002', message = 'Another profile renamed a device';
  exception when raise_exception then if sqlerrm <> 'Device was not found' then raise; end if; end;
  begin
    perform public.bloom_remove_device('18000000-0000-0000-0000-000000000181');
    raise exception using errcode = 'P0002', message = 'Another profile removed a device';
  exception when raise_exception then if sqlerrm <> 'Device was not found' then raise; end if; end;
end $$;
do $$ begin
  if not public.bloom_register_device('18000000-0000-0000-0000-000000000181', 'Second profile Mac', 'macos', true, 'allowed', 'off', 1) then
    raise exception 'The same installation could not be registered in a separate profile';
  end if;
  if (select count(*) from public.bloom_list_devices()) <> 1
    or (select display_name from public.bloom_list_devices() where device_id = '18000000-0000-0000-0000-000000000181') <> 'Second profile Mac' then
    raise exception 'A separate profile did not retain its own device record';
  end if;
end $$;

select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000181', true);
select public.bloom_remove_device('18000000-0000-0000-0000-000000000182');
do $$ begin
  if (select count(*) from public.bloom_list_devices()) <> 1 then raise exception 'Removed device remains visible'; end if;
  if public.bloom_register_device('18000000-0000-0000-0000-000000000182', 'Renamed', 'macos', true, 'allowed', 'on', 2) then
    raise exception 'Removed device was silently restored';
  end if;
end $$;

reset role;
do $$ begin
  if (select removed_at from public.bloom_devices where profile_id = '00000000-0000-0000-0000-000000000181'
    and device_id = '18000000-0000-0000-0000-000000000182') is null then
    raise exception 'Device removal was not retained';
  end if;
  if (select display_name from public.bloom_devices where profile_id = '00000000-0000-0000-0000-000000000181'
    and device_id = '18000000-0000-0000-0000-000000000182') <> 'Removed device'
    or (select selected_target_count from public.bloom_devices where profile_id = '00000000-0000-0000-0000-000000000181'
      and device_id = '18000000-0000-0000-0000-000000000182') is not null then
    raise exception 'Device removal retained private display or status data';
  end if;
end $$;

rollback;
