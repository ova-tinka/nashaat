# Daris compared with Nashaat

Reviewed local source on 2026-10-27. Daris is located at `../daris`.

Nashaat has the stronger foundation for continued development: explicit repository boundaries, broader tests, and database-controlled workout rewards. Daris provides a focused study experience with AI questions, course materials, and an offline demo. Both implement the same general product loop: complete a useful activity, earn minutes, then spend them on access to distracting apps.

## Comparison

| Area | Daris | Nashaat |
| --- | --- | --- |
| Product focus | Studying, subjects, tasks, AI questions | Workouts, exercise plans, sessions, achievements and social features |
| Stack | Flutter, Dart SDK constraint ^3.10.1, Supabase | Flutter, Dart SDK constraint ^3.10.1, Supabase |
| Presentation architecture | GetX controllers, bindings and named routes | Feature view models and coordinators, app router, domain repository interfaces and infrastructure implementations |
| Data access | Shared `SupabaseService` handles multiple domains | Separate repository interfaces and Supabase implementations for each domain |
| Native blocking | iOS plugin, blocking services, shield and activity monitor extensions; Android MainActivity is minimal | iOS blocking plugin and shield extensions; Android plugin, blocking service and accessibility service |
| Reward handling | Task completion RPC plus direct earning/spending inserts and client balance calculation | Migration introduces authoritative workout sessions, restricted ledger writes and session uniqueness constraints |
| Demo | Dedicated demo controller and bindings, with a tested offline study/earn/spend example | No dedicated demo feature directory found |
| Flutter source files under `lib/` | 67 | 149 |
| Dart test files under `test/` | 2 | 18 |
| Supabase migration files | 7 | 18 |

Counts describe the local files inspected, not quality scores or passing test results.

## Architecture and maintainability

Daris is compact and straightforward to follow. Features use `controller/`, `view/`, and sometimes `bindings/`; data models and services are shared under `lib/data/`. Its `SupabaseService` covers authentication, subjects, tasks and screen-time accounting, so changes across those domains meet in one service.

Nashaat separates domain contracts in `lib/core/repositories/` from implementations in `lib/infra/supabase/`. Feature coordinators handle navigation and view models handle presentation state. This gives more specific places to change and substitute behavior, at the cost of additional files and wiring. Repository interfaces alone do not establish that every business rule is correctly separated or implemented.

Sources: [Daris data service](../../daris/lib/data/services/supabase_service.dart), [Daris app setup](../../daris/lib/main.dart), [Nashaat repository locator](../lib/infra/repository-locator.dart), [Nashaat router](../lib/app/app-router.dart).

## Reward accounting: a concrete difference

Daris has a `complete_study_task_and_earn` RPC, so its task flow is not entirely client controlled. However, its general `addEarning` and `recordSpend` methods insert rows directly, and `getWeeklyWalletBalance` reads earnings and spends separately and calculates the balance in Dart.

`BalanceController.spendOnSelectedApps` checks its local balance, records a spend, updates the displayed balance, and then calls the native app-unlock method. If unlocking throws, the controller reports that the wallet was updated but apps could not be opened. This method contains no compensating refund. The separate balance check and insert also warrant a database-level concurrency review; this inspection does not establish whether deployed database rules prevent overspending.

Nashaat's authoritative rewards migration snapshots workout plans into sessions, adds uniqueness constraints for session completion, and revokes direct client writes to workout logs and the screen-time ledger. That is a stronger pattern for protecting reward integrity. The presence of the migration does not prove it has been deployed or that all accounting paths are correct.

Sources: [Daris balance controller](../../daris/lib/features/balance/controller/balance_controller.dart), [Daris wallet methods](../../daris/lib/data/services/supabase_service.dart), [Nashaat authoritative rewards migration](../supabase/migrations/20260923000009_authoritative_workout_rewards.sql).

## Platform implementation

Daris has substantial native iOS work, including `BlockingEngine`, `ScheduleManager`, `FocusFlowPlugin`, and a Device Activity monitor extension. Nashaat has its own iOS plugin and shield extensions. Extension inventories differ; source presence alone cannot determine which app enforces limits more reliably on a device.

The Android difference is clearer: Daris's `MainActivity` simply extends `FlutterActivity`, whereas Nashaat includes an Android blocking plugin, foreground service, and accessibility service. Daris's iOS work should not be treated as proof of Android blocking support.

Sources: [Daris iOS plugin](../../daris/ios/Runner/FocusFlowPlugin.swift), [Daris Android entry point](../../daris/android/app/src/main/kotlin/com/focusflow/focus_flow_flutter/MainActivity.kt), [Nashaat platform bridge](../lib/infra/blocking/blocking-platform-service.dart), [Nashaat Android blocking service](../android/app/src/main/kotlin/com/example/nashaat/AppBlockingService.kt).

## Tests and development confidence

Daris has two Dart test files covering wallet/demo behavior and authentication widgets. Nashaat has eighteen, spanning authentication, onboarding, workouts, dashboard, social, achievements, settings, the shell and design foundations. Nashaat therefore has broader existing test coverage by feature, though file counts do not measure assertion quality or code coverage.

Sources: [Daris wallet/demo tests](../../daris/test/wallet_and_demo_test.dart), [Nashaat workout session tests](../test/features/workout/view_model/active_session_view_model_test.dart), [Nashaat social tests](../test/features/social/view_model/friends_view_model_test.dart).

## What to borrow

1. Keep Nashaat's repository, view-model and coordinator structure when adding features. Adapt Daris ideas into those boundaries.
2. Consider Daris's offline demo pattern for demonstrating the workout-to-minutes loop without account setup or native permissions.
3. Review Daris's explicit earn, reward-result and spend-confirmation flow as a product reference. A visual comparison still requires running both apps.
4. Use Nashaat's database-controlled rewards approach as a reference for strengthening Daris's general wallet operations. Make spending atomic and define recovery when native access fails.
5. Compare iOS expiry and relocking behavior on real devices before sharing native blocking code. The two apps have different extension arrangements.

## Scope and verification

This was a read-only source comparison of local architecture, dependencies, feature inventories, selected wallet implementations, native file inventories, tests and migrations. No application code was changed. No Flutter tests, analyzer, builds, deployed database checks or device checks were run. UI quality, subscription completeness, production readiness and actual enforcement reliability remain unverified.
