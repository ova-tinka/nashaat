# Nashaat repository onboarding guide

This document is a practical map of the Nashaat repository for someone who has never seen the project before. It explains what the product does, how the Flutter code is organized, how data moves through the app, how Supabase/Postgres is used, how native blocking works, and which parts of the repository need extra caution.

The guide describes the repository as it exists in the current checkout. Some design documents describe a broader or older version of the product, so the current code and SQL files take precedence when they disagree with prose documentation.

## 1. The short version

Nashaat is a Flutter mobile app in which a user completes workouts to earn screen time. The app stores the user profile, workout plans, completed sessions, screen-time transactions, blocking rules, and social data in Supabase/Postgres. App blocking itself is platform-specific:

- Android uses Usage Access, overlay/accessibility-related settings, a native accessibility service, and a foreground service.
- iOS uses Apple FamilyControls/ManagedSettings extensions and a native app picker.
- The Flutter layer coordinates the user experience and keeps the screen-time balance in sync with the native blocker.

The main runtime path is:

```text
Flutter screen
    -> feature ViewModel (ChangeNotifier)
        -> core repository interface
            -> Supabase repository implementation
                -> Supabase client
                    -> PostgreSQL / Supabase Auth

Blocking-specific path:

Flutter ViewModel
    -> BlockingPlatformService
        -> MethodChannel('com.nashaat/blocking')
            -> Android or iOS native blocking implementation
```

The project is intended to follow Clean Architecture, feature modules, MVVM, and Coordinator navigation. In practice it is best described as **Clean Architecture-inspired**: the core layer is separated well, but several feature ViewModels directly access Supabase and most features obtain concrete repositories through a global service locator.

## 2. Product mental model

The product loop is:

1. A user signs up or signs in.
2. The user completes onboarding and chooses a workout schedule, workout duration, expected phone usage, and blocking settings.
3. The user creates or follows a workout plan.
4. Completing a workout creates a workout log and earns screen-time credit.
5. The user selects apps to block and activates blocking.
6. As the user uses blocked apps, the available screen-time balance is consumed.
7. The user can review progress, rewards, leaderboards, settings, and account data.

The central business relationship is:

```text
Workout completion
    -> workout_logs
    -> earned screen-time transaction
    -> profiles.balance_minutes increase

Blocked-app usage
    -> native blocker
    -> periodic focus accounting
    -> spent screen-time transaction
    -> profiles.balance_minutes decrease
```

The app therefore has two kinds of important state:

- **Durable server state:** profiles, plans, logs, transactions, rules, leaderboards, and other Supabase records.
- **Platform/runtime state:** whether blocking is active, selected native apps/categories/domains, permissions, the current foreground package on Android, workout timer state, and local UI state.

When debugging a feature, first determine which of these two state categories is wrong.

## 3. Repository status and source-of-truth rules

Before making changes, inspect the checkout:

```bash
git status --short
git log -5 --oneline
```

The checkout inspected while preparing this guide already contained uncommitted changes. They included changes to the router, profile entity/repository, blocking and focus behavior, settings, workout session behavior, the Supabase profile repository, the active-session/focus/settings screens, iOS entitlements, and a new time-exhausted screen. Do not reset or overwrite those files without understanding the existing work.

Use these sources in this order when they disagree:

1. Current Dart code and tests.
2. `docs/db/schema.sql` plus the checked-in Supabase migrations.
3. Current platform code under `android/` and `ios/`.
4. Architecture and product documents under `docs/`.
5. `AGENTS.md`, `CLAUDE.md`, and the README for project conventions.

There is documentation drift to be aware of:

- `README.md` contains only the project title and is not a useful onboarding source.
- `AGENTS.md` and `CLAUDE.md` describe an older, smaller feature list.
- `docs/onboarding-guide.md` is useful, but some directory names and feature descriptions are stale. For example, the code uses `view-model`, while some documentation uses `view_model`.
- The written architecture says ViewModels should not import Supabase, but several current ViewModels do so directly.
- The design documentation describes more future product scope than the current implementation provides.

## 4. Technology stack

| Area | Technology in this repository | Where to inspect it |
|---|---|---|
| Mobile UI | Flutter, Dart `^3.10.1` | `pubspec.yaml`, `lib/` |
| Framework version observed | Flutter 3.38.3 stable; Dart 3.10.1 | `flutter --version` |
| Design system | Material 3 with a custom Nashaat theme | `lib/shared/design/` |
| State management | `provider` and `ChangeNotifier`; ViewModels are manually constructed | `pubspec.yaml`, `lib/features/` |
| Navigation | Named routes plus `AppCoordinator` and feature coordinators | `lib/app/`, feature `coordinator/` folders |
| Backend client | `supabase_flutter` | `lib/main.dart`, `lib/infra/` |
| Backend | Supabase services and PostgreSQL | `docs/db/schema.sql`, `supabase/migrations/` |
| Authentication | Supabase Auth, email OTP, phone OTP, Google, Apple | `lib/core/repositories/auth-repository.dart`, `lib/infra/supabase/auth-repository-impl.dart` |
| Configuration | `flutter_dotenv` and a root `.env` asset | `.env`, `pubspec.yaml`, `lib/main.dart` |
| Local persistence | `shared_preferences`, currently used for locale and native Android blocking state | `lib/shared/providers/locale-provider.dart`, Android native code |
| Charts | `fl_chart` | Dashboard feature |
| Internationalization | Flutter ARB localization, English and Arabic | `l10n.yaml`, `lib/l10n/` |
| Typography | `google_fonts`, Inter and Cairo in the custom design system | `lib/shared/design/typography.dart` |
| Social sign-in | `google_sign_in`, `sign_in_with_apple`, `crypto` for nonce-related auth work | `pubspec.yaml`, auth implementation |
| HTTP / AI translation | `http`; optional Groq translation service | `lib/infra/translation/groq-translation-service.dart` |
| Testing | `flutter_test`, `mocktail`, `flutter_lints` | `test/`, `pubspec.yaml` |
| Auxiliary tooling | Node script and Supabase JS dependency for importing exercise data | `package.json`, `scripts/import-free-exercise-db.mjs` |
| Native Android | Kotlin, accessibility service, foreground service, platform channel | `android/app/src/main/kotlin/com/example/nashaat/` |
| Native iOS | Swift, FamilyControls, ManagedSettings, shield extensions | `ios/Runner/`, `ios/NashaatShield/`, `ios/NashaatShieldAction/` |

