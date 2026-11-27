-- Run in the dedicated sandbox project only, after the billing migrations.
-- List prices are fixtures. Replace store IDs here if your sandbox uses other IDs.
begin;
insert into public.bloom_subscription_products(plan_id,scope,billing_period,provider,provider_product_id,
  active,weekly_credits,seat_limit,currency,price_minor)
select tier,scope,period,provider,
  case provider
    when 'app_store' then 'bloom_'||tier||'_'||scope||'_'||period
    when 'play_store' then 'bloom_'||tier||'_'||scope||':'||period
    else tier||'_'||scope||'_'||period
  end,
  true,case tier when 'basic' then 10 else 30 end,
  case scope when 'individual' then 1 else 5 end,
  case provider when 'tap' then 'USD' end,
  case provider when 'tap' then (case period when 'week' then 299 when 'month' then 799 else 6999 end)
    * (case when tier='premium' then 2 else 1 end) * (case when scope='household' then 2 else 1 end) end
from unnest(array['basic','premium']) tier cross join unnest(array['individual','household']) scope
cross join unnest(array['week','month','year']) period cross join unnest(array['app_store','play_store','tap']) provider
on conflict(provider,provider_product_id) do nothing;
-- The first run opens the fixture campaign window. Running the seed again
-- preserves both the dates and existing redemptions.
insert into bloom_private.billing_offers(code,kind,product_id,amount_minor,play_option_id,starts_at,ends_at,redemption_limit)
select fixture.code,fixture.kind,p.id,fixture.amount_minor,fixture.play_option_id,now(),now()+interval '30 days',fixture.redemption_limit
from (values
  ('SANDBOX_WEB_INTRO','intro','tap','basic_individual_month',499,null,25),
  ('SANDBOX_WEB_CAMPAIGN','campaign','tap','basic_individual_month',599,null,10),
  ('SANDBOX_WEB_WINBACK','win_back','tap','basic_individual_month',399,null,15),
  ('SANDBOX_PLAY_CAMPAIGN','campaign','play_store','bloom_basic_individual:month',null,'month:bloom-sandbox-campaign',10),
  ('SANDBOX_PLAY_WINBACK','win_back','play_store','bloom_basic_individual:month',null,'month:bloom-sandbox-winback',15)
) fixture(code,kind,provider,sku,amount_minor,play_option_id,redemption_limit)
join public.bloom_subscription_products p on p.provider=fixture.provider and p.provider_product_id=fixture.sku
on conflict (code) do nothing;
commit;
