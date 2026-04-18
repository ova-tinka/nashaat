# Use Case 05: Log Workout & Earn State/Interface-Time

## Title
Log Workout & Earn State/Interface-Time (Includes Live Workout Session)

## Actor
Authenticated User

## Description
An authenticated user logs a workout and earns screen-time credits. There are three paths to log a workout:

1. **Live Workout Session** — The user follows a guided, exercise-by-exercise real-time session with timers, rep counters, set looping, and rest countdowns. The app coaches them through each exercise and set in sequence.
2. **Quick Complete** — The user has already finished the workout (e.g., at the gym without the app) and wants to immediately mark the plan as done without going through the live flow.
3. **Ad-Hoc Log** — The user logs an unplanned workout by entering type, duration, and intensity manually.

After any path, the system calculates earned screen-time, updates the balance, and records the workout for streaks and leaderboard tracking.

## Preconditions
1. The user is authenticated and has an active session.
2. The user has at least one active workout plan (for plan-based logging) OR is logging an ad-hoc workout.
3. The user has not already logged this specific plan for the current day (unless it is scheduled twice).

## Main Flow

### MF-1: Starting a Workout (Entry Point)
1. The user proceeds to the **Dashboard** or **Workout Plans** interface.
2. The user selects **"Start Workout"** on a specific plan.
3. The system provides the **Workout Launch** interface showing:
   - Plan name and summary (exercise count, estimated duration)
   - Full exercise list preview with sets/reps/duration for each
   - Three action buttons:
     - **"Start Live Workout"** (primary, prominent) — enters the guided live session
     - **"Mark as Complete"** (secondary) — quick-complete for users who already finished
     - **"Log Ad-Hoc Instead"** (tertiary text link) — switches to the ad-hoc form
4. The user selects one of the three paths (see MF-2, MF-3, or MF-4).

---

### MF-2: Live Workout Session (Guided Exercise-by-Exercise Flow)

#### Phase A: Session Initialization
1. The user selects **"Start Live Workout"**.
2. The system enters the **Live Session** screen:
   - A 5-second countdown ("Get Ready...") before the first exercise begins.
   - The overall session timer starts at 00:00 and runs for the entire workout.
   - The screen enters a workout-optimized layout with large touch targets and a screen lock toggle.

#### Phase B: Exercise Execution Loop
3. The system returns or provides the **Active Exercise Card** for the first exercise:
   - **Header bar**: Overall elapsed time | Current progress ("Exercise 1 of 8") | Pause button | Lock button
   - **Exercise name**
   - **Demo visual**: Thumbnail/animation of the exercise (if available)
   - **Set indicator**: "Set 1 of 3"
   - **Target display** (depends on exercise type):
     - **Rep-based exercise**: Shows target reps (e.g., "12 reps") with a large **"Set Done"** button
     - **Time-based exercise**: Shows a countdown timer (e.g., "0:45") that auto-starts and counts down to zero with audio/haptic cues at completion
   - **Notes**: Any user-added notes for this exercise (e.g., "Use 40kg dumbbells")
   - **Navigation**: "Skip Exercise" text link at the bottom

4. **For rep-based exercises:**
   a. The user performs the reps physically.
   b. The user selects **"Set Done"** when the set is complete.
   c. The system records the set as completed and advances (see Step 6).

5. **For time-based exercises:**
   a. The countdown timer starts automatically when the exercise card appears.
   b. The user can tap **"Pause"** to pause the countdown (e.g., to adjust position).
   c. When the timer reaches 0:00:
      - A short vibration + audio chime plays.
      - The system auto-completes the set and advances (see Step 6).
   d. The user can also tap **"Set Done"** early to manually end the set before the timer runs out.