The app is primarily a Dart/Flutter application. The Node dependency is not a second application backend; it supports exercise-catalog import work.

## 5. Getting the app running

### Prerequisites

Install Flutter with a mobile toolchain for the platform you intend to run. The repository currently targets Android and iOS. A real device or simulator/emulator is needed to validate native blocking; unit/widget tests do not prove that blocking permissions or accessibility behavior work.

### Environment variables

Create a local, git-ignored `.env` file at the repository root:

```dotenv
SUPABASE_URL=<your-supabase-url>
SUPABASE_ANON_KEY=<your-supabase-anon-key>
```

The file is loaded as a Flutter asset by `lib/main.dart`. Do not commit it, paste real keys into tickets, or include it in logs. The app also has an optional `GROQ_API_KEY` lookup for the translation service; if that service is enabled, treat the key as sensitive and do not ship a privileged server key inside the mobile binary.

### First commands

```bash
flutter pub get
flutter analyze
flutter test
flutter run
```

Useful focused commands:

```bash
flutter test test/features/workout/view-model/active-session-view-model-test.dart
flutter test --plain-name "name of a test"
flutter build apk
flutter build ios
```

The exact test path may vary by feature; use `rg --files test` to find it.

### Verification observed during repository inspection

- `flutter test` passed: all 142 tests passed.
- `flutter analyze` completed with no analyzer errors, but reported four informational/lint findings: three `use_build_context_synchronously` findings and one missing-curly-braces finding.
- No Android or iOS build was run during the inspection.
- No native permission/device behavior was verified during the inspection.

## 6. Repository layout

```text
nashaat/
├── android/                         # Android project and native blocking code
├── ios/                             # iOS project, entitlements, blocking extensions
├── lib/
│   ├── main.dart                    # App entry point and dependency startup
│   ├── app/                         # App router and global coordinator
│   ├── core/                        # Domain entities and repository contracts
│   ├── features/                    # Feature screens, ViewModels, models, coordinators
│   ├── infra/                       # Supabase implementations and platform services
│   ├── l10n/                        # ARB files and generated localization code
│   └── shared/                      # Design system, components, providers, utilities
├── docs/
│   ├── db/                          # Canonical schema, migrations notes, seed scripts/data
│   ├── diagrams/                    # Architecture, class, sequence, and use-case docs
│   ├── structure/                   # Architecture and project-structure documentation
│   ├── onboarding-guide.md          # Earlier onboarding notes; partially stale
│   └── repo-onboarding-guide.md     # This guide
├── supabase/migrations/             # Incremental schema changes
├── scripts/                         # Exercise import tooling
├── test/                            # ViewModel tests and test helpers
├── pubspec.yaml                     # Flutter dependencies and asset configuration
├── package.json                     # Node exercise-import dependency/script
├── AGENTS.md                        # Repository working instructions
└── CLAUDE.md                        # Additional project notes
```

### Current feature directories

| Feature | What it owns | Current implementation state |
|---|---|---|
| `auth` | Login, registration, OTP, social sign-in, password/account actions | Implemented and tested; provider setup still needs platform configuration |
| `onboarding` | Initial user preferences and blocking setup | Implemented; blocking setup errors are isolated from profile completion |
| `dashboard` | Balance, streak, weekly progress, recent activity | Implemented dashboard shell and data loading |
| `workout` | Plans, exercise library, workout builder, active sessions, AI-generation entry point | Main workout flow is implemented |
| `blocking` | Blocking rules, permissions, activation, emergency breaks, focus balance | Implemented with Android/iOS native dependencies |
| `social` | Private leaderboards and invite-code joining | Leaderboard flow exists; friendship UI is not complete |
| `settings` | Profile, screen-time setup, strict blocking setting, account actions | Implemented |
| `shell` | Five-tab application shell | Implemented |
| `log-activity` | Historical/legacy route area | Source directory is currently empty; route redirects to the shell |
| `subscription` | Subscription entry point | Route exists, but current screen is a placeholder |

The `core/use-cases/` directory exists but is empty. Business orchestration currently lives primarily in feature ViewModels.

## 7. Application startup and navigation

### Startup sequence

The entry point is [`lib/main.dart`](../lib/main.dart):

1. Flutter bindings are initialized.
2. The application logger boots.
3. `.env` is loaded.
4. Supabase is initialized using `SUPABASE_URL` and `SUPABASE_ANON_KEY`.
5. `LocaleProvider` is installed with `ChangeNotifierProvider`.
6. `NashaatApp` configures theme, localization, the global navigator key, and `AppRouter`.
7. The initial route is `/`, which displays `AuthGate`.

