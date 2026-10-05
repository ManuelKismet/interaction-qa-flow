# Development acceptance coverage index

Updated 2026-10-05. This index is the starting point before running a test. Scope is development only; production and the old local database are excluded. Detailed evidence and chronology remain in [the checkpoint](user-admin-e2e-checkpoint-2026-10-04.md). PASS means the stated scope only, not every related feature. UNCERTAIN means evidence is incomplete, not a failure.

| Gate / actor | Status | Evidence / scope | Next action or reason for retest |
|---|---|---|---|
| Guest local Knowledge and Interact common flows | PASS, reuse | Historical guest checkpoints; participant/nested/report/template checks recorded | Repeat only a changed path |
| Guest registration/linking, guesttester1@test.com | PASS, reuse |9eaa93a: Link guest recovery submitted, signed-in identity after reload;6d89698 authoritative verification | No new signup/linking |
| Linked account without organisation, local continuity | PASS, reuse |6d89698 signout/signin: local Knowledge, both sessions, reusable template retained; no organisation | On-device preservation; no cloud-transfer claim |
| Verification email delivery | OPEN |guesttester1 and later synthetic accounts manually verified | Normal email delivery not demonstrated |
| Original guest group's owner/admin after linking | UNCERTAIN |9eaa93a/6d89698 local continuity does not prove group membership;9032f23 later used new anonymous identity | Inspect existing guesttester1/group records; narrow retest allowed if inconclusive |
| Guesttester1 later org/department/team enrolment | UNCERTAIN | No exact completion located in all-history search | Use existing identity; do not repeat regularuser1 enrolment |
| Regularuser1 organisation enrolment/department/team assignment | PASS, reuse | Current checkpoint: Employee, E2E Operations, two teams | Separate from guesttester1 continuity |
| Admin organisation setup/member management | PASS recorded scope | Current checkpoint: synthetic org, departments, teams, membership | Wider matrix tracked separately |
| Regular Knowledge lifecycle/search/contribution | PASS recorded scope | Current checkpoint: own content, approved content protection, search, discussion, review request | No general repeat |
| Regular private Interact lifecycle/report/reload | PASS, reuse |ca40e2aa fixture, completed and persisted | No general repeat |
| Organisation Interact non-owner read-only UI | PASS affected regression | Populated organisation session read/report; write controls removed | Keep private/session matrix separate |
| Scoped answer-owner assigned/role-only/out-of-scope/revoked UI | PASS, cleaned | Current checkpoint, temporary authority restored to Employee | No repeated role grant |
| Admin question/answer review/challenge decisions | PASS recorded cases | Current checkpoint: challenge reject/accept and question-change reject | Audit storage completeness separate |
| Canonical merge/unmerge | PASS, cleaned |7b1e2087/e700114c merge200/unmerge200; archived/unlinked duplicate baseline | No repeat |
| Template ownership/archive/Restore | PASS affected regressions |bd0ae05 non-owner hidden, owner/admin actions and Restore | Failure SnackBar widget evidence only |
| Basic JSON/CSV native clipboard | PASS | Existing private session exports; JSON2261chars/CSV259chars | No repeat |
| Hosted CSV formula neutralization / JSON fidelity | PASS |0f87f47 fixture69d4afaf;203chars,2rows/8columns,4 risky cells protected | No spreadsheet execution/full hosted control-character claim |
| Verified registered Shared groups create/join/approval | PASS |0f87f47 groupa12cb842; Employee owner, orgAdmin invited viewer | No repeat except changed removal path |
| Group and organisation authority independence UI | PASS recorded cases | OrgAdmin had no automatic group; approved viewer write/invite disabled | Full direct-API matrix remains separate |
| Shared-group member removal | BLOCKED hosted; fix validating |0f87f47 blank page/no request; newdaadc66 fix/widget test | Validate exact head, deploy development, retest removal/revocation only |
| Guest optimistic concurrency | PASS recorded scope | Conflict/retry/save and no overwrite in prior guest checkpoint | Stale-draft closing usability separately open |
| Stale guest draft closing | OPEN | Earlier pending usability item | Narrow UI check |
| PDF native supported glyphs/multipage/nesting | PASS recorded scope | Prior report checks | Printed CJK/emoji output tooling-blocked; do not equate HTML preview with PDF |
| Tenant/private/department/team full route matrix | PARTIAL | Automated boundaries and recorded hosted samples | Identify missing actor/route combinations; tags do not imply team privacy |
| Navigation spinner/reload-to-root | OPEN | Some route-specific recovery passes; root cause not closed | Narrow reproductions; no blanket navigation sign-off |
| Proposal approval atomicity/retry | FAIL reproduced; fix validating |a67a246 disposable probe: partial question then duplicate on retry;daadc66 regression | Independent90backend pass; hosted normal approval follows reviewed rollout; no live failure injection |
| DB readiness | SOURCE/TEST validating |daadc66 /ready distinct from /health | Check exact tests then hosted healthy endpoint; no live outage injection |
| Dependency lock/lint/compile reproducibility | VALIDATING |daadc66 pinned backend lock; fresh clean installation running | Record actual completion |
| GitHub CI | BLOCKED externally | Copilot reports action_required/zero jobs | No CI execution claim; local gates distinct |
| Development recovery procedure | DOC reviewed, rehearsal NOT RUN |daadc66 development-recovery.md | No restore/IAM changes; rehearsal requires separately scoped approval |
| Current deployed code |0f87f47 |APIreview0f87f47, Hosting1791199919218000 | daadc66 not deployed until all gates pass |

