begin;

insert into auth.users(id) values
  ('ac000000-0000-4000-8000-000000000011'),
  ('ac000000-0000-4000-8000-000000000012');
insert into public.bloom_subscription_products(id,plan_id,scope,billing_period,provider,provider_product_id,active,weekly_credits,seat_limit) values
  ('ac000000-0000-4000-8001-000000000011','basic','individual','month','play_store','fixture-basic:month',true,5,1);
insert into bloom_private.billing_offers(code,kind,product_id,play_option_id,starts_at,ends_at,redemption_limit) values
  ('PLAY_FIXTURE','campaign','ac000000-0000-4000-8001-000000000011','month:fixture-campaign',now()-interval '1 day',now()+interval '1 day',1);
update bloom_private.billing_config set checkout_enabled=true;

do $$
declare
  first_payer uuid := 'ac000000-0000-4000-8000-000000000011';
  second_payer uuid := 'ac000000-0000-4000-8000-000000000012';
  input jsonb := jsonb_build_object('product_id','ac000000-0000-4000-8001-000000000011','code','PLAY_FIXTURE',
    'offer_code','PLAY_FIXTURE','offer_option_id','month:fixture-campaign');
  first_hold timestamptz;
  paid_at timestamptz;
  snapshot jsonb;
begin
  if public.bloom_billing_tap(first_payer,'play_offer',input)->>'option_id' is distinct from 'month:fixture-campaign'
    or public.bloom_billing_tap(second_payer,'play_offer',input)->>'option_id' is distinct from 'month:fixture-campaign'
    or exists(select 1 from bloom_private.billing_offer_uses where offer_code='PLAY_FIXTURE') then
    raise exception 'Checking a Play offer consumed the campaign slot';
  end if;

  perform set_config('request.jwt.claim.sub',first_payer::text,true);
  begin
    perform public.bloom_billing_account('prepare_mobile',input||jsonb_build_object('offer_option_id','wrong-option'));
    raise exception using errcode='P0002',message='Checkout accepted a changed offer';
  exception when raise_exception then
    if sqlerrm <> 'Review the current store offer' then raise; end if;
  end;
  if exists(select 1 from bloom_private.billing_offer_uses where offer_code='PLAY_FIXTURE') then
    raise exception 'A changed offer consumed a slot';
  end if;

  perform public.bloom_billing_account('prepare_mobile',input);
  select play_hold_until into strict first_hold from bloom_private.billing_offer_uses
    where offer_code='PLAY_FIXTURE' and profile_id=first_payer;
  perform public.bloom_billing_account('prepare_mobile',input);
  if first_hold is null or (select play_hold_until from bloom_private.billing_offer_uses
    where offer_code='PLAY_FIXTURE' and profile_id=first_payer) is distinct from first_hold then
    raise exception 'The same payer could not retry the existing hold without extending it';
  end if;

  perform set_config('request.jwt.claim.sub',second_payer::text,true);
  begin
    perform public.bloom_billing_account('prepare_mobile',input);
    raise exception using errcode='P0002',message='Checkout exceeded campaign capacity';
  exception when raise_exception then
    if sqlerrm <> 'Offer is unavailable' then raise; end if;
  end;
  update bloom_private.billing_offer_uses
    set reserved_at=now()-interval '1 hour',play_hold_until=now()-interval '30 minutes'
    where offer_code='PLAY_FIXTURE' and profile_id=first_payer;
  perform public.bloom_billing_account('prepare_mobile',input);

  -- Refresh with an old purchase and then a newly verified purchase of the held plan.
  paid_at := clock_timestamp();
  snapshot := jsonb_build_object('provider','play_store','sku','fixture-basic:month','subscription_ref','fixture-old-play',
    'status','expired','start_at',paid_at-interval '60 days','period_start',paid_at-interval '60 days',
    'end_at',paid_at-interval '30 days','cancel_at_end',true);
  perform public.bloom_apply_revenuecat(second_payer,clock_timestamp(),jsonb_build_array(snapshot));
  if (select play_hold_until from bloom_private.billing_offer_uses
    where offer_code='PLAY_FIXTURE' and profile_id=second_payer) is null then
    raise exception 'An unrelated historical purchase redeemed the current offer';
  end if;
  snapshot := snapshot||jsonb_build_object('subscription_ref','fixture-new-play','status','active',
    'start_at',paid_at,'period_start',paid_at,'end_at',paid_at+interval '30 days','cancel_at_end',false);
  perform public.bloom_apply_revenuecat(second_payer,clock_timestamp(),jsonb_build_array(snapshot));
  if not exists(select 1 from bloom_private.billing_offer_uses
    where offer_code='PLAY_FIXTURE' and profile_id=second_payer and play_hold_until is null) then
    raise exception 'A matching verified Play purchase did not redeem the hold';
  end if;
  begin
    perform public.bloom_billing_tap(first_payer,'play_offer',input);
    raise exception using errcode='P0002',message='A redeemed campaign slot reopened';
  exception when raise_exception then
    if sqlerrm <> 'Offer is unavailable' then raise; end if;
  end;
end
$$;

rollback;
