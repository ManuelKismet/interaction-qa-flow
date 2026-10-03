# Hosted development migration checkpoint

Recorded 2026-10-03 (Europe/London). The founder explicitly authorized applying migrations and deploying/testing directly in the existing hosted development environment. A disposable local database is optional and is not a prerequisite for this work. Production release remains separate.

## Environment and ownership

The database is the existing `intqaflow_dev` on Cloud SQL instance `intqaflow-dev-pg`, project `intqaflow-dev`, europe-west2. The phrase "private database connection" refers to restricted access and private credentials for this same development database, not another database.

Codex owns environment configuration and independent verification; Copilot owns application changes and their tests; founder and Codex review acceptance together.

## Verified during this session

- Stopped Codespace `bookish-happiness-w974vpwgq7j3g95v`; GitHub displayed the stopped confirmation. Reopened it after a seven-second pause. The editor reached connected state and its terminal executed commands.
- Preserved existing worktrees and the untracked prior PostgreSQL migration review. Fetched changes into detached review worktree `/workspaces/intqaflow-dev-guest-49bced8`, pinned to `49bced8ad55c0172804f6f0cc22f50bfa8b8bb1e` from guest PR #11.
- Reviewed `0009`, the explicit PostgreSQL `question_status` cast correcting `0010`, and guest tables/constraints/indexes in `0011`.
- Restored the loopback Cloud SQL Auth Proxy on `127.0.0.1:55432` with the existing authorized gcloud user login. Default application credentials were absent after restart; no new credential or IAM grant was created. Proxy log confirmed ready for connections.
- Connected to hosted database `intqaflow_dev`; read schema revision `0008` before changes.
- Applied `alembic upgrade head` from the pinned guest checkout with the existing private migrator account and an explicit hosted-development database URL. Exit code was 0. PostgreSQL transactional migration output confirmed `0008 -> 0009 -> 0010 -> 0011` completed successfully.
- Migration log is privately stored at `/home/vscode/.local/share/intqaflow/dev-migration-49bced8.log`; credentials were not printed or committed.

## Pending verification

A follow-up command was submitted to check guest-table reads using the API runtime account and run the complete backend test suite into `/home/vscode/.local/share/intqaflow/dev-guest-backend-tests.log`. The browser then stalled again (DOM snapshot, screenshot and lightweight snapshot timeouts), so neither result was observed. Do not count either check as passed; recover the log and rerun/read runtime access checks.

Successful migration output is not full guest acceptance. Firebase anonymous sign-in was not changed in this session and remains pending fresh readback/configuration. API/client guest deployment, real anonymous-token and multi-group privacy acceptance, runtime privileges, search checks, Flutter checks, rendered reports and end-to-end acceptance remain pending.

No application deployment, production change, repository merge, database reset, local disposable database creation, paid embedding activation, App Check mode change or IAM change was performed in this session. One earlier editor tab could not be closed because binding itself timed out; do not claim all stalled tabs were closed.
