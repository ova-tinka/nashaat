begin;
insert into auth.users(id) values
 ('00000000-0000-0000-0000-000000000121'),
 ('00000000-0000-0000-0000-000000000122'),
 ('00000000-0000-0000-0000-000000000123'),
 ('00000000-0000-0000-0000-000000000124');
set local role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000121', true);
select set_config('bloom.managed_house', public.bloom_create_household('Managed family')::text, true);
select set_config('bloom.managed_invite', public.bloom_create_child_invite(current_setting('bloom.managed_house')::uuid), true);
select set_config('bloom.managed_id', public.bloom_create_child_profile(current_setting('bloom.managed_house')::uuid, 'Child',
  '12000000-0000-0000-0000-000000000121')::text, true);
do $$ begin
  if public.bloom_create_child_profile(current_setting('bloom.managed_house')::uuid, ' Child ',
      '12000000-0000-0000-0000-000000000121') <> current_setting('bloom.managed_id')::uuid then
    raise exception 'Create retry did not return the same profile';
  end if;
  if not exists (select 1 from public.bloom_profiles where id = current_setting('bloom.managed_id')::uuid)
    or not exists (select 1 from public.bloom_child_profiles where profile_id = current_setting('bloom.managed_id')::uuid) then
    raise exception 'Parent cannot see managed profile';
  end if;
  begin
    perform public.bloom_create_child_profile(current_setting('bloom.managed_house')::uuid, 'Different', '12000000-0000-0000-0000-000000000121');
    raise exception using errcode = 'P0002', message = 'Request was reused';
  exception when raise_exception then if sqlerrm <> 'Request was already used with a different name' then raise; end if; end;
  if has_table_privilege('authenticated', 'public.bloom_child_profiles', 'INSERT') or has_table_privilege('authenticated', 'public.bloom_child_profiles', 'DELETE') then
    raise exception 'Client can write child profiles directly';
  end if;
end $$;

select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000122', true);
select public.bloom_accept_child_invite(current_setting('bloom.managed_invite'));
do $$ begin
  if exists (select 1 from public.bloom_child_profiles where profile_id = current_setting('bloom.managed_id')::uuid)
    or exists (select 1 from public.bloom_profiles where id = current_setting('bloom.managed_id')::uuid) then
    raise exception 'Child account saw managed profile';
  end if;
  begin
    perform public.bloom_create_child_profile(current_setting('bloom.managed_house')::uuid, 'Intruder', '12000000-0000-0000-0000-000000000122');
    raise exception using errcode = 'P0002', message = 'Child created a managed profile';
  exception when raise_exception then if sqlerrm <> 'Parent access required' then raise; end if; end;
end $$;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000123', true);
do $$ begin
  if exists (select 1 from public.bloom_child_profiles where profile_id = current_setting('bloom.managed_id')::uuid) then raise exception 'Outsider saw child profile'; end if;
  begin
    perform public.bloom_delete_unpaired_child_profile(current_setting('bloom.managed_id')::uuid);
    raise exception using errcode = 'P0002', message = 'Outsider removed child profile';
  exception when raise_exception then if sqlerrm <> 'Child profile not found' then raise; end if; end;
end $$;

-- Model a future account link to verify the deletion guard.
reset role;
update public.bloom_profile_accounts set profile_id = current_setting('bloom.managed_id')::uuid
  where user_id = '00000000-0000-0000-0000-000000000124';
set local role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000121', true);
do $$ begin
  begin
    perform public.bloom_delete_unpaired_child_profile(current_setting('bloom.managed_id')::uuid);
    raise exception using errcode = 'P0002', message = 'Linked profile was removed';
  exception when raise_exception then if sqlerrm <> 'A linked profile cannot be deleted here' then raise; end if; end;
end $$;
reset role;
update public.bloom_profile_accounts set profile_id = user_id where user_id = '00000000-0000-0000-0000-000000000124';
set local role authenticated;
select public.bloom_delete_unpaired_child_profile(current_setting('bloom.managed_id')::uuid);
do $$ begin
  if exists (select 1 from public.bloom_profiles where id = current_setting('bloom.managed_id')::uuid) then raise exception 'Profile was not removed'; end if;
end $$;
rollback;
