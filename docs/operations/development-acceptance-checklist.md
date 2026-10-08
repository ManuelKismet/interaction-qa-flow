# Development acceptance checklist

> Current status (2026-10-05): historical baseline and scenario inventory. Dated FAIL/PENDING/NOT RUN labels below are not current verdicts. See [current checkpoint](development-deployment/user-admin-e2e-checkpoint-2026-10-04.md) for superseding evidence and remaining gaps. Production and old local database excluded.

Prepared 2026-10-02. Deployment remains deferred. Keep the old local database and its volume until hosted end-to-end acceptance passes. Use synthetic data and fake embeddings for local checks. No production data, live embedding calls, public server exposure or global App Check enforcement changes are part of this checklist.

## Evidence and policy

Baseline source: detached PR 4 commit 936e801848c20ac3b453212add47dc7c895fde44. Isolated SQLite ASGI tests used real identity dependencies and UID membership mapping with mocked Firebase token verification. This does not prove live signatures, token exchange, hosted PostgreSQL isolation or browser acceptance.

The user confirmed private Interact sessions are owner-only, including against organisation administrators. Copilot correction requests: PR 4 comments 5960196899 (IQ-03/IQ-04) and 5960415960 (IQ-05). All three are acceptance blockers until independently verified on the corrected commit.

Run from the pinned backend worktree with PYTHONPATH set to that backend:

```sh
EMBEDDING_PROVIDER=fake /tmp/intqaflow-backend-review-venv/bin/python -m pytest -q -s -p no:cacheprovider tests/test_firebase_auth.py tests/test_guided.py /workspaces/intqaflow/docs/operations/review-probes/backend_security_observations.py
```

Observed: 20 passed in 3.12 seconds. Two opt-in observation probes deliberately assert existing defects; their success means the defects reproduced, not privacy acceptance. All 81 documented API operations tested rejected missing identity. Sample other-tenant ID returned 404, forged organisation returned 403 and employee administrator action returned 403. IQ-03 private detail/list/answers returned 200 and unrelated comment creation 201. IQ-04 departmentless department session creation returned 201 and unrelated departmentless read 200. IQ-05 administrator read of another owner's private session returned 200.

Flutter baseline: clean analysis and tests; JavaScript release build succeeded with optional Wasm dry run disabled. See firebase-flutter-validation.md. No live sign-in or App Check exchange has been performed.

## Test identities and evidence

Use tenant A owner, unrelated same-tenant employee, tenant A administrator, same-department member, different-department member, departmentless member and tenant B member. Include inactive and unmapped identities. Each role must use its own server-side UID mapping; never simulate permissions only with client headers. Use unique synthetic question/session markers and shared resource IDs for negative tests.

For each executed case record commit, date, environment, actor role/tenant, action, expected result, observed result and evidence reference. Redact ID tokens, App Check tokens, database URLs and credentials. Separate mocked automation, real browser behaviour and hosted database evidence. Pending and blocked cases must not be signed off as passed.

## Authentication and App Check

| Case | Action and expected result | Current evidence / next step |
|---|---|---|
| Sign-in and membership | Real email/password sign-in produces authenticated identity; UID maps to server-side tenant and role; sign-out removes access. | Live pending; no development user provisioned by this run. |
| Invalid identity | Missing, expired, wrong-project, revoked or disabled identity denied; inactive/unmapped UID denied. | Existing mocked auth tests passed; live SDK verification and revocation IAM still pending. |
| Forged client identity | Supply forged user, tenant and role headers or request fields; server identity remains authoritative and forged selections denied. | Mocked identity/tenant tests passed; browser replay pending. |
| Enterprise exchange | Client selects registered Enterprise provider; approved development origin yields token accepted by backend. | Registration exists; live exchange pending. Codespace/localhost is not a registered origin. |
| Observation mode | Missing App Check token follows observation policy; supplied invalid token is denied. | Mocked backend tests passed. Live observation pending. |
| Enforcement mode | In an isolated test configuration, missing/invalid/wrong-app token denied and valid matching token accepted. | Mocked tests passed. Do not turn on global enforcement before live positive/negative checks. |
| Independent protections | Valid identity with bad App Check denied; valid App Check without identity denied; App Check does not grant user permissions. | Missing identity checked across 81 operations; live combined cases pending. |
| Local browser prerequisite | Confirm supported private development origin or explicitly scoped debug setup before browser token tests. | Blocked: no debug tokens or additional domain configuration created. |

## Tenant isolation and private content

| Case | Action and expected result | Status |
|---|---|---|
| Cross-tenant reads and writes | Tenant B replays tenant A IDs and queries for questions, answers/comments, departments/teams, Interact sessions, reports/imports/exports; no data returned or mutations allowed. | Sample direct question and forged selection passed; full route/role matrix pending. |
| Private Knowledge | Owner can read and use own question; unrelated same-tenant employee cannot discover/read/comment on it or access child resources. | FAIL IQ-03; awaiting correction. |
| Private derived data | Lists, pagination, search, answers, comments, reactions, versions and canonical/alias metadata must not reveal a private parent's content or identifiers to unauthorised actors. | Expanded coverage pending on correction. Filter visibility before pagination. |
| Department Knowledge | Author and authorised department member retain documented access; other department, departmentless and other tenant denied. | Pending full positive/negative matrix. |
| Department Interact | Create/update/import requires valid same-tenant department; legacy null-department records never authorise unrelated departmentless members through null equality. | FAIL IQ-04; awaiting correction. |
| Private Interact owner-only | Owner retains access; unrelated employee and administrator cannot read/edit session, children, reports or exports; lists exclude it. | FAIL IQ-05 direct administrator read; awaiting correction and expanded coverage. |
| Authorised shared visibility | Department and organisation visibility still work for legitimate members after privacy fixes. | Pending positive regressions. |
| No side effects on denial | Denied comment/edit/import/branch actions leave database contents unchanged. | Pending correction regression checks. |

