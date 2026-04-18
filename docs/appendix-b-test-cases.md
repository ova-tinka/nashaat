# Appendix B – Test Cases Specification

---

## UC01 – Register Account

---

### Test Case 1.1

| Field | Value |
|---|---|
| **Test case #** | 1.1 |
| **Associated use case ID** | UC01 |
| **Test designed by** | Ayham Dwairy |
| **Test design date** | 18/04/2026 |
| **Executed by** | Ayham Dwairy |
| **Execution date** | 18/04/2026 |
| **Test case name** | Register with valid email and OTP |
| **Short description** | A new user registers successfully using a valid email address and completes OTP verification |

**Pre-conditions:**
- No existing account is associated with the email address
- App is on the Register screen

| Step | Test Step | Expected System Response | Actual Result | Pass/Fail | Comment |
|---|---|---|---|---|---|
| 1 | Enter a valid email address and a password meeting requirements, tap Register | System sends a 6-digit OTP to the provided email | | | |
| 2 | Enter the correct 6-digit OTP received by email | System verifies the OTP and navigates to the Onboarding screen | | | |
| 3 | Check post-condition: profile row created in database | A profile entry exists in the Supabase profiles table for the new user | | | |

**Post-conditions:**
1. User account is created and verified in Supabase auth
2. A corresponding profile row is created in the profiles table
3. User is redirected to the Onboarding screen

---

### Test Case 1.2

| Field | Value |
|---|---|
| **Test case #** | 1.2 |
| **Associated use case ID** | UC01 |
| **Test designed by** | Ayham Dwairy |
| **Test design date** | 18/04/2026 |
| **Executed by** | Ayham Dwairy |
| **Execution date** | 18/04/2026 |
| **Test case name** | Register with already-registered email |
| **Short description** | User attempts to register using an email address that already has an existing account |

**Pre-conditions:**
- An account with the email test@nashaat.com already exists in the system
- App is on the Register screen

| Step | Test Step | Expected System Response | Actual Result | Pass/Fail | Comment |
|---|---|---|---|---|---|
| 1 | Enter test@nashaat.com and any valid password, tap Register | System displays an error message indicating the email is already in use | | | |
| 2 | Verify the user remains on the Register screen | Screen does not navigate away; Register form is still visible | | | |

**Post-conditions:**
1. No new account is created
2. User remains on the Register screen

---

### Test Case 1.3

| Field | Value |
|---|---|
| **Test case #** | 1.3 |
| **Associated use case ID** | UC01 |
| **Test designed by** | Ayham Dwairy |
| **Test design date** | 18/04/2026 |
| **Executed by** | Ayham Dwairy |
| **Execution date** | 18/04/2026 |
| **Test case name** | Register with invalid email format |
| **Short description** | User attempts to register using a malformed email address |

**Pre-conditions:**
- App is on the Register screen

| Step | Test Step | Expected System Response | Actual Result | Pass/Fail | Comment |
|---|---|---|---|---|---|
| 1 | Enter "notanemail" in the email field and a valid password, tap Register | System displays a validation error indicating the email format is invalid | | | |
| 2 | Verify no OTP is sent | No email is received; user remains on the Register screen | | | |

**Post-conditions:**
1. No account is created
2. User remains on the Register screen with the validation error visible

---

## UC02 – Login

---

### Test Case 2.1

| Field | Value |
|---|---|
| **Test case #** | 2.1 |
| **Associated use case ID** | UC02 |
| **Test designed by** | Abdulrahman Refaat |
| **Test design date** | 18/04/2026 |
| **Executed by** | Abdulrahman Refaat |
| **Execution date** | 18/04/2026 |
| **Test case name** | Successful login with email and password |
| **Short description** | An existing verified user logs in with correct credentials and is directed to the Dashboard |

**Pre-conditions:**
- A verified account exists for test@nashaat.com
- App is on the Login screen

| Step | Test Step | Expected System Response | Actual Result | Pass/Fail | Comment |
|---|---|---|---|---|---|
| 1 | Enter test@nashaat.com and the correct password, tap Login | System authenticates the user and navigates to the Dashboard screen | | | |
| 2 | Verify the Dashboard loads with user data | Dashboard displays the user's screen time balance, streak, and recent activity | | | |

**Post-conditions:**
1. User session is active
2. Dashboard screen is displayed with correct user data

---

### Test Case 2.2

| Field | Value |
|---|---|
| **Test case #** | 2.2 |
| **Associated use case ID** | UC02 |
| **Test designed by** | Abdulrahman Refaat |
| **Test design date** | 18/04/2026 |
| **Executed by** | Abdulrahman Refaat |
| **Execution date** | 18/04/2026 |
| **Test case name** | Login with incorrect password |
| **Short description** | User attempts to log in with a wrong password and receives an error |

