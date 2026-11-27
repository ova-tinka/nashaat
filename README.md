# Bloom

Bloom is a personal growth and screen-time management app with four peer pillars: Exercise, Education, Reading, and Tasks. Focus and Screen Time connect those activities to one account, shared credit wallet, and platform-specific app and website controls.

## Main app

- **iOS and Android:** Expo, React Native, and Expo Router.
- **macOS:** Tauri shell using the shared web export.
- **Native controls:** platform adapters in `modules/`, `native/`, and `src-tauri/`.
- **Backend:** Supabase migrations and Edge Functions in `supabase/`.

The repository root is the Bloom app root. The earlier Flutter Nashaat app is archived locally at `../old/nashaat-flutter` and is no longer part of this repository.

## Setup

1. Install Node.js (see `.nvmrc` for Node 24 LTS) and run `npm ci` from the repository root.
2. Install the standalone Supabase CLI (pinned in `.supabase-version`, e.g. `brew install supabase/tap/supabase`; do not install `supabase` via npm).
3. Set `EXPO_PUBLIC_SUPABASE_URL` and `EXPO_PUBLIC_SUPABASE_PUBLISHABLE_KEY` in the ignored root `.env` file. Set `EXPO_PUBLIC_BLOOM_WEB_URL` to the public root URL of the web deployment to enable Mac reading-document handoff. Use `.env.example` as the template. Never put a service-role key in a client app or commit an environment file.
4. Apply the required Bloom migrations from `supabase/migrations/` to a development project.

## Run and verify

```sh
npm run ios
npm run android
npm run desktop
npm run typecheck
npm run lint
npm run test:schema
```

The native blocking integrations require development or signed builds and physical-device checks. Unit and SQL fixtures do not prove that an operating system is enforcing a restriction. See [the four-pillar roadmap](docs/bloom-super-app-roadmap.md), [macOS readiness report](docs/qa/12-FINAL-READINESS-ASSESSMENT.md), and [platform verification notes](docs/macos-verification.md).
