begin;

alter table public.bloom_subscriptions
  drop constraint bloom_subscriptions_payer_user_id_fkey,
  add constraint bloom_subscriptions_payer_profile_fkey foreign key (payer_user_id)
    references public.bloom_profiles(id) on delete restrict;

-- Legacy household rows retain their existing read behavior until mapped to a billing provider.
drop policy bloom_subscriptions_read on public.bloom_subscriptions;
create policy bloom_subscriptions_read on public.bloom_subscriptions for select to authenticated
  using (payer_user_id = (select bloom_private.current_profile_id())
    or (bloom_private.is_household_member(household_id) and exists (
      select 1 from public.bloom_subscription_products p where p.id = product_id
        and p.provider not in ('app_store', 'play_store', 'tap')
    )));

alter table public.bloom_subscription_products
  add column weekly_credits integer check (weekly_credits > 0),
  add column seat_limit integer check (seat_limit > 0),
  add column currency text check (currency ~ '^[A-Z]{3}$'),
  add column price_minor integer check (price_minor > 0);

alter table public.bloom_subscriptions
  add column billing_provider text,
  add column activated_at timestamptz,
  add column grace_until timestamptz,
  add column next_product_id uuid references public.bloom_subscription_products(id),
  add constraint bloom_subscription_provider_identity unique (billing_provider, provider_subscription_id);

create table bloom_private.billing_config (
  singleton boolean primary key default true check (singleton),
  checkout_enabled boolean not null default false,
  notice_at timestamptz,
  enforcement_at timestamptz,
  transition_weekly_credits integer not null default 10 check (transition_weekly_credits > 0),
  check (enforcement_at is null or (notice_at is not null
    and enforcement_at >= notice_at + interval '720 hours'))
);
insert into bloom_private.billing_config (singleton) values (true);

create table bloom_private.billing_feature_costs (
  feature text primary key,
  credits integer not null check (credits > 0)
);
insert into bloom_private.billing_feature_costs values
  ('coach_chat', 1), ('coach_weekly', 3), ('study_tutor', 1),
  ('document_help', 3), ('mock_exam_assess', 3), ('read_reflection', 1), ('task_breakdown', 1);

create table bloom_private.billing_seats (
  subscription_id uuid not null references public.bloom_subscriptions(id) on delete cascade,
  profile_id uuid not null references public.bloom_profiles(id) on delete cascade,
  assigned_at timestamptz not null default clock_timestamp(),
  primary key (subscription_id, profile_id)
);
create index bloom_billing_seats_profile_idx on bloom_private.billing_seats(profile_id);

create table bloom_private.usage_credit_anchors (
  profile_id uuid primary key references public.bloom_profiles(id) on delete cascade,
  anchored_at timestamptz not null
);

alter table public.bloom_credit_ledger
  drop constraint bloom_credit_ledger_entry_type_check,
  drop constraint bloom_credit_ledger_check,
  alter column amount_minutes drop not null,
  alter column user_id drop not null,
  add column usage_profile_id uuid references public.bloom_profiles(id) on delete cascade,
  add column usage_credits integer check (usage_credits > 0),
  add column usage_window_at timestamptz,
  add column usage_status text check (usage_status in ('reserved', 'spent', 'released')),
  add column usage_feature text references bloom_private.billing_feature_costs(feature),
  add constraint bloom_credit_ledger_units check (
    (entry_type in ('earned', 'spent', 'expired', 'adjustment') and user_id is not null
      and usage_profile_id is null and usage_credits is null and usage_window_at is null
      and usage_status is null and usage_feature is null and amount_minutes is not null and amount_minutes <> 0
      and ((entry_type = 'earned' and amount_minutes > 0 and expires_at is not null)
        or (entry_type in ('spent', 'expired') and amount_minutes < 0) or entry_type = 'adjustment'))
    or (entry_type = 'usage' and user_id is null and amount_minutes is null and expires_at is null
      and workout_session_id is null and growth_source_id is null and usage_profile_id is not null
      and usage_credits is not null and usage_window_at is not null and usage_status is not null
      and usage_feature is not null)
  );
-- Minute-ledger RLS continues to use user_id. Only the usage RPC exposes usage rows.
create unique index bloom_usage_request_idx
  on public.bloom_credit_ledger(usage_profile_id, idempotency_key) where entry_type = 'usage';
create index bloom_usage_window_idx
  on public.bloom_credit_ledger(usage_profile_id, usage_window_at) where entry_type = 'usage';

