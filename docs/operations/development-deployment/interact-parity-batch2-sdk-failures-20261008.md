# Batch 2 independent Flutter checks — 2026-10-08

Source b408dbe7dfed796189124aba6e0e53cb36e89e83; exact app subtree 54b96f7482e9db42195d8bb1c7df4129fc6a86d5. Original and correction mailboxes applied unchanged; applied final commit de580eed29b6c2b07e17defbb47dcdc6597f5222. Pinned Flutter3.41.4 / Dart3.11.1. CI=true and --suppress-analytics prevent metadata probe; TAR_OPTIONS=--no-same-owner handles SDK archive ownership in this container. Enforced lockfile pubget exit0. Original validation app source unchanged.

Analyzer exit1 in26.5s: 9 test compilation errors, 0 warnings, 12 existing infos. Focused five-file test run exit1: 48 passes, 3 failures (account test file compilation, two Group administration-transfer label expectations). Command: flutter test --no-pub --reporter expanded test/account_state_widget_test.dart test/ask_page_test.dart test/guest_group_dialog_test.dart test/guest_interact_widget_test.dart test/widget_test.dart. No full suite/release pass claimed; withheld pending compilation repair.

Official formatter dry-run 9 files would change. Mechanical diff produced in separate b408dbe formatter worktree, app source not application-committed. Artifact e4cb65174c825a9705b061c84cf18880587a208f, interact-parity-batch2-format-20261008.diff98336bytes SHA2564321603601010370953946f832119af76b9c00d134bd6fd194555ccf6205bdb5; remotely retrieved/checksummed. Copilot must apply formatter before code correction or refresh formatting afterward. Preserve behavior/assertions.

Exact output excerpts:

