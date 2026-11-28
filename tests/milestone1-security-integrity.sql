begin;

-- M1 Milestone 1 security & integrity regression suite
insert into auth.users (id) values
  ('e1000000-0000-4000-8000-000000000001'), -- parent
  ('e1000000-0000-4000-8000-000000000002'), -- invited child
  ('e1000000-0000-4000-8000-000000000003'), -- personal user (billing deletion & revocation)
  ('e1000000-0000-4000-8000-000000000004'); -- refund staff / searchable test

insert into public.bloom_households (id, owner_user_id, name) values
  ('e1000000-0000-4000-8001-000000000001', 'e1000000-0000-4000-8000-000000000001', 'M1 Family');

insert into public.bloom_household_members (household_id, user_id, role) values
  ('e1000000-0000-4000-8001-000000000001', 'e1000000-0000-4000-8000-000000000001', 'parent'),
  ('e1000000-0000-4000-8001-000000000001', 'e1000000-0000-4000-8000-000000000002', 'child');

insert into public.bloom_settings (user_id) values
  ('e1000000-0000-4000-8000-000000000002')
on conflict do nothing;

-- M1-03: Invited (non-managed) child cannot update bloom_settings directly.
do $$
declare
  v_updated integer;
begin
  perform set_config('request.jwt.claim.sub', 'e1000000-0000-4000-8000-000000000002', true);
  perform set_config('request.jwt.claims', jsonb_build_object(
    'sub', 'e1000000-0000-4000-8000-000000000002',
    'session_id', 'e1000000-0000-4000-8002-000000000002'
  )::text, true);
  set local role authenticated;
  update public.bloom_settings set credits_enabled = false
    where user_id = 'e1000000-0000-4000-8000-000000000002';
  get diagnostics v_updated = row_count;
  reset role;
  if v_updated <> 0 then
    raise exception 'M1-03 failed: child updated own bloom_settings directly';
  end if;
end;
$$;

-- M1-04: parent_adjust_credit settles expired bloom_usage_sessions before computing balance.
do $$
declare
  v_usage_id uuid := 'e1000000-0000-4000-8003-000000000001';
  v_settled timestamptz;
begin
  insert into public.bloom_credit_ledger (user_id, amount_minutes, entry_type, idempotency_key, expires_at)
  values ('e1000000-0000-4000-8000-000000000002', 20, 'adjustment', 'm1-04-seed', now() + interval '5 days');

  insert into public.bloom_usage_sessions (id, user_id, request_id, requested_ms, reserved_ms, started_at, expires_at)
  values (
    v_usage_id,
    'e1000000-0000-4000-8000-000000000002',
    'e1000000-0000-4000-8003-000000000002',
    600000,
    600000,
    now() - interval '15 minutes',
    now() - interval '5 minutes'
  );

  perform set_config('request.jwt.claim.sub', 'e1000000-0000-4000-8000-000000000001', true);
  perform set_config('request.jwt.claim.sub', 'e1000000-0000-4000-8000-000000000001', true);
  perform set_config('request.jwt.claims', jsonb_build_object(
    'sub', 'e1000000-0000-4000-8000-000000000001'
  )::text, true);
  perform bloom_private.parent_adjust_credit(
    'e1000000-0000-4000-8000-000000000002',
    'e1000000-0000-4000-8003-000000000003',
    -5,
    'M1-04 check'
  );

  select settled_at into v_settled from public.bloom_usage_sessions where id = v_usage_id;
  if v_settled is null then
    raise exception 'M1-04 failed: expired usage session was not settled before parent_adjust_credit';
  end if;
end;
$$;

-- M1-05: complete_workout rejects implausible duration_seconds and rep pace.
do $$
declare
  v_ex_time uuid := 'e1000000-0000-4000-8004-000000000001';
  v_ex_reps uuid := 'e1000000-0000-4000-8004-000000000002';
  v_sess_time uuid := 'e1000000-0000-4000-8004-000000000011';
  v_sess_reps uuid := 'e1000000-0000-4000-8004-000000000012';
  v_failed boolean := false;
