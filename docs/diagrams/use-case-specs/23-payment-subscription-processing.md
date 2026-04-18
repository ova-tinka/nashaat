Use case Id: UC23    Payment Processing & Subscription Management

**Brief Description**
Users can upgrade to VIP via Stripe (monthly or annual) or via in-app purchase through the App Store / Play Store. The system handles the full upgrade, downgrade, and cancellation lifecycle. B2B billing for gym accounts (UC25) also flows through this use case. On successful payment, the user's subscription_tier in profiles is updated to VIP and all VIP features are immediately unlocked.

**Primary actors**
Authenticated User, Stripe, App Store / Play Store

**Preconditions:**
1. The user is authenticated and on the Free tier (or an existing VIP subscriber managing their plan).
2. Stripe is configured with the correct product/price IDs for monthly and annual VIP plans.
3. App Store / Play Store in-app purchase products are published and active.
4. The device has an active internet connection.

**Post-conditions:**
1. For successful upgrade: profiles.subscription_tier is set to vip; payment_subscriptions record is created with active status.
2. For cancellation: payment_subscriptions.status is set to canceled; tier reverts to free at period end.
3. For downgrade: subscription plan is updated; changes take effect at next billing cycle.
4. All subscription events are logged for audit purposes.

**Main Success Scenario:**
<ToDo: List the included use cases. Add rows to the table below if needed />

| Actor Action | Subsystem Response |
|--------------|-----------------|
| 1. User navigates to Subscription screen and selects "Upgrade to VIP". | 2. Subsystem displays plan options (monthly / annual) with pricing and feature comparison. |
| 3. User selects a plan and chooses payment method (Stripe card / App Store / Play Store). | 4. Subsystem initiates the appropriate payment flow: Stripe checkout sheet or native IAP flow. |
| 5. User completes payment. | 6. Stripe webhook or App Store/Play Store server notification confirms payment; subsystem updates profiles.subscription_tier to vip and inserts a payment_subscriptions record. |
| 7. — | 8. Subsystem sends confirmation notification (UC12) and unlocks VIP features immediately. |
| 9. User selects "Cancel Subscription". | 10. Subsystem cancels via Stripe API or IAP management; updates payment_subscriptions.status to canceled; tier reverts to free at period end; confirmation notification sent. |

**Alternative flows:**
6a. Payment declined: subsystem shows error from payment provider; user is prompted to try a different method.
6b. Webhook delayed: subsystem shows "Payment received, activating…" and polls for up to 60 seconds before showing a manual retry option.
9a. User attempts to cancel with more than 24 hours remaining in trial: subsystem shows remaining trial duration and asks for confirmation.
10a. Subscription already cancelled: subsystem shows expiry date and a "Resubscribe" option instead.

**Special Requirements:**
<ToDo: List the non-functional requirements that the use case must meet. E.g. Stripe webhook signature validated server-side; no card details stored in Supabase; IAP receipt verified via App Store/Play Store server API; subscription tier update atomic with payment confirmation; cancellation does not revoke access until period end; B2B gym billing handled via Stripe with per-seat pricing (see UC25); refund requests directed to support. />
