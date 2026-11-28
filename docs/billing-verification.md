# Subscription verification record

Baseline: `fa7fff0` on `codex/bloom-subscriptions`; local macOS worktree, 2026-11-28. No provider credentials or customer data are recorded here. “Blocked” means the scenario has not been executed and is not a pass. The setup and operational instructions are in [billing-sandbox.md](billing-sandbox.md).

## Local checks

| Scenario | Expected result | Result |
| --- | --- | --- |
| TypeScript, lint, web export | Complete successfully | Pass |
| Deno billing tests | All four tests pass | Pass |
| Schema and billing fixtures in disposable PostgreSQL | All schema and concurrency checks pass | Pass |

The billing SQL fixture constructs all 12 plan combinations for each of App Store, Play Store, and Tap and checks catalog counts; that does not establish that each variant can be purchased. The fixtures also exercise refill timing, concurrent allowance use and refund approvals, household billing privacy, duplicate and retried callbacks, overlapping subscriptions, and the paid transition. Provider behavior and physical-device behavior require the checks below.

## Purchase matrix

For each row, execute all four combinations of Basic/Premium and Individual/Household. Record the provider price and receipt, Bloom plan, renewal date, allowance, environment, device, and outcome for each purchase in a secure test record using synthetic identities. All 36 combinations below are **blocked** pending sandbox setup, explicit transaction approval, and the applicable device or provider access.

| Channel | Weekly | Monthly | Yearly | Expected for each combination |
| --- | --- | --- | --- | --- |
| iOS / RevenueCat | 4 blocked | 4 blocked | 4 blocked | Receipt and Bloom access match the selected price, plan, renewal and allowance |
| Android / RevenueCat | 4 blocked | 4 blocked | 4 blocked | Receipt and Bloom access match the selected price, plan, renewal and allowance |
| Web / Tap | 4 blocked | 4 blocked | 4 blocked | Receipt and Bloom access match the selected price, plan, renewal and allowance |

## Outstanding sandbox and device scenarios

Each row is **blocked**, not verified. Record a separate result for each named action, including commit, environment, device or platform, expected and observed result, and any provider limitation.

| Platform | Scenarios and expected outcomes |
| --- | --- |
| iOS physical device | Purchase, reinstall and restore, plan changes, cancellation, eligible and ineligible paid offers, profile switching and expired-plan refund links. Access follows the Bloom profile and provider coverage. |
| Android physical device | Purchase, restore, plan changes, cancellation, paid intro, campaign and win-back offers, expired and exhausted codes, reservation, and refund versus access status. Offers and coverage match provider state. |
| Web / Tap | Successful and declined 3-D Secure, abandoned return, renewal, failed renewal and recovery, card update, prorated upgrade, scheduled downgrade and cancellation. Pending or failed payment grants no paid access. |
| Refunds | Request a web refund; approve full and partial amounts and decline another with a reason. Settlement and refundable balance match Tap; full current-term refund ends coverage while partial and historical refunds preserve applicable coverage. Exercise store refunds where supported. |
| All offers | Confirm eligible and ineligible behavior, discounted price and duration, regular renewal price and absence of free trials before purchase. |
| Web, mobile and macOS | Confirm shared subscription, household seat limit, private member allowance and history, account switching, and management at the original provider. |
| Four pillars | Show cost, reserve once, debit on save, release on failure and reject duplicate and offline spending. |
| Refill | Observe seven-day refill in an active term; verify an upgrade preserves refill timing and consumed credits. |
| Callbacks | Authenticate or reject callbacks appropriately, retry delayed callbacks, reconcile overlapping purchases and grant each valid payment once. Review aggregate health checks and resolve discrepancies. |
| English and Arabic | Verify billing screens and 30-day notice; after expiry retain records, active-session completion and safety settings. |

## Access check, 2026-11-28

The user approved sandbox configuration and test purchases and refunds. The connected Supabase accounts exposed no dedicated Bloom sandbox; the only listed project was identified as production and was not changed. The connected iPhone was offline, and `adb` was not available in the shell. RevenueCat, Tap, and store test-account access has not been established. Provider and physical-device scenarios remain blocked until those prerequisites are available. No sandbox transaction was attempted.
