# Use Case 03: Manage Account Settings

## Title
Manage Account Settings (CRUD)

## Actor
Authenticated User

## Description
An authenticated user views and updates their profile information, changes their password, modifies their exercise targets, manages notification preferences, and can permanently delete their account. This use case covers the full CRUD lifecycle of account-related settings.

## Preconditions
1. The user is authenticated and has an active session.
2. The device has an active internet connection.
3. The user has navigated to the **Settings** screen via the bottom navigation bar or profile menu.

## Main Flow

### MF-1: View Account Settings
1. The user taps the **Settings** icon in the bottom navigation bar.
2. The system provides the **Settings** interface with the following sections:
   - **Profile Information**: Avatar, First Name, Last Name, Username, Email (read-only), Date of Birth
   - **Exercise Preferences**: Weekly target (days), Workout duration
   - **Password**: "Change Password" button
   - **Notifications**: Toggle switches for each notification category
   - **Subscription**: Current tier (Free/VIP) with link to Subscription Management
   - **Account Actions**: "Delete Account" button (in red)
   - **App Info**: Version number, Terms of Service link, Privacy Policy link
3. All fields display the user's current values loaded from the `profiles` table.

### MF-2: Update Profile Information
1. The user selects **"Edit Profile"**.
2. The system enables editing on the following fields:
   - Avatar (tap to upload or choose from gallery)
   - First Name, Last Name, Username (text inputs)
   - Date of Birth
3. The user modifies the desired fields.
4. The user selects **"Save Changes"**.
5. The system validates the input (see Business Rules).
6. The system updates the `profiles` table in Supabase.
7. The system returns or provides a success toast: "Profile updated successfully."
8. The system returns the fields to read-only mode.

### MF-3: Change Password
1. The user selects **"Change Password"**.
2. The system returns or provides the **Change Password** form:
   - Current Password (required)
   - New Password (required)
   - Confirm New Password (required)
3. The user fills in all three fields and selects **"Update Password"**.
4. The system verifies the current password against Supabase Auth.
5. The system validates the new password (see Business Rules).
6. The system updates the password via Supabase Auth's `updateUser` method.
7. The system returns or provides a success toast: "Password changed successfully."
8. The system returns to the Settings screen.

### MF-4: Update Exercise Preferences
1. The user taps the **Exercise Preferences** section.
2. The system returns or provides editable fields:
   - Weekly target: Slider from 1 to 7 days
   - Workout duration: Dropdown with options 15, 30, 45, 60, 90 minutes
3. The user adjusts the values and selects **"Save"**.
4. The system updates the `profiles` table.
5. The system recalculates the user's weekly goal progress based on the new target.
6. The system returns or provides a success toast: "Exercise preferences updated."

### MF-5: Delete Account
1. The user selects **"Delete Account"**.
2. The system returns or provides a confirmation dialog:
   - Title: "Delete Your Account?"
   - Body: "This will permanently delete your account, workout history, screen-time balance, and all associated data. This action cannot be undone."
   - Buttons: **"Cancel"** (primary) and **"Delete Permanently"** (destructive, red)
3. The user selects **"Delete Permanently"**.
4. The system prompts the user to enter their password as final confirmation.
5. The user enters their password and selects **"Confirm Deletion"**.
6. The system verifies the password.
7. The system performs a soft-delete:
   - Sets the `deleted_at` timestamp on the `profiles` record.
   - Deactivates the Supabase Auth account.
   - Cancels any active VIP subscription.
   - Removes the user from all leaderboards and friend lists.
8. The system clears all local data (session tokens, cached data).
9. The system navigates the user to the Welcome screen.
10. The system returns or provides a toast: "Your account has been deleted."

## Alternative Flows

### AF-1: Invalid Profile Data
- **Branches from:** MF-2, Step 5
- Validation fails (e.g., name too short, invalid characters).
- The system highlights the invalid fields with red borders and inline error messages.
- The user corrects the errors and resubmits.

### AF-2: Avatar Upload Fails
- **Branches from:** MF-2, Step 2
- The image file exceeds 5 MB or is not a supported format.
- The system returns a prompt: "Image must be a JPG, PNG, or WebP file under 5 MB."
- The previous avatar remains unchanged.

