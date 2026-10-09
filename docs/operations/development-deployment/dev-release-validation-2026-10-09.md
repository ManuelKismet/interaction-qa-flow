# DEV release validation — 2026-10-09

The full-suite release gate for unified Interact search and responsive workspaces is resolved. Source parent: 6f33bcc6d7378a65fcacec61926b152fbbca703c, on copilot/fixinteract-parity-batch4-edit-shared-copy.

## Verified checks

- Full Flutter suite: 392 passed, zero failures.
- Full backend suite with disposable PostgreSQL 16 and pgvector: 201 passed, zero skipped; all 32 previously environment-dependent checks ran. PostgreSQL stopped successfully afterward.
- Flutter analysis: zero errors and warnings; 18 pre-existing informational lints. Its exit code remains 1 because of those infos.
- DEV-configured release web build passed in 97.8 seconds.
- Git whitespace check passed. The original checkout’s four dirty documentation files remain byte-for-byte unchanged.
- No backend migration differs from the previously deployed 80f421d source. Backend tree: 6e7f896039fe3e982fa65cdc3e96772925510ac0.

## Regression corrections

All 31 independently confirmed earlier failures reproduced before correction. Seven test files were updated for the implemented compact UI: Reports and export and Interact options menus, scoped template-card menus, expanded owner/permission/assignment details, group role information, and the busy sharing preview dialog. Existing permissions, server-write, opt-in, import/export identity and snapshot assertions were retained.

Read-only and archived session checks now explicitly assert that Save history remains available while editing, archive and template creation actions are absent. Phone tests target the outer vertical list rather than editable-field scrollables; visibility is checked after the scroll has rendered. No application authority or feature behavior was relaxed to obtain passes.

## Release status

Backend image built from the exact backend tree above, staged as intqaflow-dev-api-release6f33bcc with zero live traffic. Frontend and backend publishing and hosted smoke results will be recorded after release. Production and security configuration remain outside this DEV rollout.

Authenticated hosted phone/search acceptance remains external/manual because the cloud-browser sign-in issue is paused. Automated mock/widget tests do not establish real Firebase sign-in acceptance.

Detailed runtime logs are retained in /workspaces/dev-release-validation-20261009 in the existing Codespace.
