# Bloom MVP and Product Roadmap

**Recommendation date:** 2026-11-15

**Scope:** Turn the supplied Bloom catalog into a staged product and technical plan. This is a roadmap, not a commitment to build every catalog item.

## Recommendation

Prove one loop first: **finish a workout, receive screen-time credits, unlock selected distractions for a bounded session, and see the same balance on the user's other devices.** Make Personal Mode the default. Exercise is the only credit-earning activity in the first MVP; family supervision is an optional follow-on, and Education, Reading, Tasks, Organization, AI, and subscriptions stay out of the first release.

Keep `bloom-exercise/` as the near-term canonical Bloom client. It already has an Expo/React Native iOS and Android app, a Tauri macOS shell, native blocking integrations, and the current Bloom database model. The root Flutter `lib/` app is a separate Nashaat implementation with overlapping workout, blocking, and wallet concepts. Freeze new feature work in the Flutter app until the team either migrates the specific pieces it needs into the canonical client or formally retires that shell. Do not maintain two clients that can award credits or enforce different versions of the same rules. Resolve the transitional app identifiers and wallet ownership before public distribution.

Treat platform blocking as a release capability, not a settings-screen feature. Run a small, private MVP pilot on the first mobile platform that passes its device and store-policy gates. Do not call Bloom cross-platform GA until the same account and wallet work across iOS, Android, and macOS and each platform passes its own blocking matrix. If a platform cannot pass, delay its launch or explicitly narrow its advertised coverage; do not imply equivalent enforcement.

## Current repository baseline

The repository is beyond a blank prototype, but it does not yet prove a reliable three-platform product. Evidence below comes from the current source tree and its recorded QA. The detailed macOS readiness report was last updated on 2026-11-12, so its installed-build state needs a fresh check before release decisions.

| Area | Exists now | Gap that affects the roadmap |
|---|---|---|
| Product clients | Root Flutter Nashaat app; separate `bloom-exercise/` Expo/React Native iOS and Android client plus Tauri macOS shell. | Two parallel clients and overlapping domain logic conflict with one maintained Bloom experience. The Bloom README says its iOS identifier is temporarily shared with the Flutter app. |
| Exercise | Plans, exercise library, workout logging/resume, weekly progress, reward settings, and server-side workout awards are connected. | This is the only developed earning lane. Keep it as the initial activity and tune its reward UX before adding more. |
| Wallet | Bloom migrations define a server-owned ledger, idempotent workout awards, balance RPCs, and serialized timed credit sessions/reservations. SQL fixtures cover account ownership, retries, credit rules, and concurrency cases. | The recorded macOS QA still lacks physical second-device proof. Its last live Easy-session recovery also failed because the local device key was unavailable. Automated SQL success does not prove native enforcement or cross-device behavior. |
| Family | Parent/child linking and selected supervision controls exist in Bloom Exercise. | Family setup and child-device enforcement need platform-specific validation. Keep Personal Mode complete without a parent account. |
| iOS blocking | Bloom has native Family Controls, Managed Settings, Device Activity, and local app/site selection. | Selection tokens are device-local; account-side app or domain strings cannot remotely select the same target on an iPhone. Confirm distribution entitlements for the app and every extension. |
| Android blocking | Native Usage Access and Accessibility service integration exists; website checks inspect supported browsers. | The service is user-enabled and may be stopped or disabled. Browser address inspection is not network-wide website blocking, and browser coverage varies. Play listing, declaration, and disclosure requirements are part of launch readiness. |
| macOS blocking | The Tauri client includes a Network Extension filter, background monitor, and app enforcement code. | The last recorded live assessment has a Brave Private website bypass, a prior app-hide failure, and incomplete end-to-end recovery. Source fixes or a configured filter do not count as a runtime pass. |
| Other catalog sections | Focus and screen-time controls exist in partial form. | Education, Reading, Tasks, a unified multi-activity dashboard, and Organization Mode are not complete product lanes. Defer them. |

Useful baseline references: [Bloom Exercise README](../bloom-exercise/README.md), [macOS readiness assessment](../bloom-exercise/docs/qa/12-FINAL-READINESS-ASSESSMENT.md), [gap and risk register](../bloom-exercise/docs/qa/04-GAP-AND-RISK-REGISTER.md), [Bloom migrations](../supabase/migrations/), and the legacy [Nashaat architecture](structure/architecture.md).

## MVP definition

### In scope