**Pre-conditions:**
- A verified account exists for test@nashaat.com
- App is on the Login screen

| Step | Test Step | Expected System Response | Actual Result | Pass/Fail | Comment |
|---|---|---|---|---|---|
| 1 | Enter test@nashaat.com and an incorrect password, tap Login | System displays an error message indicating invalid credentials | | | |
| 2 | Verify user is not logged in | User remains on the Login screen; no session is created | | | |

**Post-conditions:**
1. No session is created
2. User remains on the Login screen

---

### Test Case 2.3

| Field | Value |
|---|---|
| **Test case #** | 2.3 |
| **Associated use case ID** | UC02 |
| **Test designed by** | Abdulrahman Refaat |
| **Test design date** | 18/04/2026 |
| **Executed by** | Abdulrahman Refaat |
| **Execution date** | 18/04/2026 |
| **Test case name** | Login with Google Sign-In |
| **Short description** | User logs in using their Google account via the social login option |

**Pre-conditions:**
- A Google account is configured on the test device
- App is on the Login screen

| Step | Test Step | Expected System Response | Actual Result | Pass/Fail | Comment |
|---|---|---|---|---|---|
| 1 | Tap "Continue with Google" | System opens the Google account picker | | | |
| 2 | Select a valid Google account | System authenticates and navigates to the Dashboard or Onboarding (if first login) | | | |
| 3 | Verify user session is active | Dashboard is displayed with correct user data | | | |

**Post-conditions:**
1. User is authenticated via Google
2. Dashboard or Onboarding screen is shown

---

## UC03 – Edit Profile

---

### Test Case 3.1

| Field | Value |
|---|---|
| **Test case #** | 3.1 |
| **Associated use case ID** | UC03 |
| **Test designed by** | Abdulnaser Rabie |
| **Test design date** | 18/04/2026 |
| **Executed by** | Abdulnaser Rabie |
| **Execution date** | 18/04/2026 |
| **Test case name** | Update display name successfully |
| **Short description** | User changes their display name in Settings and the change is persisted |

**Pre-conditions:**
- User is logged in and on the Settings screen

| Step | Test Step | Expected System Response | Actual Result | Pass/Fail | Comment |
|---|---|---|---|---|---|
| 1 | Tap on the display name field and change it to "TestUser2026" | Field accepts the new input | | | |
| 2 | Tap Save | System saves the change and displays a success confirmation | | | |
| 3 | Navigate away and return to Settings | Display name shows "TestUser2026" | | | |
| 4 | Check post-condition: profile updated in DB | Supabase profiles table reflects the new display name | | | |

**Post-conditions:**
1. Display name is updated in the Supabase profiles table
2. Updated name is visible across the app

---

### Test Case 3.2

| Field | Value |
|---|---|
| **Test case #** | 3.2 |
| **Associated use case ID** | UC03 |
| **Test designed by** | Abdulnaser Rabie |
| **Test design date** | 18/04/2026 |
| **Executed by** | Abdulnaser Rabie |
| **Execution date** | 18/04/2026 |
| **Test case name** | Save profile with empty username |
| **Short description** | User clears the username field and attempts to save; system should reject the empty value |

**Pre-conditions:**
- User is logged in and on the Settings screen

| Step | Test Step | Expected System Response | Actual Result | Pass/Fail | Comment |
|---|---|---|---|---|---|
| 1 | Clear the username/display name field entirely | Field is empty | | | |
| 2 | Tap Save | System displays a validation error indicating the field is required | | | |
| 3 | Verify no change is saved | Profile name remains unchanged in the database | | | |

**Post-conditions:**
1. Profile is not updated
2. Validation error is visible on screen

---

## UC04 – Manage Workout Plan

---

### Test Case 4.1

| Field | Value |
|---|---|
| **Test case #** | 4.1 |
| **Associated use case ID** | UC04 |
| **Test designed by** | Amer Alzawawi |
| **Test design date** | 18/04/2026 |
| **Executed by** | Amer Alzawawi |
| **Execution date** | 18/04/2026 |
| **Test case name** | Create a new workout plan |
| **Short description** | User creates a new workout plan with exercises and it is saved to the database |

**Pre-conditions:**
- User is logged in and on the Workout Hub screen

