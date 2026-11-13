begin;
insert into auth.users(id, email, email_confirmed_at) values
 ('00000000-0000-0000-0000-000000000161', 'parent@example.invalid', now()),
 ('00000000-0000-0000-0000-000000000162', 'new@example.invalid', now()),
 ('00000000-0000-0000-0000-000000000163', 'used@example.invalid', now()),
 ('00000000-0000-0000-0000-000000000164', 'unverified@example.invalid', null);
insert into public.profiles(id) values
 ('00000000-0000-0000-0000-000000000161'), ('00000000-0000-0000-0000-000000000162'),
 ('00000000-0000-0000-0000-000000000163'), ('00000000-0000-0000-0000-000000000164');
insert into public.bloom_settings(user_id) values ('00000000-0000-0000-0000-000000000163');
set local role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000161', true);
select set_config('bloom.convert_house', public.bloom_create_household('Conversion family')::text, true);
select set_config('bloom.convert_child', public.bloom_create_child_profile(current_setting('bloom.convert_house')::uuid, 'Child',
  '16000000-0000-0000-0000-000000000161')::text, true);
select public.bloom_authorize_child_provisioning(current_setting('bloom.convert_child')::uuid);
reset role;
insert into auth.users(id, raw_app_meta_data) values (current_setting('bloom.convert_child')::uuid,
  jsonb_build_object('bloom_managed_child', true, 'bloom_profile_id', current_setting('bloom.convert_child')));
set local role authenticated;
select set_config('request.jwt.claim.sub', current_setting('bloom.convert_child'), true);
select set_config('bloom.convert_exercise', public.bloom_create_custom_exercise('My move', 'Private', 'reps_only')::text, true);
select set_config('bloom.convert_plan', public.bloom_create_workout_plan('My workout', jsonb_build_array(
  jsonb_build_object('exercise_id', current_setting('bloom.convert_exercise'), 'sets', 1, 'target', 10)))::text, true);
select set_config('bloom.convert_session', (select session_id::text from public.bloom_start_workout(current_setting('bloom.convert_plan')::uuid)), true);
select * from public.bloom_complete_workout(current_setting('bloom.convert_session')::uuid, jsonb_build_array(
  jsonb_build_object('exercise_id', current_setting('bloom.convert_exercise'), 'sets_completed', 1, 'reps_completed', 10)));
reset role;
insert into public.bloom_credit_ledger(user_id, amount_minutes, entry_type, idempotency_key)
values (current_setting('bloom.convert_child')::uuid, 12, 'adjustment', 'conversion-fixture');
set local role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000161', true);
select set_config('bloom.convert_code', public.bloom_create_child_account_link(current_setting('bloom.convert_child')::uuid), true);
select public.bloom_register_parent_pin('16000000-0000-0000-0000-000000000162', repeat('a', 64), '123456');
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000164', true);
do $$ begin
  begin
    perform public.bloom_accept_child_account_link(current_setting('bloom.convert_code'));
    raise exception using errcode = 'P0002', message = 'Unverified account was linked';
  exception when raise_exception then if sqlerrm <> 'A verified email account is required' then raise; end if; end;
end $$;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000163', true);
do $$ begin
  begin
    perform public.bloom_accept_child_account_link(current_setting('bloom.convert_code'));
    raise exception using errcode = 'P0002', message = 'Existing account data was overwritten';
  exception when raise_exception then if sqlerrm <> 'Use a new account with no existing activity' then raise; end if; end;
end $$;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000162', true);
do $$ declare v_profile jsonb; v_rows integer; v_plan uuid; begin
  if public.bloom_accept_child_account_link(current_setting('bloom.convert_code')) <> current_setting('bloom.convert_child')::uuid
    or public.bloom_accept_child_account_link(current_setting('bloom.convert_code')) <> current_setting('bloom.convert_child')::uuid then
    raise exception 'Link was not retry-safe';
  end if;
  v_profile := public.bloom_current_profile();
  if v_profile->>'profile_id' <> current_setting('bloom.convert_child') or not (v_profile->>'managed_child')::boolean then
    raise exception 'Independent account did not resolve the child profile';
  end if;
  if not exists (select 1 from public.bloom_workout_plans where id = current_setting('bloom.convert_plan')::uuid)
    or not exists (select 1 from public.bloom_workout_sessions where id = current_setting('bloom.convert_session')::uuid and status = 'completed')
    or not exists (select 1 from public.bloom_credit_ledger where idempotency_key = 'conversion-fixture' and amount_minutes = 12)
    or not exists (select 1 from public.exercises where id = current_setting('bloom.convert_exercise')::uuid)
    or not exists (select 1 from public.bloom_household_members where household_id = current_setting('bloom.convert_house')::uuid and role = 'child') then
    raise exception 'Linked account could not access original history, family or exercise';
  end if;
  update public.bloom_settings set credits_enabled = false where user_id = current_setting('bloom.convert_child')::uuid;
  get diagnostics v_rows = row_count;
  if v_rows <> 0 then raise exception 'Linked child changed parent settings'; end if;
  v_plan := public.bloom_create_workout_plan('Independent workout', jsonb_build_array(
    jsonb_build_object('exercise_id', current_setting('bloom.convert_exercise'), 'sets', 1, 'target', 8)));
  if not exists (select 1 from public.bloom_workout_plans where id = v_plan and user_id = current_setting('bloom.convert_child')::uuid) then
    raise exception 'New workout used account ID instead of profile ID';
  end if;
end $$;
set local role service_role;
do $$ begin
  if public.bloom_verify_parent_pin('00000000-0000-0000-0000-000000000162', '16000000-0000-0000-0000-000000000162', repeat('a', 64), '123456')
    is distinct from '00000000-0000-0000-0000-000000000161'::uuid then
    raise exception 'Linked email account could not unlock its parent';
  end if;
end $$;
rollback;