create function bloom_private.billing_coverage(p_profile uuid, p_now timestamptz)
returns table(subscription_id uuid, payer uuid, tier text, scope text, period text,
  provider text, status text, period_end timestamptz, cancel_at_end boolean, credits integer,
  coverage_start timestamptz, has_household boolean, overlapping boolean)
language sql stable security definer set search_path = pg_catalog, pg_temp as $$
  select s.id, s.payer_user_id, p.plan_id, p.scope, p.billing_period, s.billing_provider,
    s.status, s.current_period_end, s.cancel_at_period_end, p.weekly_credits,
    greatest(s.activated_at, seat.assigned_at), s.household_id is not null, count(*) over () > 1
  from public.bloom_subscriptions s
  join public.bloom_subscription_products p on p.id = s.product_id
  left join bloom_private.billing_seats seat on seat.subscription_id = s.id and seat.profile_id = p_profile
    and exists (select 1 from public.bloom_household_members m where m.household_id = s.household_id and m.user_id = p_profile)
    and p.seat_limit > (select count(*) from bloom_private.billing_seats b
      join public.bloom_household_members m on m.household_id=s.household_id and m.user_id=b.profile_id
      where b.subscription_id=s.id and (b.assigned_at,b.profile_id)<=(seat.assigned_at,seat.profile_id))
  where s.billing_provider is not null and p.weekly_credits is not null and s.activated_at <= p_now
    and ((s.status = 'active' and s.current_period_end > p_now)
      or (s.status = 'grace_period' and greatest(s.current_period_end, s.grace_until) > p_now))
    and (s.payer_user_id = p_profile or seat.profile_id is not null)
  order by p.weekly_credits desc, s.activated_at, s.id
  limit 1
$$;

create function bloom_private.billing_usage_balance(p_profile uuid, p_now timestamptz)
returns table(allowance integer, remaining integer, window_at timestamptz, next_refill_at timestamptz,
  meter boolean, can_access boolean)
language plpgsql security definer set search_path = pg_catalog, pg_temp as $$
declare
  v_policy bloom_private.billing_config;
  v_coverage record;
  v_anchor timestamptz;
  v_start timestamptz;
  v_allowance integer;
  v_used integer;
  v_transition boolean;
begin
  select * into v_policy from bloom_private.billing_config;
  select * into v_coverage from bloom_private.billing_coverage(p_profile, p_now);
  v_transition := v_policy.notice_at <= p_now and p_now < v_policy.enforcement_at and exists (
    select 1 from public.bloom_profiles p where p.id = p_profile and p.created_at < v_policy.notice_at
  );
  v_allowance := coalesce(v_coverage.credits, case when v_transition then v_policy.transition_weekly_credits end, 0);
  if v_allowance = 0 then
    return query select 0, 0, null::timestamptz, null::timestamptz,
      coalesce(v_policy.notice_at <= p_now, false), v_policy.notice_at is null or p_now < v_policy.notice_at;
    return;
  end if;

  select a.anchored_at into v_anchor from bloom_private.usage_credit_anchors a where a.profile_id = p_profile;
  if not found then
    insert into bloom_private.usage_credit_anchors (profile_id, anchored_at)
    values (p_profile, coalesce(v_coverage.coverage_start, v_policy.notice_at))
    on conflict (profile_id) do nothing;
    select a.anchored_at into v_anchor from bloom_private.usage_credit_anchors a where a.profile_id = p_profile;
  end if;
  v_start := date_bin(interval '168 hours', p_now, v_anchor);
  select coalesce(sum(l.usage_credits), 0) into v_used
  from public.bloom_credit_ledger l where l.usage_profile_id = p_profile and l.entry_type = 'usage'
    and l.usage_window_at = v_start and (l.usage_status = 'spent'
      or (l.usage_status = 'reserved' and l.created_at > p_now - interval '5 minutes'));
  return query select v_allowance, greatest(0, v_allowance - v_used), v_start, v_start + interval '168 hours', true, true;
end
$$;

create function bloom_private.bill_ai_usage()
returns trigger language plpgsql security definer set search_path = pg_catalog, pg_temp as $$
declare
  v_now timestamptz := clock_timestamp();
  v_usage record;
  v_feature text := case when tg_table_name = 'coach_requests' then 'coach_' || new.request_kind else new.request_kind end;
  v_key text := 'usage:' || v_feature || ':' || new.id::text;
  v_cost integer;
