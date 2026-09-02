# Task 3 — Make points, streaks, private leaderboards, rewards, and achievements work

**Assigned to:** Developer 3  
**Type:** Feature requirements and user-flow handoff  
**Status:** Ready for research

## Purpose

Turn Nashaat’s motivation layer into a reliable product loop. A user completes a qualifying workout, receives understandable progress, builds a streak, competes privately with friends, and earns recognition or useful rewards—especially screen time that fits Nashaat’s core purpose.

The first version must be simple enough to understand and trustworthy enough that users believe the result. Points, streaks, leaderboard scores, rewards, and achievements must not depend only on local client state.

## Existing product context

The repository already has related foundations:

- `profiles.streak_count` and `profiles.last_workout_date`
- `workout_logs` with completed workout records and earned screen-time minutes
- `screen_time_transactions` as the screen-time ledger
- `friendships` with pending/accepted/rejected relationships
- `leaderboards` with private invite codes
- `leaderboard_members.weekly_score`
- `user_rewards` for unlocked reward records
- Notification records for user-facing updates

Relevant references:

- [Private leaderboard use case](../diagrams/use-case-specs/13-private-leaderboards.md)
- [Streaks and rewards use case](../diagrams/use-case-specs/15-streaks-rewards.md)
- [Enhanced gamification notes](../diagrams/use-case-specs/22-enhanced-gamification.md)
- [Database schema](../db/schema.sql)
- [Social feature](../../lib/features/social/)
- [Gamification-related entities](../../lib/core/entities/)

The current schema is a foundation, not a complete points-and-achievements system. For example, `user_rewards` records an unlocked title and description but does not define achievement criteria, and there is no obvious points ledger in the base schema. Propose the smallest reliable data change needed; do not pretend that client-side counters are sufficient.

## Required first-version scope

The feature must include all of the following:

1. Points earned from qualifying activity, with a visible balance or total and an understandable reason for each award.
2. Daily workout streaks with current streak, longest streak, and clear next-day guidance.
3. Private weekly leaderboards limited to the user’s permitted friends/board members.
4. Rewards and achievements, including progress toward locked achievements and a clear result when one unlocks.
5. A useful connection to screen-time earning where the reward definition calls for it.

Do not expand the first version into a complex XP/level/challenge economy unless research shows it is necessary and the scope is explicitly agreed. Points and screen-time minutes are different concepts: points motivate and rank users; screen-time changes must go through the existing screen-time transaction model.

## Research assignment

1. Review at least four fitness, habit, or focus products for points, streaks, private competition, achievement presentation, and reward feedback.
2. Identify what makes a reward motivating without making the app feel punitive or addictive. Note useful patterns and possible failure modes.
3. Research simple scoring models and recommend one. Start from the existing private-leaderboard candidate formula as a hypothesis, but validate whether it is understandable and fair.
4. Define a qualifying workout for points and streaks. Account for partial completion, duplicate logs, edited/deleted logs, workouts logged offline, and timezone boundaries.
5. Define a small initial achievement set with criteria, progress behavior, unlock behavior, and whether the reward is recognition, points, or bonus screen time.
6. Define the weekly leaderboard period, tie handling, friend/privacy behavior, and reset behavior.
7. Keep a research log with sources, decisions, rejected alternatives, and open risks.

The result should be a short, testable rules table. Every number or rule must have a reason and a way to verify it.

## Concept-art assignment

Use an image generator to create concept screens for the complete motivation loop:

- Dashboard summary showing points, current streak, and screen-time balance
- Gamification/rewards hub
- Streak detail with calendar or history
- Private leaderboard with friend avatars, scores, rank, and weekly period
- Create/join private leaderboard flow
- Achievement grid with locked, in-progress, and unlocked states
- Achievement detail with criteria and progress
- Reward unlock/result state showing what the user received
- Empty and error states for no friends, no leaderboard, and unavailable data

Suggested prompt pattern:

> Mobile fitness motivation UI concept for Nashaat, where completed workouts earn screen time. Show [screen and primary action] with points, streak progress, private friends leaderboard, or achievement feedback. Use clear privacy cues, readable hierarchy, encouraging language, accessible contrast, and a polished [chosen visual direction] style. No logos, copyrighted characters, or readable fake text. Concept art for product planning, not a final screenshot.

Save the prompts with the concepts and record which interaction and visual decisions are being carried into Flutter.

## Feature requirements

### Points

- A qualifying workout or other explicitly approved action awards points once.
- The user can see how many points were earned and why, such as completed workout, consistency bonus, or achievement bonus.
- The points rule is stable, documented, and understandable without reading technical code.
- Repeating the same server event must not award points twice.
- Editing or deleting a workout must follow a documented policy; it must not create a way to farm points.
- Points may contribute to the private leaderboard, but the leaderboard must show the scoring period and what the score represents.

### Streaks

- A streak represents consecutive qualifying workout days, not merely opening the app.
- The user can see current streak, longest streak, last qualifying day, and what action protects or starts the next day.
- Completing a qualifying workout updates the visible streak promptly after the workout is accepted.
- Missing a qualifying day follows the documented timezone and grace-period rule. The rule must be consistent and testable.
- A broken streak is explained respectfully and does not erase the historical longest streak.
- Offline sync and duplicate workout submissions follow an explicit policy.

### Private friend leaderboards

