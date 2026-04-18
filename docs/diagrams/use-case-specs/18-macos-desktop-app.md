Use case Id: UC18    macOS Desktop App

**Brief Description**
A macOS native application that enforces both app blocking and web blocking on the user's Mac. App blocking uses macOS launchd process monitoring or the Screen Time API to terminate or restrict targeted applications. Web blocking is applied via DNS and browser extensions (Safari, Chrome, Firefox). All blocking rules sync bidirectionally with the user's mobile device through Supabase.

**Primary actors**
Authenticated User, macOS System

**Preconditions:**
1. The user is authenticated and the Nashaat macOS app is installed.
2. The user has granted the required macOS permissions (Accessibility, Full Disk Access for HOSTS, or Screen Time API entitlement).
3. The device has an active internet connection to sync rules with Supabase.
4. At least one blocking rule exists in the user's profile.

**Post-conditions:**
1. macOS app blocking rules are active; targeted processes are killed or restricted.
2. macOS web blocking rules are active via DNS and browser extensions.
3. All rule changes made on macOS are reflected in blocking_rules on Supabase and synced to mobile.
4. Rule changes made on mobile are pulled and applied on macOS.

**Main Success Scenario:**
<ToDo: List the included use cases. Add rows to the table below if needed />

| Actor Action | Subsystem Response |
|--------------|-----------------|
| 1. User opens Nashaat on macOS and logs in. | 2. App authenticates via Supabase Auth, fetches existing blocking_rules for the user, and applies them to macOS (process monitor + DNS profile). |
| 3. User selects apps to block on macOS (from an installed app list). | 4. Subsystem saves rules to blocking_rules (item_type: app) and activates macOS process monitor to kill the process if launched. |
| 5. User selects websites or categories to block. | 6. Subsystem saves rules to blocking_rules (item_type: url/category), updates DNS config, and pushes updated extension rules to installed browser extensions. |
| 7. User changes a blocking rule on mobile. | 8. Supabase triggers a real-time update; macOS app receives the change and updates local enforcement within 10 seconds. |

**Alternative flows:**
2a. Required macOS permissions not granted: subsystem shows a step-by-step permissions guide; blocking is inactive until permissions are granted.
4a. Target app is a system-protected process: subsystem shows a warning that the app cannot be blocked and removes it from the selection.
6a. Browser extension not installed: subsystem shows install prompts for Safari/Chrome/Firefox; web blocking via DNS still applies.
8a. Supabase connection lost: subsystem continues enforcing last-known rules locally; queues pending changes and syncs on reconnect.

**Special Requirements:**
<ToDo: List the non-functional requirements that the use case must meet. E.g. macOS 13+ required; rule sync latency under 10 seconds; app blocking via launchd daemon or Screen Time API; web blocking DNS profile + browser extension combo; browser extension available on Safari, Chrome, Firefox; local rule cache persists across app restart; no data loss on offline rule changes. />
