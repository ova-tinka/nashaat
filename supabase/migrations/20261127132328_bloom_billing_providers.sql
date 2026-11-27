begin;

create table bloom_private.billing_household_choices (
  payer_profile_id uuid primary key references public.bloom_profiles(id) on delete cascade,
  household_id uuid not null references public.bloom_households(id) on delete cascade
);
create table bloom_private.billing_checkout_holds (
  profile_id uuid primary key references public.bloom_profiles(id) on delete cascade,
  provider text not null,
  expires_at timestamptz not null
);
create table bloom_private.billing_mobile_sync (
  profile_id uuid primary key references public.bloom_profiles(id) on delete cascade,
  fetched_at timestamptz not null
);
create table bloom_private.billing_alerts (
  profile_id uuid not null references public.bloom_profiles(id) on delete cascade,
  kind text not null,
  opened_at timestamptz not null default clock_timestamp(),
  primary key (profile_id, kind)
);

create function bloom_private.billing_select_household(p_profile uuid, p_household uuid)
returns uuid language plpgsql stable security definer set search_path = pg_catalog, pg_temp as $$
declare v_household uuid;
begin
  select h.id into v_household from public.bloom_households h
  where h.id = p_household and h.owner_user_id = p_profile
    and exists (select 1 from public.bloom_household_members m
      where m.household_id = h.id and m.user_id = p_profile and m.role = 'parent');
  if not found then raise exception 'Select a household you own' using errcode = '42501'; end if;
  return v_household;
end
$$;

create function bloom_private.billing_account(p_action text, p_input jsonb)
returns jsonb language plpgsql security definer set search_path = pg_catalog, pg_temp as $$
declare
  v_profile uuid := bloom_private.current_profile_id();
  v_product public.bloom_subscription_products;
  v_subscription public.bloom_subscriptions;
  v_coverage record;
  v_household uuid;
  v_seat uuid;
  v_limit integer;
