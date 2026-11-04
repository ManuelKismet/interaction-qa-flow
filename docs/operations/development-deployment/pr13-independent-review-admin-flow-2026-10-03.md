# Independent PR13 review and admin provisioning — 3 October 2026

Fixed candidate: 86ab2b140cbbfe6a599ce595f98e5dec125d2a58. Codespace bookish-happiness-w974vpwgq7j3g95v. Isolated detached worktree /workspaces/intqaflow-review-pr13-86ab2b1; existing checkout and its untracked migration review preserved. Flutter 3.41.4 / Dart 3.11.1.

## Fresh Codespace results
- flutter pub get: succeeded.
- flutter test test/guest_interact_helpers_test.dart test/guest_interact_widget_test.dart --reporter expanded: 3 passed, 3 failed.
- flutter test --reporter expanded: 59 passed, 3 failed, same guest failures.
- flutter analyze: 10 issues, 4 warnings and 6 infos. Four warnings in guest helper/workspace/widget test; six infos in questions_repository.dart outside guest changes.
- flutter build web: succeeded, including Wasm dry run; default compile only, not a configured hosted deployment or browser/PDF acceptance.

Failures:
1. Selected participant scope label double-escapes the name. Expected Selected participant — Alice &lt;A&gt;. guest_report_document.dart escapes nameFor(participantId) while constructing scope, then escapes scope again at output. Escape once at the output boundary.
2. 360x900 layout raises nine rendering exceptions. Active participant DropdownButtonFormField at guest_workspace_page.dart:1146 overflows 846px. Deep follow-up Row at :1522 also overflows, including 123/155/187/219px. Use constrained/expanded selector and adaptive recursive indentation/actions; retain readability, participant context and accessible actions.
3. Reload widget test fails because no active-participant selector is found at test :107 / helper :128. showWorkspace reuses the current widget tree then taps the session title; source review indicates it collapses the expanded session rather than genuinely reloads it. Unmount/remount a fresh workspace/provider scope against the same saved storage before reopening. This is not evidence of product data loss.

Passing focused checks: recursive template structure/blank answers/new IDs/persistence, legacy root-only templates, and HTML injection escaping. The report ownership/scope test fails at its first scope assertion; do not claim its remaining assertions passed. Functional interaction test reaches its later reload stage, but does not pass overall.

Feedback sent to PR13 comment 5970285560. No edits to candidate implementation, merge, deployment, hosted database writes or auth/config changes. Fresh manual browser/PDF, signed-in and independent multi-identity acceptance remains pending.

## Admin provisioning source check
- GuestService.create_group creates an active admin membership for the creator's verified Firebase UID. Group admin is local to that group. transfer_administration hands admin to another active group member and makes current admin a contributor.
- Organisation API identity joins FirebaseUidMapping to active User; organization and role come from database, not signup or client-provided role.
- Mounted v1 router has auth/me, departments, teams, Knowledge/governance/Interact; no organization-member admin assignment route. Organization-create route file is not mounted and does not provision an admin.
- seed_synthetic_membership.py is operator tooling restricted to development + intqaflow-dev, mapping a specified Firebase UID to a synthetic active ADMIN. It is not a production organization onboarding UI.

## Required organization flow, as clarification of existing membership handoff
Controlled operator provisioning establishes the organization and its first legitimate admin, with verified identity and an audit record. No public self-appointed admin bootstrap. Existing organization admins can invite/add members and deliberately assign/change role through a small Members screen and server-authorized API, bounded to their own organization. Signup alone grants no organization role. Department/team membership never implies organization admin. Role changes are auditable; prevent removal/demotion of the last active admin, provide clear confirmation before granting admin, and enforce role changes on subsequent requests. Preserve owner-only private content; admin is not an automatic bypass of private permissions.

Copilot should implement within the existing prioritized stream, describe actual available first-admin provisioning and membership flow, and test unauthorized/cross-org role changes and last-admin protection. No actual access grants are requested by this note.