## Workflow to prevent repeated work

1. Start here, then read the linked dated evidence. Search current docs AND git history for the actor/fixture before calling a gate untested. Historical commits may contain checkpoints absent from this branch.
2. Reuse PASS evidence when the implementation is unchanged. A repeat must name the changed code, changed actor boundary or missing assertion. Ask for credentials only when an uncovered case needs that identity.
3. For each new result record exact commit, environment, actor, fixture, expected/observed result, evidence and cleanup state in the checkpoint; update this index in the same documentation commit.
4. Keep source review, automated tests, hosted UI/API and actual exported artifact evidence distinct. An observation probe that reproduces a defect is not acceptance.
5. Explicitly mention @copilot for assignments; a posted comment is not receipt/completion evidence. Review exact new head and independent gates before development rollout.
6. Record corrections/lessons immediately. Preserve historical evidence and link superseding conclusions rather than silently overwriting it.

### Independent validation update — 5 October 2026
Copilot head daadc665b0d59174e4e915bf5e2d0bff0dfcdfb2: full disposable PostgreSQL backend suite 90 passed; Flutter 119 passed; analyzer and release web build passed. Fresh lock-file installation, pip check, selected Ruff checks and compileall passed. These are local independent gates; hosted removal and normal approval remain pending deployment. GitHub CI still requires approval and is not a pass. Completed historical signup and CSV checks remain reused.

### Development rollout verified — 5 October 2026
daadc66 deployed: Cloud Run intqaflow-dev-api-reviewdaadc66 Ready, runtime configuration preserved, 100% traffic, /health and database-backed /ready both 200. Hosting release 1791205666163000, version d283dab943f1089c, 36 files. Both Hosting origins main.dart.js hash-match the exact validated build. Rollback targets: API review0f87f47; Hosting version 331eb642df81e56c. Hosted member removal and normal proposal approval still require targeted UI acceptance; do not mark them passed from deployment alone. Historical guesttester1 linking/local continuity and CSV remain reused. No new account created.

### Existing-owner authentication blocker — 5 October 2026, 13:30 UTC
Hosted removal regression remains BLOCKED, not failed or passed: regularuser1@test.com login received Firebase auth/invalid-credential after the intended Switch account confirmation, including the founder manual retry. No member removal request was made. Admin session remains available; updated app loads and Review has no pending Interact proposals. Do not repeat signup, reset credentials automatically, or infer successful authentication from the switch confirmation. Resume owner-only removal and fresh approval fixture after verified existing-owner sign-in.

### Read-only Firebase diagnosis — 5 October 2026, 14:05 UTC
Founder reports another invalid-credential after Switch account. Confirmed visible auth/invalid-credential. Read-only development Firebase accounts:lookup confirms regularuser1@test.com and guesttester1@test.com both exist, enabled, email verified, password provider configured. No credentials read or changed. Reviewed sign_in_page: anonymous switch dialog only asks confirmation, then calls normal signInWithEmailAndPassword with trimmed email and password controller; no account recreation or password mutation. This excludes missing/disabled/password-provider account as the observed blocker; it does not prove entered password validity or exclude input synchronization issues. Do not repeat failed attempts in a loop. Existing-owner hosted checks remain blocked pending successful sign-in or founder-operated password recovery.

### Account UX review and scope decision — 5 October 2026, 15:12 UTC
Reviewed Copilot head dfb17ad04bec93d32f37a1e27dac686de82a1bbb (new changes limited to Flutter auth/workspace, widget tests, architecture, checkpoint and retention docs). Founder confirms keep browser-local guest drafts and shared browser-profile session; provide a notice distinct from online Shared groups. No backend draft migration or multiple guest-profile UI. Extension/Teams/plugin implementation remains deferred until core feature/function acceptance is complete. Default account creation links current guest UID; explicit start fresh creates a separate account; organization membership stays optional. Source captures credentials before async confirmation but hosted invalid-credential cause remains unresolved. Source now blocks leaving a sole-admin guest group or unverifiable ownership. Immediate admin transfer exists; recipient acceptance and recoverable group closure remain NOT IMPLEMENTED, tracked as pending product work. Our disposable anonymous fixture owns an empty group, so this guard can block owner-account sign-in after deployment; do not pretend that is fixed by wording or repeatedly ask founder to log in. Resolve the fixture/group lifecycle deliberately before resuming owner-only removal. Backend unchanged from 90-pass daadc66; reuse that evidence. Independent exact-head Flutter tests/analyze/build running; no new deployment yet.

### Independent UX regression result — 5 October 2026
Exact dfb17ad full Flutter suite: 126 passed, 1 failed in 48 seconds. New test shared guest account creation defaults to same-UID linking fails at account_state_widget_test.dart:397 because a broad text finder matches both heading and action label (2 versus expected 1). This is a test ambiguity, not evidence linking failed. Sent precise fix request to @copilot comment 5997334521. Analyzer/build running separately for additional compile evidence; deployment blocked until meaningful corrected test passes. Lifecycle proposal requested in comment 5997297812; accepted transfer/group closure remain pending. Do not repeat signup or credential retries while reviewing these changes.
