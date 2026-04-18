Use case Id: UC08    Mobile App Blocking Subsystem

**Brief Description**
The subsystem restricts user-selected apps when screen-time balance is depleted. The user grants OS-level permissions, the subsystem discovers installed apps, the user selects apps to block, and a background service enforces blocking (overlay or OS screen-time APIs) and tracks usage against the balance.

**Primary actors**
Authenticated User, Subsystem (background service)

**Preconditions:**
1. User is authenticated; Nashaat app is installed.
2. User has or is setting up at least one app for blocking.

**Post-conditions:**
1. Required OS permissions are granted and active.
2. Selected apps stored in blocking_rules; background service running and enforcing.
3. App usage tracked and deducted from screen-time balance; usage statistics available.

**Main Success Scenario:**
<ToDo: List the included use cases. Add rows to the table below if needed />

| Actor Action | Subsystem Response |
|--------------|-----------------|
| 1. User navigates to Settings > Blocking Configuration (or onboarding) and grants each required permission via OS settings. | 2. Subsystem checks permissions (Android: Accessibility, Display Over Other Apps, Usage Stats; iOS: Family Controls); for each missing, shows explanation and "Grant Permission" deep-link; confirms when all granted. |
| 3. User selects apps to block from searchable list (excluding exempt apps) and selects "Save". | 4. Subsystem saves selections to blocking_rules (package/bundle ID), activates monitoring service, shows "[X] apps are now managed." |
| 5. User opens blocked app when balance > 0. | 6. Subsystem allows app; timer deducts 1 min per 1 min use; logs to app_usage_insights; at 5 min/1 min/0 sends notifications and at 0 triggers lock (Use Case 07). |
| 7. User navigates to Usage Stats. | 8. Subsystem presents total time today, per-app breakdown, weekly trends, this week vs last. |

**Alternative flows:**
2a. Permission denied: subsystem marks blocking "Inactive", explains, sends reminder after 24 hours.
2b. Permission revoked after setup: service pauses; notification to re-enable; event logged.
2c. iOS restrictions: if Family Controls not authorized, subsystem falls back to notification-only mode.
4a. User selects exempt app: subsystem prevents selection and explains.
6a. Blocked app uninstalled: subsystem removes from active list on next refresh (24h); rule kept with status uninstalled.
6b. New app installed matching category (VIP): subsystem may notify to add to blocked list.
6c. Battery optimization kills service (Android): on next launch subsystem restarts and prompts to disable optimization for Nashaat.

**Special Requirements:**
<ToDo: List the non-functional requirements: exempt apps (Phone, Messages, Emergency, Settings, Nashaat); max 30 blocked apps; usage granularity 60s; 1:1 deduction; service auto-restart after reboot; request battery exemption on Android; app list refresh every 24h; VIP category-based blocking; usage logs retained 90 days then aggregated; blocking state synced to server. />
