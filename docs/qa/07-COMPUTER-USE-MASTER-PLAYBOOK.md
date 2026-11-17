# Computer-use master playbook

This is an execution procedure, not permission to modify macOS security settings. Read 01–06 first, then 09 and 10, then execute cases in 08 only when their dependencies pass.

## Operating role and allowed actions

The executor observes and operates a previously approved trusted Bloom test build with a disposable nonproduction account and harmless test targets. The executor may open Bloom, Safari, Brave, Calculator, macOS informational settings pages, and read-only diagnostic tools. Only use the pre-existing dedicated macOS QA user and dedicated browser profiles. Do not create users, install or sign software, change certificate/keychain state, submit notarization, alter browser security settings, edit production data, run suspicious launchers, or change macOS permissions without specific approval for that action.

The test extension is global to the Mac. A dedicated user does not isolate network filtering from personal sessions. Do not run live filter tests while another user or personal work depends on this Mac. A second physical device is required to claim device-level sync.

## Status vocabulary

- **PASS:** Every stated observable acceptance condition was met and evidence was captured.
- **FAIL:** At least one stated observable contradicts expected behavior.
- **BLOCKED:** A prerequisite is unavailable, an approval dialog is pending, required equipment is absent, or safe action cannot be completed.
- **NOT RUN:** No attempt made. This is not a pass.
- **INCONCLUSIVE:** Evidence cannot distinguish Bloom from cache, network delay, wrong build, stale helper or another cause. Treat as not passed.

Never change an outcome to PASS based on code inspection, UI label, successful build, simulated SQL, or one ambiguous screen capture.

## Stage order and gates

### Gate 0 — stop immediately if unsafe

1. If a macOS “Malicious Script Blocked”/Gatekeeper warning appears, do not click override, allow, or open-anyway. Capture warning and app identity without dismissing security controls. Stop Bloom tests and mark SAFE-01 FAIL/BLOCKED as appropriate.
2. Do not execute the previously suspicious launcher. Keep it disabled. If its warning reappears, stop all testing.
3. If essential Mac networking or an unrelated application becomes unavailable, stop the current case. Use Bloom's own Stop control only if visible and safe; if protection cannot be stopped through the app, stop and hand control to the Mac owner. Do not improvise terminal commands or disable another network filter.
4. If an app or site is not in this playbook, do not substitute a personal target.

### Gate 1 — identify the build (SAFE-01)

Record timestamp, macOS version/build, chip, app version/build number, app path, SHA-256, host/filter bundle IDs, Team ID, signing status, notarization/staple result, provisioning IDs, and bundle architecture. Use read-only commands specified in 09. Host app, system extension, and agent must belong to the same reviewed build/team. A build label or old note is not evidence.

If artifact identity or notarization is not independently verifiable, STOP. Do not build/sign/notarize/install it during test execution.

### Gate 2 — confirm test environment (SAFE-02)

Use a pre-existing dedicated macOS QA user and dedicated Safari/Brave profiles. Confirm the test account is the disposable nonproduction account using the visible account identifier only; do not reveal access tokens, passwords, .env, database exports, or private account data. Record permission state and current rule/balance fixture.

Do not create a macOS user or edit a browser's Secure DNS, Shields, extension, proxy, VPN, or history settings. If there is no isolated test user/profile, stop live blocking cases as BLOCKED.

### Gate 3 — enforcement readiness

Read Bloom website/app status. “Enabled · filter configured” is configuration status only. For each live case, actual behavior under a control site and target site is required. If provider/process health is unavailable or a browser address is unreadable, label coverage degraded and only run the case's documented degraded path.

### Gate 4 — automated and simulated checks

Run AUTO-* only in the documented project directory. Run `npm run test:schema` when a Docker-compatible engine is already available. If Docker is unavailable but a local PostgreSQL server installation exists, set `BLOOM_TEST_POSTGRES_BIN` to that installation's `bin` directory and run `bash tests/run-schema-local.sh`; it creates and removes a temporary cluster with TCP listening disabled. Never point either runner at a remote URL or an existing non-test database. Do not start or reconfigure OrbStack/Docker.

### Gate 5 — platform test suites

Execute in this order:

1. SAFE suite.
2. Safari disabled/control/blocked lifecycle, then Brave equivalent.
3. Validate protected recovery-app rejection (APP-00), then app blocking on Calculator.
4. Easy server-timed window, idle billing/expiry, early finish, and request/device-key recovery (EASY-01..04). Stop Easy testing immediately if the owner key is missing; do not start another reservation.
5. Hard expiry and Super Hard cap, only if test account has explicit test allowance.
6. Persistence and recovery.
7. Permission loss only after owner approves the exact System Settings change; restore in the same case.
8. Simulated database concurrency; physical-device suite stays BLOCKED without device 2.
9. Adversarial tests only after each base case passes.
10. Run PERF-01 only after the product owner has recorded performance budgets justified by baseline measurements; otherwise keep it BLOCKED.
11. Cleanup and safe-state verification.

## Exact observation method

1. Use only example.org as accessible control and example.com as blocked target. A rule for example.com should match www.example.com as a subdomain.
2. Before enabling protection, run three fresh control navigations. For each, record time from pressing Return until page title/content is rendered. Set the navigation timeout to exactly three times the median observed control duration. If all three fail, do not set a timeout; mark environment BLOCKED.
3. Each target/control navigation uses a new tab unless the case specifically tests an already-open tab. Record whether page content rendered, whether loading continues when timeout is reached, and which URL remains in the address bar.
4. Previously rendered content remaining visible is not a navigation-block pass/fail by itself. Record it, then navigate/reload using the case steps.
5. Record Bloom configured state, monitor state, browser address status, hide-failure state, countdown, and account balance before/after. Never use the UI label alone as evidence.
6. Capture a screenshot for each unexpected state; include full browser title/address only for the harmless example domains. Do not capture personal tabs, tokens, account secrets, or private history.
7. A blocking result passes only if target fails to render after the measured navigation timeout while control renders within the same timeout, and protection is confirmed disabled afterward by target loading. If browser hides, record hide event and re-open only for the documented relaunch check.
8. For countdown tests, use 0.25 minutes only if server/UI confirms at least 15 seconds are eligible and available. Record server-authoritative end/remaining time exposed by app UI/diagnostic; do not assume requested equals granted. If server returns less than 15 seconds or daily cap is exhausted, mark BLOCKED for expiry test.

## Failure protocol

At first failure:

1. Stop at the failing step. Do not click repeated actions or restart the app.
2. Record test/step, local timestamp with timezone, app/build hash, visible expected versus actual, selected rule/mode, permission indicators and one screenshot.
3. Record whether provider or monitor status is configured, actively observed, or unknown.
4. Apply only the recovery action named by that test. If none applies, mark FAIL or BLOCKED and stop dependent tests.
5. Retry only where the case allows it. A retry gets a new attempt number and evidence.
6. Do not fix code, query/modify a remote database, inspect secrets, or change permissions to “make it pass.”

## Completion

Every attempted case gets one tracker row with result, timestamp, build ID, evidence path/description, actual behavior, and cleanup result. Before ending, confirm website rules are stopped unless parent-managed; app blocking is stopped unless parent-managed; no Easy reservation remains unsettled; no countdown is extended; permissions match initial state; test account is isolated; suspicious launcher remains disabled; no test warning was bypassed. If any item cannot be verified, mark cleanup BLOCKED and hand control to the owner.