`AuthGate` checks the current Supabase session. If there is no session it sends the user to login. If a session exists, it asks the auth repository whether onboarding is needed, then sends the user either to onboarding or to the dashboard shell. Errors in this decision currently fall back to login.

### Navigation files

- [`lib/app/app-router.dart`](../lib/app/app-router.dart) contains route constants and the route switch.
- [`lib/app/app-coordinator.dart`](../lib/app/app-coordinator.dart) owns the global `navigatorKey` and convenience navigation methods.
- Feature coordinators wrap feature-specific navigation decisions, but the global coordinator remains the central route executor.

Current route map:

| Route | Destination / purpose |
|---|---|
| `/` | `AuthGate` |
| `/login` | Login screen |
| `/register` | Registration screen |
| `/onboarding` | Onboarding flow |
| `/dashboard` | `AppShellScreen`, the authenticated five-tab shell |
| `/workout-builder` | Create/edit workout plan; optional `planId` argument |
| `/exercise-library` | Browse/search exercises |
| `/exercise-detail` | Exercise details; receives an exercise argument |
| `/active-session` | Run a workout; receives a `WorkoutPlanEntity` |
| `/ai-generation` | AI workout generation entry point |
| `/settings` | Settings screen |
| `/time-exhausted` | Time-exhausted screen |
| `/log-activity` | Legacy route that redirects to the authenticated shell |
| `/blocking` | Legacy/declared route; verify the route before using it directly because the current coordinator helper redirects to the dashboard |
| `/subscription` | Placeholder subscription screen |

### The authenticated shell

[`lib/features/shell/view/app-shell-screen.dart`](../lib/features/shell/view/app-shell-screen.dart) uses an `IndexedStack` with five tabs:

1. Home → dashboard.
2. Workout → workout hub.
3. Focus → focus/blocking screen.
4. Social → leaderboard screen.
5. Settings → settings screen.

Because the children are retained by an `IndexedStack`, tab state persists. The screens create and load their ViewModels in `initState`, so opening the shell can start several feature loads at once. This matters when debugging startup latency or seeing multiple Supabase requests immediately after login.

## 8. Architecture in detail

### Intended layers

```text
app/
  Composition root: startup, route definitions, global navigation

features/
  User-facing vertical slices: screens, ViewModels, feature models, coordinators

core/
  Domain vocabulary and contracts: entities and repository interfaces

infra/
  External implementations: Supabase repositories, native bridges, translation

shared/
  Cross-cutting UI and utilities: theme, components, localization provider, logging
```

### Core layer

`lib/core/` contains 14 domain entities and 14 repository contracts. It is intentionally free of Flutter and Supabase imports. Examples include:

- `ProfileEntity`
- `WorkoutPlanEntity`
- `WorkoutLogEntity`
- `ExerciseEntity`
- `BlockingRuleEntity`
- `ScreenTimeTransactionEntity`
- `LeaderboardEntity`

Repository contracts describe what the feature needs without specifying how data is stored. For example, a ViewModel can depend on `WorkoutPlanRepository` rather than on a Supabase query builder.

The use-case layer is currently empty. Do not assume there is a separate domain service for every use case; most workflows are implemented in ViewModels today.

### Feature layer

Feature folders generally contain:

```text
features/<feature>/
├── coordinator/
├── model/
├── view/
└── view-model/
```

The naming convention is kebab-case for files/directories and PascalCase for Dart classes. ViewModels usually:

- Extend `ChangeNotifier`.
- Keep mutable loading/error/data fields private.
- Expose read-only getters to widgets.
- Notify listeners after state changes.
- Receive repository contracts in their constructor when the feature follows the intended boundary.
- Dispose timers and controllers in `dispose()`.

Screens use `ListenableBuilder` or an equivalent listener pattern to rebuild from the ViewModel. Screens explicitly construct and dispose ViewModels instead of relying on a global ViewModel provider tree.

### Infrastructure layer

`lib/infra/` contains:

- `SupabaseClientProvider`, which exposes `Supabase.instance.client` and the current auth client.
- Concrete Supabase repository implementations.
- `RepositoryLocator`, the singleton composition root for repository instances.
- `BlockingPlatformService`, the MethodChannel bridge to Android and iOS.
- Permissions and translation services.

`RepositoryLocator` creates the concrete repositories for auth, profile, workout plans/logs, exercises, blocking, emergency breaks, screen-time transactions, friendships, leaderboards, notifications, rewards, and media. It also creates the Groq translation service.

One repository contract currently has no matching implementation/locator registration: `AppUsageInsightRepository`. The database table exists, but the application does not currently have a complete repository path for it.

### Dependency direction in practice

The preferred dependency direction is:

```text
View -> ViewModel -> core contract <- infra implementation -> external system
```

The actual code has two shortcuts:

1. Several ViewModels import Supabase directly to obtain the current user ID or perform a query fallback. Current examples include focus/blocking, onboarding, settings, social, active session, and workout builder.
2. Features commonly import `RepositoryLocator` directly instead of receiving dependencies from a higher-level composition root.

These shortcuts are important when adding tests or extracting use cases. Follow the local pattern carefully, but do not assume the architecture document describes every current dependency.

## 9. State management and error handling

The application uses `provider` at the root for locale state, while feature ViewModels are local `ChangeNotifier` objects. A typical screen lifecycle is:

```text
initState
  -> create ViewModel with repository dependencies
  -> call load()
  -> ListenableBuilder rebuilds UI
  -> dispose() stops timers/controllers
```

The ViewModel usually owns loading, empty, error, and action-in-progress state. The UI owns rendering and user gestures. Navigation is delegated to a coordinator rather than being scattered through every widget.

Logging is centralized in [`lib/shared/logger.dart`](../lib/shared/logger.dart). It has tagged debug logging for areas such as auth, navigation, blocking, database, boot, and errors. Use the project logger instead of adding ad-hoc `print` calls.

## 10. Feature-by-feature guide

### Authentication

Start with:

- [`lib/core/repositories/auth-repository.dart`](../lib/core/repositories/auth-repository.dart)
- [`lib/features/auth/view-model/auth-view-model.dart`](../lib/features/auth/view-model/auth-view-model.dart)
- [`lib/infra/supabase/auth-repository-impl.dart`](../lib/infra/supabase/auth-repository-impl.dart)

The auth contract supports:

- Email OTP.
- Phone/SMS OTP.
- Google ID-token exchange.
- Apple nonce/token exchange.
- Sign out.
- Onboarding status checks.
- Password changes.
- Account deletion action.

`AuthViewModel` has idle/loading/OTP-sent/error/success-style state and a local lockout after five failed attempts for 15 minutes.

Supabase creates the profile row through the database trigger described later. Social providers still require platform and Supabase provider configuration, so a successful compile does not prove Google or Apple sign-in is configured.

Important account behavior: the current `deleteAccount()` implementation marks the user with a `deleted_at` value in auth user metadata and then the settings flow signs out. It is not a privileged server-side deletion of the Supabase Auth user. Treat this as soft deletion unless the implementation is changed.

### Onboarding

Start with [`lib/features/onboarding/`](../lib/features/onboarding/).

The current flow has six steps:

1. Welcome.
2. Days per week.
3. Workout duration.
4. Daily phone hours.
5. Reward preview.
6. Blocking setup.

Current defaults include four workout days, 30-minute workouts, eight daily phone hours, two small weekly sessions, and three big weekly sessions. Finishing onboarding:

1. Calculates the weekly target from days × workout duration.
2. Updates profile identity and target data.
3. Saves screen-time economy settings.
4. Creates active blocking rules for selected packages.
5. Requests native blocking permissions.
6. Marks the profile as onboarded.

Blocking setup errors are caught separately. The profile can still be marked onboarded even when native blocking setup fails, so onboarding success does not guarantee that blocking is ready.

### Dashboard

The dashboard ViewModel loads:

- The current profile.
- Weekly workout logs.
- Recent screen-time transactions.

It computes the display name, streak, balance, weekly earned/spent values, sessions, trained minutes, target progress, and chart/activity data. The dashboard is rendered inside the shell’s Home tab.

There is an `updateStreak` repository operation, but repository-wide inspection found no current caller. If streaks appear stale after a workout, inspect this path first.

### Workouts

Start with [`lib/features/workout/`](../lib/features/workout/).

The current workout area contains:

- Workout hub.
- Workout builder.
- Exercise library.
- Exercise detail.
- Active workout session.
- AI generation entry point.

`WorkoutPlanEntity` contains the user, title, description, source (`manual` or `ai_generated`), scheduled days, exercises, session size, and timestamps. Scheduled days use the numeric convention 1 = Monday through 7 = Sunday.

Each `WorkoutPlanExercise` may contain exercise ID/name, sets, reps, duration seconds, rest seconds, weight, and distance. Plans are persisted as a row in `workout_plans`; the exercise list is stored in a JSONB column rather than in a separate plan-exercises table.

The builder can create/edit plans, toggle scheduled days, choose small/big session size, and reorder or update exercises. The library supports debounced search and filters by name, muscle group, and difficulty. The Supabase implementation uses `ilike` for text search.

The active-session ViewModel manages a timer and statuses such as idle, running, resting, paused, and completed. Saving a session currently performs these logical operations:

1. Calculate duration.
2. Build completed-exercise JSON.
3. Insert a `workout_logs` row.
4. If reward is positive, insert an earned screen-time transaction referencing the log.
5. Update the profile balance.

These are separate writes rather than one database transaction or RPC. A failure in the middle can leave a log, transaction, and balance temporarily inconsistent.

### Screen-time economy and Focus

The formula is in [`lib/shared/utils/screen-time-economy.dart`](../lib/shared/utils/screen-time-economy.dart).

```text
weekly phone minutes = daily phone hours × 7 × 60
free minutes = floor(weekly phone minutes × 20%)
earnable minutes = weekly phone minutes - free minutes
session units = small sessions + (2 × big sessions)
small-session reward = floor(earnable minutes / session units)
big-session reward = 2 × small-session reward
```

`FocusViewModel` performs a weekly reset when the current week starts after the stored reset timestamp. The reset path currently resets balance to zero, adds the free allowance, records the free allowance as an earned transaction, and reloads profile/reward state.

While blocking is active, the focus timer ticks every 60 seconds. In non-strict mode it drains continuously. In strict Android mode it asks the native layer for the foreground package and drains only when that package matches an active rule. In strict iOS mode the Flutter layer returns false because it cannot inspect the foreground app in the same way.

When balance reaches zero, the app attempts to re-activate blocking. Each drain records a spent transaction and updates profile balance as separate writes. This is another area where retries and partial failures matter.