## Phase 6 Interact manual scenarios

Recovered earlier notes establish these outstanding scenarios, but do not contain the original A–M labels or a case-by-case sign-off. The repository lookup also did not locate that original matrix. This is a working scenario inventory, not a replacement or renumbering of the original A–M plan. All browser cases below remain NOT RUN; passing existing test_guided.py cases is supporting automation only.

| Scenario | Manual procedure and acceptance result |
|---|---|
| Participant switching and shared answers | Create two synthetic participants, enter distinct participant answers plus shared answers, switch repeatedly and reload. Shared answers remain shared; participant answers remain associated with the correct participant. |
| Answer-owned participant branches | Add a follow-up to one participant answer. Another participant must not inherit that private answer branch; switching back restores the correct branch and ownership. |
| Nested follow-ups and return to main path | Traverse multiple follow-up levels, complete a leaf and continue. Navigation returns to the correct parent/main path without skipped prompts, duplicate answers or orphaned branches; reload preserves structure. |
| Template-version isolation | Create a session from one template version, change/publish the template, then create another session. Existing session structure remains stable and new session uses the new version. |
| Legacy import | Paste a synthetic legacy JSON fixture into the existing import dialog, verify participant/branch relationships and safe defaults, then round-trip export/import. Invalid or cross-tenant references fail without partial mutation. |
| All-participant reports | Generate a report covering every participant and shared answers, including nested branches. Counts and ownership match the source session; private/session authorization also applies to report/export. |
| Knowledge search separation | Search for unique Interact-only markers. They do not appear in Knowledge results until an explicitly authorised Knowledge proposal/promotion workflow completes. |
| Knowledge bridge and review | Exercise authorised proposal/review flow with synthetic data and fake embeddings; reject unauthorised review and preserve provenance. Record IQ-06 department-owner review and IQ-07 rollback behaviour separately. |
| Export safety | Round-trip JSON copy/paste without changing ownership/visibility. For CSV, formula-prefixed synthetic values must not execute as formulas. IQ-08 remains a separate audit item. |
| History and restart | Edit and reload a session; inspect version/history behaviour without claiming revision labels are restorable snapshots. Record IQ-10 separately; compare UI and API results. |

## Execution order and remaining gates

1. Baseline synthetic auth/App Check, tenant samples and guided suite executed above.
2. Independently test Copilot's IQ-03/IQ-04/IQ-05 corrections, including both authorised and denied operations. Keep defect observation probes separate from acceptance tests.
3. Resolve live prerequisites: server ADC/revocation-check permission, scoped local App Check strategy and synthetic Firebase UID membership setup. No additional IAM grants are authorised by this document.
4. Run real sign-in and App Check positive/negative checks privately; then verify hosted database behaviour on the reviewed schema/migrations. Migration 0008 is not applied by this checklist.
5. Run the Phase 6 browser scenarios, capture verdicts, and reconcile recovered A–M labels if the original source becomes available.
6. Review remaining audit findings and record formal sign-off before discussing deployment or retiring the local database.


## Independent correction review on 2026-10-02

Pinned b2bdf20ab102eec625dfa844618af4efc5f39cf3: full fake-embedding backend suite 52 passed in 6.38 seconds. Separate UID-mapped replay confirmed original IQ-03 direct reads/child reads/comment and answer writes/list exclusion, owner access, sampled tenant denial and IQ-04 null-department creation denial/legacy record reads/revisions/exports/list exclusion. IQ-05 still reproduced there.

Copilot then completed IQ-05 in 2962b2c502e5ff1183fb5bfadde683e1c9a91667. Independently pinned this commit: full fake-embedding suite 53 passed in 6.34 seconds; the UID-mapped replay passed four cases in 2.34 seconds, including 81 missing-identity operations and administrator denial on another owner's private Interact session. Inspected owner/read authorization changes and the focused suite. These results are synthetic SQLite evidence with mocked token verification, not live hosted acceptance.

Remaining IQ-03 canonical-target leak: an unrelated same-tenant actor submits a duplicate suggestion for a visible source question, selecting a visible alias whose canonical root is private. POST /api/v1/questions/{source}/duplicate-suggestions returns 201 and discloses the private root's ID and title. Permission is checked on the alias before _root resolves it; the resolved root lacks a visibility check. Independent negative acceptance test fails (expected 403, observed 201), and a suggestion is persisted. This blocks Knowledge privacy sign-off despite the ordinary suite passing.

Reproducible opt-in files:
- review-probes/privacy_acceptance.py: four successful boundary cases on 2962b2c.
- review-probes/canonical_privacy_acceptance.py: one failing private canonical-target case on 2962b2c.

Run from the pinned backend with PYTHONPATH containing that backend and the isolation branch's docs/operations/review-probes directory, using the review virtual environment and EMBEDDING_PROVIDER=fake. Invoke these files explicitly with pytest; they are not automatically included in the application's suite. Preserve backend_security_observations.py as the historical defect reproduction helper.

Next correction: check visibility of resolved canonical roots and intermediate aliases before suggestion creation and response construction; test denied creation leaves no persisted suggestion, legitimate owner/public-root operations succeed, and related canonical/search paths do not expose private target metadata. Live Firebase/App Check, hosted migration/database acceptance and manual Phase 6 remain pending. No merge or deployment.


Current test planning starts with [the coverage index](development-deployment/user-flow-acceptance-index.md); do not rerun historical cases marked PASS without a documented reason.
