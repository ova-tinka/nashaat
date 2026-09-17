# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Nashaat is a Flutter mobile application backed by Supabase (PostgreSQL). It helps users earn screen time by completing workouts, with features for app/web blocking, social leaderboards, and subscription management.

## Common Commands

```bash
flutter pub get                        # Install dependencies
flutter run                            # Run app (debug)
flutter test                           # Run all tests
flutter test test/some_test.dart       # Run single test file
flutter analyze                        # Static analysis
flutter build apk                     # Build Android
flutter build ios                      # Build iOS
```

## Architecture

**Stack**: Flutter (Dart ^3.10.1) + Supabase + Material Design 3

**Pattern**: Clean Architecture with feature-based modules and MVVM + Coordinator navigation.

### `lib/` Structure

```
lib/
├── main.dart                    # Entry point, Supabase init, root widget
├── app/                         # App-level setup
│   ├── app-coordinator.dart     # Global navigator key, push/replace helpers
│   └── app-router.dart          # Named route constants + generateRoute switch
├── core/                        # Domain layer (entities, abstract repos, use cases)
├── features/                    # Feature modules (see below)
├── infra/                       # External services (Supabase client, notifications, permissions)
└── shared/                      # Cross-cutting: theme, reusable components
```

### Feature Module Convention

Each feature under `features/` follows this structure:

```
features/<feature-name>/
├── coordinator/    # Feature-specific navigation logic
├── model/          # Data models / DTOs
├── view/           # Widgets and screens
└── view-model/     # State management and business logic
```

Current features: `auth`, `blocking`, `dashboard`, `log-activity`, `onboarding`, `subscription`.

### Navigation

Coordinator pattern — `AppCoordinator` holds a `GlobalKey<NavigatorState>` and provides navigation helpers. Routes are defined as string constants in `AppRouter` (e.g., `/log-activity`, `/blocking`) and resolved via `onGenerateRoute`.

### Database

Schema is in `docs/db/schema.sql`. Key tables: `profiles` (extends `auth.users`), `exercises`, `workout_plans`, `workout_logs`, `blocking_rules`, `screen_time_transactions`, `friendships`, `leaderboards`, `user_rewards`. Uses PostgreSQL enums, JSONB columns, and triggers for auto-profile creation on signup.

## Naming Conventions

- **Files and directories**: kebab-case (`log-activity/`, `app-router.dart`, `workout-plan-card.dart`)
- **Dart classes**: PascalCase (`AppRouter`, `WorkoutPlanCard`)
- **Dart variables/functions**: camelCase
- **Route paths**: kebab-case (`/log-activity`, `/blocking`)
- **Doc files**: numbered kebab-case (`01-register-account.md`)

## Environment

Requires a `.env` file at the project root (git-ignored):
```
SUPABASE_URL=<your-supabase-url>
SUPABASE_ANON_KEY=<your-anon-key>
```

Loaded via `flutter_dotenv` as a declared asset in `pubspec.yaml`.

## Docs

- `docs/db/schema.sql` — Full PostgreSQL schema
- `docs/use-case-specs/` — Numbered use case specifications (01 through 15)
- `docs/diagrams/` — Architecture and sequence diagrams
- `docs/structure/` — Project structure documentation
