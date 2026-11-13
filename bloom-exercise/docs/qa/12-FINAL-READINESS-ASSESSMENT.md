# Final macOS readiness assessment

**Assessment updated:** 2026-11-12. **Disposition: NOT READY to call Bloom functional and reliable on macOS.** The notarized host 0.1.0/filter 1.1.7 helper-refresh build is installed. Its broker and monitor were re-registered and Bloom reported both ready, which resolves the earlier 1.1.6 XPC peer rejection. In the latest Brave Private test, `example.org` loaded as the control and the blocked `example.com` target also rendered while protection was enabled. Immediate Brave blocking therefore still fails; a delayed hide result and the exact flow class remain unverified. Calculator remained usable under active app protection in an earlier run. Easy idle expiry charged its reserved interval, but early Finish failed because Bloom reported that the reservation device key was unavailable.

## Decision

The selected Easy policy is a **server-timed access window**. The database calculates elapsed time from the server reservation timestamp until early finish or the effective expiry, caps the debit to the reservation, and ignores a client-supplied duration. Idle time is billed; there is no pause or inactivity refund. This provides verifiable elapsed access accounting. It does **not** prove that the selected app was foreground, a page was interacted with, the user was attentive, or OS enforcement stayed active.

The user supplied `supabase db push` output showing migration `20261111000001_bloom_server_timed_easy.sql` applied and the push completed. Isolated PostgreSQL fixtures independently pass. Read-only linked Supabase CLI inspection returned HTTP 403. A live Easy reservation/idle expiry was observed and the displayed balance reflected its debit; a later ended session could not be synced because the client lacked the device key. The remote schema and session row/`settled_at` were not independently inspected.

**The current installed implementation cannot pass the full macOS reliability suite as written.** The Brave bypass is reproduced on 1.1.1; the exact flow protocol was not traced. Source 1.1.6 adds a UID-scoped in-memory broker for the root/user policy handoff, but the installed 1.1.6 listener rejects the monitor's XPC connection because its signing-information lookup omitted the flag required to return the Team ID. Source 1.1.7 fixes the lookup. Its signed build is awaiting notarization and has not been installed. The host reports broker readiness only after the daemon is active, the monitor is live, and a fresh snapshot is acknowledged; the current installed monitor does not reach that state. Hostless flows without a matching source identity remain best-effort to avoid disrupting unrelated traffic. App enforcement relies on best-effort hiding. Do not claim broad browser or app enforcement.

## Earlier installed build identity

- App: `/Applications/Bloom Exercise.app`, host version `0.1.0`, bundle ID `com.focusflow.focusFlowFlutter`, Team ID `SSYR69RTPK`, host CDHash `103ee4e9167fa620724eb1f2c8b44de2b8532703`.
- Filter extension: `com.focusflow.focusFlowFlutter.filter`, version/build `1.1.0/1.1.0`; monitor ID `com.focusflow.focusFlowFlutter.monitor`. Filter version is intentionally independent of host version.
- Strict deep code-sign verification passed; Gatekeeper accepted it as `Notarized Developer ID`; stapler validation passed. Apple notary submission `da86a10d-f1f8-4635-a831-80e980cdcc04` was Accepted.
- `systemextensionsctl` reports filter `1.1.0/1.1.0` activated/enabled. The prior `1.0/1` registration is terminated and waiting to uninstall on reboot. No restart was performed.
- No malware warning appeared. The suspicious launcher was not run. Following the user's authorization, Bloom reported the background monitor Ready and Accessibility trusted. No permission was toggled or revoked/restored. See `09-TEST-DATA-AND-ENVIRONMENT.md` for build identity and current environment.

### Latest Brave test and mitigation build

