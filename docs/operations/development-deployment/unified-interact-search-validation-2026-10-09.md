# Unified Interact search validation — 2026-10-09

Search is implemented on the Batch 4 working branch, with Guest device-local isolation and common permission-scoped Personal/Organisation sources. The implementation and coverage are described in ../../architecture/unified-search.md.

## Verified

- Backend: 169 passed, 32 environment-dependent tests skipped. New service tests cover private ownership, verified identity, active Group membership, archived/expired Groups, organisation visibility, cross-tenant isolation, deleted descendants, recursive answers and limits.
- Focused Flutter search/account/Guest/navigation suite: 113 passed. Includes all-source Interact, Guest isolation, result filters, owner guards, account switches, retry and collapsed-question navigation without saved graph mutation.
- Release web build: passed (91.2 seconds); no deployment performed.
- Analyzer: no errors or warnings; 18 informational lints.
- Original Codespace checkout's four dirty documentation files remain byte-for-byte unchanged. All implementation work is isolated in a separate worktree.

## Wider UI regression baseline

The pre-search head f0d4659d585a0baab771f36156cbde7393499a73 independently produced 339 passes and 31 failures. The full implementation run produced 342 passes and 32 failures: the same 31 cases plus a new test fixture missing the required participant list. That fixture was corrected; the subsequent 113-test focused run passed. This is not a claim that the entire Flutter suite is green.

The 31 baseline cases still require investigation/updated acceptance checks before deployment:

- guest_group_dialog_test.dart: group sharing is opt-in and describes online destination
- guest_group_dialog_test.dart: recipient sees and can accept pending administration transfer
- guided_batch3_test.dart: archived session is read-only with no reopen control
- guided_batch3_test.dart: narrow phone with keyboard keeps question list reachable
- guided_batch3_test.dart: non-owner cannot see organisation mutation controls
- guided_batch3_test.dart: owner sees destination, status, labels and placeholders
- guided_page_test.dart: archived templates can be restored without changing versions
- guided_page_test.dart: legacy grant holder can manage templates and restore failures are visible
- guided_page_test.dart: new template version uses edited draft and preserves snapshots
- guided_page_test.dart: non-owner employee cannot manage another creator template
- guided_safety_test.dart: creator authority on organisation session matches backend
- guided_safety_test.dart: creator authority on private session matches backend
- guided_safety_test.dart: delegate authority on organisation session matches backend
- guided_safety_test.dart: delegate authority on private session matches backend
- guided_safety_test.dart: late export (200) cannot open a dialog or snackbar after navigating to /guided
- guided_safety_test.dart: late export (200) cannot open a dialog or snackbar after navigating to /guided/sessions/session-2
- guided_safety_test.dart: late export (503) cannot open a dialog or snackbar after navigating to /guided
- guided_safety_test.dart: late export (503) cannot open a dialog or snackbar after navigating to /guided/sessions/session-2
- guided_safety_test.dart: legacy authority on organisation session matches backend
- guided_safety_test.dart: legacy authority on private session matches backend
- guided_safety_test.dart: open session export clears on identity change
- guided_safety_test.dart: organisation import warnings remain visible before opening imported session
- guided_safety_test.dart: owner authority on organisation session matches backend
- guided_safety_test.dart: owner authority on private session matches backend
- guided_safety_test.dart: role-only authority on organisation session matches backend
- guided_safety_test.dart: role-only authority on private session matches backend
- guided_safety_test.dart: unsupported guest backup import has a visible failure and no navigation
- guided_session_page_test.dart: session owner retains editing controls
- organisation_scope_test.dart: routed organisation page clears owner data on role, UID and signout
- organisation_scope_test.dart: routed page refreshes revoked review capability and retries list errors
- team_ui_test.dart: ask form exposes team selector and selects parent department

## Rollout

Not deployed. DEV remains on its previous release. The frontend and backend must be deployed together because Interact search adds API endpoints. Hosted signed-in acceptance remains external while cloud browser authentication is unavailable.

## Superseding full-suite validation

The remaining full-suite gate was resolved on 2026-10-09: 392 Flutter tests and 201 backend tests passed, including PostgreSQL integration checks; DEV-configured release build passed. See [DEV release validation](dev-release-validation-2026-10-09.md) for corrections and rollout status. Earlier figures above are historical checkpoints.
