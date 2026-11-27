#!/usr/bin/env bash
set -euo pipefail

bloom_dir="$(cd "$(dirname "$0")/.." && pwd)"
bloom_pg_bin="${BLOOM_TEST_POSTGRES_BIN:-}"
if [[ -z "$bloom_pg_bin" && -x "/opt/homebrew/bin/initdb" && -x "/opt/homebrew/bin/pg_ctl" && -x "/opt/homebrew/bin/postgres" ]]; then
  bloom_pg_bin="/opt/homebrew/bin"
fi
if [[ -z "$bloom_pg_bin" || ! -x "$bloom_pg_bin/initdb" || ! -x "$bloom_pg_bin/pg_ctl" || ! -x "$bloom_pg_bin/postgres" ]]; then
  echo 'Set BLOOM_TEST_POSTGRES_BIN to a local PostgreSQL bin directory.' >&2
  exit 1
fi

bloom_tmp="$(mktemp -d "${TMPDIR:-/tmp}/bloom-types-XXXXXX")"
export bloom_tmp
bloom_port=55445

cleanup() {
  "$bloom_pg_bin/pg_ctl" -D "$bloom_tmp/data" -m fast stop >/dev/null 2>&1 || true
  python3 -c 'import os,shutil; shutil.rmtree(os.environ["bloom_tmp"], ignore_errors=True)'
}
trap cleanup EXIT

"$bloom_pg_bin/initdb" -D "$bloom_tmp/data" --no-locale --encoding=UTF8 --auth=trust >/dev/null
"$bloom_pg_bin/pg_ctl" -D "$bloom_tmp/data" \
  -o "-F -c listen_addresses=127.0.0.1 -p $bloom_port" \
  -l "$bloom_tmp/postgres.log" start >/dev/null

bloom_psql() {
  psql -q -v ON_ERROR_STOP=1 -h 127.0.0.1 -p "$bloom_port" -U "$(id -un)" -d postgres "$@"
}

bloom_psql <<'SQL'
create role anon nologin;
create role authenticated nologin;
create role service_role nologin bypassrls;
create schema if not exists extensions;
create schema if not exists auth;
create schema if not exists storage;
create table auth.users (id uuid primary key, raw_app_meta_data jsonb not null default '{}'::jsonb, raw_user_meta_data jsonb not null default '{}'::jsonb, email text, email_confirmed_at timestamptz, is_anonymous boolean default false);
create function auth.uid() returns uuid language sql stable as $$ select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid $$;
create function auth.jwt() returns jsonb language sql stable as $$ select coalesce(nullif(current_setting('request.jwt.claims', true), ''), '{}')::jsonb $$;
grant usage on schema auth, extensions, public to authenticated, anon;
grant execute on function auth.uid() to authenticated, anon;
grant execute on function auth.jwt() to authenticated, anon;
create table storage.buckets (id text primary key, name text not null, public boolean not null default false, file_size_limit bigint, allowed_mime_types text[]);
create table storage.objects (id uuid primary key default gen_random_uuid(), bucket_id text not null, name text not null);
alter table storage.objects enable row level security;
create function storage.foldername(p_name text) returns text[] language sql immutable as $$ select regexp_split_to_array(p_name, '/') $$;
grant usage on schema storage to authenticated, anon;
grant execute on function storage.foldername(text) to authenticated, anon;
grant select, insert, delete on storage.objects to authenticated;
SQL

while IFS= read -r migration; do
  bloom_psql < "$migration" >/dev/null
done < <(find "$bloom_dir/supabase/migrations" -maxdepth 1 -type f -name '*.sql' -print | sort)

supabase gen types typescript --db-url "postgresql://$(id -un)@127.0.0.1:${bloom_port}/postgres" --schema public > "$bloom_dir/src/lib/database.types.ts"
echo "Generated src/lib/database.types.ts from local migration schema."