begin
  insert into public.bloom_workout_sessions (id, user_id, plan_snapshot, started_at) values
    (v_sess_time, 'e1000000-0000-4000-8000-000000000003',
      jsonb_build_array(jsonb_build_object('exercise_id', v_ex_time, 'measurement_type', 'time_only')),
      now() - interval '30 seconds'),
    (v_sess_reps, 'e1000000-0000-4000-8000-000000000004',
      jsonb_build_array(jsonb_build_object('exercise_id', v_ex_reps, 'measurement_type', 'reps_only')),
      now() - interval '10 seconds');

  perform set_config('request.jwt.claim.sub', 'e1000000-0000-4000-8000-000000000003', true);
  perform set_config('request.jwt.claims', jsonb_build_object(
    'sub', 'e1000000-0000-4000-8000-000000000003'
  )::text, true);

  begin
    perform * from bloom_private.complete_workout(v_sess_time, jsonb_build_array(
      jsonb_build_object('exercise_id', v_ex_time, 'sets_completed', 1, 'duration_seconds', 3600)
    ));
  exception when others then
    v_failed := true;
  end;
  if not v_failed then
    raise exception 'M1-05 failed: accepted 3600s workout after 30s elapsed';
  end if;

  perform set_config('request.jwt.claim.sub', 'e1000000-0000-4000-8000-000000000004', true);
  perform set_config('request.jwt.claims', jsonb_build_object(
    'sub', 'e1000000-0000-4000-8000-000000000004'
  )::text, true);

  v_failed := false;
  begin
    perform * from bloom_private.complete_workout(v_sess_reps, jsonb_build_array(
      jsonb_build_object('exercise_id', v_ex_reps, 'sets_completed', 5, 'reps_completed', 500)
    ));
  exception when others then
    v_failed := true;
  end;
  if not v_failed then
    raise exception 'M1-05 failed: accepted 2500 reps after 10s elapsed';
  end if;
end;
$$;

-- M1-07 + M1-20 + M1-26: Billing deletion gate, seat cleanup trigger, and refund self-approval guard.
do $$
declare
  v_prod uuid := 'e1000000-0000-4000-8005-000000000001';
  v_hh_prod uuid := 'e1000000-0000-4000-8005-000000000002';
  v_sub_personal uuid := 'e1000000-0000-4000-8005-000000000011';
  v_sub_hh uuid := 'e1000000-0000-4000-8005-000000000012';
  v_res jsonb;
  v_charge uuid := 'e1000000-0000-4000-8005-000000000021';
  v_refund uuid := 'e1000000-0000-4000-8005-000000000022';
  v_self_denied boolean := false;
