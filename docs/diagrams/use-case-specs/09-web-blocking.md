Use case Id: UC09    Web Blocking Subsystem

**Brief Description**
The subsystem restricts access to user-configured websites when screen-time balance is depleted. On mobile, blocking is OS-level (iOS Screen Time WebDomain, Android local VPN). On desktop, a browser extension (Chrome/Firefox/Edge) enforces blocking. User configures domains from the app; enforcement is cross-platform.

**Primary actors**
Authenticated User, Subsystem (browser extension / OS-level blocking)

**Preconditions:**
1. User is authenticated. On iOS/Android: same permissions as app blocking (or VPN for Android). On desktop: supported browser with Nashaat extension installed and authenticated.

**Post-conditions:**
1. Extension installed, authenticated, and monitoring (desktop); blocked domains in blocking_rules and synced.
2. Web usage for blocked domains tracked and deducted from balance; at zero balance, "Time's Up" page shown.

**Main Success Scenario:**
<ToDo: List the included use cases. Add rows to the table below if needed />

| Actor Action | Subsystem Response |
|--------------|-----------------|
| 1. (Mobile) User configures blocked websites (Use Case 10); (Desktop) user installs extension and enters pairing code from app. | 2. Mobile: Subsystem registers domains with Screen Time API (iOS) or VPN (Android). Desktop: Subsystem validates 8-char code (5 min validity), returns extension token; extension stores token; app shows "Browser extension connected." |
| 3. User configures blocked sites via app or extension ("+ Add Site", "Block This Site"); changes sync. | 4. Subsystem saves domains to blocking_rules; syncs to extension within 30s. |
| 5. User navigates to blocked domain. | 6. If balance > 0: site loads, usage timer runs, reported every 60s, balance decremented; badge shows balance; at 5/1 min warnings, at 0 block page. If balance = 0: extension/subsystem shows "Time's Up" block page (or OS shield). |
| 7. User opens extension popup and selects "View Stats". | 8. Subsystem shows time on blocked sites today, per-domain breakdown, top 5 this week. |

**Alternative flows:**
2a. Pairing code expired: extension prompts to generate new code from app.
2b. Invalid pairing code: extension shows error; after 5 failures lock 15 min.
2c. Extension token expired (30 days): extension prompts re-authenticate; blocking paused until reconnect.
2d. User disables/removes extension: extension notifies server; app shows "Extension disconnected."
4a. Incognito: blocking only if user enabled extension for incognito; app suggests enabling.
4b. Multiple browsers: each needs own extension and pairing; config shared via API.
4c. Root domain entered: subdomains blocked by default; user can add specific subdomain.
6a. Network error (extension): use cached balance; if cache >10 min, fail closed (block) and message when connection restored.

**Special Requirements:**
<ToDo: List the non-functional requirements: supported browsers Chrome/Firefox/Edge v90+; mobile no extension (OS-level); pairing code 8-char, 5 min, single-use; token 30 days; max 50 domains; subdomains included by default; 60s tracking; 1:1 deduction; cache refresh 60s; fail closed if API unreachable >10 min; config sync 30s; max 3 extensions per user; emergency breaks apply to web. />
