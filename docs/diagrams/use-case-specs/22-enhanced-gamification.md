Use case Id: UC22    Enhanced Gamification

**Brief Description**
The system awards XP and levels based on workout activity, unlocks achievement badges across four categories (Consistency, Strength, Social, Discipline), and runs weekly and monthly challenges with leaderboard integration. Completing challenges grants bonus screen time. Milestone rewards such as a "30-Day Streak" badge are automatically triggered by the badge engine when criteria are met.

**Primary actors**
Authenticated User, System (badge engine)

**Preconditions:**
1. The user is authenticated.
2. The user has at least one completed workout logged in workout_logs.
3. Gamification data tables (gamification_badges, user_badges) are seeded with system badges.
4. Challenges are published and active for the current week/month.

**Post-conditions:**
1. XP and level are updated on the user's profile after each qualifying action.
2. Newly unlocked badges are saved in user_badges with unlocked_at timestamp.
3. Completed challenges are marked complete; bonus screen time is credited to screen_time_transactions.
4. Notifications are sent for badge unlocks and challenge completions (UC12).

**Main Success Scenario:**
<ToDo: List the included use cases. Add rows to the table below if needed />

| Actor Action | Subsystem Response |
|--------------|-----------------|
| 1. User completes a workout session (UC05). | 2. Badge engine evaluates all system badge criteria; XP is awarded based on workout duration and intensity. |
| 3. Badge criteria met for one or more badges. | 4. Subsystem inserts rows in user_badges for each newly unlocked badge and sends push notification (UC12). |
| 5. User opens the Achievements screen. | 6. Subsystem displays all badges (locked and unlocked), current XP, level, and active challenges with progress bars. |
| 7. User completes the weekly challenge (e.g., "Log 5 workouts this week"). | 8. Subsystem marks the challenge complete, credits bonus screen time to screen_time_transactions, and updates the leaderboard (UC13). |
| 9. Monthly challenge period ends. | 10. Badge engine tallies results, distributes milestone badges to qualifying users, and resets challenge counters. |

**Alternative flows:**
2a. User has already earned the badge: badge engine skips; no duplicate user_badge rows are created.
4a. Push notification delivery fails: badge unlock is still recorded; notification can be retrieved from the in-app notification centre.
7a. Challenge expires before user completes it: challenge is marked expired; no bonus screen time is credited; user sees "Challenge Expired" status.

**Special Requirements:**
<ToDo: List the non-functional requirements that the use case must meet. E.g. badge unlock idempotent — no duplicates; XP award calculated server-side to prevent tampering; challenge progress updated in real time; leaderboard reflects challenge scores within 30 seconds; bonus screen time credited atomically with challenge completion; badge categories: Consistency, Strength, Social, Discipline; badge icons stored in gamification_badges.icon_url. />
