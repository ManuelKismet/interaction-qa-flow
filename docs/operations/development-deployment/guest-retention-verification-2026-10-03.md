# Guest retention independent review — 3 October 2026

User requested independent review and Codespace verification. Copilot owns application code/tests; Codex owns configuration and independent verification. Hosted development database only; no production changes.

## Pinned sources and integration

Retention source: PR11 commit 477c941f942aa6d4ee364c32e6fe231d5dca4a79. This guest branch does not yet contain the separately verified PR12 report version. Do not deploy PR11 alone as the combined guest/report candidate.

Applied only retention commit 477c941 onto verified guest/report/printing source 1de3e0c81e0d192dea94b2e39346300dae358ce9 in isolated detached Codespace worktree /workspaces/intqaflow-verify-combined-retention-477c941. Cherry-pick applied cleanly, producing local-only c28d694b5b34f128a0bc445e6932cb013170c894. Flutter source diff against 1de3e0c is empty; report document, openPrintableReport and restored printCurrentPage remain intact. No application branch was pushed or merged.

## Review

Cleanup defaults to dry-run, requires explicit --apply, validates batch size 1–500, uses existing expires_at <= cutoff semantics without changing 90-day inactivity policy, and emits aggregate counts only. Each candidate is locked and expiry rechecked before dependent guest rows are removed within a per-group transaction. Normal group access already locks its row; group-list renewal now uses the same lock. Deletion statements address only guest memberships/invitations/entries/revisions/group. Organisation/private sessions and identity/rate-limit records are outside deletion scope.

Tests cover expiry boundary, dry-run, batching, reactivation before recheck, idempotence and rollback. Runbook documents backup/recovery, restricted permissions and separate scheduler review. No code-review blocker identified in this bounded delta. This is not approval to activate hosted deletion/scheduling.

## Independent executed results

- Full backend suite: 75 passed in 10.44s, using existing synthetic unit-test harness.
- Flutter pub get: passed.
- Full Flutter suite: 56 passed, zero failures.
- Analyzer: zero errors/warnings, six existing null-aware style infos; exit 1 solely from those infos.
- Configured development release web build: passed in 44.5s using stored dev Firebase/App Check config and hosted dev API. Secrets/config remain outside source control.
- Diff check passed; isolated checkout clean.
- Actual hosted Cloud SQL dry-run: intqaflow_dev, migration 0011; batch size 1, apply=False; zero eligible/candidate groups, zero deletions. SQL mutation guard rejected any INSERT/UPDATE/DELETE/DDL. No disposable local PostgreSQL database or hosted schema/data change.

## Limits and next step

Hosted dry-run had no expired candidates, so it did not exercise per-candidate PostgreSQL lock/delete paths. Real concurrent PostgreSQL renewal/purge and deletion acceptance are not claimed. Synthetic unit tests validate apply behavior; no hosted apply command was executed.

To make the reviewed result a submitted deployment candidate, integrate this exact retention delta with PR12 source 1de3e0c and compare its tree with local c28d694 before deployment. Browser account linking/conflicts, sign-in/out cache isolation, cross-group/organisation privacy and rendered PDF acceptance remain pending on configured candidate/final dev deployment. Deletion/scheduling remain disabled; no merge, deployment, IAM, Firebase or App Check change.

Sanitized verification logs: /home/vscode/.local/share/intqaflow/retention-477c941-{backend,pub,test,analyze,build}.log; results.json and hosted-dryrun.json with the same prefix.
