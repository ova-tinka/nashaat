Use case Id: UC19    Windows Web Blocking App

**Brief Description**
A Windows desktop application that provides web blocking only (no app blocking). Web blocking is enforced by modifying the Windows HOSTS file and deploying browser extensions for Chrome, Firefox, and Edge. The user's blocked domains are fetched from their Supabase profile and kept in sync. App blocking is explicitly out of scope for Windows.

**Primary actors**
Authenticated User, Windows System, Browser Extension

**Preconditions:**
1. The user is authenticated and the Nashaat Windows app is installed.
2. The app has been run with elevated privileges (Administrator) to modify the HOSTS file.
3. The device has an active internet connection.
4. At least one web blocking rule exists in the user's profile.

**Post-conditions:**
1. The Windows HOSTS file contains entries for all blocked domains, routing them to 127.0.0.1.
2. Browser extensions are active and enforce block pages for matched domains.
3. Changes to blocking rules are reflected in both the HOSTS file and browser extension config.
4. Rule changes sync with Supabase so mobile and macOS apps remain consistent.

**Main Success Scenario:**
<ToDo: List the included use cases. Add rows to the table below if needed />

| Actor Action | Subsystem Response |
|--------------|-----------------|
| 1. User opens Nashaat on Windows and logs in. | 2. App authenticates via Supabase, fetches blocking_rules (item_type: url), and writes blocked domains to the Windows HOSTS file; sends updated domain list to installed browser extensions. |
| 3. User adds a new domain or selects a category to block. | 4. Subsystem saves the rule to blocking_rules via Supabase, appends the domain(s) to the HOSTS file, and pushes updated config to browser extensions. |
| 5. User removes a blocking rule. | 6. Subsystem deletes the rule from Supabase and removes the corresponding HOSTS file entries and extension rule. |
| 7. Rule change is made on mobile. | 8. App receives Supabase real-time update, rewrites affected HOSTS entries, and refreshes browser extension config. |

**Alternative flows:**
2a. App not run as Administrator: subsystem prompts user to restart with elevated privileges; blocking is inactive until done.
2b. Browser extension not installed: subsystem shows install prompts for Chrome, Firefox, and Edge; HOSTS-based blocking still applies.
4a. Domain already blocked: subsystem deduplicates and confirms without creating a duplicate HOSTS entry.
8a. Supabase offline: subsystem continues with last-known HOSTS file; queues changes and syncs on reconnect.

**Special Requirements:**
<ToDo: List the non-functional requirements that the use case must meet. E.g. Windows 10+ required; Administrator privileges required for HOSTS modification; HOSTS file backed up before first write; app blocking explicitly not supported on Windows; browser extension available for Chrome, Firefox, Edge; HOSTS sync latency under 5 seconds; local state persists across restarts. />
