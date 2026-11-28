# Bloom Legal, Privacy & Disclosure Drafts (Implementation-Ready)

> **Status:** Draft prepared from actual repository behavior on `2026-11-28`. Marked sections (`[OWNER REVIEW REQUIRED]`) must be completed and reviewed by legal counsel / business owner before public commercial launch.

---

## 1. Data Inventory (Verified from Source Code)

| Category | Exact Data Processed | Storage / Destination | Retention / Deletion |
| --- | --- | --- | --- |
| Account & Auth | Email address, Supabase Auth UID, profile ID, child/guardian link | Supabase Auth & `public.bloom_profiles` | Deleted via `bloom-account-delete` (Family accounts routed for review) |
| Activity & Growth | Workout plans, sessions, Study items/notes, Reading items/progress, Tasks | Supabase PostgreSQL (`bloom_*` tables) | Exportable via `bloom-account-export`; deleted on personal deletion |
| Private Uploads | User-uploaded Study/Reading PDFs & EPUBs | Private Supabase Storage bucket | Signed 300s URLs on export; deleted on personal deletion |
| AI Features (Optional) | Study Tutor prompts/answers, Document Help, Mock Exam, Coach, Reading Reflection | OpenAI / configured AI provider via Edge Functions (`bloom-*`) | Quota counters separate from deletable conversation history |
| Device Blocking & Screen Time | Selected app bundle IDs/package names, blocked domains, earned-minute ledger, active countdowns | On-device (`UserDefaults` App Group / `SharedPreferences` / `NEFilterManager`) + server credit ledger (`bloom_credit_ledger`) | **macOS website addresses stay strictly on-device**; never sent to Bloom servers |
| Subscriptions | Plan tier, period, entitlement status, Tap receipts / RevenueCat customer snapshot | Supabase (`bloom_subscriptions`, `bloom_billing_*`), RevenueCat, Tap, Apple/Google | Billing audit records preserved lawfully; store cancellation managed by store |
| Telemetry (When Enabled) | Crash stack traces (`Sentry`) & allowlisted funnel events (`Amplitude`) | Sentry / Amplitude | **PII scrubbed; child accounts strictly excluded from Amplitude & user IDs** |

---

## 2. Privacy Policy Draft

- **Who we are:** `[OWNER REVIEW REQUIRED: Legal company / developer entity name, registered address, privacy contact email]`
- **What we collect & why:** Account credentials and activity records to sync Exercise, Study, Reading, Tasks, and Earned Screen Time across your devices; subscription metadata to verify paid access.
- **On-device privacy for Focus blocking:** Browser URLs and app-blocking checks evaluated by Bloom on macOS, iOS, and Android remain on your device.
- **Third-party processors:** Supabase (database, auth, storage, Edge Functions), RevenueCat (iOS/Android receipt verification), Tap Payments (web card checkout), `[OWNER REVIEW REQUIRED: AI model provider entity]`, Sentry (error diagnostics when enabled), Amplitude (essential product analytics when enabled).
- **Child & guardian accounts:** Child profiles are paired by a parent/guardian, keep separate accounts and credit balances, and have third-party product analytics disabled in Bloom (`setAnalyticsIdentity(..., { childProfile: true })`). `[OWNER REVIEW REQUIRED: Obtain legal review for COPPA / GDPR-K / local minor-data requirements before enabling public child-account signups.]`
- **Your rights (Export & Deletion):** Personal accounts can export JSON + file links or permanently delete their account inside **Profile → Account**. `[OWNER REVIEW REQUIRED: Specify retention window for backups/financial tax records and external web deletion URL: https://...]`

---

## 3. Terms of Service & Paid-Only Subscription Terms Draft

- **Paid-only product:** Bloom requires an active paid subscription to start new activities across Exercise, Study, Reading, and Tasks. There is no permanent free tier or free trial.
- **Auto-renewal:** Subscriptions (Weekly, Monthly, or Yearly; Basic or Premium; Individual or Household) renew automatically unless cancelled before the end of the current billing period.
- **Cancellation & Refunds:**
  - **Apple App Store purchases:** Manage or cancel in iOS/macOS Settings → Apple Account → Subscriptions; refunds are governed by Apple (`reportaproblem.apple.com`).
  - **Google Play purchases:** Manage or cancel in Google Play → Payments & subscriptions; refunds are governed by Google Play.
  - **Bloom website (Tap) purchases:** Manage, cancel at period end, or request a refund directly on the Bloom website `/subscription` page. `[OWNER REVIEW REQUIRED: Insert formal Tap refund eligibility & SLA policy.]`
- **Account deletion vs. subscription cancellation:** Deleting a Bloom account does **not** automatically cancel an active Apple App Store or Google Play subscription; cancel with the store first.

---

## 4. Permission Explanations (In-App & Store Metadata)

- **iOS Screen Time / Family Controls:** Used solely to shield apps and websites selected by the user or parent on that iPhone/iPad.
- **Android Accessibility Service:** Used solely to detect foreground launch of user-selected distraction apps and block them when earned screen time is not active.
- **macOS Network Extension, Background Monitor & Accessibility:** Used to block configured domains system-wide, display the Bloom Shield overlay, and coordinate earned screen time locally.

---

## 5. Support & Feedback

- **Support Contact:** `[OWNER REVIEW REQUIRED: support@yourdomain.com and support web URL]`
