Use case Id: UC07    Interface Lock

**Brief Description**
When screen-time balance reaches zero, the subsystem activates a screen lock on blocked apps and websites and shows a lock overlay encouraging the user to work out. The user can request an emergency break for a limited temporary override; emergency breaks are limited to prevent abuse.

**Primary actors**
Authenticated User, Subsystem (automated trigger)

**Preconditions:**
1. User is authenticated; at least one app or website is configured for blocking.
2. Blocking is active (permissions granted); screen-time balance is being consumed.

**Post-conditions:**
- Lock activation: Blocked apps/sites inaccessible; Lock Overlay displayed; balance recorded as 0.
- Emergency break: Record in emergency_breaks; lock lifted for 15 min (20 for VIP); after expiry lock re-activated unless balance replenished.
- Deactivation (via workout): Lock removed; balance positive; apps/sites accessible.

**Main Success Scenario:**
<ToDo: List the included use cases. Add rows to the table below if needed />

| Actor Action | Subsystem Response |
|--------------|-----------------|
| 1. User uses blocked apps/sites; balance decrements in real time (1 min use = 1 min deducted). | 2. Subsystem monitors balance; at 5 min sends warning notification; at 1 min sends urgent notification; at 0 triggers screen lock (overlay on Android, Screen Time API on iOS; block page for web). |
| 3. User sees Lock Overlay ("Screen-Time Depleted") with "Start Workout" and "Request Emergency Break". | 4. Subsystem displays overlay with streak/motivation; overlay persists until user earns time or uses break. |
| 5. User selects "Request Emergency Break" and confirms "Use Break" (if breaks remaining). | 6. Subsystem checks daily break usage; if remaining, records break (15 min standard, 20 VIP), lifts lock, shows countdown notification; at expiry re-activates lock and notifies. |
| 7. User completes a workout (Use Case 05) while lock is active. | 8. Subsystem credits screen-time, deactivates lock, notifies "Screen unlocked! You earned [X] minutes." |

**Alternative flows:**
2a. No blocking configured: lock inactive; dashboard suggests configuring blocking.
2b. Lock activates while app in background: full-screen overlay on blocked app (Android) or notification + block (iOS).
2c. Device restart during lock: on boot service checks balance and re-activates lock if 0; emergency break timer resumes from server-synced remaining time.
4a. User attempts to bypass lock: overlay re-triggered (Android); iOS shield prevents launch; if user revokes Screen Time, subsystem detects and urges re-authorization; bypass logged.
6a. No emergency breaks remaining (2 used today, or 3 for VIP): subsystem disables button and shows message; resets at midnight.
6b. Emergency break requested during active workout: subsystem suggests completing workout instead; option "Use Break Anyway".
6c. VIP: 3 breaks/day, 20 min each; dialog text adjusted.

**Special Requirements:**
<ToDo: List the non-functional requirements: balance decrements 1:1 with blocked usage; warnings at 5 min and 1 min; lock at 0; Free 2 breaks/day 15 min, VIP 3/day 20 min; breaks reset at midnight; break time does not replenish balance; Nashaat and essential apps never blocked; service survives reboot; bypass attempts logged; lock state synced to server. />