begin
  insert into public.bloom_subscription_products (id, plan_id, scope, billing_period, provider, provider_product_id, active, weekly_credits, seat_limit, currency, price_minor)
  values
    (v_prod, 'basic', 'individual', 'month', 'tap', 'm1_personal_month', true, 4, 1, 'USD', 1000),
    (v_hh_prod, 'basic', 'household', 'month', 'tap', 'm1_hh_month', true, 4, 2, 'USD', 1500);

  insert into public.bloom_subscriptions (id, payer_user_id, product_id, provider_subscription_id, billing_provider, status, cancel_at_period_end, activated_at, current_period_start, current_period_end)
  values
    (v_sub_personal, 'e1000000-0000-4000-8000-000000000003', v_prod, 'm1-sub-personal', 'tap', 'active', false, now() - interval '1 day', now() - interval '1 day', now() + interval '29 days');

  insert into public.bloom_subscriptions (id, payer_user_id, household_id, product_id, provider_subscription_id, billing_provider, status, cancel_at_period_end, activated_at, current_period_start, current_period_end)
  values
    (v_sub_hh, 'e1000000-0000-4000-8000-000000000001', 'e1000000-0000-4000-8001-000000000001', v_hh_prod, 'm1-sub-hh', 'tap', 'active', false, now() - interval '1 day', now() - interval '1 day', now() + interval '29 days');

  -- M1-07: Active auto-renewing Tap sub blocks deletion with needs_billing_cancellation.
  v_res := bloom_private.request_account_deletion('e1000000-0000-4000-8000-000000000003', 'e1000000-0000-4000-8000-000000000003');
  if v_res->>'status' <> 'needs_billing_cancellation' then
    raise exception 'M1-07 failed: expected needs_billing_cancellation, got %', v_res->>'status';
  end if;

  update public.bloom_subscriptions set cancel_at_period_end = true where id = v_sub_personal;
  v_res := bloom_private.request_account_deletion('e1000000-0000-4000-8000-000000000003', 'e1000000-0000-4000-8000-000000000003');
  if v_res->>'status' <> 'queued' then
    raise exception 'M1-07 failed: expected queued after cancellation, got %', v_res->>'status';
  end if;

  -- M1-20: Deleting household member cleans up their billing seat.
  insert into bloom_private.billing_seats (subscription_id, profile_id)
  values (v_sub_hh, 'e1000000-0000-4000-8000-000000000002')
  on conflict do nothing;

  delete from public.bloom_household_members
  where household_id = 'e1000000-0000-4000-8001-000000000001'
    and user_id = 'e1000000-0000-4000-8000-000000000002';

  if exists (
    select 1 from bloom_private.billing_seats
    where subscription_id = v_sub_hh and profile_id = 'e1000000-0000-4000-8000-000000000002'
  ) then
    raise exception 'M1-20 failed: seat remained after household member removal';
  end if;

  -- M1-26: Refund staff cannot approve their own refund.
  insert into bloom_private.billing_refund_staff values ('e1000000-0000-4000-8000-000000000004') on conflict do nothing;
  insert into bloom_private.tap_attempts (id, payer, product_id, subscription_id, kind, state, currency, amount_minor, recurring_minor, provider_ref)
  values (v_charge, 'e1000000-0000-4000-8000-000000000004', v_prod, v_sub_personal, 'initial', 'captured', 'USD', 1000, 1000, 'chg_m1_self');
  insert into bloom_private.tap_refunds (id, charge_id, payer, amount_minor, state, reason)
  values (v_refund, v_charge, 'e1000000-0000-4000-8000-000000000004', 500, 'requested', 'test');

  begin
    perform public.bloom_billing_tap(
      'e1000000-0000-4000-8000-000000000004',
      'refund_decision',
      jsonb_build_object('id', v_refund, 'state', 'approved', 'amount_minor', 500, 'note', 'self')
    );
  exception when others then
    if sqlerrm like '%Another reviewer must decide this refund%' then
      v_self_denied := true;
    end if;
  end;
  if not v_self_denied then
    raise exception 'M1-26 failed: staff member approved their own refund';
  end if;
end;
$$;

-- M1-09: Dead-lettered webhooks (webhook_attempts >= 12) are excluded from bloom_claim_billing_webhooks.
do $$
declare
  v_dead uuid := 'e1000000-0000-4000-8006-000000000001';
begin
  insert into public.bloom_billing_events (id, provider, provider_event_id, event_type, webhook_attempts, processed_at)
  values (v_dead, 'tap', 'm1-dead-webhook', 'CAPTURED', 12, null);

  if exists (select 1 from public.bloom_claim_billing_webhooks() where id = v_dead) then
    raise exception 'M1-09 failed: claimed dead-letter webhook with 12 attempts';
  end if;
end;
$$;

-- M1-11: Revoked auth session cannot read bloom_profiles or bloom_profile_accounts.
do $$
declare
  v_revoked_sid uuid := 'e1000000-0000-4000-8007-000000000001';
  v_count integer;
begin
  insert into bloom_private.revoked_auth_sessions (session_id, profile_id)
  values (v_revoked_sid, 'e1000000-0000-4000-8000-000000000004');

  perform set_config('request.jwt.claim.sub', 'e1000000-0000-4000-8000-000000000004', true);
  perform set_config('request.jwt.claims', jsonb_build_object(
    'sub', 'e1000000-0000-4000-8000-000000000004',
    'session_id', v_revoked_sid::text
  )::text, true);
  set local role authenticated;
  select count(*) into v_count from public.bloom_profiles where id = 'e1000000-0000-4000-8000-000000000004';
  reset role;
  if v_count <> 0 then
    raise exception 'M1-11 failed: revoked session read bloom_profiles';
  end if;
end;
$$;

