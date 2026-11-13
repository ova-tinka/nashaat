begin;
insert into auth.users(id) values
 ('00000000-0000-0000-0000-000000000151'),
 ('00000000-0000-0000-0000-000000000152'),
 ('00000000-0000-0000-0000-000000000153');
set local role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000151', true);
select set_config('bloom.pin_house', public.bloom_create_household('PIN family')::text, true);
select set_config('bloom.pin_invite', public.bloom_create_child_invite(current_setting('bloom.pin_house')::uuid), true);
select public.bloom_register_parent_pin('15000000-0000-0000-0000-000000000151', repeat('a', 64), '123456');
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000152', true);
select public.bloom_accept_child_invite(current_setting('bloom.pin_invite'));
do $$ begin
  if has_function_privilege('authenticated', 'public.bloom_verify_parent_pin(uuid,uuid,text,text)', 'EXECUTE')
    or has_table_privilege('authenticated', 'bloom_private.parent_unlock_devices', 'SELECT') then
    raise exception 'Client can access parent PIN internals';
  end if;
  begin
    perform public.bloom_register_parent_pin('15000000-0000-0000-0000-000000000152', repeat('b', 64), '123456');
    raise exception using errcode = 'P0002', message = 'Child registered parent PIN';
  exception when raise_exception then if sqlerrm <> 'Parent access required' then raise; end if; end;
  begin
    perform public.bloom_leave_or_remove_child(current_setting('bloom.pin_house')::uuid, '00000000-0000-0000-0000-000000000152');
    raise exception using errcode = 'P0002', message = 'Child left family without parent';
  exception when raise_exception then if sqlerrm <> 'Parent access required' then raise; end if; end;
end $$;
reset role;
do $$ begin
  if exists (select 1 from bloom_private.parent_unlock_devices where pin_hash = '123456' or secret_hash = convert_to(repeat('a', 64), 'UTF8')) then
    raise exception 'PIN or device secret stored in plaintext';
  end if;
end $$;
set local role service_role;
do $$ declare i integer; begin
  if public.bloom_verify_parent_pin('00000000-0000-0000-0000-000000000153', '15000000-0000-0000-0000-000000000151', repeat('a', 64), '123456') is not null then
    raise exception 'Unrelated child unlocked parent';
  end if;
  if public.bloom_verify_parent_pin('00000000-0000-0000-0000-000000000152', '15000000-0000-0000-0000-000000000151', repeat('b', 64), '123456') is not null then
    raise exception 'Wrong device secret unlocked parent';
  end if;
  for i in 1..5 loop
    if public.bloom_verify_parent_pin('00000000-0000-0000-0000-000000000152', '15000000-0000-0000-0000-000000000151', repeat('a', 64), '654321') is not null then
      raise exception 'Wrong PIN unlocked parent';
    end if;
  end loop;
  if public.bloom_verify_parent_pin('00000000-0000-0000-0000-000000000152', '15000000-0000-0000-0000-000000000151', repeat('a', 64), '123456') is not null then
    raise exception 'Locked device accepted a PIN';
  end if;
end $$;
reset role;
update bloom_private.parent_unlock_devices set locked_until = clock_timestamp() - interval '1 second'
  where device_id = '15000000-0000-0000-0000-000000000151';
set local role service_role;
do $$ begin
  if public.bloom_verify_parent_pin('00000000-0000-0000-0000-000000000152', '15000000-0000-0000-0000-000000000151', repeat('a', 64), '123456')
    is distinct from '00000000-0000-0000-0000-000000000151'::uuid then raise exception 'Correct PIN did not unlock parent'; end if;
end $$;
reset role;
do $$ begin
  if exists (select 1 from bloom_private.parent_unlock_devices where failed_attempts <> 0 or locked_until is not null) then
    raise exception 'Successful unlock did not reset attempts';
  end if;
end $$;
set local role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000151', true);
select public.bloom_remove_parent_pin('15000000-0000-0000-0000-000000000151');
set local role service_role;
do $$ begin
  if public.bloom_verify_parent_pin('00000000-0000-0000-0000-000000000152', '15000000-0000-0000-0000-000000000151', repeat('a', 64), '123456') is not null then
    raise exception 'Removed device unlocked parent';
  end if;
end $$;
rollback;
