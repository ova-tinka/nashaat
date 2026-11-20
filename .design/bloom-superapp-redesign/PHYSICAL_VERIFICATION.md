# Physical verification checklist

**Status:** Not run on installed app builds. Local policy tests and desktop compilation are not device verification.

Use dedicated test accounts and devices. Record build/version, OS version, test date, and pass/fail only; do not include access tokens, pairing codes, real family names, or personal activity data.

## Readiness

| Platform | Required before verification | Status |
|---|---|---|
| iOS | Install an iOS build on a physical device; use a test parent/child pair | Pending |
| Android | Install an Android build on a physical device; use a test parent/child pair | Pending |
| macOS | Sign and provision the app and system extension, install on a test Mac, then approve only the system permissions needed for the test | Pending; current local bundle and extension are unsigned |
| Windows | Confirm a Windows host/runtime and platform adapter before testing enforcement | Unsupported; browser layout only |

## Checks

| Check | Procedure | Pass evidence | Status |
|---|---|---|---|
| Permission truth | Deny, grant, and revoke the platform permission where the OS supports each transition; reopen Bloom and refresh Devices | Bloom reports the OS-returned state and gives platform-specific recovery steps; no denied state is shown as active enforcement | Pending |
| Native blocking | Select a test app/site, start Focus, check the native status, attempt the selected target, then stop Focus | The target is blocked only when the OS service reports enforcement active; status recovers after Focus ends | Pending |
| Browser coverage | With permission granted, test a controlled URL in each browser Bloom reports as supported; include Safari and Brave on macOS if listed | Supported browsers enforce the configured test rule; unsupported browsers are named as unsupported | Pending |
| Rule sync | Change a parent-managed test rule, sync on the child device, disconnect/reconnect network, and refresh status | Last successful sync time remains visible during refresh failure; a later successful sync updates the time and native status | Pending |
| Restart recovery | Start a test block, restart the app and the OS service/device as supported, then refresh status | Bloom reports actual post-restart enforcement and recovers only when the native adapter confirms it | Pending |
| Family pairing and safe exit | Pair a test child device, enter Child View, try a guardian deep link, then use the parent re-auth flow | Guardian route is refused; parent access requires the configured device credential and creates a fresh parent session | Pending |
| Session recovery | Interrupt an eligible test workout/session and reopen the app on the same device | Resume appears only when the server reports a resumable session; reward completion remains server-confirmed and idempotent | Pending |

Do not report a platform capability as physically verified until its row has a recorded result from that platform. macOS native policy/bridge tests are useful preflight checks but do not substitute for this checklist.
