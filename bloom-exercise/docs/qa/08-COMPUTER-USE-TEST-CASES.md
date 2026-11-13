# Computer-use test cases

Every case has the required fields. Each numbered execution step includes its observable expected result inline as **expected:**. ENV-00 means every field in 09-TEST-DATA-AND-ENVIRONMENT.md was observed and populated; any UNSET/UNVERIFIED prerequisite blocks the case. Execute in ID order and update one tracker row per attempt.

## Suite A — safe environment

### SAFE-01 — Identify trusted build

- **Test ID:** SAFE-01.

- **Feature:** Build safety and identity. **Objective:** Prove exact app, extension and monitor are one reviewed signed/notarized build.
- **Priority:** P0. **Risk:** Unknown/stale code could trigger warnings or install global filtering.
- **Prerequisites:** Owner selected an existing test app; do not install/rebuild. **Environment:** ENV-00; read-only Terminal.
- **Test data:** Exact app path, SHA-256, Team ID, bundle IDs; no secrets. **Initial state:** Bloom protection stopped; suspicious launcher disabled.
- **Preparation steps:** Select app in Finder and confirm name/path.
- **Execution steps:** 1. Run SHA-256 command from 09; **expected:** one digest recorded. 2. Run strict code-sign verify; **expected:** exit success. 3. Read signature details; **expected:** same expected Team ID. 4. Run Gatekeeper assessment; **expected:** accepted. 5. Validate stapled ticket; **expected:** succeeds. 6. Read host/filter IDs and versions; **expected:** IDs/team match and the documented independent filter-version policy is satisfied; host/filter versions need not be identical.
- **Evidence to capture:** Digest, versions, IDs, Team ID, exit statuses; redact user path if shared. **Pass criteria:** All identity checks match one artifact. **Fail criteria:** Invalid, unknown, mismatched or unnotarized.
- **Recovery procedure:** Do not open/repair/re-sign; stop. **Cleanup procedure:** Close Terminal without copying unrelated output.
- **Related code:** scripts/build-macos-filter.cjs; scripts/sign-macos-app.cjs; src-tauri/tauri.conf.json. **Related automated tests:** AUTO-NATIVE-01; artifact checks manual.
- **Dependencies:** None. **Retry policy:** One retry only for an identified path/typing error, same bundle. **Escalation rule:** Stop on warning or provenance uncertainty.

### SAFE-02 — Confirm isolated test user and account

- **Test ID:** SAFE-02.

- **Feature:** Test data isolation. **Objective:** Confirm pre-existing dedicated QA user/profiles and disposable nonproduction Bloom account.
- **Priority:** P0. **Risk:** System filter is global; personal sessions could be affected.
- **Prerequisites:** Dedicated macOS user/browser profiles already exist; account owner confirms nonproduction project. **Environment:** ENV-00; active user is QA user.
- **Test data:** example.com, example.org, Calculator, visible test account identifier. **Initial state:** Bloom protection stopped.
- **Preparation steps:** Do not create user/profile.
- **Execution steps:** 1. Read current user from macOS menu; **expected:** recorded QA user. 2. Read visible Bloom account identifier; **expected:** disposable account. 3. Read Safari and Brave profile labels; **expected:** dedicated profiles. 4. Confirm no other user/personal work depends on Mac during test; **expected:** owner confirms.
- **Evidence to capture:** Non-sensitive labels and confirmation timestamp. **Pass criteria:** All observations match. **Fail criteria:** Wrong user/account/profile or other user needs Mac.
- **Recovery procedure:** Sign out only through normal UI if authorized; otherwise stop. **Cleanup procedure:** Leave profiles unchanged.
- **Related code:** src/lib/auth.tsx; src/components/macos-focus.tsx. **Related automated tests:** None.
- **Dependencies:** SAFE-01. **Retry policy:** One selection of an already existing QA profile. **Escalation rule:** Missing dedicated user/profile means BLOCKED.

### SAFE-03 — Permission and protection baseline

- **Test ID:** SAFE-03.

- **Feature:** Permission/service state. **Objective:** Record initial state before live behavior.
- **Priority:** P0. **Risk:** Tests may affect networking or leave permissions changed.
- **Prerequisites:** SAFE-01/02 PASS. **Environment:** ENV-00; read-only Settings.
- **Test data:** Accessibility, browser Automation, monitor path/state, website/app rules, mode, timezone, daily limit, balance. **Initial state:** Bloom stopped.
- **Preparation steps:** Open Focus and informational System Settings pages only.
- **Execution steps:** 1. Confirm no malicious-script/Gatekeeper warning; **expected:** absent. 2. Read website/app status; **expected:** stopped or explicit unknown. 3. Read monitor path/state; **expected:** current bundle or unavailable, no unknown path accepted. 4. Record Accessibility/Automation state without switches; **expected:** on/off/unknown per permission. 5. Record rules/mode/timezone/limit/balance; **expected:** baseline captured.
- **Evidence to capture:** Focus status, permission states, timestamp; no logs with tokens/history. **Pass criteria:** All fields recorded, no warning, no active reservation. **Fail criteria:** warning, unknown process, active reservation or another provider.
- **Recovery procedure:** No state changes; stop. **Cleanup procedure:** Close Settings only.
- **Related code:** BloomAppController.swift; BloomFilterController.swift; BloomAppMonitor.swift. **Related automated tests:** AUTO-MAC-01 not automated.
- **Dependencies:** SAFE-02. **Retry policy:** One Focus status refresh. **Escalation rule:** Unknown filter/process/lease blocks all tests.

## Suite B — Safari

### WEB-SAF-01 — Baseline and new-navigation blocking

- **Test ID:** WEB-SAF-01.

- **Feature:** Safari website enforcement. **Objective:** example.org stays accessible; example.com blocks only while Bloom is enabled.
- **Priority:** P1. **Risk:** Cache or general network failure creates false pass.
- **Prerequisites:** SAFE-01..03 PASS; Safari listed supported; no other user depends on filter. **Environment:** ENV-00; use measured timeout from 07.
- **Test data:** example.com rule; example.org control; dedicated Safari window. **Initial state:** Filter stopped, no credit.
- **Preparation steps:** Ensure example.com rule exists using Bloom UI.
- **Execution steps:** 1. New Safari tab → example.org; **expected:** renders and is timed. 2. New tab → example.com; **expected:** renders with filter off. 3. Focus: Set up website filter, then Save and start blocking; **expected:** configured; provider health recorded separately. 4. Fresh tab → example.org; **expected:** renders in timeout. 5. Fresh tab → example.com; **expected:** does not render by timeout. 6. Focus: Stop blocking; **expected:** disabled. 7. Fresh tab → example.com; **expected:** renders.
- **Evidence to capture:** Per-navigation timing/result, Focus status, screenshots for anomalies. **Pass criteria:** Control steps 1/4 load; target steps 2/7 load and step 5 fails by timeout. **Fail criteria:** Control blocked, target loads while configured, target remains blocked after stop.
- **Recovery procedure:** Bloom Stop per runbook. **Cleanup procedure:** Stop and restore initial rule state; verify example.com loads.
- **Related code:** BloomFilterController.swift; BloomFilterDataProvider.swift; WebsiteRules.swift; MacBrowserAddress.swift. **Related automated tests:** AUTO-NATIVE-01 only.
- **Dependencies:** SAFE-03. **Retry policy:** One fresh-tab retry only if control just succeeded. **Escalation rule:** Cache/flow ambiguity is INCONCLUSIVE, not pass.

### WEB-SAF-02 — Existing tab, reload, subdomain, window and restart

- **Test ID:** WEB-SAF-02.

