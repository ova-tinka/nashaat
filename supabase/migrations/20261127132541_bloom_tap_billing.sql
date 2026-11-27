begin;

create table bloom_private.tap_agreements (
  subscription_id uuid primary key references public.bloom_subscriptions(id) on delete restrict,
  customer_ref text not null,
  card_ref text not null,
  agreement_ref text not null,
  accepted_at timestamptz not null,
  recurring_minor integer not null check (recurring_minor > 0),
  currency text not null,
  term_anchor timestamptz not null,
  term_number integer not null default 1 check (term_number > 0),
  reauthorize_at_renewal boolean not null default false
);
create table bloom_private.billing_offers (
  code text primary key check (code ~ '^[A-Z0-9_-]{1,40}$'),
  kind text not null check (kind in ('intro', 'campaign', 'win_back')),
  product_id uuid not null references public.bloom_subscription_products(id),
  amount_minor integer check (amount_minor > 0),
  play_option_id text,
  starts_at timestamptz not null,
  ends_at timestamptz not null check (ends_at > starts_at),
  redemption_limit integer not null check (redemption_limit > 0),
  check ((amount_minor is not null) <> (play_option_id is not null))
);
create table bloom_private.tap_attempts (
  id uuid primary key default gen_random_uuid(),
  payer uuid not null references public.bloom_profiles(id) on delete restrict,
  product_id uuid not null references public.bloom_subscription_products(id),
  household_id uuid references public.bloom_households(id) on delete set null,
  subscription_id uuid references public.bloom_subscriptions(id) on delete restrict,
  kind text not null check (kind in ('initial','renewal','upgrade','recovery','card_update')),
  state text not null default 'ready' check (state in ('ready','pending','captured','declined','review')),
  currency text not null,
  amount_minor integer not null check (amount_minor > 0),
  recurring_minor integer not null check (recurring_minor > 0),
  offer_code text references bloom_private.billing_offers(code),
  term_start timestamptz,
  term_end timestamptz,
  provider_ref text unique,
  created_at timestamptz not null default clock_timestamp(),
  sent_at timestamptz,
  next_check_at timestamptz,
  checkout_url text,
  receipt_url text
);
create unique index bloom_tap_open_attempt on bloom_private.tap_attempts(payer)
  where state in ('ready','pending','review');
create unique index bloom_tap_renewal_period on bloom_private.tap_attempts(subscription_id,term_start)
  where kind = 'renewal';
create index bloom_tap_due_attempts on bloom_private.tap_attempts(next_check_at)
  where state in ('ready','pending');
create table bloom_private.billing_offer_uses (
  offer_code text not null references bloom_private.billing_offers(code),
  profile_id uuid not null references public.bloom_profiles(id) on delete restrict,
  attempt_id uuid references bloom_private.tap_attempts(id) on delete restrict,
  reserved_at timestamptz not null default clock_timestamp(),
  play_hold_until timestamptz,
  primary key (offer_code, profile_id),
  check (play_hold_until is null or (attempt_id is null and play_hold_until > reserved_at))
);
create table bloom_private.billing_refund_staff (
  profile_id uuid primary key references public.bloom_profiles(id) on delete cascade
);
create table bloom_private.tap_refunds (
  id uuid primary key default gen_random_uuid(),
  charge_id uuid not null references bloom_private.tap_attempts(id) on delete restrict,
  payer uuid not null references public.bloom_profiles(id) on delete restrict,
  state text not null default 'requested' check (state in ('requested','declined','approved','pending','refunded','failed','review')),
  reason text not null check (char_length(reason) between 1 and 600),
  review_note text check (char_length(review_note) between 1 and 600),
  reviewed_by uuid references public.bloom_profiles(id) on delete set null,
  amount_minor integer check (amount_minor > 0),
  provider_ref text unique,
  created_at timestamptz not null default clock_timestamp(),
  sent_at timestamptz,
  next_check_at timestamptz
);
create unique index bloom_tap_one_refund_request on bloom_private.tap_refunds(charge_id)
  where state = 'requested';

create function bloom_private.billing_term_end(p_anchor timestamptz,p_period text,p_term integer)
returns timestamptz language sql immutable set search_path = pg_catalog, pg_temp as $$
  select case p_period when 'week' then p_anchor + make_interval(hours => 168 * p_term)
    when 'month' then ((p_anchor at time zone 'UTC') + make_interval(months => p_term)) at time zone 'UTC'
    when 'year' then ((p_anchor at time zone 'UTC') + make_interval(years => p_term)) at time zone 'UTC' end
