# Bloom — Milestone 2: Commercial Readiness Report

**Date:** 2026-11-28 · **Target Launch:** Monday, November 30, 2026 · **Baseline:** Milestone 1 (`041b27c`) + Milestone 2 updates

---

## 1. Commercial Readiness Executive Summary

Bloom's repository engineering for Milestone 2 is substantially complete: paid-only billing infrastructure (RevenueCat + Tap + server-side PostgreSQL guards), bounded offline entitlement caching, 7-step persisted onboarding, password recovery (`reset-password.tsx`), account export/deletion with store-cancellation disclosures, legal/privacy/terms screen (`legal.tsx`), PII-scrubbed Sentry crash monitoring (`src/lib/sentry.ts` + Edge helper), child-safe Amplitude funnel analytics (`src/lib/analytics.ts`), and cross-platform macOS/iOS/Android Focus enforcement are all implemented and verified at the TypeScript, lint, unit-test, Deno, and Rust levels.

**Commercial Go/No-Go Today:** **NO-GO for public launch until the Owner-Action Register below is executed** (specifically: freeing disk space for Xcode iOS archiving, configuring live RevenueCat/App Store/Google Play/Tap products & webhooks, supplying Sentry/Amplitude/Supabase env keys, executing physical-device sandbox purchases, and filling in legal entity/support contact details).

---

## 2. RevenueCat Integration Status

| Area | Status | Evidence |
| --- | --- | --- |
| SDK Installation | Installed (`react-native-purchases@11.1.0`, `react-native-purchases-ui@11.1.0`) | [package.json](../package.json) |
| Platform Configuration | Keyed via `EXPO_PUBLIC_REVENUECAT_IOS_KEY` / `EXPO_PUBLIC_REVENUECAT_ANDROID_KEY` | [store-billing.native.ts](../src/lib/store-billing.native.ts) |
| Customer Identity | Bound to Bloom `profileId` via `Purchases.configure` / `logIn`, cleared on `logOut` | [auth.tsx](../src/lib/auth.tsx), [_layout.tsx](../src/app/(app)/_layout.tsx), [close-device-access.ts](../src/lib/close-device-access.ts) |
| Offerings & Pricing | Localized prices, Apple intro/win-back eligibility, Play base plans + `bloom-intro` tag | [store-billing.native.ts](../src/lib/store-billing.native.ts), [subscription.tsx](../src/app/(app)/subscription.tsx) |
| Backend Sync & Webhooks | Bearer-verified webhook (`/webhook`) + authenticated customer sync (`/sync`) + `bloom_apply_revenuecat` RPC | [bloom-revenuecat/index.ts](../supabase/functions/bloom-revenuecat/index.ts), [revenuecat-billing.ts](../supabase/functions/_shared/revenuecat-billing.ts) |
| Live Keys & Sandbox | **Owner Action Required** — `.env` has no `EXPO_PUBLIC_REVENUECAT_*` keys and no sandbox transaction has run | [billing-verification.md](billing-verification.md) |

---

## 3. Subscription Product & Entitlement Configuration Matrix

Bloom enforces one paid subscription across all 4 pillars (`Basic`/`Premium` × `Individual`/`Household` × `week`/`month`/`year` = 12 products per provider: `app_store`, `play_store`, `tap`). No free tier or free trial is exposed.
- Server-side access check: `bloom_private.billing_usage_balance` + `bloom_guard_new_activity` triggers ([20261127133443_bloom_billing_access.sql](../supabase/migrations/20261127133443_bloom_billing_access.sql)).
- Client entitlement cache: 24-hour max bounded offline cache in [billing-context.tsx](../src/lib/billing-context.tsx) that expires immediately at `plan.period_end` or `enforcement_at`.

---

## 4. Subscription Lifecycle & 5. Cross-Platform Entitlement Test Results

- **Automated Deno billing tests:** `4/4` passed (`revenuecat` ownership/aliases/Play SKU mapping + `tap` currency/webhook verification in `supabase/functions/_shared/billing_test.ts`).
- **SQL & concurrency billing fixtures:** Previously verified in `tests/billing.sql`, `tests/billing-rollout.sql`, `tests/billing-play-offers.sql`, `tests/billing-concurrency.py` (requires Docker/Postgres to re-run locally).
- **Physical-device sandbox purchases & cross-platform restore (iOS ↔ Android ↔ macOS ↔ Web):** **Blocked — Owner Action Required** (needs RevenueCat/App Store/Play sandbox setup + physical device).

---