- **Feature:** Rule propagation. **Objective:** Distinguish old displayed content from a new blocked request.
- **Priority:** P1. **Risk:** Cache/socket hides propagation failure.
- **Prerequisites:** WEB-SAF-01 PASS. **Environment:** ENV-00; same timeout.
- **Test data:** example.com, www.example.com, example.org only. **Initial state:** Filter off; target and control loaded in separate tabs.
- **Preparation steps:** With Bloom off, confirm both sites render before start.
- **Execution steps:** 1. New tab → http://example.com; **expected:** record initial redirect/final URL while protection is off. 2. New tab → www.example.com; **expected:** it resolves/renders while protection is off; if DNS/page is unavailable, mark only the subdomain subcase BLOCKED, never count DNS failure as Bloom block. 3. Enable Bloom; **expected:** configured. 4. Return to old target tab; **expected:** old content may remain, record only. 5. Reload target; **expected:** no render by timeout. 6. New tab → www.example.com; **expected:** blocked as subdomain only if baseline step 2 succeeded. 7. New window → example.org; **expected:** renders. 8. Quit Safari normally, reopen, fresh tab → example.com; **expected:** blocked while filter stays enabled. 9. Stop Bloom, fresh tab → example.com; **expected:** renders.
- **Evidence to capture:** Window/tab type, redirect/final URL, old/new content, times and status. **Pass criteria:** Reload, baseline-resolvable subdomain and browser-restart target requests block; control and disabled target load. Redirect outcome is recorded separately. **Fail criteria:** Any supported fresh target request renders or control fails; old content visibility alone is neither.
- **Recovery procedure:** Stop via Bloom; reopen Safari only after stop if hidden. **Cleanup procedure:** Close test tabs/windows and restore rule.
- **Related code:** BloomFilterController.swift; WebsiteRules.swift; BloomFilterDataProvider.swift. **Related automated tests:** AUTO-NATIVE-01.
- **Dependencies:** WEB-SAF-01. **Retry policy:** None. **Escalation rule:** If Safari restart would close personal work, BLOCKED.

### WEB-SAF-03 — Server grant, expiry and reblock

- **Test ID:** WEB-SAF-03.

- **Feature:** Safari Hard/Super allowance. **Objective:** Verify bounded access, expiry and reblocking.
- **Priority:** P1. **Risk:** Unlimited access, double charge or account loss.
- **Prerequisites:** Safe and WEB-SAF-01 pass; account has confirmed >=15 s daily allowance; no lease; owner authorized small debit. **Environment:** ENV-00; authoritative response visible.
- **Test data:** example.com, example.org, 0.25 min request. **Initial state:** Website protection on, no countdown.
- **Preparation steps:** Record balance/mode/timezone/daily allowance and request ID; don't calculate local end.
- **Execution steps:** 1. Fresh target navigation; **expected:** blocked. 2. Request 0.25 min; **expected:** server returns allowed and UI countdown; record returned remaining time. 3. example.org fresh tab; **expected:** loads. 4. example.com fresh tab while countdown positive; **expected:** loads only if grant positive. 5. Wait until zero and refresh status; **expected:** no time remains and one debit shown. 6. Fresh example.com tab; **expected:** blocked. 7. Stop filter; **expected:** stopped. 8. Fresh target tab; **expected:** loads.
- **Evidence to capture:** Nonsecret request ID, returned duration/end, timestamps, page results, before/after balance. **Pass criteria:** Native deadline does not exceed response; target access only during positive grant; reblock and one debit. **Fail criteria:** Grant extends server end, bypass after expiry or duplicate debit.
- **Recovery procedure:** Keep marker/rule until original server end; use runbook. **Cleanup procedure:** Stop after expiry; restore rules.
- **Related code:** SupabaseCreditGrant.swift; BloomFilterHost.swift; FilterCreditClock.swift; migration 20261101210152. **Related automated tests:** AUTO-NATIVE-01; AUTO-SQL-01.
- **Dependencies:** WEB-SAF-01. **Retry policy:** No new grant; one same-ID retry only on documented transient error.
- **Escalation rule:** Unknown owner/end/offline state keeps access blocked and ends suite.

## Suite C — Brave and other supported browsers

### WEB-BRV-01 — Brave target/control with settings unchanged

- **Test ID:** WEB-BRV-01.

- **Feature:** Brave website filtering. **Objective:** Test full basic lifecycle and report browser-specific state.
- **Priority:** P1. **Risk:** Prior Brave bypass; changing Shields/DNS alters personal security.
- **Prerequisites:** SAFE-01..03 PASS; Brave listed supported and dedicated profile. **Environment:** ENV-00; record Shields/Secure DNS without modification.
- **Test data:** example.com target; example.org control. **Initial state:** Filter off.
- **Preparation steps:** Record Brave version/profile/security labels.
- **Execution steps:** 1. New tab → example.org; **expected:** loads. 2. New tab → example.com; **expected:** loads. 3. Enable Bloom; **expected:** configured. 4. New tab → example.org; **expected:** loads. 5. Fresh tab → example.com; **expected:** does not render by measured timeout. 6. Read address/hide status; **expected:** readable/degraded/unknown captured. 7. Stop Bloom, new target tab; **expected:** loads.
- **Evidence to capture:** Timings, profile/version/security labels, Focus status, anomaly screenshot. **Pass criteria:** Control loads, target blocked only while configured. **Fail criteria:** Target loads while configured, control blocked or browser hide fails.
- **Recovery procedure:** Stop via Bloom; reopen hidden Brave only after stop. **Cleanup procedure:** Close test tabs; do not change settings.
- **Related code:** BloomFilterDataProvider.swift; MacFlowSource.swift; MacBrowserURL.swift; BloomAppMonitor.swift. **Related automated tests:** AUTO-NATIVE-01 only.
- **Dependencies:** SAFE-03; WEB-SAF-01. **Retry policy:** One fresh-tab retry if control succeeded and first result is ambiguous.
- **Escalation rule:** Any bypass is FAIL; stop browser tests and do not toggle settings.

### WEB-BRV-02 — Existing/private windows and restart

- **Test ID:** WEB-BRV-02.

- **Feature:** Brave lifecycle boundaries. **Objective:** Measure existing tab, private window and normal relaunch path.
- **Priority:** P1. **Risk:** Protocol/path differs across window types.
- **Prerequisites:** WEB-BRV-01 PASS; owner confirms harmless private-window test. **Environment:** ENV-00; same timeout.
- **Test data:** example.com and example.org only. **Initial state:** Bloom stopped; both sites preloaded in dedicated profile.
- **Preparation steps:** No signed-in/private data.
- **Execution steps:** 1. Enable Bloom; **expected:** configured. 2. Return to preloaded target; **expected:** old content may remain, record only. 3. Reload; **expected:** blocked by timeout. 4. New normal window to control; **expected:** loads. 5. New private window to target; **expected:** record result and whether this path is declared supported. 6. Quit/reopen Brave normally; fresh target request; **expected:** blocked while configured. 7. Stop Bloom; fresh target request; **expected:** loads.
- **Evidence to capture:** Window type, address, result, status. **Pass criteria:** 3/6 block, 4/7 load; private result is documented against supported scope. **Fail criteria:** Supported private target loads or control blocked.
- **Recovery procedure:** Stop; leave profile settings. **Cleanup procedure:** Close test windows and restore rule.
- **Related code:** BloomFilterDataProvider.swift; MacBrowserAddress.swift; MacBrowserURL.swift. **Related automated tests:** AUTO-NATIVE-01.
- **Dependencies:** WEB-BRV-01. **Retry policy:** None.
- **Escalation rule:** If private mode isn't supported or safe to use, that subcase is BLOCKED, do not improvise.

### WEB-OTHER-01 — Additional listed installed browsers

- **Test ID:** WEB-OTHER-01.

