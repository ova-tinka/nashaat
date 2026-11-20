# Bloom selected long-range scope and estimates

**Date:** 2026-11-20
**Basis:** Current working tree, `Bloom_Full_PRD_v1.docx`, and `docs/bloom-super-app-roadmap.md`.

This records the requested feature scope regardless of whether the roadmap classifies a feature as MVP or later. Estimates are for one experienced full-stack product engineer, in focused engineering days of about 6–8 hours. They include the first usable UI, data/backend work, permissions, automated checks, and integration with the current Expo/Supabase architecture. They are planning ranges, not commitments.

## Selected pillar scope

- **Exercise:** adaptive weekly plans and recovery; guided AI and habit/lapse coaching; private social challenges; richer progress, achievements, and personal-best tracking. Exclude camera rep counting, technique feedback, and wearables. Existing plans, logging, progress, coach, and competitions are foundations to extend.
- **Education / Study:** tutor, adaptive practice, weekly study plans, spaced repetition, source-aware document help, mock exams and review, and comprehension/verification checks. Expand subjects into courses, lessons, and assignments. Exclude mastery maps/tracking and study groups.
- **Reading:** integrated reader for supported authorized formats, discovery and recommendations, AI explanation/reflection, vocabulary, personal library, notes/annotations, and comprehension checks that give a useful signal about understanding. Exclude audio and reading clubs.
- **Tasks:** projects, milestones and task hierarchy; AI breakdown into actionable steps; Focus-linked completion. Exclude adaptive weekly scheduling.
- **Shared layer:** one cross-pillar weekly planning and supportive behavior system, permission-scoped intelligence/memory, and one server-authoritative credit flow across all four pillars.

## Work order: easiest to hardest

The order uses the midpoint of each estimate. Each line is an incremental feature on top of the current code, not a rewrite.

| Order | Feature slice | Current foundation / result | Estimate |
|---:|---|---|---:|
| 1 | Study weekly plans | Subjects and weekly minute targets exist; add a flexible, scheduled study plan. | 2–4 days |
| 2 | Focus-linked task completion | Dated tasks and completion exist; link Focus time to the task without creating a second reward event. | 2–4 days |
| 3 | Private exercise challenges | Friend and competition flows exist; shape them into bounded, private workout challenges without direct messages. | 2–4 days |
| 4 | Study comprehension/verification | Add optional checks or artifacts to confirm learning activity; do not treat understanding as proof of time spent. | 2–4 days |
| 5 | Study courses, lessons, and assignments | Extend the current subject model so plans, sessions, practice, and documents have places to attach. | 3–5 days |
| 6 | AI task breakdown | Turn a user-approved task into editable steps and milestones. | 3–5 days |
| 7 | Exercise progress and personal bests | Extend weekly progress/history with achievements and useful personal records. | 3–6 days |
| 8 | Adaptive exercise plans and recovery | Adapt existing plans using goals, ability, availability, recent progress, and planned rest. | 3–6 days |
| 9 | Exercise habit and lapse coaching | Extend the movement coach with adherence support and supportive recovery after missed sessions. | 3–6 days |
| 10 | Reading notes, annotations, and vocabulary | Extend the existing reading list/progress flow with saved notes and vocabulary review. | 4–7 days |
| 11 | Study tutor | Add source-aware explanations, uncertainty handling, and a focused tutor conversation. | 4–7 days |
| 12 | Adaptive study practice | Add practice questions with user-controlled difficulty adjustment from answers. No persistent mastery map. | 4–7 days |
| 13 | Spaced repetition | Add retrieval prompts, review scheduling, and a review queue for study material. | 4–7 days |
| 14 | Task projects and hierarchy | Turn the current flat dated task list into projects, milestones, and nested tasks/checklists. | 4–7 days |
| 15 | Mock exams and performance review | Add exam setup, timed attempts, results, and a review flow. | 5–8 days |
| 16 | Reading discovery and recommendations | Add a starter catalog and recommendations. Estimate assumes public-domain/free metadata, not a licensed commercial catalog. | 5–9 days |
| 17 | Reading AI reflection and understanding signals | Add reflection prompts and comprehension checks, with a history of responses that helps the user judge whether they are following and benefiting. | 6–10 days |
| 18 | Shared rewards for Study, Read, and Tasks | Connect these completions to the existing ledger with server-side eligibility, idempotency, caps, and Focus de-duplication. | 6–10 days |
| 19 | Cross-pillar weekly planning and behavior coaching | Combine all four goals into a flexible week, explain suggestions, and support user-controlled adjustments and lapse recovery. | 8–14 days |
| 20 | Integrated reader | Add supported EPUB/PDF reading, position/bookmarks, and session progress for user-owned or otherwise authorized content. | 10–16 days |
| 21 | Shared intelligence and memory | Add permission-scoped cross-pillar context, visible/correctable summaries, retention/deletion behavior, and age-appropriate boundaries. | 10–16 days |
| 22 | Source-aware document help | Ingest supported user documents, retrieve relevant passages, and return answers with source references. Estimate assumes text-based PDF/DOCX, not scanned-document OCR or cloud-drive connectors. | 10–18 days |

## Effort summary

| Area | Feature work |
|---|---:|
| Exercise | 11–22 engineer-days |
| Education / Study | 34–60 engineer-days |
| Reading | 25–42 engineer-days |
| Tasks | 9–16 engineer-days |
| Shared planning, intelligence, and rewards | 24–40 engineer-days |
| **Feature subtotal** | **103–180 engineer-days** |
| Full-product regression and integration hardening | 10–20 engineer-days |
| **Estimated total** | **113–200 engineer-days** |

For one person, that is about **23–40 five-day workweeks**. A 2–3 person team can parallelize some work, but dependencies and integration make this roughly a **3–6 month calendar effort**, not a one-day build. A single day is enough for a narrow prototype or planning slice, not the complete scope.

## Assumptions and exclusions

- The estimate uses the current working tree as the baseline: the four module flows, exercise planning/logging, movement coach, competitions, and shared credit ledger remain usable. Study, Read, and Tasks currently provide basic records/sessions but do not award credits.
- AI work reuses the existing provider integration; it does not include training or hosting a model.
- Reader and document support is limited to user-owned/authorized content and a small first set of formats. DRM circumvention and commercial content licensing are excluded.
- Estimates include app-level automated verification. They exclude store approvals and a full physical-device release-certification cycle.
- Not included because they were outside the selected pillar list: Windows support, broad offline queue/reconciliation, calendar/cloud-drive integrations, Organization Mode expansion, and broader Family Mode work. Offline support or those platform/product extensions would need separate estimates.
- Exclusions explicitly selected within the pillars remain out of scope: camera rep counting, technique feedback, wearables, Study mastery tracking and groups, Reading audio and clubs, and adaptive task scheduling.

The current tree has substantial uncommitted work. These ranges assume that work is retained and stable; rework against a changing baseline would increase the estimate.
