# Non-functional requirements

| Requirement | Designed/implemented evidence | Measured status |
|---|---|---|
|Response time (registration/dashboard/activity/wallet)|No audited performance budgets/results identified|Unverified|
|Persistence/backend availability|Supabase client/migrations|Availability and relaunch tested only selectively; unverified as requirement|
|Reward correctness/concurrency|SQL constraints/functions and concurrency fixtures referenced by QA|Fixture evidence exists; full app/device coverage unverified|
|Offline recovery|Client/native recovery logic exists|End-to-end offline/reconnect unverified|
|Blocking reliability|Native extension/accessibility mechanisms|Contradicted by Brave/Calculator QA fails|
|Auth/data isolation/RLS|RLS policies/migrations exist|Security adversarial coverage incomplete|
|Credit integrity|Server-authoritative migrations and idempotency|SQL fixture evidence; live rollback/cross-device incomplete|
|Usability/navigation|Expo routes/components|No measured usability study evidence identified|
|Arabic RTL|Theme/localization support requires inspection|Unverified|
|Cross-device synchronization|Device registry/schema/tests|No physical multi-device result identified|
|Maintainability/docs|Architecture and QA docs exist; dirty worktree|Qualitative only|
