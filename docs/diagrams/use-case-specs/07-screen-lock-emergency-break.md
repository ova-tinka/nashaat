# Use Case 07: State/Interface Lock & Emergency Break Handling

## Title
Screen Lock & Emergency Break Handling

## Actor
Authenticated User, System (automated trigger)

## Description
When a user's screen-time balance reaches zero, the system activates a screen lock that restricts access to blocked apps and websites. The user is presented with a lock screen overlay that encourages them to work out to earn more time. In urgent situations, the user can request an emergency break, which grants a limited, temporary override of the screen lock. Emergency breaks are strictly limited to prevent abuse.

## Preconditions
1. The user is authenticated and has an active session.
2. The user has configured at least one app or website for blocking.
3. The blocking system is active (device permissions are granted).
4. The user's screen-time balance has been tracked and is currently being consumed.

## Main Flow

### MF-1: State/Interface Lock Activation
1. The system's background service continuously monitors the user's screen-time balance while blocked apps/websites are in use.
2. The balance decrements in real-time as the user uses blocked apps (1 minute of usage = 1 minute deducted).
3. When the balance reaches **5 minutes**, the system sends a warning notification: "You have 5 minutes of screen-time remaining. Work out to earn more!"
4. When the balance reaches **1 minute**, the system sends an urgent notification: "1 minute remaining! Your blocked apps will be locked soon."
5. When the balance reaches **0 minutes**, the system triggers the screen lock:
   a. **On Android**: All blocked apps are immediately overlaid with the Lock Screen Overlay via the Display Over Other Apps permission.
   b. **On iOS**: The Screen Time API's application shield is activated for all blocked apps, preventing them from launching. A push notification directs the user to open Nashaat.
   c. Blocked websites are restricted via the Screen Time API web-domain management (mobile) or the browser extension (desktop).
   d. Within the Nashaat app, the system displays the **Lock Screen Overlay**:
      - Title: "Screen-Time Depleted"
      - Body: "You've used all your earned screen-time. Complete a workout to unlock more time!"
      - Buttons:
        - **"Start Workout"** (primary, navigates to Workout Plans)
        - **"Request Emergency Break"** (secondary, subtle)
      - Display: Current streak and motivational message (e.g., "Don't break your 12-day streak!")
6. The Lock State/Interface Overlay persists until the user earns more screen-time or uses an emergency break.

### MF-2: Emergency Break Request
1. The user selects **"Request Emergency Break"** on the Lock State/Interface Overlay.
2. The system checks the user's emergency break usage for the current day.
3. If the user has remaining breaks (less than 2 used today):
   a. The system returns or provides a confirmation dialog:
      - Title: "Emergency Break"
      - Body: "This will unlock your apps for 15 minutes. You have [X] emergency break(s) remaining today. Emergency breaks do not replenish your screen-time balance."
      - Buttons: **"Use Break"** and **"Cancel"**
4. The user selects **"Use Break"**.
5. The system records the emergency break in the `emergency_breaks` table with:
   - User ID
   - Timestamp
   - Duration: 15 minutes
6. The system temporarily lifts the screen lock for all blocked apps and websites.
7. A persistent countdown notification appears: "Emergency Break: 14:59 remaining"
8. The countdown is visible as a floating overlay or notification bar across all screens.
9. When the emergency break has **2 minutes** remaining, the system sends a warning: "Your emergency break ends in 2 minutes."
10. When the 15-minute break expires:
    a. The system re-activates the screen lock.
    b. All blocked apps and websites are restricted again.
    c. The system sends a notification: "Emergency break ended. Complete a workout to earn more screen-time."

### MF-3: State/Interface Lock Deactivation (via Workout)
1. While the screen lock is active, the user completes a workout (via Use Case 05).
2. The system calculates and credits screen-time to the user's balance.
3. The system automatically deactivates the screen lock.
4. A notification is sent: "Screen unlocked! You earned [X] minutes of screen-time."
5. The user can now freely use previously blocked apps within their new balance.

## Alternative Flows

### AF-1: No Emergency Breaks Remaining
- **Branches from:** MF-2, Step 3
- The user has already used 2 emergency breaks today.
- The system returns a prompt: "You've used all your emergency breaks for today (2 of 2). Your breaks reset at midnight. Complete a workout to unlock your apps."
- The "Request Emergency Break" button is disabled and grayed out.

### AF-2: Emergency Break During Active Workout
- **Branches from:** MF-2, Step 4
- The user already has a workout session in progress.
- The system returns a prompt: "You have a workout in progress! Complete it to earn screen-time instead of using a break."
- Buttons: **"Continue Workout"** (navigates to active session) and **"Use Break Anyway"**.

