Use case Id: UC10    Manage Blocking Configuration (CRUD)

**Brief Description**
An authenticated user manages which mobile apps and websites are restricted when screen-time is depleted: add, view, modify (schedule, toggle active/paused), and remove. Central configuration hub for Use Cases 08 (app) and 09 (web).

**Primary actors**
Authenticated User

**Preconditions:**
1. User is authenticated; device has internet.
2. For app blocking: OS permissions granted (UC08). For web: extension installed and authenticated (UC09).

**Post-conditions:**
- Add: New item in blocking_rules; monitoring active; extension synced for websites.
- Modify: Config updated; applied in real time (apps) or within 30s (web).
- Remove: Item deleted from blocking_rules; no longer monitored.

**Main Success Scenario:**
<ToDo: List the included use cases. Add rows to the table below if needed />

| Actor Action | Subsystem Response |
|--------------|-----------------|
| 1. User navigates to Settings > Blocking Configuration. | 2. Subsystem displays Apps and Websites tabs with list of blocked items (name, icon, status, schedule, date added) and summary "[X] apps and [Y] websites blocked." |
| 3. User taps "+ Add App", selects app(s), optionally sets schedule, and selects "Add". | 4. Subsystem validates (exempt apps excluded, limits), saves to blocking_rules, starts monitoring, shows "[App Name] added." |
| 5. User taps "+ Add Website", enters domain, sets schedule and subdomains option, selects "Add". | 6. Subsystem validates domain, saves to blocking_rules, syncs to extension in 30s, shows "[domain] added." |
| 7. User taps item, changes status/schedule, selects "Save". | 8. Subsystem updates blocking_rules; effect immediate (apps) or within 30s (web); shows "Configuration updated." |
| 9. User swipes/taps Remove and confirms. | 10. Subsystem deletes from blocking_rules, stops monitoring, shows "[item] removed." |
| 11. User enters bulk edit, selects items, chooses "Pause All Selected" or "Remove All Selected". | 12. Subsystem updates blocking_rules, shows "[X] items paused/removed." |

**Alternative flows:**
2a. Blocking paused (permissions revoked): subsystem shows banner and "Fix Permissions" button.
4a. Max blocked apps (30, VIP 50): subsystem prompts to remove one to add.
4b. Duplicate entry: subsystem shows "[item] is already in your blocked list."
4c. Exempt app selected: subsystem prevents and explains.
6a. Max blocked websites (50, VIP 100): subsystem prompts to remove one to add.
6b. Invalid domain: subsystem shows inline error (valid domain format).
6c. No extension connected (website config): subsystem saves but shows "Install extension" and link.
8a. Custom schedule with no days: subsystem prompts to select at least one day.
10a. Removing last item: subsystem confirms; dashboard suggests adding apps to block.

**Special Requirements:**
<ToDo: List the non-functional requirements: Free 30 apps/50 sites, VIP 50/100; exempt apps; domain validation (dot, no spaces, max 253 chars); subdomains on by default; schedules Always/Weekdays/Weekends/Custom (15-min increments); Paused = not enforced; bulk limit 20 items; changes logged in blocking_audit_log. />