begin
  if tg_op = 'INSERT' then
    perform pg_advisory_xact_lock(hashtextextended('bloom-usage:' || new.profile_id::text, 0));
    v_now := clock_timestamp();
    select * into v_usage from bloom_private.billing_usage_balance(new.profile_id, v_now);
    if not v_usage.can_access then
      raise exception using errcode = 'P0001', message = 'BLOOM_SUBSCRIPTION_REQUIRED';
    end if;
    if not v_usage.meter then return new; end if;
    select c.credits into strict v_cost from bloom_private.billing_feature_costs c where c.feature = v_feature;
    if v_usage.remaining < v_cost then
      raise exception using errcode = 'P0001', message = 'BLOOM_USAGE_CREDITS_EXHAUSTED';
    end if;
    insert into public.bloom_credit_ledger(entry_type, idempotency_key, created_at,
      usage_profile_id, usage_credits, usage_window_at, usage_status, usage_feature)
    values ('usage', v_key, v_now, new.profile_id, v_cost, v_usage.window_at, 'reserved', v_feature);
  elsif new.status <> old.status and new.status in ('completed', 'failed') then
    perform pg_advisory_xact_lock(hashtextextended('bloom-usage:' || new.profile_id::text, 0));
    update public.bloom_credit_ledger l
    set usage_status = case when new.status = 'completed' then 'spent' else 'released' end
    where l.usage_profile_id = new.profile_id and l.entry_type = 'usage'
      and l.idempotency_key = v_key and l.usage_status = 'reserved'
      and (new.status = 'failed' or l.created_at > v_now - interval '5 minutes');
    if not found and new.status = 'completed' and exists (
      select 1 from public.bloom_credit_ledger l where l.usage_profile_id = new.profile_id
        and l.entry_type = 'usage' and l.idempotency_key = v_key and l.usage_status <> 'spent'
    ) then
      raise exception 'Usage reservation expired';
    end if;
  end if;
  return new;
end
$$;

create trigger bloom_bill_coach_usage before insert or update of status on bloom_private.coach_requests
  for each row execute function bloom_private.bill_ai_usage();
create trigger bloom_bill_growth_usage before insert or update of status on bloom_private.growth_ai_requests
  for each row execute function bloom_private.bill_ai_usage();

create function bloom_private.billing_summary()
returns jsonb language plpgsql security definer set search_path = pg_catalog, pg_temp as $$
declare
  v_profile uuid := bloom_private.current_profile_id();
  v_now timestamptz := clock_timestamp();
  v_coverage record;
  v_usage record;
begin
  if v_profile is null then raise exception 'Sign in required' using errcode = '42501'; end if;
  select * into v_coverage from bloom_private.billing_coverage(v_profile, v_now);
  select * into v_usage from bloom_private.billing_usage_balance(v_profile, v_now);
  return jsonb_build_object(
    'plan', case when v_coverage.subscription_id is not null then
      (to_jsonb(v_coverage) - 'payer' - 'coverage_start') ||
      jsonb_build_object('is_payer', v_coverage.payer = v_profile) end,
    'allowance', v_usage.allowance, 'remaining', v_usage.remaining, 'metered', v_usage.meter,
    'next_refill_at', v_usage.next_refill_at, 'can_access', v_usage.can_access,
    'notice_at', (select c.notice_at from bloom_private.billing_config c),
    'enforcement_at', (select c.enforcement_at from bloom_private.billing_config c),
    'feature_costs', (select jsonb_object_agg(feature, credits) from bloom_private.billing_feature_costs),
    'recent_usage', coalesce((select jsonb_agg(to_jsonb(history) order by history.created_at desc) from (
      select l.usage_feature as feature, l.usage_credits as credits, l.created_at
      from public.bloom_credit_ledger l where l.usage_profile_id = v_profile
        and l.entry_type = 'usage' and l.usage_status = 'spent' order by l.created_at desc limit 20
    ) history), '[]'::jsonb)
  );
end
$$;

create function public.bloom_billing_summary()
returns jsonb language sql security invoker set search_path = pg_catalog, pg_temp
as $$ select bloom_private.billing_summary() $$;

revoke all on bloom_private.billing_config, bloom_private.billing_feature_costs,
  bloom_private.billing_seats, bloom_private.usage_credit_anchors from public, anon, authenticated;
revoke all on function bloom_private.bill_ai_usage(), bloom_private.billing_coverage(uuid, timestamptz),
  bloom_private.billing_usage_balance(uuid, timestamptz), bloom_private.billing_summary(),
  public.bloom_billing_summary() from public, anon, authenticated;
grant execute on function bloom_private.billing_summary(), public.bloom_billing_summary() to authenticated;

commit;
