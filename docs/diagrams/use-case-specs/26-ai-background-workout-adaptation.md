Use case Id: UC26    AI Background Workout Adaptation

**Brief Description**
A system AI agent runs as a background job every 1–2 weeks per user. It analyses the user's recent workout logs, completed exercises, progression trends (weight and rep increases), and app usage data, taking into account the user's stated goals (weight loss, muscle gain, endurance, flexibility). The agent proposes plan modifications such as increased weights, exercise substitutions, or adjusted frequency. The user receives a push notification summarising the proposed changes and can approve or revert them.

**Primary actors**
AI Agent (System), Authenticated User, Supabase Backend

**Preconditions:**
1. The user is authenticated and has at least 2 weeks of workout_logs.
2. An ai_workout_jobs record has been scheduled for the user (status: pending).
3. The AI Service (Claude API) is reachable from the Supabase Edge Function.
4. The user has an active workout plan in workout_plans.

**Post-conditions:**
1. ai_workout_jobs.status is updated to completed or failed.
2. On completion: ai_workout_jobs.analysis_result contains the proposed changes JSONB.
3. If user approves: the workout plan is updated; a new version is saved in workout_plans and linked via ai_workout_jobs.updated_plan_id.
4. If user reverts: the original plan is restored; ai_workout_jobs.updated_plan_id is cleared.
5. A notification is sent to the user (UC12) with a summary of proposed changes.

**Main Success Scenario:**
<ToDo: List the included use cases. Add rows to the table below if needed />

| Actor Action | Subsystem Response |
|--------------|-----------------|
| 1. — | 2. Supabase scheduled job triggers the AI Agent Edge Function for users with a pending ai_workout_jobs record. |
| 3. — | 4. AI Agent fetches workout_logs, screen_time_transactions, and app_usage_insights for the past 2 weeks; analyses progression and goal alignment. |
| 5. — | 6. AI Agent generates a structured set of proposed modifications (exercise substitutions, weight/rep increases, frequency changes) and writes the result to ai_workout_jobs.analysis_result; sets status to completed. |
| 7. — | 8. Subsystem sends push notification to user: "Your workout plan has been updated based on your progress. Tap to review." |
| 9. User taps notification and reviews proposed changes. | 10. Subsystem displays a diff-style view of current plan vs proposed plan. |
| 11. User taps "Approve Changes". | 12. Subsystem applies modifications to workout_plans, saves updated plan, and links it in ai_workout_jobs.updated_plan_id. |
| 13. User taps "Revert". | 14. Subsystem discards proposed changes; restores original plan; clears ai_workout_jobs.updated_plan_id. |

**Alternative flows:**
4a. Insufficient data (fewer than 2 weeks of logs): AI Agent sets ai_workout_jobs.status to failed with reason "insufficient_data"; no notification sent; job is rescheduled for 1 week later.
6a. AI Service unreachable: Edge Function retries up to 3 times with exponential backoff; on final failure sets status to failed and logs the error.
11a. User ignores the notification: proposed changes remain pending; a reminder notification is sent after 48 hours; if ignored again, changes are auto-discarded after 7 days.

**Special Requirements:**
<ToDo: List the non-functional requirements that the use case must meet. E.g. background job runs via Supabase Edge Function on a scheduled cron; user-facing approval required before plan is modified; no plan changes without explicit approval; diff view must clearly show added, removed, and modified exercises; AI analysis context window capped at last 4 weeks of data; job failures do not corrupt existing plans; rescheduling logic prevents duplicate jobs per user; Edge Function execution timeout 60 seconds. />