| Step | Test Step | Expected System Response | Actual Result | Pass/Fail | Comment |
|---|---|---|---|---|---|
| 1 | Tap "Create Plan" | System opens the Workout Builder screen | | | |
| 2 | Enter a plan name and add at least one exercise from the library | Exercise appears in the plan's exercise list | | | |
| 3 | Tap Save | System saves the plan and navigates back to the Workout Hub | | | |
| 4 | Verify the new plan appears in "My Plans" tab | Plan card is visible with the correct name | | | |
| 5 | Check post-condition: plan saved in DB | Plan entry exists in the Supabase workout_plans table | | | |

**Post-conditions:**
1. Workout plan is saved in the workout_plans table
2. Plan appears in the user's "My Plans" list

---

### Test Case 4.2

| Field | Value |
|---|---|
| **Test case #** | 4.2 |
| **Associated use case ID** | UC04 |
| **Test designed by** | Amer Alzawawi |
| **Test design date** | 18/04/2026 |
| **Executed by** | Amer Alzawawi |
| **Execution date** | 18/04/2026 |
| **Test case name** | Edit an existing workout plan |
| **Short description** | User modifies an existing workout plan and the changes are persisted |

**Pre-conditions:**
- User is logged in
- At least one workout plan exists in "My Plans"

| Step | Test Step | Expected System Response | Actual Result | Pass/Fail | Comment |
|---|---|---|---|---|---|
| 1 | Tap on an existing plan and select Edit | Workout Builder opens with the plan's current data pre-filled | | | |
| 2 | Change the plan name and add one more exercise | Changes are reflected in the builder form | | | |
| 3 | Tap Save | System saves the updated plan and returns to Workout Hub | | | |
| 4 | Verify the plan card shows the updated name | Plan card displays the new name | | | |

**Post-conditions:**
1. Updated plan is saved in the workout_plans table
2. Changes are reflected in the UI

---

### Test Case 4.3

| Field | Value |
|---|---|
| **Test case #** | 4.3 |
| **Associated use case ID** | UC04 |
| **Test designed by** | Amer Alzawawi |
| **Test design date** | 18/04/2026 |
| **Executed by** | Amer Alzawawi |
| **Execution date** | 18/04/2026 |
| **Test case name** | Delete a workout plan |
| **Short description** | User deletes a workout plan and it is removed from the list and the database |

**Pre-conditions:**
- User is logged in
- At least one workout plan exists in "My Plans"

| Step | Test Step | Expected System Response | Actual Result | Pass/Fail | Comment |
|---|---|---|---|---|---|
| 1 | Long press or tap the delete option on an existing plan | System displays a confirmation dialog | | | |
| 2 | Confirm deletion | System deletes the plan and removes it from the "My Plans" list | | | |
| 3 | Check post-condition: plan removed from DB | Plan entry no longer exists in the workout_plans table | | | |

**Post-conditions:**
1. Plan is deleted from the workout_plans table
2. Plan no longer appears in the user's "My Plans" list

---

## UC05 – Log Workout

---

### Test Case 5.1

| Field | Value |
|---|---|
| **Test case #** | 5.1 |
| **Associated use case ID** | UC05 |
| **Test designed by** | Ayham Dwairy |
| **Test design date** | 18/04/2026 |
| **Executed by** | Ayham Dwairy |
| **Execution date** | 18/04/2026 |
| **Test case name** | Complete a workout session and earn screen time |
| **Short description** | User completes all exercises in a session and the system credits screen time to their balance |

**Pre-conditions:**
- User is logged in
- At least one workout plan exists
- Current screen time balance is noted before starting

| Step | Test Step | Expected System Response | Actual Result | Pass/Fail | Comment |
|---|---|---|---|---|---|
| 1 | Open a workout plan and tap Start Session | Active Session screen opens with the first exercise displayed | | | |
| 2 | Complete each exercise by tapping Next through all sets | System tracks progress and advances through the exercise list | | | |
| 3 | Tap Finish Session on the last exercise | System calculates earned screen time minutes and saves the workout log | | | |
| 4 | Navigate to the Dashboard | Screen time balance is higher than the noted pre-workout value | | | |
| 5 | Check post-condition: log saved in DB | A workout log entry exists in the workout_logs table with correct duration | | | |

**Post-conditions:**
1. Workout log is saved in the workout_logs table
2. Screen time balance is updated in the profiles table
3. A screen_time_transactions entry is recorded

---

### Test Case 5.2

| Field | Value |
|---|---|
| **Test case #** | 5.2 |
| **Associated use case ID** | UC05 |
| **Test designed by** | Ayham Dwairy |
| **Test design date** | 18/04/2026 |
| **Executed by** | Ayham Dwairy |
| **Execution date** | 18/04/2026 |
| **Test case name** | Abandon workout session mid-way |
| **Short description** | User exits the session before completing it and no screen time is credited |

