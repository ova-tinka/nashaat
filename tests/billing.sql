begin;

insert into auth.users(id) values
 ('ac000000-0000-4000-8000-000000000001'),
 ('ac000000-0000-4000-8000-000000000002'),
 ('ac000000-0000-4000-8000-000000000003'),
 ('ac000000-0000-4000-8000-000000000004');

insert into public.bloom_households (id,owner_user_id,name)
values ('ac000000-0000-4000-8001-000000000001','ac000000-0000-4000-8000-000000000001','Fixture family');
insert into public.bloom_household_members (household_id,user_id,role) values
 ('ac000000-0000-4000-8001-000000000001','ac000000-0000-4000-8000-000000000001','parent'),
 ('ac000000-0000-4000-8001-000000000001','ac000000-0000-4000-8000-000000000002','child');

insert into public.bloom_subscription_products(plan_id,scope,billing_period,provider,provider_product_id,active,weekly_credits,seat_limit,currency,price_minor)
select tier, scope, period, provider, tier || '_' || scope || '_' || period, true,
  case when tier = 'basic' then 4 else 8 end,
  case when scope = 'household' then 2 else 1 end,
  case when provider = 'tap' then 'USD' end,
  case when provider = 'tap' then (case when tier = 'basic' then 1000 else 2000 end) end
from unnest(array['basic','premium']) tier cross join unnest(array['individual','household']) scope
cross join unnest(array['week','month','year']) period cross join unnest(array['app_store','play_store','tap']) provider;
update bloom_private.billing_config set checkout_enabled=true,notice_at=now()-interval '31 days',enforcement_at=now()-interval '1 day';
insert into bloom_private.billing_refund_staff values ('ac000000-0000-4000-8000-000000000004');

do $$
declare
  payer uuid := 'ac000000-0000-4000-8000-000000000001';
  member uuid := 'ac000000-0000-4000-8000-000000000002';
  visitor uuid := 'ac000000-0000-4000-8000-000000000003';
  staff uuid := 'ac000000-0000-4000-8000-000000000004';
  household uuid := 'ac000000-0000-4000-8001-000000000001';
  basic uuid;
  premium uuid;
  sub uuid;
  due uuid;
  charge uuid;
  refund uuid;
  details jsonb;
  prior_date timestamptz := now()-interval '20 days';
  v_input jsonb;
  attempted boolean;
