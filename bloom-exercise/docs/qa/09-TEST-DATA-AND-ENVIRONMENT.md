# Test data and environment

This file is the single source for case prerequisites. Do not fill unknown values by guessing. Never put secrets, access tokens, passwords, .env, keychain output, database dumps or private browser data here.

## Required environment record

Create a copy of this table in the execution tracker for each run:

| Field | Value |
|---|---|
| Run ID / operator / timestamp + timezone | MAC-LIVE-20261111-BRV-1.1.1; Codex; 2026-11-11; individual UI timestamps not captured |
| macOS version and build | 27.2.1 / 26B131 (`sw_vers`) |
| Hardware / architecture | MacBook Air / arm64 |
| App version / CFBundleVersion | Live retest: host `0.1.0`; filter `1.1.1/1.1.1`. Notarized 1.1.2 build: host `0.1.0`; filter `1.1.2/1.1.2`; independent filter version is intentional |
| App bundle path | Live retest: `/Applications/Bloom Exercise QA 1.1.1.app`. Notarized 1.1.2 copy: `/Applications/Bloom Exercise QA 1.1.2.app`; build source remains at `src-tauri/target/release/bundle/macos/Bloom Exercise.app` |
| App bundle SHA-256 | Bundle hash not collected for the live 1.1.1 QA copy. Notarized 1.1.2 archive SHA-256: `09421ea8dc9d629744fd78d0baf3cb64c5e77b2849cecd6c9e6a907b9c181806`. |
| App, monitor and system-extension IDs | `com.focusflow.focusFlowFlutter`; `com.focusflow.focusFlowFlutter.monitor`; `com.focusflow.focusFlowFlutter.filter` |
| Developer Team ID (not certificate/private-key data) | `SSYR69RTPK` |
| Signature verification | PASS for tested 1.1.1 QA copy per prior notarization verification. New 1.1.2 app passed `codesign --verify --deep --strict`; its CDHash was not recorded. |
| Gatekeeper assessment | 1.1.1: PASS, `Notarized Developer ID`. 1.1.2: PASS, `Notarized Developer ID`; installed copy accepted by Gatekeeper. |
| Notarization ticket and stapler validation | 1.1.1: PASS; Apple submission `8ec02138-2581-422b-9666-8a4a10b75083` accepted and stapled. 1.1.2: PASS; Apple submission `4873975e-0713-4615-aba7-ea86613e9c30` accepted; staple and validation passed. |
| Host/filter profile app IDs and required entitlements | Inspected: host has content-filter/system-extension-install entitlements and app group `SSYR69RTPK.com.nashaat.bloomexercise`; filter has app sandbox/content-filter-provider and the same app group. Monitor includes the app group and Apple Events entitlement. |
| Host/filter version policy | Live test: host `0.1.0`; filter `1.1.1/1.1.1`. New uninstalled build: host `0.1.0`; filter `1.1.2/1.1.2`. Versions intentionally differ; the filter's independent version must be monotonic to avoid an extension downgrade/update-order conflict. |
| Test project/environment name | Nonproduction Bloom QA Supabase project; user-provided CLI output reports migration `20261111000001_bloom_server_timed_easy.sql` applied. Project ref omitted. Independent linked CLI reads returned HTTP 403. |
| Disposable user/account visible identifier | Existing disposable Bloom test account; identifier omitted. An earlier live Easy test changed the displayed balance from `4.33` to `2.58` minutes; no new credit or workout was used in the Brave retest. |
| Dedicated macOS QA user already exists | No separate QA macOS user was established. |
| Browser names/version/profile; Shields/Secure DNS left unchanged | Brave version not recorded. A new Brave Private window in the current macOS user was used for the bounded retest; there is no dedicated QA user/profile. `example.org` loaded and fresh `example.com` targets loaded before and after monitor setup. Brave Shields/Secure DNS and settings were not changed; the isolated test window was closed and existing personal tabs were not navigated. |
| Accessibility permission | Bloom reported Accessibility trusted after the user-authorized monitor setup. No separate TCC toggle was changed or revoked/restored during this follow-up. |
| Apple Events permissions by browser | Not independently inspected; no browser-specific permission change was made. |
| LaunchAgent state and current executable path | The monitor process is running from `/Applications/Bloom Exercise QA 1.1.2.app/Contents/MacOS/BloomAppMonitor`; app-group heartbeat is current and `AXIsProcessTrusted()` reports true. Browser Automation status is `available` for the current Brave check. |
| System extension state and provider health evidence | Filter 1.1.1 was activated/enabled in the prior live run; older 1.1.0 and 1.0/1 registrations await reboot removal. `systemextensionsctl` reports filter 1.1.2 activated/enabled. Website protection remains off: the repository copy’s activation/start request was rejected because it was outside `/Applications`, and CUA could not open the installed app. Provider health has no independent host-visible acknowledgement. |
| Network/VPN/proxy conditions (non-sensitive summary) | No test-specific network/VPN/proxy change; detailed network environment was not recorded. |
| Current rules, mode, daily limit, timezone, balance | Website filter stopped; temporary `example.com` rule cleared. App protection is off; saved manual `com.apple.calculator` rule remains. Hard mode restored; per-exercise rate is 10 repetitions for 1 minute, exercise-time fields blank, timezone Asia/Qatar. Displayed balance `2.58` minutes. |
| Evidence storage path | No screenshot or log file artifact saved. UI/terminal observations are transcribed in this tracker and `../macos-verification.md`; no private browser data included. |
| Performance budget reference and rationale | UNSET; PERF-01 is BLOCKED until the owner records budgets based on paired baseline measurements and product needs |
| Performance run conditions (power, network, workload, sample method) | UNSET; record identically for Bloom-off/on rounds |

