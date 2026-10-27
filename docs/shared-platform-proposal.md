# A shared platform for workouts, studying, reading and tasks

Yes—this is feasible. My recommendation is one shared platform, implemented in a React Native monorepo, with four domain modules and initially one combined mobile app. Keep the modules usable by separate branded apps if that becomes useful later.

The biggest work is defining a consistent reward economy, consolidating the backend, and migrating native blocking. Sharing buttons across frontends is comparatively straightforward.

## Decide what “super app” means

| Distribution | What users get | Engineering implications |
| --- | --- | --- |
| One combined app | One installation, login, wallet and navigation across all four activities | Simplest launch and most coherent blocking behavior |
| Four standalone apps | Separate installations and experiences using the same account/backend | Four release pipelines, deep-link setups and native configurations; shared account does not automatically mean shared login state |
| Combined app plus standalone apps | Both options | Feasible through shared packages, but adds substantial testing and distribution work |

Your architecture can support all three. I would launch the combined app first and add standalone frontends only when there is a clear audience for each. Separate apps controlling the same device's restrictions introduce coordination problems that a shared database alone cannot resolve.

## Proposed structure

An illustrative structure—not files that already exist:

```text
apps/
  mobile/                 combined app: navigation, branding, composition
  nashaat/                optional workout-only frontend later
  daris/                  optional study-only frontend later
  reader/                 optional reading-only frontend later
  planner/                optional tasks-only frontend later
packages/
  ui/                     tokens, typography, buttons, fields, dialogs
  identity/               account, session handling, profile
  api/                    typed backend access and generated database types
  economy/                wallet queries, reward and spend contracts
  blocking/               React Native bridge plus Swift/Kotlin modules
  workouts/               workout logic, hooks and reusable screens
  study/                  courses, materials, quizzes and study sessions
  reading/                library, progress, notes and reading sessions
  tasks/                  tasks, recurrence, completion and planning
  testing/                shared fixtures and test helpers
supabase/
  migrations/             one authoritative migration history
  functions/              privileged integrations and AI orchestration
  tests/                  permissions, accounting and concurrency checks
```

