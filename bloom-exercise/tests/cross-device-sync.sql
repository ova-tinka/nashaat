-- Synthetic integration fixture: model two devices using the same account.
-- Every record is rolled back at the end; no persistent test account is made.
begin;

insert into auth.users(id) values
  ('00000000-0000-0000-0000-000000000071'),
  ('00000000-0000-0000-0000-000000000072'),
  ('00000000-0000-0000-0000-000000000073');
insert into public.profiles(id, first_name, username) values
  ('00000000-0000-0000-0000-000000000071', 'Sync Parent', 'sync-parent'),
  ('00000000-0000-0000-0000-000000000072', 'Sync Child', 'sync-child'),
  ('00000000-0000-0000-0000-000000000073', 'Sync Outsider', 'sync-outsider');
insert into public.exercises(id, name, measurement_type, is_system) values
  ('10000000-0000-0000-0000-000000000071', 'Sync test push-ups', 'reps_only', true);

set local role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000071', true);
do $$
declare v_household uuid; v_invite text;
begin
  v_household := public.bloom_create_household('Synthetic cross-device family');
  v_invite := public.bloom_create_child_invite(v_household);
  perform set_config('bloom.sync_household', v_household::text, true);
  perform set_config('bloom.sync_invite', v_invite, true);
end;
$$;

select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000072', true);
do $$
declare v_plan uuid; v_session uuid;
begin
  perform public.bloom_accept_child_invite(current_setting('bloom.sync_invite'));
  insert into public.bloom_settings(user_id, credit_mode, credit_timezone)
    values (auth.uid(), 'easy', 'UTC');
  -- Device A creates a workout. Device B later observes and completes it.
  v_plan := public.bloom_create_workout_plan('Sync workout', '[
    {"exercise_id":"10000000-0000-0000-0000-000000000071","sets":2,"target":8}
  ]'::jsonb);
  select session_id into v_session from public.bloom_start_workout(v_plan);
  perform set_config('bloom.sync_plan', v_plan::text, true);
  perform set_config('bloom.sync_workout', v_session::text, true);
end;
$$;

-- Device B reads shared state and updates a shared setting.
do $$
begin
  if not exists (select 1 from public.bloom_workout_plans
      where id = current_setting('bloom.sync_plan')::uuid and title = 'Sync workout')
    or not exists (select 1 from public.bloom_workout_sessions
      where id = current_setting('bloom.sync_workout')::uuid and status = 'in_progress') then
    raise exception 'A second device could not read the shared workout state';
  end if;
  update public.bloom_settings set credit_mode = 'hard', credit_timezone = 'Asia/Qatar'
    where user_id = auth.uid();
end;
$$;

-- Device A must reload Device B's preference from the server.
do $$
begin
  if not exists (select 1 from public.bloom_settings
    where user_id = auth.uid() and credit_mode = 'hard' and credit_timezone = 'Asia/Qatar') then
    raise exception 'A setting saved on one device was not visible to another';
  end if;
end;
$$;

-- Parent grants synthetic credits and rules for Android and macOS.
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000071', true);
do $$
begin
  perform public.bloom_parent_adjust_credit('00000000-0000-0000-0000-000000000072',
    '60000000-0000-0000-0000-000000000071', 12, 'Synthetic cross-device balance');
  insert into public.bloom_blocking_rules(user_id, platform, target_type, target_identifier)
    values
      ('00000000-0000-0000-0000-000000000072', 'android', 'website', 'example.test'),
      ('00000000-0000-0000-0000-000000000072', 'android', 'app', 'com.example.synthetic'),
      ('00000000-0000-0000-0000-000000000072', 'macos', 'website', 'example.test'),
      ('00000000-0000-0000-0000-000000000072', 'macos', 'app', 'com.example.synthetic');
end;
$$;

select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000072', true);
do $$
declare v_session uuid; v_remaining bigint;
begin
  if public.bloom_credit_balance() <> 12 then raise exception 'Synthetic shared credit balance did not persist'; end if;
  if (select count(*) from public.bloom_blocking_rules where platform = 'android' and enabled) <> 2
    or (select count(*) from public.bloom_blocking_rules where platform = 'macos' and enabled) <> 2 then
    raise exception 'A device could not read its own platform rules';
  end if;
  perform public.bloom_complete_workout(current_setting('bloom.sync_workout')::uuid, '[
    {"exercise_id":"10000000-0000-0000-0000-000000000071","sets_completed":2,"reps_completed":8}
  ]'::jsonb);
  if not exists (select 1 from public.bloom_workout_sessions
    where id = current_setting('bloom.sync_workout')::uuid and status = 'completed'
      and exercise_results->0->>'reps_completed' = '8') then
    raise exception 'A workout completed on one device was not saved for the account';
  end if;

  -- Balance is shared; an active countdown remains bound to its originating device.
  select session_id, remaining_ms into v_session, v_remaining
    from public.bloom_start_enforced_credit_session(
      '50000000-0000-0000-0000-000000000071',
      '70000000-0000-0000-0000-000000000071', 5);
  if v_remaining <= 0 then raise exception 'Synthetic countdown did not start'; end if;
  if (select session_id from public.bloom_start_enforced_credit_session(
      '50000000-0000-0000-0000-000000000071',
      '70000000-0000-0000-0000-000000000071', 5)) <> v_session then
    raise exception 'A same-device retry created a second countdown';
  end if;
  begin
    perform public.bloom_start_enforced_credit_session(
      '50000000-0000-0000-0000-000000000071',
      '70000000-0000-0000-0000-000000000072', 5);
    raise exception using errcode = 'P0002', message = 'Another device took over a countdown';
  exception when raise_exception then
    if sqlerrm <> 'Screen-time session belongs to another device or request' then raise; end if;
  end;
end;
$$;

select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000073', true);
do $$
begin
  if exists (select 1 from public.bloom_workout_plans where title = 'Sync workout')
    or exists (select 1 from public.bloom_blocking_rules where target_identifier = 'example.test')
    or public.bloom_credit_balance() <> 0 then
    raise exception 'Synthetic data leaked to another account';
  end if;
end;
$$;

rollback;
