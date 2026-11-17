begin;
insert into auth.users(id) values ('00000000-0000-0000-0000-000000000051');
insert into public.bloom_settings(user_id, credit_mode, credit_timezone) values ('00000000-0000-0000-0000-000000000051', 'hard', 'UTC');
insert into public.bloom_credit_ledger(user_id, amount_minutes, entry_type, idempotency_key, expires_at)
  values ('00000000-0000-0000-0000-000000000051', 70, 'earned', 'enforced-51', now() + interval '1 day');
insert into auth.users(id) values ('00000000-0000-0000-0000-000000000052');
insert into public.bloom_settings(user_id, credit_mode, credit_timezone) values ('00000000-0000-0000-0000-000000000052', 'hard', 'UTC');
insert into public.bloom_credit_ledger(user_id, amount_minutes, entry_type, idempotency_key, expires_at) values
  ('00000000-0000-0000-0000-000000000052', 0.01, 'earned', 'enforced-small-52', now() + interval '1 day'),
  ('00000000-0000-0000-0000-000000000052', 70, 'earned', 'enforced-large-52', now() + interval '2 days');
insert into auth.users(id) values ('00000000-0000-0000-0000-000000000053');
insert into public.bloom_settings(user_id, credit_mode, credit_timezone) values ('00000000-0000-0000-0000-000000000053', 'hard', 'UTC');
insert into public.bloom_credit_ledger(user_id, amount_minutes, entry_type, idempotency_key, expires_at)
  values ('00000000-0000-0000-0000-000000000053', 70, 'earned', 'enforced-expiry-53', now() + interval '1 day');
set local role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000051', true);
do $$
declare v_id uuid; v_retry uuid; v_remaining bigint;
begin
  select session_id, remaining_ms into v_id, v_remaining
    from public.bloom_start_enforced_credit_session('50000000-0000-0000-0000-000000000051', '70000000-0000-0000-0000-000000000051', 2);
  if v_remaining < 1 or v_remaining > 120000 then raise exception 'Invalid remaining time'; end if;
  select session_id into v_retry from public.bloom_start_enforced_credit_session('50000000-0000-0000-0000-000000000051', '70000000-0000-0000-0000-000000000051', 2);
  if v_retry <> v_id then raise exception 'Retry created a second enforced session'; end if;
  select session_id, remaining_ms into v_retry, v_remaining from public.bloom_verify_countdown_grant(
    '50000000-0000-0000-0000-000000000051', '70000000-0000-0000-0000-000000000051');
  if v_retry <> v_id or v_remaining <= 0 or v_remaining > 120000 then raise exception 'Read-only countdown verification failed'; end if;
  if has_function_privilege('anon', 'public.bloom_verify_countdown_grant(uuid,uuid)', 'execute')
     or not has_function_privilege('authenticated', 'public.bloom_verify_countdown_grant(uuid,uuid)', 'execute') then
    raise exception 'Countdown verifier has incorrect execution privileges';
  end if;
  begin
    perform public.bloom_verify_countdown_grant('50000000-0000-0000-0000-000000000051', '70000000-0000-0000-0000-000000000052');
    raise exception using errcode = 'P0002', message = 'Wrong countdown device accepted';
  exception when raise_exception then
    if sqlerrm <> 'Screen-time session unavailable' then raise; end if;
  end;
  perform set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000052', true);
  begin
    perform public.bloom_verify_countdown_grant('50000000-0000-0000-0000-000000000051', '70000000-0000-0000-0000-000000000051');
    raise exception using errcode = 'P0002', message = 'Other countdown account accepted';
  exception when raise_exception then
    if sqlerrm <> 'Screen-time session unavailable' then raise; end if;
  end;
  perform set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000051', true);
  begin
    perform public.bloom_start_enforced_credit_session('50000000-0000-0000-0000-000000000051', '70000000-0000-0000-0000-000000000052', 2);
    raise exception using errcode = 'P0002', message = 'A second device reused the countdown';
  exception when raise_exception then
    if sqlerrm <> 'Screen-time session belongs to another device or request' then raise; end if;
  end;
  begin
    perform public.bloom_stop_credit_session(v_id);
    raise exception using errcode = 'P0002', message = 'Enforced session stopped early';
  exception when raise_exception then
    if sqlerrm <> 'This screen-time session runs until its scheduled end' then raise; end if;
  end;
  begin
    perform public.bloom_start_enforced_credit_session('50000000-0000-0000-0000-000000000052', '70000000-0000-0000-0000-000000000052', 2);
    raise exception using errcode = 'P0002', message = 'Second device started a session';
  exception when raise_exception then
    if sqlerrm <> 'A screen-time session is already running' then raise; end if;
  end;
end;
$$;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000052', true);
do $$
declare v_remaining bigint;
begin
  select remaining_ms into v_remaining
    from public.bloom_start_enforced_credit_session('50000000-0000-0000-0000-000000000053', '70000000-0000-0000-0000-000000000053', 2);
  if v_remaining < 1000 then raise exception 'A subsecond expiry bucket blocked usable credits'; end if;
end;
$$;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000053', true);
do $$
declare v_id uuid; v_remaining bigint; v_balance numeric;
begin
  select session_id, remaining_ms into v_id, v_remaining
    from public.bloom_start_enforced_credit_session('50000000-0000-0000-0000-000000000054', '70000000-0000-0000-0000-000000000054', 0.034);
  if v_remaining < 1 or v_remaining > 2000 then raise exception 'Short countdown duration was incorrect'; end if;
  perform pg_sleep(2.2);
  select remaining_ms into v_remaining from public.bloom_verify_countdown_grant(
    '50000000-0000-0000-0000-000000000054', '70000000-0000-0000-0000-000000000054');
  if v_remaining <> 0 then raise exception 'Expired countdown verified as active'; end if;
  begin
    perform public.bloom_start_enforced_credit_session('50000000-0000-0000-0000-000000000054', '70000000-0000-0000-0000-000000000054', 0.034);
    raise exception using errcode = 'P0002', message = 'Expired countdown was reusable';
  exception when raise_exception then
    if sqlerrm <> 'Screen-time session has ended' then raise; end if;
  end;
  -- The fixture runs in one transaction, so now() is frozen; explicitly settle
  -- after expiry before checking the ledger-backed balance.
  perform public.bloom_stop_credit_session(v_id);
  begin
    perform public.bloom_verify_countdown_grant('50000000-0000-0000-0000-000000000054', '70000000-0000-0000-0000-000000000054');
    raise exception using errcode = 'P0002', message = 'Settled countdown accepted';
  exception when raise_exception then
    if sqlerrm <> 'Screen-time session unavailable' then raise; end if;
  end;
  perform public.bloom_stop_credit_session(v_id);
  v_balance := public.bloom_credit_balance();
  if v_balance >= 70 or v_balance < 69.96 then raise exception 'Expired countdown debit was incorrect'; end if;
  if public.bloom_credit_balance() <> v_balance then raise exception 'Expired countdown was charged twice'; end if;
end;
$$;
rollback;
