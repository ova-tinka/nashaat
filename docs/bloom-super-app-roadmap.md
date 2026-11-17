# Bloom Four-Pillar Super App Roadmap

**Recommendation date:** 2026-11-15

This roadmap treats Exercise, Education, Reading, and Tasks as equal first-class parts of Bloom. Focus and Screen Time connect the four areas; they are not separate ways to earn duplicate credits. The goal is a useful, connected super app with a small but complete experience in every pillar, followed by deeper tools over time.

## Product direction

Bloom's initial MVP should make all four pillars usable from one account, one home, one activity history, one credit wallet, and one device protection setup. Each pillar gets one meaningful end-to-end activity flow at launch. Depth can differ according to what users need and what the pilot shows.

The common loop is:

> Choose a meaningful activity in any pillar → complete and record it → earn credits once → spend them on supported apps or websites → see progress and wallet updates on every connected device.

Keep **Personal Mode complete and the default**. Supervised Family Mode is optional. Organization Mode is a later extension. Avoid making account setup depend on a parent, school, or team.

## What the repository already tells us

The repository root now contains the Expo/React Native clients for iOS and Android and the Tauri macOS shell. The Flutter Nashaat client has been archived outside the repository at `../old/nashaat-flutter`. The Bloom code already contains exercise planning/logging, reward settings, a server-owned credit ledger, family linking, and native blocking integrations. Education, Reading, and Tasks still need their first product flows.

The implementation also has platform risks that must stay visible: iOS target selections are device-local; Android blocking relies on user-enabled access and a supported-browser list; and the last detailed macOS readiness report records live blocking failures. The report is dated 2026-11-12, so retest the current signed artifact before treating its installed-build results as current.

Use the repository-root Bloom app as the canonical product shell and organize its navigation around four peer pillars. Keep one wallet contract and one product identity. Existing bundle identifiers and store entitlements still need a deliberate release review; do not change identifiers as a side effect of moving files.

Baseline references: [Bloom README](../README.md), [macOS readiness assessment](qa/12-FINAL-READINESS-ASSESSMENT.md), [risk register](qa/04-GAP-AND-RISK-REGISTER.md), [Bloom migrations](../supabase/migrations/), and [Bloom architecture](structure/architecture.md).

## Smallest useful four-pillar MVP

The MVP is four complete, intentionally small vertical slices sharing the same activity and reward system.

| Pillar | MVP experience | Completion and reward rule |
|---|---|---|
| **Exercise** | Browse a starter exercise library, follow or create a simple workout plan, and log a session. | User confirms the completed session; server applies a transparent per-session and weekly cap. Existing workout flows can be reused. |
| **Education** | Add a subject or course, set a weekly goal, and record a focused study session against a lesson or assignment. | A timer alone does not grant credits. User records the completed lesson or assignment; optional quiz/verification tools come later. |
| **Reading** | Add a book or article, start/end a reading session, and record pages or chapter progress. | Award from a session or milestone once, with sensible daily limits. Recommendations, reviews, and challenges come later. |
| **Tasks** | Create personal tasks with due dates and simple checklists; review a daily list and mark eligible work complete. | Each task occurrence has a stable ID and configured reward. Recurring tasks cannot replay an earlier occurrence's credit. |

Shared MVP pieces:

- One onboarding flow that helps users choose goals in any or all four areas. No pillar is mandatory.
- One home dashboard showing the four pillars, today's chosen goals, recent activity, current Focus/blocking status, and available credits.
- A simple calendar/history view that can show workouts, study sessions, reading, and tasks together.
- A shared Focus timer that can attach to any activity. It can enforce restrictions and record focused time, but it never creates a second reward for the same activity.
- One account-wide wallet. Activity completion may create one earning entry; spending reserves credits before the device unlocks a selected target.
- App and website blocking surfaced from the same Screen Time area, with platform-specific capabilities and status stated plainly.
- Self-confirmation as the default activity verification. No computer vision, AI grading, photo requirements, or surveillance in the first MVP.

**Not in the first MVP:** advanced coaching, AI explanations, generated study plans, quizzes and flashcards at scale, reading discovery, shared task assignment, social leaderboards, subscriptions, Organization Mode, and advanced cross-pillar analytics. Add them only after the four basic flows and shared reward loop demonstrate use.

## Shared activity and reward model

Do not build four disconnected credit systems. Each pillar should emit a common completion record with: account ID, activity type, stable activity/occurrence ID, start and completion time, user confirmation or approval state, reward-rule version, and an idempotency key. Store only the details needed for that activity; for example, a reading record needs book and page progress, while a task may need its checklist state.

