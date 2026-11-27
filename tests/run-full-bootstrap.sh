#!/usr/bin/env bash
set -euo pipefail

bloom_dir="$(cd "$(dirname "$0")/.." && pwd)"
bloom_root="$bloom_dir"
bloom_pg_bin="${BLOOM_TEST_POSTGRES_BIN:-}"
if [[ -z "$bloom_pg_bin" ]]; then
  if command -v initdb >/dev/null 2>&1 && [[ -x "$(dirname "$(command -v initdb)")/postgres" ]] && [[ -x "$(dirname "$(command -v initdb)")/pg_ctl" ]]; then
    bloom_pg_bin="$(dirname "$(command -v initdb)")"
  elif [[ -x "/opt/homebrew/bin/initdb" && -x "/opt/homebrew/bin/pg_ctl" && -x "/opt/homebrew/bin/postgres" ]]; then
    bloom_pg_bin="/opt/homebrew/bin"
  fi
fi

use_docker=0
if [[ -z "$bloom_pg_bin" || ! -x "$bloom_pg_bin/initdb" || ! -x "$bloom_pg_bin/pg_ctl" || ! -x "$bloom_pg_bin/postgres" ]]; then
  if command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
    use_docker=1
  else
    echo 'Set BLOOM_TEST_POSTGRES_BIN to a local PostgreSQL bin directory or ensure Docker is running.' >&2
    exit 1
  fi
fi

if ! command -v psql >/dev/null 2>&1 && [[ "$use_docker" -eq 0 ]]; then
  echo 'Required test tool is missing: psql' >&2
  exit 1
fi

bloom_test_dir="$(mktemp -d "${TMPDIR:-/tmp}/bloom-bootstrap-XXXXXX")"
export bloom_test_dir
bloom_socket_dir="$bloom_test_dir/socket"
bloom_port=55444
bloom_container="bloom-bootstrap-$$"
mkdir -p "$bloom_socket_dir"

bloom_cleanup() {
  if [[ "$use_docker" -eq 1 ]]; then
    docker stop "$bloom_container" >/dev/null 2>&1 || true
  else
    "$bloom_pg_bin/pg_ctl" -D "$bloom_test_dir/data" -m fast stop >/dev/null 2>&1 || true
  fi
  python3 -c 'import os,shutil; shutil.rmtree(os.environ["bloom_test_dir"], ignore_errors=True)'
}
trap bloom_cleanup EXIT

if [[ "$use_docker" -eq 1 ]]; then
  docker run --rm -d --name "$bloom_container" \
    -e POSTGRES_HOST_AUTH_METHOD=trust postgres:16-alpine >/dev/null
  for attempt in {1..45}; do
    ready_count=$(docker logs "$bloom_container" 2>&1 | grep -c 'database system is ready to accept connections' || true)
    if [[ "${ready_count:-0}" -ge 2 ]]; then break; fi
    sleep 1
  done
  bloom_psql() {
    docker exec -i "$bloom_container" psql -q -v ON_ERROR_STOP=1 -U postgres -d postgres "$@"
  }
else
  "$bloom_pg_bin/initdb" -D "$bloom_test_dir/data" --no-locale --encoding=UTF8 --auth=trust >/dev/null
  "$bloom_pg_bin/pg_ctl" -D "$bloom_test_dir/data" \
    -o "-F -c listen_addresses='' -k $bloom_socket_dir -p $bloom_port" \
    -l "$bloom_test_dir/postgres.log" start >/dev/null
  bloom_psql() {
    psql -q -v ON_ERROR_STOP=1 -h "$bloom_socket_dir" -p "$bloom_port" -U "$(id -un)" -d postgres "$@"
  }
fi

# Minimal Supabase role/auth/storage fixtures required for full migration replay.
bloom_psql <<'SQL'
create role anon nologin;
create role authenticated nologin;
create role service_role nologin bypassrls;
create schema if not exists extensions;
create schema if not exists auth;
create schema if not exists storage;
create table auth.users (
  id uuid primary key,
  raw_app_meta_data jsonb not null default '{}'::jsonb,
  raw_user_meta_data jsonb not null default '{}'::jsonb,
  email text,
  email_confirmed_at timestamptz,
  is_anonymous boolean default false
);
create function auth.uid() returns uuid language sql stable as $$
  select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid
$$;
create function auth.jwt() returns jsonb language sql stable as $$
  select coalesce(nullif(current_setting('request.jwt.claims', true), ''), '{}')::jsonb
$$;
grant usage on schema auth, extensions, public to authenticated, anon;
grant execute on function auth.uid() to authenticated, anon;
grant execute on function auth.jwt() to authenticated, anon;
create table storage.buckets (
  id text primary key,
  name text not null,
  public boolean not null default false,
  file_size_limit bigint,
  allowed_mime_types text[]
);
create table storage.objects (
  id uuid primary key default gen_random_uuid(),
  bucket_id text not null,
  name text not null
);
alter table storage.objects enable row level security;
create function storage.foldername(p_name text) returns text[] language sql immutable as $$
  select regexp_split_to_array(p_name, '/')
$$;
grant usage on schema storage to authenticated, anon;
grant execute on function storage.foldername(text) to authenticated, anon;
grant select, insert, delete on storage.objects to authenticated;
SQL

migration_count=0
while IFS= read -r migration; do
  bloom_psql < "$migration" >/dev/null
  migration_count=$((migration_count + 1))
done < <(find "$bloom_root/supabase/migrations" -maxdepth 1 -type f -name '*.sql' -print | sort)

if [[ "$migration_count" -eq 0 ]]; then
  echo 'No migrations were found.' >&2
  exit 1
fi

bloom_psql < "$bloom_root/supabase/seed.sql" >/dev/null
bloom_psql < "$bloom_root/tests/bootstrap-seed-verify-first.sql" >/dev/null
bloom_psql < "$bloom_root/supabase/seed.sql" >/dev/null
bloom_psql < "$bloom_root/tests/bootstrap-seed-verify-reseed.sql" >/dev/null

printf 'Bloom full bootstrap and idempotent seed checks passed (%s migrations).\n' "$migration_count"
