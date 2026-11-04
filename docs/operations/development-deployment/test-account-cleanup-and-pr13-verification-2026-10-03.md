# Disposable account cleanup and PR13 verification — 2026-10-03

## User-directed testing workflow

Founder requested real live acceptance flows: create fresh users through the application, verify email, sign out/sign in normally, provision membership/admin roles through the authorised backend path, and create fresh content through the UI. Synthetic data remains appropriate only where relevant. Isolated automated test doubles do not establish live Firebase authentication acceptance. Codex owns environment/configuration and independent verification; Copilot owns application corrections/tests. Founder authorises running verification on new Copilot commits without repeat confirmation; recurring failures must be brought back for discussion.

## Completed hosted development cleanup

Explicitly authorised permanent removal of the three synthetic sign-in accounts, subsequently all twenty disposable anonymous guests and their related throwaway test content. Project: intqaflow-dev. Actual database: hosted Cloud SQL intqaflow-dev:europe-west2:intqaflow-dev-pg / intqaflow_dev. Codespace used only as a client through the authenticated loopback Cloud SQL proxy, not a local PostgreSQL store.

Deleted Firebase Auth users:
- synthetic-admin@invalid.example / intqaflow-dev-acceptance-admin
- synthetic-same-org@invalid.example / oYmt4NjnabYNNQ4ohXkzEg2dJJh2
- synthetic-foreign-org@invalid.example / 93CqvgC8UpZB2t95EL8ViL5poIk2
- Twenty anonymous identities inventoried in the same project's console, all created 2026-10-03.

Readback: Firebase console displays No users for this project yet. Anonymous sign-in stays enabled; automatic anonymous cleanup was observed OFF and was not changed. Shared guest test group Synthetic acceptance A 2026-10-03 (0eb513d2-4af8-4479-8d09-9d62f0ae7232) expired 2027-01-01, about 89 days away; it was not near expiry. Authentication account cleanup is distinct from application database retention.

Matched exact Firebase UIDs to database mappings before cleanup. Scope included the two confirmed synthetic tenants: synthetic-development (3efed8c4-6ba8-5656-bad6-105211c41151) and synthetic-foreign-acceptance (8d78bef5-bc9b-5550-8313-2813830ecbc8). Guard verified those tenants contained exactly the three identified synthetic users, and the identified guest group had no members outside the twenty reviewed guest UIDs.

Database cleanup completed in one transaction with lock/statement timeouts and normal foreign-key enforcement. Nullable links within only the scoped synthetic tenant rows were cleared to resolve dependencies, followed by ordered deletes. Removed the three users and their UID mappings, two synthetic tenants, two Knowledge questions and embeddings, two templates with versions/questions, four Interact sessions with six participants, sixteen questions, twelve answers and twenty-four revisions, thirty-four audit events, the identified guest group with its cascading membership/content/revision data, and four guest rate-limit rows. Cascade child deletions may report zero in later direct deletes because the parent deletion already removed them. No constraints were disabled, tables truncated, schema/migrations reset, or unrelated rows selected for deletion.

Independent post-commit readback: targeted organisations absent; no rows remain under their organisation IDs or under the twenty guest UIDs in the inspected UID-bearing tables. Firebase listing empty. No production resources were changed. Old local test browser backups are not evidence of cloud data; this cleanup does not claim clearing storage in the founder's personal browser.

## Independent PR13 verification

Pinned commit: 979c9e021e3604327a5939d4c1861e5d90922f15, Retire synthetic manual auth flow. Detached Codespace worktree /workspaces/intqaflow-review-pr13-979c9e0. Logs /tmp/intqaflow-979c9e0-verification. Worktree git status clean after checks, lockfile unchanged.

- Dependency resolution: pass; pip check pass.
- Backend pytest: 82 passed, 1 deprecation warning, 17.15 seconds. Isolated in-memory SQLite and fake embeddings; not a hosted runtime/authentication acceptance result.
- Flutter: 77 passed, 2 failed, approximately 50 seconds.
- flutter analyze: zero errors, zero warnings, 12 informational style findings; exit 1, so not a fully clean analyzer pass.
- Release Flutter web build: pass, 90.4 seconds.

Remaining Flutter failures:
1. team_ui_test.dart — admin surface shows team creation and membership controls: expected exactly one Departments widget, found zero after removal of AdminPage adminOverride and replacement of test membership setup.
2. account_state_widget_test.dart — account creation sends verification email: RenderFlex overflowed by 68 pixels on the bottom.

The earlier f1a98a8 fixture-only correction had independently passed all 78 then-existing Flutter tests; these new results apply to 979c9e0 and must not be replaced with that older pass. Application source changed for signup verification and admin override removal, so the latest full suite and build were rerun.

No merge or deployment performed. Real UI signup/email verification/sign-in, admin provisioning, guest privacy/multiple profiles and rendered PDF acceptance remain pending. Recurring failures are returned to the founder for the requested discussion before another fix cycle.
