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
