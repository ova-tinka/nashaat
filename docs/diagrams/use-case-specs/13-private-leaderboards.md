Use case Id: UC13    Private Leaderboards

**Brief Description**
Authenticated users view their ranking among friends on private leaderboards. The subsystem aggregates workout data, scores by frequency/duration/consistency, and ranks within the friend group. Leaderboards reset weekly. (MVP: no historical snapshots; scores reset to zero each week.)

**Primary actors**
Authenticated User, Subsystem (automated scoring)

**Preconditions:**
1. User is authenticated.
2. User has at least one accepted friend (Use Case 14).
3. Device has active internet connection.

**Post-conditions:**
1. User has viewed current leaderboard; data cached locally.
2. Weekly winners recorded; reset and achievement notifications sent.

**Main Success Scenario:**
<ToDo: List the included use cases. Add rows to the table below if needed />

| Actor Action | Subsystem Response |
|--------------|-----------------|
| 1. User navigates to Leaderboard tab. | 2. Subsystem queries leaderboard_members for current week weekly_score for user and friends. |
| 3. — | 4. Subsystem displays Weekly Leaderboard: header (week dates, "Resets in X"); podium (top 3 with avatars, scores, medals); full ranking list (rank, avatar, name, score, change indicator); user summary card (rank, score, points to next rank, workout count). |
| 5. User taps a row to view score breakdown. | 6. Subsystem shows Score Detail modal: total score, breakdown (workouts×10, duration/10, streak bonus, consistency bonus), friend's weekly summary. |
| 7. (Background) Monday 00:00 UTC. | 8. Subsystem resets weekly_score to 0 for all; notifies last week's winner; adds "Weekly Champion" badge for winner. |

**Alternative flows:**
2a. Data loading error: subsystem shows cached data with "Pull to refresh" or "Tap to retry."
4a. No friends: empty state "Add friends to compete!" with "Add Friends" button; user sees own score only.
4b. Only one friend: leaderboard shows both; simplified podium.
4c. Tied scores: tiebreak by workout count then earliest last workout; same rank, next skipped.
4d. Friend removed mid-week: friend removed from leaderboard immediately.
4e. User has no workouts this week: score 0 with nudge "Log a workout to start climbing!"
4f. Very large friend group (>50): lazy load 20 at a time; user's row pinned at bottom.

**Special Requirements:**
<ToDo: List the non-functional requirements: private (user + friends only); score = (workouts×10) + (duration/10) + streak_bonus + consistency_bonus; streak bonus 5 if streak≥7; consistency 10 if goal met by Wednesday; real-time recalc on workout log; reset Monday 00:00 UTC; tiebreaker rules; Weekly Champion badge; duration cap 180 min/workout; cache TTL 2 min; weekly summary notification Monday 8 AM local. />
