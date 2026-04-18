Use case Id: UC02    Login

**Brief Description**
An existing user authenticates via email/password, Sign in with Apple, or Sign in with Google. The subsystem loads profile, settings, and screen-time balance and redirects to the main dashboard. Social sign-in also serves as registration when no account exists.

**Primary actors**
Registered User

**Preconditions:**
1. The user has a registered Nashaat account (email verified or created via Apple/Google).
2. Nashaat app is installed, device has internet, and user is not currently logged in.

**Post-conditions:**
1. User has an active authenticated session stored on the device.
2. Profile, screen-time balance, and streak data are loaded.
3. User is viewing the main dashboard (or onboarding if not yet completed).
4. Session valid for 7 days (or 30 days if "Remember Me" or social login).

**Main Success Scenario:**
<ToDo: List the included use cases. Add rows to the table below if needed />

| Actor Action | Subsystem Response |
|--------------|-----------------|
| 1. User opens app and enters credentials or selects "Continue with Apple/Google". | 2. Subsystem validates input (email path) or initiates OAuth; sends credentials to Supabase Auth. |
| 3. User completes authentication (password submit or provider consent). | 4. Subsystem receives session from Supabase, stores tokens securely (Keychain/EncryptedSharedPreferences), fetches profile, balance, streak, and checks onboarding status. |
| 5. — | 6. Subsystem transitions user to Main Dashboard (or Onboarding if not completed). |

**Alternative flows:**
2a. Valid session already exists: subsystem skips login screen and proceeds to post-login data load (step 4).
2b. Forgot Password: user requests reset; subsystem sends reset link via Supabase; user sets new password and returns to Login.
2c. Social sign-in cancelled: subsystem returns to Login screen.
2d. Google Sign-In not available on device: subsystem hides or disables Google option.
4a. Incorrect email or password: subsystem shows generic "Invalid email or password"; password cleared, email retained; failed-attempt counter incremented.
4b. Account locked (5 failed attempts in 30 min): subsystem disables Log In for 30 min and shows Reset Password option.
4c. Email not verified (email path): subsystem prompts to check inbox and offers Resend Verification Email.
4d. Social email conflicts with existing email/password account: subsystem prompts to log in with email and link provider from Settings.
4e. Network error: subsystem shows connection message; email preserved, password cleared for email path.
4f. Account deleted/deactivated: subsystem shows message to contact support.
4g. Apple token revoked: subsystem prompts to re-authorize or use email.

**Special Requirements:**
<ToDo: List the non-functional requirements: secure token storage (Keychain/EncryptedSharedPreferences); no disclosure of whether email or password was wrong; session refresh within 5 min of expiry; password reset link expiry 1 hour; offer biometric login after first successful login. />
