begin;
insert into auth.users(id) values
 ('00000000-0000-0000-0000-000000000061'),
 ('00000000-0000-0000-0000-000000000062');
insert into public.bloom_settings(user_id, credit_mode, credit_timezone) values
 ('00000000-0000-0000-0000-000000000061', 'easy', 'UTC'),
 ('00000000-0000-0000-0000-000000000062', 'easy', 'UTC');
insert into public.bloom_credit_ledger(user_id, amount_minutes, entry_type, idempotency_key, expires_at) values
 ('00000000-0000-0000-0000-000000000061', 10, 'earned', 'usage-61-early', now() + interval '1 hour'),
 ('00000000-0000-0000-0000-000000000061', 20, 'earned', 'usage-61-late', now() + interval '2 hours'),
 ('00000000-0000-0000-0000-000000000062', 10, 'earned', 'usage-62-new', now() + interval '2 hours');
set local role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000061', true);
do $$
declare
  v_id uuid;
  v_retry uuid;
  v_ms bigint;
  v_access_ms bigint;
begin
  select session_id, reserved_ms, expiry_remaining_ms into v_id, v_ms, v_access_ms
    from public.bloom_start_usage_session('50000000-0000-0000-0000-000000000061',
      '70000000-0000-0000-0000-000000000061', 900000);
  if v_ms <> 600000 or v_access_ms < 599000 or public.bloom_credit_balance() <> 20 then
    raise exception 'Reservation did not isolate the earliest expiry bucket or reserve the access window';
  end if;
  select session_id into v_retry from public.bloom_start_usage_session('50000000-0000-0000-0000-000000000061',
    '70000000-0000-0000-0000-000000000061', 900000);
  if v_retry <> v_id then raise exception 'Retry created a duplicate reservation'; end if;
  select session_id, reserved_ms, expiry_remaining_ms into v_retry, v_ms, v_access_ms
    from public.bloom_verify_usage_grant(v_id, '70000000-0000-0000-0000-000000000061');
  if v_retry <> v_id or v_ms <> 600000 or v_access_ms <= 0 or v_access_ms > v_ms then
    raise exception 'Read-only grant did not match the active reservation';
  end if;
  if public.bloom_credit_balance() <> 20 then raise exception 'Verification changed the balance'; end if;
  begin
    perform public.bloom_verify_usage_grant(v_id, '70000000-0000-0000-0000-000000000062');
    raise exception using errcode = 'P0002', message = 'Wrong device verified reservation';
  exception when raise_exception then
    if sqlerrm <> 'Screen-time reservation unavailable' then raise; end if;
  end;
  perform set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000062', true);
  begin
    perform public.bloom_verify_usage_grant(v_id, '70000000-0000-0000-0000-000000000061');
    raise exception using errcode = 'P0002', message = 'Other account verified reservation';
  exception when raise_exception then
    if sqlerrm <> 'Screen-time reservation unavailable' then raise; end if;
  end;
  perform set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000061', true);
  begin
    perform public.bloom_start_usage_session('50000000-0000-0000-0000-000000000061',
      '70000000-0000-0000-0000-000000000062', 900000);
    raise exception using errcode = 'P0002', message = 'Another device reused the reservation';
  exception when raise_exception then
    if sqlerrm <> 'Screen-time reservation belongs to another device' then raise; end if;
  end;
  begin
    perform public.bloom_start_usage_session('50000000-0000-0000-0000-000000000061',
      '70000000-0000-0000-0000-000000000061', 60000);
    raise exception using errcode = 'P0002', message = 'Reservation request changed';
  exception when raise_exception then
    if sqlerrm <> 'Screen-time reservation request was already used' then raise; end if;
  end;
  begin
    perform public.bloom_start_usage_session('50000000-0000-0000-0000-000000000064',
      '70000000-0000-0000-0000-000000000064', 60000);
    raise exception using errcode = 'P0002', message = 'A second device reserved the same account';
  exception when raise_exception then
    if sqlerrm <> 'A screen-time reservation is already active on another device' then raise; end if;
  end;
  begin
    update public.bloom_settings set credit_mode = 'hard' where user_id = auth.uid();
    raise exception using errcode = 'P0002', message = 'Mode changed during active access';
  exception when raise_exception then
    if sqlerrm <> 'Stop the active screen-time session before changing these settings' then raise; end if;
  end;
  perform set_config('bloom.usage_id', v_id::text, true);
