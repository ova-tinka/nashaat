#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd "$(dirname "$0")/.." && pwd)"
expected_version="$(tr -d '[:space:]' < "$root_dir/.supabase-version")"

if ! command -v supabase >/dev/null 2>&1; then
  echo "Standalone Supabase CLI ($expected_version) is required. Install via Homebrew: brew install supabase/tap/supabase" >&2
  exit 1
fi

installed_version="$(supabase --version | head -n 1 | tr -d '[:space:]')"
echo "Supabase CLI: $installed_version (pinned minimum/target: $expected_version)"
