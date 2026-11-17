# AGENTS.md

## Project

Bloom is a four-pillar personal growth and screen-time management app. Exercise, Education, Reading, and Tasks are first-class areas. Focus and Screen Time are shared services across them. Personal Mode must work without supervision; Family and Organization modes are optional extensions.

## Stack and layout

- Expo Router and React Native: `src/`
- Android and iOS app configuration: `app.json`, `plugins/`, `modules/`, and `native/`
- macOS Tauri host and native services: `src-tauri/`
- Shared native blocking module: `modules/bloom-blocking/`
- Supabase Edge Functions and migrations: `supabase/`
- Automated checks and fixtures: `tests/`, `src-tauri/**/tests/`

The repository root is the app root. Do not add a second app shell or duplicate credit logic in another client. Keep OS-specific blocking behind platform adapters and report actual enforcement state rather than saved configuration.

## Common commands

```sh
npm ci
npm run ios
npm run android
npm run desktop
npm run typecheck
npm run lint
npm run test:schema
```

Focused tests are listed in the root `package.json`. Native permission, blocking, restart, and sync behavior requires physical-device verification on each supported OS.

## Product invariants

- One server-authoritative credit ledger serves all four activity pillars and all devices.
- Every activity reward has a stable idempotency key; Focus cannot award a second time for the activity it supports.
- Device-specific selections and permissions stay device-specific when an OS requires it.
- Offline activities remain pending until accepted by the server. Do not authorize offline spending from a cached balance.
- Family members keep separate accounts and wallets; supervision shares only explicitly permitted information.

## Environment and data

Use the ignored root `.env` for local Expo configuration and `.env.example` for variable names. Never print, commit, or send `.env` contents, service-role keys, production logs, or real family/child data. Run database tests only against their disposable local fixtures.
