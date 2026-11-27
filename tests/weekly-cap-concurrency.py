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


user_id = "00000000-0000-0000-0000-000000000599"
setup_sql = f"""
begin;
insert into auth.users(id) values ('{user_id}') on conflict (id) do nothing;
insert into public.bloom_settings(user_id, credits_enabled, credit_timezone, reps_per_award, rep_award_minutes, weekly_earning_cap_minutes)
  values ('{user_id}', true, 'UTC', 10, 5, 12) on conflict (user_id) do nothing;
set local role authenticated;
select set_config('request.jwt.claim.sub', '{user_id}', true);
select public.bloom_save_growth_reward_rules('{user_id}', 'study', true, 5, 60, 60, 0, false);
select public.bloom_save_growth_reward_rules('{user_id}', 'read', true, 5, 60, 60, 0, false);
select public.bloom_save_growth_reward_rules('{user_id}', 'tasks', true, 5, 60, 60, 0, false);
select public.bloom_create_growth_item('study', 'subject', 'Race Study Cap', '', null, 30, '90000000-0000-0000-0000-000000000591');
select public.bloom_create_growth_item('read', 'reading', 'Race Read Cap', '', null, null, '90000000-0000-0000-0000-000000000592');
select public.bloom_create_growth_item('tasks', 'task', 'Race Task Cap', '', null, null, '90000000-0000-0000-0000-000000000593');
select public.bloom_create_plan_for_user(
  '{user_id}',
  'Race Plan Cap',
  jsonb_build_array(jsonb_build_object(
    'exercise_id', public.bloom_create_custom_exercise('Race Cap Pushup', 'Cap race', 'reps_only'),
    'sets', 1, 'target', 10
  ))
);
commit;
"""
code, _, err = run_psql(setup_sql)
assert code == 0, f"Weekly cap concurrency setup failed: {err}"

# Pre-start workout, study, and read sessions so all 4 completions race simultaneously.
pre_sql = f"""
begin;
set local role authenticated;
select set_config('request.jwt.claim.sub', '{user_id}', true);
select public.bloom_start_workout((select id from public.bloom_workout_plans where user_id = '{user_id}' limit 1));
select public.bloom_start_growth_session(
  'study',
  (select id from public.bloom_growth_items where profile_id = '{user_id}' and module_id = 'study'),
  '90000000-0000-0000-0000-000000000594', 'Test', '90000000-0000-0000-0000-000000000595'
);
select public.bloom_start_growth_session(
  'read',
  (select id from public.bloom_growth_items where profile_id = '{user_id}' and module_id = 'read'),
  '90000000-0000-0000-0000-000000000596', 'Test', '90000000-0000-0000-0000-000000000597'
);
commit;
"""
code, _, err = run_psql(pre_sql)
assert code == 0, f"Pre-start failed: {err}"

barrier = threading.Barrier(4)
results = []


def worker(sql: str):
    barrier.wait()
    results.append(run_psql(sql))


workout_sql = f"""
begin;
set local role authenticated;
select set_config('request.jwt.claim.sub', '{user_id}', true);
select public.bloom_complete_workout(
  (select id from public.bloom_workout_sessions where user_id = '{user_id}' and status = 'in_progress' limit 1),
  jsonb_build_array(jsonb_build_object(
    'exercise_id', (select id from public.exercises where bloom_owner_user_id = '{user_id}' limit 1),
    'sets_completed', 1, 'reps_completed', 10
  ))
);
commit;
"""
study_sql = f"""
begin;
set local role authenticated;
select set_config('request.jwt.claim.sub', '{user_id}', true);
select public.bloom_finish_growth_session(
  (select id from public.bloom_growth_sessions where profile_id = '{user_id}' and module_id = 'study' and status = 'in_progress' limit 1)
);
commit;
"""
read_sql = f"""
begin;
set local role authenticated;
select set_config('request.jwt.claim.sub', '{user_id}', true);
select public.bloom_finish_growth_session(
  (select id from public.bloom_growth_sessions where profile_id = '{user_id}' and module_id = 'read' and status = 'in_progress' limit 1)
);
commit;
"""
task_sql = f"""
begin;
set local role authenticated;
select set_config('request.jwt.claim.sub', '{user_id}', true);
select public.bloom_update_growth_item(
  (select id from public.bloom_growth_items where profile_id = '{user_id}' and module_id = 'tasks' limit 1),
  'Race Task Cap', '', null, 'completed', 100
);
commit;
"""

threads = [threading.Thread(target=worker, args=(s,)) for s in (workout_sql, study_sql, read_sql, task_sql)]
for t in threads:
    t.start()
for t in threads:
    t.join()

for c, _, e in results:
    assert c == 0, f"Concurrent completion failed: {e}"

code, total_str, err = run_psql(f"""
select coalesce(sum(amount_minutes), 0) from public.bloom_credit_ledger
where user_id = '{user_id}' and entry_type = 'earned';
""")
assert code == 0, f"Sum query failed: {err}"
total = float(total_str)
assert total == 12.0, f"Expected exact 12.0 minutes across 4 concurrent pillar completions, got {total}"

print("Concurrent cross-pillar earnings respected the 12-minute account-wide weekly cap.")