begin
  if exists (select 1 from public.bloom_subscription_products where active
    group by provider having count(*) <> 12) then raise exception 'Incomplete catalog variants'; end if;
  select p.id into basic from public.bloom_subscription_products p where provider='tap' and provider_product_id='basic_household_year';
  select p.id into premium from public.bloom_subscription_products p where provider='tap' and provider_product_id='premium_household_year';
  insert into bloom_private.billing_offers(code,kind,product_id,amount_minor,starts_at,ends_at,redemption_limit)
    values ('WELCOME','intro',basic,700,now()-interval '1 day',now()+interval '1 day',1);
  v_input := jsonb_build_object('product_id',basic,'household_id',household,'accepted',true,'amount_minor',700,
    'recurring_minor',1000,'currency','USD','code','welcome');
  details := public.bloom_billing_tap(payer,'quote',v_input);
  if details->>'amount_minor' <> '700' or details->>'recurring_minor' <> '1000' then raise exception 'Offer price wrong'; end if;
  details := public.bloom_billing_tap(payer,'checkout',v_input);
  charge := (details->>'id')::uuid;
  if exists (select 1 from bloom_private.billing_coverage(payer,now())) then raise exception 'Pending checkout granted coverage'; end if;

  v_input := jsonb_build_object('id',charge,'provider_ref','chg_fixture','currency','USD','amount_minor',700,
    'state','captured','customer_ref','cus_fixture','card_ref','card_fixture','agreement_ref','agreement_fixture');
  perform public.bloom_billing_tap(null,'charge_result',v_input);
  perform public.bloom_billing_tap(null,'charge_result',v_input);
  select subscription_id into strict sub from bloom_private.billing_coverage(payer,clock_timestamp());
  if (select count(*) from public.bloom_subscriptions where payer_user_id=payer) <> 1 then
    raise exception 'Duplicate charge callback duplicated coverage';
  end if;
  update public.bloom_subscriptions set activated_at=prior_date,current_period_start=prior_date where id=sub;
  perform set_config('request.jwt.claim.sub',payer::text,true);
  perform public.bloom_billing_account('update_seat',jsonb_build_object('subscription_id',sub,'profile_id',member,'enabled',true));
  if exists (select 1 from bloom_private.billing_coverage(visitor,now())) then raise exception 'Unrelated profile read family coverage'; end if;
  if (select remaining from bloom_private.billing_usage_balance(member,clock_timestamp())) <> 4 then raise exception 'Child seat missing'; end if;

  details := public.bloom_billing_summary();
  if (details->>'remaining')::integer <> 4 or (details->>'next_refill_at')::timestamptz <> prior_date+interval '504 hours' then
    raise exception 'Annual plan should refill every 168 hours';
  end if;
  insert into bloom_private.coach_requests(id,profile_id,request_kind,prompt)
    values('ac000000-0000-4000-8002-000000000001',payer,'weekly','Synthetic fixture');
  if (public.bloom_billing_summary()->>'remaining')::integer <> 1 then raise exception 'Usage was not reserved'; end if;
  update bloom_private.coach_requests set status='failed' where id='ac000000-0000-4000-8002-000000000001';
  if (public.bloom_billing_summary()->>'remaining')::integer <> 4 then raise exception 'Failed usage was not released'; end if;
  insert into bloom_private.coach_requests(id,profile_id,request_kind,prompt)
    values('ac000000-0000-4000-8002-000000000002',payer,'chat','Synthetic fixture');
  update bloom_private.coach_requests set status='completed' where id='ac000000-0000-4000-8002-000000000002';
  if public.bloom_credit_balance() <> 0 then raise exception 'Usage changed screen-time minutes'; end if;
  if (select remaining from bloom_private.billing_usage_balance(member,clock_timestamp())) <> 4 then
    raise exception 'Payer usage depleted child credits';
  end if;
  if (select remaining from bloom_private.billing_usage_balance(payer,prior_date+interval '504 hours')) <> 4 then
    raise exception 'Spent units carried across a refill';
  end if;
  update public.bloom_subscriptions set product_id=premium where id=sub;
  if (public.bloom_billing_summary()->>'remaining')::integer <> 7 then raise exception 'Upgrade reset consumed units'; end if;

  perform public.bloom_apply_revenuecat(payer,now(),
    jsonb_build_array(jsonb_build_object('provider','app_store','sku','basic_individual_month','subscription_ref','receipt-fixture',
      'status','active','start_at',prior_date,'end_at',now()+interval '1 day','cancel_at_end',false)),'native-fixture','INITIAL_PURCHASE');
  perform public.bloom_apply_revenuecat(payer,now()-interval '1 minute','[]','reordered-fixture','EXPIRATION');
  if (select count(*) from public.bloom_subscriptions where payer_user_id=payer and status='active') <> 2
    or (public.bloom_billing_summary()->>'remaining')::integer <> 7 then
    raise exception 'Out-of-order or overlapping provider sync changed the allowance';
  end if;

  details := public.bloom_billing_tap(payer,'refund_request',jsonb_build_object('charge_id',charge,'reason','Fixture reason'));
  refund := (details->>'id')::uuid;
  perform public.bloom_billing_tap(staff,'refund_decision',jsonb_build_object('id',refund,'state','approved','amount_minor',300,'note','Fixture review'));
  perform public.bloom_billing_tap(null,'claim_refund',jsonb_build_object('id',refund));
  details := public.bloom_billing_tap(payer,'refund_request',jsonb_build_object('charge_id',charge,'reason','Second fixture request'));
  due := (details->>'id')::uuid;
  attempted := false;
  begin
    perform public.bloom_billing_tap(staff,'refund_decision',jsonb_build_object('id',due,'state','approved','amount_minor',401,'note','Fixture review'));
  exception when raise_exception then attempted := true;
  end;
  if not attempted then raise exception 'Pending partial refund did not reserve refundable amount'; end if;
  perform public.bloom_billing_tap(null,'refund_result',jsonb_build_object('id',refund,'provider_ref','re_fixtureA',
    'currency','USD','charge_ref','chg_fixture','amount_minor',300,'state','refunded'));
  if (select status from public.bloom_subscriptions where id=sub) <> 'active' then raise exception 'Partial refund revoked coverage'; end if;
  perform public.bloom_billing_tap(staff,'refund_decision',jsonb_build_object('id',due,'state','approved','amount_minor',400,'note','Fixture review'));
  perform public.bloom_billing_tap(null,'claim_refund',jsonb_build_object('id',due));
  perform public.bloom_billing_tap(null,'refund_result',jsonb_build_object('id',due,'provider_ref','re_fixtureB',
    'currency','USD','charge_ref','chg_fixture','amount_minor',400,'state','refunded'));
  if (select status from public.bloom_subscriptions where id=sub) <> 'revoked' then raise exception 'Full current refund left coverage active'; end if;

  insert into bloom_private.tap_attempts(payer,product_id,subscription_id,kind,state,currency,amount_minor,recurring_minor)
    values(payer,basic,sub,'card_update','captured','USD',100,1000);
  details := public.bloom_billing_tap(payer,'history');
  if jsonb_array_length(details->'charges') <> 1 or details->'charges'->0->>'id' <> charge::text
    or jsonb_array_length(details->'refunds') <> 2
    or exists (select 1 from jsonb_array_elements(details->'refunds') item
      where item->>'charge_id' <> charge::text or item->>'state' <> 'refunded') then
    raise exception 'Payer history did not return the charge and both refunds while hiding the card authorization';
  end if;
  details := public.bloom_billing_tap(visitor,'history');
  if jsonb_array_length(details->'charges') <> 0 or jsonb_array_length(details->'refunds') <> 0 then
    raise exception 'Payment history leaked to an unrelated member';
  end if;
