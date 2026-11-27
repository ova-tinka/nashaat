import os
import subprocess
import sys
import threading

container = sys.argv[1] if len(sys.argv) > 1 else None
pg_host = os.environ.get("BLOOM_TEST_PG_HOST")
pg_port = os.environ.get("BLOOM_TEST_PG_PORT")
pg_user = os.environ.get("BLOOM_TEST_PG_USER")
pg_db = os.environ.get("BLOOM_TEST_PG_DATABASE", "postgres")


def run_psql(sql: str):
    if container:
        cmd = ["docker", "exec", "-i", container, "psql", "-X", "-At", "-v", "ON_ERROR_STOP=1", "-U", "postgres", "-d", "postgres"]
    else:
        cmd = ["psql", "-X", "-At", "-v", "ON_ERROR_STOP=1", "-h", pg_host, "-p", pg_port, "-U", pg_user, "-d", pg_db]
    res = subprocess.run(cmd, input=sql, text=True, capture_output=True)
    return res.returncode, res.stdout.strip(), res.stderr.strip()


setup_sql = """
begin;
insert into auth.users(id) values ('00000000-0000-0000-0000-000000000499') on conflict (id) do nothing;
insert into public.bloom_settings(user_id, credits_enabled)
  values ('00000000-0000-0000-0000-000000000499', true) on conflict (user_id) do nothing;
set local role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000499', true);
select public.bloom_create_growth_item('study', 'subject', 'Concurrency Study', '', null, 60,
  '90000000-0000-0000-0000-000000000491');
select public.bloom_set_growth_ai_preferences('study', true, true);
select public.bloom_begin_study_tutor_request(
  '90000000-0000-0000-0000-000000000492',
  (select id from public.bloom_growth_items where profile_id = '00000000-0000-0000-0000-000000000499' and title = 'Concurrency Study'),
  'Explain gravity'
);
commit;
"""
code, _, err = run_psql(setup_sql)
assert code == 0, f"Setup failed: {err}"

# Race clear_study_tutor_conversation() vs finish_study_tutor_request() concurrently.
barrier = threading.Barrier(2)
race_results = []


def worker(sql: str):
    barrier.wait()
    race_results.append(run_psql(sql))


clear_sql = """
begin;
set local role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000499', true);
select public.bloom_clear_study_tutor_conversation();
commit;
"""
finish_sql = """
begin;
set local role service_role;
select public.bloom_finish_study_tutor_request(
  '90000000-0000-0000-0000-000000000492',
  'Explain gravity',
  'Gravity is the attraction between masses.',
  'General explanation only.'
);
commit;
"""

t1 = threading.Thread(target=worker, args=(clear_sql,))
t2 = threading.Thread(target=worker, args=(finish_sql,))
t1.start()
t2.start()
t1.join()
t2.join()

for c, out, e in race_results:
    assert c == 0, f"Concurrent clear/finish failed unexpectedly: {e}"

# Regardless of lock acquisition order, 0 messages must exist after both complete,
# unless finish ran first and clear ran second (which also deletes all messages).
# Wait: in either order (clear->finish or finish->clear), 0 messages must remain!
code, msg_count, err = run_psql("""
select count(*) from public.bloom_study_tutor_messages
where profile_id = '00000000-0000-0000-0000-000000000499';
""")
assert code == 0 and msg_count == "0", f"Expected 0 messages after clear/finish race, got {msg_count} ({err})"

# Verify quota event was preserved (count = 1).
code, quota_count, err = run_psql("""
select count(*) from bloom_private.growth_ai_quota_events
where profile_id = '00000000-0000-0000-0000-000000000499';
""")
assert code == 0 and quota_count == "1", f"Expected 1 preserved quota event, got {quota_count} ({err})"

# Race two simultaneous begin_* requests across Study Tutor and Tasks for a fresh profile.
begin_setup = """
begin;
insert into auth.users(id) values ('00000000-0000-0000-0000-000000000498') on conflict (id) do nothing;
insert into public.bloom_settings(user_id, credits_enabled)
  values ('00000000-0000-0000-0000-000000000498', true) on conflict (user_id) do nothing;
set local role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000498', true);
select public.bloom_create_growth_item('study', 'subject', 'Race Study', '', null, 60,
  '90000000-0000-0000-0000-000000000493');
select public.bloom_create_growth_item('tasks', 'task', 'Race Task', '', null, null,
  '90000000-0000-0000-0000-000000000494');
select public.bloom_set_growth_ai_preferences('study', true, true);
select public.bloom_set_growth_ai_preferences('tasks', true, true);
commit;
"""
code, _, err = run_psql(begin_setup)
assert code == 0, f"Concurrent begin setup failed: {err}"

begin_barrier = threading.Barrier(2)
begin_results = []


def begin_worker(sql: str):
    begin_barrier.wait()
    begin_results.append(run_psql(sql))


begin_study_sql = """
begin;
set local role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000498', true);
select public.bloom_begin_study_tutor_request(
  '90000000-0000-0000-0000-000000000495',
  (select id from public.bloom_growth_items where profile_id = '00000000-0000-0000-0000-000000000498' and module_id = 'study'),
  'Explain momentum'
);
select pg_sleep(0.3);
commit;
"""
begin_task_sql = """
begin;
set local role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000498', true);
select public.bloom_begin_growth_ai_request(
  '90000000-0000-0000-0000-000000000496',
  'tasks',
  'task_breakdown',
  (select id from public.bloom_growth_items where profile_id = '00000000-0000-0000-0000-000000000498' and module_id = 'tasks'),
  'Break down task'
);
select pg_sleep(0.3);
commit;
"""

bt1 = threading.Thread(target=begin_worker, args=(begin_study_sql,))
bt2 = threading.Thread(target=begin_worker, args=(begin_task_sql,))
bt1.start()
bt2.start()
bt1.join()
bt2.join()

successes = sum(1 for c, _, _ in begin_results if c == 0)
failures = [e for c, _, e in begin_results if c != 0]
assert successes == 1 and len(failures) == 1, f"Expected 1 success and 1 failure, got {begin_results}"
assert "An AI request is already running" in failures[0], f"Unexpected failure reason: {failures[0]}"

print("Concurrent Study Tutor clear vs finish serialized cleanly with 0 leaked messages.")
