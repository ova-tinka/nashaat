# Bloom billing sandbox

Bloom has one subscription for all four pillars. Basic and Premium differ in their weekly allowance. Individual and Household each support weekly, monthly, and yearly billing. The allowance resets after seven days regardless of payment cadence. Usage credits are an included weekly feature allowance. Earned screen-time minutes use their own unit in the ledger.

## Set up the sandbox

1. Use a dedicated Supabase project, RevenueCat sandbox store products, and Tap test merchant. Apply the billing migrations and load the catalog from [sandbox-catalog.sql](../supabase/billing/sandbox-catalog.sql). Its USD amounts, seat counts, allowances, and campaign values are fixtures. Match the Play campaign option identifiers in the seed to paid offers in the test store. Use a test currency enabled by the Tap merchant. Adjust the sandbox catalog in Git so others can reproduce it.
2. Configure one App Store subscription group with the 12 products. Rank the products by level of service in App Store Connect. On Play, create four subscriptions with three auto-renew base plans each. Set the default same-product replacement to charge at the next billing date. Map both stores in RevenueCat. Enable store server notifications and choose **Keep with original App User ID** for restore behavior. Disable Apple Family Sharing for these products. Bloom manages Household seats. Keep store test users, product IDs, offers, and the two public SDK keys aligned with the corresponding build.
3. Enable Tap Save Card and test the hosted card flow with 3-D Secure, an authenticated card update, and a merchant-initiated billed renewal. Use the same URL origin for the browser and the return page. The Expo host must serve the SPA on a direct request to `/subscription`.
4. Configure the Edge Functions with the names below and deploy them. Configure the RevenueCat webhook to end in `/functions/v1/bloom-revenuecat/webhook` with the configured bearer token. Tap's per-request callback ends in `/functions/v1/bloom-tap/webhook`. Schedule the billing worker with [schedule-tap.sql](../supabase/billing/schedule-tap.sql). It handles Tap renewals and refunds and retries callbacks from both providers. The worker needs both provider API keys.
5. Grant a sandbox employee's stable Bloom profile a refund-staff row through an authorized database operator. Use test identities and synthetic charges. Turn `bloom_private.billing_config.checkout_enabled` on only after validating the catalog and callbacks. Set a notice time and enforcement time at least 720 hours apart for the 30-day transition. Existing profiles receive temporary access during that interval. The home screen shows the transition date.

| Configuration | Purpose |
| --- | --- |
| `EXPO_PUBLIC_REVENUECAT_IOS_KEY` and `EXPO_PUBLIC_REVENUECAT_ANDROID_KEY` | Public platform SDK keys in the Expo build. |
| `BLOOM_BILLING_ENVIRONMENT` | `sandbox` or `production`, set on the matching Edge deployment. |
| `BLOOM_REVENUECAT_SECRET_KEY` | Server API v1 key for verified customer snapshots. |
| `BLOOM_REVENUECAT_WEBHOOK_TOKEN` | Shared bearer value for the RevenueCat callback. |
| `BLOOM_TAP_SECRET_KEY` | Server key for the matching Tap merchant environment. |
| `BLOOM_BILLING_WEB_ORIGIN` | Exact origin of the Expo website without a trailing slash. |
| `BLOOM_BILLING_FUNCTION_BASE` | Public HTTPS Functions base URL ending in `/functions/v1`. |
| `BLOOM_TAP_CARD_CHECK_MINOR` | Tap-approved temporary authorization amount in minor units for the sandbox currency. |
| `BLOOM_TAP_VARIABLE_RENEWALS` | Default false. Enable only after Tap confirms the agreement supports the explicitly accepted regular renewal amount after a discounted charge. |
| `BLOOM_BILLING_WORKER_TOKEN` | Worker bearer value, also stored in Vault for the scheduled job. |

For Play campaigns, configure paid offers using Play stock eligibility for intro prices and a developer-determined offer for a campaign or win-back. Tag introductory paid options `bloom-intro`. Checking an entered Play code previews the paid option. Confirming purchase reserves a slot for 30 minutes. A verified Play purchase of the selected plan during that window records the redemption. Expired holds free unconfirmed slots. Set up Apple paid introductory, campaign code, and win-back offers in App Store Connect. For Tap and Android campaigns, configure dates, limits, product, and the amount or Play option in `bloom_private.billing_offers`. Tap applies the discount to the first billed term and discloses the regular renewal price before payment. When Tap requires fresh authorization after an introductory term or a scheduled change, Bloom prompts the payer to pay the next term with updated consent.

## Verify and operate

- Run `npm run typecheck`, `npm run lint`, `npm run build:web`, `npm run test:schema`, and `deno test supabase/functions/_shared/billing_test.ts`.
- On physical iOS and Android development builds, buy plans, restore from a fresh install, and verify the same profile in the browser and macOS app. Try an offer, period change, cancellation, refund, and a sign-in switch on a shared device. Use Apple and Google test accounts. Check English and Arabic on both stores and on the Tap return page.
- In Tap sandbox, test a captured and declined 3-D Secure payment, an abandoned return, agreement renewal, failed renewal and recovery, card update, and settlement of a full and partial refund. Confirm amount, currency, environment, next refill, and remaining access against the provider and Bloom records.
- Watch worker HTTP status and aggregate counts from [health.sql](../supabase/billing/health.sql), including overdue callbacks, captured Tap payments without a linked term, and usage entries outside the expected refill window. The callback inbox retains lookup references and retry timestamps. Review `bloom_private.billing_alerts` for unmatched products, conflicting subscriptions, and uncertain provider requests. Reconcile a request marked for review against Tap using its order reference before taking a new charge or refund action. Keep provider records and the billing event inbox to support reconciliation. The provider consoles remain the receipt and refund authority for mobile. Google Play refund-only orders can require a staff reconciliation because RevenueCat detects refund-and-revoke more reliably.
- Before any production rollout, approve the merchant market, renewal and refund terms, prices, allowances, seats, and storefront configuration. Validate the provider flows in sandbox first and use production-specific settings and keys.