begin
  if v_profile is null then raise exception 'Sign in required' using errcode = '42501'; end if;
  if p_action = 'catalog' then
    return jsonb_build_object(
      'enabled', (select c.checkout_enabled from bloom_private.billing_config c) and not bloom_private.is_child_profile(v_profile),
      'products', coalesce((select jsonb_agg(jsonb_build_object(
        'id', p.id, 'tier', p.plan_id, 'scope', p.scope, 'period', p.billing_period, 'provider', p.provider,
        'store_product', p.provider_product_id, 'weekly_credits', p.weekly_credits, 'seat_limit', p.seat_limit,
        'currency', p.currency, 'price_minor', p.price_minor
      ) order by p.plan_id, p.scope, case p.billing_period when 'week' then 1 when 'month' then 2 else 3 end)
      from public.bloom_subscription_products p
      where p.active and p.weekly_credits is not null and p.provider in ('app_store', 'play_store', 'tap')), '[]'::jsonb),
      'households', coalesce((select jsonb_agg(jsonb_build_object('id', h.id, 'name', h.name,
        'members', (select jsonb_agg(jsonb_build_object('id', m.user_id, 'role', m.role) order by m.joined_at, m.user_id)
          from public.bloom_household_members m where m.household_id = h.id)))
        from public.bloom_households h where h.owner_user_id = v_profile), '[]'::jsonb)
    );
  end if;
  if bloom_private.is_child_profile(v_profile) then
    raise exception 'Billing is managed by the payer' using errcode = '42501';
  end if;
  if p_action = 'prepare_mobile' then
    if not (select c.checkout_enabled from bloom_private.billing_config c) then raise exception 'Checkout is unavailable'; end if;
    perform pg_advisory_xact_lock(hashtextextended('bloom-billing:' || v_profile::text, 0));
    select * into v_product from public.bloom_subscription_products p where p.id = (p_input->>'product_id')::uuid
      and p.active and p.weekly_credits is not null and p.provider in ('app_store', 'play_store');
    if not found then raise exception 'Plan is unavailable'; end if;
    select * into v_coverage from bloom_private.billing_coverage(v_profile, clock_timestamp());
    if v_coverage.subscription_id is not null and (
      v_coverage.payer <> v_profile or v_coverage.provider <> v_product.provider
    ) then raise exception 'Manage your existing subscription first'; end if;
    if v_product.scope = 'household' then
      v_household := bloom_private.billing_select_household(v_profile, (p_input->>'household_id')::uuid);
      if v_coverage.scope = 'household' and exists (
        select 1 from public.bloom_subscriptions s where s.id = v_coverage.subscription_id and s.household_id <> v_household
      ) then raise exception 'Manage your current household before changing its plan'; end if;
      insert into bloom_private.billing_household_choices values (v_profile, v_household)
      on conflict (payer_profile_id) do update set household_id = excluded.household_id;
    end if;
    if exists (select 1 from bloom_private.tap_attempts a where a.payer = v_profile and a.state in ('ready','pending','review')) then
      raise exception 'An existing checkout must finish first';
    end if;
    insert into bloom_private.billing_checkout_holds values (v_profile,v_product.provider,clock_timestamp()+interval '30 minutes')
    on conflict (profile_id) do update set provider=excluded.provider,expires_at=excluded.expires_at
      where bloom_private.billing_checkout_holds.expires_at<=clock_timestamp()
        or bloom_private.billing_checkout_holds.provider=excluded.provider;
    if not found then raise exception 'An existing checkout must finish first'; end if;
    return jsonb_build_object('allowed', true);
  elsif p_action = 'link_household' then
    v_household := bloom_private.billing_select_household(v_profile,(p_input->>'household_id')::uuid);
    update public.bloom_subscriptions s set household_id=v_household where s.id=(p_input->>'subscription_id')::uuid
      and s.payer_user_id=v_profile and s.household_id is null and s.billing_provider in ('app_store','play_store')
      and s.status in ('active','grace_period')
      and exists(select 1 from public.bloom_subscription_products p where p.id=s.product_id and p.scope='household');
    if not found then raise exception 'Household subscription unavailable' using errcode='42501'; end if;
    insert into bloom_private.billing_household_choices values(v_profile,v_household)
      on conflict (payer_profile_id) do update set household_id=excluded.household_id;
    delete from bloom_private.billing_alerts where profile_id=v_profile and kind='household_selection_required';
    return jsonb_build_object('ok',true);
  elsif p_action in ('seats', 'update_seat') then
    select * into v_subscription from public.bloom_subscriptions s where s.id = (p_input->>'subscription_id')::uuid
      and s.payer_user_id = v_profile and s.household_id is not null and s.billing_provider is not null for update;
    if not found then raise exception 'Household subscription unavailable' using errcode = '42501'; end if;
    v_household := bloom_private.billing_select_household(v_profile, v_subscription.household_id);
    select p.seat_limit into v_limit from public.bloom_subscription_products p where p.id = v_subscription.product_id;
    if p_action = 'update_seat' then
      if v_subscription.status not in ('active', 'grace_period')
        or greatest(v_subscription.current_period_end, v_subscription.grace_until) <= clock_timestamp() then
        raise exception 'Household subscription has expired';
      end if;
      v_seat := (p_input->>'profile_id')::uuid;
      if v_seat is null or v_seat = v_profile or not exists (
        select 1 from public.bloom_household_members m where m.household_id = v_household and m.user_id = v_seat
      ) then raise exception 'Choose a current household member'; end if;
      if (p_input->>'enabled')::boolean then
        if not exists (select 1 from bloom_private.billing_seats b where b.subscription_id = v_subscription.id and b.profile_id = v_seat)
          and v_limit <= 1 + (select count(*) from bloom_private.billing_seats b join public.bloom_household_members m
            on m.user_id = b.profile_id and m.household_id = v_household where b.subscription_id = v_subscription.id)
        then raise exception 'All seats are assigned'; end if;
        insert into bloom_private.billing_seats (subscription_id, profile_id) values (v_subscription.id, v_seat)
          on conflict do nothing;
      else
        delete from bloom_private.billing_seats where subscription_id = v_subscription.id and profile_id = v_seat;
      end if;
    end if;
    return jsonb_build_object('seat_limit', v_limit, 'household_id', v_household, 'members',
      coalesce((select jsonb_agg(jsonb_build_object('profile_id', m.user_id, 'role', m.role,
        'name', child.display_name, 'enabled', m.user_id = v_profile or b.profile_id is not null) order by m.joined_at, m.user_id)
      from public.bloom_household_members m left join bloom_private.billing_seats b
        on b.subscription_id = v_subscription.id and b.profile_id = m.user_id
      left join public.bloom_child_profiles child on child.profile_id=m.user_id and child.household_id=v_household
      where m.household_id = v_household), '[]'::jsonb));
  end if;
  raise exception 'Unknown billing action';
end
$$;

create function public.bloom_billing_account(p_action text, p_input jsonb default '{}')
returns jsonb language sql security invoker set search_path = pg_catalog, pg_temp
as $$ select bloom_private.billing_account(p_action, p_input) $$;

-- Only a server which retrieved the full subscriber snapshot may call this RPC.
create function public.bloom_apply_revenuecat(p_profile uuid, p_fetched_at timestamptz, p_rows jsonb,
  p_event_id text default null, p_event_type text default null)
returns void language plpgsql security definer set search_path = pg_catalog, pg_temp as $$
declare
  v_row record;
  v_product public.bloom_subscription_products;
  v_household uuid;
  v_subscription uuid;
  v_seen uuid[] := '{}';
  v_source uuid;
