begin;
insert into auth.users(id) values
  ('00000000-0000-0000-0000-000000000041'),
  ('00000000-0000-0000-0000-000000000042'),
  ('00000000-0000-0000-0000-000000000043');
insert into public.exercises(id, name, measurement_type, is_system)
  values ('10000000-0000-0000-0000-000000000041', 'Exercise', 'reps_only', true);
insert into public.profiles(id, first_name) values
  ('00000000-0000-0000-0000-000000000041', 'Parent'), ('00000000-0000-0000-0000-000000000042', 'Child');

set local role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000041', true);
do $$
declare v_house uuid; v_token text;
begin
  v_house := public.bloom_create_household('Example family');
  v_token := public.bloom_create_child_invite(v_house);
  perform set_config('bloom.test_house', v_house::text, true);
  perform set_config('bloom.test_invite', v_token, true);
  if has_table_privilege('authenticated', 'bloom_private.household_invites', 'SELECT') then raise exception 'Invite hashes are readable'; end if;
end; $$;

select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000042', true);
do $$
declare v_house uuid; v_plan uuid;
begin
  v_house := public.bloom_accept_child_invite(current_setting('bloom.test_invite'));
  if v_house <> current_setting('bloom.test_house')::uuid or public.bloom_accept_child_invite(current_setting('bloom.test_invite')) <> v_house then
    raise exception 'Invitation was not retry-safe';
  end if;
  insert into public.bloom_settings(user_id) values (auth.uid());
  v_plan := public.bloom_create_workout_plan('Child plan', '[{"exercise_id":"10000000-0000-0000-0000-000000000041","sets":1,"target":10}]'::jsonb);
  perform set_config('bloom.test_child_plan', v_plan::text, true);
  begin
    perform public.bloom_create_child_invite(v_house);
    raise exception using errcode = 'P0002', message = 'Child created an invitation';
  exception when raise_exception then
    if sqlerrm <> 'Parent access required' then raise; end if;
  end;
end; $$;

select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000043', true);
do $$ begin
  begin
    perform public.bloom_create_plan_for_user('00000000-0000-0000-0000-000000000042', 'Intrusion', '[{"exercise_id":"10000000-0000-0000-0000-000000000041","sets":1,"target":10}]'::jsonb);
    raise exception using errcode = 'P0002', message = 'Outsider created a child plan';
  exception when raise_exception then
    if sqlerrm <> 'Family access required' then raise; end if;
  end;
  begin
    perform public.bloom_accept_child_invite(current_setting('bloom.test_invite'));
    raise exception using errcode = 'P0002', message = 'Invitation was used twice';
  exception when raise_exception then
    if sqlerrm <> 'Invalid or expired invitation' then raise; end if;
  end;
  if exists (select 1 from public.bloom_household_members where household_id = current_setting('bloom.test_house')::uuid)
    or exists (select 1 from public.bloom_workout_plans where id = current_setting('bloom.test_child_plan')::uuid)
    or exists (select 1 from public.bloom_family_members(current_setting('bloom.test_house')::uuid)) then
    raise exception 'An outsider can see family data';
  end if;
end; $$;