**Pre-conditions:**
- User is logged in
- An active workout session is in progress
- Current screen time balance is noted

| Step | Test Step | Expected System Response | Actual Result | Pass/Fail | Comment |
|---|---|---|---|---|---|
| 1 | Start a workout session and complete only the first exercise | Session is active and progress is shown | | | |
| 2 | Navigate back / abandon the session without finishing | System exits the session without saving a completed log | | | |
| 3 | Navigate to the Dashboard | Screen time balance remains unchanged from the noted value | | | |

**Post-conditions:**
1. No screen time is credited
2. No completed workout log is saved

---

### Test Case 5.3

| Field | Value |
|---|---|
| **Test case #** | 5.3 |
| **Associated use case ID** | UC05 |
| **Test designed by** | Ayham Dwairy |
| **Test design date** | 18/04/2026 |
| **Executed by** | Ayham Dwairy |
| **Execution date** | 18/04/2026 |
| **Test case name** | Screen time credit is proportional to session duration |
| **Short description** | A longer workout session credits more screen time than a shorter one |

**Pre-conditions:**
- User is logged in
- Two workout plans exist: one short (10 min) and one long (30 min)

| Step | Test Step | Expected System Response | Actual Result | Pass/Fail | Comment |
|---|---|---|---|---|---|
| 1 | Complete the short workout session | System credits screen time corresponding to ~10 minutes of activity | | | |
| 2 | Note the credited screen time amount | Amount is recorded | | | |
| 3 | Complete the long workout session | System credits screen time corresponding to ~30 minutes of activity | | | |
| 4 | Compare credited amounts | Long session credits significantly more screen time than the short session | | | |

**Post-conditions:**
1. Both logs are saved in workout_logs with correct durations
2. Screen time credits are proportional to workout duration

---

## UC06 – Performance Dashboard

---

### Test Case 6.1

| Field | Value |
|---|---|
| **Test case #** | 6.1 |
| **Associated use case ID** | UC06 |
| **Test designed by** | Abdulrahman Refaat |
| **Test design date** | 18/04/2026 |
| **Executed by** | Abdulrahman Refaat |
| **Execution date** | 18/04/2026 |
| **Test case name** | Dashboard displays correct workout and screen time data |
| **Short description** | Dashboard loads and accurately reflects the user's logged workouts and current screen time balance |

**Pre-conditions:**
- User is logged in
- At least two workouts have been logged this week
- Current screen time balance is known

| Step | Test Step | Expected System Response | Actual Result | Pass/Fail | Comment |
|---|---|---|---|---|---|
| 1 | Navigate to the Dashboard screen | Dashboard loads without errors | | | |
| 2 | Check the screen time balance displayed | Balance matches the known value from the profiles table | | | |
| 3 | Check the weekly workout count | Count matches the number of logs recorded this week in workout_logs | | | |
| 4 | Check streak display | Streak value matches consecutive workout days in the database | | | |

**Post-conditions:**
1. Dashboard displays accurate data consistent with the database state

---

### Test Case 6.2

| Field | Value |
|---|---|
| **Test case #** | 6.2 |
| **Associated use case ID** | UC06 |
| **Test designed by** | Abdulrahman Refaat |
| **Test design date** | 18/04/2026 |
| **Executed by** | Abdulrahman Refaat |
| **Execution date** | 18/04/2026 |
| **Test case name** | Dashboard empty state for new user |
| **Short description** | Dashboard handles a new user with no workout history gracefully |

**Pre-conditions:**
- User is newly registered with no workout logs

| Step | Test Step | Expected System Response | Actual Result | Pass/Fail | Comment |
|---|---|---|---|---|---|
| 1 | Navigate to the Dashboard screen | Dashboard loads without errors or crashes | | | |
| 2 | Check weekly workout section | Section displays a zero count or an empty state message | | | |
| 3 | Check streak display | Streak shows 0 or a "start your streak" prompt | | | |

**Post-conditions:**
1. Dashboard renders correctly with no data without crashing

---

## UC07 – Interface Lock

---

### Test Case 7.1

| Field | Value |
|---|---|
| **Test case #** | 7.1 |
| **Associated use case ID** | UC07 |
| **Test designed by** | Abdulnaser Rabie |
| **Test design date** | 18/04/2026 |
| **Executed by** | Abdulnaser Rabie |
| **Execution date** | 18/04/2026 |
| **Test case name** | Lock overlay activates when screen time balance is zero |
| **Short description** | When the user's screen time balance reaches zero, the lock overlay is displayed |

