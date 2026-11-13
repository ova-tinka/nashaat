import os
import subprocess
import sys

if len(sys.argv) > 1:
    psql = ['docker', 'exec', '-i', sys.argv[1], 'psql', '-qAt', '-v', 'ON_ERROR_STOP=1', '-U', 'postgres', '-d', 'postgres']
else:
    host = os.environ.get('BLOOM_TEST_PG_HOST')
    if not host:
        raise SystemExit('An isolated test database is required.')
    psql = ['psql', '-qAt', '-v', 'ON_ERROR_STOP=1', '-h', host,
            '-p', os.environ.get('BLOOM_TEST_PG_PORT', '5432'),
            '-U', os.environ.get('BLOOM_TEST_PG_USER', 'postgres'),
            '-d', os.environ.get('BLOOM_TEST_PG_DATABASE', 'postgres')]

user = '00000000-0000-0000-0000-000000000131'
family = '13000000-0000-0000-0000-000000000131'
request = '13000000-0000-0000-0000-000000000132'
setup = f"""
insert into auth.users(id) values ('{user}');
insert into public.bloom_households(id, owner_user_id, name) values ('{family}', '{user}', 'Test');
insert into public.bloom_household_members(household_id, user_id, role) values ('{family}', '{user}', 'parent');
"""
subprocess.run(psql, input=setup, text=True, check=True, stdout=subprocess.DEVNULL)

sql = f"""begin;
set local role authenticated;
select set_config('request.jwt.claim.sub', '{user}', true);
select public.bloom_create_child_profile('{family}', 'Child', '{request}');
select pg_sleep(0.5);
commit;
"""
processes = [subprocess.Popen(psql, stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True) for _ in range(2)]
for process in processes:
    process.stdin.write(sql)
    process.stdin.close()
results = []
for process in processes:
    stdout, stderr = process.stdout.read(), process.stderr.read()
    if process.wait() != 0:
        raise SystemExit(f'Concurrent profile request failed: {stderr}')
    ids = [line for line in stdout.splitlines() if line and line != user]
    if len(ids) != 1:
        raise SystemExit('Unexpected profile request result')
    results.append(ids[0])
if results[0] != results[1]:
    raise SystemExit('Concurrent retries returned different profiles')
count = subprocess.run(psql, input=f"select count(*) from public.bloom_child_profiles where household_id = '{family}';",
                       text=True, check=True, capture_output=True).stdout.strip()
if count != '1':
    raise SystemExit('Concurrent retries created duplicate profiles')
print('Concurrent child profile retries were serialized.')
