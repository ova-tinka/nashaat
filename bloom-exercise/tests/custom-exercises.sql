begin;
insert into auth.users(id) values
 ('00000000-0000-0000-0000-000000000101'),
 ('00000000-0000-0000-0000-000000000102'),
 ('00000000-0000-0000-0000-000000000103');

set local role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000101', true);
select set_config('bloom.custom_house', public.bloom_create_household('Family')::text, true);
select set_config('bloom.custom_invite', public.bloom_create_child_invite(current_setting('bloom.custom_house')::uuid), true);
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000102', true);
select public.bloom_accept_child_invite(current_setting('bloom.custom_invite'));
select set_config('bloom.custom_id', public.bloom_create_custom_exercise('Private move', 'My notes', 'reps_only')::text, true);
select set_config('bloom.custom_plan', public.bloom_create_workout_plan('Private plan', jsonb_build_array(
  jsonb_build_object('exercise_id', current_setting('bloom.custom_id'), 'sets', 1, 'target', 10)))::text, true);
do $$ begin
  if not exists (select 1 from public.exercises where id = current_setting('bloom.custom_id')::uuid) then
    raise exception 'Owner cannot read the custom exercise';
  end if;
  begin
    perform public.bloom_create_custom_exercise('Invalid', '', 'bad');
    raise exception using errcode = 'P0002', message = 'Invalid measurement accepted';
  exception when raise_exception then if sqlerrm <> 'Invalid measurement type' then raise; end if; end;
end $$;

select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000103', true);
do $$ begin
  if exists (select 1 from public.exercises where id = current_setting('bloom.custom_id')::uuid) then
    raise exception 'Outsider can read a custom exercise';
  end if;
  begin
    perform public.bloom_create_workout_plan('Intrusion', jsonb_build_array(
      jsonb_build_object('exercise_id', current_setting('bloom.custom_id'), 'sets', 1, 'target', 10)));
    raise exception using errcode = 'P0002', message = 'Outsider used a private exercise';
  exception when raise_exception then if sqlerrm <> 'Exercise not found' then raise; end if; end;
  perform public.bloom_create_custom_exercise('Private move', 'Other notes', 'time_only');
end $$;

select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000101', true);
select set_config('bloom.parent_exercise', public.bloom_create_custom_exercise('Parent move', '', 'reps_only')::text, true);
do $$ begin
  if not exists (select 1 from public.exercises where id = current_setting('bloom.custom_id')::uuid) then
    raise exception 'Parent cannot see child exercise';
  end if;
  perform public.bloom_update_plan_for_user('00000000-0000-0000-0000-000000000102', current_setting('bloom.custom_plan')::uuid,
    'Updated', jsonb_build_array(jsonb_build_object('exercise_id', current_setting('bloom.custom_id'), 'sets', 2, 'target', 12)));
  begin
    perform public.bloom_create_plan_for_user('00000000-0000-0000-0000-000000000102', 'Wrong owner',
      jsonb_build_array(jsonb_build_object('exercise_id', current_setting('bloom.parent_exercise'), 'sets', 1, 'target', 10)));
    raise exception using errcode = 'P0002', message = 'Parent exercise added to child plan';
  exception when raise_exception then if sqlerrm <> 'Exercise not found' then raise; end if; end;
end $$;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000102', true);
do $$ declare v_session uuid; begin
  select session_id into v_session from public.bloom_start_workout(current_setting('bloom.custom_plan')::uuid);
  if not exists (select 1 from public.bloom_workout_sessions where id = v_session and plan_snapshot->0->>'name' = 'Private move') then
    raise exception 'Custom exercise was not included in workout';
  end if;
end $$;
reset role;
set local role anon;
do $$ begin
  if exists (select 1 from public.exercises where id = current_setting('bloom.custom_id')::uuid) then
    raise exception 'Anonymous user can read a custom exercise';
  end if;
end $$;
rollback;
