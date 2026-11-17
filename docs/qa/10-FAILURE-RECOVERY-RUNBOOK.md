# Failure recovery runbook

Use only these documented actions. Do not improvise privileged commands, bypass a macOS warning, kill browser processes, edit app-group files, or update a remote database manually.

| Failure | Immediate action | Safe recovery | Stop/escalate when |
|---|---|---|---|
| Malicious Script Blocked / Gatekeeper / unidentified developer warning | Stop all Bloom tests; capture visible warning and exact app identity; do not approve/open anyway. | Leave warning intact and hand control to Mac owner/security reviewer. Keep suspicious launcher disabled. | Always. Do not dismiss via override or remove quarantine. |
| Unknown app/build/Team ID/signature/notary | Do not open the app. | Use a separately reviewed trusted artifact only after owner selects it and full identity check passes. | Any identity value missing/mismatched or app is unnotarized. |
| Browser cannot open sites or unrelated apps lose network | Stop case; if Bloom app responsive, use Bloom website Stop control. Keep evidence. | If stop succeeds, retest example.org once with protection off. Do not touch other filters/VPN/security settings. | Stop unavailable, disabled, or network remains affected; hand control to owner. |
| Website target still renders | Record URL, protection preference, monitor/address status, exact timeout, browser and screenshot. | One retry only in a fresh tab if the case allows and control just succeeded; then stop target suite. | Source identity unknown, provider status absent, or unrelated app traffic changed. |
| Bloom says configured but no traffic result | Treat as unverified; do not mark active. | Follow only that case's control/target navigation probe. | Filter cannot be independently enabled or another filter is configured. |
| App hide failure | Capture Calculator window state and Bloom appHideFailed/monitor status. Do not repeatedly launch Calculator. | If Stop is available, stop app blocking; confirm Calculator works normally. | Selected app is not Calculator, work could be lost, or stop control missing. |
| Accessibility/Automation permission dialog appears | Do not approve/deny unless exact test has prior owner authorization. | Mark permission case BLOCKED; don't dismiss dialog until owner instructs. | Prompt is unexpected or identifies unknown app. |
| Permission was revoked and protection fails | Do not claim protection. Complete normal Settings restoration only if approved. | Restore exact prior switch; return to Bloom, refresh, recheck harmless behavior. | Switch cannot be restored or behavior does not recover. Stop other cases. |
| Server rejects or times out Hard/Super grant | Preserve current marker; don't make another request or clear it. | Reconnect only if expected/authorized; retry same request ID once only per case. Native protection must stay blocked until server validation. | Response changes request/session, balance, account, or target unexpectedly. |
| Countdown active when test ends | Do not extend or shorten it. Keep test rules and wait for recorded original expiry, then confirm block. | After expiry, refresh with supported app flow and stop protection. Do not clear marker to imitate cancel. | Deadline, owner, or active state cannot be determined. |
| Easy session open/closed but not settled | Keep usage marker/journal; do not delete or replay with altered values. | Use Bloom supported Finish/Sync once when correct account is signed in. | Another account owns it, server outcome differs, or settlement repeats. |
| Stale/wrong LaunchAgent executable | Stop tests. Record expected and reported paths from status. | Use Bloom ordinary setup UI only if reviewed build reports a safe state and no system warning appears. | It would replace unknown service or current process origin is suspicious. Never manually boot out an unknown agent. |
| Browser address unreadable | Record permission/Automation status and degraded message. | Use case's whole-browser hide test only with recognized browser and permission. | Whole-browser hide fails or browser isn't recognized. Do not change Secure DNS/Shields. |
| App/Bloom crash | Record crash dialog/time; don't relaunch repeatedly. | Follow case-specific restart only after no active work and no countdown issue. | Active reservation/deadline, warning, corrupted state, or unknown provenance. |
| Database engine unavailable | Mark SQL suite BLOCKED and capture non-sensitive socket error only. | Continue source review; rerun only if Docker-compatible engine is already available. | Do not start/reconfigure OrbStack/Docker or connect remote Supabase. |
| Cleanup cannot restore baseline | Stop tests. Record remaining rule, permission, monitor, reservation or protection state. | Leave Bloom protection stopped if possible; preserve original server expiry; contact owner. | Any state could affect normal browsing, personal app access, or credit. |

## Emergency boundaries

- Bloom UI Stop is the first and only routine deactivation path in this playbook.
- System Settings is used only for a permission case with prior specific approval; restore that setting before completion.
- Commands that uninstall system extensions, boot out launch agents, remove quarantine, disable Gatekeeper, alter PF, use root, or directly edit preferences/databases are not approved recovery.
- If app cannot be opened or protection cannot be stopped, do not ask the smaller model to invent a remedy. Hand control to the Mac owner and report exact state.
- Never clear a server countdown marker as a way to cancel a lease. The server's original expiry owns the countdown.
