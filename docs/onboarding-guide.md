# Nashaat — Developer Onboarding Guide

> This guide explains how the Nashaat codebase works, what every folder and file type does, how to follow the naming conventions, and how to create new features step by step.
>
> Written for beginners. No prior Flutter architecture experience assumed.

---

## Table of Contents

- [What is Nashaat?](#what-is-nashaat)
- [Tech Stack](#tech-stack)
- [Project Structure](#project-structure)
- [Understanding the Layers](#understanding-the-layers)
- [What Each File Type Does](#what-each-file-type-does)
- [The MVVM-C Pattern (Explained Simply)](#the-mvvm-c-pattern-explained-simply)
- [How Data Flows Through the App](#how-data-flows-through-the-app)
- [How Navigation Works](#how-navigation-works)
- [Naming Conventions](#naming-conventions)
- [How to Create a New Feature](#how-to-create-a-new-feature)
- [Common Commands](#common-commands)
- [Environment Setup](#environment-setup)
- [Rules You Must Follow](#rules-you-must-follow)

---

## What is Nashaat?

Nashaat is a mobile app that helps users **earn screen time by completing workouts**.

The core idea:

1. You work out → you earn screen time minutes
2. Those minutes let you use apps that would otherwise be blocked
3. There are social features (leaderboards, friends) and subscriptions (free / VIP)

---

## Tech Stack

| Layer | Technology |
|-------|-----------|
| **Frontend** | Flutter (Dart) |
| **Backend / Database** | Supabase (PostgreSQL) |
| **Auth** | Supabase Auth (email OTP, phone OTP, Google, Apple) |
| **Design System** | Material Design 3 |
| **State Management** | `ChangeNotifier` (built into Flutter) |
| **Environment Config** | `flutter_dotenv` (.env file) |

---

## Project Structure

Here is the full `lib/` folder — this is where all the Dart code lives:

```
lib/
├── main.dart                          ← App entry point
│
├── app/                               ← App-level setup
│   ├── app-coordinator.dart           ← Global navigation helper
│   └── app-router.dart                ← Route definitions
│
├── core/                              ← Domain layer (pure Dart, no Flutter)
│   ├── entities/                      ← Data models (what things ARE)
│   │   ├── enums.dart
│   │   ├── profile-entity.dart
│   │   ├── workout-log-entity.dart
│   │   ├── exercise-entity.dart
│   │   ├── blocking-rule-entity.dart
│   │   ├── notification-entity.dart
│   │   └── ... (14 files total)
│   │
│   ├── repositories/                  ← Abstract interfaces (what we CAN DO)
│   │   ├── auth-repository.dart
│   │   ├── blocking-repository.dart
│   │   ├── notification-repository.dart
│   │   └── ... (15 files total)
│   │
│   └── use_cases/                     ← Business rules (empty for now)
│
├── features/                          ← Feature modules (the main code)
│   ├── auth/
│   │   ├── coordinator/               ← Where to navigate after auth
│   │   ├── model/                     ← Auth-specific enums/DTOs
│   │   ├── view/                      ← Login, register, OTP screens
│   │   └── view_model/               ← Auth state + business logic
│   │
│   ├── blocking/
│   │   ├── coordinator/
│   │   ├── view/
│   │   └── view_model/
│   │
│   ├── dashboard/                     ← Scaffold only (not built yet)
│   ├── log_activity/                  ← Scaffold only
│   ├── onboarding/                    ← Scaffold only
│   └── subscription/                  ← Scaffold only
│
├── infra/                             ← External service adapters
│   ├── supabase/
│   │   ├── supabase-client.dart       ← Supabase client singleton
│   │   ├── auth-repository-impl.dart  ← Implements AuthRepository
│   │   └── blocking-repository-impl.dart
│   ├── blocking/
│   │   └── blocking-platform-service.dart  ← Native platform bridge
│   ├── notifications/                 ← Empty (for FCM setup later)
│   └── permissions/
│       └── permission-service.dart
│
└── shared/                            ← Cross-cutting utilities
    ├── logger.dart                    ← Logging with tags
    ├── theme/
    │   └── app-theme.dart             ← Light/dark Material 3 theme
    ├── components/                    ← Reusable composed widgets
    └── ui/                            ← Low-level UI helpers
```

---

## Understanding the Layers

Think of the code as **4 layers**, each with a specific job:

```
┌─────────────────────────────────────────────┐
│                 features/                    │  ← What the user sees and does
│          (views, view-models, coordinators)  │
├─────────────────────────────────────────────┤
│                   core/                      │  ← What things ARE and what we CAN DO
│          (entities, repository interfaces)   │  ← Pure Dart — no Flutter, no Supabase
├─────────────────────────────────────────────┤
│                   infra/                     │  ← HOW we talk to the outside world
│          (Supabase, Firebase, native APIs)   │  ← Implements core/ interfaces
├─────────────────────────────────────────────┤
│                  shared/                     │  ← Stuff everyone uses
│          (theme, logger, reusable widgets)   │
└─────────────────────────────────────────────┘
```

### Layer Rules

| Rule | Why |
|------|-----|
| `features/` can import `core/` and `shared/` | Features use domain models and shared utilities |
| `features/` can import `infra/` | Features need real implementations |
| `core/` imports **nothing** from other layers | Domain logic must be pure and independent |
| `infra/` imports `core/` | It implements the interfaces defined in core |
| `shared/` imports **nothing** from `features/` | Shared code can't depend on specific features |
| Features **never import other features** | Each feature is isolated |

---

## What Each File Type Does

### Entity (`core/entities/`)

> **"What is this thing?"**

An entity defines the shape of a piece of data. It's like a blueprint.

```dart
class BlockingRuleEntity {
  final String id;
  final String userId;
  final ItemType itemType;        // app or website
  final String itemIdentifier;    // package name or domain
  final RuleStatus status;        // active, inactive, archived
  final DateTime createdAt;
  final DateTime updatedAt;

  const BlockingRuleEntity({ ... });

  BlockingRuleEntity copyWith({ ... });  // Create a modified copy
}
```

**Key rules:**
- All fields are `final` (immutable — you can't change them after creation)
- Use `copyWith()` to create a modified version
- No Flutter imports. No Supabase imports. Just plain Dart.
- File name: `blocking-rule-entity.dart` (kebab-case, ends with `-entity`)

---

### Repository Interface (`core/repositories/`)

> **"What can we do with this thing?"**

A repository defines the **operations** you can perform, without saying **how** they work.

```dart
abstract class BlockingRepository {
  Future<List<BlockingRuleEntity>> getUserRules(String userId, {RuleStatus? status});
  Future<BlockingRuleEntity> createRule(BlockingRuleEntity rule);
  Future<BlockingRuleEntity> updateRuleStatus(String id, RuleStatus status);
  Future<void> deleteRule(String id);
}
```

**Key rules:**
- Always `abstract` — no actual code, just method signatures
- Uses entities from `core/entities/`
- The real code that talks to Supabase lives in `infra/`
- File name: `blocking-repository.dart` (kebab-case, ends with `-repository`)

---

### Repository Implementation (`infra/supabase/`)

> **"Here's how we actually do it with Supabase."**

This is where the real database queries live.

```dart
class SupabaseBlockingRepository implements BlockingRepository {
  final _client = SupabaseClientProvider.instance.client;

  @override
  Future<List<BlockingRuleEntity>> getUserRules(String userId, {RuleStatus? status}) async {
    var query = _client.from('blocking_rules').select().eq('user_id', userId);
    if (status != null) {
      query = query.eq('status', _statusToString(status));
    }
    final data = await query;
    return data.map(_fromMap).toList();
  }
}
```

**Key rules:**
- Class name starts with `Supabase` + the interface name: `SupabaseBlockingRepository`
- `implements` the abstract repository from `core/`
- This is the **only place** that imports Supabase
- File name: `blocking-repository-impl.dart` (ends with `-impl`)

---

### ViewModel (`features/*/view_model/`)

> **"What state does this screen need, and what logic controls it?"**

The ViewModel holds the screen's state and business logic. It extends `ChangeNotifier`.

```dart
class BlockingViewModel extends ChangeNotifier {
  // ── State (private) ──
  List<BlockingRuleEntity> _rules = [];
  bool _isLoading = false;
  String? _error;

  // ── Getters (public, read-only) ──
  List<BlockingRuleEntity> get rules => List.unmodifiable(_rules);
  bool get isLoading => _isLoading;
  String? get error => _error;

  // ── Actions ──
  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();        // Tell the UI to rebuild

    _rules = await _repo.getUserRules(_userId);

    _isLoading = false;
    notifyListeners();        // Tell the UI to rebuild again
  }
}
```

**Key rules:**
- Extends `ChangeNotifier`
- State fields are private (`_underscore`)
- Public getters expose read-only state
- Call `notifyListeners()` after every state change
- No Flutter widget imports — only pure Dart + repository calls
- File name: `blocking-view-model.dart` (kebab-case, ends with `-view-model`)

---

### View / Screen (`features/*/view/`)

> **"What does the user see?"**

A screen is a Flutter widget that displays UI based on the ViewModel's state.

```dart
class BlockingScreen extends StatefulWidget {
  final String userId;
  const BlockingScreen({super.key, required this.userId});

  @override
  State<BlockingScreen> createState() => _BlockingScreenState();
}

class _BlockingScreenState extends State<BlockingScreen> {
  late final BlockingViewModel _vm;

  @override
  void initState() {
    super.initState();
    _vm = BlockingViewModel(
      userId: widget.userId,
      blockingRepo: SupabaseBlockingRepository(),
      // ... other dependencies
    );
    _vm.initialize();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _vm,
      builder: (context, _) {
        if (_vm.isLoading) return const CircularProgressIndicator();
        if (_vm.error != null) return Text(_vm.error!);
        return _buildContent();
      },
    );
  }
}
```

**Key rules:**
- `StatefulWidget` that creates the ViewModel in `initState()`
- Uses `ListenableBuilder` to rebuild when the ViewModel calls `notifyListeners()`
- Passes dependencies to the ViewModel (repository, services)
- File name: `blocking-screen.dart` (kebab-case, ends with `-screen`)

---

### Coordinator (`features/*/coordinator/`)

> **"Where do we go next?"**

A coordinator handles navigation decisions for a feature.

```dart
class AuthCoordinator {
  final AppCoordinator _app;
  const AuthCoordinator(this._app);

  void handleAuthSuccess(AuthViewModel vm) {
    if (vm.needsOnboarding) {
      _app.showOnboarding();    // Navigate to onboarding
    } else {
      _app.showDashboard();     // Navigate to dashboard
    }
  }
}
```

**Key rules:**
- Takes `AppCoordinator` as a dependency
- Makes navigation decisions based on ViewModel state
- Never builds widgets — only navigates
- File name: `auth-coordinator.dart` (kebab-case, ends with `-coordinator`)

---

### Model (`features/*/model/`)

> **"Feature-specific data types that aren't domain entities."**

```dart
enum OtpMethod { email, phone }

enum AuthFlowStep {
  idle,
  loading,
  otpSent,
  verifying,
  authenticated,
  error,
}
```

**Key rules:**
- Enums, DTOs, or small classes specific to one feature
- Not shared across features (use `core/entities/` for that)
- File name: `auth-models.dart` (kebab-case, ends with `-models`)

---

## The MVVM-C Pattern (Explained Simply)

MVVM-C stands for **Model - View - ViewModel - Coordinator**.

Here's what each part does:

```
┌──────────┐     watches      ┌─────────────┐     calls      ┌────────────┐
│          │ ◀──────────────── │             │ ──────────────▶ │            │
│   View   │                  │  ViewModel   │                │ Repository │
│ (screen) │ ──────────────▶  │  (state +    │ ◀────────────── │ (database) │
│          │   user actions   │   logic)     │    data         │            │
└──────────┘                  └──────┬──────┘                 └────────────┘
                                     │
                                     │ navigation decisions
                                     ▼
                              ┌─────────────┐
                              │ Coordinator  │
                              │ (where to    │
                              │  go next)    │
                              └─────────────┘
```

**In plain English:**

1. The **View** (screen) shows buttons, text, lists
2. When the user taps something, the View tells the **ViewModel**
3. The ViewModel does the work (calls the database, processes data)
4. The ViewModel updates its state and calls `notifyListeners()`
5. The View rebuilds automatically to show the new state
6. If navigation is needed, the **Coordinator** decides where to go

---

## How Data Flows Through the App

Let's trace what happens when a user blocks an app:

```
1. User taps "Block Instagram" on BlockingScreen (View)
         │
         ▼
2. BlockingScreen calls _vm.addRules([instagram])
         │
         ▼
3. BlockingViewModel calls _repo.createRule(rule) (ViewModel → Repository)
         │
         ▼
4. SupabaseBlockingRepository inserts row into blocking_rules table (Infra)
         │
         ▼
5. BlockingViewModel calls _platform.startBlocking(appIds) (ViewModel → Service)
         │
         ▼
6. BlockingPlatformService sends message to native Android/iOS (Infra)
         │
         ▼
7. BlockingViewModel updates _rules list, calls notifyListeners()
         │
         ▼
8. BlockingScreen rebuilds, showing Instagram in the blocked apps list (View)
```

---

## How Navigation Works

Nashaat uses the **Coordinator pattern** for navigation:

### Route Definitions

All routes are defined as string constants in `lib/app/app-router.dart`:

```dart
class AppRouter {
  static const String splash       = '/';
  static const String login        = '/login';
  static const String register     = '/register';
  static const String dashboard    = '/dashboard';
  static const String logActivity  = '/log-activity';
  static const String blocking     = '/blocking';
  static const String subscription = '/subscription';
}
```

### AppCoordinator

The global `AppCoordinator` (`lib/app/app-coordinator.dart`) provides navigation methods:

```dart
appCoordinator.showLogin();          // Navigate to login (clears stack)
appCoordinator.showDashboard();      // Navigate to dashboard (clears stack)
appCoordinator.showBlocking(userId: '...');  // Push blocking screen
appCoordinator.pop();                // Go back
```

### Adding a New Route

1. Add the route constant in `app-router.dart`
2. Add the `case` in `generateRoute()`
3. Add a navigation method in `app-coordinator.dart`
4. Create a feature coordinator if the feature has internal navigation

---

## Naming Conventions

| What | Convention | Example |
|------|-----------|---------|
| **Files** | kebab-case | `blocking-view-model.dart` |
| **Folders** | kebab-case | `log-activity/`, `view_model/` |
| **Classes** | PascalCase | `BlockingViewModel` |
| **Variables & functions** | camelCase | `isLoading`, `notifyListeners()` |
| **Private fields** | camelCase with underscore | `_rules`, `_isLoading` |
| **Constants** | camelCase | `static const String splash = '/'` |
| **Route paths** | kebab-case | `/log-activity`, `/blocking` |
| **Enums** | PascalCase name, camelCase values | `enum RuleStatus { active, inactive }` |

### File Naming Suffixes

| File Type | Suffix | Example |
|-----------|--------|---------|
| Entity | `-entity.dart` | `profile-entity.dart` |
| Repository (abstract) | `-repository.dart` | `auth-repository.dart` |
| Repository (impl) | `-repository-impl.dart` | `auth-repository-impl.dart` |
| ViewModel | `-view-model.dart` | `auth-view-model.dart` |
| Screen | `-screen.dart` | `login-screen.dart` |
| Coordinator | `-coordinator.dart` | `auth-coordinator.dart` |
| Models | `-models.dart` | `auth-models.dart` |
| Widgets | `-widgets.dart` | `auth-widgets.dart` |
| Service | `-service.dart` | `permission-service.dart` |

---

## How to Create a New Feature

Let's say you're building the **dashboard** feature. Here's every step:

### Step 1 — Create the folder structure

```
lib/features/dashboard/
├── coordinator/
│   └── dashboard-coordinator.dart
├── model/
│   └── dashboard-models.dart        ← (only if you need feature-specific types)
├── view/
│   └── dashboard-screen.dart
└── view_model/
    └── dashboard-view-model.dart
```

### Step 2 — Create the entity (if needed)

If your feature introduces new data, add it to `core/entities/`:

```dart
// lib/core/entities/dashboard-summary-entity.dart
class DashboardSummaryEntity {
  final int screenTimeBalance;
  final int streakCount;
  final int workoutsThisWeek;

  const DashboardSummaryEntity({ ... });
}
```

### Step 3 — Create the repository interface

```dart
// lib/core/repositories/dashboard-repository.dart
abstract class DashboardRepository {
  Future<DashboardSummaryEntity> getSummary(String userId);
}
```

### Step 4 — Create the repository implementation

```dart
// lib/infra/supabase/dashboard-repository-impl.dart
class SupabaseDashboardRepository implements DashboardRepository {
  @override
  Future<DashboardSummaryEntity> getSummary(String userId) async {
    final data = await _client.from('profiles').select().eq('id', userId).single();
    return DashboardSummaryEntity(
      screenTimeBalance: data['screen_time_balance_minutes'],
      streakCount: data['streak_count'],
      workoutsThisWeek: ...,
    );
  }
}
```

### Step 5 — Create the ViewModel

```dart
// lib/features/dashboard/view_model/dashboard-view-model.dart
class DashboardViewModel extends ChangeNotifier {
  final DashboardRepository _repo;
  final String _userId;

  DashboardSummaryEntity? _summary;
  bool _isLoading = false;

  DashboardSummaryEntity? get summary => _summary;
  bool get isLoading => _isLoading;

  DashboardViewModel({required String userId, required DashboardRepository repo})
      : _userId = userId, _repo = repo;

  Future<void> load() async {
    _isLoading = true;
    notifyListeners();

    _summary = await _repo.getSummary(_userId);

    _isLoading = false;
    notifyListeners();
  }
}
```

### Step 6 — Create the Screen

```dart
// lib/features/dashboard/view/dashboard-screen.dart
class DashboardScreen extends StatefulWidget {
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late final DashboardViewModel _vm;

  @override
  void initState() {
    super.initState();
    _vm = DashboardViewModel(
      userId: /* get from auth */,
      repo: SupabaseDashboardRepository(),
    );
    _vm.load();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _vm,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(title: const Text('Dashboard')),
          body: _vm.isLoading
              ? const Center(child: CircularProgressIndicator())
              : _buildContent(),
        );
      },
    );
  }

  Widget _buildContent() {
    final summary = _vm.summary;
    if (summary == null) return const SizedBox.shrink();
    return Column(
      children: [
        Text('Screen Time: ${summary.screenTimeBalance} min'),
        Text('Streak: ${summary.streakCount} days'),
      ],
    );
  }
}
```

### Step 7 — Register the route

In `lib/app/app-router.dart`:

```dart
case dashboard:
  return MaterialPageRoute(builder: (_) => const DashboardScreen());
```

### Step 8 — Add navigation

In `lib/app/app-coordinator.dart`:

```dart
void showDashboard() {
  Log.nav('showDashboard');
  _navigator?.pushNamedAndRemoveUntil('/dashboard', (_) => false);
}
```

---

## Common Commands

```bash
# Install dependencies
flutter pub get

# Run the app (debug mode)
flutter run

# Run all tests
flutter test

# Run a single test file
flutter test test/some_test.dart

# Analyze code for issues
flutter analyze

# Build for Android
flutter build apk

# Build for iOS
flutter build ios
```

---

## Environment Setup

### 1. Install Flutter

Follow the [official Flutter install guide](https://docs.flutter.dev/get-started/install).

### 2. Clone the repo

```bash
git clone <repo-url>
cd nashaat
```

### 3. Create the `.env` file

Create a file called `.env` in the project root:

```env
SUPABASE_URL=<your-supabase-url>
SUPABASE_ANON_KEY=<your-anon-key>
```

> Ask the project lead for these values if you don't have them.

### 4. Install dependencies

```bash
flutter pub get
```

### 5. Run the app

```bash
flutter run
```

---

## Rules You Must Follow

These are not suggestions. They are rules.

### 1. Never import one feature from another feature

```dart
// ❌ WRONG — features must be isolated
import 'package:nashaat/features/auth/view_model/auth-view-model.dart';
// (inside a file in features/blocking/)

// ✅ RIGHT — use core/ for shared models
import 'package:nashaat/core/entities/profile-entity.dart';
```

### 2. Never import Supabase in a ViewModel

```dart
// ❌ WRONG
import 'package:supabase_flutter/supabase_flutter.dart';

// ✅ RIGHT — depend on the abstract repository
final BlockingRepository _repo;
```

### 3. Always use kebab-case for file names

```
✅ auth-view-model.dart
❌ authViewModel.dart
❌ auth_view_model.dart
❌ AuthViewModel.dart
```

### 4. Always call `notifyListeners()` after changing state

```dart
// ❌ WRONG — UI won't update
_isLoading = true;

// ✅ RIGHT
_isLoading = true;
notifyListeners();
```

### 5. Keep entities immutable

```dart
// ❌ WRONG — mutable field
String name;

// ✅ RIGHT — immutable
final String name;
```

### 6. Use `Log` for debugging, not `print()`

```dart
// ❌ WRONG
print('loading rules');

// ✅ RIGHT
Log.blocking('loading rules for user $userId');
```

### 7. Every repository implementation must implement the abstract interface

```dart
// ✅
class SupabaseBlockingRepository implements BlockingRepository { ... }
```

---

## Existing Logging Tags

The `Log` class in `lib/shared/logger.dart` provides these:

| Method | Tag | Use For |
|--------|-----|---------|
| `Log.auth()` | `🔐 auth` | Authentication flows |
| `Log.nav()` | `🧭 nav` | Navigation events |
| `Log.blocking()` | `🚫 blocking` | Blocking feature |
| `Log.db()` | `🗄️ db` | Database operations |
| `Log.boot()` | `🚀 boot` | App startup |
| `Log.error()` | `💥 tag` | Errors (pass custom tag) |

When you add a new feature, consider adding a new log tag.

---

## Quick Reference Card

```
Need to...                          → Go to...
────────────────────────────────────────────────────
Define what data looks like         → core/entities/
Define what operations exist        → core/repositories/
Write the actual database code      → infra/supabase/
Build the screen UI                 → features/*/view/
Manage screen state + logic         → features/*/view_model/
Handle navigation decisions         → features/*/coordinator/
Add a new route                     → app/app-router.dart
Add a navigation method             → app/app-coordinator.dart
Share a widget across features      → shared/components/
Change the app theme                → shared/theme/app-theme.dart
Log something                       → shared/logger.dart
Check the database schema           → docs/db/schema.sql
```

---

> **Remember:** When in doubt, look at how the `auth` or `blocking` features are built. They are the reference implementations. Copy their patterns.
