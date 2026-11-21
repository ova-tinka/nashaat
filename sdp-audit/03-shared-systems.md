# Shared systems

| System | Status | Evidence and limitation |
|---|---|---|
| Auth/profile | Partial | Supabase persistent session setup `src/lib/supabase.ts:6-18`; routes `src/app/sign-in.tsx`; database identity/RLS migrations. Registration, OTP delivery and session recovery require configured backend runtime. |
| Personal/family | Partial | Household, child profiles, pairing and assignments migrations/functions exist. Family linking/approval runtime not independently verified. |
| Arabic/RTL | Insufficient evidence | Theme/localization files exist but no full Arabic RTL acceptance result identified. |
| Shared credit ledger | Partial | `20260417000001_screen_time_economy.sql`, `20260923000009_authoritative_workout_rewards.sql`, `20261120140000_bloom_shared_growth_rewards.sql`; idempotency and SQL concurrency fixtures documented in QA. Cross-device runtime consistency remains unverified. |
| Focus/device protection | Partial/failed | Native Android/iOS module and macOS Network Extension/monitor code exist. Brave and Calculator failures contradict broad reliability claims; restart and permission-loss acceptance incomplete. |
| Sync | Partial | Device registry and cross-device SQL fixtures exist; no physical multi-device evidence in this audit. |
| AI | Partial | Edge functions for growth AI, coach, study tutor, reading reflection, mock exam. Provider credentials/network required; functional quality and availability not verified. |
| Notifications | Insufficient | No end-to-end delivery evidence identified. |
| Social/gamification | Partial | competitions/friends/leaderboards migrations and app route exist; live behavior not verified. |
| Payment/subscriptions | Missing/unverified | No store/payment proof found in examined source. Do not infer from planned UC. |
| Wellness guidance | Partial | Product modules exist; content review and behavior evidence not audited. |
