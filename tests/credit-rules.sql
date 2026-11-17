begin;

do $$ begin
  if bloom_private.credit_week_end('2026-10-31 20:59:00+00', 'Asia/Qatar') <> '2026-10-31 21:00:00+00'::timestamptz
    or bloom_private.credit_week_end('2026-10-31 21:00:00+00', 'Asia/Qatar') <> '2026-11-07 21:00:00+00'::timestamptz
    or bloom_private.credit_week_end('2026-11-01 04:01:00+00', 'America/New_York') <> '2026-11-08 05:00:00+00'::timestamptz then
    raise exception 'Sunday boundary or daylight-saving transition is incorrect';
  end if;
end; $$;

insert into auth.users(id) values ('00000000-0000-0000-0000-000000000011'), ('00000000-0000-0000-0000-000000000012');
insert into public.exercises(id, name, measurement_type, is_system) values
  ('10000000-0000-0000-0000-000000000011', 'Repetitions', 'reps_only', true),
  ('10000000-0000-0000-0000-000000000012', 'Timed', 'time_only', true);
insert into public.bloom_credit_ledger(user_id, amount_minutes, entry_type, idempotency_key, expires_at)
  values ('00000000-0000-0000-0000-000000000011', 12, 'earned', 'expired-fixture', now() - interval '1 second');
set local role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000011', true);

do $$
declare
  v_plan uuid;
  v_session uuid;
  v_amount numeric;
  v_expiry timestamptz;
  v_local timestamp;
begin
  insert into public.bloom_settings(user_id, credit_timezone) values (auth.uid(), 'Asia/Qatar');
  begin
    update public.bloom_settings set reps_per_award = 10 where user_id = auth.uid();
    raise exception using errcode = 'P0002', message = 'Partial rate accepted';
  exception when check_violation then null;
  end;
  begin
    update public.bloom_settings set credit_mode = 'super_hard' where user_id = auth.uid();
    raise exception using errcode = 'P0002', message = 'Super hard without cap accepted';
  exception when check_violation then null;
  end;
  begin
    update public.bloom_settings set credit_timezone = 'Not/A_Timezone' where user_id = auth.uid();
    raise exception using errcode = 'P0002', message = 'Invalid time zone accepted';
  exception when raise_exception then
    if sqlerrm <> 'Choose a valid time zone' then raise; end if;
  end;

  v_plan := public.bloom_create_workout_plan('Credit plan', '[
    {"exercise_id":"10000000-0000-0000-0000-000000000011","sets":3,"target":5},
    {"exercise_id":"10000000-0000-0000-0000-000000000012","sets":2,"target":60}
  ]'::jsonb);
  select session_id into v_session from public.bloom_start_workout(v_plan);
  perform public.bloom_complete_workout(v_session, '[{"exercise_id":"10000000-0000-0000-0000-000000000011","sets_completed":1,"reps_completed":5}]'::jsonb);
  if public.bloom_credit_balance() <> 0 then raise exception 'Unset rates earned credit'; end if;

  update public.bloom_settings set reps_per_award = 10, rep_award_minutes = 2,
    exercise_minutes_per_award = 5, time_award_minutes = 3,
    credit_mode = 'super_hard', super_daily_cap_minutes = 30 where user_id = auth.uid();
  select session_id into v_session from public.bloom_start_workout(v_plan);
  perform public.bloom_complete_workout(v_session, '[
    {"exercise_id":"10000000-0000-0000-0000-000000000011","sets_completed":3,"reps_completed":5},
    {"exercise_id":"10000000-0000-0000-0000-000000000012","sets_completed":2,"duration_seconds":60}
  ]'::jsonb);
  select amount_minutes, expires_at into v_amount, v_expiry from public.bloom_credit_ledger where workout_session_id = v_session;
  if v_amount <> 4.2 or public.bloom_credit_balance() <> 4.2 then raise exception 'Incorrect earnings: %', v_amount; end if;
  if (select credits_earned_minutes from public.bloom_workout_sessions where id = v_session) <> 4.2 then raise exception 'Session earnings missing'; end if;
  v_local := v_expiry at time zone 'Asia/Qatar';
  if extract(isodow from v_local) <> 7 or v_local::time <> '00:00:00'::time or v_expiry <= now() then
    raise exception 'Weekly expiry was incorrect: %', v_expiry;
  end if;
  perform public.bloom_complete_workout(v_session, '[]'::jsonb);
  if (select count(*) from public.bloom_credit_ledger where workout_session_id = v_session) <> 1
     or public.bloom_credit_balance() <> 4.2 then raise exception 'Retry duplicated credits'; end if;

  update public.bloom_settings set credits_enabled = false where user_id = auth.uid();
  select session_id into v_session from public.bloom_start_workout(v_plan);
  perform public.bloom_complete_workout(v_session, '[{"exercise_id":"10000000-0000-0000-0000-000000000011","sets_completed":1,"reps_completed":10}]'::jsonb);
  if public.bloom_credit_balance() <> 4.2 then raise exception 'Credits were earned while disabled'; end if;
end;
$$;

select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000012', true);
do $$ begin
  if public.bloom_credit_balance() <> 0 or exists (select 1 from public.bloom_credit_ledger) then
    raise exception 'Another account can see credits';
  end if;
end; $$;

rollback;
