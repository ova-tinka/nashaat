# Nashaat GitHub Development and Branching Policy

This document is the working agreement for developing, reviewing, and releasing Nashaat through GitHub. It applies to every contributor, reviewer, maintainer, and release manager who works in the repository.

The policy is intentionally based on the repository's current state: the only shared branch is `main`. It does not assume that `develop`, `staging`, or release branches already exist.

> **Short version:** Create one short-lived working branch from `main`, push only that branch, open one pull request into `main`, pass the required checks, get the required review, and merge through GitHub. Never push directly to `main` or create/use a reserved branch.

## 1. Repository baseline

The following facts were verified when this policy was written:

- The repository has `main` and `origin/main` only.
- `main` is the default branch and the only supported PR target in the current workflow.
- There is no `develop`, `staging`, `production`, `release/*`, or `hotfix/*` branch in the current repository.
- There is no `.github/workflows/` directory yet, so GitHub Actions checks must be added and configured before they can be made required.
- Flutter linting is configured through [analysis_options.yaml](../analysis_options.yaml).
- The project is a Flutter application using Supabase. The application structure and layer boundaries are described in [AGENTS.md](../AGENTS.md) and [docs/onboarding-guide.md](onboarding-guide.md).

Branch settings and CI are GitHub-side configuration. They cannot be inferred from this Markdown file alone. Repository administrators must complete the enforcement checklist in [Section 13](#13-github-administrator-enforcement).

## 2. Non-negotiable rules

1. `main` is protected. Contributors do not push, force-push, delete, or rewrite it.
2. Every code, test, database, configuration, and documentation change enters `main` through a pull request.
3. A contributor PR must use an approved short-lived branch as its head and `main` as its base.
4. A contributor must not create, push, delete, rebase, merge, or open a PR from/to any reserved branch listed in Section 4.
5. A contributor may push only to a branch they own or have explicitly been assigned to maintain. Never push to another developer's branch without their agreement.
6. A PR is not ready to merge until its checks are green, required reviews are complete, and all conversations are resolved.
7. The PR author must not approve or merge their own PR.
8. Secrets, production credentials, personal data, database exports, and production logs never belong in a commit, issue, PR, or GitHub Actions output.
9. Long-lived shared branches are not created casually. A new permanent branch requires a policy change, a GitHub ruleset, an owner, and a documented reason.

## 3. Branch terminology

- **Base branch / target branch:** The branch a PR is merging into. For normal Nashaat work, this is `main`.
- **Head branch / source branch:** The branch containing the proposed change. For normal work, this is the contributor's short-lived branch.
- **Protected branch:** A branch on which GitHub prevents direct or unsafe writes and requires the repository workflow.
- **Reserved branch:** A protected or role-restricted branch that ordinary contributors may not use.
- **Maintainer:** A person explicitly granted merge permission for this repository.
- **Release manager:** A maintainer responsible for builds, version tags, store submission, and production release operations.
- **Repository administrator:** A person responsible for GitHub settings, rulesets, access, secrets, and environments.

When this policy says that regular developers must “never interact” with a branch, it means they must not create it, check it out as a work branch, push to it, force-push it, delete it, rebase it, merge it, or open a PR using it as the head or base. A developer may see a protected branch in GitHub or receive a read-only reference to it, but must not use it for development.

## 4. Branch permissions

### 4.1 Allowed contributor branches

These are the only branch families a regular contributor may create and push:

| Branch pattern | Use | PR target | Contributor permissions |
|---|---|---|---|
| `feature/<issue>-<slug>` | New product functionality | `main` | Create, push, update, and delete their own branch |
| `fix/<issue>-<slug>` | Bug fix or regression fix | `main` | Create, push, update, and delete their own branch |
| `refactor/<issue>-<slug>` | Internal restructuring without intended behavior change | `main` | Create, push, update, and delete their own branch |
| `docs/<issue>-<slug>` | Documentation-only work | `main` | Create, push, update, and delete their own branch |
| `test/<issue>-<slug>` | Tests or test infrastructure | `main` | Create, push, update, and delete their own branch |
| `chore/<issue>-<slug>` | Maintenance, tooling, or housekeeping | `main` | Create, push, update, and delete their own branch |
| `perf/<issue>-<slug>` | Performance improvement | `main` | Create, push, update, and delete their own branch |
| `ci/<issue>-<slug>` | GitHub Actions or developer automation | `main` | Create, push, update, and delete their own branch |
| `security/<issue>-<slug>` | Security hardening or a privately tracked security task | `main` | Create, push, update, and delete their own branch; use private reporting for vulnerabilities |

`<issue>` is the GitHub issue number. `<slug>` is a short lowercase kebab-case description, for example:

~~~text
feature/142-add-workout-history
fix/187-refresh-blocking-balance
docs/201-document-supabase-migrations
test/215-cover-subscription-state
~~~

If there is no existing issue, create one before creating the branch. For a security incident, use the private security-reporting process and use the identifier assigned by the maintainer rather than disclosing details publicly.

### 4.2 Protected and reserved branches

The following names and patterns are not contributor work branches:

| Branch or pattern | Purpose | Regular developer access |
|---|---|---|
| `main` | Reviewed, releasable product history | Read/fetch/pull and use as a PR base; no direct write, force-push, deletion, or merge |
| `develop` | Not part of the current workflow | Never create or use. A PR to it is not allowed unless this policy is formally changed first |
| `staging` | Pre-production deployment, if introduced later | Never create or use |
| `production` / `prod` | Production deployment control, if introduced later | Never create or use |
| `release/*` | Release-manager-owned release preparation | Never create, push, delete, or use as a PR head/base |
| `hotfix/*` | Maintainer-owned emergency release work | Never create, push, delete, or use as a PR head/base |
| `archive/*` | Historical, read-only material | Never create, push, delete, or use as a PR head/base |
| `wip/*` / `tmp/*` | Local experiments only | Do not push or open PRs from these branches |
| `dependabot/*` | GitHub dependency automation | Do not create or push manually; review the bot PR instead |
| `v*` tags | Immutable release references, such as `v1.0.0` | Never create, move, delete, or force-update release tags |

The reserved list is deliberate. Do not create a `develop` branch just because a tutorial uses Git Flow, and do not create `staging` or `release/*` branches to bypass a review or deployment problem. If the product later needs another environment branch, the maintainers must update this policy and configure GitHub protections before the branch is created.

### 4.3 What contributors may do with `main`

Contributors may:

- clone the repository;
- fetch `main` and its history;
- pull the latest `main` into a clean local checkout;
- create an approved working branch from `main`;
- open a PR with an approved working branch as the head and `main` as the base.

Contributors may not:

- run `git push origin main`;
- run `git push --force` or `git push --force-with-lease` against `main`;
- delete or rename `main`;
- commit on `main` and use a direct push as the delivery mechanism;
- merge their own PR or bypass required checks;
- use `main` as a shared work branch.

The remote-tracking name `origin/main` is not a second development branch. It is the local reference to the GitHub `main` branch and has the same protection requirements.

## 5. Pull-request rules

### 5.1 Allowed PR matrix

For the current repository, the allowed normal PRs are:

| PR head/source | PR base/target | Allowed for regular developers? | Result |
|---|---|---:|---|
| `feature/*` | `main` | Yes | Normal feature PR |
| `fix/*` | `main` | Yes | Normal bug-fix PR |
| `refactor/*` | `main` | Yes | Normal refactor PR |
| `docs/*` | `main` | Yes | Documentation PR |
| `test/*` | `main` | Yes | Test PR |
| `chore/*`, `perf/*`, `ci/*` | `main` | Yes | Maintenance PR |
| `security/*` | `main` | Only for approved, non-sensitive security work | Use private reporting for vulnerabilities |
| `dependabot/*` | `main` | Review only; automation creates the head branch | Dependency update PR |
| `main` | `main` | No | A contributor must use a working branch |
| Any `develop`, `staging`, `production`, `prod`, `release/*`, `hotfix/*`, or `archive/*` | Any base | No | Reserved-branch interaction is forbidden |

There is no normal PR target other than `main` in this policy. In particular, contributors must not open PRs to `develop`, `staging`, `production`, or a release branch.

### 5.2 One branch, one purpose, one PR

- A branch should address one issue or one tightly related change.
- Do not combine unrelated UI, database, dependency, and cleanup changes in one PR.
- Do not keep using a merged branch for new work. Delete it and start a new branch from the latest `main`.
- Do not open multiple PRs from the same branch for unrelated targets.
- If work must be split, create separate branches and make the dependency clear in the PR description.
- A draft PR is appropriate for early design feedback, but it must not be merged while marked Draft.

### 5.3 PR title

Use the same format as the final commit title:

~~~text
<type>(<scope>): <imperative summary>
~~~

Examples:

~~~text
feat(workout): add workout history to the dashboard
fix(blocking): restore balance after a failed sync
docs(github): document branch and pull request policy
test(auth): cover expired verification codes
~~~

Keep the title short enough to scan in the PR list. The body explains the details.

## 6. Standard contributor workflow

### Step 1: Start from an issue and understand the project boundary

Before writing code:

1. Find or create the GitHub issue.
2. Read the relevant use-case specification in `docs/diagrams/use-case-specs/`.
3. Check the architecture and feature boundaries in [docs/structure/architecture.md](structure/architecture.md) and [docs/onboarding-guide.md](onboarding-guide.md).
4. Identify whether the change touches authentication, blocking, subscriptions, Supabase/RLS, native Android/iOS behavior, localization, or release configuration. These areas require extra review.

Do not start from an old local branch without checking its base. A stale or unknown branch can contain work from another issue.

### Step 2: Synchronize with `main`

Use a clean working tree and update the local base branch:

~~~bash
git status --short
git fetch --prune origin
git switch main
git pull --ff-only origin main
~~~

If `git status --short` shows changes that belong to another task, stop and preserve them. Do not delete, stash, or overwrite someone else's work without agreement.

### Step 3: Create an approved branch

~~~bash
git switch -c feature/142-add-workout-history
~~~

Replace the type, issue number, and slug with the actual task. Do not create the branch from `develop`, `staging`, `release/*`, `hotfix/*`, or another contributor's branch.

### Step 4: Implement within the project architecture

Follow the existing feature-based Clean Architecture and MVVM/coordinator conventions:

- keep domain logic in the appropriate `core/` layer;
- keep feature-specific UI and view models within the relevant `features/<feature>/` module;
- keep Supabase and platform integrations in the infrastructure layer;
- preserve the repository's kebab-case file and directory naming;
- update use-case, architecture, schema, or onboarding documentation when behavior or structure changes.

Do not use a PR as an excuse to perform unrelated repository-wide renaming or formatting.

### Step 5: Run local checks

From the repository root, run the checks relevant to the change:

~~~bash
flutter pub get
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
~~~

For platform-specific changes, run the available platform check as well:

~~~bash
flutter build apk
flutter build ios --no-codesign
~~~

The Android build is relevant to Android changes. The iOS build is relevant to iOS changes and requires a suitable macOS/Xcode environment. If a platform check cannot be run, state the limitation in the PR instead of claiming it passed.

Before committing, also inspect the exact change:

~~~bash
git diff --check
git status --short
git diff --stat
git diff
~~~

Never use `git add .` blindly. Stage only the files belonging to the issue and verify that `.env`, credentials, build output, IDE files, and unrelated changes are absent.

### Step 6: Commit and push the working branch

Use an imperative commit message with a recognized type:

~~~bash
git add path/to/intended-file.dart test/path/to/test.dart
git commit -m "feat(workout): add workout history"
git push --set-upstream origin feature/142-add-workout-history
~~~

The first push creates the remote working branch. Later pushes should name the same branch explicitly:

~~~bash
git push origin feature/142-add-workout-history
~~~

Never push to `main` or a reserved branch. Never include secrets in a commit simply because they are needed for a local build.

### Step 7: Open the PR against `main`

In GitHub, confirm all of the following before clicking **Create pull request**:

- **Base repository:** the Nashaat repository;
- **Base branch:** `main`;
- **Compare/head branch:** your approved working branch;
- **Title:** follows the project format;
- **Status:** Draft if feedback is still needed, otherwise Ready for review;
- **Issue link:** the PR references the correct issue, for example `Closes #142`;
- **Scope:** the changed files match the issue;
- **Checks:** the local commands and any available GitHub checks are listed honestly.

If GitHub proposes `develop`, `staging`, or another branch as the base, stop and select `main`. If the correct target cannot be selected, ask a maintainer rather than opening the PR against a reserved branch.

## 7. Commit-message conventions

Use:

~~~text
type(scope): imperative summary
~~~

Recommended types:

| Type | Use |
|---|---|
| `feat` | New user-visible capability |
| `fix` | User-visible bug fix |
| `refactor` | Internal code change with no intended behavior change |
| `docs` | Documentation only |
| `test` | Tests only or test support |
| `chore` | Maintenance that does not change product behavior |
| `perf` | Performance improvement |
| `ci` | GitHub Actions or automation |
| `build` | Build, packaging, or dependency infrastructure |
| `security` | Security hardening |

The repository's existing history is not fully uniform, so this convention is the standard going forward. During PR review, small fixup commits are acceptable. The maintainer should squash the PR into one coherent commit unless there is a documented reason to preserve separate commits.

Do not rewrite a branch after another person has based work on it. If you need to rebase your own unshared branch, tell active reviewers and use `--force-with-lease`, never a blind `--force`.

## 8. Pull-request description template

Copy this structure into each PR body:

~~~markdown
## Summary
- What changed?
- Why was it needed?

## Issue
Closes #<issue-number>

## Scope
- [ ] Flutter/UI
- [ ] View model/domain logic
- [ ] Authentication
- [ ] Blocking or screen-time accounting
- [ ] Subscription/payment
- [ ] Supabase schema/RLS/migration
- [ ] Android/iOS/native code
- [ ] Localization
- [ ] Documentation

## Validation
Commands run:
- `dart format --output=none --set-exit-if-changed lib test`
- `flutter analyze`
- `flutter test`
- Other: `<command>`

Result or limitation:
<Describe the result. Be explicit about checks that could not run.>

## UI evidence
<Add screenshots or a short recording for visual changes. Use test data only.>

## Database and configuration
- [ ] No database/configuration change
- [ ] Migration added and documented
- [ ] RLS/auth behavior reviewed
- [ ] No secret or production data included

## Risk and rollback
<What could fail? How would a maintainer safely revert or disable it?>

## Reviewer notes
<Call out areas that deserve special attention.>
~~~

The description must explain behavior and risk, not merely repeat the commit list. A reviewer should be able to understand the change without reconstructing the author's local session.

## 9. Review policy

### 9.1 Required review

- Every PR needs at least one approval from a reviewer other than the author.
- Changes to authentication, Supabase schema/RLS/migrations, blocking and screen-time accounting, subscriptions/payments, native platform code, CI/release configuration, or security need two approvals when two qualified reviewers are available.
- A maintainer must perform the final merge.
- The author may respond to comments and push fixes, but may not approve their own PR.
- A new push that changes reviewed code requires the author to tell reviewers what changed. GitHub should dismiss stale approvals when configured by administrators.

### 9.2 What reviewers check

Reviewers should evaluate:

- correctness against the linked issue and use-case specification;
- compatibility with the existing Clean Architecture and feature module boundaries;
- loading, empty, error, retry, offline, and permission states;
- authentication and authorization behavior;
- Supabase queries, RLS assumptions, migrations, and data consistency;
- screen-time balance and blocking invariants;
- subscription and payment safety;
- Arabic/localized text, layout direction, and responsive UI where applicable;
- tests for changed business rules and regressions;
- performance, lifecycle, and resource cleanup;
- secret handling, logging, and dependency risk;
- documentation and rollback impact.

Review comments should be specific and respectful. Mark a comment as blocking only when it must be addressed before merge. If a decision is made in a PR, update the code or documentation so the decision does not remain only in a comment thread.

### 9.3 Author responsibilities during review

The author must:

- answer every review comment;
- push fixes to the same working branch;
- re-run affected checks after changes;
- explain intentional deviations from the request or architecture;
- re-request review after a substantial update;
- keep the PR title, body, screenshots, and check results current.

Do not close a PR to hide unresolved feedback and open an identical PR. If the base or design is wrong, explain the correction and update the existing PR or ask the maintainer to close it.

## 10. Merge policy

A maintainer may merge only when:

- the PR base is `main`;
- the head is an approved working branch or an approved automation branch;
- the issue and acceptance criteria are addressed;
- required checks pass;
- required approvals are current;
- all blocking conversations are resolved;
- the branch is not carrying unrelated changes;
- no secrets, private data, or generated build artifacts are present;
- the maintainer has considered release and rollback impact.

The default merge method is **Squash and merge**. The squash message should use the approved PR title format. After a successful merge, delete the short-lived head branch unless it is actively needed for a documented dependent PR.

Do not:

- merge a red or failing PR because the change “looks small”;
- merge with unresolved conflicts;
- bypass required reviews or checks for convenience;
- merge directly from a developer's local checkout;
- leave a stale branch alive for future unrelated work;
- rewrite `main` after a merge.

## 11. Keeping a PR current

When `main` moves while a PR is open, update your own working branch:

~~~bash
git fetch origin
git switch feature/142-add-workout-history
git rebase origin/main
git push --force-with-lease origin feature/142-add-workout-history
~~~

Only use `--force-with-lease` on your own, unshared working branch. If another person is using the branch, coordinate before rebasing; a merge from `origin/main` may be safer.

After a rebase or conflict resolution:

1. inspect `git diff` and `git status --short`;
2. verify that no unrelated commits or files were introduced;
3. run the affected tests and checks again;
4. tell reviewers that the branch history changed;
5. confirm that the PR still targets `main`.

## 12. Project-specific change rules

### 12.1 Flutter code and tests

- Follow the Dart lints in [analysis_options.yaml](../analysis_options.yaml).
- Keep file and directory names in the repository's kebab-case convention.
- Add or update tests under `test/` for changed view-model and business behavior.
- Keep UI, state management, navigation, domain, and infrastructure responsibilities in their existing layers.
- Do not commit `.dart_tool/`, `build/`, simulator output, screenshots containing private data, or temporary debug files.

The tracked lock files are part of this Flutter application. A dependency change should normally include the corresponding intentional updates to `pubspec.lock` and, when iOS dependencies change, `ios/Podfile.lock`. Review lockfile changes for unexpected packages or version jumps.

### 12.2 Supabase schema, policies, and migrations

Database work is high risk and requires maintainer review:

1. Add a new migration under [supabase/migrations/](../supabase/migrations/); do not edit a migration that may already have been applied to a shared environment.
2. Use the repository's timestamped migration naming convention.
3. Test the migration and RLS behavior against a non-production environment or approved local setup.
4. Update [docs/db/schema.sql](db/schema.sql) and related architecture/use-case documentation when the documented schema or behavior changes.
5. Describe data impact, backfill requirements, rollback limits, and authorization behavior in the PR.
6. Never attach a production database dump or real user records to the PR.

If a migration has already reached a shared environment, create a corrective migration instead of rewriting history.

### 12.3 Authentication, blocking, subscriptions, and native code

These areas affect user access, time enforcement, money, or device permissions. The PR must include:

- the affected use case and invariant;
- failure and recovery behavior;
- tests or a reproducible manual test plan;
- platform/device coverage where relevant;
- a rollback or feature-disable plan;
- an explicit note about any required Supabase, App Store, Play Store, or OS configuration.

Do not test against production accounts or production data unless the release manager has approved a controlled procedure.

### 12.4 Documentation and diagrams

Documentation-only changes still use a branch and PR. Keep documentation close to the source of truth:

- use-case behavior belongs with the relevant use-case specification;
- architecture belongs in `docs/structure/` or the architecture diagrams;
- database structure belongs in `docs/db/`;
- onboarding and developer workflow belongs in `docs/`.

Use lowercase kebab-case filenames, and update links when moving a document.

## 13. GitHub administrator enforcement

This section is for repository administrators. The policy is not complete operationally until these settings are applied.

### 13.1 Protect `main`

Create a branch protection rule or repository ruleset for `main` that:

- requires a pull request before merging;
- requires at least one approval;
- dismisses stale approvals when new code is pushed;
- requires all review conversations to be resolved;
- requires the branch to be up to date before merging, where supported;
- requires the CI checks listed in Section 13.2 once they exist;
- blocks force-pushes and branch deletion;
- restricts direct pushes to maintainers or the release role;
- prevents contributors from bypassing the protection rule;
- makes `main` the default branch.

For high-risk paths, use CODEOWNERS or a second approval rule when the repository team is large enough to support it. Do not grant ordinary contributors a bypass permission merely to make a failing PR merge.

### 13.2 Add and require CI checks

The repository currently has no GitHub Actions workflow. Add a workflow under `.github/workflows/` that runs for pull requests and pushes to `main`. At minimum, the workflow should reproduce the project checks:

~~~bash
flutter pub get
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
~~~

Use stable, explicit check names and then require those exact names in the `main` ruleset. Platform builds can be path-specific or separate checks because Android and iOS runners have different toolchains. A check must not be marked successful when it was skipped because a required environment was unavailable.

### 13.3 Protect reserved names and release tags

Configure rulesets and repository permissions for:

~~~text
develop
staging
production
prod
release/*
hotfix/*
archive/*
v*
~~~

Regular contributors must not be able to create, update, force-update, or delete these refs. Release tags should be created only by the release manager or an approved release workflow.

### 13.4 Add repository guardrails

Administrators should add and maintain:

- a pull-request template based on Section 8;
- a CODEOWNERS file for high-risk areas when ownership is agreed;
- issue templates for bugs, features, security reports, and database changes;
- Dependabot or another approved dependency-update process, if desired;
- protected GitHub Actions environments for release and production operations;
- least-privilege repository roles with no production credentials for ordinary contributors;
- secret scanning, push protection, and dependency alerts where available.

These additions should themselves be made through a PR to `main`, except for the GitHub settings that can only be changed in the repository administration interface.

## 14. Issues, labels, and project communication

Use GitHub issues as the durable record of scope and decisions:

- one issue per feature, bug, documentation task, or technical change;
- include acceptance criteria and affected area;
- link related use cases, schema docs, screenshots, or design decisions;
- close the issue from the merged PR with `Closes #<number>`;
- move unresolved follow-up work to a new issue instead of silently expanding the PR.

Recommended labels are:

~~~text
type:feature    type:bug       type:docs       type:chore
area:auth       area:blocking  area:workout    area:subscription
area:database   area:native    area:ci         area:localization
priority:high   priority:normal priority:low
risk:high       risk:normal    status:blocked status:needs-review
~~~

Never place passwords, access tokens, private vulnerability details, real user data, or production credentials in an issue. Move sensitive information to the approved private channel and leave only a non-sensitive reference in GitHub.

## 15. Security and secret handling

The project uses local environment configuration for Supabase settings. Local `.env` files are ignored and are not tracked. Developers must:

- keep `.env` and other local secret files outside commits;
- use a local or test project for development;
- never put a Supabase service-role key, database password, signing key, keystore, provisioning profile, or GitHub token in source control;
- never print secrets in test output, debug logs, PR comments, or GitHub Actions logs;
- use GitHub Actions secrets or protected environments only for approved automation;
- review staged files before every push.

If a secret is committed or exposed:

1. stop sharing or using the exposed value;
2. notify a maintainer privately;
3. revoke or rotate the credential immediately;
4. determine whether logs, caches, artifacts, forks, or tags also contain it;
5. remove it from history through the repository's approved incident procedure;
6. document the incident without copying the secret into the report.

Deleting a secret from the latest commit is not enough if it was present in Git history or a public artifact.

## 16. Failure and exception handling

### A contributor accidentally pushes to `main` or a reserved branch

Stop immediately. Do not force-push, reset, delete, or attempt a history rewrite. Tell a maintainer exactly which ref was changed and which commit was pushed. The maintainer will preserve evidence and choose the safest recovery.

### A PR is opened against the wrong base

Do not merge it. Change the base to `main` if the commits are correct and GitHub can represent the change safely; otherwise close it and open a new PR from a clean working branch. Ask a maintainer if the target selector is unavailable.

### `main` is broken

Do not repair it with a direct push. A maintainer creates a `fix/<issue>-<slug>` branch from the current `main`, opens an urgent PR into `main`, and documents the validation and rollback plan. If a release-only branch is needed, it is owned by the release manager under the reserved-branch rules.

### A PR has conflicts

Update the contributor's own working branch from `origin/main`, resolve conflicts locally, run the affected checks, and push the result. Never resolve conflicts by editing `main` directly.

### A check cannot run locally

Report the exact command, environment limitation, and any alternative validation in the PR. Do not replace “not run” with “passed.” A maintainer decides whether a controlled CI or device run is required.

### Emergency security fix

Do not disclose the vulnerability in a public issue or PR. Use the private security process, create only the minimum necessary non-sensitive tracking information, and let the maintainer/release manager coordinate the fix and release.

## 17. Release and tagging policy

Nashaat does not use long-lived `release/*` branches by default. Releases are cut from reviewed commits on `main`.

The release manager should:

1. confirm that `main` is green and the intended PRs are merged;
2. update the application version in `pubspec.yaml` through a PR when required;
3. run the appropriate Android and iOS builds in approved environments;
4. verify Supabase migration and configuration readiness;
5. create an annotated version tag from the exact release commit;
6. publish the GitHub release and store artifacts through approved credentials;
7. record known issues and rollback steps.

Example tag commands for a release manager:

~~~bash
git switch main
git pull --ff-only origin main
git tag -a v1.0.0 -m "Release v1.0.0"
git push origin v1.0.0
~~~

Contributors must not create, move, delete, or force-update `v*` tags. Production migrations, store submission, signing credentials, and release environments are release-manager responsibilities, not ordinary developer permissions.

## 18. Roles and access boundaries

| Role | May create/push working branches | May approve | May merge to `main` | May change GitHub rules/settings |
|---|---:|---:|---:|---:|
| Contributor | Their own approved branch only | No for their own PR | No | No |
| Reviewer | Only if also assigned as contributor | Yes, when qualified | No unless also a maintainer | No |
| Maintainer | Yes | Yes | Yes, through the PR rules | Only if granted |
| Release manager | Yes, plus release operations | Yes | Yes | Release settings only when granted |
| Repository administrator | By assignment | Yes | Yes if also a maintainer | Yes |

Access should be granted through GitHub roles and protected environments, not through shared accounts or shared tokens. A person's role does not permit them to bypass the documented review or secret-handling process.

## 19. Quick-reference checklists

### Before creating a branch

- [ ] I have a GitHub issue or approved private task identifier.
- [ ] I understand the relevant use case and architecture boundary.
- [ ] My local `main` is current.
- [ ] My working tree is clean or I have preserved unrelated work.
- [ ] My branch name uses an approved type, issue number, and kebab-case slug.

### Before opening a PR

- [ ] The head is my approved working branch.
- [ ] The base is `main`.
- [ ] The PR addresses one issue or one cohesive change.
- [ ] `git diff --check` passes.
- [ ] Formatting, analysis, and tests were run and reported honestly.
- [ ] UI evidence is included for visual changes.
- [ ] Database/configuration impact is documented.
- [ ] No secrets, private data, build output, or unrelated files are included.

### Before merging

- [ ] Required checks are green.
- [ ] Required approval(s) are current and not from the author.
- [ ] Blocking conversations are resolved.
- [ ] The branch is up to date with `main`.
- [ ] The PR has a rollback or recovery plan appropriate to its risk.
- [ ] The maintainer will squash-merge and delete the short-lived branch.

### Daily safe commands

~~~bash
git status --short --branch
git fetch --prune origin
git switch main
git pull --ff-only origin main
git switch -c fix/187-refresh-blocking-balance
git diff --check
~~~

Avoid destructive commands unless the target and ownership are certain. In particular, never use `git reset --hard`, `git clean -fd`, or force-push commands to “fix” a shared branch or an unknown working tree.

## 20. Changing this policy

Changes to branch names, PR targets, merge strategy, required checks, or access boundaries must be proposed in a PR to `main` that updates this file. The PR must explain:

- why the current workflow is insufficient;
- which teams or roles gain or lose access;
- which GitHub rulesets and CI checks will change;
- how existing open branches and PRs will be migrated;
- how the new workflow will be rolled back.

The repository administrator applies the corresponding GitHub settings only after the policy PR is approved. Until both this document and the GitHub settings agree, the more restrictive rule applies.

**Policy owner:** Nashaat maintainers

**Default PR target:** `main`

**Default merge method:** Squash and merge

**Review this policy when:** A new permanent branch, deployment environment, release process, or CI requirement is introduced.