- **Feature:** Browser compatibility. **Objective:** Test every additional installed browser Bloom itself lists as supported.
- **Priority:** P2. **Risk:** Coverage may be overstated.
- **Prerequisites:** SAFE-01..03 and Safari/Brave basic tests pass. **Environment:** ENV-00, one tracker row per browser.
- **Test data:** example.com/example.org. **Initial state:** Filter stopped.
- **Preparation steps:** Read Bloom supported-browser list; do not install browser.
- **Execution steps:** 1. Select one additional listed installed browser; **expected:** identity matches list. 2. Navigate control with filter off; **expected:** loads. 3. Enable Bloom; fresh target request; **expected:** observed against timeout. 4. Stop Bloom; fresh target; **expected:** loads.
- **Evidence to capture:** Name/version/profile and each page result. **Pass criteria:** Lifecycle passes for every listed installed browser. **Fail criteria:** Any supported browser bypass or unrelated block.
- **Recovery procedure:** Stop Bloom; no settings changes. **Cleanup procedure:** Close test tabs.
- **Related code:** MacBrowserURL.swift; MacBrowserAddress.swift; BloomFilterDataProvider.swift. **Related automated tests:** AUTO-NATIVE-01 browser ID only.
- **Dependencies:** WEB-SAF-01; WEB-BRV-01. **Retry policy:** One retry only after control succeeds and a recorded network error caused ambiguity.
- **Escalation rule:** Unlisted browser is out of scope; don't infer support.

## Suite D — app blocking

### APP-01 — Calculator lifecycle

- **Test ID:** APP-01.

- **Feature:** App enforcement. **Objective:** Calculator is usable off, hidden while blocked, and usable after Stop.
- **Priority:** P1. **Risk:** Hide failure or unsaved-work loss.
- **Prerequisites:** SAFE-01..03 PASS; Calculator has no work; permission/monitor state recorded. **Environment:** ENV-00; Calculator only.
- **Test data:** com.apple.calculator. **Initial state:** App protection stopped; no countdown.
- **Preparation steps:** Close Calculator normally.
- **Execution steps:** 1. Open Calculator and calculate 2+2; **expected:** display 4. 2. Close normally; **expected:** no open work. 3. In Bloom choose Calculator and start app blocking; **expected:** configured and current monitor status shown. 4. Launch Calculator once; **expected:** window hides within measured monitor response or appHideFailed reports degraded. 5. If optional authorized app grant is active, launch once; **expected:** usable only during positive server countdown. 6. Stop app blocking after any lease ends; **expected:** stop succeeds. 7. Open Calculator and calculate 2+2; **expected:** visible 4.
- **Evidence to capture:** Window before/after, timestamps, appEnabled/appHideFailed/monitor/countdown. **Pass criteria:** Steps 1/7 usable, step 4 hidden, stop restores. **Fail criteria:** Target usable without credit, unrelated app affected, hide failure or stop unavailable.
- **Recovery procedure:** Stop via Bloom; verify Calculator. Never terminate it. **Cleanup procedure:** Remove test rule if newly added; verify stopped.
- **Related code:** MacAppRules.swift; BloomAppMonitor.swift; BloomAppController.swift; MacMonitorRules.swift. **Related automated tests:** AUTO-NATIVE-01.
- **Dependencies:** SAFE-03. **Retry policy:** One new attempt after clean initial state; no repeated launches in one attempt.
- **Escalation rule:** Any unsaved work, hide failure, wrong target or missing Stop ends suite.

### APP-02 — Calculator relaunch and activation race

- **Test ID:** APP-02.

- **Feature:** App launch/relaunch. **Objective:** Check whether one normal relaunch bypasses rule.
- **Priority:** P1. **Risk:** One-second frontmost polling can race.
- **Prerequisites:** APP-01 pass; no open work. **Environment:** ENV-00.
- **Test data:** Calculator only. **Initial state:** App blocking on; no credit.
- **Preparation steps:** Close Calculator.
- **Execution steps:** 1. Launch once; **expected:** hide within measured poll or explicit failure. 2. If hidden, activate Calculator once from Dock; **expected:** monitor re-applies hide. 3. Refresh Bloom status; **expected:** active only if monitor healthy/no hide failure. 4. Stop protection and open Calculator; **expected:** remains usable.
- **Evidence to capture:** Launch/activation timestamps, visible window, status. **Pass criteria:** Each activation hidden while blocked and app usable after stop. **Fail criteria:** Window stays usable without allowance or UI says active after failure.
- **Recovery procedure:** Stop and verify Calculator. **Cleanup procedure:** Remove test rule if new.
- **Related code:** BloomAppMonitor.swift; BloomAppController.swift; MacMonitorRules.swift. **Related automated tests:** AUTO-NATIVE-01.
- **Dependencies:** APP-01. **Retry policy:** No same-run retry.
- **Escalation rule:** Visible access under block means FAIL and stop.

### APP-00 — Protected recovery apps cannot be selected

- **Test ID:** APP-00.
- **Feature:** App-rule safety. **Objective:** Verify critical macOS recovery tools are rejected before any hide rule is saved.
- **Priority:** P1. **Risk:** An accidental rule could hide the Finder, settings or recovery terminal.
- **Prerequisites:** SAFE-01..03 pass; no app protection active; Calculator suite not running. **Environment:** ENV-00; reviewed build only.
- **Test data:** com.apple.finder, com.apple.systempreferences, com.apple.terminal. **Initial state:** App rules unchanged; app protection off.
- **Preparation steps:** Open Focus; record initial app rule list.
- **Execution steps:** 1. Enter com.apple.finder and click Add app; **expected:** draft row appears. 2. Click Save and start app blocking; **expected:** Bloom rejects it with protected-app message and appConfigured stays false. 3. Remove Finder draft; **expected:** draft row disappears. 4. Enter com.apple.systempreferences and click Add app; **expected:** draft row appears. 5. Click Save/start; **expected:** same rejection and appConfigured false. 6. Remove draft; **expected:** row disappears. 7. Repeat steps 4–6 using com.apple.terminal; **expected:** rejection and no persisted protected rule. 8. Reopen Focus status and read app list; **expected:** none of the three IDs is stored/active.
- **Evidence to capture:** Each rejected ID, UI error, configured state, final rule list; no app is hidden or terminated.
- **Pass criteria:** All three are rejected; native rule list remains unchanged; app blocking remains off.
- **Fail criteria:** Any protected ID persists, app blocking turns on, or recovery app is hidden.
- **Recovery procedure:** If a protected rule unexpectedly activates, use Bloom Stop if available and immediately escalate; do not launch/terminate other apps to recover.
- **Cleanup procedure:** Remove only test draft rows and verify baseline rule list.
- **Related code:** MacAppRules.swift; BloomAppController.swift; MacAppRulesCheck.swift.
- **Related automated tests:** AUTO-NATIVE-01; checks all protected IDs and stale-rule refusal.
- **Dependencies:** SAFE-03. **Retry policy:** One fresh attempt per rejected bundle after restoring empty draft list.
- **Escalation rule:** Any rule saved or hidden recovery app stops the whole suite.

## Suite E — Easy mode

### EASY-01 — Early finish charges server elapsed access

- **Test ID:** EASY-01.

- **Feature:** Easy server-timed access window. **Objective:** Confirm idle time is charged and unused reserved time is released after an early finish.
- **Priority:** P1. **Risk:** Incorrect debit or reservation loss.
- **Prerequisites:** Disposable account has positive Easy balance and no daily cap; owner authorized balance mutation. **Environment:** ENV-00; test server/account verified.
- **Test data:** Starting displayed balance B; reserve 1 minute; keep selected targets idle for 20 measured seconds; finish early. **Initial state:** Easy mode, blocking on, no session.
- **Preparation steps:** Record exact displayed B and disposable account ID. Start a stopwatch when tapping “Use screen time”. Do not open Calculator or a blocked website during the wait.
- **Execution steps:** 1. Request 1 minute; **expected:** reservation starts and the local timer displays the access window. 2. Leave Bloom in the foreground with no selected target open for 20 seconds; **expected:** the displayed remaining time decreases while idle. 3. Tap “Finish screen-time session”; **expected:** the session closes and Bloom syncs it. 4. Refresh the balance once; **expected:** the debit is approximately 20 seconds (0.33 minutes), within 0.05 minutes of stopwatch time; unused reserved time is available again. 5. If Finish remains available, tap it once; **expected:** the balance does not change again.
- **Evidence to capture:** Before/after balance, displayed remaining time, stopwatch duration, request/session ID if shown, local timestamp and screenshot. **Pass criteria:** idle interval visibly advances; balance decreases by elapsed access time within the stated display/interaction tolerance; repeat finish creates no second debit. **Fail criteria:** timer pauses while idle, full reservation is charged for the 20-second run, no debit is recorded, or repeated finish changes balance.
- **Recovery procedure:** Use supported Sync/Finish once; never edit local state. **Cleanup procedure:** Confirm the session is settled and protection is stopped.
- **Related code:** `MacUsageStore.swift`, `UsageTracker.kt`, `BloomUsageState.swift`, `bloom_server_timed_easy` migration. **Related automated tests:** AUTO-NATIVE-01, AUTO-SQL-01.
- **Dependencies:** SAFE-03; app/browser safety. **Retry policy:** No new reservation retry.
- **Escalation rule:** If the timer does not advance while idle, the balance falls outside tolerance, or the session owner differs, stop and record actual versus expected. Do not retry on the live account.