end
$$;

do $$
declare
  payer uuid := 'ac000000-0000-4000-8000-000000000003';
  basic uuid := (select id from public.bloom_subscription_products where provider='tap' and provider_product_id='basic_individual_month');
  premium uuid := (select id from public.bloom_subscription_products where provider='tap' and provider_product_id='premium_individual_month');
  anchor timestamptz := date_trunc('second',now())-interval '1 month 1 day';
  old_end timestamptz := bloom_private.billing_term_end(anchor,'month',1);
  new_end timestamptz := bloom_private.billing_term_end(anchor,'month',2);
  sub uuid;
  charge uuid;
  downgrade_at timestamptz;
  quote jsonb;
  verified jsonb;
  agreement jsonb := jsonb_build_object('customer_ref','cus_fixture','card_ref','card_fixture','agreement_ref','agreement_fixture');
begin
  insert into public.bloom_subscriptions(payer_user_id,product_id,provider_subscription_id,billing_provider,
    status,activated_at,current_period_start,current_period_end)
  values(payer,basic,'tap-renewal-fixture','tap','active',anchor,anchor,old_end)
    returning id into sub;
  insert into bloom_private.tap_agreements(subscription_id,customer_ref,card_ref,agreement_ref,
    accepted_at,recurring_minor,currency,term_anchor)
  values(sub,'cus_fixture','card_fixture','agreement_fixture',anchor,1000,'USD',anchor);

  charge := (public.bloom_billing_tap(null,'claim_renewal',jsonb_build_object('id',sub))#>>'{}')::uuid;
  if charge is null or public.bloom_billing_tap(null,'claim_renewal',jsonb_build_object('id',sub)) <> 'null'::jsonb then
    raise exception 'Tap should enqueue one renewal per term';
  end if;
  verified := public.bloom_billing_tap(null,'claim_charge',jsonb_build_object('id',charge));
  if verified->'agreement'->>'agreement_ref' <> 'agreement_fixture'
    or public.bloom_billing_tap(null,'claim_charge',jsonb_build_object('id',charge)) <> 'null'::jsonb then
    raise exception 'A worker should claim the saved agreement and defer duplicate attempts';
  end if;
  perform public.bloom_billing_tap(null,'charge_result',jsonb_build_object('id',charge,'provider_ref','chg_declined_fixture',
    'currency','USD','amount_minor',1000,'state','declined'));
  if not exists (select 1 from bloom_private.billing_coverage(payer,clock_timestamp())
    where status='grace_period' and period_end=old_end) then
    raise exception 'A declined renewal advanced the paid term or removed recovery access';
  end if;

  quote := public.bloom_billing_tap(payer,'quote',jsonb_build_object('product_id',basic));
  if quote->>'kind' <> 'recovery' or quote->>'amount_minor' <> '1000' then raise exception 'Recovery quote is wrong'; end if;
  charge := (public.bloom_billing_tap(payer,'checkout',quote||jsonb_build_object('product_id',basic,'accepted',true))->>'id')::uuid;
  verified := agreement||jsonb_build_object('id',charge,'provider_ref','chg_recovered_fixture','state','captured',
    'currency','USD','amount_minor',1000);
  perform public.bloom_billing_tap(null,'charge_result',verified);
  perform public.bloom_billing_tap(null,'charge_result',verified);
  if not exists (select 1 from public.bloom_subscriptions where id=sub and status='active'
    and activated_at=anchor and current_period_start=old_end and current_period_end=new_end)
    or (select term_number from bloom_private.tap_agreements where subscription_id=sub) <> 2 then
    raise exception 'Verified recovery should renew the original term once and preserve its anchor';
  end if;

  quote := public.bloom_billing_tap(payer,'quote',jsonb_build_object('product_id',premium));
  if quote->>'kind' <> 'upgrade' or (quote->>'amount_minor')::integer not between 1 and 999
    or quote->>'recurring_minor' <> '2000' then raise exception 'Upgrade was not prorated'; end if;
  verified := public.bloom_billing_tap(payer,'checkout',quote||jsonb_build_object('product_id',premium,'accepted',true));
  charge := (verified->>'id')::uuid;
  if not exists (select 1 from bloom_private.billing_coverage(payer,clock_timestamp()) where tier='basic') then
    raise exception 'An unconfirmed upgrade granted Premium';
  end if;
  perform public.bloom_billing_tap(null,'charge_result',agreement||jsonb_build_object('id',charge,
    'provider_ref','chg_upgrade_fixture','state','captured','currency','USD','amount_minor',verified->'amount_minor'));
  if not exists (select 1 from bloom_private.billing_coverage(payer,clock_timestamp()) where tier='premium' and period_end=new_end)
    or not (select reauthorize_at_renewal from bloom_private.tap_agreements where subscription_id=sub) then
    raise exception 'Confirmed upgrade lost the paid term or can raise renewal without consent';
  end if;

  perform public.bloom_billing_tap(payer,'schedule',jsonb_build_object('subscription_id',sub,'product_id',basic));
  if (public.bloom_billing_tap(payer,'history')->'scheduled'->>'product_id')::uuid is distinct from basic then
    raise exception 'Scheduled downgrade missing from payer history';
  end if;
  downgrade_at := clock_timestamp()-interval '1 second';
  update public.bloom_subscriptions set current_period_end=downgrade_at where id=sub;
  if public.bloom_billing_tap(null,'claim_renewal',jsonb_build_object('id',sub)) is distinct from 'null'::jsonb then
    raise exception 'Downgrade requiring fresh authorization should not auto-charge';
  end if;
  quote := public.bloom_billing_tap(payer,'quote',jsonb_build_object('product_id',basic));
  if quote->>'kind' <> 'recovery' or quote->>'amount_minor' <> '1000' then
    raise exception 'Scheduled downgrade should authorize Basic pricing';
  end if;
  charge := (public.bloom_billing_tap(payer,'checkout',quote||jsonb_build_object('product_id',basic,'accepted',true))->>'id')::uuid;
  perform public.bloom_billing_tap(null,'charge_result',agreement||jsonb_build_object('id',charge,
    'provider_ref','chg_downgrade_fixture','state','captured','currency','USD','amount_minor',1000));
  if not exists (select 1 from bloom_private.billing_coverage(payer,clock_timestamp())
    where tier='basic' and period_end=bloom_private.billing_term_end(downgrade_at,'month',1)) then
    raise exception 'Verified downgrade did not start Basic at the scheduled boundary';
  end if;

  perform public.bloom_billing_tap(payer,'cancel',jsonb_build_object('subscription_id',sub));
  if not exists (select 1 from bloom_private.billing_coverage(payer,clock_timestamp()) where tier='basic' and cancel_at_end) then
    raise exception 'Period-end cancellation removed access early';
  end if;
  update public.bloom_subscriptions set current_period_end=clock_timestamp()-interval '1 second' where id=sub;
  perform public.bloom_billing_tap(null,'due');
  if exists(select 1 from bloom_private.billing_coverage(payer,clock_timestamp()))
    or public.bloom_billing_tap(null,'claim_renewal',jsonb_build_object('id',sub)) <> 'null'::jsonb then
    raise exception 'Cancelled coverage or charge survived the end of the term';
  end if;
end
$$;

set local role authenticated;
select set_config('request.jwt.claim.sub','ac000000-0000-4000-8000-000000000002',true);
do $$
begin
  if has_function_privilege(current_user,'public.bloom_billing_tap(uuid,text,jsonb)','EXECUTE')
    or has_function_privilege(current_user,'public.bloom_apply_revenuecat(uuid,timestamptz,jsonb,text,text)','EXECUTE') then
    raise exception 'Authenticated clients can submit provider states';
  end if;
  if exists(select 1 from public.bloom_credit_ledger where entry_type='usage')
    or exists(select 1 from public.bloom_subscriptions)
    or jsonb_array_length(public.bloom_billing_summary()->'recent_usage') <> 0 then
    raise exception 'Household recipient read another payer’s billing or usage';
  end if;
end
$$;

rollback;