end;
$$;

-- Settlement must ignore both a forged low duration and a forged high one.
select pg_sleep(1.1);
do $$
declare
  v_id uuid := current_setting('bloom.usage_id')::uuid;
  v_used bigint;
  v_balance numeric;
  v_spent numeric;
begin
  perform public.bloom_finish_usage_session(v_id, '70000000-0000-0000-0000-000000000061', 0);
  begin
    perform public.bloom_verify_usage_grant(v_id, '70000000-0000-0000-0000-000000000061');
    raise exception using errcode = 'P0002', message = 'Settled reservation verified';
  exception when raise_exception then
    if sqlerrm <> 'Screen-time reservation unavailable' then raise; end if;
  end;
  select used_ms into v_used from public.bloom_usage_sessions where id = v_id;
  if v_used < 1000 or v_used >= 10000 then raise exception 'Server elapsed time was not used for settlement: %', v_used; end if;
  perform public.bloom_finish_usage_session(v_id, '70000000-0000-0000-0000-000000000061', 600000);
  perform public.bloom_finish_usage_session(v_id, '70000000-0000-0000-0000-000000000061');
  select -amount_minutes into v_spent from public.bloom_credit_ledger where idempotency_key = 'usage:' || v_id::text;
  if v_spent <> trunc(v_used::numeric / 60000, 4) then raise exception 'Server debit did not match measured elapsed time'; end if;
  select public.bloom_credit_balance() into v_balance;
  if v_balance <> 30 - v_spent then raise exception 'Settled balance was not debited exactly once'; end if;
  if (select count(*) from public.bloom_credit_ledger where idempotency_key = 'usage:' || v_id::text) <> 1 then
    raise exception 'Settlement created a duplicate expense';
  end if;
  perform set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000062', true);
  begin
    perform public.bloom_finish_usage_session(v_id, '70000000-0000-0000-0000-000000000061');
    raise exception using errcode = 'P0002', message = 'Another account settled reservation';
  exception when raise_exception then
    if sqlerrm <> 'Screen-time reservation not found' then raise; end if;
  end;
end;
$$;

-- An expired access window is settled from server time before a new window is
-- admitted; inactivity and app closure do not pause the elapsed window.
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000061', true);
do $$
declare
  v_first uuid;
  v_second uuid;
  v_used bigint;
  v_remaining bigint;
begin
  select session_id into v_first from public.bloom_start_usage_session('50000000-0000-0000-0000-000000000065',
    '70000000-0000-0000-0000-000000000065', 1000);
  perform pg_sleep(1.2);
  select expiry_remaining_ms into v_remaining from public.bloom_verify_usage_grant(v_first,
    '70000000-0000-0000-0000-000000000065');
  if v_remaining <> 0 or (select settled_at from public.bloom_usage_sessions where id = v_first) is not null then
    raise exception 'Verification altered or reopened an expired session';
  end if;
  select session_id into v_second from public.bloom_start_usage_session('50000000-0000-0000-0000-000000000066',
    '70000000-0000-0000-0000-000000000065', 1000);
  select used_ms into v_used from public.bloom_usage_sessions where id = v_first;
  if v_used <> 1000 or (select settled_at from public.bloom_usage_sessions where id = v_first) is null then
    raise exception 'Expired access window was not settled at its server-side limit';
  end if;
  perform public.bloom_finish_usage_session(v_second, '70000000-0000-0000-0000-000000000065');
end;
$$;

do $$
begin
  if to_regprocedure('public.bloom_finish_usage_session(uuid,uuid)') is null
     or to_regprocedure('public.bloom_finish_usage_session(uuid,uuid,bigint)') is null then
    raise exception 'Server-timed finish RPC is missing';
  end if;
  if has_function_privilege('anon', 'public.bloom_verify_usage_grant(uuid,uuid)', 'execute')
     or not has_function_privilege('authenticated', 'public.bloom_verify_usage_grant(uuid,uuid)', 'execute') then
    raise exception 'Read-only grant verifier has incorrect execution privileges';
  end if;
  if to_regprocedure('bloom_private.finish_usage_session(uuid,uuid,bigint)') is not null then
    raise exception 'Client-controlled private settlement function remains callable';
  end if;
end;
$$;
rollback;
