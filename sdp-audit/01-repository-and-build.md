# Repository and build

- Git branch `codex`; HEAD `5f38d289977e7739d76e4a603cd1260db00443b5` (`Implement Bloom Read experience`, 2026-11-21). Audit timestamp uses environment date; no independent clock capture.
- Dirty working tree at audit start, including app, native, test, migration and docs edits. Findings describe the checked-out tree, not a clean commit.
- Expo Router/React Native app in `src/`; Tauri v2/Rust host plus Swift macOS services in `src-tauri/`; Supabase migrations/functions in `supabase/`; shared Expo native module in `modules/bloom-blocking/`; tests in `tests/` and native test folders. `package.json` version 0.1.1, filter version 1.1.21. `app.json` declares iOS, Android, web; `src-tauri/tauri.conf.json` has Windows target configuration.
- Supabase client is configured through `EXPO_PUBLIC_SUPABASE_URL` and publishable key; absent config makes client null (`src/lib/supabase.ts:6-18`). No secret values inspected.
- No `.github/workflows` files found. CI latest result: unavailable.
- Candidate build: source version 0.1.1; no evidence this is latest signed/store build. Tauri config version 0.1.1. Build artifacts/signatures not verified.
- Build/test execution: typecheck invoked; result pending capture at audit generation. No mobile/desktop build attempted. Native permissions, extension signing/notarization, credentials, and physical devices constrain meaningful validation.
- Relevant scripts: `package.json` scripts include typecheck, lint, schema, macOS native/state, growth features, desktop build. Schema runner can use disposable local database only; no production DB actions performed.
- Evidence paths: `package.json`, `app.json`, `src-tauri/tauri.conf.json`, `src/lib/supabase.ts`, `docs/qa/01-ARCHITECTURE-INVENTORY.md`, `docs/qa/03-FEATURE-COMPLETENESS-AUDIT.md`.