- Live retest app: `/Applications/Bloom Exercise QA 1.1.1.app`, host 0.1.0/filter 1.1.1, signed and notarized. Filter 1.1.1 was activated/enabled.
- Mitigation build: host 0.1.0/filter 1.1.2. Focused native checks and local Supabase build passed. Apple accepted submission `4873975e-0713-4615-aba7-ea86613e9c30`; stapling and validation passed. Strict signature verification passed and Gatekeeper accepted the installed `/Applications/Bloom Exercise QA 1.1.2.app` as `Notarized Developer ID`. Notarized archive SHA-256 is `09421ea8dc9d629744fd78d0baf3cb64c5e77b2849cecd6c9e6a907b9c181806`.
- `systemextensionsctl` reports the 1.1.2 system extension activated/enabled. A website start request from the repository build was rejected because the host was outside `/Applications`; CUA timed out opening the installed app. The website policy remains off. The monitor LaunchAgent is running; Accessibility and Brave Automation report trusted/available. No `example.com` rule was saved and no Brave test was started in this follow-up.
- Source follow-up, filter 1.1.6: `MacPolicyBroker` validates same-team peer identity, accepts monitor snapshots only for the effective non-root UID, serves snapshots only to the root filter, and expires state using the shared monotonic clock/boot marker. Browser hostless drops and earned-access decisions consume this snapshot instead of root app-group preferences. The host only reports website usage readiness after the service is enabled, the monitor is live, and it has recently received a broker acknowledgement. Native broker/readiness tests, unsigned component builds, and strict verification of the signed local app pass. Apple accepted notarization submission `6aaba6ec-1370-414b-a131-50dbcdc62ff0`; the app was stapled and Gatekeeper accepts it as `Notarized Developer ID`. Current notarized archive: `src-tauri/target/release/bundle/macos/Bloom Exercise 0.1.0 filter 1.1.6 notarized.zip`; SHA-256 `6f273c09f22eaff7434cd0c9efb9f53e91d79e78dfbbd0bebd345192c86cd005`. The QA copy is installed and open; `SMAppService` approval, actual peer identity at runtime, and Brave target/control behavior remain unverified.

### Current broker identity fix

- Live 1.1.6 state: the Network Extension is `[activated enabled]`; the policy-broker LaunchDaemon is running and its endpoint is active. The user LaunchAgent runs from `/Applications/Bloom Exercise QA 1.1.6 previous.app`. Privacy-safe system logs show repeated XPC peer rejection.
- Root cause: `SecCodeCopySigningInformation` was called with flags `0`, which returned the monitor's signing identifier but omitted its Team ID. The broker's same-team peer check therefore rejected the signed monitor. A local Security.framework probe returned the expected monitor identifier and Team ID when the `kSecCSSigningInformation` flag was included.
- Source filter 1.1.7 requests the signing information and has a regression assertion. `npm run test:macos-native`, `npm run test:filter-version`, `npm run build:macos-filter`, `npm run desktop:build:local`, and strict code-sign verification pass. Signed local-Supabase archive: `src-tauri/target/release/bundle/macos/Bloom Exercise 0.1.0 filter 1.1.7 broker identity fix.zip`; SHA-256 `31ab2e430b2770ee0d8bb9ceb490e2015bae18fe9b2ef3179333bda343402e40`.
- `notarytool submit` could not begin: the `BloomNotary` Keychain profile and the previously supplied item label were not present in the login, system, metadata, or listed temporary Keychains. No credential was read or printed, no notarization submission ID was created, and 1.1.7 was not installed. No new browser target/control test ran.

## Current live results

| Check | Result | Evidence and limit |
|---|---|---|
| Trusted app identity | PASS for notarized 1.1.1, 1.1.2, 1.1.6; 1.1.7 signed only | 1.1.6 is installed at `/Applications/Bloom Exercise QA 1.1.6.app`; strict signature, stapler validation, and Gatekeeper assessment pass. The 1.1.7 local build passes strict signing but is not notarized or installed. |
| Filter setup/stop | FAIL at broker handoff on installed 1.1.6 | `systemextensionsctl` reports 1.1.6 activated/enabled and `launchctl` reports the broker daemon running with an active endpoint. Privacy-safe logs show recurring monitor XPC peer rejection. Bloom Background Activity is on; the current monitor process runs from the preserved previous app copy. The source fix is in signed 1.1.7, which is not yet notarized or installed. |
| Safari | PASS, narrow, earlier 1.1.0 run | `example.org` loaded with filtering on; a fresh `example.com` URL produced Safari's server-connection error while protection was on; a fresh target loaded after protection stopped and the rule was cleared. This is one observed fresh-navigation lifecycle, not repeatability or coverage of existing connections, redirects, subdomains, or restarts. Safari was not retested on 1.1.1. |
| Brave Private | FAIL, latest browser retest; broker handoff separately FAIL | On 1.1.1, `example.org` loaded. Fresh `example.com` loaded before and after monitor setup; Bloom reported `Brave · address check: automation` on the second attempt. No 1.1.6 or 1.1.7 browser target/control trial ran. The test used a newly opened Private window in the current macOS user because no dedicated QA user/profile was available. The isolated test window was closed and the website rule removed. |
| Persisted rule cleanup/settings | PASS, limited | The temporary `example.com` rule was cleared and remained absent in Focus. Hard mode, 10 repetitions/1 minute, and Asia/Qatar were restored. The saved Calculator rule remains; no app reopen/restart was performed in the follow-up. |
| App blocking / Calculator | FAIL, earlier 1.1.0 run | With the monitor Ready and Accessibility reported trusted, Calculator remained visible and usable while app protection was active. After Stop, Calculator worked normally. Protection is off now; the manual Calculator rule remains saved. |
| Easy idle expiry/accounting | PASS, narrow | An idle 0.25-minute reservation expired and the displayed balance changed from 4.33 to 4.08. A later one-minute window also expired; final displayed balance was 2.58. These display observations do not independently prove remote `settled_at`. |
| Easy early finish / sync | FAIL | Bloom displayed “The device key for this reservation is unavailable.” Leaving and returning to Focus did not restore Sync. The full early-finish/refund lifecycle is not verified; see R-19/EASY-04. |
| Hard / Super Hard expiry | INCONCLUSIVE / NOT RUN | The earlier 0.25-minute Hard request debited about 0.0533 minutes but no active countdown/expiry/reblock was observed. Super Hard was not attempted. |
| Permission loss/recovery, restart, physical second device | NOT RUN/BLOCKED | Monitor/Accessibility were reported ready/trusted, but no permission was revoked/restored or OS restart performed. A second physical device is unavailable. |