**Pre-conditions:**
- User is logged in
- Blocking is enabled with at least one app configured
- Screen time balance is set to 0 minutes

| Step | Test Step | Expected System Response | Actual Result | Pass/Fail | Comment |
|---|---|---|---|---|---|
| 1 | Confirm screen time balance is 0 on the Focus screen | Balance displays 0 minutes | | | |
| 2 | Attempt to open a blocked application | System displays the lock screen overlay | | | |
| 3 | Verify the lock overlay shows remaining balance as 0 | Overlay displays 0 minutes remaining | | | |

**Post-conditions:**
1. Lock overlay is visible and blocking access to the app

---

### Test Case 7.2

| Field | Value |
|---|---|
| **Test case #** | 7.2 |
| **Associated use case ID** | UC07 |
| **Test designed by** | Abdulnaser Rabie |
| **Test design date** | 18/04/2026 |
| **Executed by** | Abdulnaser Rabie |
| **Execution date** | 18/04/2026 |
| **Test case name** | Emergency break temporarily dismisses lock |
| **Short description** | User uses the emergency break feature to temporarily bypass the lock |

**Pre-conditions:**
- Screen time balance is 0
- Lock overlay is currently displayed

| Step | Test Step | Expected System Response | Actual Result | Pass/Fail | Comment |
|---|---|---|---|---|---|
| 1 | Tap the "Emergency Break" button on the lock overlay | System prompts the user to confirm the emergency break | | | |
| 2 | Confirm the emergency break | Lock overlay is dismissed and the app becomes accessible temporarily | | | |
| 3 | Verify the emergency break is logged | An entry is recorded in screen_time_transactions for the break | | | |

**Post-conditions:**
1. Emergency break is recorded in the database
2. Lock is temporarily lifted

---

### Test Case 7.3

| Field | Value |
|---|---|
| **Test case #** | 7.3 |
| **Associated use case ID** | UC07 |
| **Test designed by** | Abdulnaser Rabie |
| **Test design date** | 18/04/2026 |
| **Executed by** | Abdulnaser Rabie |
| **Execution date** | 18/04/2026 |
| **Test case name** | Lock deactivates after earning screen time |
| **Short description** | After completing a workout and earning screen time, the lock is lifted |

**Pre-conditions:**
- Screen time balance is 0
- Lock overlay is active

| Step | Test Step | Expected System Response | Actual Result | Pass/Fail | Comment |
|---|---|---|---|---|---|
| 1 | Navigate to the workout section from the lock screen | App allows navigation to workout section | | | |
| 2 | Complete a workout session | System credits earned screen time to the balance | | | |
| 3 | Attempt to access the previously blocked app | Lock overlay is no longer displayed; app is accessible | | | |

**Post-conditions:**
1. Screen time balance is greater than 0
2. Blocked apps are accessible

---

## UC08 – Mobile App Blocking

---

### Test Case 8.1

| Field | Value |
|---|---|
| **Test case #** | 8.1 |
| **Associated use case ID** | UC08 |
| **Test designed by** | Amer Alzawawi |
| **Test design date** | 18/04/2026 |
| **Executed by** | Amer Alzawawi |
| **Execution date** | 18/04/2026 |
| **Test case name** | Select and activate blocking for a mobile app |
| **Short description** | User selects an app to block and the system enforces the block |

**Pre-conditions:**
- User is logged in and on the Blocking screen
- Required permissions (Accessibility Service on Android / Family Controls on iOS) are granted

| Step | Test Step | Expected System Response | Actual Result | Pass/Fail | Comment |
|---|---|---|---|---|---|
| 1 | Tap "Add App" or open the App Picker | System displays a list of installed applications | | | |
| 2 | Select a target app (e.g., YouTube) and confirm | The app is added to the blocking list | | | |
| 3 | Enable blocking and reduce screen time balance to 0 | System enforces the block on the selected app | | | |
| 4 | Attempt to open the blocked app | System prevents access and shows the lock overlay | | | |

**Post-conditions:**
1. Blocking rule is saved in the blocking_rules table
2. Selected app is blocked when balance is depleted

---

### Test Case 8.2

| Field | Value |
|---|---|
| **Test case #** | 8.2 |
| **Associated use case ID** | UC08 |
| **Test designed by** | Amer Alzawawi |
| **Test design date** | 18/04/2026 |
| **Executed by** | Amer Alzawawi |
| **Execution date** | 18/04/2026 |
| **Test case name** | Unblock a previously blocked app |
| **Short description** | User removes an app from the blocking list and it becomes accessible |

**Pre-conditions:**
- User is logged in
- At least one app is currently in the blocking list