## Build identity procedure (read-only)

Set the exact app path by visually selecting the reviewed app. Do not use wildcard paths, old Test builds, a temporary build, or any executable with unknown provenance. In Terminal, run these read-only commands after replacing the path with the exact visible path:

~~~sh
shasum -a 256 "/Applications/REVIEWED-Bloom.app"
codesign --verify --deep --strict --verbose=2 "/Applications/REVIEWED-Bloom.app"
codesign -dv --verbose=4 "/Applications/REVIEWED-Bloom.app" 2>&1
spctl --assess --type execute --verbose=4 "/Applications/REVIEWED-Bloom.app"
xcrun stapler validate "/Applications/REVIEWED-Bloom.app"
~~~

Expected: same Developer Team ID in host and nested system extension; strict signature passes; Gatekeeper accepts; stapler validates; filter bundle ID matches configured extension ID; the documented independent filter version is not older than its prior registered version; monitor path reported by Bloom belongs to this same app copy. Host and filter versions are intentionally allowed to differ. If any command indicates unnotarized, invalid, unknown, mismatched, or missing, stop and mark SAFE-01 BLOCKED/FAIL. Do not use quarantine removal, Gatekeeper overrides, or another app copy.

The command path is a placeholder; replace only with the exact reviewed app path. Do not type credentials into Terminal. Avoid commands that print embedded app plist public key; a publishable key is not required in QA evidence.

## Harmless test values

| Purpose | Value |
|---|---|
| Blocked website | example.com |
| Blocked subdomain | www.example.com |
| Accessible control | example.org |
| Safe app target | Calculator, bundle identifier com.apple.calculator |
| Browser targets | Safari and Brave only if installed/listed as supported; add other listed installed browsers if available |
| Hard/Super test request | 0.25 min (15 s), only when server confirms >=15 s available |
| Easy reservation | Reserve 1.0 min only if account allows it; record elapsed access from reservation through Finish. Idle time is billable. |
| Credit test account | Existing dedicated disposable nonproduction account only; visible identifier stays in local tracker |
| Workout test record | Do not add/complete a workout unless owner explicitly approved balance mutation; prefer an existing disposable fixture |

Never use displayed total as Hard daily allowance. Hard eligibility is bounded by weekly earnings/7, local-day remaining, available balance, earliest expiry bucket, and server end. Super Hard further limits by configured cap. If actual allowance cannot be verified from the disposable fixture, mark credit cases BLOCKED.

## Expected arithmetic

These are deterministic fixture examples, not values to write into a real account.

- Easy: starting balance B, reserved R, server elapsed access U, all in minutes. `U = min(R, max(0, min(server_finish, access_expires_at) - billing_started_at))`. Expected final balance is B - U; unused amount R - U becomes available again. Example: B=5.00, R=1.00, U=0.50 → final 4.50, 0.50 returned. SQL truncates spent minutes to 4 decimals; 30 seconds records 0.5000.
- Easy idle time: inactivity does not pause the access window. For a 20-second early finish, expect about 0.3333 minutes debited, subject to timestamp and UI observation tolerance. An immediate finish may still debit a small amount for RPC elapsed time; do not require a zero debit.
- Easy measurement boundary: the server verifies elapsed grant duration. It does not verify foreground app use, browser interaction, attention, or OS enforcement continuity.
- Hard/Super: server grant G seconds; expected server end is server_started_at + G, bounded by local day end and earliest credit expiration. Same request is ended after expiry and cannot restart. Verify one debit in disposable server fixture, subject to SQL floor/expiry rules.
- Requested minutes are not expected grant. Record returned remaining_ms.
- Balance cannot go negative; duplicate finish/debit cannot add a second ledger expense.

## Browser and permissions

- Keep Safari/Brave security settings at their current dedicated-profile values. Record Secure DNS, Shields and extensions as shown; do not change them.
- Use new tabs and exact example domains only. No personal bookmarks/accounts.
- Record Accessibility and Automation permission state in Bloom/System Settings before a permission test. Permission test is BLOCKED without approval for exact setting change.
- A separate macOS QA user is required but does not isolate the content-filter system extension. Ensure no other user/network depends on this Mac before enabling.

## Cleanup baseline

Record initial website/app rules, mode, permissions, monitor status, and balance. After suite: Bloom protection off, remove only example.com and Calculator user-managed rules, settle test usage through supported Bloom flow, restore permission switches, close test tabs, and sign out only if initially signed out. Do not remove parent-managed rules. If cleanup requires direct database, Keychain, System Extension or LaunchAgent modification, stop and escalate.

## Isolated SQL verification

The primary runner is `npm run test:schema`, which creates a disposable PostgreSQL 16 Docker container. If Docker is unavailable and a local PostgreSQL server installation is present, set `BLOOM_TEST_POSTGRES_BIN` to that installation's `bin` directory and run `bash tests/run-schema-local.sh` from `bloom-exercise/`. The local runner starts a temporary cluster on a private Unix socket with TCP disabled, applies only Bloom migrations and fixture tests, runs concurrency checks, then stops and deletes that temporary cluster. Do not set database URLs or point tests at Supabase/production.
