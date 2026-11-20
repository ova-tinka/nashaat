# Platform and access matrix

**Status:** Four-pillar Home and navigation rework implemented · platform enforcement and physical app checks pending

## Access boundaries

| Surface | Adult profile | Child profile | Enforcement |
|---|---|---|---|
| My Space, Exercise, Progress, Activity | Own profile data | Own child profile data | Authenticated profile scope and existing service policies |
| Family setup and management | Create/join/manage when authorized | Redirected to Child View | App route gate plus server-side household/role checks |
| Child details, coaching, competition approvals | Only the authorized guardian | Redirected to Child View | Existing protected RPCs and row policies; UI never grants access |
| Profile switch | Configure device PIN; review before removing it or returning to Child View | Parent restore only when device-managed and PIN is present | Existing secure device credential and auth session replacement; destructive transitions require explicit confirmation |
| Device status and inventory | Current profile sees its own installation list | Child sees only the child profile’s own list | Profile-scoped RLS; permission and blocking values are last-reported status from each installation |

Family remains optional. The current family flow supports household creation/joining, child profile setup, pairing, child workout plans and credit controls, plus existing coaching and competition approval screens. The Family overview shows each connected child's assigned modules, available screen-time balance, weekly Exercise activity, recent workouts and pending coaching/competition requests from parent-authorized services. Consequential credit, plan, blocking-rule, child-search privacy, coaching-consent, proposal-decision, competition-decision and access-code actions show the affected child/family and require confirmation before the authorized server operation. Success is reflected by refreshed server data or a saved-state message; failures remain visible for retry. The child detail view now shows the child-attributed workout activity returned by the existing analytics service.

Child profiles start with no module assignments. An authorized parent can assign an available module from child detail; the assignment is persisted with the updating profile and timestamp. The server returns only assigned, currently available modules and checks assignments before opening each module’s data operations. The local migration enables Exercise, Study, Read and Tasks; if a future server version marks a module unavailable, its assignment and access fail closed. Household membership retains one `parent` role type alongside `child`; role tiers, role changes and parent invitations are not part of this implementation.

## Platform capability

| Platform/runtime | Workspace presentation | Exercise and account data | Focus enforcement report |
|---|---|---|---|
| iOS app | Mobile | Supported through the current app | Read from `bloom-blocking` status and Apple permission state |
| Android app | Mobile | Supported through the current app | Read from `bloom-blocking`, permission and service health state |
| macOS Tauri | Desktop rail and workspace width | Supported through current app services | Read from macOS Tauri native commands |
| Web browser | Responsive desktop shell at laptop widths | Available where the existing web services work | Explicitly unavailable; browser preview has no native Focus adapter |
| Windows Tauri | Responsive desktop presentation only | No Windows-specific native adapter verified | Unsupported until a Windows host and enforcement adapter exist |

`isMacDesktop()` checks both Tauri runtime and macOS WebView identity before invoking macOS commands. A Windows Tauri host must not be treated as macOS merely because it uses Tauri.

## Device truth and limitations

- Devices are registered per Bloom profile. Each installation/profile pair has a persistent random ID and editable display name, so two Macs or two iPhones remain separate entries and rotating one profile's inventory ID does not alter another profile's list. Existing installations migrate their prior local ID into the first active profile that checks in. Parent and child profile inventories are not shared.
- Remote status is the last report from that installation, not proof that its permission or blocking state is still active. Reports older than 24 hours are labeled stale.
- Removing a device removes its profile inventory entry and scrubs its saved name/status. It does not sign that installation out; sign out there to end its Bloom session. A later check-in with the old installation ID remains hidden.
- A failed native read is shown as unavailable/error, never as enforcement being off.
- Parent-rule sync errors show the last successful sync time when one exists, or state that no successful sync has been recorded yet. A failed refresh is not presented as a current successful sync.

## Phase D/E parity and open requirements