- One Bloom account with Personal Mode available immediately; one user can sign in on multiple devices.
- One weekly exercise goal, a small exercise library, and workout plan/log/resume flows already present in Bloom Exercise.
- One deterministic earning rule with a reasonable weekly cap. A completed workout may award once; retries and sync must not create a second award.
- One account-level wallet backed by the Bloom server ledger. Show earned, available, reserved, spent, and expired credit clearly.
- One bounded unlock session at a time per account. Reserve the requested amount on the server before a device applies its local restriction changes. The session is tied to the requesting device and cannot be replayed on another device.
- Device-local app and website target selection, with a clear list of supported targets and a truthful Ready, Degraded, or Off state.
- Cross-device sync for goals, completed workouts, reward history, balance, and account-level blocking rules. Platform-specific target selections and permissions remain device-specific where the OS requires that.
- A simple home view: today's workout goal, last completed session, available credits, and blocking/session status.

### Out of scope for this MVP

Education, Reading, a general-purpose task manager, Organization Mode, AI coaching/generation, camera-based exercise verification, social leaderboards, subscription billing, complex credit trading between family members, and broad analytics. Do not create separate credits for Focus time when Focus is attached to the same workout or another future activity.

### MVP success criteria

These are proposed pilot gates, not facts from existing analytics. Revisit the product thresholds after a small baseline cohort; the accounting and device-safety gates are release requirements.

| Measure | Exit target |
|---|---|
| First value | At least 70% of pilot sign-ups complete a workout and see their first credit award within 7 days. |
| Habit signal | At least 25% of the first cohort is active in week 4. Track completed workouts per active user per week as the primary behavior metric. |
| Wallet integrity | No duplicate grant, double debit, negative available balance, or cross-account access in retry, simultaneous request, sign-out, and reconnect scenarios. Verify on the server and on at least two physical devices. |
| Blocking honesty | Every advertised target in the per-platform support list passes 20 repeated block/control attempts on physical devices; zero essential-app false blocks. Record OS version, app version, browser, permission state, restart, and offline/reconnect cases. |
| Recovery | After permission revocation, process termination, restart, and network loss, Bloom reports its true state and gives a working recovery path. Never display “active” based only on a saved preference. |
| Cross-device behavior | One account sees the same confirmed activity and wallet on two physical devices. Racing unlock attempts yield one reservation, never two spends. Extend this to all three platforms before cross-platform GA. |

Screen-time reduction is not an MVP success claim. Bloom can record credits and bounded access sessions, but those are not equivalent to universally accurate foreground-app usage or attention measurement. Add a screen-time-reduction target only after each platform can collect comparable, user-authorized baseline data.

## Platform capabilities and constraints