### EASY-02 — Foreground changes do not pause Easy time

- **Test ID:** EASY-02.

- **Feature:** Easy server-timed access. **Objective:** Confirm the same access window runs during target use, target inactivity, and unrelated-app use.
- **Priority:** P1. **Risk:** Wrong charge/refund.
- **Prerequisites:** EASY-01 setup; known positive balance; target app and website rules configured; owner approved test debit. **Environment:** ENV-00; monitor live.
- **Test data:** Reserve 1 minute; Calculator and an unrelated app; measured intervals: 15 seconds Calculator foreground, 15 seconds unrelated app foreground, 15 seconds Calculator foreground. **Initial state:** Easy mode, blocking active, no usage session.
- **Preparation steps:** Record balance B and verify Calculator is a selected app target. Start a stopwatch at the “Use screen time” tap.
- **Execution steps:** 1. Reserve 1 minute; **expected:** server reservation and local access window start. 2. Keep Calculator foreground for 15 measured seconds; **expected:** Calculator remains usable. 3. Switch to the unrelated app for 15 measured seconds; **expected:** access countdown continues. 4. Return to Calculator for 15 measured seconds; **expected:** countdown continues. 5. Finish the session and refresh balance; **expected:** server debit is approximately 45 seconds plus any measured start/finish interaction time, with a tolerance of 0.05 minutes. 6. Repeat only the read-only balance refresh; **expected:** settled balance is unchanged.
- **Evidence to capture:** Stopwatch timeline, displayed timer at each step, before/after balance, selected app rule, and screenshot. **Pass criteria:** countdown advances in all three intervals and balance reflects total reservation-to-finish elapsed time within 0.05 minutes; no duplicate expense. **Fail criteria:** switching away pauses/reduces charge, a foreground change increases the rate, or balance is inconsistent with total elapsed access time.
- **Recovery procedure:** Finish once through UI; retain state until server confirms. **Cleanup procedure:** Close Calculator/browser test tabs; stop app/site protections.
- **Related code:** `BloomAppMonitor.swift`, `MacUsageStore.swift`, `UsageTracker.kt`, `BloomUsageState.swift`, server-timed Easy migration. **Related automated tests:** AUTO-NATIVE-01; AUTO-SQL-01.
- **Dependencies:** EASY-01; APP-01; WEB-SAF-01. **Retry policy:** No retry with same request; new attempt only after settlement.
- **Escalation rule:** If a target becomes unusable, the countdown stops while idle, or balance differs by more than 0.05 minutes, stop and capture evidence. Do not change browser security settings.

### EASY-03 — Rapid switching and duplicate actions

- **Test ID:** EASY-03.

- **Feature:** Easy mode boundary/idempotency.
- **Objective:** Ensure rapid target switches and double Finish cannot double charge/refund.
- **Priority:** P1. **Risk:** Race or duplicate ledger write.
- **Prerequisites:** Disposable local SQL fixture; no live account mutation. **Environment:** ENV-00 for UI run, isolated DB for automated run.
- **Test data:** SQL fixture with a 60-second reservation; wait at least 1 second; call legacy finish with `p_used_ms=0`, then retry with `p_used_ms=reserved_ms`. **Initial state:** Clean disposable fixture.
- **Preparation steps:** Run AUTO-SQL-01 only if local DB engine is already available.
- **Execution steps:** 1. Start one reservation; **expected:** one row with a server start and effective deadline. 2. Wait at least 1 second without relying on any local foreground measurement; **expected:** server wall time advances. 3. Call legacy finish with `p_used_ms=0`; **expected:** stored `used_ms` is at least 1000 and below the reservation cap. 4. Call legacy finish again with `p_used_ms=reserved_ms` and call the new two-argument finish; **expected:** stored `used_ms` and one ledger entry remain unchanged. 5. Start another 1-second reservation, wait 1.2 seconds, then request a new reservation; **expected:** expired one is settled at 1000 ms before new one begins. 6. Call finish as a different account or with another device key; **expected:** server rejects ownership.
- **Evidence to capture:** SQL assertion output, exact session IDs, stored `used_ms`, ledger entry count and final balance. **Pass criteria:** one server-derived debit, forged low/high values do not affect it, no duplicate debit/refund, expired usage is settled before a new window, wrong owner denied. **Fail criteria:** client duration changes debit, reservation is reusable, or duplicate ledger entry appears.
- **Recovery procedure:** Roll back disposable fixture only. **Cleanup procedure:** Destroy only test database container created by runner.
- **Related code:** `20261111000001_bloom_server_timed_easy.sql`; `tests/actual-usage.sql`; `tests/credit-concurrency.py`.
- **Related automated tests:** AUTO-SQL-01/02.
- **Dependencies:** SAFE-03. **Retry policy:** Clean fixture only.
- **Escalation rule:** Do not use production DB or alter real account to force a boundary.

### EASY-04 — Session owner survives route recovery

- **Test ID:** EASY-04.
- **Feature:** Easy reservation persistence and settlement recovery. **Objective:** Verify the request/device key remains available to Finish or Sync after Focus is left and reopened.
- **Priority:** P1. **Risk:** A valid reservation can expire without an explicit settlement/refund path, leaving the user unable to finish early.
- **Prerequisites:** SAFE-01..03 pass; disposable account has at least 1 minute of Easy allowance; no open usage reservation; the current build has a documented recovery route. **Environment:** ENV-00; nonproduction endpoint and account confirmed.
- **Test data:** One 1-minute Easy reservation; `example.com` and Calculator only; initial balance B recorded. **Initial state:** Easy mode, website/app protection on, no active usage session.
- **Preparation steps:** Record B, current mode, and selected target rules. Confirm the Finish control is visible only after the server reservation and local usage state are both ready. Do not start if an earlier request is shown as pending.
- **Execution steps:** 1. Start one 1-minute Easy reservation; **expected:** Bloom displays an active reservation and its Finish control. 2. Open Profile, then return to Focus without signing out or closing Bloom; **expected:** the same reservation remains visible and its request/device key remains usable. 3. Click Finish once before the one-minute access deadline; **expected:** Bloom closes local access and settles through the server without a missing-key error. 4. Refresh the displayed balance once; **expected:** only reservation-to-finish server elapsed time is charged and unused time is available again. 5. If Sync remains available, click once; **expected:** the final balance does not change again.
- **Evidence to capture:** Active/closed UI states, exact error text if any, before/after balance, timestamps, and screenshots that contain no account identifier or credentials. Do not copy the device key into the report.
- **Pass criteria:** The same owner key survives route recovery; Finish settles once; server-derived elapsed time matches within 0.05 minutes; no duplicate debit.
- **Fail criteria:** Missing device key, a second owner/request, a finish that cannot settle, or balance changes twice.
- **Recovery procedure:** If the key is unavailable, do not retry or create another reservation. Leave protection in its current safe state, wait until the server-defined expiry, then use the documented recovery flow once. If no supported recovery is available, stop and escalate.
- **Cleanup procedure:** Stop website/app protection after expiry; verify no active local session and record the displayed balance. Do not clear native/server session data directly.
- **Related code:** `src/components/macos-focus.tsx`, `src/lib/bloom.ts`, `src-tauri/macos/MacUsageStore.swift`, `src-tauri/macos/BloomFilterHost.swift`, `supabase/migrations/20261111000001_bloom_server_timed_easy.sql`.
- **Related automated tests:** AUTO-NATIVE-01; AUTO-SQL-01; a UI/storage recovery regression test is required before rerunning this case.
- **Dependencies:** EASY-01; SAFE-03. **Retry policy:** No retry on the same live account; use a clean fixture after a fix.
- **Escalation rule:** Any missing key, unknown owner, server settlement ambiguity, or unexpected debit stops Easy testing. Do not improvise a direct RPC or edit local state.