| Step | Test Step | Expected System Response | Actual Result | Pass/Fail | Comment |
|---|---|---|---|---|---|
| 1 | Navigate to the Blocking screen | Blocking list shows the currently blocked app | | | |
| 2 | Remove the app from the blocking list | App is removed from the list | | | |
| 3 | Attempt to open the previously blocked app | App opens normally without a lock overlay | | | |

**Post-conditions:**
1. Blocking rule is removed from the blocking_rules table
2. Previously blocked app is freely accessible

---

## UC10 – Manage Blocking Configuration

---

### Test Case 10.1

| Field | Value |
|---|---|
| **Test case #** | 10.1 |
| **Associated use case ID** | UC10 |
| **Test designed by** | Abdulrahman Refaat |
| **Test design date** | 18/04/2026 |
| **Executed by** | Abdulrahman Refaat |
| **Execution date** | 18/04/2026 |
| **Test case name** | Add a new blocking rule |
| **Short description** | User creates a new blocking rule for a specific app and it is saved correctly |

**Pre-conditions:**
- User is logged in and on the Blocking Configuration screen
- No existing rule exists for the target app

| Step | Test Step | Expected System Response | Actual Result | Pass/Fail | Comment |
|---|---|---|---|---|---|
| 1 | Tap Add Rule and select an app from the picker | Selected app appears in the configuration form | | | |
| 2 | Configure the rule (e.g., block always) and save | Rule is saved and appears in the blocking rules list | | | |
| 3 | Check post-condition: rule saved in DB | Entry exists in the blocking_rules table for the selected app | | | |

**Post-conditions:**
1. New blocking rule is saved in the blocking_rules table
2. Rule is visible in the blocking configuration list

---

### Test Case 10.2

| Field | Value |
|---|---|
| **Test case #** | 10.2 |
| **Associated use case ID** | UC10 |
| **Test designed by** | Abdulrahman Refaat |
| **Test design date** | 18/04/2026 |
| **Executed by** | Abdulrahman Refaat |
| **Execution date** | 18/04/2026 |
| **Test case name** | Delete an existing blocking rule |
| **Short description** | User removes a blocking rule and it is deleted from the system |

**Pre-conditions:**
- User is logged in
- At least one blocking rule exists

| Step | Test Step | Expected System Response | Actual Result | Pass/Fail | Comment |
|---|---|---|---|---|---|
| 1 | Navigate to the Blocking Configuration screen | Existing rules are displayed | | | |
| 2 | Select a rule and choose Delete | System displays a confirmation prompt | | | |
| 3 | Confirm deletion | Rule is removed from the list | | | |
| 4 | Check post-condition: rule removed from DB | Entry no longer exists in the blocking_rules table | | | |

**Post-conditions:**
1. Blocking rule is deleted from the blocking_rules table
2. Rule no longer appears in the configuration list

---

## UC13 – Private Leaderboards

---

### Test Case 13.1

| Field | Value |
|---|---|
| **Test case #** | 13.1 |
| **Associated use case ID** | UC13 |
| **Test designed by** | Abdulnaser Rabie |
| **Test design date** | 18/04/2026 |
| **Executed by** | Abdulnaser Rabie |
| **Execution date** | 18/04/2026 |
| **Test case name** | Create a new private leaderboard |
| **Short description** | User creates a private leaderboard and it is saved with a generated invite code |

**Pre-conditions:**
- User is logged in and on the Leaderboard screen

| Step | Test Step | Expected System Response | Actual Result | Pass/Fail | Comment |
|---|---|---|---|---|---|
| 1 | Tap "Create Leaderboard" | System opens the leaderboard creation form | | | |
| 2 | Enter a leaderboard name and confirm | System creates the leaderboard and displays an invite code | | | |
| 3 | Verify the leaderboard appears in the user's leaderboard list | New leaderboard card is visible with the correct name | | | |
| 4 | Check post-condition: leaderboard saved in DB | Entry exists in the leaderboards table | | | |

**Post-conditions:**
1. Leaderboard is saved in the leaderboards table
2. Creator is listed as a member with owner role
3. An invite code is generated

---

### Test Case 13.2

| Field | Value |
|---|---|
| **Test case #** | 13.2 |
| **Associated use case ID** | UC13 |
| **Test designed by** | Abdulnaser Rabie |
| **Test design date** | 18/04/2026 |
| **Executed by** | Abdulnaser Rabie |
| **Execution date** | 18/04/2026 |
| **Test case name** | Join a leaderboard using an invite code |
| **Short description** | A second user joins an existing leaderboard using the invite code |

