begin;

insert into auth.users(id) values
  ('00000000-0000-0000-0000-000000000021'), ('00000000-0000-0000-0000-000000000022'),
  ('00000000-0000-0000-0000-000000000023'), ('00000000-0000-0000-0000-000000000024'),
  ('00000000-0000-0000-0000-000000000025'), ('00000000-0000-0000-0000-000000000026');
insert into public.bloom_settings(user_id, credit_mode, credit_timezone, super_daily_cap_minutes) values
  ('00000000-0000-0000-0000-000000000021', 'hard', 'UTC', null),
  ('00000000-0000-0000-0000-000000000022', 'hard', 'UTC', null),
  ('00000000-0000-0000-0000-000000000023', 'hard', 'UTC', null),
  ('00000000-0000-0000-0000-000000000024', 'super_hard', 'UTC', 5),
  ('00000000-0000-0000-0000-000000000025', 'hard', 'UTC', null),
  ('00000000-0000-0000-0000-000000000026', 'hard', 'UTC', null);
insert into public.bloom_credit_ledger(user_id, amount_minutes, entry_type, idempotency_key, expires_at) values
  ('00000000-0000-0000-0000-000000000021', 70, 'earned', 'earned-21', now() + interval '3 hours'),
  ('00000000-0000-0000-0000-000000000022', 1, 'earned', 'earned-22-early', now() + interval '1 hour'),
  ('00000000-0000-0000-0000-000000000022', 69, 'earned', 'earned-22-late', now() + interval '2 hours'),
  ('00000000-0000-0000-0000-000000000023', 70, 'earned', 'earned-23', now() + interval '3 hours'),
  ('00000000-0000-0000-0000-000000000024', 70, 'earned', 'earned-24', now() + interval '3 hours'),
  ('00000000-0000-0000-0000-000000000024', -4, 'spent', 'spent-24', now() + interval '3 hours'),
  ('00000000-0000-0000-0000-000000000025', 1, 'earned', 'earned-25-early', now() + interval '1 hour'),
  ('00000000-0000-0000-0000-000000000025', -1, 'spent', 'spent-25-early', now() + interval '1 hour'),
  ('00000000-0000-0000-0000-000000000025', 69, 'earned', 'earned-25-late', now() + interval '2 hours'),
  ('00000000-0000-0000-0000-000000000026', 70, 'earned', 'earned-26', now() + interval '3 hours'),
  ('00000000-0000-0000-0000-000000000026', -10, 'spent', 'spent-26', now() + interval '3 hours');
insert into public.bloom_credit_sessions(user_id, request_id, mode, started_at, ends_at, expires_at)
  values ('00000000-0000-0000-0000-000000000023', '50000000-0000-0000-0000-000000000023',
    'hard', now() - interval '2 minutes', now() - interval '1 minute', now() + interval '3 hours');

set local role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000021', true);
do $$
declare v_session uuid; v_retry uuid; v_start timestamptz; v_end timestamptz;
begin
  select session_id, session_started_at, session_ends_at into v_session, v_start, v_end
    from public.bloom_start_credit_session('50000000-0000-0000-0000-000000000021', 30);
  perform set_config('bloom.test_credit_session', v_session::text, true);
  if extract(epoch from v_end - v_start) > 600 then raise exception 'Hard mode exceeded one seventh of weekly earnings'; end if;
  select session_id into v_retry from public.bloom_start_credit_session('50000000-0000-0000-0000-000000000021', 30);
  if v_retry <> v_session then raise exception 'Retry created a duplicate session'; end if;
  begin
    perform public.bloom_start_credit_session('50000000-0000-0000-0000-000000000099', 1);
    raise exception using errcode = 'P0002', message = 'A second countdown started';
  exception when raise_exception then
    if sqlerrm <> 'A screen-time session is already running' then raise; end if;
  end;
  begin
    update public.bloom_settings set credit_mode = 'easy' where user_id = auth.uid();
    raise exception using errcode = 'P0002', message = 'Mode changed during countdown';
  exception when raise_exception then
    if sqlerrm <> 'Stop the active screen-time session before changing these settings' then raise; end if;
  end;
  perform public.bloom_stop_credit_session(v_session);
  perform public.bloom_stop_credit_session(v_session);
  if (select count(*) from public.bloom_credit_ledger where idempotency_key = 'countdown:' || v_session::text) > 1 then
    raise exception 'Stopping twice duplicated a debit';
  end if;
  update public.bloom_settings set credit_mode = 'easy' where user_id = auth.uid();
  begin
    perform public.bloom_start_credit_session('50000000-0000-0000-0000-000000000098', 1);
    raise exception using errcode = 'P0002', message = 'Unsupported actual-use mode started';
  exception when raise_exception then
    if sqlerrm <> 'Actual-use tracking is not available yet' then raise; end if;
  end;
