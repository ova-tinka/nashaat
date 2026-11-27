import concurrent.futures
import subprocess
import sys
import threading

psql = ['docker', 'exec', '-i', sys.argv[1], 'psql', '-qAt', '-v', 'ON_ERROR_STOP=1', '-U', 'postgres', '-d', 'postgres']
payer = 'bc000000-0000-4000-8000-000000000001'
monthly = 'bc000000-0000-4000-8001-000000000001'
subscription = 'bc000000-0000-4000-8002-000000000001'

def run(statement, check=True):
    return subprocess.run(psql, input=statement, text=True, capture_output=True, check=check)

run(f"""
insert into auth.users (id) values ('{payer}');
insert into public.bloom_subscription_products(id,plan_id,scope,billing_period,provider,provider_product_id,weekly_credits,active)
values('{monthly}','basic','individual','month','tap','fixture-concurrent-monthly',3,true);
insert into public.bloom_subscriptions(id,payer_user_id,product_id,provider_subscription_id,billing_provider,status,activated_at,current_period_start,current_period_end)
values('{subscription}','{payer}','{monthly}','fixture-billing-concurrent','tap','active',now()-interval '8 days',now()-interval '8 days',now()+interval '22 days');
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

try:
    with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
        results = list(pool.map(reserve, [1, 2]))
    failures = [result for result in results if result.returncode]
    assert len(failures) == 1 and 'BLOOM_USAGE_CREDITS_EXHAUSTED' in failures[0].stderr, [result.stderr for result in results]
    summary = run(f"select remaining from bloom_private.billing_usage_balance('{payer}',clock_timestamp());")
    assert summary.stdout.strip() == '0', summary.stdout
    print('Concurrent billing usage requests respected the weekly allowance.')
finally:
    run(f"""
    delete from public.bloom_subscriptions where id='{subscription}';
    delete from public.bloom_subscription_products where id='{monthly}';
    delete from public.bloom_profiles where id='{payer}' and not exists (
      select 1 from public.bloom_profile_accounts where profile_id='{payer}'
    );
    """)