6. **Set Completion & Looping:**
   a. After a set is completed, the system checks if there are more sets remaining for the current exercise.
   b. **If more sets remain** (e.g., completed Set 1 of 3):
      - The system starts a **Rest Timer** countdown (using the configured rest duration for this exercise, default 60 seconds).
      - The Rest Timer screen shows:
        - "Rest" label with the countdown (e.g., "0:47")
        - Current exercise name and which set is next ("Next: Set 2 of 3")
        - **"Skip Rest"** button to immediately start the next set
        - **"+15s"** and **"-15s"** buttons to adjust rest time on the fly
        - A preview of the next set's target (reps or duration)
      - When the rest timer reaches 0:00, a vibration + chime plays.
      - The system loops back to Step 3, displaying the **same exercise** with the set indicator updated (e.g., "Set 2 of 3").
   c. **If all sets for this exercise are complete** (e.g., finished Set 3 of 3):
      - The exercise is marked as done with a checkmark animation.
      - A brief "Exercise Complete!" toast appears (1 second).
      - The system checks if there are more exercises in the plan.

7. **Exercise Transition:**
   a. **If more exercises remain:**
      - The system starts a **Rest Timer** (using the configured rest between exercises, default 90 seconds).
      - The Rest Timer screen shows:
        - "Rest" label with the countdown
        - **"Up Next"** preview: Next exercise name, sets x reps, thumbnail
        - **"Skip Rest"** button
        - **"+15s"** / **"-15s"** buttons
      - When rest ends, the system advances to the **next exercise**, looping back to Step 3 with the new exercise loaded and set indicator reset to "Set 1 of N".
   b. **If this was the last exercise:**
      - The session auto-completes (see Phase C).

8. **Mid-Session Progress Bar:**
   - A thin progress bar runs along the top or bottom of the screen, filling proportionally as sets are completed across all exercises.
   - Example: Plan has 8 exercises, 3 sets each = 24 total sets. After completing 12 sets, the bar shows 50%.

#### Phase C: Session Completion
9. After the final set of the final exercise:
   - The overall session timer stops.
   - The system provides a brief **"Workout Complete!"** animation (2 seconds, full interface with confetti).
10. The system proceeds to the **Workout Summary** (see MF-5).

---