### AF-3: User Attempts to Bypass Lock
- **Branches from:** MF-1, Step 5
- The user tries to force-close the lock overlay or access blocked apps through alternative means.
- On Android: The Accessibility Service detects the blocked app launch and re-triggers the overlay.
- On iOS: The Screen Time API prevents the app from launching via the application shield. However, the user can revoke Screen Time access entirely via iOS Settings > Screen Time > Apps with Screen Time Access, which cannot be programmatically prevented. If access is revoked, the system detects it on next launch, pauses blocking, and sends a persistent notification urging re-authorization (see Use Case 08, AF-2).
- A log entry is recorded in the `bypass_attempts` table for analytics.

### AF-4: VIP Emergency Break Benefits
- **Branches from:** MF-2, Step 2
- VIP users receive 3 emergency breaks per day instead of 2.
- VIP emergency breaks last 20 minutes instead of 15.
- The system adjusts the dialog text accordingly.

### AF-5: Device Restart During Lock
- **Branches from:** MF-1, Step 6
- The user restarts their device while the screen lock is active.
- Upon device boot, the Nashaat background service starts automatically.
- The system checks the user's screen-time balance.
- If balance is still 0, the screen lock is re-activated.
- If an emergency break was in progress, the system checks the server-synced break end-time and resumes the countdown from the correct remaining duration (the timer is not reset or extended by the reboot).

### AF-6: State/Interface Lock Activates While App is in Background
- **Branches from:** MF-1, Step 5
- The user is actively using a blocked app when balance reaches 0.
- The system posts a full-screen notification/overlay on top of the blocked app.
- On Android: The overlay covers the entire screen.
- On iOS: A notification directs the user away from the app, and the State/Interface Time API blocks further access.

### AF-7: Balance Replenished by Friend Gift (Future Feature)
- **Branches from:** MF-1, Step 6
- A friend sends the user screen-time as a gift (potential future feature).
- The system credits the gifted minutes and deactivates the lock.
- Not implemented in the initial release.

### AF-8: No Blocking Configured
- **Branches from:** MF-1, Step 1
- The user has not configured any apps or websites for blocking.
- The screen lock system is inactive.
- The user's screen-time balance still depletes, but no lock is triggered.
- A dashboard notice suggests: "Configure app blocking to make the most of Nashaat."

## Postconditions

### For State/Interface Lock Activation:
1. All configured blocked apps and websites are inaccessible.
2. The Lock State/Interface Overlay is displayed.
3. The user's screen-time balance is recorded as 0 in the database.

### For Emergency Break:
1. An emergency break record exists in the `emergency_breaks` table.
2. The screen lock is temporarily lifted for 15 minutes (or 20 for VIP).
3. The daily emergency break counter is incremented.
4. After the break expires, the lock is re-activated (unless the user earned more time).

### For State/Interface Lock Deactivation:
1. The screen lock is removed.
2. Blocked apps and websites are accessible again.
3. The user's screen-time balance is positive.

## Business Rules

| Rule ID | Rule Description |
|---------|-----------------|
| BR-01 | State/Interface-time balance decrements in real-time: 1 minute of blocked-app usage = 1 minute deducted. |
| BR-02 | A warning notification is sent at 5 minutes remaining. |
| BR-03 | An urgent notification is sent at 1 minute remaining. |
| BR-04 | State/Interface lock activates immediately when balance reaches 0. |
| BR-05 | Free-tier users receive 2 emergency breaks per day, each lasting 15 minutes. |
| BR-06 | VIP users receive 3 emergency breaks per day, each lasting 20 minutes. |
| BR-07 | Emergency breaks reset daily at midnight (user's local timezone). |
| BR-08 | Emergency break time does NOT count as screen-time and does NOT deplete the balance further. |
| BR-09 | The Nashaat app itself is never locked (the user must always be able to access Nashaat to log workouts). |
| BR-10 | Essential system apps (Phone, Messages, Emergency calls, Settings) are never blocked. |
| BR-11 | The background monitoring service must survive device restarts (auto-start on boot). |
| BR-12 | If device permissions for blocking are revoked, the system sends a notification urging the user to re-enable them and logs the event. |
| BR-13 | Bypass attempts are logged and, after 5 attempts in a day, a special notification is sent: "Struggling with screen-time? A quick workout can help!" |
| BR-14 | State/Interface lock state is synced to the server so it persists across app reinstalls. |

## UI/UX Notes
- The Lock State/Interface Overlay should be visually calming but firm, using a dark background with a motivational illustration (e.g., a person exercising).
- The "Start Workout" button should be large, prominent, and use the app's primary action color.
- The "Request Emergency Break" button should be styled as a subtle text link, not a prominent button, to discourage overuse.
- During an emergency break, the countdown should be always visible (persistent notification or floating widget) so the user is aware of the remaining time.
- Warning notifications (5 min, 1 min) should use distinct sounds and haptic feedback to grab attention.
- The overlay must not be dismissible by tapping outside it or pressing the back button.
- On the Lock State/Interface, display a small summary of what the user could earn from a quick workout (e.g., "A 15-min workout could earn you 30+ minutes of screen-time!").
- Consider adding a breathing exercise or mindfulness prompt on the lock screen as an alternative positive activity.
