#!/usr/bin/env bash
set -euo pipefail

bloom_dir="$(cd "$(dirname "$0")/.." && pwd)"
bloom_root="$(cd "$bloom_dir/.." && pwd)"
bloom_test_container="bloom-exercise-test-$$"

docker run --rm -d --name "$bloom_test_container" \
  -e POSTGRES_HOST_AUTH_METHOD=trust postgres:16-alpine >/dev/null
trap 'docker stop "$bloom_test_container" >/dev/null 2>&1 || true' EXIT

for attempt in {1..45}; do
  bloom_ready_count=$(docker logs "$bloom_test_container" 2>&1 | grep -c 'database system is ready to accept connections' || true)
  if [ "${bloom_ready_count:-0}" -ge 2 ]; then break; fi
  sleep 1
done

docker exec -i "$bloom_test_container" psql -q -v ON_ERROR_STOP=1 -U postgres -d postgres >/dev/null <<'SQL'
create role anon nologin;
create role authenticated nologin;
create role service_role nologin bypassrls;
create schema auth;
create table auth.users (id uuid primary key, raw_app_meta_data jsonb not null default '{}'::jsonb,
  email text, email_confirmed_at timestamptz, is_anonymous boolean default false);
create table public.profiles (id uuid primary key references auth.users(id) on delete cascade, first_name text, last_name text,
  username text, streak_count integer default 0, last_workout_date date, timezone text default 'UTC');
create function auth.uid() returns uuid language sql stable as $$ select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid $$;
grant usage on schema auth, public to authenticated, anon;
grant execute on function auth.uid() to authenticated, anon;
create table public.exercises (id uuid primary key, name text unique not null, description text, instructions text[] not null default '{}', media_link text, measurement_type text not null, is_system boolean not null default true);
alter table public.exercises enable row level security;
create policy "Exercise catalog is publicly readable" on public.exercises for select to anon, authenticated using (true);
grant select on public.exercises to anon, authenticated;
SQL

bloom_migrations=()
while IFS= read -r migration; do bloom_migrations+=("$migration"); done < <(
  find "$bloom_root/supabase/migrations" -maxdepth 1 -type f -iname '*bloom*.sql' -print | sort
)
if [ "${#bloom_migrations[@]}" -eq 0 ]; then
  echo 'No Bloom migrations were found.' >&2
  exit 1
fi
for migration in "${bloom_migrations[@]}"; do
  if [[ "$migration" == *bloom_profile_identity.sql ]]; then
    docker exec -i "$bloom_test_container" psql -q -v ON_ERROR_STOP=1 -U postgres -d postgres \
      < "$bloom_dir/tests/profile-identity-before.sql" >/dev/null
  fi
  docker exec -i "$bloom_test_container" psql -q -v ON_ERROR_STOP=1 -U postgres -d postgres \
    < "$migration" >/dev/null
done
docker exec -i "$bloom_test_container" psql -q -v ON_ERROR_STOP=1 -U postgres -d postgres \
  < "$bloom_dir/tests/schema.sql" >/dev/null
docker exec -i "$bloom_test_container" psql -q -v ON_ERROR_STOP=1 -U postgres -d postgres \
  < "$bloom_dir/tests/credit-rules.sql" >/dev/null
docker exec -i "$bloom_test_container" psql -q -v ON_ERROR_STOP=1 -U postgres -d postgres \
  < "$bloom_dir/tests/goal-analytics.sql" >/dev/null
docker exec -i "$bloom_test_container" psql -q -v ON_ERROR_STOP=1 -U postgres -d postgres \
  < "$bloom_dir/tests/workout-plan-editing.sql" >/dev/null
docker exec -i "$bloom_test_container" psql -q -v ON_ERROR_STOP=1 -U postgres -d postgres \
  < "$bloom_dir/tests/weekly-planning.sql" >/dev/null
docker exec -i "$bloom_test_container" psql -q -v ON_ERROR_STOP=1 -U postgres -d postgres \
  < "$bloom_dir/tests/product-outcomes.sql" >/dev/null
docker exec -i "$bloom_test_container" psql -q -v ON_ERROR_STOP=1 -U postgres -d postgres \
  < "$bloom_dir/tests/credit-sessions.sql" >/dev/null
docker exec -i "$bloom_test_container" psql -q -v ON_ERROR_STOP=1 -U postgres -d postgres \
  < "$bloom_dir/tests/households.sql" >/dev/null
docker exec -i "$bloom_test_container" psql -q -v ON_ERROR_STOP=1 -U postgres -d postgres \
  < "$bloom_dir/tests/enforced-countdowns.sql" >/dev/null
docker exec -i "$bloom_test_container" psql -q -v ON_ERROR_STOP=1 -U postgres -d postgres \
  < "$bloom_dir/tests/actual-usage.sql" >/dev/null
docker exec -i "$bloom_test_container" psql -q -v ON_ERROR_STOP=1 -U postgres -d postgres \
  < "$bloom_dir/tests/cross-device-sync.sql" >/dev/null
docker exec -i "$bloom_test_container" psql -q -v ON_ERROR_STOP=1 -U postgres -d postgres \
  < "$bloom_dir/tests/workout-session-timer.sql" >/dev/null
docker exec -i "$bloom_test_container" psql -q -v ON_ERROR_STOP=1 -U postgres -d postgres \
  < "$bloom_dir/tests/custom-exercises.sql" >/dev/null
docker exec -i "$bloom_test_container" psql -q -v ON_ERROR_STOP=1 -U postgres -d postgres \
  < "$bloom_dir/tests/profile-identity.sql" >/dev/null
docker exec -i "$bloom_test_container" psql -q -v ON_ERROR_STOP=1 -U postgres -d postgres \
  < "$bloom_dir/tests/managed-child-profiles.sql" >/dev/null
docker exec -i "$bloom_test_container" psql -q -v ON_ERROR_STOP=1 -U postgres -d postgres \
  < "$bloom_dir/tests/child-device-pairing.sql" >/dev/null
docker exec -i "$bloom_test_container" psql -q -v ON_ERROR_STOP=1 -U postgres -d postgres \
  < "$bloom_dir/tests/parent-device-pin.sql" >/dev/null
docker exec -i "$bloom_test_container" psql -q -v ON_ERROR_STOP=1 -U postgres -d postgres \
  < "$bloom_dir/tests/profile-account-conversion.sql" >/dev/null
docker exec -i "$bloom_test_container" psql -q -v ON_ERROR_STOP=1 -U postgres -d postgres \
  < "$bloom_dir/tests/ai-coaching.sql" >/dev/null
docker exec -i "$bloom_test_container" psql -q -v ON_ERROR_STOP=1 -U postgres -d postgres \
  < "$bloom_dir/tests/competitions.sql" >/dev/null
python3 "$bloom_dir/tests/credit-concurrency.py" "$bloom_test_container"
python3 "$bloom_dir/tests/profile-concurrency.py" "$bloom_test_container"
python3 "$bloom_dir/tests/competition-concurrency.py" "$bloom_test_container"
echo 'Bloom schema and access checks passed.'
