# Unified Knowledge search workflow checkpoint — 2026-10-06

## Current state

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