## 6. Completed Onboarding Flow Summary

- Implemented per-profile persisted 7-step flow in [src/lib/onboarding.ts](../src/lib/onboarding.ts) & [src/app/(app)/onboarding.tsx](../src/app/(app)/onboarding.tsx): Welcome → Goals → Usage Mode → Earned Screen Time → Contextual OS Permissions → Paid Subscription → Recommended Real First Activity.
- Child accounts bypass onboarding automatically; adult progress persists per `profileId` across restarts and offline periods; permissions and setup remain revisitable from Settings.

---

## 7. Account Management Implementation Status

- **Registration, Login, Email Verification:** Verified in [sign-in.tsx](../src/app/sign-in.tsx) & [auth.tsx](../src/lib/auth.tsx).
- **Password Recovery:** Implemented in [sign-in.tsx](../src/app/sign-in.tsx) (`resetPasswordForEmail`) + [reset-password.tsx](../src/app/reset-password.tsx) (`updateUser`, expired/invalid link handling) + `bloomexercise://reset-password` deep-link support in [lib.rs](../src-tauri/src/lib.rs).
- **Logout:** Calls `closeDeviceAccess` (closes native usage sessions & RevenueCat `logOut`) + `resetAnalytics()` + `supabase.auth.signOut()`.
- **Account Deletion & Export:** Verified in [account.tsx](../src/app/(app)/account.tsx), now with explicit warning that account deletion does not cancel Apple/Google subscriptions and direct links to `/subscription` & `/legal`.

---

## 8. Legal and Privacy Content Status

- In-app route [src/app/legal.tsx](../src/app/legal.tsx) accessible both signed-out and signed-in (linked from Sign In, Paywall, Account Deletion, and Settings).
- Full drafts and processor inventory in [docs/legal-privacy-drafts.md](legal-privacy-drafts.md) with `[OWNER REVIEW REQUIRED]` markers for legal entity name, address, support contact, external web deletion URL, and minor-data legal review.

---

## 9. Sentry & 10. Amplitude Verification Status

- **Sentry ([src/lib/sentry.ts](../src/lib/sentry.ts), [supabase/functions/_shared/sentry.ts](../supabase/functions/_shared/sentry.ts)):** Zero-dependency Sentry Envelope client with `ErrorBoundary`, global handlers, and PII scrubbing (`scrubSensitiveData`). Unit-tested DSN parsing & scrubbing. Live delivery pending `EXPO_PUBLIC_SENTRY_DSN` / `BLOOM_SENTRY_DSN`.
- **Amplitude ([src/lib/analytics.ts](../src/lib/analytics.ts)):** Centralized allowlisted event emitter covering all acquisition, commercial, core product, and account events. Strictly disables tracking for child accounts (`childProfile: true`) and resets identity on logout. Live delivery pending `EXPO_PUBLIC_AMPLITUDE_API_KEY`.

---

## 11. API Spending Controls & 12. Disaster Recovery

- Documented and verified in [docs/disaster-recovery-and-controls.md](disaster-recovery-and-controls.md).

---

## 13. Modified & New Files Summary

- **New:** `src/lib/sentry.ts`, `src/lib/analytics.ts`, `src/lib/onboarding.ts`, `src/app/reset-password.tsx`, `src/app/legal.tsx`, `src/app/(app)/onboarding.tsx`, `supabase/functions/_shared/sentry.ts`, `tests/onboarding.test.mjs`, `tests/sentry-analytics.test.mjs`, `docs/legal-privacy-drafts.md`, `docs/disaster-recovery-and-controls.md`, `docs/milestone-2-commercial-readiness.md`.
- **Modified:** `src/lib/auth.tsx`, `src/lib/billing-context.tsx`, `src/app/_layout.tsx`, `src/app/sign-in.tsx`, `src/app/(app)/_layout.tsx`, `src/app/(app)/subscription.tsx`, `src/app/(app)/account.tsx`, `src/app/(app)/(tabs)/settings.tsx`, `src-tauri/src/lib.rs`, `supabase/functions/bloom-revenuecat/index.ts`, `.env.example`.

---

## 14. Database Migration Summary

- No new migrations added in Milestone 2; Milestone 1 (`20261128000001_bloom_milestone1_stabilization.sql`) and Billing migrations (`20261127132108`–`20261127135532`) remain intact.

---

## 15. Remaining Verified Defects & 16. Deferred Items

