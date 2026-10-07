# Unified Knowledge search workflow checkpoint — 2026-10-06

## Latest independent replacement review — correction pending, 2026-10-07

Replacement PR19 delivery completed in artifact commit
`20f6a89c8f35a2b077298b029d10abf17c815642`, parent adee30e5.
Mailbox path `docs/operations/development-deployment/unified-knowledge-ask-parity-replacement-20261007.patch`;
exact-byte SHA256 `d49ac604aa73037ce7e6de56fcc01d3544cd688a8463fa1e1f424c5ac4ffb630`.
Declared base e9e3cc804e8dbb45033e637304fd34c21cd14b2f verified.
Applied UNCHANGED via git am in /workspaces/intqaflow-unified-search-dev-20261006.
Complete review source **`6514b7e50c38520449b114853f9f11d1c74db136`**, pushed to
fix/unified-search-dev-20261006 and exact GitHub readback verified.
Independent entire-tree diff against authored adee30e53a92b6e51fa3ee2472216db1b7beeb20
is empty; diff --check passed. Five Flutter files only; no backend/schema changes.
Isolated tree clean and four dirty main docs preserved. No Codex app/test edits.

| Executed independent check on6514b7e | Result |
|---|---|
| Python compile / Alembic heads | exit0 / single0014, exit0 |
| Full backend |111 passed,4 skipped,10 warnings,22.07s,exit0|
| Fresh real PostgreSQL16 |4 passed,1.53s,exit0,asyncpg|
| Separate isolated migration database |0014→0013→0014 and current0014 PASS,exit0|
| Full Flutter |177 passed,3 failed,about80s,exit1|
| Analyzer |0 errors,0 warnings,13 existing infos,16.3s,exit1 due infos|
| Configured DEV release web build |PASS,105.5s,exit0|
| Non-mutating Dart format check |all5touched files would change,exit1; no modifications|

Initial PostgreSQL/migration attempt used unavailable psycopg driver and failed
ModuleNotFoundError; corrected executions used installed asyncpg on fresh local
databases ask_pr19_tests_6514b7e / ask_pr19_migrate_6514b7e, host127.0.0.1:55442.
Do not report initial attempt as a code failure or hide it. No hosted DB touched.
Logs/exit receipts retained in /home/vscode/.local/share/intqaflow/ask-validation-6514b7e.

