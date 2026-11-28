import concurrent.futures
import subprocess
import sys
import threading

psql = ['docker', 'exec', '-i', sys.argv[1], 'psql', '-qAt', '-v', 'ON_ERROR_STOP=1', '-U', 'postgres', '-d', 'postgres']
payer = 'bc000000-0000-4000-8000-000000000001'
monthly = 'bc000000-0000-4000-8001-000000000001'
subscription = 'bc000000-0000-4000-8002-000000000001'
staff = ['bc000000-0000-4000-8000-000000000002', 'bc000000-0000-4000-8000-000000000003']
charge = 'bc000000-0000-4000-8002-000000000002'
first_refund = 'bc000000-0000-4000-8002-000000000003'
next_refund = 'bc000000-0000-4000-8002-000000000004'
webhook_event = 'webhook:chg_concurrenttest:CAPTURED'

def run(statement, check=True):
    return subprocess.run(psql, input=statement, text=True, capture_output=True, check=check)

run(f"""
insert into auth.users (id) values ('{payer}'), ('{staff[0]}'), ('{staff[1]}');
insert into bloom_private.billing_refund_staff values ('{staff[0]}'), ('{staff[1]}');
insert into public.bloom_subscription_products(id,plan_id,scope,billing_period,provider,provider_product_id,weekly_credits,active)
values('{monthly}','basic','individual','month','tap','fixture-concurrent-monthly',3,true);
insert into public.bloom_subscriptions(id,payer_user_id,product_id,provider_subscription_id,billing_provider,status,activated_at,current_period_start,current_period_end)
values('{subscription}','{payer}','{monthly}','fixture-billing-concurrent','tap','active',now()-interval '8 days',now()-interval '8 days',now()+interval '22 days');
insert into bloom_private.tap_attempts
  (id,payer,product_id,subscription_id,kind,state,currency,amount_minor,recurring_minor,provider_ref)
values ('{charge}','{payer}','{monthly}','{subscription}','initial','captured','USD',700,700,'chg_concurrent_fixture');
insert into bloom_private.tap_refunds (id,charge_id,payer,state,amount_minor,reason)
values ('{first_refund}','{charge}','{payer}','pending',300,'First partial refund'),
  ('{next_refund}','{charge}','{payer}','requested',null,'Remaining amount');
""")
barrier = threading.Barrier(2)

def reserve(attempt):
    barrier.wait()
    return run(f"""
      begin;
      insert into bloom_private.coach_requests(id,profile_id,request_kind,prompt)
      values ('bc000000-0000-4000-8003-00000000000{attempt}','{payer}','weekly','Concurrency fixture');
      select pg_sleep(0.4);
      commit;
    """, check=False)

def approve(reviewer):
    barrier.wait()
    return run(f"""
      begin;
      select public.bloom_billing_tap('{reviewer}','refund_decision',
        jsonb_build_object('id','{next_refund}','state','approved','amount_minor',400,'note','Concurrent review'));
      select pg_sleep(0.4);
      commit;
    """, check=False)

def claim_webhook(_):
    barrier.wait()
    return run("""
      begin;
      select count(*) from public.bloom_claim_billing_webhooks();
      select pg_sleep(0.4);
      commit;
    """).stdout.strip()

try:
    with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
        results = list(pool.map(reserve, [1, 2]))
    failures = [result for result in results if result.returncode]
    assert len(failures) == 1 and 'BLOOM_USAGE_CREDITS_EXHAUSTED' in failures[0].stderr, [result.stderr for result in results]
    summary = run(f"select remaining from bloom_private.billing_usage_balance('{payer}',clock_timestamp());")
    assert summary.stdout.strip() == '0', summary.stdout
    print('Concurrent billing usage requests respected the weekly allowance.')
    with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
        results = list(pool.map(approve, staff))
    failures = [result for result in results if result.returncode]
    assert len(failures) == 1 and 'Request already reviewed' in failures[0].stderr, [result.stderr for result in results]
    total = run(f"""
        select sum(amount_minor),count(*) filter (where state='approved')
        from bloom_private.tap_refunds where charge_id='{charge}' and state in ('approved','pending','refunded','review');
    """)
    assert total.stdout.strip() == '700|1', total.stdout
    print('Concurrent partial refund approvals respected the remaining refundable amount.')

    run(f"select public.bloom_queue_billing_webhook('tap','{webhook_event}','payment_callback','chg_concurrenttest');")
    with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
        claims = list(pool.map(claim_webhook, [1, 2]))
    assert sorted(claims) == ['0', '1'], claims
    print('Concurrent billing workers did not claim the same webhook.')
finally:
    run(f"""
    delete from public.bloom_billing_events where provider='tap' and provider_event_id='{webhook_event}';
    delete from bloom_private.tap_refunds where charge_id='{charge}';
    delete from bloom_private.tap_attempts where id='{charge}';
    delete from bloom_private.billing_refund_staff where profile_id in ('{staff[0]}','{staff[1]}');
    delete from public.bloom_subscriptions where id='{subscription}';
    delete from public.bloom_subscription_products where id='{monthly}';
    delete from auth.users where id in ('{payer}','{staff[0]}','{staff[1]}');
    delete from public.bloom_profiles where id in ('{payer}','{staff[0]}','{staff[1]}');
    """)
