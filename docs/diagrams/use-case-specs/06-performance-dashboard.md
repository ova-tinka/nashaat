Use case Id: UC06    Access Personal Performance Dashboard

**Brief Description**
An authenticated user views their personal performance dashboard: weekly workout progress, screen-time balance, active streak, leaderboard ranking among friends, and reward/achievement status. The dashboard is the primary home screen.

**Primary actors**
Authenticated User

**Preconditions:**
1. User is authenticated and has completed onboarding.
2. Device has active internet (or cached data available for offline viewing).

**Post-conditions:**
1. User has viewed current performance metrics.
2. Dashboard data is cached locally for offline access.
3. Newly unlocked rewards marked as "seen" in the database.

**Main Success Scenario:**
<ToDo: List the included use cases. Add rows to the table below if needed />

| Actor Action | Subsystem Response |
|--------------|-----------------|
| 1. User opens app or taps Dashboard tab. | 2. Subsystem queries profiles, workout_logs (current week), screen_time_balance, streak, leaderboard_members, user_rewards. |
| 3. — | 4. Subsystem displays Dashboard: greeting, Screen-Time Balance card, Weekly Progress ring, Active Streak, Leaderboard snapshot, Rewards & Achievements, Today's Workout (plan or "Start Workout" / ad-hoc prompt). |
| 5. User may pull-to-refresh. | 6. Subsystem caches data after fetch; pull-to-refresh triggers fresh fetch. |

**Alternative flows:**
4a. No workout history (new user): progress ring 0%, streak "Start a streak", leaderboard "Add friends", rewards show first milestone.
4b. Offline: subsystem loads cached data; banner "You're offline"; pull-to-refresh shows connection message; Start Workout still works.
4c. Screen-time balance depleted (0): card red with message to complete workout; notice if blocking active.
4d. Streak at risk (past 6 PM, no workout today): streak section shows amber warning.
4e. Weekly goal achieved: ring 100%, celebratory message.
4f. Data loading error: subsystem shows loaded sections and "Tap to retry" for failed sections.
4g. VIP user: additional Weekly Insights section with AI tips.

**Special Requirements:**
<ToDo: List the non-functional requirements: dashboard default landing after login; weekly progress reset Monday 00:00 UTC; balance color thresholds (green >60, yellow 15–60, red <15 min); cache TTL 5 min; pull-to-refresh bypasses cache; greeting by time of day; Today's Workout from plan schedules; VIP-only AI insights; NEW badge until user taps. />