The follow-up UI remained accessible. No Safari/Brave Automation prompt appeared; Bloom later reported Safari's address as readable. Safari's private test window became locked by macOS and was not unlocked; the regular Safari test tab was returned to `example.org`. No Brave tab was opened during this follow-up.

## What is verified by automated checks

Focused source checks on 2026-11-11 at 12:55–12:56 Asia/Qatar passed:

- `npm run typecheck`, `npm run lint`, `npm run test:macos-state` (2 tests), `npm run test:macos-native`, and `cargo check --locked --manifest-path src-tauri/Cargo.toml`.
- Isolated PostgreSQL 14.21 run: all 14 Bloom migrations and 11 SQL fixtures, including server-timed Easy debit, ignored forged low/high client durations, idempotent settlement, expiry, balance/ownership, and concurrency assertions.
- Synthetic reservation/concurrency and two-logical-device fixtures. These are simulations, not physical device tests.
- The typecheck, lint, state/native, Rust, isolated PostgreSQL, and QA documentation checks were rerun on 2026-11-11 14:31–14:33 Asia/Qatar; all exited 0. `test:macos-state` again reported two passing tests and the same non-failing Node module-type warning.
- `python3 tests/validate-qa-docs.py` — earlier PASS at 2026-11-11 14:33 Asia/Qatar; 13 QA docs and 30 structured cases validated. This follow-up adds EASY-04 and changes current outcomes; validation is pending.

These tests establish source behavior and isolated database invariants. They do not establish current remote schema state, live Easy settlement, browser enforcement, app hiding, or permission/restart recovery.

## Architecture readiness

- **Website filtering:** Some visible hostnames and TCP/TLS SNI are matchable. The Brave bypass remains a live FAIL on 1.1.1. A live privacy-safe stream showed hostless UDP allows but did not tie one to the target; QUIC remains unconfirmed. Installed 1.1.6 has an active filter and daemon, but the monitor-to-broker XPC handoff fails. Source 1.1.7 fixes the missing signing-information flag; notarization, installation, fresh snapshot acknowledgement, and live target/control tests remain. Do not blanket-drop UDP or unidentified applications. Apple URL Filter remains a separate WebKit/URLSession option and cannot make Brave participate.
- **Provider health:** The UI reports broker readiness only after the daemon, monitor, and fresh snapshot acknowledgement are present. The current daemon does not accept the monitor connection, so the policy snapshot is not confirmed and provider traffic is not proven.
- **Application enforcement:** `NSRunningApplication.hide()` is best effort and can race. The live Calculator test failed: its window remained usable while app protection was active. Bloom cannot claim launch denial.
- **Easy measurement:** Server time verifies the access-window duration only. If product intent is actual foreground use or attention, a distinct trustworthy OS measurement source remains required; this server-timed choice does not provide it.
- **Security:** `tauri.conf.json` still has `csp: null`; audit of the renderer command surface remains open. The local account and app-group state are within the logged-in user boundary.
- **Cross-device:** Database simulation passes; no second physical device was available.
- **Reliability:** No evidence-based performance budgets or paired CPU, memory, energy, latency, drift, or recovery measurements exist.

## Remaining release blockers

