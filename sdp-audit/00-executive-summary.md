# Bloom SDP verification audit

**Audit date:** 2026-11-21 (repository environment date) · **Branch:** `codex` · **HEAD:** `5f38d289977e7739d76e4a603cd1260db00443b5` · **Scope:** read-only source/document review; working tree was dirty at start.

## Verdict

Bloom has substantial implementation across Expo/React Native, Tauri/macOS, Supabase SQL/functions, and a shared native blocking module. It is not defensible to claim reliable release readiness: the repository's own QA tracker records reproducible failures for Brave Private website enforcement, Calculator app blocking, and Easy early-finish settlement. Four pillar screens and server schemas exist, but source presence does not establish full end-to-end persistence or runtime success. The report can be compared because `docs/SDP Report.docx`, Appendix A DOCX and `docs/appendix-b-test-cases.md` exist. The available Markdown appendix has only 32 `### Test Case` entries, not 133; do not fabricate the remaining 101. DOCX extraction is outstanding.

## Pillars

- **Exercise:** substantial app/backend workflows (plans, logging, progress, rewards); end-to-end current build/runtime evidence incomplete.
- **Education:** study module and tutor/artifact backends exist; complete activity/reward lifecycle not demonstrated.
- **Reading:** reader, library/session/reflection support and recent migrations exist; persistence/reward lifecycle not demonstrated end to end.
- **Tasks:** growth module and task-related shared activity support exist; full recurrence/checklist/reward proof is incomplete.

All four: **partially supported; end-to-end acceptance not established**. AI is optional and requires external provider configuration; core activity flows should not require it.

## Critical findings

1. Brave Private loaded a configured blocked target in two tracked runtime trials (WEB-BRV-01/03).
2. Calculator remained visible and usable during configured protection (APP-01).
3. Easy Finish could not recover its reservation device key; settlement/refund was not proven (EASY-01/04).
4. A configured website filter is not proof of live enforcement. QA docs distinguish readiness from target-flow enforcement.
5. Windows build configuration exists; store submission, deployed release, post-launch monitoring are not evidenced.
6. No CI workflow directory was found; no current automated results were independently generated in this audit.

## UC status counts

A complete defensible UC01–UC55 count is **not established by this pass**; use-case names alone are not proof. See matrix for provisional classifications. Do not report invented totals.

## Testing

The tracker contains actual recorded runtime observations and local SQL/test evidence; this audit did not independently rerun them. `docs/appendix-b-test-cases.md` contains 32 case headings, while the requested 133-case source must be extracted from the DOCX/report appendix before ownership allocation. CSV contains the available 32 only and is explicitly provisional.

## Milestones 11–14

11 System testing: **partially completed**; retain failures/open coverage. 12 Windows client: **pending/deferred** (configuration is not proof). 13 Store submission: **pending**. 14 Post-launch monitoring: **pending** absent deployed telemetry evidence.

## Five report corrections

1. Qualify all blocking claims; Brave Private and Calculator failed runtime checks.
2. Describe Easy as failed/inconclusive for early finish; reservation-key recovery and server settlement need proof.
3. State that four pillars have implemented components, while full persisted end-to-end acceptance remains unverified.
4. Do not claim 133 tests passed/completed; Appendix B execution columns are blank in available source and tracker contains only selected executions.
5. Mark Windows/store/post-launch milestones pending unless deployment/submission/monitoring evidence is supplied.
