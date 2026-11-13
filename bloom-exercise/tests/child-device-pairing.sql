begin;
insert into auth.users(id) values
 ('00000000-0000-0000-0000-000000000141'),
 ('00000000-0000-0000-0000-000000000142');
set local role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000141', true);
select set_config('bloom.pair_house', public.bloom_create_household('Pairing family')::text, true);
select set_config('bloom.pair_profile', public.bloom_create_child_profile(current_setting('bloom.pair_house')::uuid, 'Child',
  '14000000-0000-0000-0000-000000000141')::text, true);
do $$ begin
  begin
    perform public.bloom_create_child_pairing_code(current_setting('bloom.pair_profile')::uuid);
    raise exception using errcode = 'P0002', message = 'Unprovisioned child paired';
  exception when raise_exception then if sqlerrm <> 'Child identity is not ready' then raise; end if; end;
end $$;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000142', true);
do $$ begin
  begin
    perform public.bloom_authorize_child_provisioning(current_setting('bloom.pair_profile')::uuid);
    raise exception using errcode = 'P0002', message = 'Outsider authorized provisioning';
  exception when raise_exception then if sqlerrm <> 'Child profile not found' then raise; end if; end;
end $$;
reset role;
do $$ begin
  begin
    insert into auth.users(id, raw_app_meta_data) values (current_setting('bloom.pair_profile')::uuid,
      jsonb_build_object('bloom_managed_child', true, 'bloom_profile_id', current_setting('bloom.pair_profile'),
        'bloom_parent_id', '00000000-0000-0000-0000-000000000142'));
    raise exception using errcode = 'P0002', message = 'Wrong parent provisioned child';
  exception when raise_exception then if sqlerrm <> 'Provisioning authorization required' then raise; end if; end;
end $$;
set local role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000141', true);
select public.bloom_authorize_child_provisioning(current_setting('bloom.pair_profile')::uuid);
reset role;
insert into auth.users(id, raw_app_meta_data) values (current_setting('bloom.pair_profile')::uuid,
  jsonb_build_object('bloom_managed_child', true, 'bloom_profile_id', current_setting('bloom.pair_profile'),
    'bloom_parent_id', '00000000-0000-0000-0000-000000000141'));
do $$ begin
  if not exists (select 1 from public.bloom_profile_accounts where user_id = current_setting('bloom.pair_profile')::uuid and profile_id = user_id)
    or not exists (select 1 from public.bloom_household_members where user_id = current_setting('bloom.pair_profile')::uuid and household_id = current_setting('bloom.pair_house')::uuid and role = 'child')
    or not exists (select 1 from public.bloom_settings where user_id = current_setting('bloom.pair_profile')::uuid) then
    raise exception 'Managed child identity was not linked atomically';
  end if;
end $$;
set local role authenticated;
select set_config('request.jwt.claim.sub', current_setting('bloom.pair_profile'), true);
do $$ declare v_rows integer; begin
  update public.bloom_settings set credits_enabled = false where user_id = auth.uid();
  get diagnostics v_rows = row_count;
  if v_rows <> 0 then raise exception 'Managed child changed parent credit settings'; end if;
  begin
    perform public.bloom_leave_or_remove_child(current_setting('bloom.pair_house')::uuid, auth.uid());
    raise exception using errcode = 'P0002', message = 'Managed child left family';
  exception when raise_exception then if sqlerrm <> 'Parent access required' then raise; end if; end;
  if has_function_privilege('authenticated', 'public.bloom_consume_child_pairing_code(text)', 'EXECUTE')
    or has_table_privilege('authenticated', 'bloom_private.child_pairing_codes', 'SELECT') then
    raise exception 'Child can access pairing internals';
  end if;
end $$;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000141', true);
update public.bloom_settings set credits_enabled = false where user_id = current_setting('bloom.pair_profile')::uuid;
do $$ begin
  if not exists (select 1 from public.bloom_settings where user_id = current_setting('bloom.pair_profile')::uuid and not credits_enabled) then
    raise exception 'Parent cannot update child settings';
  end if;
end $$;
select set_config('bloom.pair_old', public.bloom_create_child_pairing_code(current_setting('bloom.pair_profile')::uuid), true);
select set_config('bloom.pair_code', public.bloom_create_child_pairing_code(current_setting('bloom.pair_profile')::uuid), true);
set local role service_role;
do $$ declare v_hash text; begin
  v_hash := encode(sha256(convert_to(current_setting('bloom.pair_old'), 'UTF8')), 'hex');
  begin
    perform public.bloom_consume_child_pairing_code(v_hash);
    raise exception using errcode = 'P0002', message = 'Old code still usable';
  exception when raise_exception then if sqlerrm <> 'Invalid or expired pairing code' then raise; end if; end;
  v_hash := encode(sha256(convert_to(current_setting('bloom.pair_code'), 'UTF8')), 'hex');
  if public.bloom_consume_child_pairing_code(v_hash) <> current_setting('bloom.pair_profile')::uuid then raise exception 'Pairing returned wrong profile'; end if;
  begin
    perform public.bloom_consume_child_pairing_code(v_hash);
    raise exception using errcode = 'P0002', message = 'Pairing code reused';
  exception when raise_exception then if sqlerrm <> 'Invalid or expired pairing code' then raise; end if; end;
end $$;
rollback;
