# Batch 3 independent review — 2026-10-08

## Batch 3 DEV frontend rollout — 2026-10-08 (current)

**Reviewed batch3 frontend source `5a2dd26410a428b6a0b516efe53afc37d89362b7` is deployed to DEV.** Repository tree`46e373deec7f3351dd307d5b68d3e7042d75122b`, app subtree`1a3642d9fde6dd377300c056966712174dcae89a`. Includes batches1+2 and independently reviewed batch3 organisation/guest/personal editor, scoped clipboard safety and uncertain-delete/Undo recovery. Three immutable mailbox handoffs independently match exact bytes/SHA/tree. No repository merge or production change.

Independent final gates: Flutter298PASS exit0 (38s), locked offline pubgetPASS, format2correctionfiles0changes, analyzer0errors0warnings12baselineinfos(exit1 solelyinfos). ConfiguredDEVreleasePASS using existing publicDEVdefines and AUTH_DIAGNOSTICS=true/no-wasm-dry-run/pwa-strategy=none in isolated Codespace worktree; runner54.5s. No appsource changes after validation. Backend unchanged; existing158backend/PG receipt retained, not new rerun.

Hosting **release`1791473511974000` / version`f2b2a3b33b4acd94`**,36files, deploy exit0. BOTH origins (`intqaflow-dev.firebaseapp.com`, `intqaflow-dev.web.app`) served exact reviewed build bytes for index/bootstrap/main. Main.dart.js4645494bytes SHA256`90e2dfda9ebbbc777b89d70d249e3ba30402291826c4592325c7d52b7dc995cd`; index1531bytes SHA`a06d2eb52561601b37b68f0fc8eb22498200b5eea6b8c828347f90ff74611858`; bootstrap9805bytes SHA`0cec5f2734f9e60c05d76b120829c68acbc55f9e62387c91223181b5851e7d67`.

API **`intqaflow-dev-api-review80f421d`100%traffic unchanged**, public health200/ready200. No API deployment, DB/proxy/schema/migration/IAM/serviceidentity/credential/firewall/access change. Hosting rollback retained **prior version`fd994b8bd5fe8b22` / release`1791460845367000`**, no rollback triggered; leave additive schema/account data intact.

Codespace **bookish happiness STOPPED**, explicitly confirmed GitHub toast and Last used (no Active). Isolated source`/workspaces/intqaflow-batch3-independent-20261008`, receipts`/workspaces/batch3-independent-receipts-20261008` (build-receipt.json/publication-verified.json/logs). Root four pre-existing dirty docs preserved. No ongoing test/build/deploy worker or DB started.

**Still OPEN:** IP19guest/nonmember reload returns to list (no routing/persistence decision implemented); hosted authenticated personal/organisation/Groups and physical/device/accessibility acceptance (earlier cloud-browser auth issue, founder paused). Hosted-file and API verification are not an authenticated UI acceptance pass. No new hosted guest scenario matrix executed after this rollout. Batch4Groupcollaboration/fullcrossroleacceptance not started. See `interact-parity-batch3-independent-review-20261008.md` for independent gates/findings and source receipts. Next remaining product work is guest reload decision and batch4; authenticated checks remain founder/manual pending as previously agreed.

Status: **FINAL CORRECTED SOURCE VALIDATED AND DEPLOYED TO DEV (scoped acceptance)**. Guest reload decision and hosted authenticated acceptance remain OPEN. Earlier review entries below are historical; current outcome follows.

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


## Review-fix delivery independently validated; uncertain-delete follow-up authorised

Founder authorised "Action next steps and uncertainty edge case" at15:35BST on2026-10-08.

- Review-fix source `1e2947ed4fe647c074e32c7ff313ad988b57564e`; artifact `8728b802654e8507aabb63b9c38625c678ac8626`.
- Original incremental mailbox34935UTF8bytes SHA256`c6f9c648b4cdf662bf701868387865bc4ee23e74acb6719b999d4a10326b7b94` independently matches.
- Clean proof checkout at exact05ec538 applies2commits unchanged and reproduces repository tree`a87b5d94e80993e58e2d0514b7f2c4779795ee42` and app subtree`56768f0d721cc43b75363450478ba0ae920e61ea`.
- Independent locked offline pubget exit0; fullFlutter --no-pub -r expanded **290PASS exit0** elapsed35s; 2changedDartfiles format0changes exit0; analyze --no-pub exit1solely12baselineinfos,0errors0warnings. Logs in isolated scratch review-fix checkout, not Codespace. No backend changes or backend rerun.
- Local checkout preparation initially overlapped a still-running worktree checkout, causing an index-lock/aborted git-am setup failure. After checkout completed, own failed am was aborted and clean unchanged am succeeded; this was local tooling, not a delivered patch defect. First --no-pub test attempt before dependency setup was not a source test failure; locked pubget then actual full suite passed.

