Use case Id: UC11    Subscription Management Subsystem (CRUD)

**Brief Description**
An authenticated user manages their Nashaat subscription. Users start on Free tier and can subscribe to VIP (AI plans, screen-time bonus, higher blocking limits, enhanced emergency breaks, analytics). Users view details, upgrade to VIP, change plan (monthly/annual), and cancel. Payments via App Store / Play Store.

**Primary actors**
Authenticated User

**Preconditions:**
1. User is authenticated; device has internet.
2. User has valid payment method in platform account (App Store / Play Store).

**Post-conditions:**
- Subscribe: subscriptions table has active VIP; features unlocked; auto-renewal scheduled.
- Plan change: subscriptions updated; effect next billing (downgrade) or immediate (upgrade).
- Cancel: Auto-renewal off; VIP until end of billing period; then downgrade to Free.

**Main Success Scenario:**
<ToDo: List the included use cases. Add rows to the table below if needed />

| Actor Action | Subsystem Response |
|--------------|-----------------|
| 1. User navigates to Settings > Subscription. | 2. Subsystem displays current tier (Free/VIP), VIP details (dates, price, payment method, auto-renewal), or Free with benefits list and "Upgrade to VIP"; feature comparison table. |
| 3. User selects "Upgrade to VIP", chooses Monthly/Annual (and optional 7-day trial), selects "Subscribe" or "Start Free Trial". | 4. Subsystem opens platform purchase flow (StoreKit 2 / Play Billing); user confirms; subsystem receives receipt. |
| 5. — | 6. Subsystem validates receipt with server/Apple/Google; updates subscriptions table; unlocks VIP features; shows "Welcome to VIP!" and sends confirmation. |
| 7. (VIP) User selects "Change Plan" and confirms alternative plan. | 8. Subsystem processes via platform API; updates subscriptions; confirms and notifies. |
| 9. (VIP) User selects "Cancel Subscription", passes retention screen, optionally selects reason, and confirms. | 10. Subsystem cancels auto-renewal via platform; sets cancellation and access end date; user keeps VIP until end of period; then subsystem downgrades and notifies. |

**Alternative flows:**
2a. Free trial already used: trial option not shown; regular price only.
2b. Restore Purchases: subsystem queries platform; restores VIP if valid subscription found; else "No active subscription found."
4a. Payment failed or cancelled: subsystem shows message; user remains Free.
4b. Promotional pricing: subsystem shows promo price and applies at checkout.
4c. User under 18: platform parental consent flow (Ask to Buy / Family Link).
6a. Receipt validation failed: subsystem retries up to 3 times; shows message; logs for support if all fail.
6b. Subscription expired (billing issue): grace period; notification to update payment; then cancel and downgrade.
10a. Downgrade with excess blocked items: subsystem pauses excess above Free limits and notifies.

**Special Requirements:**
<ToDo: List the non-functional requirements: two tiers Free/VIP; VIP $9.99/mo or $79.99/yr; one-time 7-day trial per platform account; native billing only; receipt validation mandatory; retry 3× at 30s; cancellation at period end; no direct refunds (Apple/Google); excess blocking items paused on downgrade; grace period per platform; status checked on launch, cached 24h; subscription_events logged. />
