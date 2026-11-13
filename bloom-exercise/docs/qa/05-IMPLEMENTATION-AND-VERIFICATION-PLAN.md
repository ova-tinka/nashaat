# Implementation and verification plan

This is the change-control record. Changes already in the working tree are separated from future work. Unrelated dirty root files were not modified.

## Changes already made

| Change | Defect/evidence | Files | Correction and check | Rollback |
|---|---|---|---|---|
| Unknown browser identity | NE flow may not identify application; global fallback could harm unrelated apps. Apple data provider app group is read-only. | MacFlowSource.swift, BloomFilterDataProvider.swift, native tests | Unknown source allows; known browser is targeted; removed provider app-group counter write. Deterministic test is in native suite. | Revert only if deterministic tests fail; stop Bloom protections before another live attempt. No security bypass. |
| Easy eligibility and hide check | Selected website without blocked host must not accrue Easy use; hide call isn't proof. | MacMonitorRules.swift, BloomAppMonitor.swift, tests/build script | Count only selected app or matching blocked host; verify hidden/terminated after run-loop, otherwise report failure. Native suite. | Keep non-termination behavior; revert only on focused regression evidence. |
| Server-authoritative Hard/Super lease | Renderer-supplied deadline may diverge from DB session. | SupabaseCreditGrant.swift, BloomFilterHost.swift, BloomFilterController.swift, BloomAppController.swift, Rust bridge, credit UI/recovery/types/tests/build/sign scripts | Native posts request ID/device/minutes/current user token; only server remaining_ms authorizes; redirects/malformed/expired response rejected; boot-bound deadline shared. Recovery retries same request and fails closed. | Roll back only after stopping protection and resolving any active test lease through owner path. Never extend locally. |
| SQL migration discovery | Hardcoded migration list could omit or misorder migration. | tests/run-schema.sh | Find timestamped Bloom migrations and sort; bash syntax passed. | Restore explicit ordered list only if runner dependency regression is shown. |
| Build version and status language | Generated filter version 1.0 vs app 0.1.0; “Active” label used NE preference only. | scripts/build-macos-filter.cjs, filter/Info.plist, macos-focus.tsx | Generator takes numeric package version; UI describes configuration, not live provider. | Preserve accurate status wording even if build version strategy changes. |
| App hide failure visibility | Native monitor tracks hide failure; UI omitted reason. | BloomAppController.swift, BloomFilterHost.swift, macos-blocking.ts, macos-focus.tsx | Add typed status and degraded-state message; typecheck/native regression required. | Revert only added status field if serialization regression; retain conservative disabled state. |
| Protected recovery apps | MacAppRules excluded Bloom but allowed other essential app IDs; a bad rule could hide recovery tools. | MacAppRules.swift, MacAppRulesCheck.swift, BloomAppController.swift | Reject six critical macOS app bundle IDs at normalization and recheck them in shouldBlock; update error text; native regression asserts both validation and stale-rule refusal. | Revert only with a reviewed replacement allowlist/denylist and tests; never remove recovery protection without replacement. |
| Server-timed Easy window | Finish RPC accepted user-controlled `p_used_ms`; foreground reports are mutable by the signed-in user. | `20261111000001_bloom_server_timed_easy.sql`, `src/lib/bloom.ts`, Mac/iOS/Android timers, Focus and credit-rule UI, SQL/native fixtures | Database computes elapsed reservation time and caps it at the effective access end; clients send no duration; the legacy RPC overload ignores its duration. Local timers continue while idle and use the server-provided remaining window. Old foreground-measured reservations settle at zero rather than being retroactively billed; new reservations set `billing_started_at` from the server clock. | Review existing open reservations before deploying with the matching app release. Rollback requires a corrective migration; do not restore client-authoritative billing. |

## Remaining remediation

### R-01: Easy server-timed accounting — source fix complete; live early-finish recovery fails (P0/P1)