### Blocking and emergency breaks

Start with:

- [`lib/features/blocking/view-model/blocking-view-model.dart`](../lib/features/blocking/view-model/blocking-view-model.dart)
- [`lib/features/blocking/view-model/focus-view-model.dart`](../lib/features/blocking/view-model/focus-view-model.dart)
- [`lib/infra/blocking/blocking-platform-service.dart`](../lib/infra/blocking/blocking-platform-service.dart)
- [`lib/core/repositories/blocking-repository.dart`](../lib/core/repositories/blocking-repository.dart)

The blocking ViewModel loads permissions, active rules, today’s emergency breaks, and native blocking state. It can select apps, add/remove/toggle rules, activate/deactivate native blocking, and request emergency breaks.

The current Supabase blocking repository filters to `item_type = 'app'`, matching the current Flutter/Android flow. The domain enum and database also support `website`, but complete web/category blocking is not present in the current Flutter path.

Emergency breaks are limited to 15 minutes per day. The ViewModel sums today’s records, clamps a requested break to the remaining allowance, inserts an `emergency_breaks` row, updates local usage, and runs a second timer for the break. The current code does not record a balance debit or penalty transaction for an emergency break.

### Social

Start with [`lib/features/social/`](../lib/features/social/).

The leaderboard flow:

1. Load leaderboards belonging to the current user.
2. Select a leaderboard.
3. Load members.
4. Load member profiles.
5. Calculate/display ranks.
6. Create a private leaderboard with a generated invite code or join using an invite code.

The friendship repository supports friend requests, pending requests, status updates, and removal, but there is no complete current friend-facing screen/ViewModel flow comparable to the leaderboard flow.

### Settings

Settings can load/update the profile, save screen-time setup, toggle strict blocking mode, change the password, request account deletion, and sign out. It is also one of the places where the current code directly accesses Supabase for the current user instead of relying exclusively on a repository abstraction.

### Subscription and AI status

The repository contains subscription concepts and a subscription route, but the current `/subscription` screen is a placeholder saying subscription management is coming soon. Do not describe payments as implemented without checking a newer branch or external product configuration.

The workout feature has an AI-generation entry point, but the repository’s visible auxiliary AI-related service is a Groq translation service. Treat AI workout generation as an entry point or partial feature until its full implementation and backend behavior are verified.

## 11. Database and Supabase

The canonical base schema is [`docs/db/schema.sql`](db/schema.sql). The repository also has incremental files under [`supabase/migrations/`](../supabase/migrations/). The schema is PostgreSQL-oriented and uses Supabase Auth’s `auth.users` table for identity.

### Schema inventory

The base schema contains 14 application tables, 10 enum types, one function, one trigger, and indexes. The principal tables are:

| Table | Purpose | Main application consumers |
|---|---|---|
| `profiles` | Application profile extending `auth.users`; balance, tier, targets, streak | Auth, onboarding, dashboard, settings, workout reward, focus |
| `media` | User-owned media metadata and storage paths | Media/profile avatar paths |
| `exercises` | Exercise catalog | Exercise library, workout builder |
| `workout_plans` | User workout plans and schedule | Workout hub, builder, active session |
| `workout_logs` | Completed workout sessions | Active session, dashboard |
| `blocking_rules` | Apps/websites selected for blocking | Blocking/focus |
| `emergency_breaks` | Daily emergency-break records | Blocking/focus |
| `friendships` | Friend requests and relationship status | Friendship repository; UI is partial |
| `user_rewards` | Unlocked rewards | Focus/dashboard/reward loading |
| `notifications` | User notifications and read state | Notification repository |
| `screen_time_transactions` | Earned/spent/penalty/manual balance ledger | Dashboard, focus, workout completion |
| `leaderboards` | Private leaderboard definitions and invite codes | Social |
| `leaderboard_members` | Leaderboard membership and weekly scores | Social |
| `app_usage_insights` | Daily usage totals and per-app JSON breakdown | Schema only currently; no concrete app repository |

### Important columns and storage choices

#### `profiles`

`profiles.id` is a UUID primary key and foreign key to `auth.users.id` with cascade behavior. It stores email, username, names, onboarding status, weekly workout target, screen-time balance, streak, last workout, subscription tier, FCM token, and timestamps.

The screen-time migration adds:

- `daily_phone_hours`
- `weekly_small_sessions`
- `weekly_big_sessions`
- `last_weekly_reset_at`

The current Dart code also reads/writes `strict_blocking_only`. Repository-wide inspection of checked-in SQL did not find that column in the base schema or checked-in migrations. Verify the actual Supabase project before relying on this field in a fresh database.

#### `exercises`

The base schema includes a unique name, description, primary muscle group, measurement type, media reference, and system-exercise flag. The exercise-catalog migration adds difficulty level, `muscle_groups TEXT[]`, `steps TEXT[]`, a backfill from the original muscle-group field, and supporting indexes.

#### `workout_plans`

Rows belong to a user and contain title, description, source, `scheduled_days INT[]`, and `exercises JSONB`. A later migration adds `session_size` with small/big validation.

#### `workout_logs`

Rows belong to a user, optionally reference a plan, require a positive duration, and store earned screen time, completed exercises as JSONB, notes, and a timestamp.

#### `screen_time_transactions`

The transaction ledger stores user, amount, type, description, timestamp, and an optional `reference_id`. `reference_id` is typed as UUID but the base schema does not establish a foreign-key relationship to a specific source table.