## Suite F — Hard mode

### HARD-01 — Server countdown and expiry reblock

- **Test ID:** HARD-01.

- **Feature:** Hard mode. **Objective:** Verify server-authorized countdown, one debit, expiry and block restoration.
- **Priority:** P1. **Risk:** Access exceeds credits or balance debited incorrectly.
- **Prerequisites:** Disposable account, Hard mode, >=15 s eligible daily amount, target protection on, no active lease; owner authorized small test debit. **Environment:** ENV-00; nonproduction endpoint verified.
- **Test data:** 0.25 min request; example.com and Calculator only as selected target. **Initial state:** Hard mode, protection on, no credit.
- **Preparation steps:** Record B, timezone, date/day, weekly-earned display, daily remainder, request ID.
- **Execution steps:** 1. Test target blocked; **expected:** no access. 2. Request 0.25 minutes; **expected:** server response amount/time is shown. 3. During positive grant navigate target; **expected:** access only if grant is positive. 4. Wait to server end; **expected:** countdown reaches zero without changing wall clock. 5. Fresh target navigation; **expected:** blocked. 6. Refresh/settle; **expected:** one debit, balance nonnegative.
- **Evidence to capture:** Server/UI remaining milliseconds, start/end timestamps, target result during/after, before/after balance.
- **Pass criteria:** Native end <= server expiry, access expires, target blocks again, one debit. **Fail criteria:** post-expiry access or multiple debit.
- **Recovery procedure:** Preserve request marker/rules until original server expiry; use runbook.
- **Cleanup procedure:** Stop Bloom after expiry; confirm lease settled.
- **Related code:** SupabaseCreditGrant.swift; FilterCreditClock.swift; BloomFilterHost.swift; enforced countdown migrations/tests.
- **Related automated tests:** AUTO-NATIVE-01; AUTO-SQL-01.
- **Dependencies:** SAFE-03; WEB-SAF-01; account fixture. **Retry policy:** Same ID once only for transient network failure; never new request to extend.
- **Escalation rule:** Wrong owner, end, daily allowance or offline validation stops.

### HARD-02 — Daily allowance, date boundary and clock safety

- **Test ID:** HARD-02.

- **Feature:** Hard day/week calculations.
- **Objective:** Verify weekly-earned/7 allowance, local timezone day end, settings lock, and no clock-change bypass.
- **Priority:** P1. **Risk:** Daily limit bypass or unfair lockout.
- **Prerequisites:** Disposable SQL fixture; do not edit Mac clock. **Environment:** isolated PostgreSQL; timezone fixture values explicit.
- **Test data:** Fixed credit timezone, ledger rows before/at Sunday week boundary and local midnight; cap-sized requests. **Initial state:** clean fixture; fake DB timestamps.
- **Preparation steps:** Use documented SQL/fake time fixtures only.
- **Execution steps:** 1. Start request within day allowance; **expected:** grant <= min(balance, earliest expiry, weekly-earned/7 remainder, day remainder). 2. Request at exact cap; **expected:** exact allowed seconds. 3. Request one second above exhausted allowance; **expected:** rejected. 4. Test UTC/local day transition and daylight-saving timezone fixture; **expected:** reset follows stored IANA timezone. 5. Change simulated clock backward/forward and boot marker; **expected:** local monotonic authorization does not grow; changed boot denies.
- **Evidence to capture:** SQL assertion output, before/after ledger and timezone. **Pass criteria:** all inequalities/boundaries hold. **Fail criteria:** overage, wrong day reset or deadline extension.
- **Recovery procedure:** Rollback disposable transaction only. **Cleanup procedure:** Dispose fixture.
- **Related code:** timed credit session migration; FilterCreditClock.swift; tests/enforced-countdowns.sql.
- **Related automated tests:** AUTO-SQL-01; AUTO-NATIVE-01.
- **Dependencies:** AUTO-SQL-01 available. **Retry policy:** Clean transaction.
- **Escalation rule:** Do not change real Mac time/timezone; if DB unavailable mark BLOCKED.

## Suite G — Super Hard

### SUPER-01 — Exact daily cap and one-over boundary

- **Test ID:** SUPER-01.

- **Feature:** Super Hard daily cap.
- **Objective:** Confirm min(Hard daily limit, configured cap) and exact boundary enforcement.
- **Priority:** P1. **Risk:** Cap exceeded through arithmetic or concurrency.
- **Prerequisites:** Disposable DB fixture with explicit timezone/cap/earnings. **Environment:** isolated PostgreSQL only.
- **Test data:** Bounded balance; cap C; requests C, then a request exceeding remaining daily allowance by one second. **Initial state:** no active session, known ledger.
- **Preparation steps:** Calculate expected from SQL fixture, not UI.
- **Execution steps:** 1. Request exactly C; **expected:** grant <=C and may be shortened by balance/expiry/day. 2. After consuming/exhausting cap, request one second more; **expected:** rejected. 3. Advance fake clock to next local day; **expected:** cap resets only at day boundary. 4. Repeat two concurrent near-cap starts; **expected:** combined grant does not exceed cap.
- **Evidence to capture:** SQL result sets and final ledger. **Pass criteria:** exact and over/concurrent conditions satisfy cap. **Fail criteria:** combined grants exceed cap or wrong reset timezone.
- **Recovery procedure:** Rollback disposable fixture. **Cleanup procedure:** Drop only local test DB/container.
- **Related code:** timed credit SQL migration; tests/enforced-countdowns.sql; tests/credit-concurrency.py.
- **Related automated tests:** AUTO-SQL-01/02.
- **Dependencies:** HARD-02. **Retry policy:** Clean fixtures only.
- **Escalation rule:** No live account cap tests without a verified disposable account.

### SUPER-02 — Offline/reconnect/restart ownership

- **Test ID:** SUPER-02.

- **Feature:** Super Hard recovery.
- **Objective:** Reconnect/restart cannot extend original server-owned expiry.
- **Priority:** P1. **Risk:** Offline or restart enables excess access.
- **Prerequisites:** Isolated QA Mac; owner explicitly authorizes network interruption and restart; no personal work; <=15 s test grant; system filter already approved. **Environment:** ENV-00.
- **Test data:** one stable request ID/device key, example.com. **Initial state:** protection on, no session.
- **Preparation steps:** Record owner, returned remaining_ms, server expiry; ensure cleanup plan.
- **Execution steps:** 1. Request short grant; **expected:** server expiry recorded. 2. Disconnect network only through normal Wi-Fi UI after grant starts; **expected:** no new grant is possible and local deadline does not change. 3. Reconnect before expiry; **expected:** same request revalidates same server end. 4. Restart Bloom normally; **expected:** it remains blocked until owner/expiry validated. 5. After expiry request recovery; **expected:** server returns expired; target remains blocked. 6. Do not restart macOS unless separate explicit approval is recorded; **expected:** if not approved, mark reboot subcase BLOCKED.
- **Evidence to capture:** Server end, network state/times, marker outcome, target before/after. **Pass criteria:** no extension; restart revalidates original session; expired is blocked.
- **Fail criteria:** request creates later end, offline grants time or wrong owner accepted.
- **Recovery procedure:** Restore network; keep request marker until server outcome known; use runbook.
- **Cleanup procedure:** Stop protection after expiry; verify network normal.
- **Related code:** MacCreditRecovery.tsx; SupabaseCreditGrant.swift; FilterCreditClock.swift.
- **Related automated tests:** AUTO-NATIVE-01/AUTO-SQL-01 simulate; live recovery manual.
- **Dependencies:** HARD-01; owner authorization. **Retry policy:** Same request once only.
- **Escalation rule:** If Mac restart is not separately authorized or active work exists, BLOCKED.

