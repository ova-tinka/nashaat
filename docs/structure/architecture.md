# Nashaat — Architecture & Project Structure

## 1. What Is Nashaat?

Nashaat is a mobile application that ties physical exercise to screen-time allowance. Users build workout plans, log completed sessions, and earn screen-time minutes in return. The app can block distracting apps and websites until the user meets their exercise goals, creating a self-reinforcing habit loop.

Key capabilities:

- **Workout planning & logging** — create routines (manual or AI-generated for VIP), track completion, and earn screen-time credits.
- **Screen-time economy** — an immutable ledger of earned/spent/penalty minutes governs how much leisure screen-time is available.
- **App & web blocking** — enforce blocking rules on the device when the screen-time balance runs out.
- **Social motivation** — private leaderboards, friend connections, streaks, and reward milestones.
- **Subscription tiers** — free tier with core features; VIP tier unlocks AI workout generation, advanced analytics, and extended blocking options.

---

## 2. Technology Choices

| Concern | Choice | Rationale |
|---|---|---|
| **Framework** | Flutter (Dart SDK ^3.10.1) | Single codebase for iOS and Android with native performance. Material 3 design system out of the box. |
| **Backend / Auth** | Supabase (PostgreSQL + GoTrue) | Managed Postgres with built-in auth (email/password, OAuth), real-time subscriptions, and Row-Level Security — no custom server to maintain. |
| **Environment config** | `flutter_dotenv` | Keeps `SUPABASE_URL` and `SUPABASE_ANON_KEY` out of version control via a git-ignored `.env` file. |
| **Linting** | `flutter_lints` (analysis_options.yaml) | Enforces idiomatic Dart and Flutter best practices across the codebase. |
| **State / UI pattern** | MVVM-C (Model-View-ViewModel-Coordinator) | Separates navigation logic (Coordinator) from presentation state (ViewModel) and UI (View), keeping each layer independently testable. |
| **Project organisation** | Feature-first | Each feature owns its full vertical slice (view → view_model → model → coordinator), reducing cross-feature coupling. |

---

## 3. Architectural Pattern — MVVM-C

```
┌──────────────┐
│  Coordinator │  Owns navigation decisions for a feature or the whole app.
│              │  Receives "what happened" signals from ViewModels and
│              │  translates them into route pushes/pops.
└──────┬───────┘
       │ navigates
       ▼
┌──────────────┐
│     View     │  Stateless or thin-stateful Flutter widgets.
│              │  Reads state from the ViewModel; forwards user
│              │  gestures back to the ViewModel.
└──────┬───────┘
       │ binds to
       ▼
┌──────────────┐
│  ViewModel   │  Holds presentation state and orchestrates use-cases.
│              │  Exposes streams/notifiers the View listens to.
│              │  Never imports Flutter UI code.
└──────┬───────┘
       │ calls
       ▼
┌──────────────┐
│  Use Case /  │  Pure business logic. Depends only on repository
│  Repository  │  interfaces defined in core/, implemented in infra/.
└──────────────┘
```

### Why MVVM-C over alternatives

- **vs plain MVVM** — Coordinators centralise navigation, preventing Views from knowing about other Views. This makes deep-link support and flow changes trivial.
- **vs BLoC** — ViewModels are simpler to reason about for screens with moderate complexity; BLoC's event/state ceremony adds overhead without proportional benefit here.
- **vs MVC** — MVC conflates presentation state and navigation; MVVM-C draws a clear boundary for each.

### Data-flow rules

1. **Views** never call repositories or Supabase directly.
2. **ViewModels** depend on abstract repository interfaces (`core/repositories/`), not concrete implementations.
3. **Coordinators** depend on ViewModels (to observe outcomes) and the navigator, nothing else.
4. **Infra** implements repository interfaces and wraps third-party SDKs (Supabase, notifications, permissions).

---

## 4. Project Organisation

```
lib/
│
├── main.dart                        Entry point — initialises Supabase, runs NashaatApp
│
├── app/
│   ├── app_coordinator.dart         Root-level coordinator (owns NavigatorKey)
│   └── app_router.dart              Named-route constants & onGenerateRoute
│
├── features/                        One folder per product feature
│   ├── auth/
│   │   ├── coordinator/             AuthCoordinator — login ↔ register ↔ forgot-password flows
│   │   ├── view/                    LoginScreen, RegisterScreen, etc.
│   │   ├── view_model/              AuthViewModel — manages auth state
│   │   └── model/                   DTOs & request/response models specific to auth
│   ├── onboarding/                  First-run experience, profile setup
│   ├── dashboard/                   Home screen, weekly stats, leaderboard snapshot
│   ├── log_activity/                Workout logging, screen-time earning
│   ├── blocking/                    App & website blocking configuration
│   └── subscription/               Free / VIP tier management
│
├── core/                            Shared domain layer (feature-agnostic)
│   ├── entities/                    Domain models (User, WorkoutPlan, BlockingRule …)
│   ├── repositories/                Abstract repository interfaces
│   └── use_cases/                   Business-logic actions (e.g. LogWorkoutUseCase)
│
├── shared/                          Cross-feature presentation utilities
│   ├── theme/
│   │   └── app_theme.dart           Light & dark ThemeData (Material 3, deepPurple seed)
│   ├── components/                  Composed widgets (cards, dialogs, bottom sheets)
│   └── ui/                          Low-level helpers (spacing, text styles, extensions)
│
└── infra/                           External-world adapters
    ├── supabase/
    │   └── supabase_client.dart     SupabaseClientProvider (client + auth accessors)
    ├── notifications/               FCM / local notification setup
    └── permissions/                 Runtime permission requests (camera, activity, etc.)
```

### Naming conventions

