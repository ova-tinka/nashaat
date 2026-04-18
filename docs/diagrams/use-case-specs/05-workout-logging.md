Use case Id: UC05    Workout Logging

**Brief Description**
An authenticated user logs a workout via (1) Live Workout Session—guided exercise-by-exercise with timers and rest—(2) Quick Complete for an already-done workout, or (3) Ad-Hoc log (type, duration, intensity). Subsystem calculates earned screen-time, updates balance, and records for streaks and leaderboards.

**Primary actors**
Authenticated User

**Preconditions:**
1. User is authenticated and has at least one active workout plan (for plan-based logging) or is logging ad-hoc.
2. User has not already logged this plan for the current day (unless scheduled twice).

**Post-conditions:**
1. Workout log exists in workout_logs with completion mode.
2. Screen-time balance increased by calculated amount; screen_time_transactions record created.
3. Streak and weekly leaderboard score updated.
4. Notification sent; dashboard shows updated balance, workout status, and streak.

**Main Success Scenario:**
<ToDo: List the included use cases. Add rows to the table below if needed />

| Actor Action | Subsystem Response |
|--------------|-----------------|
| 1. User selects "Start Workout" on a plan and chooses "Start Live Workout", "Mark as Complete", or "Log Ad-Hoc Instead". | 2. Subsystem presents Workout Launch (plan summary and three options) or Ad-Hoc form. |
| 3. Live: User follows guided session (Set Done, rest skip/adjust, next exercise). Quick: User submits duration and intensity. Ad-Hoc: User submits type, duration, intensity. | 4. Subsystem runs timers/rest, records sets completed; or accepts quick/ad-hoc inputs; validates duration ≥5 min and ≤180 min. |
| 5. User completes session or form and views Workout Summary (earned screen-time, balance, streak). | 6. Subsystem calculates screen-time (base 2 min per 1 min exercise × intensity × streak/VIP bonuses), shows summary with breakdown. |
| 7. User selects "Done". | 8. Subsystem persists workout_logs, updates balance, creates screen_time_transactions, updates streak and leaderboard, sends notification. |

**Alternative flows:**
2a. Duplicate plan log today: subsystem prompts; user can log ad-hoc instead.
2b. Daily workout limit (5) reached: subsystem blocks new workout.
4a. Partial live session (Finish Early): subsystem offers "Log Partial Workout" or "Resume"; partial counts for streak only if ≥50% sets completed.
4b. Pause & resume: timer pauses; overlay shows Resume/Finish Early/Discard; backgrounded >5 min triggers notification; >30 min auto-saves partial.
4c. Skip exercise: user confirms skip; exercise not counted; session continues.
4d. Screen lock toggle during live session: touch disabled except unlock (tap-and-hold to exit).
6a. Duration <5 min: subsystem prompts to continue (live) or disables submit (quick/ad-hoc).
6b. Duration >180 min: subsystem caps credited duration at 180 min and notifies.
6c. Daily screen-time cap (480 min) reached: workout logged but no extra screen-time.
8a. Network error on submit: workout saved locally and synced when online.

**Special Requirements:**
<ToDo: List the non-functional requirements: minimum 5 min workout to earn; max 180 min credited per session; base rate 1 min exercise = 2 min screen-time; intensity multipliers; streak/VIP bonuses; daily cap 480 min; max 5 logs/day; partial streak rule ≥50%; offline sync within 48 hours; live session UX (large touch targets, haptics, audio cues). />
