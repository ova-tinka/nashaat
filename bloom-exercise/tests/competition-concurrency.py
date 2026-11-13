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
            '-p', os.environ.get('BLOOM_TEST_PG_PORT', '5432'), '-U', os.environ.get('BLOOM_TEST_PG_USER', 'postgres'),
            '-d', os.environ.get('BLOOM_TEST_PG_DATABASE', 'postgres')]

owner = '00000000-0000-0000-0000-000000000191'
users = ['00000000-0000-0000-0000-000000000192', '00000000-0000-0000-0000-000000000193']
event = '19000000-0000-0000-0000-000000000191'
code = 'b' * 64
setup = f"""
insert into auth.users(id) values ('{owner}'), ('{users[0]}'), ('{users[1]}');
insert into public.bloom_social_profiles(profile_id, display_name) values ('{owner}', 'Owner'), ('{users[0]}', 'One'), ('{users[1]}', 'Two');
insert into public.bloom_competitions(id, owner_profile_id, title, metric, visibility, status, max_participants, starts_at, ends_at, published_at)
 values ('{event}', '{owner}', 'Race', 'workouts', 'private', 'published', 2, now() + interval '1 hour', now() + interval '2 hours', now());
insert into public.bloom_competition_participants(competition_id, profile_id, status, approved_at) values ('{event}', '{owner}', 'approved', now());
insert into bloom_private.competition_link_invites(token_hash, competition_id, created_by, expires_at)
 values (sha256(convert_to('{code}', 'UTF8')), '{event}', '{owner}', now() + interval '1 hour');
"""
subprocess.run(psql, input=setup, text=True, check=True, stdout=subprocess.DEVNULL)
processes = []
for user in users:
    sql = f"""begin;
set local role authenticated;
select set_config('request.jwt.claim.sub', '{user}', true);
select public.bloom_accept_competition_link('{code}');
select pg_sleep(0.5);
commit;
"""
    process = subprocess.Popen(psql, stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    processes.append((process, sql))
for process, sql in processes:
    process.stdin.write(sql)
    process.stdin.close()
results = [(process.wait(), process.stdout.read(), process.stderr.read()) for process, _ in processes]
if sum(code == 0 for code, _, _ in results) != 1 or not any('Competition is full' in err for status, _, err in results if status != 0):
    raise SystemExit('Concurrent joins did not enforce event capacity')
check = subprocess.run(psql, input=f"select count(*) from public.bloom_competition_participants where competition_id = '{event}' and status = 'approved';",
                       text=True, check=True, capture_output=True).stdout.strip()
if check != '2':
    raise SystemExit('Concurrent joins created the wrong participant count')
print('Concurrent competition joins respected capacity.')