### MF-3: Quick Complete (Already Finished the Workout)
1. The user selects **"Mark as Complete"** on the Workout Launch screen.
2. The system returns or provides a **Quick Complete Form**:
   - "How long did your workout take?" — Duration input in minutes (pre-filled with the plan's estimated duration)
   - "How intense was it?" — Low / Medium / High selector (default: Medium)
   - "Did you complete all exercises?" — Toggle (default: Yes)
     - If No: "How many did you complete?" — Number input or slider (1 to total exercises)
   - Optional: "Any notes?" — Text field
3. The user fills in the details and selects **"Submit"**.
4. The system validates (duration >= 5 minutes).
5. The system proceeds to the **Workout Summary** (see MF-5).

---

### MF-4: Ad-Hoc Workout Log
1. The user selects **"Log Ad-Hoc Instead"** from the Workout Launch screen, OR selects **"Log Ad-Hoc Workout"** from the Dashboard.
2. The system returns or provides the **Ad-Hoc Workout Form**:
   - Workout Type: Cardio / Strength / Flexibility / HIIT / Sports / Other (required)
   - Duration (minutes): Number input (required)
   - Intensity: Low / Medium / High (required)
   - Description (optional, e.g., "30-minute jog in the park")
3. The user provides the data and submits the **"Submit"** request.
4. The system validates (duration >= 5 minutes, duration <= 180 minutes).
5. The system proceeds to the **Workout Summary** (see MF-5).

---

### MF-5: Workout Summary & State/Interface-Time Calculation (Shared Completion Flow)
1. The system calculates earned screen-time:
   - **Base rate**: 1 minute of exercise = 2 minutes of screen-time.
   - **Intensity multiplier**: Low = 1.0x, Medium = 1.25x, High = 1.5x.
   - **Streak bonus**: +10% if active streak >= 7 consecutive days.
   - **VIP bonus**: +20% if the user has an active VIP subscription.
   - **Formula**: `screen_time = duration * 2 * intensity_multiplier * (1 + streak_bonus) * (1 + vip_bonus)`
   - **Example**: 30 min, high intensity, 10-day streak, VIP = 30 * 2 * 1.5 * 1.1 * 1.2 = 118.8 → rounded to **119 minutes**.
   - For live sessions, duration is the actual session timer value. For quick complete/ad-hoc, duration is the user-entered value.
   - For live sessions, intensity is auto-determined based on rest-to-work ratio and exercise categories (can be overridden by user on the summary screen before confirming).

2. The system provides the **Workout Summary** interface:
   - Completion mode badge: "Live Session" / "Quick Complete" / "Ad-Hoc"
   - Total duration
   - Exercises completed and total sets completed (for plan-based)
   - State/Interface-time earned
   - Breakdown: Base earned, intensity multiplier, streak bonus, VIP bonus
   - New screen-time balance (after adding earnings)
   - Streak status (e.g., "Day 11!" with flame animation)
   - Animated celebration (confetti or particles)
   - **"Adjust Intensity"** link — allows user to override the auto-detected intensity before finalizing (live sessions only)

3. The user selects **"Done"** to confirm and return to the dashboard.

4. The system persists the workout:
   a. Inserts a record into `workout_logs` with: user ID, plan ID (if applicable), duration, screen-time earned, and the `completed_exercises` JSONB array (which tracks exactly what was accomplished), plus optional notes.
   b. Updates the user's screen-time balance in the `profiles` table.
   c. Inserts a `screen_time_transactions` record (type: `earned`).
   d. Evaluates and updates the user's streak (see Use Case 15).
   e. Updates the user's leaderboard score for the current week.
   f. Triggers a notification: "You earned [X] minutes of screen-time!" (see Use Case 12).

---

## Alternative Flows

### AF-1: Partial Live Session (Finish Early)
- **Branches from:** MF-2, Phase B (any step)
- The user selects **"Finish Early"** (accessible via the pause menu).
- The system returns a prompt: "You completed [X] of [Y] exercises ([A] of [B] total sets). Do you want to log this partial workout?"
- Buttons: **"Log Partial Workout"** and **"Resume Workout"**.
- If logged: screen-time is calculated based on actual elapsed time and exercises completed. The workout is flagged as `partial: true`.
- Partial workouts count toward streaks only if at least 50% of total sets are completed.

### AF-2: Pause & Resume Live Session
- **Branches from:** MF-2, Phase B (any step)
- The user selects the **Pause** option (or the physical power button / app goes to background).
- The session timer pauses. The exercise timer (if time-based) pauses.
- The system returns or provides the **Paused** overlay:
  - Elapsed time (frozen)
  - Progress so far (exercises and sets completed)
  - **"Resume"** action
  - **"Finish Early"** action
  - **"Discard Workout"** button (destructive, with confirmation)
- Paused time is NOT counted toward workout duration.
- If the app is backgrounded, the pause persists. A local notification is sent after 5 minutes: "Your workout is paused. Tap to resume."
- If the user does not return within 30 minutes, the session auto-saves as a partial workout.

### AF-3: Skip Exercise in Live Session
- **Branches from:** MF-2, Step 3 (navigation)
- The user selects **"Skip Exercise"** on the Active Exercise Card.
- The system returns a prompt: "Skip [Exercise Name]? It won't count toward your workout."
- If confirmed: The exercise is marked as skipped (not completed). The system advances to the next exercise.
- Skipped exercises reduce the total completed count but do not stop the session timer.

### AF-4: Navigate Back to Previous Exercise
- **Branches from:** MF-2, Phase B
- The user swipes right or selects the **"Previous"** option.
- The system returns to the previous exercise.
- If the previous exercise was already completed, the system shows it in a "completed" state with an option to **"Redo Exercise"**.
- Redoing an exercise does not earn double credit — it replaces the previous completion data for that exercise.

### AF-5: Workout Duration Below Minimum
- **Branches from:** MF-5, Step 1
- The total workout duration is less than 5 minutes (across any completion path).
- The system returns a prompt: "Workouts must be at least 5 minutes long to earn screen-time. Keep going!"
- For live sessions: the user is returned to the active session to continue.
- For quick complete/ad-hoc: the submit button is disabled until duration >= 5.

### AF-6: Workout Duration Exceeds Maximum
- **Branches from:** MF-5, Step 1
- The total duration exceeds 180 minutes.
- The system caps the credited duration at 180 minutes.
- The system returns a prompt: "Great workout! State/Interface-time is calculated for up to 180 minutes per session."

### AF-7: Duplicate Workout Log for Today
- **Branches from:** MF-1, Step 2
- The user tries to start a plan that was already completed today.
- The system returns a prompt: "You've already completed '[Plan Name]' today. You can log an ad-hoc workout instead."
- Buttons: **"Log Ad-Hoc"** and **"Cancel"**.

### AF-8: Daily State/Interface-Time Earning Cap Reached
- **Branches from:** MF-5, Step 1
- The user has already earned 480 minutes (8 hours) today.
- The system returns a prompt: "You've reached today's maximum screen-time earnings. The workout is still logged for your streak and stats."
- The workout is recorded but no additional screen-time is credited.

### AF-9: Daily Workout Log Limit Reached
- **Branches from:** MF-1, Step 2
- The user has already logged 5 workouts today.
- The system returns a prompt: "You've reached the daily workout limit (5 per day). Come back tomorrow!"
- No new workout can be started.

### AF-10: App Backgrounded During Live Session
- **Branches from:** MF-2, Phase B
- The user backgrounds the app (home button, notification tap, phone call).
- The session timer continues in the background for up to 5 minutes.
- A persistent notification shows: "Workout in progress — [elapsed time]".
- If the user returns within 5 minutes, the session continues seamlessly.
- If the user does not return within 5 minutes, the session auto-pauses (see AF-2).

### AF-11: Network Error on Submission
- **Branches from:** MF-5, Step 4
- The system cannot reach Supabase.
- The workout data is saved locally on the device.
- The system returns a prompt: "Workout saved locally. It will sync when you're back online."
- On next app launch with connectivity, the system syncs pending workout logs.

### AF-12: State/Interface Lock Toggle During Live Session
- **Branches from:** MF-2, Phase B
- The user selects the **Lock** option in the header.
- The screen enters **Lock Mode**: all touch input is disabled except for a small unlock button in the corner.
- This prevents accidental taps during physical activity.
- The user taps and holds the unlock button (1 second) to exit lock mode.

### AF-13: View Exercise Queue During Live Session
- **Branches from:** MF-2, Phase B
- The user swipes up or selects the **"View All"** option.
- The system returns or provides an **Exercise Queue** overlay showing all exercises in order:
  - Completed exercises with checkmarks
  - Current exercise highlighted
  - Upcoming exercises with set/rep info
  - Skipped exercises marked
- The user can tap on any upcoming exercise to jump to it (with a "Skip to this exercise?" confirmation).

### AF-14: Quick Complete with Partial Exercises
- **Branches from:** MF-3, Step 2
- The user toggles "Did you complete all exercises?" to **No**.
- A slider or number input appears for how many exercises were completed.
- Partial quick-completes count toward streaks only if at least 50% of exercises were completed.

### AF-15: Adjust Rest Timer Preferences Mid-Session
- **Branches from:** MF-2, Step 6b or Step 7a
- During any rest period, the user selects **"+15s"** or **"-15s"** to adjust the current rest countdown.
- The user can also tap **"Set Default"** to update the rest duration for all remaining rest periods in this session (does not modify the saved plan).

---

## Postconditions
1. A workout log record exists in the `workout_logs` table with the completion mode recorded.
2. The user's screen-time balance is increased by the calculated amount.
3. A `screen_time_transactions` record exists with the earnings detail.
4. The user's streak is updated (maintained, incremented, or reset).
5. The user's weekly leaderboard score is updated.
6. A notification confirming the earned screen-time has been sent.
7. The dashboard reflects the updated balance, workout status, and streak.

## Business Rules

| Rule ID | Rule Description |
|---------|-----------------|
| BR-01 | Three workout completion modes exist: Live Session, Quick Complete, and Ad-Hoc. All earn screen-time using the same formula. |
| BR-02 | Minimum workout duration to earn screen-time is 5 minutes (all modes). |
| BR-03 | Maximum creditable workout duration per session is 180 minutes (all modes). |
| BR-04 | Base screen-time earning rate: 1 minute of exercise = 2 minutes of screen-time. |
| BR-05 | Intensity multipliers: Low = 1.0x, Medium = 1.25x, High = 1.5x. |
| BR-06 | Streak bonus: +10% if active streak >= 7 consecutive days. |
| BR-07 | VIP bonus: +20% for active VIP subscribers. |
| BR-08 | Earned screen-time is rounded to the nearest whole minute. |
| BR-09 | Daily screen-time earning cap is 480 minutes (8 hours). |
| BR-10 | Maximum of 5 workout logs per day across all modes and plans. |
| BR-11 | A user cannot log the same plan more than once per day unless it is explicitly scheduled twice. |
| BR-12 | Partial workouts (live or quick complete) count toward streaks only if at least 50% of sets/exercises are completed. |
| BR-13 | Ad-hoc workouts always count toward streaks regardless of completion. |
| BR-14 | State/Interface-time balance cannot be negative; it is floored at 0. |
| BR-15 | All earned screen-time amounts and bonus breakdowns are stored in the workout log for audit. |
| BR-16 | Offline workout logs must sync within 48 hours; after that, they expire and are discarded. |
| BR-17 | Live session paused time is NOT counted toward workout duration. |
| BR-18 | Live session auto-pauses after 5 minutes in background; auto-saves as partial after 30 minutes paused. |
| BR-19 | Default rest between sets: 60 seconds. Default rest between exercises: 90 seconds. Both are adjustable mid-session. |
| BR-20 | Time-based exercise timers auto-start when the exercise card appears and auto-complete the set when reaching 0. |
| BR-21 | For live sessions, intensity is auto-detected from the rest-to-work ratio and exercise categories, but can be overridden by the user on the summary screen. |
| BR-22 | Skipped exercises in live sessions are not counted toward completed exercises but the session timer still runs. |
| BR-23 | State/Interface lock mode disables all touch input except the unlock button to prevent accidental taps during exercise. |

## UI/UX Notes

### Live Session State/Interface
- The live session must be designed for **in-workout use**: large fonts, high-contrast colors, minimal clutter, huge touch targets (minimum 56x56dp).
- The **overall session timer** should be always visible in the top bar, running continuously.
- The **Active Exercise Card** should dominate the screen (80%+ of viewport), showing only the current exercise.
- For **rep-based exercises**, the "Set Done" button should be massive (full-width, at least 64dp tall) and easy to tap with sweaty hands.
- For **time-based exercises**, the countdown timer should be the central visual element with large digits (48sp+), a circular progress ring, and a pulsing animation in the last 5 seconds.
- **Rest periods** should have a calming visual style (darker background, slower animations) contrasting with the active exercise energy.
- The **set loop indicator** (e.g., "Set 2 of 3") must be prominent so the user always knows where they are.
- **Haptic feedback** (vibration) should fire on: set completion, exercise completion, rest timer end, countdown at 3-2-1, and workout completion.
- **Audio cues**: short beep at rest end, triple beep at countdown 3-2-1, celebratory sound at workout completion. Audio should work even when the phone is on silent (using the alarm audio channel).
- The **progress bar** (sets completed / total sets) should provide a constant sense of advancement.

### Quick Complete
- The Quick Complete form should be fast and minimal — completable in under 10 seconds.
- Pre-fill duration with the plan's estimated duration to minimize input.
- Use a large segmented control for intensity (Low / Medium / High) for quick one-tap selection.

### Workout Launch State/Interface
- **"Start Live Workout"** should be the most visually prominent action.
- **"Mark as Complete"** should be clearly available but secondary (outlined button style).
- The exercise list preview should be scrollable but collapsed by default to keep the action buttons above the fold.

### Summary State/Interface
- The screen-time earned number should animate with a counting-up effect.
- Show the breakdown (base + multipliers + bonuses) as an expandable section so users understand how earnings are calculated.
- Confetti or particle animation on completion to make it feel rewarding.
- The "Done" button should be the only prominent action to avoid confusion.