- A user can view a weekly leaderboard that is private to the permitted group.
- The screen shows the period, the score definition, the user’s rank, nearby entries, and enough detail to understand progress.
- Only accepted friends or explicitly permitted private-board members can see the leaderboard’s user data. There is no accidental public/global ranking.
- Users can create or join a private board through a clear flow. If invite-code membership and accepted friendships are different concepts, document the relationship and enforce it consistently.
- The UI handles no friends, one friend, ties, removed friends, no workouts, loading, stale data, and network failure.
- Weekly reset behavior is documented. Previous results may be summarized, but do not imply historical rankings are stored unless they actually are.
- Users can leave a board or hide their participation according to the chosen privacy rule.

### Rewards and achievements

- Achievements have a name, description, category, criteria, icon/visual treatment, and locked/in-progress/unlocked state.
- The user can see progress toward the next useful achievements rather than only a list of already-earned badges.
- Achievement unlocks are idempotent: one achievement produces one user unlock even if an event is retried.
- The app explains the result immediately after an unlock and can surface it later in the rewards area or notification center.
- Rewards are explicit about what the user receives. A screen-time reward must create the appropriate ledger entry and update the available balance through the existing economy flow.
- The initial set should cover consistency, completing workouts, social participation, and meaningful milestones without requiring a large content-management system.
- If a reward requires a claim or confirmation, the UI makes that action clear. If it is automatic, the UI says so.

## Suggested initial rule decisions to validate through research

These are starting points for the developer to test and refine, not permission to add complexity silently:

- Award points only after a workout log has been accepted by the server.
- Count one qualifying workout per calendar day toward a streak; define the minimum duration or completion threshold.
- Use the existing weekly private-board model for the first leaderboard release.
- Prefer automatic achievement unlocks and automatic ledger-backed screen-time benefits over a complicated reward shop.
- Keep score breakdowns visible so users can predict how their actions affect rank.

## User flows

### Complete a workout and receive progress

Choose workout → complete qualifying session → save workout log → server evaluates points, streak, achievements, leaderboard score, and screen-time earning → app shows a single result summary → user can open the detailed breakdown.

The summary must distinguish points, streak progress, achievements, and screen-time minutes. A failed notification must not undo a recorded reward.

### View personal progress

Dashboard → tap points/streak/rewards summary → view current streak, longest streak, points, recent awards, and next achievement → tap an item for its criteria and history → return to a workout or blocking action.

### View the private leaderboard

Social/leaderboard area → choose private board → view current week and ranking → inspect score breakdown or a friend summary → return to the leaderboard or start a workout.

### Create or join a private board

Leaderboard area → create board or enter invite code → confirm privacy and members → board appears in the user’s private list → user can view or leave it later.

### Unlock an achievement or reward

Qualifying event → criteria met → achievement/reward is recorded once → user sees unlock feedback and benefit → rewards screen shows unlocked date, criteria, and any screen-time transaction.

### Miss or break a streak

User opens app after a missed qualifying day → app explains the current state and preserved longest streak → user receives a constructive next action → a new qualifying workout starts or continues a new streak according to the documented rule.

## Simple technical guidance

- Use the existing workout log and screen-time transaction flows as the source events. Do not award points or screen time from a button press that has not produced a valid workout record.
- Keep authoritative calculations on Supabase/server-side logic or another trusted boundary. The Flutter client may display results but must not be able to award arbitrary points or minutes.
- Make event handling idempotent. Retries, app restarts, and duplicate submissions must not duplicate points, achievements, leaderboard score, or screen-time credit.
- Use Row-Level Security so users can read their own progress and only the private friend/board data they are allowed to see.
- The smallest data model should support point awards/history, achievement definitions and progress, user unlocks, leaderboard period/score, and reward/ledger references. Document any migration or RPC needed before implementation.
- Reuse existing `LeaderboardEntity`, `LeaderboardMemberEntity`, `UserRewardEntity`, friendship repositories, and shared UI patterns where they fit. Extend them when the current fields are insufficient rather than hiding missing data in arbitrary JSON.
- Keep the first release simple. A clear points ledger plus a small achievement catalog is preferable to multiple overlapping currencies and counters.

## Deliverables

- Research log and scoring/privacy comparison
- Final rules table for points, streaks, leaderboard periods, achievements, and rewards
- Concept-art screens and image-generator prompts
- Working progress, streak, private leaderboard, rewards, and achievements flows
- Required schema/RLS/RPC/migration notes
- Notification and failure behavior notes
- Focused tests or reproducible manual checks for duplicate events, privacy, weekly reset, streak boundaries, achievement unlocks, and screen-time ledger updates

## Acceptance criteria

- Completing one qualifying workout produces the documented points, streak, leaderboard, achievement, and screen-time outcomes exactly once.
- Users can understand why they received points or a reward.
- Streak behavior is consistent across same-day, next-day, missed-day, timezone, offline-sync, and duplicate-event cases covered by the rules.
- Private leaderboards show only permitted users and handle ties, empty states, removed members, and weekly reset correctly.
- Achievements can be locked, in progress, and unlocked; unlocks are persisted and cannot duplicate.
- Screen-time rewards use the existing transaction ledger and cannot be granted by arbitrary client input.
- A failed notification or refresh does not erase an already recorded result.
- Concept art and the final rules are included with the implementation handoff.

## Out of scope for the first version

- Public/global leaderboards
- A large marketplace or spendable points economy
- XP levels, complex challenges, or streak freezes unless separately approved
- Competitive features that expose users outside their private friend/board context
- Client-only gamification state that is not recoverable from Supabase
