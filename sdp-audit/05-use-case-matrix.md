# UC01–UC55 provisional implementation matrix

Statuses are source-based and conservative; “partial” does not mean acceptance passed. Platforms generally Expo mobile unless desktop-specific. Evidence: routes under `src/app`, screens/components under `src/components`, migrations/functions under `supabase/`; named gaps below.

| UC | Name | Status | Platform / principal evidence | Next action |
|---|---|---|---|---|
|01|Register Account|Partial|Mobile; sign-in/Auth|OTP disposable account test|
|02|Login|Partial|Mobile; auth.tsx|session/restart/logout test|
|03|Edit Profile|Partial|Mobile profile route|persist/relogin test|
|04|Manage Workout Plan|Partial|Mobile; bloom.ts; workout plan migrations|CRUD E2E|
|05|Log Workout|Partial|Mobile; exercise records; reward migration|persist + idempotent reward|
|06|Performance Dashboard|Partial|home dashboard|compare aggregates to ledger|
|07|Interface Lock|Partial|native blocking modules|device enforcement test|
|08|Mobile App Blocking|Partial|Android/iOS native module|permissions/restart test|
|09|Web Blocking|Failed on Brave; partial elsewhere|macOS filter docs tracker|repair/retest |
|10|Manage Blocking Configuration|Partial|focus/config routes|verify status reflects enforcement|
|11|Subscription Management|Unverified|no submission/runtime evidence|identify provider and test sandbox|
|12|Receive Notifications|Unverified|no delivery evidence|test permission and delivery|
|13|Private Leaderboards|Partial|competitions/social migrations|RLS/privacy E2E|
|14|Manage Friends|Partial|social routes/migrations|invite/accept/revoke E2E|
|15|Streaks and Rewards|Partial|gamification migrations|exactly-once test|
|16|Onboarding|Partial|onboarding routes|fresh account flow|
|17|DNS-Based Web Blocking|Failed/partial|Network Extension; tracker Brave fails|retest and correct report|
|18|macOS Desktop App|Partial|src-tauri; QA docs|signed clean install/runtime suite|
|19|Windows Web Blocking|Unverified|Tauri targets/config only|Windows build + enforcement proof|
|20|AI Agent Workout Generation|Partial|growth AI function|credentialed manual generation test|
|21|Computer Vision Form Checking|Missing/unverified|no evidence located|mark future work or implement|
|22|Enhanced Gamification|Partial|gamification/social migrations|runtime acceptance|
|23|Payment Processing|Missing/unverified|no provider evidence|mark future work or implement/test sandbox|
|24|Analytics and Reports|Partial|goal analytics/dashboard code|validate source data and timing|
|25|Coach/B2B|Partial|coach routes/functions|tenant/coach workflow test|
|26|Background AI Workout Adaptation|Unverified|no background execution proof|prove trigger/scheduling or correct claim|
|27|Weekly Goals|Partial|weekly planner + migrations|pillar goal E2E|
|28|Weekly Progress|Partial|dashboard/actuals|validate all four pillars|
|29|Shared Credit Wallet|Partial; early-finish failure|credit/session migrations|recover key and reconcile ledger|
|30|Redeem Screen-Time Credits|Partial|focus/redeem session code|settlement and enforcement E2E|
|31|Credit Transactions|Partial|ledger migration/UI|history matches server ledger|
|32|Subjects and Courses|Partial|growth module/study schema|CRUD E2E|
|33|Study Plans|Partial|study module/planner|persist/restart test|
|34|Study Sessions|Partial|study practice|complete without AI; reward verification|
|35|Educational Progress|Partial|study artifacts/weekly actuals|progress consistency E2E|
|36|Reading Library|Partial|read module|CRUD/persistence E2E|
|37|Reading Goals|Partial|weekly pillar planning|goal update test|
|38|Reading Sessions|Partial|reader/session code|persist completion E2E|
|39|Reading Progress|Partial|reading migrations|resume/relaunch validation|
|40|Personal Tasks|Partial|growth module/task schema|CRUD E2E|
|41|Task Checklists|Unverified|no complete runtime evidence|verify persistence|
|42|Recurring Tasks|Unverified|no complete runtime evidence|verify recurrence rules|
|43|Eligible Tasks|Partial|shared growth rewards migration|eligibility/idempotency test|
|44|Task Progress|Partial|weekly actuals|validate aggregate|
|45|Focus Sessions|Partial; Easy failure|focus routes/native modules|early finish/restart state reconciliation|
|46|Synchronize Devices|Partial|device registry/cross-device SQL|two physical devices|
|47|Unified Activity History|Unverified|no evidence of full unified history|implement/verify aggregation|
|48|Device Protection Status|Partial; status caveat|native modules/macOS tracker|distinguish configured/active|
|49|AI Study Assistance|Partial|study tutor function|credentialed test; manual fallback|
|50|AI Reading Assistance|Partial|read reflection function|credentialed test; manual fallback|
|51|AI Task Planning|Unverified|no confirmed workflow|verify or mark future work|
|52|Recommendations|Unverified|no validated recommendation engine|verify or mark future work|
|53|Family Linking|Partial|pairing/provision functions|fresh family account test|
|54|Approve Supervised Activities|Partial|parent controls migrations|approval/rejection end-to-end|
|55|Digital Wellness Guidance|Partial|growth content surfaces|content and navigation acceptance|

Tests/dependencies: see `07-test-inventory.csv` and `11-unverified-items.md`. Automated test presence is not equivalent to execution evidence.
