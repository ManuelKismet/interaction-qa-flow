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

Deployed source: acf30470e9004baefbc37bcaca735ddab3a8f8c6. API revision intqaflow-dev-api-release6f33bcc serves 100% of DEV traffic; health returns 200. Firebase Hosting release 1791508359447000, version ab9d1ef7e5175302, publishes 37 files. Both https://intqaflow-dev.web.app and https://intqaflow-dev.firebaseapp.com match the tested index.html, flutter_bootstrap.js, main.dart.js and release-info.json SHA-256 values (eight comparisons). Missing/invalid user tokens and unauthenticated Personal/Organisation Interact search return 401; hosted-origin CORS passes. Production and existing security configuration were not changed. Disposable PostgreSQL is stopped; the existing Codespace will be stopped after the receipt push.

Authenticated hosted phone/search acceptance remains external/manual because the cloud-browser sign-in issue is paused. Automated mock/widget tests do not establish real Firebase sign-in acceptance.

Detailed runtime logs are retained in /workspaces/dev-release-validation-20261009 in the existing Codespace.