**Pre-conditions:**
- A leaderboard exists with a known invite code
- A second user account is available for testing

| Step | Test Step | Expected System Response | Actual Result | Pass/Fail | Comment |
|---|---|---|---|---|---|
| 1 | Log in with the second user account | Dashboard is displayed | | | |
| 2 | Navigate to Leaderboards and tap "Join Leaderboard" | System prompts for an invite code | | | |
| 3 | Enter the valid invite code | System adds the user to the leaderboard and displays it in their list | | | |
| 4 | Check post-condition: membership saved in DB | Entry exists in the leaderboard members table for the second user | | | |

**Post-conditions:**
1. Second user is added as a member of the leaderboard
2. Leaderboard appears in the second user's list

---

### Test Case 13.3

| Field | Value |
|---|---|
| **Test case #** | 13.3 |
| **Associated use case ID** | UC13 |
| **Test designed by** | Abdulnaser Rabie |
| **Test design date** | 18/04/2026 |
| **Executed by** | Abdulnaser Rabie |
| **Execution date** | 18/04/2026 |
| **Test case name** | Leaderboard rankings reflect workout activity |
| **Short description** | After logging a workout, the user's rank on the leaderboard updates correctly |

**Pre-conditions:**
- User is a member of a leaderboard with at least one other member
- User has logged a workout this week

| Step | Test Step | Expected System Response | Actual Result | Pass/Fail | Comment |
|---|---|---|---|---|---|
| 1 | Navigate to the Leaderboard screen and open the leaderboard | Rankings are displayed for all members | | | |
| 2 | Verify the current user's score reflects their weekly workout minutes | User's score matches their logged activity for the week | | | |
| 3 | Log another workout and return to the leaderboard | User's score and rank update to reflect the new workout | | | |

**Post-conditions:**
1. Rankings are accurate and reflect current week's workout data

---

## UC15 – Streaks & Rewards

---

### Test Case 15.1

| Field | Value |
|---|---|
| **Test case #** | 15.1 |
| **Associated use case ID** | UC15 |
| **Test designed by** | Amer Alzawawi |
| **Test design date** | 18/04/2026 |
| **Executed by** | Amer Alzawawi |
| **Execution date** | 18/04/2026 |
| **Test case name** | Streak increments after consecutive daily workouts |
| **Short description** | User's streak count increases by 1 after logging a workout on consecutive days |

**Pre-conditions:**
- User is logged in
- User has an existing streak of at least 1 day
- Current streak value is noted

| Step | Test Step | Expected System Response | Actual Result | Pass/Fail | Comment |
|---|---|---|---|---|---|
| 1 | Complete and log a workout on the current day | Workout is saved successfully | | | |
| 2 | Navigate to the Dashboard | Streak count is incremented by 1 from the noted value | | | |
| 3 | Verify streak value in DB | profiles table streak_count matches the displayed value | | | |

**Post-conditions:**
1. Streak count is incremented in the profiles table
2. Updated streak is reflected on the Dashboard

---

### Test Case 15.2

| Field | Value |
|---|---|
| **Test case #** | 15.2 |
| **Associated use case ID** | UC15 |
| **Test designed by** | Amer Alzawawi |
| **Test design date** | 18/04/2026 |
| **Executed by** | Amer Alzawawi |
| **Execution date** | 18/04/2026 |
| **Test case name** | Streak resets after a missed day |
| **Short description** | If the user does not log a workout for a full day, the streak is reset to zero |

**Pre-conditions:**
- User has an active streak of 3 or more days
- Simulated condition: last workout log is older than 48 hours

| Step | Test Step | Expected System Response | Actual Result | Pass/Fail | Comment |
|---|---|---|---|---|---|
| 1 | Simulate a missed day by setting the last workout log date to 2 days ago in the database | Last log is now outside the streak window | | | |
| 2 | Open the app and navigate to the Dashboard | Streak is displayed as 0 or reset | | | |
| 3 | Verify streak value in DB | profiles table streak_count reflects 0 | | | |

**Post-conditions:**
1. Streak count is reset to 0
2. Dashboard displays the reset streak

---

## UC16 – Onboarding

---

### Test Case 16.1

| Field | Value |
|---|---|
| **Test case #** | 16.1 |
| **Associated use case ID** | UC16 |
| **Test designed by** | Ayham Dwairy |
| **Test design date** | 18/04/2026 |
| **Executed by** | Ayham Dwairy |
| **Execution date** | 18/04/2026 |
| **Test case name** | Complete full onboarding flow |
| **Short description** | A newly registered user completes all 6 onboarding steps and is directed to the Dashboard |