- **Decision:** User selected a server-timed access window. Easy charges server elapsed time from reservation until early finish or effective expiry; inactivity does not pause and there is no usage-based refund.
- **Why:** macOS has no supported app-foreground attestation API available to this app; local monitor reports can be edited by the logged-in user.
- **Correction:** Implemented. Migration adds `access_expires_at`, removes client duration from the current RPC contract, keeps a compatibility overload that ignores `p_used_ms`, and settles expired reservations before new reservations or guarded balance changes. Mac, iOS, and Android local timers follow the same continuous-window rule. Remaining work is isolated QA deployment and live client/service expiry verification after artifact gates pass.
- **Evidence:** Isolated PostgreSQL 14.21 run passed 14 Bloom migrations, 11 SQL fixtures, and countdown/Easy concurrency checks. The SQL fixture proves server elapsed debit despite forged `0` and oversized values, idempotent settlement, expiry, balance, and device/account ownership. In the live Mac run, an idle 0.25-minute window expired and the displayed balance reflected the full debit. A later one-minute reservation expired; Finish reported that its device key was unavailable. The displayed final balance was 2.58, but the remote row/`settled_at` was not independently inspected. This verifies one live idle expiry debit only, not early finish, remote settlement-row state, foreground use, or continuous blocking.
- **Rollback:** Do not restore client-authoritative settlement. If regression appears, stop new Easy grants until a corrective migration/client change passes fixtures; do not rewrite live account history.

### R-02/R-03: Website coverage and readiness (P1)

- **Question:** Why did Brave Private load a fresh blocked URL while Bloom's filter was enabled, and how can Bloom communicate actual provider readiness?
- **Why:** The current notarized build reproduced a Brave bypass. Source confirms the provider allows a flow with no visible hostname when it is not a TCP flow, and it also allows unknown-source flows to avoid disrupting unrelated apps. QUIC/HTTP/3 is plausible but the exact observed flow was not traced. NE preference enabled does not prove the provider is servicing traffic.
- **Root cause and change:** The 1.1.5 diagnostic `unreadable-browser-policy-flag-off-allow` showed the root system extension did not see the logged-in monitor's app-group policy. A root Network Extension and per-user LaunchAgent have different user-container visibility. Filter 1.1.6 adds a same-team XPC broker that stores only short-lived policy snapshots in memory, binds each publish to the monitor's effective UID, and serves reads only to the signed root filter for the requested flow UID. The filter uses that snapshot for hostless-browser drops and earned website access. It does not broaden drops to unknown apps or UDP globally. The UI reports broker approval and availability states.
- **Evidence:** Focused broker fixtures cover peer identity/team, monitor and filter roles, UID isolation, stale/boot mismatch, hostless source match, unreadable-browser state, earned-access expiry, and truthful readiness when the daemon/monitor/snapshot acknowledgement is absent or stale. A new native fixture covers helper executable fingerprint changes and stale-registration refresh. `npm run test:macos-native` and `npm run test:filter-version` pass. The host 0.1.0/filter 1.1.7 helper-refresh build was Developer ID signed, accepted by Apple, stapled, passed Gatekeeper assessment, and installed. Bloom reported the broker and monitor ready after helper re-registration.
- **Current result:** The original broker peer-rejection cause is fixed and readiness was restored on the installed 1.1.7 build. The live Brave Private test still failed its target expectation: `example.org` loaded and `example.com` also rendered while website protection was enabled. The initial page render is confirmed; a delayed hide result and the exact network flow are not. No flow diagnostic rows were available. Hostless/encrypted paths remain unclassified; do not broaden blocking without identifying the flow. Detailed observations are in `docs/macos-verification.md`.
- **Rollback:** Status remains configured/unknown; never label active absent proof.

### R-04: App hide (P1)

The Calculator-only live trial ran after the monitor was Ready and Accessibility was reported trusted. Calculator stayed visible and usable under protection, then worked normally after Stop. Treat app enforcement as FAIL. Investigate the hide result and status propagation with deterministic observer tests; keep Stop visible and do not terminate apps as a workaround. The installed build's Calculator rule remains saved but app protection is off; a supported clear-manual-app-list action is also missing.

### R-05: CSP and command surface (P1)

Inventory built app endpoints/assets; set CSP with exact production Supabase and local dev origins, required Tauri IPC/assets/fonts/styles. Test auth/rules/credit/web export and harmless inline-script rejection. Do not use a wildcard HTTPS policy. Review every custom native action and scope/account validation.

### R-06/R-09: Permissions and build identity (P1)

