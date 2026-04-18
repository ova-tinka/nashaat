Use case Id: UC12    Receive Notifications

**Brief Description**
The subsystem sends targeted notifications (push, in-app, optional email) for events and schedules: workout reminders, screen-time earned, weekly goal warnings, screen lock alerts, streak warnings, friend activity, reward unlocks, subscription alerts. Users configure preferences per category.

**Primary actors**
Authenticated User, Subsystem (automated triggers)

**Preconditions:**
1. User is authenticated.
2. Push notification permission granted (or defaults applied at onboarding).

**Post-conditions:**
1. Notification delivered via configured channels; record in notifications table with status.
2. Tapping notification navigates to relevant screen; badge reflects unread count.

**Main Success Scenario:**
<ToDo: List the included use cases. Add rows to the table below if needed />

| Actor Action | Subsystem Response |
|--------------|-----------------|
| 1. A triggering event occurs (workout reminder, screen-time earned, lock, streak, friend, reward, subscription, etc.). | 2. Subsystem evaluates event against user notification preferences; if enabled, builds payload (title, body, action, priority, channel). |
| 3. — | 4. Subsystem sends via Push (FCM/APNs), In-App (notifications table), and/or Email; records notification as sent. |
| 5. User receives notification; may tap to open app or open Notification Center (bell icon). | 6. Push: appears in tray; in-app banner if app foreground; tap deep-links. In-App: badge on bell; center shows list (icon, title, body, time, read/unread); tap marks read and navigates. |
| 7. User goes to Settings > Notifications and toggles categories (workout, screen-time, weekly goal, lock, streak, friend, rewards, subscription, email). | 8. Subsystem updates notification_preferences; changes save immediately. |
| 9. User may "Mark All as Read" or "Clear All" in Notification Center. | 10. Subsystem updates read status and removes deleted from notifications table. |

**Alternative flows:**
2a. Push permission denied: push not sent; in-app still delivered; Settings shows banner and "Enable Notifications" deep-link.
2b. Quiet hours: only high-priority push; others in-app only.
4a. User offline: push queued by FCM/APNs; in-app stored and shown on next open.
4b. Delivery failure (invalid token): subsystem logs; removes token; new token on next launch.
4c. Multiple devices: push to all; read status synced across devices.
6a. Notification center >100 unread: show 100 most recent; "Load More"; purge >30 days.

**Special Requirements:**
<ToDo: List the non-functional requirements: push requires OS permission; in-app always delivered; subscription alerts cannot be disabled; workout reminder default 8 AM, configurable 5 AM–10 PM; quiet hours default 10 PM–7 AM; purge 30 days; max 100 in center; email for subscription and optional weekly summary; deep-links on push; friend workout rate limit 1/friend/day; re-engagement push if app not opened 7 days (max 1/week); preferences immediate. />