**ONE targeted incremental correction** sent on same authorised
[PR19 comment6033327274](https://github.com/ManuelKismet/interaction-qa-flow/pull/19#issuecomment-6033327274),
complete baseline6514b7e, no competing task:
- controller test 'drops stale results after identity and membership changes':
expected three password calls, actual four; diagnose legitimate transition refresh
vs redundant/unscoped request, retain scope/privacy rejection assertions.
- actual GuestWorkspacePage navigation harness raises [core/no-app] Firebase default
app missing through firebaseAuthProvider, followed by Saved Q&A missing at
ask_page_test.dart:328. Faithful deterministic provider overrides required;
do not replace real destination with dummy text/suppress exceptions.
- manual-only submission test StateError 'No element' at ask_page_test.dart:436;
fix finder/harness/control behaviour while retaining exact manual payload and
no retrieved/local/private-content upload assertions.
- Copilot to format touched Dart files. Preserve all previous parity acceptance.
Await completion/mailbox declaring baseline6514b7e and exact checksum before
UNCHANGED application and independent rerun. Copilot's original Flutter tools
were unavailable exit127; its outer shell0 was not a pass.

DEV rollout **HELD**, unchanged complete reviewed105a528 /
intqaflow-dev-api-review105a528100%, schema0014 /
Hostingrelease1791323636722000/version4eb839685c6f21c7.
Keep reviewed rollback and additive schema/private data; no live downgrade/purge.
Temporary PostgreSQL stopped (pg_ctl confirmed server stopped), no proxy started.
Codespace bookish-happiness-w974vpwgq7j3g95v stopped, GitHub banner confirmed.
All source/log/database files retained. Main four dirty docs preserved.
Old PR13 task8c57d37e remains quarantined (not confirmed cancelled); reject late
outputs. Replacement identity remains b8a0e4a5-3c30-4d03-a7d3-9d1739fa54f0.
Fake-provider semantic quality and authenticated personal-import E2E/F04/F08/F09
remain unverified. Organisation improvements DEFERRED. No production, merge,
security/IAM/AppCheck weakening, secrets disclosure or automatic upload.
Monitoring remains cancelled; no automation created.

## Active replacement and old-output quarantine — 2026-10-07

Founder explicitly authorised a NEW SEPARATE Copilot session after both browser
and manual Stop failed to confirm cancellation of stalled request6026870639.
CLI2.102.0 was installed from the official release with SHA256 verified, outside
the repo at /home/vscode/.local/bin/gh. Authenticated workflow lookup succeeded;
no new Actions run exists for the old correction. Exact CLI Stop attempt returned
unknown command "stop" for "gh agent-task". Do not claim old cancellation.
Codespace stopped again; files and main four dirty docs preserved.

ONLY active authorised correction: **REPLACEMENT-ASK-PARITY-20261007**.
[Replacement task](https://github.com/ManuelKismet/interaction-qa-flow/tasks/b8a0e4a5-3c30-4d03-a7d3-9d1739fa54f0?q=is%3Aopen+author%3A%40me)
ID `b8a0e4a5-3c30-4d03-a7d3-9d1739fa54f0`; initial activity/session
`659d9fb1-53de-49bc-bb43-acdf79ad6f21`. GitHub shows **In progress**,
with actual environment setup, base/checkpoint/PR discussion inspection and Ask
source/test reads, not merely a queued spinner. Created2026-10-07 around07:01Z
(08:01 Europe/London). No completed artifact or new independent passes yet.
Selected source branch fix/unified-search-dev-20261006; fresh GitHub readback
confirmed exact COMPLETE base `e9e3cc804e8dbb45033e637304fd34c21cd14b2f`.
Same full correction6026870639 and original acceptance6026591268; no added scope.
Replacement must use a separate branch/PR, never old PR13 carrier, publish ONE
incremental format patch declaring this base plus authored/source/artifact SHAs.
Copilot owns app/tests; Codex applies unchanged and independently reruns gates.

**SUPERSEDED / QUARANTINED**: old correction request6026870639,
created2026-10-06T22:49:13Z, under task
`8c57d37e-831d-4101-8af0-5c25a6aa65da` on PR13 /
copilot/improve-short-query-search-yet-again. Old UI still Queued; not stopped.
[Supersession marker](https://github.com/ManuelKismet/interaction-qa-flow/pull/13#issuecomment-6032732442).
Any late completion, commit, patch, or Actions artifact attributable to that OLD
attempt is audit-only: **DO NOT APPLY, MERGE OR DEPLOY**. Retain history; do not
reset/delete its commits. PR13 head movement is not acceptance evidence. Only
registered replacement provenance may enter review. Previously accepted runtime
105a528 and unchanged-applied rejected reviewe9e3cc8 are not invalidated.
Record replacement PR/branch/run/artifact IDs when published; do not invent them.

DEV UNCHANGED: reviewed105a528/backendreview105a528100%, schema0014,
Hostingrelease1791323636722000/version4eb839685c6f21c7. No new deployment,
merge or hosted migration. Retain105a528 rollback and additive schema/private
records. Fake-provider quality, personal-import authenticated E2E/F04/F08/F09
remain unverified. Organisation improvements remain DEFERRED. No production,
IAM/AppCheck weakening, secret disclosure, paid-provider activation, automatic
local-content upload or database downgrade/purge. Monitoring remains cancelled;
no automation created. Await ONLY replacement artifact, avoid retry loops.

## Latest independent review — Ask parity correction pending, 2026-10-06

Copilot Ask-parity run37540651764 completed success at22:41:25Z.
Completion6026770454 published artifact
`6de32ac7e97148eb4022ddc080c1f64387586749`, authored
`607bcce3ea61e0fb9c9392c2cd9c0b2bbbc847c3`, base105a528.
Its unified-knowledge-ask-parity-20261007.patch was applied UNCHANGED with git am
in /workspaces/intqaflow-unified-search-dev-20261006, producing exact complete
review source `e9e3cc804e8dbb45033e637304fd34c21cd14b2f`.
Published to fix/unified-search-dev-20261006 and GitHub readback verified.
Seven Flutter files only; backend/schema unchanged. Clean isolated tree and
main worktree's four dirty documentation files preserved.

| Independent check on e9e3cc8 | Executed result |
|---|---|
| Python compile / Alembic heads | exit0 / single0014 |
| Full backend |111 passed,4 skipped,10 warnings,40.13s,exit0|
| Fresh separate real PostgreSQL16 |4 passed,3.92s,exit0|
| Isolated migration round-trip |0014→0013→0014 PASS,exit0|
| Full Flutter |173 passed,1 failed,about91s,exit1|
| Analyzer |0 errors,1 warning,13 infos,13.3s,exit1|
| Configured DEV release build |PASS,49.9s,exit0|
| Non-mutating Dart format check |7 changed files would be formatted,exit1; source untouched|

Rollout BLOCKED by unused question_models import warning in
ask_suggestions_controller.dart:11:8 and new AskPage widget harness failure:
“No Material widget found” (bare AskPage route, pumpAndSettle line168).
This is a test harness failure, not proof production lacks Material.
Actual Ask-specific privacy/submission, stale account/organisation, partial
failure/retry, local answer/body-vs-semantic, scoped navigation/dedup and
mobile/keyboard acceptance coverage is also incomplete; do not mark it passed.

[ONE consolidated incremental correction](https://github.com/ManuelKismet/interaction-qa-flow/pull/13#issuecomment-6026870639)
requires exact complete basee9e3cc804e8dbb45033e637304fd34c21cd14b2f, not
carrier6de32ac or a reconstructed old patch tree. Copilot owns app/tests.
Await its one corrected artifact; no competing requests or further rollout.

DEV is UNCHANGED: backendintqaflow-dev-api-review105a528 at100%,
schema0014, Hostingrelease1791323636722000/version4eb839685c6f21c7.
Both-origin current bundle hashes remain the105a528 snapshot below.
For any next rollout, retain reviewed105a528 + Hosting4eb839685c6f21c7 as
rollback; retain additive0014/private data, never live downgrade/purge.
No Cloud Run stage, traffic switch, Hosting publish or hosted migration executed
for rejected e9e3cc8. Fake-provider quality, authenticated personal-import
E2E/F04/F08/F09 and live search/navigation gap remain separate; organisation
owner/delegated-admin/Teams/join-request changes remain deferred.

Logs/exit receipts retained privately under
/home/vscode/.local/share/intqaflow/ask-validation-e9e3cc8.
Codespace restarted through existing GitHub UI for validation.
Temporary PostgreSQL stopped and files retained; no proxy used.
GitHub UI confirmed “Codespace bookish happiness stopped”. Validation runners
completed; no temporary database/proxy left active. Files/evidence retained.
Recurring monitoring remains cancelled by founder; do not recreate.

## Active follow-up — Ask & search unified parity, founder-authorised 2026-10-06

Founder reports the deployed search works in their manual test. Scope/account,
queries and source-navigation coverage were not specified, so record this as
founder-reported success, not Codex-executed authenticated/multi-source E2E.
The earlier cloud-browser search smoke remains separately inconclusive.

Static review on exact deployed105a528 confirmed organisation AskPage uses
organisation-only questionsRepository search and related-question rows with
department/team/answer/match labels. It does not yet share the unified
Local/Private/Group/Organisation search coverage and explicit origin labels.

Founder explicitly approved extending the same unified search to Ask & search.
[ONE targeted Copilot handoff](https://github.com/ManuelKismet/interaction-qa-flow/pull/13#issuecomment-6026591268)
uses complete base `105a528f19b2383545b5cfae17197439ce065279` on
`fix/unified-search-dev-20261006`, not the older patch-carrier head.
Apply only its future incremental patch unchanged; never reconstruct old patches.

Preserve existing form/submission/selectors and Ask as new question. Accessible
Local/Private/Group/Organisation results get actual source names and assigned
department/team labels, useful snippets, shared ranking/query lifecycle and
correct source navigation. A local/private match never blocks deliberate new
organisation submission and never copies/uploads private/local content
automatically. Existing access boundaries, membership checks, no-org personal
usage, query/identity freshness, retry/partial failures and original retention
remain mandatory. Shared reusable logic and meaningful actual AskPage/widget
regressions required; no unnecessary schema or deferred organisation work.

Copilot owns app/tests; Codex independently reviews/applies/tests in the existing
isolated worktree and manages DEV-only rollout after passing gates. No new patch
is independently tested or deployed at this handoff. Current runtime remains
review105a528/schema0014/Hosting4eb839685c6f21c7 as recorded below.
Codespace remains stopped while awaiting artifact. Recurring monitoring remains
cancelled; do not recreate. Real-provider quality, authenticated personal-import
E2E/F04/F08/F09 and deferred organisation work remain separate.

## Latest deployed snapshot — DEV search rollout verified, 2026-10-06

Complete reviewed source `105a528f19b2383545b5cfae17197439ce065279` on
`fix/unified-search-dev-20261006` is deployed to **intqaflow-dev only**.
Artifact8efaf683, authored9698850d, was applied unchanged to98ca4f6.
Source push and GitHub readback matched the full SHA.

| Independent check on105a528 | Executed result |
|---|---|
| Compile / Alembic head | PASS / single0014 |
| Backend full suite |111 passed,4 PostgreSQL skips,10 warnings,35.09s,exit0|
| Fresh isolated PostgreSQL16 |4 passed,1.35s,exit0|
| Isolated migration cycle |0014→0013→0014 PASS,exit0|
| Full Flutter suite |169 passed,about67s,exit0|
| Analyzer |0 errors,0 warnings,13 infos,18.3s,exit1 from infos|
| Configured DEV release build |PASS,62.3s,exit0|

The initial reused PostgreSQL test database run was3PASS1FAIL due to duplicate
fixed-UID fixture records left by the earlier run; no hosted data was touched.
A new separate disposable database passed all four tests. Both logs retained.
Use a fresh empty test DB for these schema fixtures, separate from migrated
public tables, rather than assuming schema cleanup removes public fixtures.

### Verified runtime and artifacts

- Backend `intqaflow-dev-api-review105a528`,100% traffic,health/ready200.
  Staged at zero traffic first. Runtime spec identical except image;
  service identity,SQL/VPC attachments,env/security settings preserved.
- Backend image digest:
  `31d1eb5487847352ff25e9b10de2711e8afca3a1f30d758f26cf28adee61be34`.
- Additive Cloud SQL0013→0014 completed. Runtime table/column privileges,
  vector/pg_trgm extensions and all three exact trigram indexes verified.
  Before/after counts identical:questions5,answers5,groups6,memberships9,
  group entries3,personal items0. No new grants,live downgrade or purge.
- Hosting release `1791323636722000`,version `4eb839685c6f21c7`,36 files.
- Both https://intqaflow-dev.web.app/ and https://intqaflow-dev.firebaseapp.com/
  matched exact tested index/bootstrap/main bytes:
  main4497789 bytes/SHA256
  `78a8f550a70e24dea13bdbd64bed183356c88035914bc4649ddedb29879ff2c1`;
  index1531 bytes/`a06d2eb52561601b37b68f0fc8eb22498200b5eea6b8c828347f90ff74611858`;
  bootstrap9805 bytes/`0cec5f2734f9e60c05d76b120829c68acbc55f9e62387c91223181b5851e7d67`.
- Live unauthenticated personal search rejected401.
- Live guest local save and Saved Q&A listing verified with two synthetic
  local-only smoke records titled “DEV search smoke105a528”. No import/account
  action or automatic local upload performed. Records retained,not purged.
  Live query/result/navigation smoke remains inconclusive because cloud-browser
  Flutter text-input/focus automation did not reliably trigger query changes.
  Do not count that search smoke as passed or infer a confirmed app defect.
  The independent answer-ranking/Local-Private/no-upload widget regressions passed.

### Rollback, remaining gaps and cleanup

Rollback traffic to `intqaflow-dev-api-reviewaafc112` and Hosting to
version `49afc5b14f53f3b0` (release1791307395456000).
**Retain additive schema0014 and private data**; never live DB downgrade/purge.
The previous reviewed revision/Hosting version remain the rollback targets.

Meaningful semantic-provider quality remains unverified in fake-provider DEV.
Authenticated personal-import/edit/multi-device E2E and F04/F08/F09 remain open.
Live guest query/result/navigation smoke needs ordinary browser validation.
Organisation owner/delegated-admin/Teams/join-request improvements remain
explicitly deferred. No production,merge,IAM/AppCheck weakening or secret
disclosure performed.

Operational receipts/logs retained privately under
`/home/vscode/.local/share/intqaflow/search-validation-105a528` and
`search-105a528-*.json`. Disposable PostgreSQL stopped; migration proxy
terminated by its finally block. Main worktree's four dirty docs preserved.
Temporary staging tag removal passed (exit0), leaving reviewed105a528 at100%.
Post-cleanup both-origin exact-byte,health/ready and private rejection checks
passed again (exit0). GitHub UI confirmed “Codespace bookish happiness stopped”.
Files/evidence retained; no database/proxy or rollout runner left active.
Recurring monitoring remains cancelled by founder; do not recreate.

## Current state (original handoff history)

Founder reviewed the seven search improvements and authorised implementation.
Copilot handoff was published as [PR 13 comment](https://github.com/ManuelKismet/interaction-qa-flow/pull/13#issuecomment-6023733274).
Implementation, independent validation and development rollout are pending;
this handoff is not evidence that the feature is complete.

Exact implementation baseline:
`fix/saved-qa-dev-20261006` at
`aafc112fbbf220eda1077895334dc16b4930eeab`.
Use the complete published source, not the older PR patch-carrier head.
Copilot owns app/backend/test changes; Codex independently reviews, validates,
configures and deploys to development within the authorised workflow.

## Accepted scope

- One existing Search Knowledge field searches accessible local, private account,
  Group and organisation Knowledge, with department/team access governed by
  existing permissions. Personal/group access needs no organisation.
- Clear source badges, question results and answer snippets, visible beneath the
  field while typing on both Knowledge views. Preserve placement and Saved Q&A.
- Keyword/prefix and bounded typo matching, plus meaningful semantic retrieval
  for backend content through the configurable provider. Rank exact/strong text
  matches before weaker semantic results and keep lexical fallback.
- Enforce scope permissions before retrieval/ranking/snippets/counts; no private
  data added to shared/global semantic indexes. Group membership/lifecycle and
  organisation policies remain authoritative.
- Local item content remains on-device unless explicitly imported. Search never
  uploads local content or silently imports, mutates or removes originals.
- Debounced bounded requests; stale query/account responses ignored; sign-out and
  identity changes clear private results. Accessible navigation opens the source.
- Loading, empty, retry and partial-scope failure states preserve the query and
  available results. Empty queries do not trigger unbounded remote listing.

## Review gates and next steps

1. Confirm Copilot's published implementation SHA and artifact/base provenance.
   Apply unchanged code patches only against the stated baseline.
2. Review permissions across lexical/semantic branches and source labels.
   Check answer indexing, per-scope isolation, query bounds and local privacy.
3. Independently run compilation/analyzer first, meaningful backend/Flutter
   suites, isolated PostgreSQL retrieval/permission checks and a release build.
   Record actual tests versus unavailable tools or live provider checks.
4. If meaningful provider credentials are unavailable, keep that live validation
   explicitly pending. Fake embeddings cannot establish semantic quality.
5. Only after review/checks, perform the authorised development rollout and
   verify runtime/source/Hosting artifacts and changed browser behavior.
   No production deployment, merge, purge or security weakening is authorised.
6. Update this checkpoint with source/artifacts, results, runtime/schema changes,
   rollback and remaining acceptance gaps.

The earlier live authenticated personal import/edit/multi-device acceptance gap
remains outstanding. Do not close it or F04/F08/F09 just because search tests or
deployment succeed. See [previous rollout checkpoint](README.md) and
[workflow lessons](personal-workspace-workflow-lessons-2026-10-06.md).

## Independent first-patch review — 2026-10-06

Published artifact `9bc571daa9c3348acfc322e57f84d9566acd930d` contains
`unified-knowledge-search-20261006.patch`, authored commit
`04b09c259e8d5bed408b8ebf07268af3e5b218ef`, declaring the correct
`aafc112` base. It has NOT been applied or deployed. This review was static;
no runtime test pass is claimed.

Blockers were consolidated into
[Copilot correction request](https://github.com/ManuelKismet/interaction-qa-flow/pull/13#issuecomment-6024434062):

- Duplicate Alembic revision 0013/down_revision0012 conflicts with the existing
  personal-workspace schema. Correct to a unique next revision based on 0013.
- Backend personal/group semantic retrieval missing; preserve private scoped
  indexes, local content privacy and lexical fallback.
- Results grouped by origin without common relevance ranking; source badges,
  organisation/department/team names and useful local/account answer previews missing.
- Local/group result navigation incomplete; query/account freshness and full
  personal item coverage need validation.
- Remote UI, scoped semantic permission, PostgreSQL typo and failure/isolation
  regressions insufficiently covered.
- New answer embedding input requires lifecycle invalidation across governance
  and other accepted/verified answer transitions.

Because this patch is unapplied, requested one corrected consolidated patch
against the exact original complete baseline. Resume by verifying the new
authored/artifact commits and reviewing those blockers before running full
independent checks or changing development.

Founder explicitly instructed search only, then dev rollout after confirmation
it works. [Organisation improvements](organisation-improvements-deferred-2026-10-06.md)
are recorded but must not be implemented or assigned to Copilot until the
founder gives the later start instruction.

## Corrected patch applied and independently tested — 2026-10-06

Artifact `7eca2357ecc774508bf827bd694f73f531177925` was applied unchanged
in a new isolated worktree, producing
`44422230f7435e503b82e96586ff6ec5314bdab1` on
`fix/unified-search-dev-20261006`. Source branch is pushed and GitHub readback
verified. Deployed source remains `aafc112`; **no search deployment yet**.

| Check | Executed result |
|---|---|
| Python compileall | Pass |
| Alembic heads | Single head 0014 |
| Backend suite | 110 passed, 1 failed, 4 PostgreSQL tests skipped without URL; 10 warnings, 26.32 s, exit 1 |
| Flutter dependencies | Pass |
| Flutter analysis | 2 errors, 3 warnings, 11 informational notices; 23.1 s, exit 1 |
| Fresh isolated PostgreSQL migration | Upgrade through 0014 passed |
| Actual PostgreSQL search/concurrency | 2 passed, 1 failed; 0.87 s, exit 1 |
| Isolated migration round-trip | 0014 → 0013 → 0014 passed, exit 0 |
| Full Flutter suite / release build | Not run: compile errors block these gates |

Failures and remaining matching issues were consolidated into
[Copilot correction request](https://github.com/ManuelKismet/interaction-qa-flow/pull/13#issuecomment-6025264339):

- Nullable membership status access and nonexistent personal reload method in
  guest_workspace_page.dart; redundant assertions and unused savedItems warnings.
- Account search test incorrectly expects one record despite two legitimate
  same-owner sentinel records. Preserve owner isolation while correcting the assertion.
- PostgreSQL semantic fixture fails because GuestGroup is never added before
  flushing/using its ID, producing null group_id.
- Personal backend typo coverage, strong answer/body lexical priority against
  semantic-only matches, compact Private/Local badges and remote widget regressions
  still require completion.

Requested a targeted incremental patch against the exact pushed `44422230`
source, not another reconstructed full feature patch. Next step is review/apply
that correction, repeat independent gates, then DEV-only rollout if passing.
No automatic claim of test completion or meaningful live semantic quality.

The database was disposable PostgreSQL16 on loopback port55442, not Cloud SQL.
Its server was stopped after the isolated migration round-trip; files retained
for resumable checks. Logs are private under /tmp/intqaflow-search-*.log in the
Codespace. Main worktree's four pre-existing dirty docs were preserved.
Organisation improvements remain explicitly deferred until founder instruction.

Cleanup confirmed: Codespace bookish happiness stopped after review source and
checkpoint were pushed. Restart only for the next independent correction check.


## Incremental correction independently validated — 2026-10-06

Copilot artifact `6c69662936102ee6a47fedaef73b102475d7ca68`, authored
`d9d2a506298787e21ea41296004b9273914ba1e3`, contains
`unified-knowledge-search-corrections-20261006.patch` with base `44422230`.
Applied unchanged in the isolated review worktree, producing exact source
`047d4131f2542a02762c3fdc9822dd52ce59f43d`; pushed on
`fix/unified-search-dev-20261006` and GitHub branch readback confirmed.

Executed independent checks:

- Python compileall passed; Alembic single head 0014.
- Backend: 111 passed, 4 PostgreSQL skips, 10 warnings, 27.33s.
- Flutter analyzer: zero errors/warnings, 13 informational notices, 19.9s;
  exit 1 due to infos. These are not a zero-exit result.
- Full Flutter suite: 167 passed, 1 failed, about 77s, exit 1. New stale
  account-result and partial-source retry widget regressions passed.
- Fresh disposable PostgreSQL16 upgraded through 0014. Search, personal
  concurrency and Group lock-order suites: 4 passed, 0.44s, exit 0.
- Isolated 0014→0013→0014 round-trip passed, exit 0. No hosted DB changes.
- Release compilation started separately; result pending at this checkpoint.

Single failing Flutter scenario: `guest_interact_widget_test.dart:87`,
“Saved Q&A search edits and removes local entries and returns to the form”,
expects “On this device” in the search result, while approved badge is now
“Local”. Detailed local storage status must remain independently asserted.
[One targeted test correction](https://github.com/ManuelKismet/interaction-qa-flow/pull/13#issuecomment-6025524398)
was sent against exact `047d413`; no competing requests. Next step: apply that
incremental correction unchanged, rerun affected/full frontend gates and
record release result before authorised DEV rollout.

DEV remains source `aafc112`, backend `reviewaafc112`, schema0013 and
Hosting1791307395456000/version49afc5b14f53f3b0. No deployment, merge,
production, security change or automatic local upload performed.
Meaningful live semantic-provider quality and authenticated personal-import
E2E remain unverified; organisation improvements remain deferred.

Database files are retained at
`/home/vscode/.local/share/intqaflow/search-review-20261006`, loopback55442.
Server stopped after isolated checks. Validation evidence is copied to
`/home/vscode/.local/share/intqaflow/search-validation-047d413`.
Main worktree's four pre-existing dirty docs preserved. Recurring monitoring
was cancelled by the founder; do not recreate it.

Release compilation completed: `flutter build web --release` passed, exit0,
99.3s compilation on exact `047d413`. This was an independent generic
release compile, not the configured Firebase deployment bundle. Deployment
remains gated on the one full-suite assertion failure above.

Final logs and exit files copied to retained validation directory. GitHub UI
confirmed Codespace bookish happiness stopped after build completion.


## Final badge-test retest and remaining application corrections — 2026-10-06

Artifact `ddb0360f40e81cce16adfdf6d19dca3eb4df179f`, authored
`bbe7349b3a9c169a2bb77519bf423f0c6fe4a56e`, was applied unchanged to047d413,
producing `98ca4f612a4334cf4d95ee10ff294be0a000903d` on the same isolated
worktree/branch. Source pushed and GitHub branch readback verified.

- Full Flutter:167 passed,1 failed,about70s,exit1.
- Analyzer:0errors/0warnings/13infos,16.9s,exit1 from infos.
- App/backend code unchanged by this one-line test patch; prior111 backend
  pass, isolated PostgreSQL4pass/migration cycle, and release compilation
  apply to the unchanged app tree, not newly executed checks here.

The compact Local Chip assertion still fails at
`guest_interact_widget_test.dart:87` (zero matching Chips). Static review
confirmed an APPLICATION contract gap: local/loaded-account result source is
still constructed as origin plus storage status, and the renderer uses that
whole string as its Chip label. Separate compact Local/Private badges from
storage status, which already has its own field. Also local `_localRelevance`
still scores all answer/body-only matches0.9, below semantic-only remote1.0;
backend scoring was corrected but the on-device path was missed.

[One consolidated targeted correction](https://github.com/ManuelKismet/interaction-qa-flow/pull/13#issuecomment-6025761236)
requests application fixes plus meaningful Local/Private and cross-source
answer-ranking regressions against exact98ca4f6, retaining all navigation,
edit/remove/local-retention checks. Do not merely suppress the test or broaden
badge text contract. Next: apply Copilot incremental correction unchanged,
repeat independent relevant gates, then DEV rollout only when passing.

No cloud deployment/migration/traffic/Hosting/security changes made in this
retest. DEV remains aafc112/schema0013. Organisation improvements and live
semantic-provider/authenticated-import acceptance gaps remain deferred or
unverified as previously recorded. Validation evidence retained under
`/home/vscode/.local/share/intqaflow/search-validation-98ca4f6`.
Main worktree's four dirty docs remain preserved; recurring monitoring remains
cancelled. Codespace cleanup confirmation will follow.

Cleanup confirmed: GitHub UI displayed “Codespace bookish happiness stopped”.
No temporary database/proxy was started during this test-only retest.
