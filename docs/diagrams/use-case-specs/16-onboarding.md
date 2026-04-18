Use case Id: UC16    Onboarding (Exercise Target & Blocking Preferences)

**Brief Description**
A newly registered user completes onboarding by setting their weekly exercise target (days per week and workout duration), then configuring initial app and website blocking preferences (or skipping). The subsystem saves the data to the profile, requests device permissions if apps are selected, sets status to onboarded, and transitions the user to the Main Dashboard.

**Primary actors**
Newly Registered User (Authenticated, pending onboarding)

**Preconditions:**
1. The user has just completed registration (Use Case 01) and is authenticated with status pending onboarding.
2. The device has an active internet connection.
3. The user has been redirected to the Onboarding flow by the subsystem.

**Post-conditions:**
1. The user's weekly exercise target (days and duration) is stored in the profiles table.
2. The user's blocking preferences are stored in the blocking_rules table (or empty if skipped).
3. Account tier is Free with 0 minutes screen-time balance and 0 streak (if not already set).
4. User status is updated to onboarded.
5. The user is viewing the Main Dashboard.

**Main Success Scenario:**
<ToDo: List the included use cases. Add rows to the table below if needed />

| Actor Action | Subsystem Response |
|--------------|-----------------|
| 1. User is presented with Onboarding - Exercise Target (days per week 1–7, then workout duration 15/30/45/60/90 min). | 2. Subsystem displays slider or selection UI; user selects target and duration. |
| 3. User is presented with Onboarding - Blocking Preferences (Apps to Block, Websites to Block). | 4. Subsystem displays searchable app list and domain input; user selects at least one app or website to block, or taps "Skip for Now". |
| 5. If apps selected: user grants or denies device permissions when prompted. | 6. Subsystem requests Accessibility/Display Over Other Apps/Usage Stats (Android) or Screen Time API (iOS) if needed; saves onboarding data to profile (target, blocking_rules, tier Free, balance 0, streak 0, status onboarded). If skip: saves with empty blocking list. |
| 7. — | 8. Subsystem transitions user to the Main Dashboard. |

**Alternative flows:**
6a. User skips blocking preferences: subsystem saves onboarding data with an empty blocking list and shows a dismissible tooltip on the dashboard: "You can configure app blocking anytime from Settings"; flow continues to main step 8.
6b. User denies device permissions for app blocking: subsystem shows "App blocking requires these permissions to work. You can enable them later in Settings"; blocking preferences are saved but marked as inactive until permissions are granted; flow continues to main step 8.

**Special Requirements:**
<ToDo: List the non-functional requirements that the use case must meet. E.g. weekly exercise target 1–7 days; workout duration one of 15, 30, 45, 60, 90 minutes; max 30 apps and 50 websites on initial blocking list; domain names valid (at least one dot, no spaces); progress indicator (e.g. Step 1 of 2) during onboarding; "Skip for Now" visually de-emphasized; exercise target screen engaging (slider/card selection); blocking screen shows app icons with names. />