**Open recovery defect, actioned:** a queued failed DELETE that did succeed remotely can be replaced by Undo with update because stale personalItems still contains the old record. It retries an absent record indefinitely instead of recreating. Copilot's own receipt explicitly admits this edge, and independent source inspection confirms the decision path. No live hosted user deletion performed.

Same task received one follow-up requiring authoritative same-UID reconciliation and existing source-key idempotency, preserving pending Undo on read failure, recreate only when missing, no duplicate/repeated delete, no blind overwrite of newer changed/recreated remote record (explicit conflict required), UID/generation guards for delayed reads/writes, and meaningful404/409 fakes/negative-control coverage. New mailbox must be incremental ONLY from exact8728b802 through new source, named interact-parity-batch3-uncertain-delete-fix-20261008.patch, with separate artifact commit and unchanged clean git-am proof. Original two mailboxes remain immutable.

Clipboard fix/new10tests are retained. ConfiguredDEV release is intentionally deferred to coherent corrected source. Guest reload/product decision and hosted authenticated acceptance remain OPEN. No merge/deployment/schema/production/security access change; batches1+2 remain deployed80f421d.


## Uncertain-delete recovery independently validated and configured build passed

- Final source `5a2dd26410a428b6a0b516efe53afc37d89362b7`; artifact `e8ea0b47fcf8eb066356ab7e88bb8eecddab38ef`; incremental base `8728b802654e8507aabb63b9c38625c678ac8626`.
- Mailbox29866bytes SHA256`1b5985f5d521f695eb7f53c1c959055ff2146172e1158081f5f91dd2d75a7118`. Independent unchanged git-am2commits matches repository tree`46e373deec7f3351dd307d5b68d3e7042d75122b` and app subtree`1a3642d9fde6dd377300c056966712174dcae89a`.
- Independent full Flutter **298PASS exit0**, elapsed38s. Locked offline pubget exit0, format2files0changes exit0, analyzer0errors0warnings12baselineinfos(exit1). No backend changes; no backend/PostgreSQL rerun.
- Source review: recovery records attempted DELETE identity/revision, fetches same-UID authoritative state, idempotently creates missing item, revision-checks unchanged item, accepts identical replay without duplicate, and exposes explicit conflict for newer changed/recreated content. Failed read/write preserves pending Undo; UID/generation guards retained. Same-content unchanged-record restore still makes one revision-checked update; it is redundant but does not bypass conflict protection. No further application edit required for this detail.
- Configured DEV build independently executed in resumed bookish-happiness Codespace, isolated worktree`/workspaces/intqaflow-batch3-independent-20261008` at exact5a2dd264, receipts`/workspaces/batch3-independent-receipts-20261008`. Fetch/checkout/locked-offline-pubget/configured-release all exit0, runner54.5s.
- Build command: existing officialFlutter path, analytics suppressed, build web --release --no-pub --no-wasm-dry-run --pwa-strategy=none; existing `/workspaces/batch2-independent-receipts-20261008/dev-public-defines.json` plus AUTH_DIAGNOSTICS=true. Config nonempty/DEV-target assertions passed; no credential values printed, new credentials requested or access changed. Config SHA256`3e2c32a1e918d5b9e1b635d9c6ca91799ec3184911509288395b3f5b0d613f76`.
- Build hashes: index.html1531bytes SHA`a06d2eb52561601b37b68f0fc8eb22498200b5eea6b8c828347f90ff74611858`; bootstrap9805bytes SHA`0cec5f2734f9e60c05d76b120829c68acbc55f9e62387c91223181b5851e7d67`; main.dart.js4645494bytes SHA`90e2dfda9ebbbc777b89d70d249e3ba30402291826c4592325c7d52b7dc995cd`.
- Original Codespace root four existing dirty documentation files confirmed unchanged; no overwrite/rebase/merge.
- Founder reiterated next steps after source/build gate pass; DEV FRONTEND publication now authorised. Backend80f421d, DB/schema and production must remain unchanged. Existing Hosting deploy script was inspected and explicitly targets sites/intqaflow-dev. **Publication has not yet been executed** at this checkpoint: browser terminal input became unresponsive; one safe Codespace tab reload reconnect underway. No deployment success claimed until release and served-byte verification.
- Guest reload route decision and hosted authenticated acceptance remain OPEN; do not interpret build/tests as full parity or live authenticated acceptance.