| Item | Convention | Example |
|---|---|---|
| Files | `snake_case.dart` | `login_screen.dart` |
| Classes | `PascalCase` | `LoginScreen` |
| Feature folders | `snake_case` | `log_activity/` |
| Route constants | `static const String` in `AppRouter` | `AppRouter.login` → `'/login'` |
| Views (screens) | Suffix `Screen` | `DashboardScreen` |
| ViewModels | Suffix `ViewModel` | `DashboardViewModel` |
| Coordinators | Suffix `Coordinator` | `AuthCoordinator` |
| Repositories | Prefix with domain, suffix `Repository` | `WorkoutRepository` |
| Use Cases | Verb-noun, suffix `UseCase` | `LogWorkoutUseCase` |

---

## 5. Backend — Supabase & Database

### Connection

The app loads `SUPABASE_URL` and `SUPABASE_ANON_KEY` from a `.env` file at startup. The singleton is accessible via `SupabaseClientProvider.client`.

### Schema overview (docs/db/schema.sql)

The PostgreSQL schema defines 8 custom enums and 13 tables:

| Table | Purpose |
|---|---|
| `profiles` | Extends `auth.users` — username, avatar, status, subscription tier, screen-time balance, streak |
| `media` | Centralised storage metadata for user-uploaded images/videos |
| `exercises` | Master exercise catalogue (system + user-created) |
| `workout_plans` | User routines with scheduled days and JSONB exercise list |
| `workout_logs` | Completed session records; earned screen-time recorded here |
| `screen_time_transactions` | Immutable ledger (earned / spent / penalty / manual adjustment) |
| `blocking_rules` | Per-user app or website identifiers to block |
| `emergency_breaks` | Temporary blocking bypasses with reason + duration |
| `friendships` | Bidirectional friend requests (pending / accepted / rejected) |
| `user_rewards` | Unlocked achievements and streak milestones |
| `notifications` | Push / in-app notification records |
| `leaderboards` + `leaderboard_members` | Private invite-code leaderboards with weekly scores |
| `app_usage_insights` | Daily aggregated screen-time breakdown (JSONB) |

A database trigger automatically creates a `profiles` row when a new user signs up through Supabase Auth.

Row-Level Security (RLS) policies are expected to be layered on top via Supabase dashboard or migration scripts in `supabase/`.

---

## 6. Feature Map

The following table maps each feature folder to its use-case specifications in `docs/use-case-specs/`:

| Feature folder | Use-case specs | Core responsibility |
|---|---|---|
| `auth/` | UC-01 Register, UC-02 Login | Sign up (email, Google, Apple), sign in, password reset, session management |
| `onboarding/` | UC-03 Manage Account Settings | First-run profile setup, preferences, weekly exercise target |
| `dashboard/` | UC-06 Performance Dashboard, UC-13 Leaderboards, UC-15 Streaks & Rewards | Home screen with weekly progress, leaderboard snapshot, streak status |
| `log_activity/` | UC-04 Manage Workout Plan, UC-05 Log Workout & Earn Screen-time | Create/edit workout plans, log sessions, calculate earned minutes |
| `blocking/` | UC-07 Screen Lock & Emergency Break, UC-08 Mobile App Blocking, UC-09 Web Blocking, UC-10 Manage Blocking Config | Enforce and configure app/website restrictions, emergency bypasses |
| `subscription/` | UC-11 Subscription Management | Free vs VIP tier, feature gating, payment integration |

Cross-cutting specs (UC-12 Notifications, UC-14 Manage Friends) are handled in `infra/notifications/` and shared components respectively.

---

## 7. Routing & Navigation

`AppRouter` defines named route constants and a `generateRoute` factory. `AppCoordinator` holds the global `NavigatorKey` and exposes typed methods (`showDashboard()`, `showLogin()`, etc.) so that ViewModels never touch `Navigator` directly.

Feature-level coordinators (e.g. `AuthCoordinator`) can manage sub-flows (login → forgot password → reset confirmation) internally before handing control back to `AppCoordinator`.

```
AppCoordinator
├── AuthCoordinator       (login ↔ register ↔ reset)
├── OnboardingCoordinator (step 1 → step 2 → … → dashboard)
├── DashboardCoordinator  (tabs, drill-downs)
├── LogActivityCoordinator
├── BlockingCoordinator
└── SubscriptionCoordinator
```

---

## 8. Theming

`AppTheme` provides `light` and `dark` `ThemeData` instances using Material 3's `ColorScheme.fromSeed` with `Colors.deepPurple` as the seed colour. `NashaatApp` passes both to `MaterialApp`, enabling automatic dark-mode switching based on system settings.

---

## 9. Testing Strategy

```
test/
├── unit/            Pure Dart tests for use cases, entities, ViewModels
├── widget/          Flutter widget tests for Views in isolation
└── integration/     End-to-end flows (optional, run on device/emulator)
```

- ViewModels are tested by injecting mock repository implementations.
- Views are tested with `WidgetTester` by providing a mock ViewModel.
- Coordinators are tested by asserting the correct route was pushed for a given ViewModel event.

---

## 10. Preferences & Conventions

1. **Specification-first** — every feature has a written use-case spec before code is written.
2. **No credentials in git** — secrets live in `.env`, which is git-ignored.
3. **Minimal dependencies** — add a package only when it provides clear value over a hand-written solution.
4. **Material 3** — all UI follows Material 3 guidelines via `useMaterial3: true`.
5. **Dart analysis clean** — `flutter analyze` must pass with zero issues before merging.
6. **Feature isolation** — features never import from each other directly; shared code goes in `core/` or `shared/`.
7. **Immutable domain models** — entities in `core/entities/` should be immutable data classes.
8. **Repository pattern** — all data access goes through abstract interfaces in `core/repositories/`, implemented in `infra/`.
