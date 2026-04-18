Use case Id: UC15    Streaks & Rewards Subsystem

**Brief Description**
The subsystem tracks consecutive daily workout completions (streaks) and evaluates eligibility for rewards and achievements. Streaks incentivize daily exercise; rewards give milestone recognition. Subsystem evaluates daily, awards badges/trophies, and grants bonus benefits. Users view streak history, earned rewards, and progress to upcoming achievements.

**Primary actors**
Authenticated User, Subsystem (automated evaluation)

**Preconditions:**
1. User is authenticated.
2. User has logged at least one workout (for streak tracking to begin).

**Post-conditions:**
- Streak update: profiles reflects current_streak, last_workout_date; if broken, streak_history and longest_streak preserved.
- Reward: user_rewards updated; tangible benefits applied; notifications sent.

**Main Success Scenario:**
<ToDo: List the included use cases. Add rows to the table below if needed />

| Actor Action | Subsystem Response |
|--------------|-----------------|
| 1. (Nightly) At midnight user local time, subsystem evaluates each user: did they log a qualifying workout (≥5 min, plan ≥50% or ad-hoc) yesterday? | 2. If yes: increment streak, update profiles (current_streak, last_workout_date, longest_streak if applicable), evaluate rewards (MF-2). If no: reset streak to 0, update profiles, send "Streak ended"; VIP with freeze may consume freeze and preserve streak. |
| 3. When user logs a workout same day: display updates (e.g. streak+1 or "Day 1 of your new streak!"). | 4. Subsystem evaluates reward_definitions; for each unmet reward whose criteria are met, inserts user_rewards, sends notification, applies benefits (e.g. bonus screen-time). |
| 5. User opens Streaks & Rewards screen. | 6. Subsystem shows: Current Streak (flame, count, longest, VIP freeze status), 90-day calendar heatmap; Rewards grid (earned/locked with progress); Next Milestones (top 3 with progress bars). Tapping reward shows criteria, progress, date earned, benefits. |

**Alternative flows:**
2a. Streak broken after long run (e.g. 30+ days): subsystem sends empathetic notification and records in streak_history.
2b. VIP streak freeze: if missed day and freeze available, consume freeze and preserve streak; notify remaining freezes.
2c. No freezes left (VIP): streak resets; notify.
2d. Timezone change: use device/profile timezone; 2-hour grace after midnight for fairness.
2e. Offline sync after midnight: if sync within 2 hours, credit previous day and preserve streak.
4a. Multiple rewards from one workout: award all; single notification listing them; "NEW" on rewards screen.
6a. New rewards in app update: retroactive evaluation on first launch; qualifying rewards awarded with "Retroactive Achievement" notification.

**Special Requirements:**
<ToDo: List the non-functional requirements: qualifying workout ≥5 min; plan-based ≥50% completion; ad-hoc always qualifies; evaluation at midnight local; 2-hour grace; VIP 2 freezes/month, auto-consumed, no rollover; longest_streak never decremented; rewards permanent; bonus screen-time credited immediately; badges/frames on profile; Legend (365-day) permanent 5% bonus; Perfect Week Monday midnight; Ironclad Month 1st midnight; multiple rewards per workout allowed; retroactive evaluation once per update with new rewards. />
