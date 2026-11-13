import subprocess
import sys
import os

user_id = "00000000-0000-0000-0000-000000000031"
if len(sys.argv) > 1:
    container = sys.argv[1]
    psql = ["docker", "exec", "-i", container, "psql", "-q", "-v", "ON_ERROR_STOP=1", "-U", "postgres", "-d", "postgres"]
else:
    host = os.environ.get("BLOOM_TEST_PG_HOST")
    if not host:
        raise SystemExit("Pass a Docker test container or set BLOOM_TEST_PG_HOST for an isolated local test database.")
    psql = ["psql", "-q", "-v", "ON_ERROR_STOP=1", "-h", host,
        "-p", os.environ.get("BLOOM_TEST_PG_PORT", "5432"),
        "-U", os.environ.get("BLOOM_TEST_PG_USER", "postgres"),
        "-d", os.environ.get("BLOOM_TEST_PG_DATABASE", "postgres")]
setup = f"""
insert into auth.users(id) values ('{user_id}');
insert into public.bloom_settings(user_id, credit_mode, credit_timezone)
values ('{user_id}', 'hard', case when extract(hour from now() at time zone 'UTC') = 23 then 'Pacific/Honolulu' else 'UTC' end);
insert into public.bloom_credit_ledger(user_id, amount_minutes, entry_type, idempotency_key, expires_at)
values ('{user_id}', 70, 'earned', 'concurrent-fixture', now() + interval '1 hour');
"""
subprocess.run(psql, input=setup, text=True, check=True, stdout=subprocess.DEVNULL)

processes = []
for request in ("50000000-0000-0000-0000-000000000031", "50000000-0000-0000-0000-000000000032"):
    sql = f"""begin;
set local role authenticated;
select set_config('request.jwt.claim.sub', '{user_id}', true);
select * from public.bloom_start_credit_session('{request}', 5);
select pg_sleep(0.5);
commit;
"""
    process = subprocess.Popen(psql, stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    processes.append((process, sql))

for process, sql in processes:
    process.stdin.write(sql)
    process.stdin.close()

results = []
for process, _ in processes:
    stdout = process.stdout.read()
    stderr = process.stderr.read()
    results.append((process.wait(), stdout, stderr))

if sum(code == 0 for code, _, _ in results) != 1:
    raise SystemExit("Concurrent requests did not produce exactly one successful countdown")
if not any("A screen-time session is already running" in stderr for code, _, stderr in results if code != 0):
    raise SystemExit("The second concurrent request failed for an unexpected reason")

print("Concurrent countdown requests were serialized.")

user_id = "00000000-0000-0000-0000-000000000032"
setup = f"""
insert into auth.users(id) values ('{user_id}');
insert into public.bloom_settings(user_id, credit_mode, credit_timezone) values ('{user_id}', 'easy', 'UTC');
insert into public.bloom_credit_ledger(user_id, amount_minutes, entry_type, idempotency_key, expires_at)
values ('{user_id}', 10, 'earned', 'concurrent-usage-fixture', now() + interval '1 hour');
"""
subprocess.run(psql, input=setup, text=True, check=True, stdout=subprocess.DEVNULL)
processes = []
for suffix in ("41", "42"):
    sql = f"""begin;
set local role authenticated;
select set_config('request.jwt.claim.sub', '{user_id}', true);
select * from public.bloom_start_usage_session('50000000-0000-0000-0000-0000000000{suffix}', '70000000-0000-0000-0000-0000000000{suffix}', 60000);
select pg_sleep(0.5);
commit;
"""
    process = subprocess.Popen(psql, stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    processes.append((process, sql))
for process, sql in processes:
    process.stdin.write(sql)
    process.stdin.close()
results = [(process.wait(), process.stdout.read(), process.stderr.read()) for process, _ in processes]
if sum(code == 0 for code, _, _ in results) != 1:
    raise SystemExit("Concurrent usage reservations did not produce exactly one successful request")
if not any("A screen-time reservation is already active on another device" in stderr for code, _, stderr in results if code != 0):
    raise SystemExit("The second concurrent usage request failed for an unexpected reason")
print("Concurrent server-timed access reservations were serialized.")
