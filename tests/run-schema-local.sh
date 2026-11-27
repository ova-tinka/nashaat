#!/usr/bin/env bash
set -euo pipefail

bloom_dir="$(cd "$(dirname "$0")/.." && pwd)"
bloom_root="$bloom_dir"
bloom_pg_bin="${BLOOM_TEST_POSTGRES_BIN:-}"
if [[ -z "$bloom_pg_bin" && -x "/opt/homebrew/bin/initdb" && -x "/opt/homebrew/bin/pg_ctl" && -x "/opt/homebrew/bin/postgres" ]]; then
  bloom_pg_bin="/opt/homebrew/bin"
fi
if [[ -z "$bloom_pg_bin" || ! -x "$bloom_pg_bin/initdb" || ! -x "$bloom_pg_bin/pg_ctl" ]]; then
  echo 'Set BLOOM_TEST_POSTGRES_BIN to a local PostgreSQL server bin directory containing initdb and pg_ctl.' >&2
  exit 1
fi
for bloom_tool in psql python3; do
  if ! command -v "$bloom_tool" >/dev/null 2>&1; then
    echo "Required test tool is missing: $bloom_tool" >&2
    exit 1
  fi
done

bloom_test_dir="$(mktemp -d "${TMPDIR:-/tmp}/bloom-schema-local-XXXXXX")"
export bloom_test_dir
bloom_socket_dir="$bloom_test_dir/socket"
bloom_port=55443
mkdir -p "$bloom_socket_dir"

bloom_cleanup() {
  "$bloom_pg_bin/pg_ctl" -D "$bloom_test_dir/data" -m fast stop >/dev/null 2>&1 || true
  python3 -c 'import os,shutil; shutil.rmtree(os.environ["bloom_test_dir"], ignore_errors=True)'
}
trap bloom_cleanup EXIT

"$bloom_pg_bin/initdb" -D "$bloom_test_dir/data" --no-locale --encoding=UTF8 --auth=trust >/dev/null
"$bloom_pg_bin/pg_ctl" -D "$bloom_test_dir/data" \
  -o "-F -c listen_addresses='' -k $bloom_socket_dir -p $bloom_port" \
  -l "$bloom_test_dir/postgres.log" start >/dev/null

bloom_psql() {
  psql -q -v ON_ERROR_STOP=1 -h "$bloom_socket_dir" -p "$bloom_port" -U "$(id -un)" -d postgres "$@"
}

bloom_psql <<'SQL'
create role anon nologin;
create role authenticated nologin;
create role service_role nologin bypassrls;
create schema auth;
create schema storage;
create table auth.users (id uuid primary key, raw_app_meta_data jsonb not null default '{}'::jsonb,
  email text, email_confirmed_at timestamptz, is_anonymous boolean default false);
create table public.profiles (id uuid primary key references auth.users(id) on delete cascade, first_name text, last_name text,
  username text, streak_count integer default 0, last_workout_date date, timezone text default 'UTC');
create function auth.uid() returns uuid language sql stable as $$ select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid $$;
grant usage on schema auth, public to authenticated, anon;
grant execute on function auth.uid() to authenticated, anon;
create table storage.buckets (id text primary key, name text not null, public boolean not null default false,
  file_size_limit bigint, allowed_mime_types text[]);
create table storage.objects (id uuid primary key default gen_random_uuid(), bucket_id text not null, name text not null);
alter table storage.objects enable row level security;
create function storage.foldername(p_name text) returns text[] language sql immutable as $$
  select regexp_split_to_array(p_name, '/')
$$;
grant usage on schema storage to authenticated, anon;
grant execute on function storage.foldername(text) to authenticated, anon;
grant select, insert, delete on storage.objects to authenticated;
create table public.exercises (id uuid primary key, name text unique not null, description text, muscle_group text, muscle_groups text[] not null default '{}', instructions text[] not null default '{}', media_link text, measurement_type text not null, is_system boolean not null default true);
alter table public.exercises enable row level security;
create policy "Exercise catalog is publicly readable" on public.exercises for select to anon, authenticated using (true);
grant select on public.exercises to anon, authenticated;
SQL