$$;

create function bloom_private.find_billing_offer(p_profile uuid, p_product uuid, p_code text)
returns bloom_private.billing_offers language plpgsql security definer set search_path = pg_catalog, pg_temp as $$
declare
  v_offer bloom_private.billing_offers;
  v_use bloom_private.billing_offer_uses;
  v_now timestamptz;
  v_existing_hold boolean;
begin
  select * into v_offer from bloom_private.billing_offers o where o.code = upper(trim(p_code))
    and o.product_id = p_product for update;
  v_now := clock_timestamp();
  if not found or v_offer.starts_at > v_now or v_offer.ends_at <= v_now then
    raise exception 'Offer is unavailable';
  end if;
  select * into v_use from bloom_private.billing_offer_uses u
    where u.offer_code=v_offer.code and u.profile_id=p_profile;
  v_existing_hold := coalesce(v_use.play_hold_until>v_now,false);
  if (v_use.profile_id is not null and v_use.play_hold_until is null)
    or (not v_existing_hold and v_offer.redemption_limit <= (select count(*) from bloom_private.billing_offer_uses u
      where u.offer_code=v_offer.code and (u.play_hold_until is null or u.play_hold_until>v_now)))
    or (v_offer.kind = 'intro' and exists (select 1 from public.bloom_subscriptions s
      where s.payer_user_id = p_profile and s.billing_provider is not null))
    or (v_offer.kind = 'win_back' and (not exists (select 1 from public.bloom_subscriptions s
      where s.payer_user_id = p_profile and s.billing_provider is not null)
      or exists (select 1 from bloom_private.billing_coverage(p_profile,v_now))))
  then raise exception 'Offer is unavailable'; end if;
  return v_offer;
end
$$;

create function bloom_private.reserve_play_offer(p_profile uuid,p_product uuid,p_code text,p_expected_option text)
returns void language plpgsql security definer set search_path = pg_catalog, pg_temp as $$
declare
  v_offer bloom_private.billing_offers;
  v_now timestamptz;
begin
  v_offer := bloom_private.find_billing_offer(p_profile,p_product,p_code);
  v_now := clock_timestamp();
  if v_offer.play_option_id is null or v_offer.play_option_id is distinct from p_expected_option then
    raise exception 'Review the current store offer';
  end if;
  if exists (select 1 from bloom_private.billing_offer_uses u
    where u.profile_id=p_profile and u.offer_code<>v_offer.code and u.play_hold_until>v_now) then
    raise exception 'An existing Play offer checkout must finish first';
  end if;
  insert into bloom_private.billing_offer_uses(offer_code,profile_id,reserved_at,play_hold_until)
  values(v_offer.code,p_profile,v_now,v_now+interval '30 minutes')
  on conflict (offer_code,profile_id) do update
    set reserved_at=excluded.reserved_at,play_hold_until=excluded.play_hold_until
    where bloom_private.billing_offer_uses.play_hold_until<=v_now;
end
$$;

create function public.bloom_billing_tap(p_profile uuid,p_action text,p_input jsonb default '{}')
returns jsonb language plpgsql security definer set search_path = pg_catalog, pg_temp as $$
declare
  v_now timestamptz := clock_timestamp();
  v_product public.bloom_subscription_products;
  v_next public.bloom_subscription_products;
  v_sub public.bloom_subscriptions;
  v_coverage record;
  v_attempt bloom_private.tap_attempts;
  v_agreement bloom_private.tap_agreements;
  v_refund bloom_private.tap_refunds;
  v_offer bloom_private.billing_offers;
  v_household uuid;
  v_subscription uuid;
  v_reference text;
  v_amount integer;
  v_refunded integer;
  v_start timestamptz;
  v_end timestamptz;
  v_state text;
  v_result jsonb;
