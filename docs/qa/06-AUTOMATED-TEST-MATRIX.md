# Automated test matrix

Results below refer to deterministic source tests, not macOS enforcement. Refresh final status in 11-TEST-EXECUTION-TRACKER.md.

| ID | Layer / command | Coverage and expected result | Current evidence |
|---|---|---|---|
| AUTO-TS-01 | npm run typecheck | UI, native bridge payloads, status fields, marker types compile without diagnostics. | PASS in current source run. |
| AUTO-LINT-01 | npm run lint | ESLint checks src and exits cleanly. | PASS in current source run. |
| AUTO-STATE-01 | npm run test:macos-state | Valid owner marker accepted; bad UUID/state/target/amount denied. | PASS: 2 tests in current source run; Node module-type warning. |
| AUTO-NATIVE-01 | npm run test:macos-native | Host/domain normalization, suffix, app rules, browser address/IDs, TLS SNI parser, monotonic clock, continuous Easy elapsed-window math on macOS/iOS, website allowance, flow identity, hide verification, broker access/readiness policy, signing-information flag, helper-registration refresh, grant decode, dylib bridge. | PASS for source 1.1.7; includes iOS persisted-state fixture, broker UID/team/freshness/acknowledgement/expiry cases, the required `kSecCSSigningInformation` assertion, helper fingerprint-refresh decisions, and host bridge compile. |
| AUTO-RUST-01 | cargo check --locked --manifest-path src-tauri/Cargo.toml | Action allowlist, request validation and Tauri integration compile. | PASS in current source run. |
| AUTO-SQL-01 | `tests/run-schema.sh` SQL fixture sequence | Apply timestamped Bloom migrations to disposable PostgreSQL; prove server-measured Easy debit, ignored forged low/high legacy values, idempotent settlement, expired-window settlement, balance release, device/account isolation, Hard/Super rules and other schema invariants. | PASS using isolated temporary PostgreSQL 14.21: all 14 Bloom migrations and 11 SQL fixtures, including `actual-usage.sql`. Docker API socket itself remains unavailable; equivalent runner commands were executed locally. |
| AUTO-SQL-02 | `credit-concurrency.py` | Parallel countdown/Easy reservations: one owner/session, no duplicate/lost credit. | PASS against the same temporary PostgreSQL 14.21 cluster; countdown and server-timed Easy races each produced exactly one owner. |
| AUTO-MIG-01 | bash -n tests/run-schema.sh and schema suite | Migration discovery/sort and shell syntax. | PASS; migration discovery and all 14 Bloom migrations applied in sorted order. |
| AUTO-SCRIPT-01 | node --check scripts/build-macos-filter.cjs; Python plist/package check | Build script parses; filter version follows its independent numeric version policy; broker executable and LaunchDaemon plist are packaged and signed. | PASS: package/filter 1.1.7, component build, signed host, strict signature verification, Apple notarization, stapling, and Gatekeeper assessment pass. The helper-refresh build is installed; see WEB-BROKER-02 for runtime registration and WEB-BRV-03 for the failed live target test. |
| DEPLOY-MIG-01 | User-run `supabase db push` | Apply `20261111000001_bloom_server_timed_easy.sql` to the selected nonproduction Bloom project. | User-provided output shows the migration applied and push finished. Linked read-only CLI inspection returned HTTP 403; no live app settlement was tested. |
| AUTO-UI-01 | No current WebDriver harness | Sign-in, Focus, save/start/stop, recovery marker, status degradation, CSP behavior. | Not implemented. |
| AUTO-MAC-01 | Platform integration | NE provider, Safari/Brave flows, Calculator hide, TCC loss/restore, launch agent, restart. | PARTIAL / overall FAIL: installed/notarized filter 1.1.7 and refreshed broker/monitor report ready. A fresh Brave Private `example.org` control loaded, but the `example.com` target also rendered while protection was enabled. The later hide state and exact flow class were not captured; unrelated browsers, Safari retest, Calculator hide, TCC recovery, and restart remain unverified. See `../macos-verification.md`. |
| PERF-01 | Manual platform/reliability | Repeated paired Bloom-off/on CPU, memory, energy, filter/rule/app latency, countdown drift, and recovery measurements on the same Mac. | BLOCKED until the product owner records evidence-based budgets; no thresholds or measurements are available in this audit. |
| AUTO-DOC-01 | `python3 tests/validate-qa-docs.py` | Required QA documents, structured cases, inline expected results, tracker rows, unique IDs, and whitespace. | PASS in the 2026-11-12 follow-up: 13 QA documents, 31 unique cases, required fields, expected outcomes, tracker rows, and whitespace. |
| AUTO-ANDROID-01 | Android module Gradle unit tests | `UsageAccountingTest` proves elapsed billing continues through inactive intervals and caps at budget/expiry; `UsageTracker` persistence/reboot behavior. | BLOCKED: Gradle executable/wrapper and Kotlin compiler are absent from the checked paths/environment. |