The current QA artifact passed strict code-sign verification, Gatekeeper assessment as Notarized Developer ID, and stapler validation; the notary submission was Accepted. Artifact identity is in `09-TEST-DATA-AND-ENVIRONMENT.md`. The new system extension is active/enabled and the previous 1.0 registration is terminated pending reboot. After the user-authorized setup, Bloom reports its background monitor Ready and Accessibility trusted. No permission was toggled or revoked/restored. The live app-hide failure shows that those permissions do not prove enforcement. Do not change permission state without the specific action-time authorization required for a new security-sensitive change.

### R-19: Easy owner-key recovery (P1)

- **Observed defect:** During a live Easy reservation, Finish displayed “The device key for this reservation is unavailable.” After navigating away and back, the local session showed ended but Sync still could not proceed. The Focus UI did not offer a supported recovery path.
- **Evidence:** CUA observation on the notarized build; source check shows `finishActualUsage()` returns early when `usageRequest` is missing, while the native usage state does not contain the server device key. The exact event that lost or failed to hydrate the key is unknown; a route/load race is only a hypothesis.
- **Correction required:** Design durable owner-key recovery with least exposure; ensure a stale `load()` cannot clear a newer request; expose a clear terminal/retry state. Add an automated UI/storage regression and native recovery check before another live account test.
- **Safety:** Do not start another live reservation or edit local session state. The expired window is accounted for in the displayed balance; remote `settled_at` remains unverified.

### R-18: Performance budgets (P2)

No performance threshold is currently supported by measured evidence. Collect paired Bloom-off/on measurements under stable conditions first, then have the product owner document budgets and rationale. PERF-01 remains BLOCKED until this decision exists; do not choose CPU, memory, battery, or latency limits by guesswork.

## Stage gates

1. **Stage 1 read-only discovery: complete.** Inventory and dirty status recorded.
2. **Stage 2 research: substantially complete.** Apple/Tauri docs and four source implementations reviewed; provider-health channel remains open.
3. **Stage 3 completeness: complete with blockers.** Universal flow visibility and guaranteed app hiding remain absent. Easy measures server-timed access duration; it does not attest foreground activity.
4. **Stage 4 remediation: partial.** Server-timed Easy source and SQL fixtures pass locally; live Easy early-finish recovery fails (R-19), Calculator hiding fails (R-04), and CSP/provider-health work remains open.
5. **Stage 5 automated verification: partial.** Native, TypeScript, lint, and isolated PostgreSQL 14.21 schema/concurrency checks pass. Docker runner is unavailable; Android Gradle tests cannot run because Gradle is absent.
6. **Stage 6 computer-use prep: complete.** `python3 tests/validate-qa-docs.py` passed after the latest Brave retest and filter 1.1.2 source notes: 13 documents, 31 structured cases, required fields, outcomes, tracker rows and whitespace. A dedicated macOS QA user/browser profile is still absent.
7. **Stage 7 real Mac E2E: partial; suite FAIL.** The notarized 1.1.1 build reproduced the Brave Private bypass after monitor setup. Filter 1.1.2 has a notarized source mitigation and passing focused native tests; its system extension is active, but website protection and live testing remain pending. Calculator hide is FAIL. Easy idle expiry charged the reserved amount; early Finish failed because the device key was unavailable. Hard/Super live behavior, permission loss/recovery, restart and physical two-device tests remain unverified or blocked. No reboot or security-warning bypass occurred.
8. **Stage 8 final readiness: not ready.** See 12-FINAL-READINESS-ASSESSMENT.md.

## Verification commands

Run from bloom-exercise:

~~~sh
npm run typecheck
npm run lint
npm run test:macos-state
npm run test:macos-native
node --check scripts/build-macos-filter.cjs
cargo check --locked --manifest-path src-tauri/Cargo.toml
bash -n tests/run-schema.sh
npm run test:schema
python3 tests/validate-qa-docs.py
~~~

If schema tests cannot reach an already-running user-authorized Docker-compatible engine, mark BLOCKED; this run used isolated local PostgreSQL 14.21 because Docker was unavailable. Do not start or alter Docker/OrbStack. The current trusted QA app was signed/notarized under the existing authorized test workflow; use its recorded artifact only, and do not treat build acceptance as enforcement evidence.