## Suite H — persistence/recovery

### PERSIST-01 — UI reload and app close/reopen

- **Test ID:** PERSIST-01.

- **Feature:** Rules, settings, balance persistence.
- **Objective:** Distinguish UI restoration from native enforcement restoration.
- **Priority:** P1. **Risk:** UI may look restored while filter/monitor isn't.
- **Prerequisites:** SAFE-01..03; only harmless rules. **Environment:** ENV-00.
- **Test data:** example.com and Calculator; current mode/limit; no active lease.
- **Initial state:** Save harmless test rules and settings; protection on only if WEB/APP base tests passed.
- **Preparation steps:** Record all initial values.
- **Execution steps:** 1. Reload Bloom webview through normal app UI if available; **expected:** rules/settings/account reload and status is truthful. 2. Close Bloom normally, wait until app exits; **expected:** no forced termination. 3. Reopen same bundle; **expected:** saved rules and settings display. 4. Independently navigate target/control and launch Calculator; **expected:** actual enforcement matches restored state, not just UI. 5. Stop protection and verify normal access; **expected:** target/app usable.
- **Evidence to capture:** Before/after settings, process path, target/control results. **Pass criteria:** state persists and behavior matches; no false ready state. **Fail criteria:** data loss, wrong account, status active with behavior absent.
- **Recovery procedure:** Stop Bloom protections via UI. **Cleanup procedure:** Restore baseline values/rules.
- **Related code:** NE prefs; MacSharedPreferences.swift; BloomAppController.swift; AsyncStorage markers.
- **Related automated tests:** AUTO-NATIVE-01; AUTO-UI-01 not implemented.
- **Dependencies:** WEB-SAF-01 and APP-01. **Retry policy:** One normal reload.
- **Escalation rule:** Active session prevents close/restart; mark BLOCKED.

### PERSIST-02 — monitor/helper and Mac restart

- **Test ID:** PERSIST-02.

- **Feature:** Process and OS restart recovery.
- **Objective:** Verify current-build monitor identity and original server deadline after restart.
- **Priority:** P1.
- **Risk:** stale monitor or reboot changes protection deadline.
- **Prerequisites:** No unsaved work; no live personal apps; account/lease recorded; explicit owner approval before macOS reboot. **Environment:** ENV-00.
- **Test data:** No countdown for ordinary monitor check; optional <=15 s test grant with owner approval.
- **Initial state:** Current Bloom build installed and baseline recorded.
- **Preparation steps:** Confirm Bloom Stop is available and Mac owner approves reboot as a separate action.
- **Execution steps:** 1. Close/reopen Bloom normally; **expected:** monitor path matches this app copy. 2. If user did not explicitly authorize Mac restart, mark reboot portion BLOCKED and stop; **expected:** no restart occurs. 3. If authorized, restart normally from Apple menu; **expected:** no forced power loss. 4. After login, open same app; **expected:** monitor/filter status not reported ready until owner and enforcement validate. 5. Verify target blocked/control accessible or lease expired; **expected:** original state/time rules. 6. Stop protection and confirm normal use; **expected:** website and app are usable with protection stopped.
- **Evidence to capture:** Process paths/status, pre/post server expiry, site/app checks, permission states.
- **Pass criteria:** path matches current bundle; original expiry not extended; actual behavior restored. **Fail criteria:** stale path or expired grant active.
- **Recovery procedure:** Follow runbook; preserve owner marker until server check.
- **Cleanup procedure:** Return protection/permissions to baseline.
- **Related code:** BloomAppController.swift; MacCreditRecovery; FilterCreditClock.swift; LaunchAgent plist.
- **Related automated tests:** AUTO-NATIVE-01 and SQL simulated; live OS restart manual.
- **Dependencies:** PERSIST-01; separate explicit reboot approval. **Retry policy:** One normal reopen; reboot no repeat.
- **Escalation rule:** Any unsafe open work, unresolved countdown, wrong monitor path or no approval stops.

## Suite I — permission loss/recovery

### PERM-01 — Accessibility revoke and restore

- **Test ID:** PERM-01.

- **Feature:** Accessibility permission.
- **Objective:** Permission loss is reported degraded; restoring it restores operation after a real behavior check.
- **Priority:** P1.
- **Risk:** False protection state, hidden app/browser failure.
- **Prerequisites:** Specific owner authorization for this switch; Calculator and harmless domains only; no unsaved work. **Environment:** ENV-00.
- **Test data:** Bloom accessibility entry; Calculator rule. **Initial state:** Record switch state; protections off.
- **Preparation steps:** In System Settings navigate Privacy & Security → Accessibility; do not change until exact case approved.
- **Execution steps:** 1. Enable app protection and verify Calculator hide once; **expected:** baseline pass. 2. Turn off Bloom's Accessibility switch; **expected:** status reports untrusted/degraded after refresh. 3. Test Calculator once; **expected:** no false “active” claim; actual result recorded. 4. Turn the same switch back on; **expected:** restored state visible. 5. Return to Bloom and refresh; **expected:** trusted state. 6. Repeat Calculator/harmless browser case; **expected:** actual behavior restored.
- **Evidence to capture:** Before/off/on switch state, monitor status, app/browser result, timestamps.
- **Pass criteria:** truthful degraded state at loss; restored permission plus actual behavior confirmed.
- **Fail criteria:** says active when operation fails; restore doesn't recover.
- **Recovery procedure:** Restore switch immediately; stop protection if safe.
- **Cleanup procedure:** Switch matches recorded initial state; remove Calculator test rule.
- **Related code:** BloomAppMonitor.swift; MacBrowserAddress.swift; MacAppRules.swift.
- **Related automated tests:** AUTO-NATIVE-01 only permission predicates; live permission required.
- **Dependencies:** APP-01; owner authorization. **Retry policy:** One full revoke/restore cycle.
- **Escalation rule:** If system requests authentication/approval not already authorized, stop and mark BLOCKED.

### PERM-02 — Apple Events browser permission

- **Test ID:** PERM-02.

- **Feature:** Browser Automation permission.
- **Objective:** Confirm Apple Events loss/restore changes address status and never silently qualifies unreadable URL.
- **Priority:** P1.
- **Risk:** Browser rule bypass or false Easy charge.
- **Prerequisites:** Owner specifically authorized Safari/Brave Automation switch; recognized browser, harmless rule. **Environment:** ENV-00.
- **Test data:** example.com blocked; example.org control; Safari and/or Brave. **Initial state:** Record Automation permission and address readable status.
- **Preparation steps:** Use Bloom UI to observe current browser address status; no user tabs.
- **Execution steps:** 1. With permission on, navigate blocked target and record host-read status; **expected:** exact state. 2. Turn off only Bloom's Automation permission for the tested browser in Privacy & Security → Automation; **expected:** status degrades/AX fallback indicated. 3. Navigate target/control in new tabs; **expected:** target does not receive Easy credit while unreadable; control remains accessible. 4. Restore switch; **expected:** permission on. 5. Refresh Bloom and repeat harmless target; **expected:** actual filter/fallback recovers.
- **Evidence to capture:** Browser-specific switch state, address source, Easy eligibility state, page results.
- **Pass criteria:** unreadable address not counted as Easy use; restoration is observed and tested.
- **Fail criteria:** unknown URL counts, unrelated traffic blocked, or stale permission state.
- **Recovery procedure:** Restore exact switch; stop Bloom protection if hide failure.
- **Cleanup procedure:** Switch matches initial; close test tabs.
- **Related code:** MacBrowserAddress.swift; MacMonitorRules.swift; BloomAppMonitor.swift.
- **Related automated tests:** AUTO-NATIVE-01.
- **Dependencies:** WEB-SAF-01/WEB-BRV-01; owner approval. **Retry policy:** One cycle per browser.
- **Escalation rule:** Unexpected permission prompt or unrelated browser behavior stops test.

