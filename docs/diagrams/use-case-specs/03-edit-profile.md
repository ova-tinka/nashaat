Use case Id: UC03    Edit Profile (CRUD)

**Brief Description**
An authenticated user views and updates profile information, changes password, modifies exercise targets, manages notification preferences, and can permanently delete their account. Covers the full CRUD lifecycle of account-related settings.

**Primary actors**
Authenticated User

**Preconditions:**
1. User is authenticated with an active session.
2. Device has an active internet connection.
3. User has navigated to the Settings screen.

**Post-conditions:**
- Profile update: profiles table and avatar storage updated.
- Password change: password updated in Supabase Auth; other sessions invalidated.
- Exercise preferences: profiles updated; weekly progress uses new values.
- Account deletion: record soft-deleted, user logged out and sees Welcome screen; VIP cancelled; removed from friends and leaderboards.

**Main Success Scenario:**
<ToDo: List the included use cases. Add rows to the table below if needed />

| Actor Action | Subsystem Response |
|--------------|-----------------|
| 1. User taps Settings and views account sections (Profile, Exercise, Password, Notifications, Subscription, Delete Account). | 2. Subsystem displays current values from profiles table. |
| 3. User edits profile (avatar, name, username, DOB) and selects "Save Changes". | 4. Subsystem validates input, updates profiles and storage, shows success toast, returns to read-only. |
| 5. User selects "Change Password", enters current and new password, and selects "Update Password". | 6. Subsystem verifies current password, validates new password, updates via Supabase Auth, invalidates other sessions, shows success and returns to Settings. |
| 7. User updates exercise preferences (weekly target, duration) and selects "Save". | 8. Subsystem updates profiles, recalculates weekly goal progress, shows success toast. |
| 9. User selects "Delete Account", confirms in dialog, and enters password for final confirmation. | 10. Subsystem verifies password, soft-deletes profile, deactivates auth, cancels VIP, clears local data, navigates to Welcome screen and shows confirmation toast. |

**Alternative flows:**
4a. Invalid profile data: subsystem highlights invalid fields with errors; user corrects and resubmits.
4b. Avatar upload fails (size/format): subsystem shows error; previous avatar unchanged.
4c. Network error during save: subsystem shows connection message; unsaved changes preserved.
6a. Incorrect current password: subsystem shows error; current password field cleared.
6b. New password same as current or fails validation: subsystem shows corresponding error.
10a. Account deletion cancelled: user selects Cancel; subsystem dismisses dialog; no changes.
10b. Wrong password on deletion: subsystem aborts deletion and returns to Settings.
10c. VIP account deletion: subsystem warns about subscription cancellation before proceeding.
10d. Network error during save: subsystem shows connection message; unsaved changes preserved.

**Special Requirements:**
<ToDo: List the non-functional requirements: profile changes audited in audit_log; avatar constraints (JPG/PNG/WebP, max 5MB, min 100x100px); password strength rules; deletion requires password re-entry; retention of deleted data for 30 days before hard delete. />