begin
  if p_profile is not null then
    perform pg_advisory_xact_lock(hashtextextended('bloom-billing:' || p_profile::text, 0));
    if bloom_private.is_child_profile(p_profile) then raise exception 'Billing is managed by the payer'; end if;
  elsif p_action not in ('due','claim_renewal','charge_result','refund_result','claim_charge','claim_refund') then
    raise exception 'Billing profile required';
  end if;

  if p_action in ('quote','checkout','play_offer') then
    if not (select c.checkout_enabled from bloom_private.billing_config c) then raise exception 'Checkout is unavailable'; end if;
    select * into v_product from public.bloom_subscription_products p where p.id = (p_input->>'product_id')::uuid
      and p.active and p.weekly_credits is not null
      and p.provider = case when p_action = 'play_offer' then 'play_store' else 'tap' end;
    if not found then raise exception 'The plan is unavailable'; end if;
    select * into v_coverage from bloom_private.billing_coverage(p_profile,v_now);
    if p_action = 'play_offer' then
      if v_coverage.subscription_id is not null then raise exception 'Offer is unavailable'; end if;
      v_offer := bloom_private.find_billing_offer(p_profile,v_product.id,p_input->>'code');
      if v_offer.play_option_id is null then raise exception 'Offer is unavailable'; end if;
      return jsonb_build_object('option_id',v_offer.play_option_id);
    end if;
    if v_product.price_minor is null or v_product.currency is null then raise exception 'The plan is unavailable'; end if;
    if v_product.scope = 'household' then
      v_household := bloom_private.billing_select_household(p_profile,(p_input->>'household_id')::uuid);
    end if;
    v_amount := v_product.price_minor;
    v_state := 'initial';
    if v_coverage.subscription_id is not null then
      if v_coverage.provider <> 'tap' or v_coverage.payer <> p_profile then raise exception 'Manage your existing subscription first'; end if;
      select * into v_sub from public.bloom_subscriptions s where s.id = v_coverage.subscription_id for update;
      select * into v_agreement from bloom_private.tap_agreements a where a.subscription_id = v_sub.id;
      if v_agreement.currency <> v_product.currency then raise exception 'Choose a plan priced in your billing currency'; end if;
      if coalesce(v_sub.next_product_id,v_sub.product_id) = v_product.id and v_coverage.status = 'grace_period' then
        v_state := 'recovery';
      elsif v_product.plan_id = 'premium' and v_coverage.tier = 'basic' and v_coverage.period = v_product.billing_period
        and v_coverage.scope = v_product.scope and v_sub.household_id is not distinct from v_household
        and v_sub.current_period_end > v_now then
        v_state := 'upgrade';
        v_amount := greatest(1,ceil((v_product.price_minor - v_agreement.recurring_minor)::numeric *
          extract(epoch from v_sub.current_period_end-v_now) /
          greatest(1,extract(epoch from v_sub.current_period_end-v_sub.current_period_start)))::integer);
      else
        raise exception 'Manage this change from your current plan';
      end if;
    elsif exists (select 1 from public.bloom_subscriptions s where s.payer_user_id = p_profile
        and s.billing_provider = 'tap' and s.status = 'grace_period' and not s.cancel_at_period_end
        and s.product_id = v_product.id and s.grace_until > v_now) then
      raise exception 'Recover the existing payment first';
    end if;
    if p_action = 'checkout' then
      if exists (select 1 from bloom_private.billing_checkout_holds h where h.profile_id=p_profile and h.expires_at>v_now) then
        raise exception 'An existing checkout must finish first';
      end if;
      select * into v_attempt from bloom_private.tap_attempts where payer=p_profile and state in ('ready','pending','review') for update;
      if found then
        if v_attempt.product_id <> v_product.id or v_attempt.kind <> v_state
          or v_attempt.household_id is distinct from v_household
          or coalesce(v_attempt.offer_code,'') <> coalesce(upper(trim(p_input->>'code')),'')
        then raise exception 'An existing checkout must finish first'; end if;
        return to_jsonb(v_attempt);
      end if;
    end if;
    if nullif(trim(p_input->>'code'),'') is not null then
      if v_state <> 'initial' then raise exception 'Offer is unavailable'; end if;
      v_offer := bloom_private.find_billing_offer(p_profile,v_product.id,p_input->>'code');
      if v_offer.amount_minor is null or v_offer.amount_minor >= v_amount then raise exception 'Offer is unavailable'; end if;
      v_amount := v_offer.amount_minor;
    end if;
    v_result := jsonb_build_object('amount_minor',v_amount,'recurring_minor',v_product.price_minor,
      'currency',v_product.currency,'period',v_product.billing_period,'kind',v_state);
    if p_action = 'quote' then return v_result; end if;
    if (p_input->>'accepted')::boolean is distinct from true
      or (p_input->>'recurring_minor')::integer is distinct from v_product.price_minor
      or (p_input->>'currency') is distinct from v_product.currency
      or (p_input->>'amount_minor')::integer is null
      or (case when v_state = 'upgrade' then (p_input->>'amount_minor')::integer < v_amount
        else (p_input->>'amount_minor')::integer <> v_amount end)
    then raise exception 'Review the current price and recurring terms'; end if;
    insert into bloom_private.tap_attempts(payer,product_id,household_id,subscription_id,kind,currency,
      amount_minor,recurring_minor,offer_code,term_start,term_end)
    values (p_profile,v_product.id,v_household,v_sub.id,v_state,v_product.currency,v_amount,
      v_product.price_minor,v_offer.code,v_sub.current_period_end,
      case when v_state = 'upgrade' then v_sub.current_period_end end)
    returning * into v_attempt;
    if v_offer.code is not null then
      insert into bloom_private.billing_offer_uses(offer_code,profile_id,attempt_id,reserved_at)
      values(v_offer.code,p_profile,v_attempt.id,v_now);
    end if;
    return to_jsonb(v_attempt);
  elsif p_action = 'history' then
    return jsonb_build_object('charges', coalesce((select jsonb_agg(to_jsonb(c) order by c.created_at desc) from (
      select id,state,amount_minor,currency,created_at,receipt_url from bloom_private.tap_attempts where payer = p_profile and kind <> 'card_update'
        order by created_at desc limit 30) c),'[]'::jsonb),
      'scheduled', (select jsonb_build_object('product_id',s.next_product_id,'period_end',s.current_period_end)
        from public.bloom_subscriptions s where s.payer_user_id=p_profile and s.billing_provider='tap'
          and s.next_product_id is not null and s.status in ('active','grace_period') order by s.current_period_end desc limit 1),
      'refunds', coalesce((select jsonb_agg(to_jsonb(r) order by r.created_at desc) from (
      select id,charge_id,state,amount_minor,created_at,review_note from bloom_private.tap_refunds where payer = p_profile
        order by created_at desc limit 30) r),'[]'::jsonb),
      'is_staff',exists(select 1 from bloom_private.billing_refund_staff f where f.profile_id=p_profile));
  elsif p_action = 'checkout_status' then
    select * into v_attempt from bloom_private.tap_attempts where id = (p_input->>'id')::uuid and payer = p_profile;
    if not found then raise exception 'Checkout unavailable'; end if;
    return to_jsonb(v_attempt);
  elsif p_action in ('cancel','resume','schedule','card_update') then
    select * into v_sub from public.bloom_subscriptions s where s.id = (p_input->>'subscription_id')::uuid
      and s.payer_user_id=p_profile and s.billing_provider='tap' and s.status in ('active','grace_period') for update;
    if not found then raise exception 'Subscription unavailable'; end if;
    if p_action = 'cancel' then
      update public.bloom_subscriptions set cancel_at_period_end=true,next_product_id=null where id=v_sub.id;
    elsif p_action = 'resume' then
      if v_sub.current_period_end <= v_now then raise exception 'Start a new checkout to resume'; end if;
      update public.bloom_subscriptions set cancel_at_period_end=false where id=v_sub.id;
    elsif p_action = 'schedule' then
      if v_sub.current_period_end <= v_now then raise exception 'Start a new checkout to change plans'; end if;
      select * into v_product from public.bloom_subscription_products where id=v_sub.product_id;
      select * into v_next from public.bloom_subscription_products where id=(p_input->>'product_id')::uuid
        and provider='tap' and active and scope=v_product.scope and currency=v_product.currency;
      if not found or v_next.price_minor is null then raise exception 'Plan is unavailable'; end if;
      -- A changed recurring amount or cadence must be reauthorized at renewal.
      update public.bloom_subscriptions set next_product_id=v_next.id,cancel_at_period_end=false where id=v_sub.id;
    else
      if (p_input->>'accepted')::boolean is distinct from true then raise exception 'Confirm your card update'; end if;
      select * into strict v_agreement from bloom_private.tap_agreements where subscription_id=v_sub.id;
      select * into v_attempt from bloom_private.tap_attempts where payer=p_profile and state in ('ready','pending','review') for update;
      if found then
        if v_attempt.kind <> 'card_update' then raise exception 'An existing checkout must finish first'; end if;
      else
        insert into bloom_private.tap_attempts(payer,product_id,household_id,subscription_id,kind,currency,amount_minor,recurring_minor)
        values(p_profile,v_sub.product_id,v_sub.household_id,v_sub.id,'card_update',v_agreement.currency,
          (p_input->>'verification_minor')::integer,v_agreement.recurring_minor) returning * into v_attempt;
      end if;
      return to_jsonb(v_attempt);
    end if;
    return jsonb_build_object('ok',true);
  elsif p_action = 'refund_request' then
    select * into v_attempt from bloom_private.tap_attempts where id=(p_input->>'charge_id')::uuid
      and payer=p_profile and state='captured' and kind <> 'card_update' for update;
    if not found then raise exception 'Payment unavailable'; end if;
    select coalesce(sum(amount_minor),0) into v_refunded from bloom_private.tap_refunds
      where charge_id=v_attempt.id and state in ('approved','pending','refunded','review');
    if v_refunded >= v_attempt.amount_minor then raise exception 'No refundable amount remains'; end if;
    insert into bloom_private.tap_refunds(charge_id,payer,reason)
      values(v_attempt.id,p_profile,trim(p_input->>'reason')) returning * into v_refund;
    return jsonb_build_object('id',v_refund.id,'state',v_refund.state);
  elsif p_action in ('refund_queue','refund_decision') then
    if not exists(select 1 from bloom_private.billing_refund_staff f where f.profile_id=p_profile) then
      raise exception 'Refund review access required';
    end if;
    if p_action = 'refund_queue' then
      return coalesce((select jsonb_agg(to_jsonb(q)) from (
        select r.id,r.state,r.reason,a.amount_minor,a.currency,r.created_at,
          a.amount_minor - coalesce((select sum(other.amount_minor) from bloom_private.tap_refunds other
            where other.charge_id=a.id and other.state in ('approved','pending','refunded','review')),0) as refundable_minor
        from bloom_private.tap_refunds r join bloom_private.tap_attempts a on a.id=r.charge_id
        where r.state='requested' order by r.created_at limit 50) q),'[]'::jsonb);
    end if;
    select * into v_refund from bloom_private.tap_refunds where id=(p_input->>'id')::uuid and state='requested' for update;
    if not found then raise exception 'Request already reviewed'; end if;
    select * into v_attempt from bloom_private.tap_attempts where id=v_refund.charge_id for update;
    v_state := p_input->>'state';
    if v_state not in ('approved','declined') or nullif(trim(p_input->>'note'),'') is null then raise exception 'Review decision is incomplete'; end if;
    if v_state = 'approved' then
      v_amount := (p_input->>'amount_minor')::integer;
      select coalesce(sum(amount_minor),0) into v_refunded from bloom_private.tap_refunds
        where charge_id=v_attempt.id and state in ('approved','pending','refunded','review');
      if v_amount is null or v_amount <= 0 or v_amount > v_attempt.amount_minor - v_refunded then
        raise exception 'Refund exceeds the available amount';
      end if;
    end if;
    update bloom_private.tap_refunds set state=v_state,amount_minor=v_amount,reviewed_by=p_profile,
      review_note=trim(p_input->>'note'),next_check_at=v_now where id=v_refund.id;
    return jsonb_build_object('id',v_refund.id,'state',v_state);
  elsif p_action = 'due' then
    update public.bloom_subscriptions s set status='expired' where s.billing_provider='tap'
      and ((s.status='grace_period' and s.grace_until <= v_now) or
        (s.status='active' and s.current_period_end <= v_now and s.cancel_at_period_end));
    return jsonb_build_object(
      'subscriptions',coalesce((select jsonb_agg(q.id) from (
        select s.id from public.bloom_subscriptions s where s.billing_provider='tap'
          and s.status='active' and not s.cancel_at_period_end and s.current_period_end <= v_now
          and not exists(select 1 from bloom_private.tap_attempts a where a.subscription_id=s.id
            and a.kind='renewal' and a.term_start=s.current_period_end)
          order by s.current_period_end limit 10) q),'[]'::jsonb),
      'attempts',coalesce((select jsonb_agg(q.id) from (
        select a.id from bloom_private.tap_attempts a where a.state in ('ready','pending')
          and a.next_check_at <= v_now order by a.next_check_at limit 10) q),'[]'::jsonb),
      'refunds',coalesce((select jsonb_agg(q.id) from (
        select r.id from bloom_private.tap_refunds r where r.state in ('approved','pending')
          and r.next_check_at <= v_now order by r.next_check_at limit 10) q),'[]'::jsonb));
  elsif p_action = 'claim_renewal' then
    select * into v_sub from public.bloom_subscriptions s where s.id=(p_input->>'id')::uuid
      and s.billing_provider='tap' and s.status='active' and not s.cancel_at_period_end
      and s.current_period_end<=v_now for update skip locked;
    if not found then return 'null'::jsonb; end if;
    select * into strict v_agreement from bloom_private.tap_agreements where subscription_id=v_sub.id;
    if v_sub.next_product_id is not null or v_agreement.reauthorize_at_renewal then
      update public.bloom_subscriptions set status='grace_period',grace_until=v_now+interval '72 hours' where id=v_sub.id;
      return 'null'::jsonb;
    end if;
    select * into strict v_product from public.bloom_subscription_products where id=v_sub.product_id;
    insert into bloom_private.tap_attempts(payer,product_id,household_id,subscription_id,kind,currency,
      amount_minor,recurring_minor,term_start,term_end,next_check_at)
    values(v_sub.payer_user_id,v_sub.product_id,v_sub.household_id,v_sub.id,'renewal',v_agreement.currency,
      v_agreement.recurring_minor,v_agreement.recurring_minor,v_sub.current_period_end,
      bloom_private.billing_term_end(v_agreement.term_anchor,v_product.billing_period,v_agreement.term_number+1),v_now)
    on conflict do nothing returning * into v_attempt;
    if found then
      update public.bloom_subscriptions set status='grace_period',grace_until=v_now+interval '72 hours'
        where id=v_sub.id;
    end if;
    return to_jsonb(v_attempt.id);
  elsif p_action = 'claim_charge' then
    select * into v_attempt from bloom_private.tap_attempts where id=(p_input->>'id')::uuid and state in ('ready','pending') for update skip locked;
    if not found or v_attempt.next_check_at > v_now then return 'null'::jsonb; end if;
    if v_attempt.kind='renewal' then
      select * into v_sub from public.bloom_subscriptions where id=v_attempt.subscription_id for update;
      if v_sub.cancel_at_period_end and v_attempt.sent_at is null then
        update bloom_private.tap_attempts set state='declined' where id=v_attempt.id;
        return 'null'::jsonb;
      end if;
    end if;
    if v_attempt.subscription_id is not null then
      select * into v_agreement from bloom_private.tap_agreements where subscription_id=v_attempt.subscription_id;
    end if;
    if v_attempt.provider_ref is null and v_attempt.sent_at <= v_now-interval '23 hours' then
      update bloom_private.tap_attempts set state='review' where id=v_attempt.id;
      insert into bloom_private.billing_alerts values(v_attempt.payer,'uncertain_tap_charge',v_now) on conflict do nothing;
      return 'null'::jsonb;
    end if;
    update bloom_private.tap_attempts set sent_at=coalesce(sent_at,v_now),
      next_check_at=v_now+interval '2 minutes' where id=v_attempt.id returning * into v_attempt;
    return to_jsonb(v_attempt)||jsonb_build_object('agreement',to_jsonb(v_agreement));
  elsif p_action = 'charge_result' then
    v_reference := p_input->>'provider_ref';
    select * into v_attempt from bloom_private.tap_attempts where id=(p_input->>'id')::uuid for update;
    if not found or v_reference is null or (v_attempt.provider_ref is not null and v_attempt.provider_ref<>v_reference)
      or p_input->>'currency' is distinct from v_attempt.currency
      or (p_input->>'amount_minor')::integer is distinct from v_attempt.amount_minor then raise exception 'Payment verification failed'; end if;
    if v_attempt.state='captured' then return jsonb_build_object('state','captured'); end if;
    if v_attempt.state='declined' and p_input->>'state'='pending' then return jsonb_build_object('state','declined'); end if;
    v_state := p_input->>'state';
    if v_state not in ('pending','captured','declined') then raise exception 'Payment status unavailable'; end if;
    update bloom_private.tap_attempts set provider_ref=v_reference,state=v_state,
      checkout_url=p_input->>'checkout_url',receipt_url=p_input->>'receipt_url',
      next_check_at=case when v_state='pending' then v_now+interval '2 minutes' end where id=v_attempt.id;
    if v_state='declined' then
      delete from bloom_private.billing_offer_uses where attempt_id=v_attempt.id;
      if v_attempt.kind='renewal' then
        update public.bloom_subscriptions set status='grace_period',grace_until=v_now+interval '72 hours'
          where id=v_attempt.subscription_id and not cancel_at_period_end;
      end if;
    elsif v_state='captured' then
      select * into strict v_product from public.bloom_subscription_products where id=v_attempt.product_id;
      v_start := coalesce(v_attempt.term_start,v_now);
      if v_attempt.kind='upgrade' then
        select current_period_start into v_start from public.bloom_subscriptions where id=v_attempt.subscription_id;
      end if;
      if v_attempt.kind='recovery' then
        select * into v_sub from public.bloom_subscriptions where id=v_attempt.subscription_id;
        select * into v_agreement from bloom_private.tap_agreements where subscription_id=v_attempt.subscription_id;
      end if;
      v_end := case when v_attempt.kind='recovery' and v_attempt.product_id=v_sub.product_id then
          bloom_private.billing_term_end(v_agreement.term_anchor,v_product.billing_period,v_agreement.term_number+1)
        else coalesce(v_attempt.term_end,bloom_private.billing_term_end(v_start,v_product.billing_period,1)) end;
      if v_attempt.kind <> 'renewal' and (
        nullif(p_input->>'customer_ref','') is null or nullif(p_input->>'card_ref','') is null
        or nullif(p_input->>'agreement_ref','') is null
      ) then
        update bloom_private.tap_attempts set state='review',term_start=v_start,term_end=v_end where id=v_attempt.id;
        insert into bloom_private.billing_alerts values(v_attempt.payer,'missing_tap_agreement',v_now) on conflict do nothing;
        return jsonb_build_object('state','review');
      end if;
      if v_attempt.kind='card_update' then
        update bloom_private.tap_agreements set customer_ref=p_input->>'customer_ref',card_ref=p_input->>'card_ref',
          agreement_ref=p_input->>'agreement_ref',accepted_at=v_attempt.created_at
          where subscription_id=v_attempt.subscription_id;
        return jsonb_build_object('state','captured');
      end if;
      if v_attempt.subscription_id is null then
        insert into public.bloom_subscriptions(payer_user_id,household_id,product_id,provider_subscription_id,
          status,billing_provider,activated_at,current_period_start,current_period_end)
        values(v_attempt.payer,v_attempt.household_id,v_product.id,v_attempt.id::text,
          'active','tap',v_start,v_start,v_end) returning id into v_subscription;
      else
        v_subscription := v_attempt.subscription_id;
        update public.bloom_subscriptions set status='active',product_id=v_product.id,grace_until=null,
          current_period_start=v_start,current_period_end=v_end,next_product_id=null where id=v_subscription;
      end if;
      if v_attempt.kind='renewal' then
        update bloom_private.tap_agreements set term_number=term_number+1 where subscription_id=v_subscription;
      else
        insert into bloom_private.tap_agreements values(v_subscription,p_input->>'customer_ref',p_input->>'card_ref',
          p_input->>'agreement_ref',v_attempt.created_at,v_attempt.recurring_minor,v_attempt.currency,v_start,1,
          v_attempt.amount_minor<>v_attempt.recurring_minor and not coalesce((p_input->>'variable_agreement')::boolean,false))
        on conflict (subscription_id) do update set customer_ref=excluded.customer_ref,card_ref=excluded.card_ref,
          agreement_ref=excluded.agreement_ref,accepted_at=excluded.accepted_at,recurring_minor=excluded.recurring_minor,
          currency=excluded.currency,term_anchor=case
            when v_attempt.kind='upgrade' or (v_attempt.kind='recovery' and v_attempt.product_id=v_sub.product_id)
              then bloom_private.tap_agreements.term_anchor else v_start end,
          term_number=case when v_attempt.kind='upgrade' then bloom_private.tap_agreements.term_number
            when v_attempt.kind='recovery' and v_attempt.product_id=v_sub.product_id then bloom_private.tap_agreements.term_number+1
            else 1 end,
          reauthorize_at_renewal=excluded.reauthorize_at_renewal;
      end if;
      update bloom_private.tap_attempts set subscription_id=v_subscription,term_start=v_start,term_end=v_end where id=v_attempt.id;
      if exists(select 1 from bloom_private.billing_coverage(v_attempt.payer,v_now) c where c.overlapping) then
        insert into bloom_private.billing_alerts values(v_attempt.payer,'overlapping_subscriptions',v_now) on conflict do nothing;
      end if;
    end if;
    insert into public.bloom_billing_events(provider,provider_event_id,event_type,subscription_id,processed_at)
      values('tap',v_reference||':'||v_state,v_state,v_subscription,v_now) on conflict do nothing;
    return jsonb_build_object('state',v_state,'checkout_url',p_input->>'checkout_url');
  elsif p_action = 'claim_refund' then
    select * into v_refund from bloom_private.tap_refunds where id=(p_input->>'id')::uuid and state in ('approved','pending') for update skip locked;
    if not found or v_refund.next_check_at > v_now then return 'null'::jsonb; end if;
    if v_refund.provider_ref is null and v_refund.sent_at <= v_now-interval '23 hours' then
      update bloom_private.tap_refunds set state='review' where id=v_refund.id;
      insert into bloom_private.billing_alerts values(v_refund.payer,'uncertain_tap_refund',v_now) on conflict do nothing;
      return 'null'::jsonb;
    end if;
    select * into strict v_attempt from bloom_private.tap_attempts where id=v_refund.charge_id;
    update bloom_private.tap_refunds set state='pending',sent_at=coalesce(sent_at,v_now),next_check_at=v_now+interval '2 minutes'
      where id=v_refund.id returning * into v_refund;
    return to_jsonb(v_refund)||jsonb_build_object('charge_ref',v_attempt.provider_ref,'currency',v_attempt.currency);
  elsif p_action='refund_result' then
    select * into v_refund from bloom_private.tap_refunds where id=(p_input->>'id')::uuid for update;
    if not found or v_refund.state not in ('pending','refunded','failed','review') then raise exception 'Refund unavailable'; end if;
    select * into strict v_attempt from bloom_private.tap_attempts where id=v_refund.charge_id for update;
    v_reference := p_input->>'provider_ref';
    if v_reference is null or (v_refund.provider_ref is not null and v_refund.provider_ref<>v_reference)
      or (p_input->>'amount_minor')::integer is distinct from v_refund.amount_minor
      or p_input->>'charge_ref' is distinct from v_attempt.provider_ref or p_input->>'currency' is distinct from v_attempt.currency
    then raise exception 'Refund verification failed'; end if;
    if v_refund.state='refunded' then return jsonb_build_object('state','refunded'); end if;
    v_state := p_input->>'state';
    if v_state not in ('refunded','failed','pending') then raise exception 'Refund status unavailable'; end if;
    update bloom_private.tap_refunds set state=v_state,provider_ref=v_reference,
      next_check_at=case when v_state='pending' then v_now+interval '2 minutes' end where id=v_refund.id;
    if v_state='refunded' and (select coalesce(sum(amount_minor),0) from bloom_private.tap_refunds
      where charge_id=v_attempt.id and state='refunded') >= v_attempt.amount_minor
    then
      update public.bloom_subscriptions set status='revoked',cancel_at_period_end=true,next_product_id=null
      where id=v_attempt.subscription_id and current_period_end=v_attempt.term_end and current_period_end>v_now;
    end if;
    insert into public.bloom_billing_events(provider,provider_event_id,event_type,subscription_id,processed_at)
      values('tap',v_reference||':'||v_state,v_state,v_attempt.subscription_id,v_now) on conflict do nothing;
    return jsonb_build_object('state',v_state);
  end if;
  raise exception 'Unknown billing action';
end
$$;

revoke all on bloom_private.tap_agreements,bloom_private.billing_offers,bloom_private.tap_attempts,
  bloom_private.billing_offer_uses,bloom_private.billing_refund_staff,bloom_private.tap_refunds from public,anon,authenticated;
revoke all on function bloom_private.billing_term_end(timestamptz,text,integer),
  bloom_private.find_billing_offer(uuid,uuid,text),bloom_private.reserve_play_offer(uuid,uuid,text,text),public.bloom_billing_tap(uuid,text,jsonb) from public,anon,authenticated;
grant execute on function public.bloom_billing_tap(uuid,text,jsonb) to service_role;
commit;