```
Analyzing flutter_app...                                        

   info • Use the null-aware marker '?' rather than a null check via an 'if' • lib/features/governance/data/governance_repository.dart:52:11 • use_null_aware_elements
   info • Use the null-aware marker '?' rather than a null check via an 'if' • lib/features/governance/data/governance_repository.dart:53:11 • use_null_aware_elements
   info • The import of 'dart:typed_data' is unnecessary because all of the used elements are also provided by the import of 'package:flutter/services.dart' • lib/features/guest/presentation/guest_report_document.dart:1:8 • unnecessary_import
   info • The import of 'dart:typed_data' is unnecessary because all of the used elements are also provided by the import of 'package:flutter/foundation.dart' • lib/features/guest/presentation/guest_workspace_page.dart:3:8 • unnecessary_import
   info • The import of 'package:cross_file/cross_file.dart' is unnecessary because all of the used elements are also provided by the import of 'package:share_plus/share_plus.dart' • lib/features/guest/presentation/guest_workspace_page.dart:5:8 • unnecessary_import
   info • Statements in an if should be enclosed in a block • lib/features/guest/presentation/guest_workspace_page.dart:2358:11 • curly_braces_in_flow_control_structures
   info • Use the null-aware marker '?' rather than a null check via an 'if' • lib/features/questions/data/questions_repository.dart:158:11 • use_null_aware_elements
   info • Use the null-aware marker '?' rather than a null check via an 'if' • lib/features/questions/data/questions_repository.dart:193:11 • use_null_aware_elements
   info • Use the null-aware marker '?' rather than a null check via an 'if' • lib/features/questions/data/questions_repository.dart:194:11 • use_null_aware_elements
   info • Use the null-aware marker '?' rather than a null check via an 'if' • lib/features/questions/data/questions_repository.dart:229:11 • use_null_aware_elements
   info • Use the null-aware marker '?' rather than a null check via an 'if' • lib/features/questions/data/questions_repository.dart:245:11 • use_null_aware_elements
   info • Use the null-aware marker '?' rather than a null check via an 'if' • lib/features/questions/data/questions_repository.dart:255:27 • use_null_aware_elements
  error • A value of type 'Consumer' can't be returned from the function 'page' because it has a return type of 'GuestWorkspacePage' • test/account_state_widget_test.dart:447:47 • return_of_invalid_type
  error • The getter 'decoration' isn't defined for the type 'TextFormField' • test/account_state_widget_test.dart:1540:22 • undefined_getter
  error • The getter 'decoration' isn't defined for the type 'TextFormField' • test/account_state_widget_test.dart:1623:22 • undefined_getter
  error • The getter 'decoration' isn't defined for the type 'TextFormField' • test/account_state_widget_test.dart:1700:22 • undefined_getter
  error • The getter 'decoration' isn't defined for the type 'TextFormField' • test/account_state_widget_test.dart:1716:22 • undefined_getter
  error • The getter 'decoration' isn't defined for the type 'TextFormField' • test/account_state_widget_test.dart:1760:22 • undefined_getter
  error • The getter 'decoration' isn't defined for the type 'TextFormField' • test/account_state_widget_test.dart:1805:22 • undefined_getter
  error • The getter 'decoration' isn't defined for the type 'TextFormField' • test/account_state_widget_test.dart:2002:20 • undefined_getter
  error • The getter 'decoration' isn't defined for the type 'TextFormField' • test/account_state_widget_test.dart:2010:20 • undefined_getter

21 issues found. (ran in 26.5s)
00:06 +29 -1: /workspace/scratch/634b5dd13590/batch2-validation/apps/flutter_app/test/guest_group_dialog_test.dart: group administration transfer requires recipient acceptance
══╡ EXCEPTION CAUGHT BY FLUTTER TEST FRAMEWORK ╞════════════════════════════════════════════════════
The following TestFailure was thrown running a test:
Expected: exactly one matching candidate
  Actual: _TextContainingWidgetFinder:<Found 0 widgets with text containing Role: admin: []>
   Which: means none were found but one was expected
The requester keeps the current role until the recipient accepts.

When the exception was thrown, this was the stack:
#4      main.<anonymous closure> (file:///workspace/scratch/634b5dd13590/batch2-validation/apps/flutter_app/test/guest_group_dialog_test.dart:1486:5)
<asynchronous suspension>
#5      testWidgets.<anonymous closure>.<anonymous closure> (package:flutter_test/src/widget_tester.dart:192:15)
<asynchronous suspension>
#6      TestWidgetsFlutterBinding._runTestBody (package:flutter_test/src/binding.dart:1682:5)
<asynchronous suspension>
<asynchronous suspension>
(elided one frame from package:stack_trace)

This was caught by the test expectation on the following line:
  file:///workspace/scratch/634b5dd13590/batch2-validation/apps/flutter_app/test/guest_group_dialog_test.dart line 1486
The test description was:
  group administration transfer requires recipient acceptance
════════════════════════════════════════════════════════════════════════════════════════════════════
00:06 +29 -2: /workspace/scratch/634b5dd13590/batch2-validation/apps/flutter_app/test/guest_interact_widget_test.dart: incompatible backup shows diagnostics without import success
00:06 +29 -2: /workspace/scratch/634b5dd13590/batch2-validation/apps/flutter_app/test/guest_group_dialog_test.dart: group administration transfer requires recipient acceptance [E]
  Test failed. See exception logs above.
  The test description was: group administration transfer requires recipient acceptance
  
00:07 +29 -2: /workspace/scratch/634b5dd13590/batch2-validation/apps/flutter_app/test/guest_group_dialog_test.dart: recipient sees and can accept pending administration transfer
══╡ EXCEPTION CAUGHT BY FLUTTER TEST FRAMEWORK ╞════════════════════════════════════════════════════
The following TestFailure was thrown running a test:
Expected: exactly one matching candidate
  Actual: _TextContainingWidgetFinder:<Found 0 widgets with text containing Role: admin: []>
   Which: means none were found but one was expected

When the exception was thrown, this was the stack:
#4      main.<anonymous closure> (file:///workspace/scratch/634b5dd13590/batch2-validation/apps/flutter_app/test/guest_group_dialog_test.dart:1522:5)
<asynchronous suspension>
#5      testWidgets.<anonymous closure>.<anonymous closure> (package:flutter_test/src/widget_tester.dart:192:15)
<asynchronous suspension>
#6      TestWidgetsFlutterBinding._runTestBody (package:flutter_test/src/binding.dart:1682:5)
<asynchronous suspension>
<asynchronous suspension>
(elided one frame from package:stack_trace)

This was caught by the test expectation on the following line:
  file:///workspace/scratch/634b5dd13590/batch2-validation/apps/flutter_app/test/guest_group_dialog_test.dart line 1522
The test description was:
  recipient sees and can accept pending administration transfer
════════════════════════════════════════════════════════════════════════════════════════════════════
00:07 +29 -3: /workspace/scratch/634b5dd13590/batch2-validation/apps/flutter_app/test/guest_interact_widget_test.dart: incompatible backup shows diagnostics without import success
00:07 +29 -3: /workspace/scratch/634b5dd13590/batch2-validation/apps/flutter_app/test/guest_group_dialog_test.dart: recipient sees and can accept pending administration transfer [E]
  Test failed. See exception logs above.
  The test description was: recipient sees and can accept pending administration transfer
  
00:07 +30 -3: /workspace/scratch/634b5dd13590/batch2-validation/apps/flutter_app/test/guest_group_dialog_test.dart: account transition remounts group state for recipient

```

Local complete logs/exit receipts: /workspace/scratch/634b5dd13590/batch2-{pubget-current,analyze,focused,corrected-format}.{log,exit}. No runtime deployment/merge, Codespace, DB/proxy or production/schema change. Batch2 remains unaccepted.