**Pre-conditions:**
- User has just registered and verified their account
- User has not previously completed onboarding

| Step | Test Step | Expected System Response | Actual Result | Pass/Fail | Comment |
|---|---|---|---|---|---|
| 1 | Enter a username on step 1 and tap Next | System advances to step 2 | | | |
| 2 | Select workout days per week on step 2 and tap Next | System advances to step 3 | | | |
| 3 | Set daily phone usage hours on step 3 and tap Next | System advances to step 4 | | | |
| 4 | Set screen time threshold on step 4 and tap Next | System advances to step 5 | | | |
| 5 | Grant required permissions on step 5 and tap Next | Permissions are accepted; system advances to step 6 | | | |
| 6 | Confirm setup on step 6 and tap Finish | System saves onboarding data and navigates to the Dashboard | | | |
| 7 | Check post-condition: onboarding flag set in DB | profiles table reflects onboarding as completed | | | |

**Post-conditions:**
1. Onboarding completion is recorded in the profiles table
2. User is on the Dashboard screen
3. User preferences are saved

---

### Test Case 16.2

| Field | Value |
|---|---|
| **Test case #** | 16.2 |
| **Associated use case ID** | UC16 |
| **Test designed by** | Ayham Dwairy |
| **Test design date** | 18/04/2026 |
| **Executed by** | Ayham Dwairy |
| **Execution date** | 18/04/2026 |
| **Test case name** | Onboarding handles permission denial gracefully |
| **Short description** | User denies permissions during onboarding and the app continues without crashing |

**Pre-conditions:**
- User is on the permissions step of onboarding (step 5)

| Step | Test Step | Expected System Response | Actual Result | Pass/Fail | Comment |
|---|---|---|---|---|---|
| 1 | When prompted for permissions, tap Deny | System acknowledges the denial without crashing | | | |
| 2 | Tap Next to continue | System proceeds to the next step or shows a note about limited functionality | | | |
| 3 | Complete onboarding and reach the Dashboard | App is functional; a warning about limited blocking functionality may be shown | | | |

**Post-conditions:**
1. App does not crash on permission denial
2. User can still reach the Dashboard

---

## UC24 – Analytics & Progress Reports

---

### Test Case 24.1

| Field | Value |
|---|---|
| **Test case #** | 24.1 |
| **Associated use case ID** | UC24 |
| **Test designed by** | Abdulrahman Refaat |
| **Test design date** | 18/04/2026 |
| **Executed by** | Abdulrahman Refaat |
| **Execution date** | 18/04/2026 |
| **Test case name** | Weekly stats display correctly on the Dashboard |
| **Short description** | Dashboard accurately aggregates and displays the user's weekly workout minutes and screen time earned |

**Pre-conditions:**
- User is logged in
- At least 3 workout logs exist within the current week

| Step | Test Step | Expected System Response | Actual Result | Pass/Fail | Comment |
|---|---|---|---|---|---|
| 1 | Navigate to the Dashboard screen | Dashboard loads without errors | | | |
| 2 | Check the weekly workout minutes displayed | Value matches the sum of durations in workout_logs for the current week | | | |
| 3 | Check the weekly screen time earned | Value matches the sum of credited transactions in screen_time_transactions for the week | | | |
| 4 | Check the weekly chart/graph | Chart bars or data points correspond to workout activity per day this week | | | |

**Post-conditions:**
1. Analytics data on the Dashboard is accurate and consistent with the database

---

### Test Case 24.2

| Field | Value |
|---|---|
| **Test case #** | 24.2 |
| **Associated use case ID** | UC24 |
| **Test designed by** | Abdulrahman Refaat |
| **Test design date** | 18/04/2026 |
| **Executed by** | Abdulrahman Refaat |
| **Execution date** | 18/04/2026 |
| **Test case name** | Dashboard updates after a new workout is logged |
| **Short description** | After logging a new workout, the Dashboard's analytics reflect the update without requiring an app restart |

**Pre-conditions:**
- User is logged in
- Dashboard is open and shows current stats

| Step | Test Step | Expected System Response | Actual Result | Pass/Fail | Comment |
|---|---|---|---|---|---|
| 1 | Note the current weekly workout minutes on the Dashboard | Value is recorded | | | |
| 2 | Navigate to Workout and complete a session | Workout is saved successfully | | | |
| 3 | Navigate back to the Dashboard | Weekly workout minutes value is higher than the noted value | | | |
| 4 | Verify the screen time balance also updated | Balance reflects the newly earned minutes | | | |

**Post-conditions:**
1. Dashboard analytics update in response to new workout data
2. No app restart required to see updated values