### AF-3: Incorrect Current Password on Password Change
- **Branches from:** MF-3, Step 4
- The current password does not match.
- The system returns a prompt: "Current password is incorrect."
- The form remains open with the current password field cleared.

### AF-4: New Password Same as Current
- **Branches from:** MF-3, Step 5
- The new password matches the current password.
- The system returns a prompt: "New password must be different from your current password."

### AF-5: Password Change Fails Validation
- **Branches from:** MF-3, Step 5
- The new password does not meet the requirements.
- The system returns or provides inline errors specifying what is missing (e.g., "Must contain at least one special character").

### AF-6: Account Deletion Cancelled
- **Branches from:** MF-5, Step 3
- The user selects **"Cancel"**.
- The dialog is dismissed and no changes are made.

### AF-7: Wrong Password on Deletion Confirmation
- **Branches from:** MF-5, Step 6
- The password is incorrect.
- The system returns a prompt: "Incorrect password. Account deletion aborted."
- The user is returned to the Settings screen.

### AF-8: Deletion of VIP Account
- **Branches from:** MF-5, Step 7
- The user has an active VIP subscription.
- Before deletion, the system warns: "You have an active VIP subscription. Deleting your account will cancel your subscription immediately. No refund will be issued for the remaining period."
- The user must acknowledge this before proceeding.

### AF-9: Network Error During Save
- **Branches from:** Any save operation
- The system returns a prompt: "Unable to save changes. Please check your connection and try again."
- Unsaved changes are preserved in the form.

## Postconditions

### For Profile Update:
1. The `profiles` table reflects the updated values.
2. The updated avatar is stored in Supabase Storage.

### For Password Change:
1. The password is updated in Supabase Auth.
2. All other active sessions for this user are invalidated (forced re-login on other devices).

### For Exercise Preferences Update:
1. The `profiles` table reflects the new target and duration.
2. Weekly progress calculations use the new values going forward.

### For Account Deletion:
1. The user's record is soft-deleted (data retained for 30 days for potential recovery, then hard-deleted).
2. The user is logged out and sees the Welcome screen.
3. Any active VIP subscription is cancelled.
4. The user is removed from friends lists and leaderboards.

## Business Rules

| Rule ID | Rule Description |
|---------|-----------------|
| BR-01 | First/Last Name must be between 2 and 50 characters, letters and spaces only. Username must be unique. |
| BR-02 | Email address cannot be changed after registration (display only). |
| BR-03 | Date of Birth must result in age >= 13 years. |
| BR-04 | Avatar images must be JPG, PNG, or WebP format, maximum 5 MB, minimum 100x100 pixels. |
| BR-05 | Avatars are stored in Supabase Storage bucket `avatars/` with the naming convention `{user_id}.{ext}`. |
| BR-06 | New password must be at least 8 characters with at least one uppercase, one lowercase, one digit, and one special character. |
| BR-07 | New password must differ from the current password. |
| BR-08 | After a password change, all other sessions for the user are invalidated. |
| BR-09 | Weekly exercise target must be between 1 and 7 days. |
| BR-10 | Workout duration must be one of: 15, 30, 45, 60, 90 minutes. |
| BR-11 | Account deletion is a soft-delete; data is retained for 30 days before permanent removal. |
| BR-12 | Users with active VIP subscriptions must be warned about subscription cancellation before deletion. |
| BR-13 | Account deletion requires password re-entry as a final safeguard. |
| BR-14 | Profile changes are audited in the `audit_log` table with timestamps. |

## UI/UX Notes
- The Settings screen should use a grouped list layout (similar to iOS Settings) with clear section headers.
- The "Delete Account" button should be at the very bottom of the screen, styled in red, and visually separated from other options.
- Profile editing should use an inline editing pattern (fields become editable in place) rather than navigating to a separate screen.
- The avatar area should show the current avatar as a large circle with a camera icon overlay to indicate it is tappable.
- Password strength should be indicated with a real-time strength meter (weak/medium/strong) as the user types.
- The confirmation dialog for account deletion should require a deliberate scroll or extra tap to reach the destructive action, preventing accidental deletion.
- All toggle switches (e.g., notifications) should save immediately on change without requiring a separate "Save" action.