-- M1-21: search_public_profiles and get_public_profile require searchable = true.
do $$
begin
  insert into public.profiles (id, username)
  values ('e1000000-0000-4000-8000-000000000004', 'M1PrivateUser')
  on conflict (id) do update set username = excluded.username;

  insert into public.bloom_social_profiles (profile_id, display_name, searchable)
  values ('e1000000-0000-4000-8000-000000000004', 'M1PrivateUser', false)
  on conflict (profile_id) do update set searchable = false, display_name = 'M1PrivateUser';

  perform set_config('request.jwt.claim.sub', 'e1000000-0000-4000-8000-000000000001', true);
  perform set_config('request.jwt.claims', jsonb_build_object(
    'sub', 'e1000000-0000-4000-8000-000000000001'
  )::text, true);

  if exists (select 1 from public.search_public_profiles('M1PrivateUser', 20)) then
    raise exception 'M1-21 failed: non-searchable profile returned by search_public_profiles';
  end if;
  if exists (select 1 from public.get_public_profile('e1000000-0000-4000-8000-000000000004')) then
    raise exception 'M1-21 failed: non-searchable profile returned by get_public_profile';
  end if;

  update public.bloom_social_profiles set searchable = true
  where profile_id = 'e1000000-0000-4000-8000-000000000004';

  if not exists (select 1 from public.search_public_profiles('M1PrivateUser', 20)) then
    raise exception 'M1-21 failed: searchable profile missing from search_public_profiles';
  end if;
end;
$$;

-- M1-22: leaderboard resets are available only to the scheduler service role.
do $$
begin
  if has_function_privilege('anon', 'public.finalize_and_reset_weekly_leaderboards()', 'EXECUTE')
    or has_function_privilege('authenticated', 'public.finalize_and_reset_weekly_leaderboards()', 'EXECUTE') then
    raise exception 'M1-22 failed: client roles can execute the leaderboard reset';
  end if;
  if not has_function_privilege('service_role', 'public.finalize_and_reset_weekly_leaderboards()', 'EXECUTE') then
    raise exception 'M1-22 failed: service role cannot execute the leaderboard reset';
  end if;
  if has_function_privilege('anon', 'public.bloom_cancel_enforced_credit_session(uuid,uuid)', 'EXECUTE') then
    raise exception 'M1-22 failed: anonymous role can cancel a credit session';
  end if;
end;
$$;

-- M1-23: website waitlist PII and token operations are server-role only.
do $$
declare
  v_signature text;
  v_table text;
begin
  foreach v_signature in array array[
    'public.bloom_website_consume_rate_limit(text,integer,integer)',
    'public.bloom_website_start_waitlist(text,text,uuid,boolean,boolean,boolean,text)',
    'public.bloom_website_confirm_waitlist(uuid,uuid)',
    'public.bloom_website_mark_waitlist_email_sent(uuid,uuid)',
    'public.bloom_website_start_management(text,uuid)',
    'public.bloom_website_manage(uuid,uuid,text,boolean,boolean,text)',
    'public.bloom_website_get_preferences(uuid,uuid)'
  ] loop
    if has_function_privilege('anon', v_signature, 'EXECUTE')
      or has_function_privilege('authenticated', v_signature, 'EXECUTE') then
      raise exception 'M1-23 failed: client role can execute %', v_signature;
    end if;
    if not has_function_privilege('service_role', v_signature, 'EXECUTE') then
      raise exception 'M1-23 failed: service role cannot execute %', v_signature;
    end if;
  end loop;

  foreach v_table in array array[
    'public.bloom_website_waitlist',
    'public.bloom_website_waitlist_events',
    'public.bloom_website_rate_limits'
  ] loop
    if has_table_privilege('anon', v_table, 'SELECT')
      or has_table_privilege('anon', v_table, 'INSERT')
      or has_table_privilege('anon', v_table, 'UPDATE')
      or has_table_privilege('anon', v_table, 'DELETE')
      or has_table_privilege('authenticated', v_table, 'SELECT')
      or has_table_privilege('authenticated', v_table, 'INSERT')
      or has_table_privilege('authenticated', v_table, 'UPDATE')
      or has_table_privilege('authenticated', v_table, 'DELETE') then
      raise exception 'M1-23 failed: client role can access %', v_table;
    end if;
  end loop;

  if exists (
    select 1 from pg_class
    where oid in (
      'public.bloom_website_waitlist'::regclass,
      'public.bloom_website_waitlist_events'::regclass,
      'public.bloom_website_rate_limits'::regclass
    ) and not relrowsecurity
  ) then
    raise exception 'M1-23 failed: row-level security is disabled for waitlist data';
  end if;
end;
$$;

rollback;