### Relationships

The important relationships are:

```text
auth.users 1 ─── 1 profiles
profiles  1 ─── * workout_plans
profiles  1 ─── * workout_logs
profiles  1 ─── * blocking_rules
profiles  1 ─── * emergency_breaks
profiles  1 ─── * screen_time_transactions
profiles  1 ─── * user_rewards
profiles  1 ─── * notifications
profiles  1 ─── * friendships as requester/addressee
profiles  1 ─── * leaderboards as owner
leaderboards 1 ─── * leaderboard_members
exercises 1 ─── * media references / workout JSON references at application level
```

Workout-plan exercises are not normalized into a join table; the plan stores the exercise list as JSONB. That makes plan reads simple, but makes relational querying, referential integrity, and exercise-history updates more application-dependent.

### Enums

The schema defines enums for:

- Item type: app or website.
- Friendship status: pending, accepted, rejected.
- Subscription tier: free or VIP.
- User status: active, verified, onboarded, inactive, deleted, suspended.
- Workout source: manual or AI-generated.
- Blocking rule status: active, inactive, archived.
- Notification status: unread, read, archived.
- Media type: image, video, document.
- Exercise measurement: reps/weight, time/distance, time-only, reps-only.
- Transaction type: earned, spent, penalty, manual adjustment.

### Signup trigger

The database defines `handle_new_user()` as a `SECURITY DEFINER` function and attaches it to an `auth.users` insert trigger. Its job is to create a `profiles` row with the new user ID and email. When debugging signup, inspect both Supabase Auth and the profile row; a successful Auth user with no profile usually indicates a trigger/schema/configuration issue.

### Migrations and exercise seed data

The checked-in migrations are:

1. `20260417000001_screen_time_economy.sql` — adds profile economy fields and workout-plan session size.
2. `20260417000002_exercise_catalog_fields.sql` — adds exercise difficulty, muscle groups, steps, backfill, and indexes.
3. `20260417000003_exercises_read_policy.sql` — grants exercise read access and adds a public read policy.

Exercise catalog instructions are in [`docs/db/exercise-catalog.md`](db/exercise-catalog.md). The curated seed is [`docs/db/seed-exercises.sql`](db/seed-exercises.sql), and an optional generated seed can be produced with:

```bash
node scripts/import-free-exercise-db.mjs <path-to-json>
node scripts/import-free-exercise-db.mjs --download
```

The import tooling does not import media files.

### Security and RLS warning

The checked-in base schema does not define per-user Row Level Security policies or enable RLS for the application tables. The only checked-in policy migration is for public reading of exercises. This means the repository’s client-side `user_id` filters must not be treated as a security boundary by themselves.

Before production use or when setting up a fresh Supabase project, verify:

- RLS is enabled on every user-owned table.
- Policies restrict reads/writes to `auth.uid()` as appropriate.
- Public exercise reads are intentional.
- Service-role operations, if added, are server-side only.
- The actual remote schema includes fields used by current Dart code, especially `strict_blocking_only`.

The remote Supabase project may contain configuration not represented in this checkout. Do not infer production security from the checked-in SQL alone.

## 12. Repository/data-access map

The main contract-to-table mapping is:

| Core contract | Supabase implementation | Primary table/service |
|---|---|---|
| `AuthRepository` | `SupabaseAuthRepository` | Supabase Auth plus `profiles` |
| `ProfileRepository` | `SupabaseProfileRepository` | `profiles` |
| `WorkoutPlanRepository` | `SupabaseWorkoutPlanRepository` | `workout_plans` |
| `WorkoutLogRepository` | `SupabaseWorkoutLogRepository` | `workout_logs` |
| `ExerciseRepository` | `SupabaseExerciseRepository` | `exercises` |
| `BlockingRepository` | `SupabaseBlockingRepository` | `blocking_rules` |
| `EmergencyBreakRepository` | `SupabaseEmergencyBreakRepository` | `emergency_breaks` |
| `ScreenTimeTransactionRepository` | `SupabaseScreenTimeTransactionRepository` | `screen_time_transactions` |
| `FriendshipRepository` | `SupabaseFriendshipRepository` | `friendships` |
| `LeaderboardRepository` | `SupabaseLeaderboardRepository` | `leaderboards`, `leaderboard_members`, `profiles` |
| `NotificationRepository` | `SupabaseNotificationRepository` | `notifications` |
| `UserRewardRepository` | `SupabaseUserRewardRepository` | `user_rewards` |
| `MediaRepository` | `SupabaseMediaRepository` | `media` |
| `AppUsageInsightRepository` | No concrete implementation found | `app_usage_insights` |

The media repository currently inserts media metadata. It does not upload file bytes to Supabase Storage. If a feature appears to save an avatar or media item, verify whether the actual binary upload is implemented elsewhere before assuming it is complete.

## 13. Native blocking architecture

The Dart bridge is [`lib/infra/blocking/blocking-platform-service.dart`](../lib/infra/blocking/blocking-platform-service.dart), using:

```text
MethodChannel('com.nashaat/blocking')
```

Methods currently exposed include:

- `checkPermissions`
- `requestPermission`
- `getInstalledApps`
- `presentAppPicker`
- `startBlocking`
- `stopBlocking`
- `isBlockingActive`
- `getForegroundApp`
- `getSelectionSummary`

### Android path

Relevant files are under `android/app/src/main/kotlin/com/example/nashaat/`.

