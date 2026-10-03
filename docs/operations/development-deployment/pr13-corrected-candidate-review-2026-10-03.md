# PR13 corrected candidate verification — 2026-10-03

Candidate: 3dd90279d712db15cc293d8abb58996b937b2748.
Isolated Codespace checkout: /workspaces/intqaflow-review-pr13-3dd9027.
Backend test environment: isolated requirements environment, SQLite in memory, fake embeddings. No deployed configuration, accounts or databases changed.

## Results
- Backend: 81 passed, 1 Starlette deprecation warning, exit 0.
- Flutter dependency resolution: succeeded; pubspec.lock changed locally and needs regeneration/commit in the PR.
- Full Flutter tests: 61 passed, 4 failed, exit 1. All test files now compile/load.
- Flutter analysis: 15 findings (1 warning, 14 infos), no errors; exit 1 remains.
- Flutter web build: succeeded, including Wasm dry run. Build took 95.9 seconds.

## Four remaining failures
1. team_ui_test.dart, admin surface shows team creation and membership controls: cannot find Payroll when tapping at line 89. New member section increases ListView content. Check lazy construction/scrolling before concluding teams disappeared. Exercise the team controls after scrolling, keeping assertions.
2. guest_interact_widget_test.dart, PDF report preview uses the active participant scope: expects exactly one Alice answer but finds two, including the editor below the dialog. Scope the assertions to the preview dialog and verify Bob content is excluded there; do not merely relax the count.
3. guest_interact_helpers_test.dart, guest reports keep answer ownership, scope and unanswered prompts: expects the literal "Triggered by Alice &lt;A&gt;: private Alice branch answer"; renderer now uses "Follow-up prompted by". Update wording while retaining assertions for actual parent-answer attribution, selected/all scopes, recursive content and escaping. This failure does not by itself establish a data leak or missing branch.
4. guest_group_dialog_test.dart, does not open Export result after entry dialog is dismissed: tries to tap removed "Export" label at line 107. Adapt to PDF download/share workflow and retain a meaningful asynchronous dismissal test with no late dialog/context exception.

These are unresolved tests; source review suggests stale wording, finder scope, and scroll setup account for the failures, but fixes must be verified before treating the suite as passing.

## Confirmed progress
The prior compiler blockers are gone. Narrow guest layout and participant switching/reload widget cases passed. The portable PDF signature/filename helper case passed. These are automated checks, not rendered PDF, actual browser download/share, or live identity acceptance.

## Remaining analysis
Async BuildContext findings at guest_workspace_page.dart:445, :2413 and :2470 need review of mounted/context ownership checks. Remove unnecessary imports, null-aware warning and relevant lint findings without suppressing checks.

## Next
Correct the four tests while preserving their original behavioral intent; regenerate dependency lock; run a clean full test/analysis/build candidate. Continue independent browser and rendered PDF review, including long content/page breaks and active participant privacy. Account sign-in, independent multi-identity testing, broader account/permissions/audit work remain unverified. No merge/deployment or first-admin provisioning was performed.
