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
commit;