- **Host disk space (`407 MiB` free):** Blocks Xcode iOS Release archive (`RNReanimated` `No space left on device`) and Tauri macOS release rebuilds until space is freed.
- **Deferred (P2/P3):** Direct macOS in-app checkout (macOS directs users to Bloom Web / iOS / Android to subscribe, then activates via synced Supabase account), recurring task occurrences, scanned-PDF OCR.

---

## 17. Owner-Action Register (Blocking Commercial Launch)

| # | Service | Exact Action Required | Blocks Launch? | Verification |
| --- | --- | --- | --- | --- |
| 1 | Local Mac Storage | Free >= 10–15 GB disk space (empty Trash / clean Xcode `DerivedData`) | **Yes (Builds)** | `df -h /System/Volumes/Data` shows >= 10G free; Xcode Archive succeeds |
| 2 | App Store Connect & Play Console | Create 12 subscription products (`Basic`/`Premium` × `Individual`/`Household` × `W/M/Y`), set localized prices & tax/banking | **Yes (P0)** | Products appear in RevenueCat Offerings |
| 3 | RevenueCat | Map all 12 iOS/Android products, configure webhook to `/functions/v1/bloom-revenuecat/webhook`, set `EXPO_PUBLIC_REVENUECAT_*` & `BLOOM_REVENUECAT_SECRET_KEY` | **Yes (P0)** | `storePlans()` returns live offerings; sandbox purchase updates `bloom_subscriptions` |
| 4 | Tap Payments (Web) | Configure live merchant keys (`BLOOM_TAP_SECRET_KEY`, `BLOOM_BILLING_WEB_ORIGIN`) and cron worker (`schedule-tap.sql`) | **Yes (Web/macOS)** | Complete 3-D Secure test charge and refund |
| 5 | Sentry & Amplitude | Create production projects; populate `EXPO_PUBLIC_SENTRY_DSN`, `BLOOM_SENTRY_DSN`, `EXPO_PUBLIC_AMPLITUDE_API_KEY` | **P1 (Recommended)** | Trigger `sendSentryTestEvent()` and verify `app_opened` in Amplitude |
| 6 | Legal & Support | Fill `[OWNER REVIEW REQUIRED]` legal entity, support email/URL, external deletion URL in `legal.tsx` & `legal-privacy-drafts.md`; review child-account rules | **Yes (Store Review)** | Store metadata & in-app Legal page contain real contact info |
| 7 | Supabase & AI Provider | Confirm PITR/daily backups enabled on prod Supabase; set OpenAI monthly spend cap & alerts | **Yes (Ops)** | Dashboard shows active PITR & hard spend cap |

---

## 18. Manual Physical-Device Testing Checklist

1. **iOS (Sandbox):** Clean install → Sign up → Complete onboarding → Authorize Screen Time → Purchase monthly plan → Verify `bloom_subscriptions` & Activity creation → Background/kill/relaunch → Restore purchases → Cancel auto-renew → Test expiry.
2. **Android (Internal Test Track):** Same flow with Google Play test account + Accessibility blocking verification.
3. **macOS (Notarized `.app`):** Sign in with iOS/Android-subscribed account → Confirm paid access unlocks → Test Focus blocking (App Shield + Website Shield + Brave extension + `bloomexercise://focus?section=earned`) → Test `bloomexercise://reset-password`.
4. **Account Switch:** Sign out Account A → Sign in Account B → Verify zero entitlement or onboarding leakage.

---

## 19. Actual Production Build Results & 20. Go/No-Go by Platform

- **Automated checks (executed on current working tree):** Verified `typecheck`, `lint`, `test:unit`, `deno test`, and `cargo test` (see final run output).
- **Xcode iOS Archive:** Failed on user's machine due to `No space left on device` (`407 MiB` free) and previously failed App Store 409 because the Nov 25 archive embedded a Development profile instead of the App Store distribution profile.
- **Platform Go/No-Go:**
  - **iOS:** **NO-GO** until disk freed, App Store distribution export re-archived, and sandbox purchase verified.
  - **Android:** **NO-GO** until Play Console products/sandbox purchase verified on physical device.
  - **macOS:** **NO-GO** until mobile/web subscription live + physical-Mac reboot/expiry QA completed.
  - **Web:** **NO-GO** until Tap live merchant + legal URLs configured.

## 21. Milestone 3 Prerequisites
- Complete Owner-Action Register items 1–7, run full physical-device purchase/lifecycle matrix, publish Chrome Web Store extension (`dist/bloom-browser-extension-cws.zip`), and optionally configure Safari `.appex` provisioning profile.
