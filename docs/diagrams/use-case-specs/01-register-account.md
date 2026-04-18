Use case Id: UC01    Register Account (Includes Email Verification)

**Brief Description**
A new user creates a Nashaat account using email/password, Sign in with Apple, or Sign in with Google. Email registration requires OTP verification; social sign-in skips verification. Upon successful account creation or verification, the user is placed on the Free tier with 0 balance and 0 streak and is directed to the Onboarding use case to set exercise targets and blocking preferences.

**Primary actors**
Unregistered User (Guest)

**Preconditions:**
1. The user does not already have a Nashaat account.
2. The user has a valid email (email path) or Apple ID/Google account (social sign-in).
3. The Nashaat app is installed and the device has an active internet connection.

**Post-conditions:**
1. A new user record exists in Supabase Auth and the profiles table.
2. User's email is verified (email path) or inherited from provider (social).
3. User is on Free tier with 0 minutes screen-time balance and 0 streak (set at account creation).
4. User's status is pending onboarding; user is directed to the Onboarding use case.

**Main Success Scenario:**
<ToDo: List the included use cases. Add rows to the table below if needed />

| Actor Action | Subsystem Response |
|--------------|-----------------|
| 1. User opens app and selects "Sign Up with Email" or "Continue with Apple/Google". | 2. Subsystem presents registration form or initiates OAuth; for email, validates input and sends OTP; for social, creates/links account and skips verification. |
| 3. User completes email verification (enters OTP) or completes social auth. | 4. Subsystem verifies OTP or provider token, sets tier Free and balance/streak to 0, then redirects user to the Onboarding use case. |

**Alternative flows:**
2a. Email already registered: subsystem shows error; user remains on form.
2b. Invalid input: subsystem shows validation errors; user corrects and resubmits.
2c. Social sign-in cancelled: subsystem returns to Welcome screen.
2d. Network error: subsystem shows connection message; form data preserved for email path.
2e. Google Sign-In not available on device: subsystem hides or disables Google option and suggests email or Apple.
4a. OTP expired/incorrect: subsystem prompts resend or shows attempts remaining; after 5 failures, 15-minute lockout.
4b. Social account already linked: subsystem logs user in and redirects to Dashboard (no onboarding).
4c. Social email matches existing email/password account: subsystem prompts user to log in with email and link from Settings.

**Special Requirements:**
<ToDo: List the non-functional requirements that the use case must meet. E.g. security (passwords hashed, OTP validity 10 min, max 5 OTP attempts); performance (social sign-in to redirect under 3s on good connection); usability (single-page form, 6-digit OTP boxes); compliance (age ≥13, Terms/Privacy acceptance). />
