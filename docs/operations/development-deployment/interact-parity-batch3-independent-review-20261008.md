# Batch 3 independent review — 2026-10-08

Status: **NOT ACCEPTED / NOT DEPLOYED**. Founder authorised independent next steps at 15:06 BST.

## Verified delivery and provenance

- Copilot task: https://github.com/ManuelKismet/interaction-qa-flow/tasks/d8e47f31-7192-4ddf-af64-1d76a8f64f6e?q=is%3Aopen+author%3A%40me
- Published final source: `04f8adabbb1be25877a640b2f9e420599c9d1560`.
- Published artifact HEAD independently read through GitHub: `05ec5386181fe39b9a2bc5f3a21c2d94e8f7f96d`.
- Complete base: `80f421d1c0ecc907d0d88a8147ccb1f2138fe377`.
- Original mailbox: 226378 bytes, SHA256 `28799e6f7f09ab95ff6d9550ffd7bae607d319a18a98dddc03cc9dba27e22cdc`.
- Independent clean detached worktree at the base: original five commits applied with git am, exit 0. The connector-to-local text wrapper initially appended one trailing newline; removing only that wrapper newline reproduced the exact published byte count and SHA256. No patch hunks were changed.
- Reproduced repository tree `245a6206bf141f20abf62f209a0d0ba33edff34a` and app subtree `320f74e08d8dd2f974aacbe31fe2ca5853feb909` match the delivery.
- Independent scratch worktree: `/workspace/scratch/634b5dd13590/batch3-independent`. This is a local isolated proof checkout, NOT a Codespace run or deployment.

## Independently executed checks

Official existing SDK Flutter3.41.4/revisionff37bef603/Dart3.11.1. Flutter invocations used CI=true FLUTTER_SUPPRESS_ANALYTICS=true and --suppress-analytics.

| Check | Result |
| --- | --- |
| flutter pub get --enforce-lockfile --offline | exit0 |
| Full flutter test -r expanded | **280 passed, exit0**, final elapsed34s; no skipped-test or suppressed-overflow changes made |
| dart format --output=none --set-exit-if-changed on 14 changed Dart files | exit0, 0 changes |
| flutter analyze | exit1 solely for 12 baseline infos, **0 errors / 0 warnings** |
| Backend diff | unchanged; backend/PostgreSQL not rerun |
| Configured DEV release | **PENDING**, defer until corrected source; no default compile represented as hosted configuration proof |

The successful test suite is compatibility evidence, not acceptance of untested races.

## Review findings sent to Copilot

1. **Account-scoped clipboard confirmation guard missing (static review finding).** New `_copySessionJson` captures an account session across a plain showDialog and only checks `confirmed` and `mounted` before copying. It lacks originating UID/generation/session-destination validation or scoped cancellation. This presents a potential stale-account export after a UID/workspace transition. This is a code-path finding, not a claimed live exploit or leaked credential. Require a scoped dialog/action and delayed UID-switch/signout clipboard regression tests; legitimate selected private-account export must remain supported without upload.
2. **Missing targeted pending-delete Undo regression**, explicitly admitted by Copilot. Require queued/in-flight and uncertain/failing-delete cases, correct final item/revision/no duplicate.
3. **Missing targeted UID-change editor regression**, explicitly admitted by Copilot. Require delayed prior-account responses, route callbacks, no prior content or next-UID write.

Same task received one consolidated correction request. It must retain all delivered batch3 work and use the same `copilot/fixinteract-parity-batch3` branch. No competing task, history rewriting, merge or deployment authorised. Correction starts at exact artifact05ec538; original applied mailbox stays immutable. Require incremental `interact-parity-batch3-review-fix-20261008.patch` from05ec538 through new source only, separate later artifact commit, original git-am tree proof and receipts.

## Explicit remaining decisions / boundaries

- IP19 guest and registered-non-member reload returns to the session list: OPEN, not full guest routing parity. No auth/router redesign or remembered session marker approved yet.
- Existing organisation archive is final (no server reopen/restore); Add back creates a new empty participant rather than identity restoration. Review found these consistent with current backend semantics; no new backend semantics introduced.
- Session-to-template is explicit organisation-wide publication of question structure; confirmation states destination and answers/names are stripped. Sessions remain private by default. Shared-only template participant-slot reduction is documented as existing server behaviour, not identical local parity.
- Hosted authenticated personal/organisation/Groups/device acceptance remains OPEN due earlier cloud-browser auth blocker. Do not retry credentials or claim it passed.
- Batches1+2 remain deployed on DEV at80f421d; production/schema/IAM/credential/firewall unchanged. Codespace remains stopped; none started for these local checks.
