# PR13 independent verification — 2026-10-03

Candidate: 907a6c31ca77dcfede352cdd4e660e9b5d2ad958.
Isolated Codespace worktree: /workspaces/intqaflow-review-pr13-907a6c3.
No merge, deployment, hosted database migration, or cloud permission changes performed.

## Backend
Installed repository requirements in an isolated test environment, using in-memory SQLite and fake embeddings.
Result: 78 passed, 1 failed, 1 warning.
Failure: tests/test_organisation_members.py::test_organisation_member_management_is_admin_scoped_and_audited, line 116, expected department_event but received None.
Source inspection shows seed_governance already assigns the employee to Finance; the update assigns the same department. The service records a department-change audit only when the department changes.
Correction: exercise a real department change using a different valid department in the same organisation, or initialize the member without a department. Verify the resulting audit event and separately verify unchanged assignments do not emit change events. Do not manufacture change events to satisfy this assertion.
Passing tests do not establish live Firebase identity, deployed PostgreSQL, or multi-user browser acceptance.

## Flutter
Dependencies resolved. Full suite: 50 passed, 5 test-file load failures. Analysis: 21 issues, including 8 errors.
Blocking errors:
- guest_report_document.dart:446: questionHtml referenced before its declaration.
- guest_workspace_page.dart:396 and :2763: kIsWeb not available.
- guest_workspace_page.dart:2308–2309: nullable cast/conditional expression syntax and non-boolean condition.
- admin_page.dart:248 and :290: valueOrNull unavailable on AsyncValue<List<DepartmentSummary>> with the installed Riverpod version.
Affected load failures include team_ui_test.dart, widget_test.dart, guest_interact_widget_test.dart, guest_interact_helpers_test.dart, and guest_group_dialog_test.dart.
No web build attempted after these compile errors. PDF rendering, download/share, responsive layout, reload, targeting, and recursive-template acceptance remain blocked.

## Additional source-review concern
OrganisationMemberService.add_member can reuse an existing active same-organisation user found by email and replace role/department. Review this reuse path against explicit role-change confirmation, last-active-admin protection, and change auditing. This is a source-review concern, not a reproduced runtime failure.

## Next candidate
Fix compiler blockers, correct the backend fixture, then independently rerun backend tests, Flutter tests/analysis/build, followed by guest-flow and rendered PDF checks. Account sign-in and independent-identity checks remain deferred.
No cloud configuration change is needed to resolve the failures above. First-admin provisioning should wait for a verified nominated account and review of the provisioning flow.