## Existing test limits

| Source | What it proves | Does not prove |
|---|---|---|
| WebsiteRulesCheck.swift | Pure host normalization and exact/suffix match. | DNS, flow metadata, actual provider. |
| TLSHostnameCheck.swift | Synthetic ClientHello parser behavior and invalid cases. | Real browser TCP, ECH, UDP/QUIC. |
| MacFlowSourceCheck.swift | Missing identity allows; recognized browser path selected; unrelated app continues normal filter; fresh matching blocked-browser marker drops hostless flow; stale/old-boot marker allows. | Actual macOS audit token and hostless flow result for Safari/Brave on filter 1.1.2. |
| MacAppRulesCheck.swift / MacMonitorRulesCheck.swift | Bundle filtering, protected recovery-app rejection, stale-rule refusal, and hide-result predicate. | Accessibility/TCC and actual window hiding. |
| FilterCreditClockCheck.swift | Fake boot/deadline values and mismatch denial. | Sleep/wake/reboot or clock changes. |
| MacUsageCheck.swift / MacUsageStore | Synthetic continuous elapsed time during idle intervals, budget/expiry cap, boot mismatch fail-closed behavior, and journal lifecycle. | Server settlement; user cannot edit local state; real filter/monitor timing. |
| IosUsageStateCheck.swift / BloomUsageState | Persisted elapsed access continues while the selected target is idle, early finish uses elapsed time, expiry caps use, and concurrent updates serialize. | DeviceActivity callback timing on a physical iPhone or entitlement behavior. |
| MacWebsiteUsageAccessCheck.swift | Host/browser allowance policy. | Live monitor/filter handoff. |
| MacPolicyBrokerCheck.swift | Same-team monitor/filter identity, root-only read, per-UID isolation, freshness, boot match, browser source decisions, and earned-access expiry. | Real XPC peer identity, LaunchDaemon approval/lifecycle, actual multi-user filtering. |
| BloomPolicyBrokerReadinessCheck.swift | UI requires enabled service, live monitor, accepted fresh snapshot; stale, missing, future acknowledgements degrade. | Actual broker launch/IPC under macOS approval and traffic enforcement. |
| SupabaseCreditGrantCheck.swift | Mock 200, expired, rejected, malformed response decode. | Real TLS/auth/RPC, retry, deployed policies. |
| test-macos-native.sh | Native source compiles/checks and bridge answers fixture. | Signed installed bundle or OS activation. |
| tests/*.sql, credit-concurrency.py | Disposable SQL invariants when DB suite runs. | Physical device sync or Mac enforcement. |

## Missing automated coverage

- Android unit test execution requires an Android SDK/Gradle environment before release.
- Native URLSession mock tests: redirect refusal, timeout/offline, 401, 429, 5xx, malformed body, idempotent retry.
- Provider lifecycle and truthful status once a supported health channel is selected; current configuration state does not prove live filtering.
- Live macOS proof that filter 1.1.6's approved cross-user broker and source-matched hostless-browser fallback block Brave's target while `example.org` remains available. The notarized 1.1.1 test showed hostless UDP decisions but did not correlate them to the target; do not infer QUIC.
- Live Easy reservation/settlement/expiry and reblocking through the deployed server-timed migration; server timing verifies elapsed access, not foreground use.
- Tauri WebDriver tests for Focus, auth, status language and CSP.
- Crashpoint tests at reservation/start/settle plus exact clock boundary tests.
- SQL suite must run against isolated local disposable PostgreSQL before any migration deployment.
- No mock substitutes for actual Network Extension, TCC, app hiding or browser traffic.
- No performance/battery baseline or product budget exists. PERF-01 records paired measurements, but cannot pass until budgets are set from the baseline and product requirements.