| Platform | Practical MVP surface | Constraint and release gate |
|---|---|---|
| **iOS** | Use Family Controls / Managed Settings for selected app, category, and domain shields; Device Activity for supported schedules and monitor events. | Apple requires the Family Controls distribution entitlement for the app and Screen Time extensions. A person can authorize Individual mode on-device; parent authorization for a child uses Apple's Family Sharing flow. The picker returns privacy-preserving device-local selections, so remote account rules cannot directly select the same apps/sites. Test actual shield start/end, restart recovery, and browser coverage on signed devices. See [Family Controls](https://developer.apple.com/documentation/familycontrols), [individual authorization](https://developer.apple.com/documentation/familycontrols/authorizationcenter/requestauthorization%28for%3A%29), and [entitlement request](https://developer.apple.com/documentation/familycontrols/requesting-the-family-controls-entitlement). |
| **Android** | Keep app blocking as an explicitly user-enabled, foreground-detection flow. Start with a documented supported-browser list for website checks. | A normal consumer app cannot use DevicePolicyManager package suspension unless it has a qualifying device/profile-owner role. Bloom's Accessibility service is subject to Play declaration, listing, disclosure, and consent rules; users can disable it and the OS can stop it. Do not label browser UI inspection as universal website blocking. See [Accessibility API policy](https://support.google.com/googleplay/android-developer/answer/10964491), [Play policy](https://support.google.com/googleplay/android-developer/answer/18265346), and [DevicePolicyManager](https://developer.android.com/reference/android/app/admin/DevicePolicyManager). |
| **macOS** | Use the Tauri shell and a signed Network Extension content filter for website rules. Treat app-level enforcement as a separate feature with a separate pass gate. | Network Extensions are system extensions and need the correct capability/provisioning for distribution. Endpoint Security can block system events but requires a separate Apple entitlement; do not make it a roadmap dependency until approval and distribution viability are confirmed. A running extension or “configured” status does not prove target traffic is blocked. Reproduce and close the recorded Brave bypass, test app enforcement and recovery on the current signed/notarized build, and verify target/control sites across restart and sleep/wake. See [Network Extension](https://developer.apple.com/documentation/networkextension), [NEFilterDataProvider](https://developer.apple.com/documentation/networkextension/nefilterdataprovider), and [System Extensions / Endpoint Security](https://developer.apple.com/system-extensions/). |

Flutter can build a macOS desktop client, but that alone does not provide OS blocking. Bloom already has substantially more native enforcement work in the Expo/Tauri tree. The stack decision is therefore about maintaining one product surface and preserving native work, not about assuming a cross-platform UI toolkit makes blocking portable. See [Flutter macOS support](https://docs.flutter.dev/platform-integration/macos/setup).

## Wallet and synchronization contract

Keep the wallet server-authoritative. The current Bloom ledger and SQL functions are a useful foundation; preserve and close their end-to-end gaps rather than introducing a client-maintained balance.

1. A workout completion has a stable activity/session ID. The server validates eligibility and writes one immutable earning entry with a unique idempotency key.
2. A device asks the server to start an unlock session. One atomic operation locks the user's account state, checks the available balance, reserves credits, records a request ID and device key, and rejects another active reservation.
3. The platform adapter applies only the policy and targets selected on that device. It reports applied, degraded, or failed status; a backend preference is not evidence of local enforcement.
4. The server settles the reservation once. Retries with the same request return the same result. If a device never reconnects, the reservation stays unavailable until the server-side expiration/recovery policy resolves it.
5. All clients refresh from the server ledger/balance. A cached value may be displayed as stale, but cannot authorize another spend.

Offline activities may be saved locally with a stable ID and shown as **Pending**. They earn credits only after server acceptance. Do not allow new offline credit spending in the MVP. A later offline mode needs bounded, device-specific server leases and explicit settlement/replay rules; an unbounded cached balance cannot prevent two disconnected devices from spending the same credits.

Keep family wallets per person. A parent-child link grants only the permissions and progress the parent is allowed to see; it does not merge balances or expose unrelated personal activity. Do not use one shared login for a household.

## Main user journeys

### Independent user (MVP)

1. Create an account; Personal Mode is the default and does not require a family invitation.
2. Choose an exercise goal and a credit rule. Bloom explains the target app/site permissions before opening system settings.
3. Select targets separately on each device and see which protections that device can actually enforce.
4. Complete and log a workout. Bloom confirms the server award and updates the wallet.
5. Start an unlock session on one device. Bloom reserves credits, applies that device's rules, ends access at the session deadline, and refreshes the same balance on the other devices.
6. Review weekly workouts, earned/spent credits, and any device whose protection is degraded.

### Supervised child account (family beta, optional)

1. A parent creates a family link and invites or pairs the child's Bloom account. The child account remains a separate identity and wallet.
2. Parent and child see what is shared. The parent assigns an exercise goal and may require approval for submitted workouts; the child keeps independent personal activity private by default.
3. The child selects locally enforceable targets and grants the platform permission. On iOS, the parent/child authorization must follow Apple's Family Sharing flow; on Android, Bloom explains the Accessibility and Usage Access controls.
4. The child completes the activity. Bloom awards credits after the configured confirmation/approval rule passes.
5. The child spends credits on their own device. The parent sees only permitted progress and can update family rules; failures and stale rules are visible to both.

Do not ship Family Mode as if it can remotely force the same rule on every OS. In particular, iOS app/domain selections are device-local, Android service access is user-controlled, and macOS app enforcement remains separately gated.

## Phased roadmap

| Phase | Work and milestone | Exit criteria |
|---|---|---|
| **0. Consolidate and prove platform feasibility** | Name one canonical client and product identity; settle app/bundle identifiers; identify which legacy Flutter features are migrated or retired. Freeze new domains. On physical devices, run a minimum target/control blocking spike on iOS, Android, and macOS; confirm Apple entitlements, Play policy path, macOS signing/notarization, and permission recovery. | A signed capability matrix says exactly what app/site blocking is supported on each OS. One client and one wallet contract own credits. No platform is labeled launch-ready from source inspection alone. Apple review/entitlement wait is tracked separately from engineering work. |
| **1. Personal exercise MVP pilot** | Complete the single workout → award → wallet → timed unlock loop using the existing Bloom Exercise implementation. Keep the pilot small and personal-mode first. Reuse workout plans, activity logs, credit settings, and server ledger; fix retry, reservation recovery, and truthful device-state gaps. Begin on the mobile platform that passes Phase 0 first. | Pilot success criteria above are met. Offline activity is pending until accepted; offline unlock spending is off. The pilot's supported device/browser list is explicit. |
| **2. Mobile cross-device and family beta** | Validate one account across physical iOS and Android devices, including simultaneous unlock attempts, sign-out/account switch, network loss, permission loss, and recovery. Add the optional parent-child journey only after personal mode is stable. Keep household balances separate. | No double-award or double-spend in adversarial concurrency runs; two-device physical sync passes; parent/child consent, permissions, data visibility, and recovery pass on each supported mobile platform. |
| **3. macOS product release gate** | Bring the Tauri client and native filter/monitor to a signed, notarized release state. Re-run Brave target/control, Safari, app enforcement, sleep/wake, restart, stale policy, disconnected network, and recovery cases on that exact artifact. Decide the app-blocking approach separately from website filtering. | No target bypass in the advertised macOS matrix and no essential app is blocked. App and website state is confirmed by observed enforcement, not enabled preferences. If app enforcement cannot pass, macOS is not advertised as providing app blocking. All three platforms pass before cross-platform GA. |
| **4. Expand activities one lane at a time** | Add Education first, then Reading, then Tasks only after the shared completion/reward contract is proven. Make Focus a mode attached to an activity; it never creates duplicate reward for the same work. Add broader calendar and progress views after each lane has real usage. | Each lane has clear completion evidence, server-side idempotency, caps, recovery, and a measured retention benefit. Remove lanes that do not improve activation or week-four retention. |
| **5. Organization and advanced growth** | Consider Organization Mode, group assignments, AI help, social challenges, and subscription features only after Personal Mode retains users and Family Mode has a privacy/permissions review. | Each addition has a named user need, consent model, unit economics, and proof it does not weaken blocking or the core habit loop. |

**Planning estimate:** Phase 0 and a scoped exercise pilot are small-to-medium engineering efforts; mobile cross-device hardening is medium; macOS release readiness is the largest and least predictable work because it depends on native enforcement, signing, entitlements, and physical-device results. Re-estimate after Phase 0. Do not attach calendar dates to Apple/Play reviews or call a code-complete build a launch until device gates pass.

## Main risks and decisions

| Risk | Impact | Mitigation / decision |
|---|---|---|
| Two app implementations and overlapping identifiers | Split product experience, duplicate features, release/signing conflicts, and divergent reward rules. | Make Bloom Exercise canonical short term; resolve app identity and explicitly migrate or retire the Flutter shell before launch. |
| OS blocking differs by platform | Users may bypass restrictions or assume broader coverage than the OS permits. | Publish per-platform coverage; test real devices; show degraded state; gate each launch on target/control and recovery tests. |
| macOS enforcement has known live failures | Breaks the central reward promise on a required platform. | Keep macOS out of GA until the current signed artifact passes the recorded Brave, app enforcement, and recovery failures. |
| Android Accessibility policy and service reliability | Store rejection, user disablement, OEM process termination, or incomplete website coverage. | Treat access as optional and user-controlled; complete declaration/disclosure; scope browser support narrowly; never imply device-owner powers. |
| iOS local target tokens and entitlement review | Parent/account rules cannot silently select remote device targets; distribution may be blocked. | Request/check entitlements early; let the device owner select targets locally; model rules as account-level intent plus device-specific selections. |
| Shared balance race/offline spending | Double spending, lost reservations, or trust-damaging corrections. | Keep atomic server reservations and immutable ledger; no offline spending at MVP; test physical two-device races and request recovery. |
| Reward gaming or duplicate activity | Inflated credits undermine blocking and fairness. | Start with one activity type, transparent caps, stable IDs, idempotent server awards, and no camera/AI verification requirement. |
| Premature breadth | Delays proving that earning and unlocking changes habits. | Hold Education, Reading, Tasks, Organization, AI, social, and billing until the exercise loop meets pilot retention goals. |

## Sources checked

- Repository: [Bloom Exercise implementation and limitations](../bloom-exercise/README.md); [macOS readiness assessment](../bloom-exercise/docs/qa/12-FINAL-READINESS-ASSESSMENT.md); [macOS risk register](../bloom-exercise/docs/qa/04-GAP-AND-RISK-REGISTER.md); [Bloom credit migrations](../supabase/migrations/).
- Apple: [Family Controls](https://developer.apple.com/documentation/familycontrols), [requesting Family Controls distribution entitlement](https://developer.apple.com/documentation/familycontrols/requesting-the-family-controls-entitlement), [Network Extension](https://developer.apple.com/documentation/networkextension), [Endpoint Security entitlement](https://developer.apple.com/system-extensions/).
- Android: [Accessibility API policy](https://support.google.com/googleplay/android-developer/answer/10964491), [Developer Program Policy](https://support.google.com/googleplay/android-developer/answer/18265346), [DevicePolicyManager](https://developer.android.com/reference/android/app/admin/DevicePolicyManager).
- Flutter: [macOS platform setup](https://docs.flutter.dev/platform-integration/macos/setup).