1. **P1 website enforcement:** Brave Private bypass is reproduced on notarized 1.1.1 with the monitor active. Installed 1.1.6's system extension and daemon are active, but XPC peer checks reject the monitor. Restore the saved notary profile, notarize/install signed 1.1.7, verify a fresh broker snapshot acknowledgement, then test `example.com` and `example.org` in Brave. Keep unsupported or unobservable flows degraded.
2. **P1 truthful readiness:** Add an Apple-supported provider lifecycle/readiness channel or keep status explicitly configured/degraded. Do not represent enabled preferences as active enforcement.
3. **P1 monitor and app enforcement:** The monitor reports Ready and Accessibility trusted, but Calculator remained usable. Investigate hide failure/status propagation and provide a supported way to clear saved manual app rules. Hiding remains best effort.
4. **P1 Easy recovery:** Fix the missing request/device-key path (R-19), add an automated route/reload recovery regression, and verify it in an isolated fixture before any further live credit use. Independently inspect deployed migration/session settlement through an authorized read-only source when available. Do not claim foreground-use measurement.
5. **P1 Brave coverage:** Verify 1.1.2 in an isolated Brave profile with the monitor active and privacy-safe flow decisions. Do not alter Shields/Secure DNS or deny unrelated traffic.
6. **P1 security posture:** Add a narrow CSP and review renderer-to-native command authorization.
7. **P1 recovery:** Verify actual permission loss/restore, monitor/app restart, sleep/wake and reboot recovery on the exact build, with safe cleanup.
8. **P1 shared account:** Physical two-device ownership/synchronization and account isolation remain blocked until a second device is available.
9. **P2 cleanup/readiness:** Old filter 1.0 waits for reboot uninstall; current 1.1 remains enabled though Bloom protection is stopped. No restart was performed.
10. **P2 reliability:** Define product budgets from measured baseline, then take repeated paired measurements.

## Stage results

| Stage | Result | Evidence |
|---|---|---|
| 1. Read-only discovery | Complete | `01-ARCHITECTURE-INVENTORY.md`; project changes and unknowns recorded |
| 2. External research | Substantially complete | `02-OPEN-SOURCE-RESEARCH.md`, primary Apple/Tauri sources and inspected project code |
| 3. Theoretical completeness | Complete with negative assessment | `03-FEATURE-COMPLETENESS-AUDIT.md`; platform coverage and best-effort limits remain |
| 4. Gap remediation | Partial | Source 1.1.7 fixes the broker signing-information lookup; helper fingerprint refresh now re-registers stale broker/monitor processes. The notarized build is installed and Bloom reports readiness. Brave Private still rendered the blocked target in the live test. Easy finish-key recovery and Calculator hide remain FAIL |
| 5. Automated verification | Partial | Native suite including helper-refresh policy, filter version, local signed build, strict signatures, Apple notarization, stapling, and Gatekeeper assessment pass. Android execution remains blocked; live website enforcement still fails in Brave Private |
| 6. Computer-use preparation | Complete | `python3 tests/validate-qa-docs.py` passed on 2026-11-12 after the latest tracker updates: 13 QA documents, 31 unique cases, required fields, outcomes, tracker rows, and whitespace. |
| 7. Real Mac end-to-end | Partial; suite FAIL | Safari passed one narrow 1.1.0 fresh-navigation lifecycle. Refreshed broker/monitor readiness passes on 1.1.7, but Brave Private loaded both the `example.org` control and blocked `example.com` target. Delayed hide, Calculator hide, and Easy early-finish recovery remain unverified or FAIL |
| 8. Final readiness | Not ready | P1 website, provider health, monitor/app, Easy live, CSP and recovery gaps remain |

## Safe current state and next action

Bloom website protection remains stopped and the temporary `example.com` rule remains cleared. App protection is off, but the saved `com.apple.calculator` rule remains. The final Easy window ended locally, but Finish/Sync could not use its device key, so its remote settlement row is unverified. Bloom Background Activity is on. The installed 1.1.6 filter is activated/enabled and its broker daemon is running, but the monitor process is from the preserved previous app copy and its XPC connection is rejected. Source 1.1.7 is signed but not notarized or installed because the saved profile is absent. The suspicious launcher remains unused. Old filter 1.0 registrations await reboot removal. No restart was performed.

CUA could not access the Bloom, Brave, or System Settings windows in this session, and no website rule was changed or new browser page tested. Next, restore the existing notary Keychain profile, notarize/install 1.1.7, verify the monitor-to-broker snapshot acknowledgement, then test safe `example.com` target and `example.org` control in Brave. Do not start more live credit sessions until EASY-04 recovery passes its isolated fixture. Keep the Brave failure open until the target is blocked and the control remains reachable.