| Requirement | Current evidence | State |
|---|---|---|
| Child cannot open guardian routes directly | App layout redirects child profiles away from Family, child-management and approval routes; backend checks remain authoritative | Implemented in code; route helper tests pass |
| Guardian keeps personal space | Family is an optional route/context alongside My Space; context selection and routes use the active profile | Implemented in code; server/session behavior still needs device verification |
| Family overview and approvals | Overview uses server-returned assignment, balance, weekly Exercise activity, recent workout, coaching proposal and event-request data, with direct links to pending review surfaces | Implemented in code; query failures stay visible per child |
| Confirm consequential child changes | Credit toggles/rules, credit adjustments, workout-plan deletion, blocking-rule edits, child invitation acceptance, membership removal and access-code creation show a scoped confirmation | Implemented in code; operations remain subject to server authorization |
| Per-module child assignment and parent role model | Server assignment table and authorized RPCs; children default to no assigned modules; assignment listing, save RPCs, route guards, launcher visibility and module data operations check the assignment. The local migration enables all four modules. One existing parent role is retained without tiers or role-change controls | Exercise/Study assignment, default-deny and authorization rules covered by local SQL fixture; Read/Tasks follow the same availability gate |
| Named device list/detail, rename, remove and same-type device distinction | Profile-scoped registry, random installation IDs, last-reported status, stale state, rename and inventory removal are implemented; removal is explicitly not remote sign-out | Implemented; migration, access-control fixture and concurrency checks pass in a disposable local PostgreSQL run |
| Laptop route presentation | Expo web export includes the existing app route families; an app-level responsive header and desktop rail now persist across tab screens and sibling approval/workout routes on web laptop widths and macOS Tauri. The compact rail keeps short destination labels visible. Family uses a child grid and a two-column child detail workspace; Activity has a selectable list/detail workspace, Progress responsive metric columns, and Devices separate status/guidance columns on wide screens | Web and unsigned macOS bundle build; latest Family mobile hierarchy captured; authenticated desktop workspace and populated child-detail visual review pending |
| Cross-device Study/Read sessions | Server sessions retain the originating profile-scoped installation ID and device name; active-session UI shows its server start time and the latest successful client check. Session start/finish require the server and do not create offline sessions | Implemented and covered by the disposable schema suite; live cross-device review awaits the intended server migration and two authorized test devices |
| Task date boundaries | Task filters use the active profile’s configured credit timezone, matching the server-side daily summary; date-only due labels format in UTC to preserve the stored calendar date | Implemented; UTC-boundary and timezone-stability tests pass |
| Windows laptop/native support | Responsive web presentation is available; there is no verified Windows Tauri host or native enforcement adapter | Browser layout only; enforcement unsupported |
| Accessibility and RTL review | Shared controls have labels/state, visible keyboard focus and system text scaling; common text styles use natural writing direction; directional banner/rail edges and forward chevrons use logical or mirrored presentation; reduced-motion preference is observed; closing the space selector returns focus to its trigger unless navigation changes routes. Header and compact navigation can grow for larger text; primary header controls and filters meet 44pt minimum targets. The gallery previews Arabic/RTL text, but app copy is English | Source audit and web build pass; Light Home, Settings, Devices, Family and Focus captures exist; Settings captured in Dark and High contrast; Focus captured in Dark. Other screen themes, full RTL visual review and physical assistive-technology review pending |
| Native permission, blocking, restart and sync | iPhone simulator build and visual launch pass. Devices accurately reports supported Focus, setup-required permission and blocking off. Simulator visuals do not exercise the OS permission or enforcement APIs | Physical-device gate pending |

## Home and navigation

- The persistent primary navigation contains Home and the four assigned, visible pillars: Exercise, Study, Read and Tasks. Hiding a pillar is a per-profile preference; historical activity and credits are retained.
- Mobile uses a safe-area-aware floating bottom dock. Desktop uses the app shell's persistent sidebar. Both filter module destinations by profile visibility and child assignments.
- Progress, Activity, Devices, Family, Settings, notifications and workspace switching remain available as contextual or secondary destinations through the profile menu and app shell.
- Home summarizes the server-authoritative balance, profile-local weekly goals, earned ledger activity and last-reported device inventory. Independent data sections retain loading, error and retry states.

## Quality checks

- Shared layout uses responsive web workspace sizing and a mobile-first scroll layout. Desktop rail collapses below its wide breakpoint.
- The authenticated app layout owns the shared header and responsive desktop rail. Family approvals, coaching, workout sessions, plan editing and exercise details therefore retain laptop navigation outside the tab navigator; mobile keeps its floating Home-and-pillars dock on primary destinations.
- React Native text remains scalable; buttons retain touch-sized hit areas and shared controls expose labels and states.
- Family and profile routes are guarded against child-profile navigation. Backend role checks remain the security boundary.
- Family child controls require explicit review/confirmation for credit settings, credit adjustments, plan deletion, parent blocking rules, search visibility, coaching consent, coach proposals, competition participation, child invitation acceptance, membership removal, and pairing/invitation/account-link code generation.
- Removing a device parent PIN and ending the parent session to return to Child View both require a review step before execution.
- macOS native policy/bridge checks, browser-domain policy checks, route-access checks and macOS/Windows platform identity checks pass in the local test suite. These compile and exercise policy code; they do not prove live Safari/Brave enforcement.
- The unsigned macOS Tauri app bundle and Expo web export complete successfully after the Phase D assignment changes. This does not verify signing, installation, permissions or live blocking.
- Physical iOS, Android and macOS checks are required for permission prompts, blocking, service restart, pairing, sync and session recovery. No native behavior is marked verified by this source review.
- RTL visual review and Windows native-host verification remain open. Current copy is English and no RTL product translation is included in this phase.
- The step-by-step physical test matrix and readiness requirements are in [PHYSICAL_VERIFICATION.md](./PHYSICAL_VERIFICATION.md).