- `BlockingPlugin.kt` checks usage access, overlay, and accessibility-related permission state; opens system settings; lists launchable apps; persists blocked package IDs; starts/stops the foreground service; and reports active state.
- `BlockingAccessibilityService.kt` receives accessibility events, checks the event package against stored `blocked_apps`, and brings the Nashaat activity forward with a blocked-app extra.
- `AppBlockingService.kt` keeps a foreground service alive; actual app interception is performed through the accessibility service.
- The Android manifest declares package-usage, overlay, foreground-service, boot, and accessibility-related capabilities.

Android debugging checklist:

1. Confirm Usage Access permission.
2. Confirm overlay permission if the current implementation requires it.
3. Confirm accessibility service is enabled.
4. Check the stored package IDs and rule rows.
5. Confirm the foreground service is running.
6. Confirm the accessibility event package matches the stored package ID.
7. Confirm the Flutter focus timer and profile balance are updating independently of the native redirect.

### iOS path

Relevant files include:

- `ios/Runner/BlockingPlugin.swift`
- `ios/NashaatShield/ShieldConfigurationExtension.swift`
- `ios/NashaatShieldAction/ShieldActionExtension.swift`
- `ios/Runner/Runner.entitlements`

The Swift plugin uses FamilyControls authorization and FamilyActivityPicker, applies ManagedSettings shields, and stores selection/active state locally. Shield extensions control what the user sees and what shield actions do. iOS can represent app, category, and web-domain selections natively.

The current Dart onboarding path may create a synthetic `ios_selection:<count>` rule to represent the native selection rather than storing every native token in `blocking_rules`. Verify this mapping before building server-side reporting around iOS rules.

Strict iOS mode currently cannot inspect the foreground app from Flutter the way Android can, so its focus-drain behavior is deliberately different. Test iOS blocking on a real supported device with the proper entitlements and FamilyControls capabilities.

There is no complete desktop blocking implementation in the current Flutter code, even though future-oriented documentation mentions macOS and Windows.

## 14. Localization, theme, and shared UI

### Localization

`l10n.yaml` configures Flutter ARB generation from `lib/l10n`. English and Arabic resources are present, and the generated `AppLocalizations` class is used by the app. `LocaleProvider` persists the selected locale in `SharedPreferences` under `app_locale`.

Localization is partial: many current UI strings are still hard-coded English. Arabic support also depends on correct RTL layout behavior in each screen, not only on translating strings.

### Theme

The active design system is under `lib/shared/design/`:

- Custom Material 3 theme.
- App colors including black/white, acid green, signal yellow, and semantic error colors.
- Inter for English and Cairo for Arabic.
- Reusable atoms, molecules, and organisms.

There is also an older-looking theme file under `lib/shared/theme/app-theme.dart`. The active app imports the newer custom theme and currently forces `ThemeMode.light`; despite the existence of an `AppTheme.dark` symbol, a real user-facing dark-mode switch is not active.

## 15. Testing and quality checks

The test suite contains 11 Dart files: feature ViewModel suites plus shared mock repository and test-data helpers. The main test approach is unit-style testing of ViewModel behavior with `mocktail` mocks.

When changing a feature:

```bash
flutter analyze
flutter test
```

Then run the most specific test file for the changed ViewModel. For native blocking, also run a real device/emulator test because Flutter tests cannot validate:

- Android permission settings.
- Accessibility event delivery.
- Android foreground service behavior.
- iOS FamilyControls authorization.
- Shield extension behavior.
- Actual app/category/domain blocking.

The current analyzer findings are informational/lint issues, not compilation errors. They should still be cleaned up when touching the affected code, especially the asynchronous `BuildContext` uses.

## 16. Known gaps and risks

These are the most important facts for a new engineer to keep in mind:

1. **Checked-in SQL lacks complete RLS.** Client-side user filters are not sufficient isolation.
2. **Schema/code drift exists.** Current Dart code uses `strict_blocking_only`, but the checked-in SQL scan did not find that column.
3. **Screen-time accounting is multi-write.** Workout rewards and focus drains can partially succeed because log, transaction, and balance updates are not atomic RPCs/transactions.
4. **The native blocker is platform-dependent.** A passing Flutter test does not mean Android/iOS blocking works.
5. **Strict mode differs by platform.** Android can query a foreground package; iOS currently cannot through the Flutter path.
6. **Web blocking is incomplete in the current app path.** The schema supports website rules, but the current repository filters to app rules.
7. **Subscriptions are not implemented end-to-end.** The route is a placeholder.
8. **App usage insights have no concrete repository path.** The table and contract exist, but the implementation/locator registration is missing.
9. **Media upload is incomplete.** The repository stores metadata; it does not upload bytes to Storage.
10. **Account deletion is currently a metadata marker plus sign-out.** It is not a true Auth-user deletion flow.
11. **Streak updates may be incomplete.** An update operation exists, but no current caller was found.
12. **Localization is incomplete.** Some UI is still English-only.
13. **The actual theme is light-only.** The dark theme symbol should not be mistaken for enabled dark mode.
14. **Architecture boundaries are not fully enforced.** Several ViewModels access Supabase directly and features use a global locator.
15. **The app shell can trigger multiple initial loads.** All retained tabs may initialize when the dashboard shell is opened.
16. **Documentation describes future scope.** Computer vision, desktop blocking, advanced gamification, payment subscriptions, analytics, coach mode, and adaptive AI appear in product/use-case documents but should not be assumed to be implemented.

## 17. Recommended first-day reading order