Expo supports workspace monorepos. Keep React Native and native dependencies aligned across applications; native modules cannot be duplicated within an app build. See [Expo monorepos](https://docs.expo.dev/guides/monorepos/).

Share components at three levels:

1. **Foundation:** colors, spacing, typography, accessibility behavior and basic controls.
2. **Common product features:** login, wallet, reward result, spend confirmation, profile and permission setup.
3. **Domain modules:** workout builder, quiz flow, reader and planner. Each frontend selects and composes the modules it needs.

Give branded apps their own theme and navigation. Do not force a quiz screen and a workout screen into one generic component just because both award minutes. Share the wallet and reward contract; preserve domain-specific interactions.

## One backend with explicit domain boundaries

Use one Supabase project per environment for the shared platform: development, staging and production. Within each environment, all frontends use the same identity and domain data. One backend does not require one giant table or service.

| Shared platform | Domain-specific data |
| --- | --- |
| Users, profiles, preferences | Workout plans, exercises and workout sessions |
| Wallet ledger, reward rules, spending | Subjects, materials, questions and study sessions |
| Entitlements and notification preferences | Books/documents, reading progress and annotations |
| Device registrations and blocking requests | Tasks, recurrence rules and completion records |

A user's completed activity should produce one uniquely identified completion event. The backend validates it, determines its reward and adds a ledger entry atomically. Frontends should not supply an arbitrary amount of earned credit.

For example, completing a study task from either Daris or the planner must refer to the same underlying task completion. Otherwise the same work could earn twice. A study session connected to a reading session also needs an explicit stacking rule.

Use separate identifiers for the user, source app, device and activity. The source app helps attribution; it must not act as a security boundary. Enforce access through database permissions and RLS. Supabase supports React Native clients and database-enforced user access: [React Native authentication](https://supabase.com/docs/guides/auth/quickstarts/react-native), [Supabase access controls](https://supabase.com/docs/guides/getting-started/the-supabase-way-to-build).

## Define the economy before implementing it

These are product decisions that affect the schema and every frontend:

- Is there one balance for all activities? I recommend yes.
- Are minutes spendable on every registered device, or allocated to one device at a time? A global wallet needs coordinated debits, while native unlocking remains device-specific.
- Do credits expire weekly? Daris currently calculates a weekly wallet; do not silently inherit that behavior across all domains.
- How are rewards determined? Workout completion, study quizzes, reading time and self-reported tasks provide different evidence of effort.
- Can related activities earn multiple rewards? Define overlap and daily limits.
- What happens offline? Initially, let users record work offline but require server validation before issuing spendable rewards.

Implement spending as an atomic server operation with an idempotency key. Then track the device's application of the unlock request. Include explicit pending, applied and failed states and a recovery policy. This addresses the Daris flow identified in the comparison, where the wallet can be deducted before native unlocking fails.

Avoid claiming that a database transaction and an OS blocking change are one atomic operation: they are separate systems and need retries and reconciliation.

## What survives the Flutter migration

| Existing work | Migration treatment |
| --- | --- |
| Database design and SQL | Reuse selected parts after resolving conflicting schemas and reward semantics |
| Domain rules | Port to TypeScript or backend functions, with behavior tests |
| Flutter widgets | Rebuild as React Native components |
| GetX controllers and Flutter view models | Port behavior into domain services and React hooks |
| Swift and Kotlin blocking code | Potentially reuse implementation, replace Flutter channel integration and validate native configuration |
| Existing tests | Reuse scenarios and expected outcomes; rewrite framework-specific tests |
| Design assets and tokens | Reuse where compatible with the new visual system |

Use Nashaat's domain boundaries as the architectural starting point. Daris contributes its study workflows and demo behavior. Neither repository should simply be copied wholesale into the new platform.

For Expo, use development builds with custom native modules. Expo Go is insufficient for your custom blocking implementation. A reusable Expo native module can live in the shared monorepo package. See [custom native code](https://docs.expo.dev/workflow/customizing/) and [reusable native modules](https://docs.expo.dev/more/create-expo-module/).

The first technical milestone should be a real-device proof: select apps, block them, spend minutes, unlock temporarily and relock after expiry, including after process termination. Verify both iOS and Android before rebuilding the entire UI. The existing native code is a starting point, not proof that the React Native integration will work unchanged.

## Migration sequence

1. **Define the shared contract.** Agree on wallet semantics, domain ownership, reward validation, task overlap and device behavior. Inventory both databases without copying production data into development.
2. **Prove the native integration.** Build a small Expo development app and bridge the existing blocking implementations. Resolve native capability and lifecycle issues early.
3. **Create the platform foundation.** Establish the monorepo, design tokens, auth, typed API layer, server-controlled wallet and database tests.
4. **Ship one complete workflow.** Port a narrow Nashaat workout flow through completion, reward, spend and native relocking. Use it to validate the architecture.
5. **Add Daris.** Port courses, materials and quizzes. Move provider credentials and privileged AI requests behind backend functions where needed.
6. **Add tasks and reading.** Start tasks with scheduling and completion; start reading with one content format. EPUB/PDF annotation, licensed catalogs, DRM and cross-device offline synchronization are separate expansions.
7. **Migrate accounts and release.** Reconcile user identities, balances, files and references; rehearse migration and rollback. Do not merge two SQL histories blindly. If existing users are in different Supabase projects, identity reconciliation requires a dedicated plan.
8. **Extract standalone frontends if justified.** Reuse the proven packages, with separate app identifiers, native configurations and release checks.

Flutter and React Native clients can coexist against a compatible backend during migration. Introduce versioned contracts and additive changes so a mobile release does not immediately break older installations.

## Effort and scope

This is a platform rebuild plus two new product domains. It is not primarily a UI framework conversion.

For planning only, a small experienced team of two or three engineers should think in several months: roughly 4–6 months for a focused combined-app MVP, assuming basic reading and tasks, reusable native blocking, no complex billing migration and limited offline support. Four polished standalone apps plus a combined app could take 6–12 months or longer. A solo implementation will usually require substantially more calendar time. These are judgment estimates, not a delivery commitment; the native proof and database inventory should precede a firm estimate.

The critical skills are React Native/TypeScript, PostgreSQL accounting and permissions, and native Swift/Kotlin integration. Test server idempotency and concurrent spending, domain completion rules, cross-app data access, and real-device blocking lifecycle behavior.

My recommended first release is **one Expo/React Native app with four experiences, one account, one wallet, one shared backend and reusable domain packages**. That produces the super app while preserving the option to ship distinct frontends later.

## Evidence and limits

This proposal builds on the local Daris/Nashaat source comparison and current official Expo/Supabase documentation. The reading and task products have not been specified or inspected. No implementation, migration, build or device test was performed for this proposal.