### PERM-03 — System Extension disable/enable

- **Test ID:** PERM-03.

- **Feature:** Network filter authorization/recovery.
- **Objective:** Verify provider loss is not shown as protected and normal reapproval recovers.
- **Priority:** P1.
- **Risk:** A global extension toggle can disrupt network for all users.
- **Prerequisites:** Dedicated isolated QA Mac, owner explicitly approves exact extension setting change, trusted build and emergency stop available. **Environment:** ENV-00.
- **Test data:** Bloom extension only; example.com/example.org.
- **Initial state:** Filter active only after WEB-SAF-01 pass.
- **Preparation steps:** Read current Network Extension setting; do not change other extensions.
- **Execution steps:** 1. Disable only Bloom filter using ordinary System Settings UI; **expected:** Bloom no longer reports verified enforcement. 2. Perform one control/target probe; **expected:** behavior and degraded status recorded. 3. Re-enable/approve only Bloom through normal UI; **expected:** system shows enabled. 4. Refresh Bloom and probe control/target; **expected:** actual behavior, not preference alone, is verified.
- **Evidence to capture:** Exact setting state, UI status, traffic probes, timestamp.
- **Pass criteria:** Loss is detected; restore yields real observed behavior.
- **Fail criteria:** false active state, other extension altered, or target inconsistent.
- **Recovery procedure:** Restore Bloom extension and stop protection through app.
- **Cleanup procedure:** Bloom extension state matches initial state; verify normal control/site use.
- **Related code:** BloomFilterController.swift; BloomFilterHost.swift.
- **Related automated tests:** AUTO-NATIVE-01 only; live OS test.
- **Dependencies:** WEB-SAF-01; explicit owner authorization.
- **Retry policy:** One disable/restore cycle. **Escalation rule:** If Settings requires unapproved admin/restart, BLOCKED; do not proceed.

## Suite J — shared account and device

### SYNC-01 — SQL simulated concurrency and isolation

- **Test ID:** SYNC-01.

- **Feature:** Shared credit/database concurrency.
- **Objective:** Confirm one reservation owner, idempotent retry, isolation, and no duplicate settlement.
- **Priority:** P1.
- **Risk:** Double spend, cross-account access or false sync claim.
- **Prerequisites:** Existing Docker-compatible local engine already available; runner configured for disposable local database. **Environment:** no remote endpoint/production access.
- **Test data:** tests/cross-device-sync.sql; tests/credit-concurrency.py; synthetic user and device UUIDs only.
- **Initial state:** No container started by operator; no remote database connection.
- **Preparation steps:** Confirm script uses local disposable PostgreSQL and sorted migrations.
- **Execution steps:** 1. Run npm run test:schema; **expected:** disposable DB starts only under runner and tests complete. 2. Inspect summary only; **expected:** account/device lock/idempotency tests pass. 3. Confirm runner removed its own test container; **expected:** no leftover test container.
- **Evidence to capture:** Exit code, sanitized test summary, timestamp.
- **Pass criteria:** All database assertions pass.
- **Fail criteria:** Any invariant failure.
- **Recovery procedure:** Runner's trap handles created test DB; do not run against Supabase.
- **Cleanup procedure:** Confirm temporary test container removed.
- **Related code:** tests/run-schema.sh; tests/cross-device-sync.sql; migrations.
- **Related automated tests:** AUTO-SQL-01/02.
- **Dependencies:** Engine already available. **Retry policy:** One retry after transient local startup error only if service was already running.
- **Escalation rule:** Missing socket = BLOCKED; don't start/reconfigure Docker/OrbStack.

### SYNC-02 — Two physical devices

- **Test ID:** SYNC-02.

- **Feature:** Real account/device synchronization.
- **Objective:** Verify same-account lease ownership/expiry and separate-account isolation on actual devices.
- **Priority:** P1.
- **Risk:** Simulated tests may not represent local enforcement/device UX.
- **Prerequisites:** Second physical Mac/device and owner-approved disposable accounts available.
- **Environment:** ENV-00 recorded on both devices; matching trusted build.
- **Test data:** Disposable account A on both; separate account B on one; same harmless domains.
- **Initial state:** No active reservations.
- **Preparation steps:** Do not use a simulated device key.
- **Execution steps:** 1. Sign into account A on both devices; **expected:** same server balance/rules. 2. Start access on device A; **expected:** owner/expiry shown. 3. Attempt same request from device B; **expected:** only permitted owner retry, no second spend. 4. Start distinct concurrent request from device B; **expected:** server rejects while session active. 5. Verify device A expires; **expected:** B cannot extend. 6. Sign into account B; **expected:** no account A rules/credit exposed.
- **Evidence to capture:** Redacted account labels, request IDs, start/end, results on both devices.
- **Pass criteria:** Owner/expiry/concurrency/isolation match server.
- **Fail criteria:** Cross-account data, double grant or incorrect device owner.
- **Recovery procedure:** Preserve server expiry and use each device's supported stop.
- **Cleanup procedure:** Sign out/restore rules only to initial state.
- **Related code:** countdown SQL owner binding; MacCreditRecovery; blocking-rules-sync.ts.
- **Related automated tests:** AUTO-SQL-01 does not substitute.
- **Dependencies:** Second device and safe fixtures. **Retry policy:** Same owner request only once.
- **Escalation rule:** Without device 2 mark BLOCKED; no claim of sync.

## Adversarial cases

### ADV-01 — Repeated requests and concurrent reservations

- **Test ID:** ADV-01.

- **Feature:** Race/idempotency.
- **Objective:** Rapid duplicate actions cannot create multiple active reservations or debits.
- **Priority:** P1. **Risk:** Credit corruption.
- **Prerequisites:** Use deterministic local SQL and fake clock; no live credit account.
- **Environment:** Local disposable DB only.
- **Test data:** tests/credit-concurrency.py, request UUIDs, two device keys.
- **Initial state:** Clean fixture.
- **Preparation steps:** Confirm destination is local.
- **Execution steps:** 1. Launch documented concurrency suite; **expected:** parallel requests serialize. 2. Replay identical request; **expected:** same result without duplicate charge. 3. Replay same ID with different device/minutes; **expected:** rejected. 4. Inspect final account totals; **expected:** no negative balance or extra session.
- **Evidence to capture:** Test output and final fixture assertions.
- **Pass criteria:** One valid owner/session and no duplicate/lost credit.
- **Fail criteria:** More than one grant/settlement or owner mismatch accepted.
- **Recovery procedure:** Roll back fixture only.
- **Cleanup procedure:** Remove disposable DB by runner.
- **Related code:** SQL owner-binding migrations; tests/credit-concurrency.py.
- **Related automated tests:** AUTO-SQL-01/02.
- **Dependencies:** SYNC-01 engine. **Retry policy:** Fresh fixture only.
- **Escalation rule:** Do not simulate rapid-click behavior on a live user account.

### ADV-02 — Sleep/wake, boot/time changes, offline boundary

- **Test ID:** ADV-02.