Use this order to form a reliable mental model quickly:

### Step 1: Establish the runtime entry point

Read:

- [`lib/main.dart`](../lib/main.dart)
- [`lib/app/app-router.dart`](../lib/app/app-router.dart)
- [`lib/app/app-coordinator.dart`](../lib/app/app-coordinator.dart)
- [`lib/features/shell/view/app-shell-screen.dart`](../lib/features/shell/view/app-shell-screen.dart)

Answer these questions:

- Where is Supabase initialized?
- How does an unauthenticated user become authenticated?
- Where does onboarding status get checked?
- Which screen is actually the authenticated home?
- Which tabs are initialized when the shell opens?

### Step 2: Understand one complete vertical slice

The workout completion flow is a good first slice:

```text
ActiveSessionScreen
  -> ActiveSessionViewModel
    -> WorkoutLogRepository
    -> ScreenTimeTransactionRepository
    -> ProfileRepository
      -> Supabase repositories
        -> workout_logs / screen_time_transactions / profiles
```

Trace the save method all the way from the button callback to the Supabase table writes. This reveals the project’s ViewModel style, repository contracts, JSON mapping, error handling, and balance logic in one path.

### Step 3: Read the domain contracts before implementations

Browse:

- `lib/core/entities/`
- `lib/core/repositories/`

Then compare one contract with its `lib/infra/supabase/` implementation. This is faster than reading every screen first because it shows the system’s vocabulary and persistence boundary.

### Step 4: Read the database schema with the Dart entities open

Start with [`docs/db/schema.sql`](db/schema.sql), then read the three migration files. Pay special attention to:

- `profiles` economy fields.
- JSONB workout exercises.
- Array-based scheduled days.
- Transaction types and references.
- The signup trigger.
- RLS/policy coverage.

### Step 5: Study native blocking separately

Read the Dart MethodChannel bridge, then Android Kotlin, then iOS Swift/extensions. Do not treat native blocking as a normal CRUD feature; it has OS permissions, lifecycle, background execution, and platform-specific behavior.

### Step 6: Read the tests as executable examples

The ViewModel tests show expected state transitions and repository calls. When a test and a prose document disagree, start by checking whether the test describes the current intended behavior, then confirm the product requirement.

## 18. Useful investigation commands

```bash
# Find files quickly
rg --files lib core test docs android ios

# Find route definitions and navigation calls
rg "AppRouter|show[A-Z]|Navigator|pushNamed" lib

# Find Supabase access
rg "Supabase|supabase" lib

# Find all repository contracts and implementations
rg --files lib/core/repositories lib/infra/supabase

# Find table names used by Dart code
rg "from\(|\.from\(" lib/infra lib/features

# Find direct user/session access
rg "currentUser|auth\.currentUser|Supabase\.instance" lib

# Find native channel methods
rg "com\.nashaat/blocking|MethodChannel|startBlocking|stopBlocking" lib android ios

# Find schema and migration references
rg "CREATE TABLE|ALTER TABLE|CREATE POLICY|ENABLE ROW LEVEL SECURITY" docs/db supabase

# Check the working tree before and after a change
git status --short
```

## 19. How to make a safe change

For a normal feature change:

1. Run `git status --short` and preserve unrelated work.
2. Find the screen and ViewModel that own the behavior.
3. Check the core entity/repository contract.
4. Check the Supabase implementation and schema column names.
5. Check whether the behavior also has a native Android/iOS path.
6. Add or update a focused ViewModel test.
7. Run `flutter analyze` and the focused test.
8. Run `flutter test` before handoff.
9. If schema changes are involved, add a migration and verify RLS/policies.
10. If blocking changes are involved, test on the relevant real platform.

For screen-time balance changes, explicitly consider idempotency, retries, duplicate transactions, and partial writes. For auth/account changes, explicitly consider Supabase Auth state, the `profiles` row, and whether the operation requires a privileged server-side function.

## 20. Glossary

- **Profile:** The application-owned row associated with a Supabase Auth user.
- **Screen-time balance:** The number of minutes currently available for allowed/blocked-app usage accounting.
- **Earned transaction:** A positive ledger entry created by a workout or free weekly allowance.
- **Spent transaction:** A negative/consumption ledger entry created by focus accounting.
- **Blocking rule:** A server-side representation of an app or website the user wants blocked.
- **Native selection:** The platform-owned app/category/domain selection, especially on iOS.
- **Focus:** The user-facing blocking/screen-time feature, not just a database table.
- **Small/big session:** Workout session sizes with a 1× or 2× screen-time reward unit.
- **Coordinator:** A navigation helper that centralizes route transitions.
- **Repository:** A contract in `core` and a concrete external-data implementation in `infra`.
- **ViewModel:** A `ChangeNotifier` that owns feature state and orchestrates repository calls.
- **RLS:** PostgreSQL Row Level Security, the database-level authorization layer that is not fully represented in the checked-in schema.

## 21. The one-paragraph handoff

Nashaat is a Flutter/Dart mobile app with Supabase/Postgres persistence and native Android/iOS blocking. The app is organized around feature ViewModels, core repository contracts, Supabase implementations, and a global coordinator, with a five-tab authenticated shell. Workouts create logs and screen-time credits; the focus system consumes credits while native blocking is active. The database has a solid domain model, but checked-in RLS and schema coverage need verification before production assumptions are made. The best way to learn the code is to trace startup, then trace active-session save end to end, then read the schema, and finally study the native blocking implementations.
