# Combined guest/report Codespace verification — 3 October 2026

User requested Codespace verification before any development deployment. Codex owns configuration and independent verification; Copilot application changes/tests; founder and Codex review acceptance together. Use hosted development Cloud SQL directly. No production work.

Pinned guest source: PR11 a9b37218d1b3649cbc02fef06c38403e0895abb4. Report source: five-file delta from corrected PR8 24862283e8d0d3cd5e2748faafb55637934c537e to PR12 27dfa7998408cf53252078ec8676b51597edf7af. Applied cleanly with git apply --3way to detached checkout /workspaces/intqaflow-verify-combined-20261003. This did not merge, commit or push an application branch.

## Executed results

- Backend full suite: 72 passed in 10.35s (existing synthetic unit-test harness; not hosted PostgreSQL acceptance).
- Flutter dependency resolution: passed.
- Combined full Flutter suite: 52 passed, two test loading/compilation failures in widget_test.dart and guest_group_dialog_test.dart. All four printable report document tests passed.
- Analyzer: one error, one warning, six existing null-aware style infos.
- Configured release web build: FAILED. Used stored development Firebase web and App Check site configuration plus hosted API URL; no credentials or tokens printed or committed.
- Diff whitespace check: passed.
- Separate hosted read-only check: current database intqaflow_dev; Alembic revision0011; all six guest tables present and runtime table privileges detected. No schema/data modifications or new local PostgreSQL database.

## Deployment blocker

PR12 replaces printCurrentPage with openPrintableReport in print_page_web.dart and print_page_stub.dart. PR11 guest_workspace_page.dart:454 still calls printCurrentPage. Analyzer and release compiler reject that undefined call. Preserve guest Report/Print functionality, dedicated authorized Interact HTML reports, participant/answer-owned branches, privacy and existing tests when fixing compatibility. Do not merely remove guest printing or weaken tests.

Copilot fix request successfully posted on PR12: comment5968649163. A subsequent repository read shows Copilot integrated guest PR11 into report candidate e259d2a1c675a4e7462c94576b354c0d2265c43c, but no response to the compatibility-fix request was present at that read. This integration alone is not a demonstrated fix.

## Limits and remaining acceptance

No deployment, release approval, merge, retention deletion, schedule activation, IAM or App Check changes. App Check observation remains unchanged. Browser account linking, identity/cache transitions, complete two-group/organisation acceptance and actual printed PDF pagination remain pending. Retention cleanup remains a separate implementation/configuration gap.

Private sanitized logs in Codespace: /home/vscode/.local/share/intqaflow/combined-20261003-{backend,pub,test,analyze,build}.log and combined-20261003-results.json. Build defines file remains outside source control.
