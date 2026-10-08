# Interact parity batch 4 — independent review, 2026-10-08

Review requested by founder through “Action”, resumed after interruption. Exact pushed-commit review replaces the oversized mailbox route by explicit founder authorisation. No deployment or merge is part of this review.

## Exact provenance

Complete accepted batch 3 base: `5a2dd26410a428b6a0b516efe53afc37d89362b7`.
Initially reviewed batch 4 HEAD: `6ab3b38c803f2e1dc1f13640512416ac7c1727e8`; repository tree `7f5dab3c2fa7c013fb6edcb94e4f261d3c3c46db`, Flutter subtree `1ab43736a7409cb9240b121315cb940548aa3c12`.
Corrected final HEAD: `6c97993c0de10f5199a26f3dda09697560d7e707`; repository tree `57c8260b1e96b683689d477576b5c678b1b1285e`, Flutter subtree `9528f2b5760a27996b46d35cc0bd439fff066f5d`.
Correction implementation commit: `bdd0c76ada2363bebeb597334f4e2983fe89dedc`; later final receipt commit changes docs only. Same task `49641b6c-45e3-447f-9db4-2675b4a3fdde`, same `copilot/fixinteract-parity-batch4-edit-shared-copy` branch. Original history and batches 1–3 retained.

## Independent finding and correction

The original editor's `_readAuthorized` searched the empty-query entry list and treated absence as loss of access. Backend list defaults/maxes at 50 (Group capacity 200), ordered by latest update. An older copy found by targeted search, or an open copy pushed down by other activity, could therefore become falsely unavailable and lose its draft.

One targeted correction request was sent to the same Copilot task. The corrected editor calls the existing exact Group/entry GET through `GuestGroupRepository.getEntry`, after Group capability read, checks returned ID and current UID/generation, and retains role/authorship, registration, denial, revision conflict and uncertain-save guards. Static diff confirms only this production correction; backend, schema, tests and dependency locks are unchanged from the independently tested prior head. Six new widgets and three actual Dio repository tests retain earlier coverage and cover older entry/cutoff reconciliation/export, exact 403/404 and delayed signout reads.

The broader static review checked editor reuse, explicit save destination, private/local original independence, retained participant IDs and answer-owned branches, expected-revision checks, uncertain applied/unapplied reconciliation, nested dialogs and saved-only exports. Duplicate authorisation checks around asynchronous output are intentional safety boundaries; no unrelated refactor requested.

## Initial independently executed Codespace checks

Codespace `bookish-happiness-w974vpwgq7j3g95v`; detached checkout `/workspaces/intqaflow-batch4-independent-20261008` at exact 6ab3b38. Receipts `/workspaces/batch4-independent-receipts-20261008`; existing root checkout and four dirty documentation files preserved.

Official Flutter 3.41.4 revision ff37bef603 / Dart 3.11.1, analytics suppressed. Locked offline pubget exit0; official five-file format exit0/zero changes; analyze exit1 only for 12 baseline infos, zero errors/warnings. Full `flutter test --no-pub --reporter expanded`: 353 passed, exit0, 223.7 seconds wall time.

Fresh external virtual environment from unchanged `backend/requirements.lock`; Ruff two new test files exit0. Fresh disposable loopback PostgreSQL16.15, vector0.8.6, port55438/database batch4_independent; BOTH PostgreSQL test URLs set. Full `pytest -q -ra`: 198 passed, 10 existing warnings, zero skips, exit0 (70.16 seconds pytest / 80.0 wall). Actual PostgreSQL concurrency/permission tests executed, including lock-wait observation. Disposable database stopped exit0; no hosted migration/data change.

Configured DEV release exit0, 54.1 seconds, using existing public DEV defines (SHA256 `3e2c32a1e918d5b9e1b635d9c6ca91799ec3184911509288395b3f5b0d613f76`), AUTH_DIAGNOSTICS=true, --no-wasm-dry-run --pwa-strategy=none. Initial main.dart.js 4,677,478 bytes/SHA256 `169ee1efcd7ad35fdb5ac89bcb516fa79ce486f2c7f353be1ea11741955f16df`. This initial build is historical validation, not the corrected release.