- **Feature:** Clock and interruption resilience.
- **Objective:** Sleep/wake does not lengthen lease; changed boot denies access; system clock changes do not alter monotonic end.
- **Priority:** P1.
- **Risk:** Countdown extension or accidental lockout.
- **Prerequisites:** First run deterministic fake-clock checks. Live sleep/wake needs owner authorization and no active work; never set Mac clock.
- **Environment:** ENV-00 for live; test fixture for simulated.
- **Test data:** FilterCreditClockCheck and fixed fake boot/deadline values; optional harmless short test lease.
- **Initial state:** No live access unless authorized.
- **Preparation steps:** Record source clock and existing timezone; do not alter either.
- **Execution steps:** 1. Run AUTO-NATIVE clock tests; **expected:** missing/different boot denies and deadline bounded. 2. If an approved live sleep/wake test is scheduled, request <=15 s lease; **expected:** deadline remains server end. 3. Sleep/wake normally; **expected:** protection does not extend. 4. Check expiration/reblock; **expected:** target blocked after original end. 5. Do not change system date/time; simulate forward/backward only in test clock; **expected:** host clock and timezone remain unchanged.
- **Evidence to capture:** Fake-clock assertion summary; optional lease end and wake times.
- **Pass criteria:** No local extension; boot mismatch denies.
- **Fail criteria:** Time change extends access or expired target stays open.
- **Recovery procedure:** Use original server deadline and runbook.
- **Cleanup procedure:** Stop after expiry.
- **Related code:** FilterCreditClock.swift; tests/FilterCreditClockCheck.swift.
- **Related automated tests:** AUTO-NATIVE-01; AUTO-SQL-01 for DB rollover.
- **Dependencies:** HARD-01; explicit live sleep approval. **Retry policy:** Fake clock clean rerun; live once.
- **Escalation rule:** No authorized sleep/no safe work state means live part BLOCKED.

## Suite K — performance and reliability

### PERF-01 — Paired resource and latency baseline

- **Test ID:** PERF-01.
- **Feature:** Runtime performance and reliability. **Objective:** Measure Bloom-off/on resource use and operational latencies under repeatable conditions, then compare them with owner-approved budgets derived from the baseline and product needs.
- **Priority:** P2. **Risk:** Unmeasured background load, battery impact, slow enforcement, countdown drift, or weak recovery can make the app unreliable or disrupt normal Mac use.
- **Prerequisites:** SAFE-01..03 PASS; basic Safari/Brave and Calculator cases pass; no personal work depends on the Mac; the owner has documented numeric budgets and rationale for CPU, memory, energy/battery, filter readiness, rule propagation, app detection/hide, countdown drift, and recovery; the disposable account has allowance for up to three 0.25-minute Hard grants if countdown measurements require separate rounds. **Environment:** ENV-00; same Mac, QA user, power source, network, browser profile, and workload for paired runs.
- **Test data:** Bloom host, filter extension, and monitor process names from the verified build; example.com/example.org; Calculator; three paired rounds and at most three 0.25-minute grants. Do not include personal process lists or history.
- **Initial state:** Bloom protection stopped, no active reservation, rules and permissions at the recorded baseline.
- **Preparation steps:** Record power source, battery percentage if available, macOS version/build, build hash, network summary, open QA applications, and approved budgets. Close only QA test windows. Do not terminate unrelated processes or change power/network settings.
- **Execution steps:** 1. With Bloom stopped, observe the idle QA workload for 10 minutes and record CPU, memory, and available Energy Impact/battery readings at the beginning and end; **expected:** baseline values and sampling method are recorded. 2. Start Bloom using the verified test flow with protection enabled; **expected:** start/readiness latency is timestamped and status is reported as configured or genuinely ready, according to available evidence. 3. Keep the same QA workload for 10 minutes; **expected:** resource and energy readings use the same method and interval. 4. Open one fresh example.org tab and record time to render; **expected:** control loads and timing is captured. 5. Open one fresh example.com tab and record time until the measured blocking timeout; **expected:** target does not render and timing is captured. 6. Change only the example.com rule through Bloom's UI and measure from Save to the next fresh target navigation; **expected:** rule propagation latency and final enforcement result are recorded. 7. Launch Calculator once and record time to the observed monitor action and confirmed hidden state; **expected:** elapsed time and hide success/failure are recorded. 8. Use an already-approved HARD-01 session to measure countdown drift and expiry/recovery; **expected:** measured end does not exceed the server end and blocking resumes. If no permitted session evidence exists, mark this metric BLOCKED and do not request a new grant. 9. Repeat the paired resource and website/app observation rounds twice more under the same conditions; repeat countdown only if the remaining allowance covers another 0.25-minute request; **expected:** three rounds are recorded or the unavailable metric is marked BLOCKED. 10. Compare each metric to its approved budget; **expected:** result is PASS only if every required metric meets its criterion in all required rounds.
- **Evidence to capture:** Three paired data sets, timestamps, sample method, power/battery state, build hash, readiness and rule/app/recovery timings, countdown drift, budget document reference, and deviations. Avoid unrelated process names and account secrets.
- **Pass criteria:** Owner-approved budgets exist with baseline/product rationale and every metric meets its specified criterion in all three paired rounds without crashes, unrelated network disruption, false-ready status, or lost/extended credit.
- **Fail criteria:** Any approved budget is exceeded, Bloom crashes/restarts repeatedly, protection reports ready without evidence, an unrelated app/site is disrupted, or countdown/credit invariants fail.
- **Recovery procedure:** Stop protection through Bloom. If it cannot be stopped safely, stop and hand control to the owner; do not kill processes or alter system filters.
- **Cleanup procedure:** Restore the recorded Bloom/rule/permission baseline, settle or wait for any existing authorized lease without duplication, close only QA test windows, and record final battery/resource state.
- **Related code:** BloomFilterController.swift; BloomFilterDataProvider.swift; BloomAppMonitor.swift; BloomAppController.swift; FilterCreditClock.swift; SupabaseCreditGrant.swift.
- **Related automated tests:** AUTO-NATIVE-01 provides deterministic component checks only; no automated performance harness is present.
- **Dependencies:** SAFE-01..03; WEB-SAF-01; APP-01; HARD-01 if countdown/recovery budgets include live access; approved numeric budgets. **Retry policy:** Three paired rounds are the planned protocol; repeat a round only if its measurement was interrupted, preserving the original evidence.
- **Escalation rule:** If any budget is missing, the machine is needed by another user, conditions cannot be held stable, or a failure has no documented safe recovery, mark BLOCKED/FAIL and stop. Do not invent a threshold or alter system settings.

## Cleanup

### CLEAN-01 — Restore safe starting state

- **Test ID:** CLEAN-01.

- **Feature:** Test teardown.
- **Objective:** Confirm no test protection, rule, lease, permission change or local test residue remains.
- **Priority:** P0.
- **Risk:** User remains blocked or account remains unsettled.
- **Prerequisites:** All attempted cases stopped; server deadlines known.
- **Environment:** ENV-00 and initial baseline from SAFE-03.
- **Test data:** Initial rules/permissions/settings/balance; harmless test rules only.
- **Initial state:** Test execution complete or aborted.
- **Preparation steps:** Wait for any original test countdown expiry; do not erase marker.
- **Execution steps:** 1. In Bloom stop website protection; **expected:** disabled. 2. Stop app protection; **expected:** disabled. 3. Remove only added example.com and Calculator rules; **expected:** baseline rules restored. 4. Finish/sync Easy session via app once; **expected:** server confirms settled. 5. Restore approved permission switches; **expected:** same as baseline. 6. Close only test tabs; **expected:** no personal data affected. 7. Recheck suspicious launcher remains disabled and no warning was bypassed; **expected:** baseline preserved. 8. Verify example.com and Calculator normal while protection off; **expected:** both usable.
- **Evidence to capture:** Before/after state table; final balance; lease/settlement outcome; permission state.
- **Pass criteria:** All states match baseline except explicitly authorized disposable balance mutation, which is documented; no active test protection.
- **Fail criteria:** Any unknown active lease, changed permission, rule, monitor or network state.
- **Recovery procedure:** Keep Bloom protection stopped if possible; hand control to owner if not.
- **Cleanup procedure:** This case is cleanup; leave docs/tracker with result and no secrets.
- **Related code:** Focus stop/finish; BloomAppController.swift; BloomFilterController.swift.
- **Related automated tests:** AUTO-SQL-01 for settlement only.
- **Dependencies:** All attempted tests.
- **Retry policy:** One refresh/recheck; do not repeat debit.
- **Escalation rule:** Any state cannot be proven restored → BLOCKED and stop.
