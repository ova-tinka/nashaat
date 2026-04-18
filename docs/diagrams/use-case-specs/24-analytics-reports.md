Use case Id: UC24    Analytics & Progress Reports

**Brief Description**
The system generates weekly and monthly reports for users covering workouts completed, screen time earned and spent, streak history, and top exercises. Reports are visualised with bar charts, line graphs, and heatmaps. Users can optionally log body measurements (weight, etc.) to track physical progress. VIP users receive advanced analytics and can export reports as PDF; Free tier users receive a basic weekly summary only.

**Primary actors**
Authenticated User (Free + VIP), System (report generator)

**Preconditions:**
1. The user is authenticated.
2. At least one completed workout exists in workout_logs.
3. screen_time_transactions contains data for the report period.

**Post-conditions:**
1. analytics_reports record is created (or refreshed) for the requested period.
2. Charts are rendered from workout_stats and screen_time_stats JSONB fields.
3. For VIP: PDF export is generated on demand and available for download.
4. Body progress data is persisted in the user's profile if logged.

**Main Success Scenario:**
<ToDo: List the included use cases. Add rows to the table below if needed />

| Actor Action | Subsystem Response |
|--------------|-----------------|
| 1. User navigates to Analytics. | 2. Subsystem checks tier; displays Weekly Summary for Free users and full dashboard (weekly + monthly) for VIP users. |
| 3. User selects a time period (current week, last week, current month, custom — VIP only). | 4. Subsystem queries workout_logs and screen_time_transactions for the period; generates or retrieves analytics_reports record. |
| 5. — | 6. Subsystem renders bar charts (workouts per day), line graphs (screen time trends), and a workout heatmap; displays top 3 exercises by volume. |
| 7. VIP user taps "Export as PDF". | 8. Subsystem generates a PDF with all charts and stats and saves it to the device or share sheet. |
| 9. User logs body measurement (optional). | 10. Subsystem saves measurement to the user's profile data and updates the progress tracking chart. |

**Alternative flows:**
2a. Free user attempts to access monthly or custom reports: subsystem shows upgrade prompt.
4a. No data for selected period: subsystem shows "No workouts logged yet" with a prompt to log a workout (UC05).
8a. PDF generation fails: subsystem retries once; on second failure, shows error with a "Try again" button.

**Special Requirements:**
<ToDo: List the non-functional requirements that the use case must meet. E.g. Free tier limited to current-week summary only; VIP gets weekly, monthly, and custom date range; report generation under 3 seconds; PDF export available offline using cached data; charts rendered with accessible colours; analytics_reports records cached and invalidated on new workout_log; body measurements stored in user profile JSONB; heatmap covers last 52 weeks for VIP. />