end; $$;

select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000022', true);
do $$
declare v_session uuid; v_start timestamptz; v_end timestamptz;
begin
  begin
    perform public.bloom_stop_credit_session(current_setting('bloom.test_credit_session')::uuid);
    raise exception using errcode = 'P0002', message = 'Another account stopped a countdown';
  exception when raise_exception then
    if sqlerrm <> 'Screen-time session not found' then raise; end if;
  end;
  select session_id, session_started_at, session_ends_at into v_session, v_start, v_end
    from public.bloom_start_credit_session('50000000-0000-0000-0000-000000000022', 20);
  if extract(epoch from v_end - v_start) > 60 then raise exception 'Countdown exceeded earliest expiry bucket'; end if;
  perform public.bloom_stop_credit_session(v_session);
end; $$;

select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000023', true);
do $$
declare v_session uuid;
begin
  if public.bloom_credit_balance() <> 69 then raise exception 'Ended, unsettled countdown was not charged'; end if;
  select session_id into v_session from public.bloom_start_credit_session('50000000-0000-0000-0000-000000000033', 1);
  if public.bloom_credit_balance() <> 69 then raise exception 'Settling changed the balance'; end if;
  if not exists (select 1 from public.bloom_credit_ledger where idempotency_key like 'countdown:%' and amount_minutes = -1) then
    raise exception 'Ended countdown was not settled';
  end if;
  perform public.bloom_stop_credit_session(v_session);
end; $$;

select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000024', true);
do $$
declare v_session uuid; v_start timestamptz; v_end timestamptz;
begin
  select session_id, session_started_at, session_ends_at into v_session, v_start, v_end
    from public.bloom_start_credit_session('50000000-0000-0000-0000-000000000024', 10);
  if extract(epoch from v_end - v_start) > 60 then raise exception 'Super hard daily cap was exceeded'; end if;
  perform public.bloom_stop_credit_session(v_session);
end; $$;

select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000025', true);
do $$
declare v_session uuid; v_expiry timestamptz;
begin
  select session_id into v_session from public.bloom_start_credit_session('50000000-0000-0000-0000-000000000025', 5);
  select expires_at into v_expiry from public.bloom_credit_sessions where id = v_session;
  if v_expiry <> (select expires_at from public.bloom_credit_ledger where idempotency_key = 'earned-25-late') then
    raise exception 'Already-spent expiry bucket was reused';
  end if;
  perform public.bloom_stop_credit_session(v_session);
end; $$;

-- A positive shared balance does not bypass the already exhausted daily limit.
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000026', true);
do $$
begin
  if public.bloom_credit_balance() <> 60 then raise exception 'Expected a positive remaining balance'; end if;
  begin
    perform public.bloom_start_enforced_credit_session(
      '50000000-0000-0000-0000-000000000026', '70000000-0000-0000-0000-000000000026', 1);
    raise exception using errcode = 'P0002', message = 'Exhausted daily allowance started a countdown';
  exception when raise_exception then
    if sqlerrm <> 'No screen time is available for today' then raise; end if;
  end;
end; $$;

rollback;