select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000041', true);
do $$
declare v_count integer; v_rule uuid; v_progress jsonb;
begin
  if (select count(*) from public.bloom_household_members where household_id = current_setting('bloom.test_house')::uuid) <> 2
    or not exists (select 1 from public.bloom_family_members(current_setting('bloom.test_house')::uuid) where display_name = 'Child')
    or not exists (select 1 from public.bloom_workout_plans where id = current_setting('bloom.test_child_plan')::uuid)
    or not exists (select 1 from public.bloom_plan_exercises where plan_id = current_setting('bloom.test_child_plan')::uuid) then
    raise exception 'Parent cannot see linked child data';
  end if;
  update public.bloom_settings set credit_mode = 'hard' where user_id = '00000000-0000-0000-0000-000000000042';
  get diagnostics v_count = row_count;
  if v_count <> 1 then raise exception 'Parent cannot update child settings'; end if;
  update public.bloom_workout_plans set title = 'Parent-edited plan' where id = current_setting('bloom.test_child_plan')::uuid;
  perform public.bloom_create_plan_for_user('00000000-0000-0000-0000-000000000042', 'Parent-created plan', '[{"exercise_id":"10000000-0000-0000-0000-000000000041","sets":1,"target":10}]'::jsonb);
  perform public.bloom_create_plan_for_user_scheduled('00000000-0000-0000-0000-000000000042', 'Parent-scheduled plan', '[{"exercise_id":"10000000-0000-0000-0000-000000000041","sets":1,"target":10}]'::jsonb, array[1,7]::smallint[]);
  if not exists (select 1 from public.bloom_workout_plans where user_id = '00000000-0000-0000-0000-000000000042' and title = 'Parent-scheduled plan' and scheduled_days = array[1,7]::smallint[]) then
    raise exception 'Parent could not create a scheduled child plan';
  end if;
  perform public.bloom_update_plan_for_user_scheduled('00000000-0000-0000-0000-000000000042', current_setting('bloom.test_child_plan')::uuid, 'Parent-edited plan', '[{"exercise_id":"10000000-0000-0000-0000-000000000041","sets":2,"target":12}]'::jsonb, array[2,6]::smallint[]);
  if not exists (select 1 from public.bloom_workout_plans where id = current_setting('bloom.test_child_plan')::uuid and scheduled_days = array[2,6]::smallint[]) then
    raise exception 'Parent could not edit a child plan schedule';
  end if;
  v_progress := public.bloom_weekly_plan_progress('00000000-0000-0000-0000-000000000042');
  if (v_progress->>'planned_workouts')::integer <> 4
    or (v_progress->>'completed_planned_workouts')::integer <> 0
    or (v_progress->>'scheduled_days')::integer <> 4
    or (v_progress->>'rest_days')::integer <> 3 then
    raise exception 'Parent could not read the child weekly schedule progress: %', v_progress;
  end if;
  insert into public.bloom_blocking_rules(user_id, platform, target_type, target_identifier)
    values ('00000000-0000-0000-0000-000000000042', 'android', 'website', 'example.com') returning id into v_rule;
  perform set_config('bloom.test_rule_id', v_rule::text, true);
  perform set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000042', true);
  if not exists (select 1 from public.bloom_blocking_rules where id = v_rule) then raise exception 'Child cannot read parent-set rules'; end if;
  update public.bloom_blocking_rules set target_identifier = 'other.example.com' where id = v_rule;
  get diagnostics v_count = row_count;
  if v_count <> 0 then raise exception 'Child changed a parent-set rule'; end if;
  delete from public.bloom_blocking_rules where id = v_rule;
  get diagnostics v_count = row_count;
  if v_count <> 0 then raise exception 'Child deleted a parent-set rule'; end if;
  begin
    insert into public.bloom_blocking_rules(user_id, platform, target_type, target_identifier)
      values ((select auth.uid()), 'android', 'app', 'com.example.app');
    raise exception using errcode = 'P0002', message = 'Child created a parent-set rule';
  exception when insufficient_privilege then null;
  end;
  perform set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000041', true);
  perform public.bloom_parent_adjust_credit('00000000-0000-0000-0000-000000000042', '60000000-0000-0000-0000-000000000041', 10, 'Bonus');
  perform public.bloom_parent_adjust_credit('00000000-0000-0000-0000-000000000042', '60000000-0000-0000-0000-000000000041', 10, 'Bonus');
  if public.bloom_parent_child_balance('00000000-0000-0000-0000-000000000042') <> 10 then raise exception 'Parent credit retry duplicated a grant'; end if;
  begin
    perform public.bloom_parent_adjust_credit('00000000-0000-0000-0000-000000000042', '60000000-0000-0000-0000-000000000041', 20, 'Bonus');
    raise exception using errcode = 'P0002', message = 'Adjustment request was reused with different amount';
  exception when raise_exception then
    if sqlerrm <> 'Adjustment request was already used' then raise; end if;
  end;
  perform public.bloom_parent_adjust_credit('00000000-0000-0000-0000-000000000042', '60000000-0000-0000-0000-000000000042', -3, 'Correction');
  if public.bloom_parent_child_balance('00000000-0000-0000-0000-000000000042') <> 7 then raise exception 'Parent credit deduction failed'; end if;
  begin
    perform public.bloom_parent_adjust_credit('00000000-0000-0000-0000-000000000042', '60000000-0000-0000-0000-000000000043', -8, 'Too much');
    raise exception using errcode = 'P0002', message = 'Parent overdrew child balance';
  exception when raise_exception then
    if sqlerrm <> 'Adjustment exceeds the child’s balance' then raise; end if;
  end;
  if has_column_privilege('authenticated', 'public.bloom_settings', 'user_id', 'UPDATE')
    or has_table_privilege('authenticated', 'public.bloom_credit_ledger', 'INSERT') then
    raise exception 'Parent can directly reassign ownership or write ledger entries';
  end if;
  perform public.bloom_leave_or_remove_child(current_setting('bloom.test_house')::uuid, '00000000-0000-0000-0000-000000000042');
  begin
    perform public.bloom_parent_adjust_credit('00000000-0000-0000-0000-000000000042', '60000000-0000-0000-0000-000000000044', 1, 'After removal');
    raise exception using errcode = 'P0002', message = 'Parent adjusted credits after removal';
  exception when raise_exception then
    if sqlerrm <> 'Parent access required' then raise; end if;
  end;
  if exists (select 1 from public.bloom_workout_plans where id = current_setting('bloom.test_child_plan')::uuid)
    or exists (select 1 from public.bloom_settings where user_id = '00000000-0000-0000-0000-000000000042')
    or exists (select 1 from public.bloom_blocking_rules where id = current_setting('bloom.test_rule_id')::uuid) then
    raise exception 'Parent retained access after child removal';
  end if;
end; $$;

rollback;
