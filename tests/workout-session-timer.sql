begin;
insert into auth.users(id) values
  ('00000000-0000-0000-0000-000000000091'),
  ('00000000-0000-0000-0000-000000000092');
insert into public.bloom_workout_sessions(id, user_id, plan_snapshot)
values ('90000000-0000-0000-0000-000000000091', '00000000-0000-0000-0000-000000000091',
  '[{"exercise_id":"10000000-0000-0000-0000-000000000091","measurement_type":"reps_only"}]');
insert into public.bloom_settings(user_id, credits_enabled) values ('00000000-0000-0000-0000-000000000091', false);

set local role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000092', true);
do $$ begin
  begin
    perform public.bloom_set_workout_timer('90000000-0000-0000-0000-000000000091', true);
    raise exception using errcode = 'P0002', message = 'Another user controlled the timer';
  exception when raise_exception then
    if sqlerrm <> 'Workout session not found' then raise; end if;
  end;
  if has_column_privilege('authenticated', 'public.bloom_workout_sessions', 'active_duration_seconds', 'UPDATE') then
    raise exception 'Clients can forge the timer';
  end if;
end $$;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000091', true);
select public.bloom_set_workout_timer('90000000-0000-0000-0000-000000000091', true);
select public.bloom_set_workout_timer('90000000-0000-0000-0000-000000000091', true);
reset role;
update public.bloom_workout_sessions set timer_started_at = clock_timestamp() - interval '120 seconds'
  where id = '90000000-0000-0000-0000-000000000091';
set local role authenticated;
select public.bloom_set_workout_timer('90000000-0000-0000-0000-000000000091', false);
select public.bloom_set_workout_timer('90000000-0000-0000-0000-000000000091', false);
do $$ declare v_seconds numeric; begin
  select active_duration_seconds into v_seconds from public.bloom_workout_sessions
    where id = '90000000-0000-0000-0000-000000000091' and timer_started_at is null;
  if v_seconds is null or v_seconds < 120 or v_seconds > 125 then raise exception 'Pause did not preserve active time: %', v_seconds; end if;
end $$;
select public.bloom_set_workout_timer('90000000-0000-0000-0000-000000000091', true);
reset role;
update public.bloom_workout_sessions set timer_started_at = clock_timestamp() - interval '30 seconds'
  where id = '90000000-0000-0000-0000-000000000091';
set local role authenticated;
select * from public.bloom_complete_workout('90000000-0000-0000-0000-000000000091',
  '[{"exercise_id":"10000000-0000-0000-0000-000000000091","sets_completed":1,"reps_completed":10}]');
do $$ declare v_seconds numeric; begin
  select active_duration_seconds into v_seconds from public.bloom_workout_sessions
    where id = '90000000-0000-0000-0000-000000000091' and timer_started_at is null;
  if v_seconds is null or v_seconds < 150 or v_seconds > 155 then raise exception 'Completion did not freeze timer: %', v_seconds; end if;
  perform public.bloom_complete_workout('90000000-0000-0000-0000-000000000091',
    '[{"exercise_id":"10000000-0000-0000-0000-000000000091","sets_completed":1,"reps_completed":10}]');
  if (select active_duration_seconds from public.bloom_workout_sessions where id = '90000000-0000-0000-0000-000000000091') <> v_seconds then
    raise exception 'Retry changed the recorded duration';
  end if;
  begin
    perform public.bloom_set_workout_timer('90000000-0000-0000-0000-000000000091', true);
    raise exception using errcode = 'P0002', message = 'Completed timer was restarted';
  exception when raise_exception then
    if sqlerrm <> 'Workout is no longer active' then raise; end if;
  end;
end $$;
rollback;