## Historical environment and mailbox boundary

Original 8db08bd accidentally tracked 3,974 environment/log paths; 9fa5caa removed them. Final tree contains no batch4-backend or virtual environment. Reviewed the ten first-party logs/results and pyvenv.cfg using read-only blob inspection; common private-key/token signatures absent in that limited scan. No historical binaries executed. This is not an exhaustive third-party binary secret audit. Copilot's durable full path/hash/size inventory records 155,360,113 blob bytes.

Copilot's unfiltered complete mailbox is 207,578,423 UTF-8 bytes, exceeding GitHub's 100MiB file cap; no misleading filtered/squashed replacement published. Its git-am reproduction proof is Copilot evidence, not independently reproduced here. Founder explicitly authorised exact pushed-commit review; final head/tree pinning is the independent provenance gate.

## Acceptance boundary

Guest/nonmember reload to session list remains accepted IP19; users reopen their sessions. Edit shared copy is explicit, originals independent, no live link. Hosted authenticated personal/organisation/Group checks, physical phone, enlarged text/screen reader and native share/printing remain OPEN. Cloud-browser authentication investigation remains paused. DEV still batch 3 frontend5a2dd264/Hosting f2b2a3b33b4acd94; backend review80f421d unchanged. No deployment/merge/production/IAM/credential/firewall/access change.

## Additional independent lifecycle probe

Copilot disclosed a possible post-disposal dialog cleanup concern from its broader review. An isolated probe outside the source checkout reused the real Group page/editor harness: unmount Group page with its navigator retained at entry, editor and nested-rename-dialog stages, plus unmount the whole navigator with a nested editor dialog. All four passed, exit0, 15.1 seconds wall/7 seconds test time; no framework exception, surviving dialog or write. This resolves those reproduced scenarios, not all possible device lifecycle interleavings. Probe and log remain in Codespace receipts; application source was not modified.

## Corrected final independent acceptance

Detached corrected checkout `/workspaces/intqaflow-batch4-corrected-independent-20261008`, pinned exact6c97993, repository57c8260b and app9528f2b5 verified before and after. Receipts in `/workspaces/batch4-independent-receipts-20261008/corrected`. Locked offline pubget exit0 (1.7s); format six touched Dart files exit0/zero changes (0.4s); analyze exit1 only for 12 baseline infos/zero errors/warnings (11.9s). Coherent full Flutter suite **362 passed**, zero skips, exit0 (178.3s wall/166s tests). No test weakening or warning suppression. Existing five repository tests retained, nine new tests added overall.

Configured DEV release **exit0**, 46.8s wall/46.4s compiler, same verified DEV defines and command as above. Final bytes/SHA256:
- index.html: 1,531 / `a06d2eb52561601b37b68f0fc8eb22498200b5eea6b8c828347f90ff74611858`.
- flutter_bootstrap.js: 9,805 / `0cec5f2734f9e60c05d76b120829c68acbc55f9e62387c91223181b5851e7d67`.
- main.dart.js: 4,677,702 / `8a13ff7e5500360cd5b7b94b314c3ab7f50470576fa045d92a60653d7b36bf7d`.

Backend production/tests/schema and Flutter dependency files are byte-identical to independently validated6ab3b38 (`git diff --exit-code` exit0); the 198 actual PostgreSQL-enabled backend passes above are reused on that explicit unchanged-code basis, not claimed as a fresh corrected-head backend rerun. Both isolated source checkouts clean after checks; original four dirty documentation files preserved.

Independent static review, full automated tests and configured DEV compile **PASS**. Found bounded-list issue fixed. Four additional lifecycle probes pass. Hosted/device/native/accessibility acceptance remains OPEN, and no rollout or merge performed. GitHub UI verified the alert: Codespace “bookish happiness” stopped. Shutdown proof captured; disposable PostgreSQL already stopped.
