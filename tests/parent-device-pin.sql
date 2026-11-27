begin;
insert into auth.users(id) values
 ('00000000-0000-0000-0000-000000000151'),
 ('00000000-0000-0000-0000-000000000152');
set local role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000151', true);
select set_config('bloom.pin_house', public.bloom_create_household('PIN family')::text, true);
select set_config('bloom.pin_invite', public.bloom_create_child_invite(current_setting('bloom.pin_house')::uuid), true);
do $$ begin
  begin
    perform public.bloom_register_parent_pin('15000000-0000-0000-0000-000000000151', repeat('a', 64), '123456');
    raise exception using errcode = 'P0002', message = 'Retired parent PIN registration succeeded';
  exception when raise_exception then
    if sqlerrm <> 'Parent PIN sign-in has been retired. Sign in with your parent account instead.' then raise; end if;
  end;
end $$;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000152', true);
select public.bloom_accept_child_invite(current_setting('bloom.pin_invite'));
reset role;
insert into bloom_private.parent_unlock_devices(device_id, parent_user_id, secret_hash, pin_hash)
values (
  '15000000-0000-0000-0000-000000000151',
  '00000000-0000-0000-0000-000000000151',
  sha256(convert_to(repeat('a', 64), 'UTF8')),
  'legacy-hash'
);
set local role service_role;
do $$ begin
  if public.bloom_verify_parent_pin('00000000-0000-0000-0000-000000000152', '15000000-0000-0000-0000-000000000151', repeat('a', 64), '123456') is not null then
    raise exception 'Retired parent PIN issued an identity';
  end if;
end $$;
rollback;