bloom_migration_count=0
while IFS= read -r bloom_migration; do
  if [[ "$bloom_migration" == *bloom_profile_identity.sql ]]; then
    bloom_psql < "$bloom_dir/tests/profile-identity-before.sql" >/dev/null
  fi
  bloom_psql < "$bloom_migration" >/dev/null
  bloom_migration_count=$((bloom_migration_count + 1))
done < <(find "$bloom_root/supabase/migrations" -maxdepth 1 -type f -iname '*bloom*.sql' -print | sort)

bloom_fixture_count=0
bloom_fixtures=(schema.sql credit-rules.sql goal-analytics.sql workout-plan-editing.sql weekly-planning.sql \
  product-outcomes.sql credit-sessions.sql households.sql child-module-assignments.sql website-rules.sql enforced-countdowns.sql actual-usage.sql cross-device-sync.sql \
  workout-session-timer.sql custom-exercises.sql profile-identity.sql managed-child-profiles.sql child-device-pairing.sql \
  parent-device-pin.sql profile-account-conversion.sql ai-coaching.sql device-registry.sql)
bloom_fixtures+=(growth-modules.sql)
bloom_fixtures+=(selected-growth-scope.sql)
bloom_fixtures+=(mock-exams-documents.sql)
bloom_fixtures+=(read-reflection-memory.sql)
bloom_fixtures+=(default-personal-memory.sql)
bloom_fixtures+=(study-tutor-quota.sql)
bloom_fixtures+=(weekly-earning-cap.sql)
if [[ "${BLOOM_SKIP_PUBLIC_COMPETITIONS:-0}" != "1" ]]; then
  bloom_fixtures+=(competitions.sql)
fi
for bloom_fixture in "${bloom_fixtures[@]}"; do
  bloom_psql < "$bloom_dir/tests/$bloom_fixture" >/dev/null
  bloom_fixture_count=$((bloom_fixture_count + 1))
done

BLOOM_TEST_PG_HOST="$bloom_socket_dir" BLOOM_TEST_PG_PORT="$bloom_port" \
  BLOOM_TEST_PG_USER="$(id -un)" BLOOM_TEST_PG_DATABASE=postgres \
  python3 "$bloom_dir/tests/credit-concurrency.py"
BLOOM_TEST_PG_HOST="$bloom_socket_dir" BLOOM_TEST_PG_PORT="$bloom_port" \
  BLOOM_TEST_PG_USER="$(id -un)" BLOOM_TEST_PG_DATABASE=postgres \
  python3 "$bloom_dir/tests/profile-concurrency.py"
BLOOM_TEST_PG_HOST="$bloom_socket_dir" BLOOM_TEST_PG_PORT="$bloom_port" \
  BLOOM_TEST_PG_USER="$(id -un)" BLOOM_TEST_PG_DATABASE=postgres \
  python3 "$bloom_dir/tests/competition-concurrency.py"
BLOOM_TEST_PG_HOST="$bloom_socket_dir" BLOOM_TEST_PG_PORT="$bloom_port" \
  BLOOM_TEST_PG_USER="$(id -un)" BLOOM_TEST_PG_DATABASE=postgres \
  python3 "$bloom_dir/tests/study-tutor-concurrency.py"
BLOOM_TEST_PG_HOST="$bloom_socket_dir" BLOOM_TEST_PG_PORT="$bloom_port" \
  BLOOM_TEST_PG_USER="$(id -un)" BLOOM_TEST_PG_DATABASE=postgres \
  python3 "$bloom_dir/tests/weekly-cap-concurrency.py"
printf 'Bloom local schema checks passed: %s migrations, %s SQL fixtures, concurrency checks.\n' \
  "$bloom_migration_count" "$bloom_fixture_count"
