# Bloom Disaster Recovery & External Spending Controls

## 1. Verified External API & AI Spending Controls

| Surface | Auth Gate | Entitlement Gate | Request / Body Limits | Timeouts & Retries | Status |
| --- | --- | --- | --- | --- | --- |
| `bloom-study-tutor` | `authenticateActiveUser` | `bloom_begin_study_tutor_request` + billing access | 6 KB body, prompt <= 2,000 chars, output <= 4,000 chars | `20s` `AbortSignal.timeout`, single call | **Verified** |
| `bloom-study-document-help` | `authenticateActiveUser` | `bloom_begin_document_help_request` + billing access | 5 KB body, bounded file extraction | `20s` timeout | **Verified** |
| `bloom-growth-ai` (Task breakdown) | `authenticateActiveUser` | `bloom_begin_task_ai_request` + billing access | 5 KB body, `max_tokens: 900` | `20s` `AbortSignal.timeout` | **Verified** |
| `bloom-mock-exam-assess` | `authenticateActiveUser` | `bloom_begin_mock_exam_request` | 22 KB body, `max_tokens: 1,600` | `20s` `AbortSignal.timeout` | **Verified** |
| `bloom-read-reflection` | `authenticateActiveUser` | `bloom_begin_read_reflection_request` | `max_tokens: 350` | `20s` `AbortSignal.timeout` | **Verified** |
| `bloom-coach` | `authenticateActiveUser` | Coach quota + profile check | Bounded JSON response (`limitedJson`) | `20s` `AbortSignal.timeout` | **Verified** |
| DB New Activity Triggers | RLS + authenticated role | `bloom_private.billing_guard_new_activity()` | Trigger on `bloom_workout_*`, `bloom_growth_*`, `bloom_task_focus_sessions` | PostgreSQL atomic check | **Verified** |

**Required Owner Action (External):** Set hard monthly spending caps and 50%/80%/100% billing alerts on the OpenAI (or configured AI provider) dashboard and Supabase plan before launch.

---

## 2. Database Backups & Migration Hygiene

- **Migrations:** 77+ timestamped SQL migrations in `supabase/migrations/` verified clean via `npm run test:bootstrap` and `tests/run-schema-local.sh`.
- **Supabase Backups (Owner Check Required):** Verify Point-in-Time Recovery (PITR) or daily automated backups are enabled on the production Supabase project. Note: Storage objects (uploaded Study/Reading PDFs) are **not** covered by SQL logical dumps and require Supabase Storage/S3 snapshot verification.

---

## 3. Contingency Runbooks

### A. Supabase Outage
1. **Impact:** Login, server credit earning/spending, AI calls, and live billing refresh fail.
2. **Safeguards in code:**
   - Paying customers retain read-only cached billing status for up to 24h (`src/lib/billing-context.tsx`, bounded strictly by `period_end` / `enforcement_at`).
   - Offline activities queue safely per profile/device in `src/lib/offline-activity-queue.ts` and never authorize offline screen-time spending.
3. **Action:** Communicate temporary sync outage via status page; monitor Supabase dashboard; replay queued activities automatically when restored.

### B. RevenueCat Outage
1. **Impact:** New mobile purchases/restores and `bloom-revenuecat/sync` fail temporarily.
2. **Safeguards in code:**
   - Existing `bloom_subscriptions` rows remain valid in PostgreSQL until `period_end` / `grace_until`.
   - `purchaseInFlightRef` in `src/app/(app)/subscription.tsx` prevents duplicate tap-triggered purchases; `billing-context.tsx` preserves valid unexpired cache for 24h.
3. **Action:** Rely on RevenueCat webhook retries (`billing-webhooks.ts`) and run `syncRevenueCat` once RevenueCat recovers.

### C. AI Provider Outage / Spend Spike
1. **Impact:** Optional AI Tutor, Document Help, Mock Exam Assessment, Coach, and Reading Reflection fail cleanly with user-facing error messages.
2. **Safeguards in code:** `20s` timeouts + no unbounded retries + all 4 core pillars, Focus blocking, and Earned Screen Time continue working normally without AI.
3. **Action:** If abuse/spike occurs, disable `access.enabled` / AI feature env flag on affected Edge Functions (`bloom-study-tutor`, `bloom-growth-ai`, etc.) without touching core pillars.

### D. Application Release Regression
1. **Mobile (iOS/Android):** Halt phased rollout in App Store Connect / Google Play Console; ship hotfix build or disable affected server capability flag (`bloom_private.billing_config.checkout_enabled = false` if billing).
2. **macOS Direct Download:** Revert download link to prior notarized `.app` / `.dmg` release.

### E. Database Corruption or Accidental Migration
1. **Stop:** Halt deployments and disable `checkout_enabled` / AI Edge Functions immediately.
2. **Preserve:** Export recent logs and `bloom_private.billing_alerts` / `billing_events` inbox.
3. **Restore:** Use Supabase PITR / latest verified snapshot to a staging branch first, verify row counts and billing tables (`supabase/billing/health.sql`), then promote or replay reconciled billing webhooks.