begin
  if not exists (select 1 from public.bloom_profiles p where p.id = p_profile) then return; end if;
  perform pg_advisory_xact_lock(hashtextextended('bloom-billing:' || p_profile::text, 0));
  if p_event_id is not null then
    insert into public.bloom_billing_events(provider, provider_event_id, event_type)
    values ('revenuecat', p_event_id, p_event_type) on conflict do nothing;
    if not found and exists (select 1 from public.bloom_billing_events e where e.provider = 'revenuecat'
      and e.provider_event_id = p_event_id and e.processed_at is not null) then return; end if;
  end if;
  insert into bloom_private.billing_mobile_sync values (p_profile, p_fetched_at)
  on conflict (profile_id) do update set fetched_at = excluded.fetched_at
    where bloom_private.billing_mobile_sync.fetched_at <= excluded.fetched_at;
  if found then
    for v_row in select * from jsonb_to_recordset(p_rows) as r(
      provider text, sku text, subscription_ref text, status text, start_at timestamptz, period_start timestamptz,
      end_at timestamptz, grace_until timestamptz, cancel_at_end boolean
    ) loop
      select p.* into v_product from public.bloom_subscription_products p
        where p.provider = v_row.provider and p.provider_product_id = v_row.sku and p.weekly_credits is not null;
      if not found then
        insert into bloom_private.billing_alerts(profile_id, kind) values (p_profile, 'unmapped_mobile_product') on conflict do nothing;
        continue;
      end if;
      v_household := null;
      v_source := null;
      if v_product.scope = 'household' then
        select h.id into v_household from bloom_private.billing_household_choices c
          join public.bloom_households h on h.id = c.household_id and h.owner_user_id = p_profile
          where c.payer_profile_id = p_profile;
        if not found then
          insert into bloom_private.billing_alerts(profile_id, kind) values (p_profile, 'household_selection_required') on conflict do nothing;
        else
          select s.id into v_source from public.bloom_subscriptions s where s.payer_user_id = p_profile
            and s.household_id = v_household and s.billing_provider = v_row.provider and s.status in ('active', 'grace_period')
            order by s.activated_at desc limit 1;
        end if;
      end if;
      insert into public.bloom_subscriptions(payer_user_id, household_id, product_id, provider_subscription_id,
        billing_provider, status, activated_at, current_period_start, current_period_end, grace_until, cancel_at_period_end)
      values(p_profile, v_household, v_product.id, v_row.subscription_ref, v_row.provider, v_row.status,
        v_row.start_at, coalesce(v_row.period_start,v_row.start_at), v_row.end_at, v_row.grace_until, v_row.cancel_at_end)
      on conflict (billing_provider, provider_subscription_id) do update
        set household_id = coalesce(public.bloom_subscriptions.household_id, excluded.household_id),
          product_id = excluded.product_id, status = excluded.status,
          current_period_start = excluded.current_period_start, current_period_end = excluded.current_period_end,
          grace_until = excluded.grace_until, cancel_at_period_end = excluded.cancel_at_period_end
        where public.bloom_subscriptions.payer_user_id = p_profile
      returning id into v_subscription;
      if v_subscription is null then raise exception 'Conflicting store subscription ownership'; end if;
      v_seen := array_append(v_seen, v_subscription);
      if v_source is not null and v_source <> v_subscription then
        insert into bloom_private.billing_seats(subscription_id, profile_id, assigned_at)
          select v_subscription, b.profile_id, b.assigned_at from bloom_private.billing_seats b
          join public.bloom_household_members m on m.household_id = v_household and m.user_id = b.profile_id
          where b.subscription_id = v_source order by b.assigned_at, b.profile_id
          limit greatest(0, v_product.seat_limit - 1)
        on conflict do nothing;
      end if;
    end loop;
    update public.bloom_subscriptions s set status = 'expired' where s.payer_user_id = p_profile
      and s.billing_provider in ('app_store', 'play_store') and not (s.id = any(v_seen))
      and s.status in ('active', 'grace_period');
    if exists (select 1 from bloom_private.billing_coverage(p_profile, clock_timestamp()) c where c.overlapping) then
      insert into bloom_private.billing_alerts(profile_id, kind) values (p_profile, 'overlapping_subscriptions') on conflict do nothing;
    end if;
  end if;
  if cardinality(v_seen)>0 then
    delete from bloom_private.billing_checkout_holds h
      where h.profile_id=p_profile and exists (select 1 from public.bloom_subscriptions s
        where s.payer_user_id=p_profile and s.billing_provider=h.provider and s.id=any(v_seen)
          and s.status in ('active','grace_period'));
  end if;
  if p_event_id is not null then
    update public.bloom_billing_events set processed_at = clock_timestamp()
      where provider = 'revenuecat' and provider_event_id = p_event_id;
  end if;
end
$$;

revoke all on bloom_private.billing_household_choices, bloom_private.billing_checkout_holds, bloom_private.billing_mobile_sync,
  bloom_private.billing_alerts from public, anon, authenticated;
revoke all on function bloom_private.billing_select_household(uuid, uuid),
  bloom_private.billing_account(text,jsonb), public.bloom_billing_account(text,jsonb),
  public.bloom_apply_revenuecat(uuid,timestamptz,jsonb,text,text) from public, anon, authenticated;
grant execute on function bloom_private.billing_account(text,jsonb), public.bloom_billing_account(text,jsonb) to authenticated;
grant execute on function public.bloom_apply_revenuecat(uuid,timestamptz,jsonb,text,text) to service_role;

commit;