The server validates eligibility, caps, and approval state, then writes to one immutable ledger. A completion can be retried or synced from offline without earning twice. Parent approval, when enabled, leaves the reward pending until approved. Use a global earning cap and clear activity-specific rates so switching pillars cannot bypass limits.

Focus and rewards follow one rule: **an activity can earn once**. If a study session uses Focus, the study completion earns; Focus does not also mint credits. If a task is linked to a focus session, completing the task remains the reward event.

Offline activity can be saved with a stable ID and marked Pending until the server confirms it. Do not allow new offline credit spending in the MVP. Later offline spending needs a bounded, device-specific server lease and replay-safe settlement; a cached balance cannot safely authorize two disconnected devices.

## Platform capability gates

| Platform | MVP approach | Constraint and launch gate |
|---|---|---|
| **iOS** | Use Family Controls, Managed Settings, and Device Activity for supported app/site shields and schedules. Users select targets on each device. | Apple requires the Family Controls distribution entitlement for the app and Screen Time extensions. Individual authorization is local; child authorization follows Apple Family Sharing. Selected targets are privacy-preserving local tokens, so account rules cannot silently map to identical targets on another iPhone. Verify signed-device authorization, shield start/end, restart, and recovery. See [Family Controls](https://developer.apple.com/documentation/familycontrols) and [entitlement request](https://developer.apple.com/documentation/familycontrols/requesting-the-family-controls-entitlement). |
| **Android** | Use clearly disclosed, user-enabled Usage Access and Accessibility integration for supported app blocking; list exact supported browsers for website checks. | A regular consumer app cannot suspend arbitrary packages with DevicePolicyManager unless it has a qualifying device/profile-owner role. Play requires Accessibility use to be declared and disclosed with consent; users can disable access and Android/OEM lifecycle behavior can interrupt it. Browser address inspection is not universal network blocking. See [Google Play Accessibility policy](https://support.google.com/googleplay/android-developer/answer/10964491) and [DevicePolicyManager](https://developer.android.com/reference/android/app/admin/DevicePolicyManager). |
| **macOS** | Use the Tauri client and Network Extension content filter for website rules. Treat app blocking as a separate capability with its own gate. | Network Extension distribution needs the matching capability and signing setup. Endpoint Security can block system events but requires a separate Apple entitlement; do not depend on it until approval and distribution are proven. Retest the recorded Brave bypass, app-enforcement failure, and recovery issues on the current signed/notarized artifact. A configured filter does not prove traffic is being blocked. See [Network Extension](https://developer.apple.com/documentation/networkextension), [NEFilterDataProvider](https://developer.apple.com/documentation/networkextension/nefilterdataprovider), and [Apple System Extensions](https://developer.apple.com/system-extensions/). |

One product does not mean identical enforcement on every OS. Before each release, show the user which selected targets are protected, which permissions are missing, and how to recover. Do not advertise a target or mode until repeated physical-device target/control tests pass.

## User journeys

### Personal Mode

1. Create an account and choose goals for any combination of Exercise, Education, Reading, and Tasks.
2. Set a simple weekly target for each chosen pillar and select supported apps/sites to restrict on each device.
3. Complete an activity: log a workout, finish a study session and lesson, record reading progress, or complete an eligible task.
4. Bloom confirms the completion, grants credits once, and updates the shared wallet.
5. Start a bounded unlock session on one device. Bloom reserves credits, applies local rules, ends access at the deadline, and refreshes other devices.
6. Review all four kinds of progress together and resolve any device protection warning.

### Supervised Family Mode

1. A parent creates a family link and invites or pairs the child's separate Bloom account.
2. Parent and child choose what is shared. The parent may assign goals and require approval for selected activities; unrelated personal activity stays private by default.
3. The child chooses targets locally and grants device permissions. iOS uses Apple's parent/child authorization flow; Android explains its user-controlled access settings.
4. The child completes any eligible activity in the four pillars. Credits remain pending if that activity requires parent approval, then enter the child's own wallet.
5. The child spends credits on their device. The parent sees only permitted progress and can adjust authorized rules; both see stale or degraded blocking status.

Family Mode extends Personal Mode and is not required for the personal journey. Organization accounts and team reporting are later work.

## Phases, milestones, and success criteria

| Phase | Scope and milestone | Exit criteria |
|---|---|---|
| **0. Unify the product foundation** | Complete the root app consolidation; settle Bloom identity and app IDs; define one activity, reward, ledger, account, and device-policy contract. Build a physical-device blocking matrix for iOS, Android, and macOS while requesting/checking required entitlements and store-policy requirements. | One navigation shell exposes four peer pillars. No second client can issue rewards. A capability matrix documents exact app/site coverage, permission requirements, signing requirements, and open failures for each OS. |
| **1. Four-pillar MVP** | Deliver one end-to-end activity flow in each pillar, shared goals/history/dashboard, Focus attachment, and one wallet/reward engine. Reuse and adapt the existing exercise implementation; create the smallest useful Education, Reading, and Tasks slices in the same app. | A Personal Mode user can earn credits through any of the four pillars and sees each completed activity in one history. Retry, offline sync, limits, and linked Focus do not create duplicate awards. |
| **2. Shared Screen Time and platform beta** | Complete atomic wallet reservation/settlement, two-device sync, native app/site enforcement, recovery, permission status, and store/distribution readiness. Add the optional family beta after Personal Mode works. | No double award or double spend in concurrency and retry checks; two physical devices show one consistent wallet; one racing unlock is accepted. Every advertised platform target passes 20 repeated block/control attempts with no essential-app false blocks. Permission loss, restart, offline/reconnect, and session expiry show truthful status and recovery. |
| **3. Cross-platform general availability** | Release the same product identity and account experience on iOS, Android, and macOS after the relevant native artifacts pass their platform gates. | All three platforms meet the support matrix on signed builds. Cross-platform physical tests include an account earning on one device and spending on another. No known blocking bypass remains in the advertised coverage. |
| **4. Deepen the four pillars** | Add richer exercise plans, course tools, quizzes/flashcards, book discovery, recurring projects, and analytics according to pilot use. Add Family Mode broadly and then consider Organization Mode. | Additions improve activation or sustained use without weakening the shared activity/reward rules. Each new verification method is optional, transparent, and proportionate. |

The product targets below are proposed pilot hypotheses, not current performance claims. Recalibrate after a baseline cohort:

- At least 70% of new users complete an activity in one of the four pillars and receive their first confirmed credit within seven days.
- At least 40% of weekly active users use two or more pillars by the end of week four; this directly tests whether Bloom works as a super app rather than four isolated tools.
- At least 25% of the first cohort remains active in week four. Track weekly completion separately for all four pillars so one area cannot hide another's failure.
- For wallet and blocking, require zero duplicate rewards, double spends, negative balances, and essential-app false blocks in the release test matrix. Product growth targets never override these safety gates.

Do not claim screen-time reduction from allowance countdowns alone. First establish comparable, user-authorized usage baselines on each platform; otherwise report earned credits and unlock sessions as their own measures.

## Main risks and decisions

| Risk | Response |
|---|---|
| Super-app ambition turns into four large feature builds | Define one useful completion journey per pillar. Defer advanced depth until users show demand. |
| Exercise has much more code than the other pillars | Reuse it as a technical reference, but give all four pillars top-level navigation, onboarding goals, dashboard presence, event/reward support, and MVP success measures. |
| Multiple clients drift | Keep one canonical client and one reward contract, with four peer pillars across supported clients. |
| App/site blocking differs by OS | Maintain per-platform coverage and permission states; release only tested target combinations; never call best-effort coverage universal. |
| macOS blocker failures undermine the core promise | Treat the latest known live failures as open until a fresh notarized build passes. Do not infer runtime reliability from source changes. |
| More earning paths create reward abuse or duplicate credits | Stable activity IDs, server-side idempotency, shared caps, one immutable ledger, pending approval state, and physical multi-device race testing. |
| Family supervision harms personal privacy | Personal Mode works independently; child account is separate; sharing is explicit and limited to authorized progress. |

## Sources checked

- Repository: [Bloom implementation and current limits](../README.md), [macOS readiness assessment](qa/12-FINAL-READINESS-ASSESSMENT.md), [risk register](qa/04-GAP-AND-RISK-REGISTER.md), [Bloom migrations](../supabase/migrations/).
- Apple: [Family Controls](https://developer.apple.com/documentation/familycontrols), [Family Controls entitlement request](https://developer.apple.com/documentation/familycontrols/requesting-the-family-controls-entitlement), [Network Extension](https://developer.apple.com/documentation/networkextension), [System Extensions and Endpoint Security](https://developer.apple.com/system-extensions/).
- Android: [Google Play Accessibility API policy](https://support.google.com/googleplay/android-developer/answer/10964491), [DevicePolicyManager](https://developer.android.com/reference/android/app/admin/DevicePolicyManager).
