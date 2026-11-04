# Guest development configuration verification — 2026-10-03

Scope: hosted IntQAFlow development only. Application code reviewed/tested at PR #11 commit `49bced8ad55c0172804f6f0cc22f50bfa8b8bb1e`. Infrastructure checkpoint branch: `chore/intqaflow-private-dev-isolation`.

## Verified

- Firebase project `intqaflow-dev`: Anonymous provider enabled and saved; Email/Password remains enabled. Automatic anonymous-account cleanup remains off to preserve guest identity continuity.
- Real Firebase anonymous signup succeeded. Firebase Admin verified the returned ID token with project audience `intqaflow-dev` and anonymous sign-in provider. No token was logged. One synthetic anonymous test identity was created.
- Hosted Cloud SQL database `intqaflow_dev` is at Alembic revision `0011`.
- Existing restricted runtime account has SELECT, INSERT, UPDATE and DELETE on all six `guest_*` tables. It cannot CREATE in public schema. No permission changes were required.
- A synthetic guest group and membership were inserted/read through the runtime account in a PostgreSQL transaction and rolled back; no synthetic database rows persisted.
- Backend existing release virtualenv dependencies pass `pip check`; reviewed guest backend suite: **72 passed in 9.95s**. Existing unit-test fixtures are distinct from the live hosted PostgreSQL check.

## Recovery and evidence

A fresh Codespace editor tab became usable after stopped-state recovery. Two older stalled editor tabs did not respond to close controls; do not report that every cloud tab was cleared. Cloud SQL Auth Proxy is reachable at loopback port 55432 with the existing gcloud login. Private credential/config files remain outside the repo and were not printed.

Backend test log: `/home/vscode/.local/share/intqaflow/dev-guest-backend-tests.log`.
Flutter logs: `/home/vscode/.local/share/intqaflow/guest-flutter-{pub,analyze,test}.log`.

## Remaining acceptance

Guest application changes have not been merged or deployed by this verification. Hosted guest UI/API multi-identity acceptance, owner-private content separation, invitations/approvals, role boundaries, linking/import idempotency and guest expiry behaviour still require deployed application checks. Configuration and library token verification alone do not establish that complete flow.

## Flutter validation at reviewed commit

- `flutter pub get`: exit 0.
- `flutter analyze`: failed with 14 findings: **1 error, 1 warning, 12 info**. Blocking error: undefined `currentGuestGroupsProvider` at `lib/app.dart:37:36`. Warning: unused `participantId` at guest workspace page line1263. Six async BuildContext findings among informational findings.
- `flutter test`: exit 1, **44 passed, 5 failures**:
  - loading `test/widget_test.dart` (compile failure)
  - `guided_ui_test.dart`: collapsed answer hides nested follow-ups
  - `guided_ui_test.dart`: keeps depth 8 editor wide at 360.0 logical pixels
  - `guided_ui_test.dart`: keeps depth 12 editor wide at 360.0 logical pixels
  - `guided_page_test.dart`: new template version uses edited draft and preserves snapshots
- Guest worktree `git status --short` returned no changes after validation.

These are findings for Copilot's application-code/test scope; no application code edits were made during configuration verification. Do not deploy this guest head as passing validation.
