# Batch 2 layout/runtime failures — 2026-10-08

Tested unchanged runtime-correction artifact from source 4cb13204475dc3385513ff5e7187909048cb47c0, exact app subtree d143124e522b746d18fed535d0909fa3296b5199. Raw git diff (not mailbox) 34056 bytes, SHA256 a8ec1dd9c66e99180bdc6511ac0d9e12ab1f029aeaeb6bedb57618b9331aaa80; applied unchanged using git apply --index atop prior844e328 equivalent. git diff --cached --quiet 4cb132 -- apps/flutter_app exit0. HEAD remains prior equivalent; staged app is the tested candidate.

Pinned Flutter3.41.4/Dart3.11.1, CI=true --suppress-analytics. Focused command: flutter test --reporter expanded test/account_state_widget_test.dart test/ask_page_test.dart test/guest_group_dialog_test.dart test/guest_interact_widget_test.dart test/widget_test.dart. Result72PASS26FAIL, exit1. Analyzer0errors0warnings12existinginfos; formatting10files2would-change (guest_workspace_page.dart/account_state_widget_test.dart). Full/release withheld. DEV unchanged, batch2 unaccepted.

The earlier run before raw-diff application is excluded. Logs below are ONLY batch2-runtime-applied-*.

Important: conflict test now reaches missing button finder at1372; do not report previous [1,2] overwrite as reproduced on this candidate. Preserve its explicit-resolution assertions. New actual layout overflows include AppShell AppBar285px horizontal at240px viewport and guest page10px bottom/56px and228px horizontal. Other missing/lazy/offscreen targets need diagnosis; source inference: new Flexible header ScrollView alters geometry/ancestor Scrollable selection. Restore usable content and target correct active scrollable; do not hide exceptions or remove assertions.

## Analyzer and format

```text
Analyzing flutter_app...                                        

   info • Use the null-aware marker '?' rather than a null check via an 'if' • lib/features/governance/data/governance_repository.dart:52:11 • use_null_aware_elements
   info • Use the null-aware marker '?' rather than a null check via an 'if' • lib/features/governance/data/governance_repository.dart:53:11 • use_null_aware_elements
   info • The import of 'dart:typed_data' is unnecessary because all of the used elements are also provided by the import of 'package:flutter/services.dart' • lib/features/guest/presentation/guest_report_document.dart:1:8 • unnecessary_import
   info • The import of 'dart:typed_data' is unnecessary because all of the used elements are also provided by the import of 'package:flutter/foundation.dart' • lib/features/guest/presentation/guest_workspace_page.dart:3:8 • unnecessary_import
   info • The import of 'package:cross_file/cross_file.dart' is unnecessary because all of the used elements are also provided by the import of 'package:share_plus/share_plus.dart' • lib/features/guest/presentation/guest_workspace_page.dart:5:8 • unnecessary_import
   info • Statements in an if should be enclosed in a block • lib/features/guest/presentation/guest_workspace_page.dart:2379:11 • curly_braces_in_flow_control_structures
   info • Use the null-aware marker '?' rather than a null check via an 'if' • lib/features/questions/data/questions_repository.dart:158:11 • use_null_aware_elements
   info • Use the null-aware marker '?' rather than a null check via an 'if' • lib/features/questions/data/questions_repository.dart:193:11 • use_null_aware_elements
   info • Use the null-aware marker '?' rather than a null check via an 'if' • lib/features/questions/data/questions_repository.dart:194:11 • use_null_aware_elements
   info • Use the null-aware marker '?' rather than a null check via an 'if' • lib/features/questions/data/questions_repository.dart:229:11 • use_null_aware_elements
   info • Use the null-aware marker '?' rather than a null check via an 'if' • lib/features/questions/data/questions_repository.dart:245:11 • use_null_aware_elements
   info • Use the null-aware marker '?' rather than a null check via an 'if' • lib/features/questions/data/questions_repository.dart:255:27 • use_null_aware_elements

12 issues found. (ran in 3.6s)
Changed lib/features/guest/presentation/guest_workspace_page.dart
Changed test/account_state_widget_test.dart
Formatted 10 files (2 changed) in 0.51 seconds.

```

## Complete focused log

```text
Waiting for another flutter command to release the startup lock...
00:00 +0: loading /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/account_state_widget_test.dart
00:00 +0: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/account_state_widget_test.dart: local guest account menu explains local-only work
00:00 +1: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/account_state_widget_test.dart: local guest account menu explains local-only work
00:00 +2: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/account_state_widget_test.dart: local guest account menu explains local-only work
00:01 +3: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/account_state_widget_test.dart: local guest account menu explains local-only work
00:01 +4: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/ask_page_test.dart: Ask suggestions show unified source badges and open source
00:01 +5: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/ask_page_test.dart: Ask suggestions show unified source badges and open source
00:01 +6: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/ask_page_test.dart: Ask suggestions show unified source badges and open source
00:01 +7: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/ask_page_test.dart: Ask suggestions show unified source badges and open source
00:02 +8: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/ask_page_test.dart: Ask suggestions show unified source badges and open source
00:02 +9: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/ask_page_test.dart: Ask suggestions show unified source badges and open source
00:02 +10: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/ask_page_test.dart: Ask suggestions show unified source badges and open source
00:02 +11: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/ask_page_test.dart: Ask suggestions show unified source badges and open source
00:02 +12: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/ask_page_test.dart: Ask suggestions show unified source badges and open source
00:02 +13: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/ask_page_test.dart: Ask suggestions show unified source badges and open source
00:02 +14: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/ask_page_test.dart: Ask suggestions show unified source badges and open source
══╡ EXCEPTION CAUGHT BY FLUTTER TEST FRAMEWORK ╞════════════════════════════════════════════════════
The following TestFailure was thrown running a test:
Expected: exactly one matching candidate
  Actual: _TextWidgetFinder:<Found 0 widgets with text "Private account policy": []>
   Which: means none were found but one was expected

When the exception was thrown, this was the stack:
#4      main.<anonymous closure> (file:///workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/ask_page_test.dart:374:5)
<asynchronous suspension>
#5      testWidgets.<anonymous closure>.<anonymous closure> (package:flutter_test/src/widget_tester.dart:192:15)
<asynchronous suspension>
#6      TestWidgetsFlutterBinding._runTestBody (package:flutter_test/src/binding.dart:1682:5)
<asynchronous suspension>
<asynchronous suspension>
(elided one frame from package:stack_trace)

This was caught by the test expectation on the following line:
  file:///workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/ask_page_test.dart line 374
The test description was:
  Ask suggestions show unified source badges and open source
════════════════════════════════════════════════════════════════════════════════════════════════════
00:02 +14 -1: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/guest_interact_widget_test.dart: Saved Q&A search edits and removes local entries and returns to the form
00:02 +14 -1: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/ask_page_test.dart: Ask suggestions show unified source badges and open source [E]
  Test failed. See exception logs above.
  The test description was: Ask suggestions show unified source badges and open source
  
00:02 +14 -1: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/guest_interact_widget_test.dart: Saved Q&A search edits and removes local entries and returns to the form
══╡ EXCEPTION CAUGHT BY FLUTTER TEST FRAMEWORK ╞════════════════════════════════════════════════════
The following TestFailure was thrown running a test:
Expected: exactly one matching candidate
  Actual: _TextWidgetFinder:<Found 0 widgets with text "Incident response": []>
   Which: means none were found but one was expected

When the exception was thrown, this was the stack:
#4      main.<anonymous closure> (file:///workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/guest_interact_widget_test.dart:118:7)
<asynchronous suspension>
#5      testWidgets.<anonymous closure>.<anonymous closure> (package:flutter_test/src/widget_tester.dart:192:15)
<asynchronous suspension>
#6      TestWidgetsFlutterBinding._runTestBody (package:flutter_test/src/binding.dart:1682:5)
<asynchronous suspension>
<asynchronous suspension>
(elided one frame from package:stack_trace)

This was caught by the test expectation on the following line:
  file:///workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/guest_interact_widget_test.dart line 118
The test description was:
  Saved Q&A search edits and removes local entries and returns to the form
════════════════════════════════════════════════════════════════════════════════════════════════════
00:02 +14 -2: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/guest_group_dialog_test.dart: failed remote forms retain drafts without replaying writes
00:02 +14 -2: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/guest_interact_widget_test.dart: Saved Q&A search edits and removes local entries and returns to the form [E]
  Test failed. See exception logs above.
  The test description was: Saved Q&A search edits and removes local entries and returns to the form
  
00:03 +15 -2: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/guest_group_dialog_test.dart: failed remote forms retain drafts without replaying writes
00:03 +15 -2: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/guest_interact_widget_test.dart: long labels and nested branches fit a narrow guest layout
══╡ EXCEPTION CAUGHT BY FLUTTER TEST FRAMEWORK ╞════════════════════════════════════════════════════
The following assertion was thrown running a test:
The finder "Found 0 widgets with text "A long session title that should truncate cleanly": []" (used
in a call to "tap()") could not find any matching widgets.

When the exception was thrown, this was the stack:
#0      WidgetController._getElementPoint (package:flutter_test/src/controller.dart:2090:7)
#1      WidgetController.getCenter (package:flutter_test/src/controller.dart:1942:12)
#2      WidgetController.tap (package:flutter_test/src/controller.dart:1075:7)
#3      main.<anonymous closure> (file:///workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/guest_interact_widget_test.dart:256:18)
<asynchronous suspension>
#4      testWidgets.<anonymous closure>.<anonymous closure> (package:flutter_test/src/widget_tester.dart:192:15)
<asynchronous suspension>
#5      TestWidgetsFlutterBinding._runTestBody (package:flutter_test/src/binding.dart:1682:5)
<asynchronous suspension>
<asynchronous suspension>
(elided one frame from package:stack_trace)

The test description was:
  long labels and nested branches fit a narrow guest layout
════════════════════════════════════════════════════════════════════════════════════════════════════
00:03 +15 -3: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/guest_group_dialog_test.dart: failed remote forms retain drafts without replaying writes
00:03 +15 -3: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/guest_interact_widget_test.dart: long labels and nested branches fit a narrow guest layout [E]
  Test failed. See exception logs above.
  The test description was: long labels and nested branches fit a narrow guest layout
  
00:03 +16 -3: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/guest_group_dialog_test.dart: failed remote forms retain drafts without replaying writes
00:03 +16 -3: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/guest_interact_widget_test.dart: legacy duplicate participant IDs are preserved and not editable

Warning: A call to tap() with finder "Found 1 widget with text "Legacy session": [
  Text("Legacy session", overflow: ellipsis, maxLines: 1, dependencies: [DefaultSelectionStyle, DefaultTextStyle, MediaQuery]),
]" derived an Offset (Offset(376.0, 446.2)) that would not hit test on the specified widget.
Maybe the widget is actually off-screen, or another widget is obscuring it, or the widget cannot receive pointer events.
The finder corresponds to this RenderBox: RenderParagraph#28f72 relayoutBoundary=up24
The hit test result at that offset is: HitTestResult(_RenderInkFeatures#8f4c0@Offset(376.0, 446.2), RenderPhysicalModel#a9add@Offset(376.0, 446.2), RenderSemanticsAnnotations#0bd1e@Offset(376.0, 446.2), RenderRepaintBoundary#facae@Offset(376.0, 446.2), RenderIgnorePointer#f3aab@Offset(376.0, 446.2), RenderAnimatedOpacity#765d6@Offset(376.0, 446.2), RenderAnimatedOpacity#9dbca@Offset(376.0, 446.2), _RenderColoredBox#f7c98@Offset(376.0, 446.2), RenderAnimatedOpacity#af309@Offset(376.0, 446.2), RenderIgnorePointer#edd59@Offset(376.0, 446.2), RenderAnimatedOpacity#13cb8@Offset(376.0, 446.2), RenderRepaintBoundary#60064@Offset(376.0, 446.2), RenderSemanticsAnnotations#60b26@Offset(376.0, 446.2), RenderOffstage#87da4@Offset(376.0, 446.2), RenderSemanticsAnnotations#740ee@Offset(376.0, 446.2), _RenderTheater#4a093@Offset(376.0, 446.2), RenderAbsorbPointer#242ea@Offset(376.0, 446.2), RenderPointerListener#11bf0@Offset(376.0, 446.2), RenderSemanticsAnnotations#82d7b@Offset(376.0, 446.2), RenderCustomPaint#e021f@Offset(376.0, 446.2), RenderSemanticsAnnotations#9fc31@Offset(376.0, 446.2), RenderSemanticsAnnotations#16337@Offset(376.0, 446.2), RenderSemanticsAnnotations#65fe5@Offset(376.0, 446.2), RenderTapRegionSurface#fa714@Offset(376.0, 446.2), RenderSemanticsAnnotations#799ef@Offset(376.0, 446.2), RenderSemanticsAnnotations#77ee7@Offset(376.0, 446.2), HitTestEntry<HitTestTarget>#e9153(_ReusableRenderView#7b246), HitTestEntry<HitTestTarget>#1840b(<AutomatedTestWidgetsFlutterBinding>))
#0      WidgetController._getElementPoint (package:flutter_test/src/controller.dart:2158:25)
#1      WidgetController.getCenter (package:flutter_test/src/controller.dart:1942:12)
#2      WidgetController.tap (package:flutter_test/src/controller.dart:1075:7)
#3      main.<anonymous closure> (file:///workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/guest_interact_widget_test.dart:364:20)
<asynchronous suspension>
#4      testWidgets.<anonymous closure>.<anonymous closure> (package:flutter_test/src/widget_tester.dart:192:15)
<asynchronous suspension>
#5      TestWidgetsFlutterBinding._runTestBody (package:flutter_test/src/binding.dart:1682:5)
<asynchronous suspension>
#6      StackZoneSpecification._registerCallback.<anonymous closure> (package:stack_trace/src/stack_zone_specification.dart:114:42)
<asynchronous suspension>
To silence this warning, pass "warnIfMissed: false" to "tap()".
To make this warning fatal, set WidgetController.hitTestWarningShouldBeFatal to true.

══╡ EXCEPTION CAUGHT BY FLUTTER TEST FRAMEWORK ╞════════════════════════════════════════════════════
The following TestFailure was thrown running a test:
Expected: exactly one matching candidate
  Actual: _TextContainingWidgetFinder:<Found 0 widgets with text containing duplicate participant
IDs: []>
   Which: means none were found but one was expected

When the exception was thrown, this was the stack:
#4      main.<anonymous closure> (file:///workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/guest_interact_widget_test.dart:367:7)
<asynchronous suspension>
#5      testWidgets.<anonymous closure>.<anonymous closure> (package:flutter_test/src/widget_tester.dart:192:15)
<asynchronous suspension>
#6      TestWidgetsFlutterBinding._runTestBody (package:flutter_test/src/binding.dart:1682:5)
<asynchronous suspension>
<asynchronous suspension>
(elided one frame from package:stack_trace)

This was caught by the test expectation on the following line:
  file:///workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/guest_interact_widget_test.dart line 367
The test description was:
  legacy duplicate participant IDs are preserved and not editable
════════════════════════════════════════════════════════════════════════════════════════════════════
00:03 +16 -4: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/guest_group_dialog_test.dart: failed remote forms retain drafts without replaying writes
00:04 +16 -4: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/guest_interact_widget_test.dart: legacy duplicate participant IDs are preserved and not editable [E]
  Test failed. See exception logs above.
  The test description was: legacy duplicate participant IDs are preserved and not editable
  
00:04 +17 -4: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/guest_group_dialog_test.dart: failed remote forms retain drafts without replaying writes
00:04 +17 -4: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/account_state_widget_test.dart: personal workspace data is cleared between account identities
══╡ EXCEPTION CAUGHT BY FLUTTER TEST FRAMEWORK ╞════════════════════════════════════════════════════
The following TestFailure was thrown running a test:
Expected: exactly one matching candidate
  Actual: _TextWidgetFinder:<Found 0 widgets with text "Account A private item": []>
   Which: means none were found but one was expected

When the exception was thrown, this was the stack:
#4      main.<anonymous closure> (file:///workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/account_state_widget_test.dart:803:5)
<asynchronous suspension>
#5      testWidgets.<anonymous closure>.<anonymous closure> (package:flutter_test/src/widget_tester.dart:192:15)
<asynchronous suspension>
#6      TestWidgetsFlutterBinding._runTestBody (package:flutter_test/src/binding.dart:1682:5)
<asynchronous suspension>
<asynchronous suspension>
(elided one frame from package:stack_trace)

This was caught by the test expectation on the following line:
  file:///workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/account_state_widget_test.dart line 803
The test description was:
  personal workspace data is cleared between account identities
════════════════════════════════════════════════════════════════════════════════════════════════════
00:04 +17 -5: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/guest_group_dialog_test.dart: failed remote forms retain drafts without replaying writes
00:04 +17 -5: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/account_state_widget_test.dart: personal workspace data is cleared between account identities [E]
  Test failed. See exception logs above.
  The test description was: personal workspace data is cleared between account identities
  
00:04 +18 -5: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/guest_group_dialog_test.dart: failed remote forms retain drafts without replaying writes
00:04 +19 -5: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/account_state_widget_test.dart: stale personal search results are ignored after account switch
00:04 +20 -5: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/guest_interact_widget_test.dart: switching active participants keeps answers and targeted branches after reload

Warning: A call to tap() with finder "Found 1 widget with widget matching predicate: [
  RawTooltip-[LabeledGlobalKey<RawTooltipState>#9aaa9]("Prepared question help", hover delay: 0:00:00.000000, touch delay: 0:00:01.500000, dismiss delay: 0:00:00.100000, triggerMode: TooltipTriggerMode.longPress, enableFeedback: true, positionDelegate: Closure: (TooltipPositionContext) => Offset from Function '_getDefaultPositionDelegate@1884220820':., state: RawTooltipState#31bbb),
]" derived an Offset (Offset(1064.0, 763.0)) that would not hit test on the specified widget.
Maybe the widget is actually off-screen, or another widget is obscuring it, or the widget cannot receive pointer events.
The finder corresponds to this RenderBox: _RenderLayoutSurrogateProxyBox#9e1c7 relayoutBoundary=up38
The hit test result at that offset is: HitTestResult(_RenderInkFeatures#533fa@Offset(1064.0, 763.0), RenderPhysicalModel#02d67@Offset(1064.0, 763.0), RenderSemanticsAnnotations#8f8ba@Offset(1064.0, 763.0), RenderRepaintBoundary#ab971@Offset(1064.0, 763.0), RenderIgnorePointer#25c6f@Offset(1064.0, 763.0), RenderAnimatedOpacity#ad4d5@Offset(1064.0, 763.0), RenderAnimatedOpacity#ea147@Offset(1064.0, 763.0), _RenderColoredBox#7263b@Offset(1064.0, 763.0), RenderAnimatedOpacity#e37c5@Offset(1064.0, 763.0), RenderIgnorePointer#b0e21@Offset(1064.0, 763.0), RenderAnimatedOpacity#04175@Offset(1064.0, 763.0), RenderRepaintBoundary#e938c@Offset(1064.0, 763.0), RenderSemanticsAnnotations#a1d4c@Offset(1064.0, 763.0), RenderOffstage#a5e06@Offset(1064.0, 763.0), RenderSemanticsAnnotations#2c0d9@Offset(1064.0, 763.0), _RenderTheater#52e91@Offset(1064.0, 763.0), RenderAbsorbPointer#fc8eb@Offset(1064.0, 763.0), RenderPointerListener#d68fa@Offset(1064.0, 763.0), RenderSemanticsAnnotations#f5639@Offset(1064.0, 763.0), RenderCustomPaint#81da4@Offset(1064.0, 763.0), RenderSemanticsAnnotations#07d64@Offset(1064.0, 763.0), RenderSemanticsAnnotations#1e129@Offset(1064.0, 763.0), RenderSemanticsAnnotations#a9bfa@Offset(1064.0, 763.0), RenderTapRegionSurface#fc3f7@Offset(1064.0, 763.0), RenderSemanticsAnnotations#d1641@Offset(1064.0, 763.0), RenderSemanticsAnnotations#77dcc@Offset(1064.0, 763.0), HitTestEntry<HitTestTarget>#3cc87(_ReusableRenderView#7b246), HitTestEntry<HitTestTarget>#e3ea6(<AutomatedTestWidgetsFlutterBinding>))
#0      WidgetController._getElementPoint (package:flutter_test/src/controller.dart:2158:25)
#1      WidgetController.getCenter (package:flutter_test/src/controller.dart:1942:12)
#2      WidgetController.tap (package:flutter_test/src/controller.dart:1075:7)
#3      main.<anonymous closure> (file:///workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/guest_interact_widget_test.dart:479:20)
<asynchronous suspension>
#4      testWidgets.<anonymous closure>.<anonymous closure> (package:flutter_test/src/widget_tester.dart:192:15)
<asynchronous suspension>
#5      TestWidgetsFlutterBinding._runTestBody (package:flutter_test/src/binding.dart:1682:5)
<asynchronous suspension>
#6      StackZoneSpecification._registerCallback.<anonymous closure> (package:stack_trace/src/stack_zone_specification.dart:114:42)
<asynchronous suspension>
To silence this warning, pass "warnIfMissed: false" to "tap()".
To make this warning fatal, set WidgetController.hitTestWarningShouldBeFatal to true.

00:04 +21 -5: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/guest_interact_widget_test.dart: switching active participants keeps answers and targeted branches after reload
00:04 +22 -5: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/guest_interact_widget_test.dart: switching active participants keeps answers and targeted branches after reload
00:05 +23 -5: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/guest_interact_widget_test.dart: switching active participants keeps answers and targeted branches after reload
══╡ EXCEPTION CAUGHT BY FLUTTER TEST FRAMEWORK ╞════════════════════════════════════════════════════
The following TestFailure was thrown running a test:
Expected: exactly one matching candidate
  Actual: _TextWidgetFinder:<Found 0 widgets with text "Shared questions get separate answers from
each participant.": []>
   Which: means none were found but one was expected

When the exception was thrown, this was the stack:
#4      main.<anonymous closure> (file:///workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/guest_interact_widget_test.dart:481:7)
<asynchronous suspension>
#5      testWidgets.<anonymous closure>.<anonymous closure> (package:flutter_test/src/widget_tester.dart:192:15)
<asynchronous suspension>
#6      TestWidgetsFlutterBinding._runTestBody (package:flutter_test/src/binding.dart:1682:5)
<asynchronous suspension>
<asynchronous suspension>
(elided one frame from package:stack_trace)

This was caught by the test expectation on the following line:
  file:///workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/guest_interact_widget_test.dart line 481
The test description was:
  switching active participants keeps answers and targeted branches after reload
════════════════════════════════════════════════════════════════════════════════════════════════════
00:05 +23 -6: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/widget_test.dart: opens the local guest workspace without a login gate
00:05 +23 -6: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/guest_interact_widget_test.dart: switching active participants keeps answers and targeted branches after reload [E]
  Test failed. See exception logs above.
  The test description was: switching active participants keeps answers and targeted branches after reload
  
00:05 +24 -6: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/widget_test.dart: opens the local guest workspace without a login gate
00:05 +24 -6: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/account_state_widget_test.dart: clearing local work does not delete personal account items
══╡ EXCEPTION CAUGHT BY FLUTTER TEST FRAMEWORK ╞════════════════════════════════════════════════════
The following TestFailure was thrown running a test:
Expected: exactly one matching candidate
  Actual: _TextWidgetFinder:<Found 0 widgets with text "Personal account item": []>
   Which: means none were found but one was expected

When the exception was thrown, this was the stack:
#4      main.<anonymous closure> (file:///workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/account_state_widget_test.dart:1180:5)
<asynchronous suspension>
#5      testWidgets.<anonymous closure>.<anonymous closure> (package:flutter_test/src/widget_tester.dart:192:15)
<asynchronous suspension>
#6      TestWidgetsFlutterBinding._runTestBody (package:flutter_test/src/binding.dart:1682:5)
<asynchronous suspension>
<asynchronous suspension>
(elided one frame from package:stack_trace)

This was caught by the test expectation on the following line:
  file:///workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/account_state_widget_test.dart line 1180
The test description was:
  clearing local work does not delete personal account items
════════════════════════════════════════════════════════════════════════════════════════════════════
00:05 +24 -7: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/widget_test.dart: opens the local guest workspace without a login gate
00:05 +24 -7: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/account_state_widget_test.dart: clearing local work does not delete personal account items [E]
  Test failed. See exception logs above.
  The test description was: clearing local work does not delete personal account items
  
00:05 +25 -7: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/widget_test.dart: opens the local guest workspace without a login gate
00:05 +25 -7: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/account_state_widget_test.dart: personal import retries selected items without removing locals
══╡ EXCEPTION CAUGHT BY RENDERING LIBRARY ╞═════════════════════════════════════════════════════════
The following assertion was thrown during layout:
A RenderFlex overflowed by 10.0 pixels on the bottom.

The relevant error-causing widget was:
  AppBar
  AppBar:file:///workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/lib/features/guest/presentation/guest_workspace_page.dart:1663:19

The overflowing RenderFlex has an orientation of Axis.vertical.
The edge of the RenderFlex that is overflowing has been marked in the rendering with a yellow and
black striped pattern. This is usually caused by the contents being too big for the RenderFlex.
Consider applying a flex factor (e.g. using an Expanded widget) to force the children of the
RenderFlex to fit within the available space instead of being sized to their natural size.
This is considered an error condition because it indicates that there is content that cannot be
seen. If the content is legitimately bigger than the available space, consider clipping it with a
ClipRect widget before putting it in the flex, or using a scrollable container rather than a Flex,
like a ListView.
The specific RenderFlex in question is: RenderFlex#96f39 relayoutBoundary=up9 OVERFLOWING:
  creator: Column ← MediaQuery ← Padding ← SafeArea ← Align ← Semantics ← DefaultTextStyle ←
    AnimatedDefaultTextStyle ← _InkFeatures-[GlobalKey#454f3 ink renderer] ←
    NotificationListener<LayoutChangedNotification> ← PhysicalModel ← AnimatedPhysicalModel ← ⋯
  parentData: offset=Offset(0.0, 0.0) (can use size)
  constraints: BoxConstraints(0.0<=w<=240.0, 0.0<=h<=64.0)
  size: Size(240.0, 64.0)
  direction: vertical
  mainAxisAlignment: spaceBetween
  mainAxisSize: max
  crossAxisAlignment: center
  verticalDirection: down
  spacing: 0.0
◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤
════════════════════════════════════════════════════════════════════════════════════════════════════
══╡ EXCEPTION CAUGHT BY RENDERING LIBRARY ╞═════════════════════════════════════════════════════════
The following assertion was thrown during layout:
A RenderFlex overflowed by 56 pixels on the right.

The relevant error-causing widget was:
  MaterialBanner
  MaterialBanner:file:///workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/lib/features/guest/presentation/guest_workspace_page.dart:1780:23

The overflowing RenderFlex has an orientation of Axis.horizontal.
The edge of the RenderFlex that is overflowing has been marked in the rendering with a yellow and
black striped pattern. This is usually caused by the contents being too big for the RenderFlex.
Consider applying a flex factor (e.g. using an Expanded widget) to force the children of the
RenderFlex to fit within the available space instead of being sized to their natural size.
This is considered an error condition because it indicates that there is content that cannot be
seen. If the content is legitimately bigger than the available space, consider clipping it with a
ClipRect widget before putting it in the flex, or using a scrollable container rather than a Flex,
like a ListView.
The specific RenderFlex in question is: RenderFlex#a8a25 relayoutBoundary=up18 OVERFLOWING:
  creator: Row ← Padding ← Column ← DefaultTextStyle ← AnimatedDefaultTextStyle ←
    _InkFeatures-[GlobalKey#59348 ink renderer] ← NotificationListener<LayoutChangedNotification> ←
    PhysicalModel ← AnimatedPhysicalModel ← Material ← Padding ← MaterialBanner ← ⋯
  parentData: offset=Offset(16.0, 2.0) (can use size)
  constraints: BoxConstraints(0.0<=w<=224.0, 0.0<=h<=Infinity)
  size: Size(224.0, 2200.0)
  direction: horizontal
  mainAxisAlignment: start
  mainAxisSize: max
  crossAxisAlignment: center
  textDirection: ltr
  verticalDirection: down
  spacing: 0.0
◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤
════════════════════════════════════════════════════════════════════════════════════════════════════
══╡ EXCEPTION CAUGHT BY RENDERING LIBRARY ╞═════════════════════════════════════════════════════════
The following assertion was thrown during layout:
A RenderFlex overflowed by 228 pixels on the right.

The relevant error-causing widget was:
  AppBar
  AppBar:file:///workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/lib/shared/widgets/app_shell.dart:299:15

The overflowing RenderFlex has an orientation of Axis.horizontal.
The edge of the RenderFlex that is overflowing has been marked in the rendering with a yellow and
black striped pattern. This is usually caused by the contents being too big for the RenderFlex.
Consider applying a flex factor (e.g. using an Expanded widget) to force the children of the
RenderFlex to fit within the available space instead of being sized to their natural size.
This is considered an error condition because it indicates that there is content that cannot be
seen. If the content is legitimately bigger than the available space, consider clipping it with a
ClipRect widget before putting it in the flex, or using a scrollable container rather than a Flex,
like a ListView.
The specific RenderFlex in question is: RenderFlex#632c5 relayoutBoundary=up13 OVERFLOWING:
  creator: Row ← Padding ← IconTheme ← Builder ← IconButtonTheme ← LayoutId-[<_ToolbarSlot.trailing>]
    ← CustomMultiChildLayout ← NavigationToolbar ← DefaultTextStyle ← IconTheme ← Builder ←
    CustomSingleChildLayout ← ⋯
  parentData: offset=Offset(0.0, 0.0) (can use size)
  constraints: BoxConstraints(0.0<=w<=240.0, 0.0<=h<=56.0)
  size: Size(240.0, 24.0)
  direction: horizontal
  mainAxisAlignment: start
  mainAxisSize: min
  crossAxisAlignment: center
  textDirection: ltr
  verticalDirection: down
  spacing: 0.0
◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤
════════════════════════════════════════════════════════════════════════════════════════════════════

Warning: A call to tap() with finder "Found 1 widget with text "Import local work": [
  Text("Import local work", dependencies: [DefaultSelectionStyle, DefaultTextStyle, MediaQuery]),
]" derived an Offset (Offset(155.8, 1350.0)) that would not hit test on the specified widget.
Maybe the widget is actually off-screen, or another widget is obscuring it, or the widget cannot receive pointer events.
Indeed, Offset(155.8, 1350.0) is outside the bounds of the root of the render tree, Size(240.0, 200.0).
The finder corresponds to this RenderBox: RenderParagraph#d674c relayoutBoundary=up35
The hit test result at that offset is: HitTestResult(HitTestEntry<HitTestTarget>#33b06(_ReusableRenderView#f4e0c), HitTestEntry<HitTestTarget>#5156a(<AutomatedTestWidgetsFlutterBinding>))
#0      WidgetController._getElementPoint (package:flutter_test/src/controller.dart:2158:25)
#1      WidgetController.getCenter (package:flutter_test/src/controller.dart:1942:12)
#2      WidgetController.tap (package:flutter_test/src/controller.dart:1075:7)
#3      main.<anonymous closure> (file:///workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/account_state_widget_test.dart:1207:20)
<asynchronous suspension>
#4      testWidgets.<anonymous closure>.<anonymous closure> (package:flutter_test/src/widget_tester.dart:192:15)
<asynchronous suspension>
#5      TestWidgetsFlutterBinding._runTestBody (package:flutter_test/src/binding.dart:1682:5)
<asynchronous suspension>
#6      StackZoneSpecification._registerCallback.<anonymous closure> (package:stack_trace/src/stack_zone_specification.dart:114:42)
<asynchronous suspension>
To silence this warning, pass "warnIfMissed: false" to "tap()".
To make this warning fatal, set WidgetController.hitTestWarningShouldBeFatal to true.

00:06 +26 -7: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/widget_test.dart: opens the local guest workspace without a login gate
00:06 +26 -7: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/guest_group_dialog_test.dart: failed autosave blocks sign-in navigation with warning
══╡ EXCEPTION CAUGHT BY FLUTTER TEST FRAMEWORK ╞════════════════════════════════════════════════════
The following StateError was thrown running a test:
Bad state: No element

When the exception was thrown, this was the stack:
#0      Iterable.single (dart:core/iterable.dart:694:25)
#1      WidgetController.element (package:flutter_test/src/controller.dart:883:30)
#2      WidgetController.ensureVisible (package:flutter_test/src/controller.dart:2382:32)
#3      main.<anonymous closure> (file:///workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/guest_group_dialog_test.dart:1163:18)
<asynchronous suspension>
#4      testWidgets.<anonymous closure>.<anonymous closure> (package:flutter_test/src/widget_tester.dart:192:15)
<asynchronous suspension>
#5      TestWidgetsFlutterBinding._runTestBody (package:flutter_test/src/binding.dart:1682:5)
<asynchronous suspension>
<asynchronous suspension>
(elided one frame from package:stack_trace)

The test description was:
  failed autosave blocks sign-in navigation with warning
════════════════════════════════════════════════════════════════════════════════════════════════════
00:06 +26 -8: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/widget_test.dart: opens the local guest workspace without a login gate
00:06 +26 -8: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/guest_group_dialog_test.dart: failed autosave blocks sign-in navigation with warning [E]
  Test failed. See exception logs above.
  The test description was: failed autosave blocks sign-in navigation with warning
  
00:06 +27 -8: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/widget_test.dart: opens the local guest workspace without a login gate
00:06 +28 -8: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/account_state_widget_test.dart: personal import retries selected items without removing locals
══╡ EXCEPTION CAUGHT BY FLUTTER TEST FRAMEWORK ╞════════════════════════════════════════════════════
The following assertion was thrown running a test:
The finder "Found 0 widgets with text "Keep this item local" descending from widgets with type
"AlertDialog": []" (used in a call to "tap()") could not find any matching widgets.

When the exception was thrown, this was the stack:
#0      WidgetController._getElementPoint (package:flutter_test/src/controller.dart:2090:7)
#1      WidgetController.getCenter (package:flutter_test/src/controller.dart:1942:12)
#2      WidgetController.tap (package:flutter_test/src/controller.dart:1075:7)
#3      main.<anonymous closure> (file:///workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/account_state_widget_test.dart:1209:20)
<asynchronous suspension>
#4      testWidgets.<anonymous closure>.<anonymous closure> (package:flutter_test/src/widget_tester.dart:192:15)
<asynchronous suspension>
#5      TestWidgetsFlutterBinding._runTestBody (package:flutter_test/src/binding.dart:1682:5)
<asynchronous suspension>
<asynchronous suspension>
(elided one frame from package:stack_trace)

The test description was:
  personal import retries selected items without removing locals
════════════════════════════════════════════════════════════════════════════════════════════════════
══╡ EXCEPTION CAUGHT BY FLUTTER TEST FRAMEWORK ╞════════════════════════════════════════════════════
The following message was thrown:
Multiple exceptions (4) were detected during the running of the current test, and at least one was
unexpected.
════════════════════════════════════════════════════════════════════════════════════════════════════
00:06 +28 -9: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/guest_interact_widget_test.dart: incompatible backup shows diagnostics without import success
00:06 +28 -9: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/account_state_widget_test.dart: personal import retries selected items without removing locals [E]
  Test failed. See exception logs above.
  The test description was: personal import retries selected items without removing locals
  
00:06 +29 -9: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/guest_group_dialog_test.dart: group sharing is opt-in and describes online destination
00:06 +30 -9: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/account_state_widget_test.dart: permanent import limit errors ask for a smaller selection
00:06 +30 -9: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/guest_interact_widget_test.dart: failed local save preserves the latest work for explicit retry
══╡ EXCEPTION CAUGHT BY FLUTTER TEST FRAMEWORK ╞════════════════════════════════════════════════════
The following StateError was thrown running a test:
Bad state: No element

When the exception was thrown, this was the stack:
#0      Iterable.single (dart:core/iterable.dart:694:25)
#1      WidgetController.element (package:flutter_test/src/controller.dart:883:30)
#2      WidgetController.ensureVisible (package:flutter_test/src/controller.dart:2382:32)
#3      main.<anonymous closure> (file:///workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/guest_interact_widget_test.dart:757:20)
<asynchronous suspension>
#4      testWidgets.<anonymous closure>.<anonymous closure> (package:flutter_test/src/widget_tester.dart:192:15)
<asynchronous suspension>
#5      TestWidgetsFlutterBinding._runTestBody (package:flutter_test/src/binding.dart:1682:5)
<asynchronous suspension>
<asynchronous suspension>
(elided one frame from package:stack_trace)

The test description was:
  failed local save preserves the latest work for explicit retry
════════════════════════════════════════════════════════════════════════════════════════════════════
00:06 +30 -10: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/account_state_widget_test.dart: permanent import limit errors ask for a smaller selection
00:06 +30 -10: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/guest_interact_widget_test.dart: failed local save preserves the latest work for explicit retry [E]
  Test failed. See exception logs above.
  The test description was: failed local save preserves the latest work for explicit retry
  
00:06 +31 -10: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/account_state_widget_test.dart: permanent import limit errors ask for a smaller selection
00:06 +32 -10: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/guest_interact_widget_test.dart: queued local work is persisted when the page is disposed
00:06 +33 -10: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/guest_interact_widget_test.dart: queued local work is persisted when the page is disposed
══╡ EXCEPTION CAUGHT BY FLUTTER TEST FRAMEWORK ╞════════════════════════════════════════════════════
The following StateError was thrown running a test:
Bad state: No element

When the exception was thrown, this was the stack:
#0      Iterable.single (dart:core/iterable.dart:694:25)
#1      WidgetController.element (package:flutter_test/src/controller.dart:883:30)
#2      WidgetController.ensureVisible (package:flutter_test/src/controller.dart:2382:32)
#3      main.<anonymous closure> (file:///workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/guest_interact_widget_test.dart:822:18)
<asynchronous suspension>
#4      testWidgets.<anonymous closure>.<anonymous closure> (package:flutter_test/src/widget_tester.dart:192:15)
<asynchronous suspension>
#5      TestWidgetsFlutterBinding._runTestBody (package:flutter_test/src/binding.dart:1682:5)
<asynchronous suspension>
<asynchronous suspension>
(elided one frame from package:stack_trace)

The test description was:
  queued local work is persisted when the page is disposed
════════════════════════════════════════════════════════════════════════════════════════════════════
00:07 +33 -11: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/account_state_widget_test.dart: revision conflicts reload before an explicit pending-edit save
00:07 +33 -11: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/guest_interact_widget_test.dart: queued local work is persisted when the page is disposed [E]
  Test failed. See exception logs above.
  The test description was: queued local work is persisted when the page is disposed
  
00:07 +34 -11: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/account_state_widget_test.dart: revision conflicts reload before an explicit pending-edit save
══╡ EXCEPTION CAUGHT BY FLUTTER TEST FRAMEWORK ╞════════════════════════════════════════════════════
The following assertion was thrown running a test:
The finder "Found 0 widgets with widget matching predicate: []" (used in a call to "tap()") could
not find any matching widgets.

When the exception was thrown, this was the stack:
#0      WidgetController._getElementPoint (package:flutter_test/src/controller.dart:2090:7)
#1      WidgetController.getCenter (package:flutter_test/src/controller.dart:1942:12)
#2      WidgetController.tap (package:flutter_test/src/controller.dart:1075:7)
#3      main.<anonymous closure> (file:///workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/account_state_widget_test.dart:1372:20)
<asynchronous suspension>
#4      testWidgets.<anonymous closure>.<anonymous closure> (package:flutter_test/src/widget_tester.dart:192:15)
<asynchronous suspension>
#5      TestWidgetsFlutterBinding._runTestBody (package:flutter_test/src/binding.dart:1682:5)
<asynchronous suspension>
<asynchronous suspension>
(elided one frame from package:stack_trace)

The test description was:
  revision conflicts reload before an explicit pending-edit save
════════════════════════════════════════════════════════════════════════════════════════════════════
00:07 +34 -12: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/guest_interact_widget_test.dart: in-flight local save completes after the page is disposed
00:07 +34 -12: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/account_state_widget_test.dart: revision conflicts reload before an explicit pending-edit save [E]
  Test failed. See exception logs above.
  The test description was: revision conflicts reload before an explicit pending-edit save
  
00:07 +35 -12: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/guest_interact_widget_test.dart: in-flight local save completes after the page is disposed
══╡ EXCEPTION CAUGHT BY FLUTTER TEST FRAMEWORK ╞════════════════════════════════════════════════════
The following StateError was thrown running a test:
Bad state: No element

When the exception was thrown, this was the stack:
#0      Iterable.single (dart:core/iterable.dart:694:25)
#1      WidgetController.element (package:flutter_test/src/controller.dart:883:30)
#2      WidgetController.ensureVisible (package:flutter_test/src/controller.dart:2382:32)
#3      main.<anonymous closure> (file:///workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/guest_interact_widget_test.dart:856:18)
<asynchronous suspension>
#4      testWidgets.<anonymous closure>.<anonymous closure> (package:flutter_test/src/widget_tester.dart:192:15)
<asynchronous suspension>
#5      TestWidgetsFlutterBinding._runTestBody (package:flutter_test/src/binding.dart:1682:5)
<asynchronous suspension>
<asynchronous suspension>
(elided one frame from package:stack_trace)

The test description was:
  in-flight local save completes after the page is disposed
════════════════════════════════════════════════════════════════════════════════════════════════════
00:07 +35 -13: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/account_state_widget_test.dart: editing an imported nested session updates the account copy
00:07 +35 -13: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/guest_interact_widget_test.dart: in-flight local save completes after the page is disposed [E]
  Test failed. See exception logs above.
  The test description was: in-flight local save completes after the page is disposed
  
00:07 +36 -13: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/account_state_widget_test.dart: editing an imported nested session updates the account copy

Warning: A call to tap() with finder "Found 1 widget with text "Imported nested session": [
  Text("Imported nested session", overflow: ellipsis, maxLines: 1, dependencies: [DefaultSelectionStyle, DefaultTextStyle, MediaQuery]),
]" derived an Offset (Offset(376.0, 580.2)) that would not hit test on the specified widget.
Maybe the widget is actually off-screen, or another widget is obscuring it, or the widget cannot receive pointer events.
The finder corresponds to this RenderBox: RenderParagraph#24e9a relayoutBoundary=up24
The hit test result at that offset is: HitTestResult(_RenderInkFeatures#e07ae@Offset(376.0, 580.2), RenderPhysicalModel#cf8be@Offset(376.0, 580.2), RenderSemanticsAnnotations#c0cf6@Offset(376.0, 580.2), RenderRepaintBoundary#14e7d@Offset(376.0, 580.2), RenderIgnorePointer#43c33@Offset(376.0, 580.2), RenderAnimatedOpacity#4fd6a@Offset(376.0, 580.2), RenderAnimatedOpacity#d5ce5@Offset(376.0, 580.2), _RenderColoredBox#c8910@Offset(376.0, 580.2), RenderAnimatedOpacity#18856@Offset(376.0, 580.2), RenderIgnorePointer#bae66@Offset(376.0, 580.2), RenderAnimatedOpacity#f5f75@Offset(376.0, 580.2), RenderRepaintBoundary#662d3@Offset(376.0, 580.2), RenderSemanticsAnnotations#bb097@Offset(376.0, 580.2), RenderOffstage#dbd7d@Offset(376.0, 580.2), RenderSemanticsAnnotations#fcaf6@Offset(376.0, 580.2), _RenderTheater#9030b@Offset(376.0, 580.2), RenderAbsorbPointer#62ef4@Offset(376.0, 580.2), RenderPointerListener#87543@Offset(376.0, 580.2), RenderSemanticsAnnotations#28df2@Offset(376.0, 580.2), RenderCustomPaint#0ccaf@Offset(376.0, 580.2), RenderSemanticsAnnotations#e3685@Offset(376.0, 580.2), RenderSemanticsAnnotations#d72ae@Offset(376.0, 580.2), RenderSemanticsAnnotations#0b304@Offset(376.0, 580.2), RenderTapRegionSurface#eae30@Offset(376.0, 580.2), RenderSemanticsAnnotations#579ed@Offset(376.0, 580.2), RenderSemanticsAnnotations#8af61@Offset(376.0, 580.2), HitTestEntry<HitTestTarget>#f2071(_ReusableRenderView#f4e0c), HitTestEntry<HitTestTarget>#45dad(<AutomatedTestWidgetsFlutterBinding>))
#0      WidgetController._getElementPoint (package:flutter_test/src/controller.dart:2158:25)
#1      WidgetController.getCenter (package:flutter_test/src/controller.dart:1942:12)
#2      WidgetController.tap (package:flutter_test/src/controller.dart:1075:7)
#3      main.<anonymous closure> (file:///workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/account_state_widget_test.dart:1488:18)
<asynchronous suspension>
#4      testWidgets.<anonymous closure>.<anonymous closure> (package:flutter_test/src/widget_tester.dart:192:15)
<asynchronous suspension>
#5      TestWidgetsFlutterBinding._runTestBody (package:flutter_test/src/binding.dart:1682:5)
<asynchronous suspension>
#6      StackZoneSpecification._registerCallback.<anonymous closure> (package:stack_trace/src/stack_zone_specification.dart:114:42)
<asynchronous suspension>
To silence this warning, pass "warnIfMissed: false" to "tap()".
To make this warning fatal, set WidgetController.hitTestWarningShouldBeFatal to true.

══╡ EXCEPTION CAUGHT BY FLUTTER TEST FRAMEWORK ╞════════════════════════════════════════════════════
The following TestFailure was thrown running a test:
Expected: exactly one matching candidate
  Actual: _TextWidgetFinder:<Found 0 widgets with text "Existing nested follow-up": []>
   Which: means none were found but one was expected

When the exception was thrown, this was the stack:
#4      main.<anonymous closure> (file:///workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/account_state_widget_test.dart:1491:5)
<asynchronous suspension>
#5      testWidgets.<anonymous closure>.<anonymous closure> (package:flutter_test/src/widget_tester.dart:192:15)
<asynchronous suspension>
#6      TestWidgetsFlutterBinding._runTestBody (package:flutter_test/src/binding.dart:1682:5)
<asynchronous suspension>
<asynchronous suspension>
(elided one frame from package:stack_trace)

This was caught by the test expectation on the following line:
  file:///workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/account_state_widget_test.dart line 1491
The test description was:
  editing an imported nested session updates the account copy
════════════════════════════════════════════════════════════════════════════════════════════════════
00:07 +36 -14: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/guest_interact_widget_test.dart: failed local save still allows backup copy with accurate status
00:07 +36 -14: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/account_state_widget_test.dart: editing an imported nested session updates the account copy [E]
  Test failed. See exception logs above.
  The test description was: editing an imported nested session updates the account copy
  
00:07 +36 -14: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/guest_interact_widget_test.dart: failed local save still allows backup copy with accurate status
══╡ EXCEPTION CAUGHT BY FLUTTER TEST FRAMEWORK ╞════════════════════════════════════════════════════
The following StateError was thrown running a test:
Bad state: No element

When the exception was thrown, this was the stack:
#0      Iterable.single (dart:core/iterable.dart:694:25)
#1      WidgetController.element (package:flutter_test/src/controller.dart:883:30)
#2      WidgetController.ensureVisible (package:flutter_test/src/controller.dart:2382:32)
#3      main.<anonymous closure> (file:///workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/guest_interact_widget_test.dart:901:20)
<asynchronous suspension>
#4      testWidgets.<anonymous closure>.<anonymous closure> (package:flutter_test/src/widget_tester.dart:192:15)
<asynchronous suspension>
#5      TestWidgetsFlutterBinding._runTestBody (package:flutter_test/src/binding.dart:1682:5)
<asynchronous suspension>
<asynchronous suspension>
(elided one frame from package:stack_trace)

The test description was:
  failed local save still allows backup copy with accurate status
════════════════════════════════════════════════════════════════════════════════════════════════════
00:07 +36 -15: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/guest_group_dialog_test.dart: account transition remounts group state for recipient
00:07 +36 -15: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/guest_interact_widget_test.dart: failed local save still allows backup copy with accurate status [E]
  Test failed. See exception logs above.
  The test description was: failed local save still allows backup copy with accurate status
  
00:07 +37 -15: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/account_state_widget_test.dart: local work stays separate until explicit account import
══╡ EXCEPTION CAUGHT BY RENDERING LIBRARY ╞═════════════════════════════════════════════════════════
The following assertion was thrown during layout:
A RenderFlex overflowed by 10.0 pixels on the bottom.

The relevant error-causing widget was:
  AppBar
  AppBar:file:///workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/lib/features/guest/presentation/guest_workspace_page.dart:1663:19

The overflowing RenderFlex has an orientation of Axis.vertical.
The edge of the RenderFlex that is overflowing has been marked in the rendering with a yellow and
black striped pattern. This is usually caused by the contents being too big for the RenderFlex.
Consider applying a flex factor (e.g. using an Expanded widget) to force the children of the
RenderFlex to fit within the available space instead of being sized to their natural size.
This is considered an error condition because it indicates that there is content that cannot be
seen. If the content is legitimately bigger than the available space, consider clipping it with a
ClipRect widget before putting it in the flex, or using a scrollable container rather than a Flex,
like a ListView.
The specific RenderFlex in question is: RenderFlex#cf113 relayoutBoundary=up9 OVERFLOWING:
  creator: Column ← MediaQuery ← Padding ← SafeArea ← Align ← Semantics ← DefaultTextStyle ←
    AnimatedDefaultTextStyle ← _InkFeatures-[GlobalKey#905c7 ink renderer] ←
    NotificationListener<LayoutChangedNotification> ← PhysicalModel ← AnimatedPhysicalModel ← ⋯
  parentData: offset=Offset(0.0, 0.0) (can use size)
  constraints: BoxConstraints(0.0<=w<=240.0, 0.0<=h<=64.0)
  size: Size(240.0, 64.0)
  direction: vertical
  mainAxisAlignment: spaceBetween
  mainAxisSize: max
  crossAxisAlignment: center
  verticalDirection: down
  spacing: 0.0
◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤
════════════════════════════════════════════════════════════════════════════════════════════════════
══╡ EXCEPTION CAUGHT BY RENDERING LIBRARY ╞═════════════════════════════════════════════════════════
The following assertion was thrown during layout:
A RenderFlex overflowed by 56 pixels on the right.

The relevant error-causing widget was:
  MaterialBanner
  MaterialBanner:file:///workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/lib/features/guest/presentation/guest_workspace_page.dart:1780:23

The overflowing RenderFlex has an orientation of Axis.horizontal.
The edge of the RenderFlex that is overflowing has been marked in the rendering with a yellow and
black striped pattern. This is usually caused by the contents being too big for the RenderFlex.
Consider applying a flex factor (e.g. using an Expanded widget) to force the children of the
RenderFlex to fit within the available space instead of being sized to their natural size.
This is considered an error condition because it indicates that there is content that cannot be
seen. If the content is legitimately bigger than the available space, consider clipping it with a
ClipRect widget before putting it in the flex, or using a scrollable container rather than a Flex,
like a ListView.
The specific RenderFlex in question is: RenderFlex#c2cf4 relayoutBoundary=up18 OVERFLOWING:
  creator: Row ← Padding ← Column ← DefaultTextStyle ← AnimatedDefaultTextStyle ←
    _InkFeatures-[GlobalKey#442cb ink renderer] ← NotificationListener<LayoutChangedNotification> ←
    PhysicalModel ← AnimatedPhysicalModel ← Material ← Padding ← MaterialBanner ← ⋯
  parentData: offset=Offset(16.0, 2.0) (can use size)
  constraints: BoxConstraints(0.0<=w<=224.0, 0.0<=h<=Infinity)
  size: Size(224.0, 2200.0)
  direction: horizontal
  mainAxisAlignment: start
  mainAxisSize: max
  crossAxisAlignment: center
  textDirection: ltr
  verticalDirection: down
  spacing: 0.0
◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤
════════════════════════════════════════════════════════════════════════════════════════════════════
══╡ EXCEPTION CAUGHT BY RENDERING LIBRARY ╞═════════════════════════════════════════════════════════
The following assertion was thrown during layout:
A RenderFlex overflowed by 228 pixels on the right.

The relevant error-causing widget was:
  AppBar
  AppBar:file:///workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/lib/shared/widgets/app_shell.dart:299:15

The overflowing RenderFlex has an orientation of Axis.horizontal.
The edge of the RenderFlex that is overflowing has been marked in the rendering with a yellow and
black striped pattern. This is usually caused by the contents being too big for the RenderFlex.
Consider applying a flex factor (e.g. using an Expanded widget) to force the children of the
RenderFlex to fit within the available space instead of being sized to their natural size.
This is considered an error condition because it indicates that there is content that cannot be
seen. If the content is legitimately bigger than the available space, consider clipping it with a
ClipRect widget before putting it in the flex, or using a scrollable container rather than a Flex,
like a ListView.
The specific RenderFlex in question is: RenderFlex#dbe42 relayoutBoundary=up13 OVERFLOWING:
  creator: Row ← Padding ← IconTheme ← Builder ← IconButtonTheme ← LayoutId-[<_ToolbarSlot.trailing>]
    ← CustomMultiChildLayout ← NavigationToolbar ← DefaultTextStyle ← IconTheme ← Builder ←
    CustomSingleChildLayout ← ⋯
  parentData: offset=Offset(0.0, 0.0) (can use size)
  constraints: BoxConstraints(0.0<=w<=240.0, 0.0<=h<=56.0)
  size: Size(240.0, 24.0)
  direction: horizontal
  mainAxisAlignment: start
  mainAxisSize: min
  crossAxisAlignment: center
  textDirection: ltr
  verticalDirection: down
  spacing: 0.0
◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤
════════════════════════════════════════════════════════════════════════════════════════════════════

Warning: A call to tap() with finder "Found 1 widget with text "Import local work": [
  Text("Import local work", dependencies: [DefaultSelectionStyle, DefaultTextStyle, MediaQuery]),
]" derived an Offset (Offset(155.8, 1350.0)) that would not hit test on the specified widget.
Maybe the widget is actually off-screen, or another widget is obscuring it, or the widget cannot receive pointer events.
Indeed, Offset(155.8, 1350.0) is outside the bounds of the root of the render tree, Size(240.0, 200.0).
The finder corresponds to this RenderBox: RenderParagraph#182c7 relayoutBoundary=up35
The hit test result at that offset is: HitTestResult(HitTestEntry<HitTestTarget>#cf649(_ReusableRenderView#f4e0c), HitTestEntry<HitTestTarget>#75cc6(<AutomatedTestWidgetsFlutterBinding>))
#0      WidgetController._getElementPoint (package:flutter_test/src/controller.dart:2158:25)
#1      WidgetController.getCenter (package:flutter_test/src/controller.dart:1942:12)
#2      WidgetController.tap (package:flutter_test/src/controller.dart:1075:7)
#3      main.<anonymous closure> (file:///workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/account_state_widget_test.dart:1542:18)
<asynchronous suspension>
#4      testWidgets.<anonymous closure>.<anonymous closure> (package:flutter_test/src/widget_tester.dart:192:15)
<asynchronous suspension>
#5      TestWidgetsFlutterBinding._runTestBody (package:flutter_test/src/binding.dart:1682:5)
<asynchronous suspension>
#6      StackZoneSpecification._registerCallback.<anonymous closure> (package:stack_trace/src/stack_zone_specification.dart:114:42)
<asynchronous suspension>
To silence this warning, pass "warnIfMissed: false" to "tap()".
To make this warning fatal, set WidgetController.hitTestWarningShouldBeFatal to true.

00:07 +38 -15: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/account_state_widget_test.dart: local work stays separate until explicit account import
══╡ EXCEPTION CAUGHT BY FLUTTER TEST FRAMEWORK ╞════════════════════════════════════════════════════
The following assertion was thrown running a test:
The finder "Found 0 widgets with text "Import selected work": []" (used in a call to "tap()") could
not find any matching widgets.

When the exception was thrown, this was the stack:
#0      WidgetController._getElementPoint (package:flutter_test/src/controller.dart:2090:7)
#1      WidgetController.getCenter (package:flutter_test/src/controller.dart:1942:12)
#2      WidgetController.tap (package:flutter_test/src/controller.dart:1075:7)
#3      main.<anonymous closure> (file:///workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/account_state_widget_test.dart:1544:18)
<asynchronous suspension>
#4      testWidgets.<anonymous closure>.<anonymous closure> (package:flutter_test/src/widget_tester.dart:192:15)
<asynchronous suspension>
#5      TestWidgetsFlutterBinding._runTestBody (package:flutter_test/src/binding.dart:1682:5)
<asynchronous suspension>
<asynchronous suspension>
(elided one frame from package:stack_trace)

The test description was:
  local work stays separate until explicit account import
════════════════════════════════════════════════════════════════════════════════════════════════════
══╡ EXCEPTION CAUGHT BY FLUTTER TEST FRAMEWORK ╞════════════════════════════════════════════════════
The following message was thrown:
Multiple exceptions (4) were detected during the running of the current test, and at least one was
unexpected.
════════════════════════════════════════════════════════════════════════════════════════════════════
00:08 +38 -16: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/guest_interact_widget_test.dart: failed backup import preserves source and current local data
00:08 +38 -16: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/account_state_widget_test.dart: local work stays separate until explicit account import [E]
  Test failed. See exception logs above.
  The test description was: local work stays separate until explicit account import
  
00:08 +39 -16: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/guest_interact_widget_test.dart: failed backup import preserves source and current local data
00:08 +40 -16: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/account_state_widget_test.dart: new verified-user Knowledge saves privately and reconciles an uncertain create
00:08 +41 -16: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/account_state_widget_test.dart: new verified-user Knowledge saves privately and reconciles an uncertain create
00:08 +42 -16: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/account_state_widget_test.dart: new verified-user Knowledge saves privately and reconciles an uncertain create
00:08 +43 -16: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/account_state_widget_test.dart: new verified-user Knowledge saves privately and reconciles an uncertain create
══╡ EXCEPTION CAUGHT BY FLUTTER TEST FRAMEWORK ╞════════════════════════════════════════════════════
The following assertion was thrown running a test:
The finder "Found 0 widgets with text "Save to private account" (considering only hit-testable
widgets with a RenderBox): []" (used in a call to "tap()") could not find any matching widgets.

When the exception was thrown, this was the stack:
#0      WidgetController._getElementPoint (package:flutter_test/src/controller.dart:2090:7)
#1      WidgetController.getCenter (package:flutter_test/src/controller.dart:1942:12)
#2      WidgetController.tap (package:flutter_test/src/controller.dart:1075:7)
#3      main.<anonymous closure> (file:///workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/account_state_widget_test.dart:1601:20)
<asynchronous suspension>
#4      testWidgets.<anonymous closure>.<anonymous closure> (package:flutter_test/src/widget_tester.dart:192:15)
<asynchronous suspension>
#5      TestWidgetsFlutterBinding._runTestBody (package:flutter_test/src/binding.dart:1682:5)
<asynchronous suspension>
<asynchronous suspension>
(elided one frame from package:stack_trace)

The test description was:
  new verified-user Knowledge saves privately and reconciles an uncertain create
════════════════════════════════════════════════════════════════════════════════════════════════════
00:08 +43 -17: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/guest_group_dialog_test.dart: uncertain deletion keeps item and blocks retry until refresh
00:08 +43 -17: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/account_state_widget_test.dart: new verified-user Knowledge saves privately and reconciles an uncertain create [E]
  Test failed. See exception logs above.
  The test description was: new verified-user Knowledge saves privately and reconciles an uncertain create
  
00:08 +44 -17: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/guest_interact_widget_test.dart: a stale save completion never reports newer edits as saved
00:08 +44 -17: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/account_state_widget_test.dart: pending private write blocks shell navigation and browser back until saved
══╡ EXCEPTION CAUGHT BY RENDERING LIBRARY ╞═════════════════════════════════════════════════════════
The following assertion was thrown during layout:
A RenderFlex overflowed by 285 pixels on the right.

The relevant error-causing widget was:
  AppBar
  AppBar:file:///workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/lib/shared/widgets/app_shell.dart:299:15

The overflowing RenderFlex has an orientation of Axis.horizontal.
The edge of the RenderFlex that is overflowing has been marked in the rendering with a yellow and
black striped pattern. This is usually caused by the contents being too big for the RenderFlex.
Consider applying a flex factor (e.g. using an Expanded widget) to force the children of the
RenderFlex to fit within the available space instead of being sized to their natural size.
This is considered an error condition because it indicates that there is content that cannot be
seen. If the content is legitimately bigger than the available space, consider clipping it with a
ClipRect widget before putting it in the flex, or using a scrollable container rather than a Flex,
like a ListView.
The specific RenderFlex in question is: RenderFlex#ca065 relayoutBoundary=up13 OVERFLOWING:
  creator: Row ← Padding ← IconTheme ← Builder ← IconButtonTheme ← LayoutId-[<_ToolbarSlot.trailing>]
    ← CustomMultiChildLayout ← NavigationToolbar ← DefaultTextStyle ← IconTheme ← Builder ←
    CustomSingleChildLayout ← ⋯
  parentData: offset=Offset(0.0, 0.0) (can use size)
  constraints: BoxConstraints(0.0<=w<=240.0, 0.0<=h<=56.0)
  size: Size(240.0, 24.0)
  direction: horizontal
  mainAxisAlignment: start
  mainAxisSize: min
  crossAxisAlignment: center
  textDirection: ltr
  verticalDirection: down
  spacing: 0.0
◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤
════════════════════════════════════════════════════════════════════════════════════════════════════
══╡ EXCEPTION CAUGHT BY RENDERING LIBRARY ╞═════════════════════════════════════════════════════════
The following assertion was thrown during layout:
A RenderFlex overflowed by 10.0 pixels on the bottom.

The relevant error-causing widget was:
  AppBar
  AppBar:file:///workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/lib/features/guest/presentation/guest_workspace_page.dart:1663:19

The overflowing RenderFlex has an orientation of Axis.vertical.
The edge of the RenderFlex that is overflowing has been marked in the rendering with a yellow and
black striped pattern. This is usually caused by the contents being too big for the RenderFlex.
Consider applying a flex factor (e.g. using an Expanded widget) to force the children of the
RenderFlex to fit within the available space instead of being sized to their natural size.
This is considered an error condition because it indicates that there is content that cannot be
seen. If the content is legitimately bigger than the available space, consider clipping it with a
ClipRect widget before putting it in the flex, or using a scrollable container rather than a Flex,
like a ListView.
The specific RenderFlex in question is: RenderFlex#6fab1 relayoutBoundary=up9 OVERFLOWING:
  creator: Column ← MediaQuery ← Padding ← SafeArea ← Align ← Semantics ← DefaultTextStyle ←
    AnimatedDefaultTextStyle ← _InkFeatures-[GlobalKey#5dc43 ink renderer] ←
    NotificationListener<LayoutChangedNotification> ← PhysicalModel ← AnimatedPhysicalModel ← ⋯
  parentData: offset=Offset(0.0, 0.0) (can use size)
  constraints: BoxConstraints(0.0<=w<=240.0, 0.0<=h<=64.0)
  size: Size(240.0, 64.0)
  direction: vertical
  mainAxisAlignment: spaceBetween
  mainAxisSize: max
  crossAxisAlignment: center
  verticalDirection: down
  spacing: 0.0
◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤
════════════════════════════════════════════════════════════════════════════════════════════════════
00:08 +44 -17: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/guest_interact_widget_test.dart: a stale save completion never reports newer edits as saved
══╡ EXCEPTION CAUGHT BY FLUTTER TEST FRAMEWORK ╞════════════════════════════════════════════════════
The following StateError was thrown running a test:
Bad state: No element

When the exception was thrown, this was the stack:
#0      Iterable.single (dart:core/iterable.dart:694:25)
#1      WidgetController.element (package:flutter_test/src/controller.dart:883:30)
#2      WidgetController.ensureVisible (package:flutter_test/src/controller.dart:2382:32)
#3      main.<anonymous closure> (file:///workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/guest_interact_widget_test.dart:1103:18)
<asynchronous suspension>
#4      testWidgets.<anonymous closure>.<anonymous closure> (package:flutter_test/src/widget_tester.dart:192:15)
<asynchronous suspension>
#5      TestWidgetsFlutterBinding._runTestBody (package:flutter_test/src/binding.dart:1682:5)
<asynchronous suspension>
<asynchronous suspension>
(elided one frame from package:stack_trace)

The test description was:
  a stale save completion never reports newer edits as saved
════════════════════════════════════════════════════════════════════════════════════════════════════
00:08 +44 -18: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/account_state_widget_test.dart: pending private write blocks shell navigation and browser back until saved
00:08 +44 -18: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/guest_interact_widget_test.dart: a stale save completion never reports newer edits as saved [E]
  Test failed. See exception logs above.
  The test description was: a stale save completion never reports newer edits as saved
  
00:08 +45 -18: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/account_state_widget_test.dart: pending private write blocks shell navigation and browser back until saved
00:08 +46 -18: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/account_state_widget_test.dart: pending private write blocks shell navigation and browser back until saved
00:08 +47 -18: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/account_state_widget_test.dart: pending private write blocks shell navigation and browser back until saved
00:08 +48 -18: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/account_state_widget_test.dart: pending private write blocks shell navigation and browser back until saved
══╡ EXCEPTION CAUGHT BY FLUTTER TEST FRAMEWORK ╞════════════════════════════════════════════════════
The following StateError was thrown running a test:
Bad state: No element

When the exception was thrown, this was the stack:
#0      Iterable.single (dart:core/iterable.dart:694:25)
#1      WidgetController.state (package:flutter_test/src/controller.dart:927:42)
#2      WidgetTester.showKeyboard.<anonymous closure> (package:flutter_test/src/widget_tester.dart:1125:42)
#5      TestAsyncUtils.guard (package:flutter_test/src/test_async_utils.dart:74:41)
#6      WidgetTester.showKeyboard (package:flutter_test/src/widget_tester.dart:1124:27)
#7      WidgetTester.enterText.<anonymous closure> (package:flutter_test/src/widget_tester.dart:1160:13)
#10     TestAsyncUtils.guard (package:flutter_test/src/test_async_utils.dart:74:41)
#11     WidgetTester.enterText (package:flutter_test/src/widget_tester.dart:1159:27)
#12     main.<anonymous closure> (file:///workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/account_state_widget_test.dart:1666:20)
<asynchronous suspension>
#13     testWidgets.<anonymous closure>.<anonymous closure> (package:flutter_test/src/widget_tester.dart:192:15)
<asynchronous suspension>
#14     TestWidgetsFlutterBinding._runTestBody (package:flutter_test/src/binding.dart:1682:5)
<asynchronous suspension>
<asynchronous suspension>
(elided 5 frames from dart:async and package:stack_trace)

The test description was:
  pending private write blocks shell navigation and browser back until saved
════════════════════════════════════════════════════════════════════════════════════════════════════
══╡ EXCEPTION CAUGHT BY FLUTTER TEST FRAMEWORK ╞════════════════════════════════════════════════════
The following message was thrown:
Multiple exceptions (3) were detected during the running of the current test, and at least one was
unexpected.
════════════════════════════════════════════════════════════════════════════════════════════════════
00:08 +48 -19: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/guest_interact_widget_test.dart: required Knowledge and session fields show inline errors
00:08 +48 -19: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/account_state_widget_test.dart: pending private write blocks shell navigation and browser back until saved [E]
  Test failed. See exception logs above.
  The test description was: pending private write blocks shell navigation and browser back until saved
  
00:08 +48 -19: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/account_state_widget_test.dart: UID transition isolates queued writes while an earlier create is unresolved
══╡ EXCEPTION CAUGHT BY RENDERING LIBRARY ╞═════════════════════════════════════════════════════════
The following assertion was thrown during layout:
A RenderFlex overflowed by 10.0 pixels on the bottom.

The relevant error-causing widget was:
  AppBar
  AppBar:file:///workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/lib/features/guest/presentation/guest_workspace_page.dart:1663:19

The overflowing RenderFlex has an orientation of Axis.vertical.
The edge of the RenderFlex that is overflowing has been marked in the rendering with a yellow and
black striped pattern. This is usually caused by the contents being too big for the RenderFlex.
Consider applying a flex factor (e.g. using an Expanded widget) to force the children of the
RenderFlex to fit within the available space instead of being sized to their natural size.
This is considered an error condition because it indicates that there is content that cannot be
seen. If the content is legitimately bigger than the available space, consider clipping it with a
ClipRect widget before putting it in the flex, or using a scrollable container rather than a Flex,
like a ListView.
The specific RenderFlex in question is: RenderFlex#02f01 relayoutBoundary=up9 OVERFLOWING:
  creator: Column ← MediaQuery ← Padding ← SafeArea ← Align ← Semantics ← DefaultTextStyle ←
    AnimatedDefaultTextStyle ← _InkFeatures-[GlobalKey#5ae0b ink renderer] ←
    NotificationListener<LayoutChangedNotification> ← PhysicalModel ← AnimatedPhysicalModel ← ⋯
  parentData: offset=Offset(0.0, 0.0) (can use size)
  constraints: BoxConstraints(0.0<=w<=240.0, 0.0<=h<=64.0)
  size: Size(240.0, 64.0)
  direction: vertical
  mainAxisAlignment: spaceBetween
  mainAxisSize: max
  crossAxisAlignment: center
  verticalDirection: down
  spacing: 0.0
◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤
════════════════════════════════════════════════════════════════════════════════════════════════════
══╡ EXCEPTION CAUGHT BY RENDERING LIBRARY ╞═════════════════════════════════════════════════════════
The following assertion was thrown during layout:
A RenderFlex overflowed by 228 pixels on the right.

The relevant error-causing widget was:
  AppBar
  AppBar:file:///workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/lib/shared/widgets/app_shell.dart:299:15

The overflowing RenderFlex has an orientation of Axis.horizontal.
The edge of the RenderFlex that is overflowing has been marked in the rendering with a yellow and
black striped pattern. This is usually caused by the contents being too big for the RenderFlex.
Consider applying a flex factor (e.g. using an Expanded widget) to force the children of the
RenderFlex to fit within the available space instead of being sized to their natural size.
This is considered an error condition because it indicates that there is content that cannot be
seen. If the content is legitimately bigger than the available space, consider clipping it with a
ClipRect widget before putting it in the flex, or using a scrollable container rather than a Flex,
like a ListView.
The specific RenderFlex in question is: RenderFlex#19063 relayoutBoundary=up13 OVERFLOWING:
  creator: Row ← Padding ← IconTheme ← Builder ← IconButtonTheme ← LayoutId-[<_ToolbarSlot.trailing>]
    ← CustomMultiChildLayout ← NavigationToolbar ← DefaultTextStyle ← IconTheme ← Builder ←
    CustomSingleChildLayout ← ⋯
  parentData: offset=Offset(0.0, 0.0) (can use size)
  constraints: BoxConstraints(0.0<=w<=240.0, 0.0<=h<=56.0)
  size: Size(240.0, 24.0)
  direction: horizontal
  mainAxisAlignment: start
  mainAxisSize: min
  crossAxisAlignment: center
  textDirection: ltr
  verticalDirection: down
  spacing: 0.0
◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤
════════════════════════════════════════════════════════════════════════════════════════════════════
00:09 +48 -19: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/guest_interact_widget_test.dart: required Knowledge and session fields show inline errors
══╡ EXCEPTION CAUGHT BY FLUTTER TEST FRAMEWORK ╞════════════════════════════════════════════════════
The following StateError was thrown running a test:
Bad state: No element

When the exception was thrown, this was the stack:
#0      Iterable.single (dart:core/iterable.dart:694:25)
#1      WidgetController.element (package:flutter_test/src/controller.dart:883:30)
#2      WidgetController.ensureVisible (package:flutter_test/src/controller.dart:2382:32)
#3      main.<anonymous closure> (file:///workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/guest_interact_widget_test.dart:1224:18)
<asynchronous suspension>
#4      testWidgets.<anonymous closure>.<anonymous closure> (package:flutter_test/src/widget_tester.dart:192:15)
<asynchronous suspension>
#5      TestWidgetsFlutterBinding._runTestBody (package:flutter_test/src/binding.dart:1682:5)
<asynchronous suspension>
<asynchronous suspension>
(elided one frame from package:stack_trace)

The test description was:
  required Knowledge and session fields show inline errors
════════════════════════════════════════════════════════════════════════════════════════════════════
00:09 +48 -20: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/account_state_widget_test.dart: UID transition isolates queued writes while an earlier create is unresolved
00:09 +48 -20: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/guest_interact_widget_test.dart: required Knowledge and session fields show inline errors [E]
  Test failed. See exception logs above.
  The test description was: required Knowledge and session fields show inline errors
  
00:09 +48 -20: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/account_state_widget_test.dart: UID transition isolates queued writes while an earlier create is unresolved
══╡ EXCEPTION CAUGHT BY FLUTTER TEST FRAMEWORK ╞════════════════════════════════════════════════════
The following StateError was thrown running a test:
Bad state: No element

When the exception was thrown, this was the stack:
#0      Iterable.single (dart:core/iterable.dart:694:25)
#1      WidgetController.state (package:flutter_test/src/controller.dart:927:42)
#2      WidgetTester.showKeyboard.<anonymous closure> (package:flutter_test/src/widget_tester.dart:1125:42)
#5      TestAsyncUtils.guard (package:flutter_test/src/test_async_utils.dart:74:41)
#6      WidgetTester.showKeyboard (package:flutter_test/src/widget_tester.dart:1124:27)
#7      WidgetTester.enterText.<anonymous closure> (package:flutter_test/src/widget_tester.dart:1160:13)
#10     TestAsyncUtils.guard (package:flutter_test/src/test_async_utils.dart:74:41)
#11     WidgetTester.enterText (package:flutter_test/src/widget_tester.dart:1159:27)
#12     main.<anonymous closure> (file:///workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/account_state_widget_test.dart:1738:20)
<asynchronous suspension>
#13     testWidgets.<anonymous closure>.<anonymous closure> (package:flutter_test/src/widget_tester.dart:192:15)
<asynchronous suspension>
#14     TestWidgetsFlutterBinding._runTestBody (package:flutter_test/src/binding.dart:1682:5)
<asynchronous suspension>
<asynchronous suspension>
(elided 5 frames from dart:async and package:stack_trace)

The test description was:
  UID transition isolates queued writes while an earlier create is unresolved
════════════════════════════════════════════════════════════════════════════════════════════════════
══╡ EXCEPTION CAUGHT BY FLUTTER TEST FRAMEWORK ╞════════════════════════════════════════════════════
The following message was thrown:
Multiple exceptions (3) were detected during the running of the current test, and at least one was
unexpected.
════════════════════════════════════════════════════════════════════════════════════════════════════
00:09 +48 -21: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/account_state_widget_test.dart: UID transition isolates queued writes while an earlier create is unresolved [E]
  Test failed. See exception logs above.
  The test description was: UID transition isolates queued writes while an earlier create is unresolved
  
00:09 +48 -21: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/account_state_widget_test.dart: deleting during uncertain create confirms creation before account deletion
══╡ EXCEPTION CAUGHT BY FLUTTER TEST FRAMEWORK ╞════════════════════════════════════════════════════
The following assertion was thrown running a test:
The finder "Found 0 widgets with widget matching predicate: []" (used in a call to "tap()") could
not find any matching widgets.

When the exception was thrown, this was the stack:
#0      WidgetController._getElementPoint (package:flutter_test/src/controller.dart:2090:7)
#1      WidgetController.getCenter (package:flutter_test/src/controller.dart:1942:12)
#2      WidgetController.tap (package:flutter_test/src/controller.dart:1075:7)
#3      main.<anonymous closure> (file:///workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/account_state_widget_test.dart:1813:20)
<asynchronous suspension>
#4      testWidgets.<anonymous closure>.<anonymous closure> (package:flutter_test/src/widget_tester.dart:192:15)
<asynchronous suspension>
#5      TestWidgetsFlutterBinding._runTestBody (package:flutter_test/src/binding.dart:1682:5)
<asynchronous suspension>
<asynchronous suspension>
(elided one frame from package:stack_trace)

The test description was:
  deleting during uncertain create confirms creation before account deletion
════════════════════════════════════════════════════════════════════════════════════════════════════
00:09 +48 -22: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/account_state_widget_test.dart: deleting during uncertain create confirms creation before account deletion [E]
  Test failed. See exception logs above.
  The test description was: deleting during uncertain create confirms creation before account deletion
  
00:09 +48 -22: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/account_state_widget_test.dart: personal refresh overlapping a create cannot replace the acknowledged item
══╡ EXCEPTION CAUGHT BY FLUTTER TEST FRAMEWORK ╞════════════════════════════════════════════════════
The following TestFailure was thrown running a test:
Expected: exactly one matching candidate
  Actual: _TextWidgetFinder:<Found 0 widgets with text "Refresh race question": []>
   Which: means none were found but one was expected

When the exception was thrown, this was the stack:
#4      main.<anonymous closure> (file:///workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/account_state_widget_test.dart:1862:7)
<asynchronous suspension>
#5      testWidgets.<anonymous closure>.<anonymous closure> (package:flutter_test/src/widget_tester.dart:192:15)
<asynchronous suspension>
#6      TestWidgetsFlutterBinding._runTestBody (package:flutter_test/src/binding.dart:1682:5)
<asynchronous suspension>
<asynchronous suspension>
(elided one frame from package:stack_trace)

This was caught by the test expectation on the following line:
  file:///workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/account_state_widget_test.dart line 1862
The test description was:
  personal refresh overlapping a create cannot replace the acknowledged item
════════════════════════════════════════════════════════════════════════════════════════════════════
00:09 +48 -23: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/account_state_widget_test.dart: personal refresh overlapping a create cannot replace the acknowledged item [E]
  Test failed. See exception logs above.
  The test description was: personal refresh overlapping a create cannot replace the acknowledged item
  
00:09 +48 -23: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/account_state_widget_test.dart: pending selected account import blocks shell navigation until confirmed
══╡ EXCEPTION CAUGHT BY RENDERING LIBRARY ╞═════════════════════════════════════════════════════════
The following assertion was thrown during layout:
A RenderFlex overflowed by 285 pixels on the right.

The relevant error-causing widget was:
  AppBar
  AppBar:file:///workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/lib/shared/widgets/app_shell.dart:299:15

The overflowing RenderFlex has an orientation of Axis.horizontal.
The edge of the RenderFlex that is overflowing has been marked in the rendering with a yellow and
black striped pattern. This is usually caused by the contents being too big for the RenderFlex.
Consider applying a flex factor (e.g. using an Expanded widget) to force the children of the
RenderFlex to fit within the available space instead of being sized to their natural size.
This is considered an error condition because it indicates that there is content that cannot be
seen. If the content is legitimately bigger than the available space, consider clipping it with a
ClipRect widget before putting it in the flex, or using a scrollable container rather than a Flex,
like a ListView.
The specific RenderFlex in question is: RenderFlex#f0c66 relayoutBoundary=up13 OVERFLOWING:
  creator: Row ← Padding ← IconTheme ← Builder ← IconButtonTheme ← LayoutId-[<_ToolbarSlot.trailing>]
    ← CustomMultiChildLayout ← NavigationToolbar ← DefaultTextStyle ← IconTheme ← Builder ←
    CustomSingleChildLayout ← ⋯
  parentData: offset=Offset(0.0, 0.0) (can use size)
  constraints: BoxConstraints(0.0<=w<=240.0, 0.0<=h<=56.0)
  size: Size(240.0, 24.0)
  direction: horizontal
  mainAxisAlignment: start
  mainAxisSize: min
  crossAxisAlignment: center
  textDirection: ltr
  verticalDirection: down
  spacing: 0.0
◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤
════════════════════════════════════════════════════════════════════════════════════════════════════
══╡ EXCEPTION CAUGHT BY RENDERING LIBRARY ╞═════════════════════════════════════════════════════════
The following assertion was thrown during layout:
A RenderFlex overflowed by 56 pixels on the right.

The relevant error-causing widget was:
  MaterialBanner
  MaterialBanner:file:///workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/lib/features/guest/presentation/guest_workspace_page.dart:1780:23

The overflowing RenderFlex has an orientation of Axis.horizontal.
The edge of the RenderFlex that is overflowing has been marked in the rendering with a yellow and
black striped pattern. This is usually caused by the contents being too big for the RenderFlex.
Consider applying a flex factor (e.g. using an Expanded widget) to force the children of the
RenderFlex to fit within the available space instead of being sized to their natural size.
This is considered an error condition because it indicates that there is content that cannot be
seen. If the content is legitimately bigger than the available space, consider clipping it with a
ClipRect widget before putting it in the flex, or using a scrollable container rather than a Flex,
like a ListView.
The specific RenderFlex in question is: RenderFlex#64a35 relayoutBoundary=up18 OVERFLOWING:
  creator: Row ← Padding ← Column ← DefaultTextStyle ← AnimatedDefaultTextStyle ←
    _InkFeatures-[GlobalKey#5195d ink renderer] ← NotificationListener<LayoutChangedNotification> ←
    PhysicalModel ← AnimatedPhysicalModel ← Material ← Padding ← MaterialBanner ← ⋯
  parentData: offset=Offset(16.0, 2.0) (can use size)
  constraints: BoxConstraints(0.0<=w<=224.0, 0.0<=h<=Infinity)
  size: Size(224.0, 2200.0)
  direction: horizontal
  mainAxisAlignment: start
  mainAxisSize: max
  crossAxisAlignment: center
  textDirection: ltr
  verticalDirection: down
  spacing: 0.0
◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤
════════════════════════════════════════════════════════════════════════════════════════════════════
══╡ EXCEPTION CAUGHT BY RENDERING LIBRARY ╞═════════════════════════════════════════════════════════
The following assertion was thrown during layout:
A RenderFlex overflowed by 10.0 pixels on the bottom.

The relevant error-causing widget was:
  AppBar
  AppBar:file:///workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/lib/features/guest/presentation/guest_workspace_page.dart:1663:19

The overflowing RenderFlex has an orientation of Axis.vertical.
The edge of the RenderFlex that is overflowing has been marked in the rendering with a yellow and
black striped pattern. This is usually caused by the contents being too big for the RenderFlex.
Consider applying a flex factor (e.g. using an Expanded widget) to force the children of the
RenderFlex to fit within the available space instead of being sized to their natural size.
This is considered an error condition because it indicates that there is content that cannot be
seen. If the content is legitimately bigger than the available space, consider clipping it with a
ClipRect widget before putting it in the flex, or using a scrollable container rather than a Flex,
like a ListView.
The specific RenderFlex in question is: RenderFlex#d42b5 relayoutBoundary=up9 OVERFLOWING:
  creator: Column ← MediaQuery ← Padding ← SafeArea ← Align ← Semantics ← DefaultTextStyle ←
    AnimatedDefaultTextStyle ← _InkFeatures-[GlobalKey#87dba ink renderer] ←
    NotificationListener<LayoutChangedNotification> ← PhysicalModel ← AnimatedPhysicalModel ← ⋯
  parentData: offset=Offset(0.0, 0.0) (can use size)
  constraints: BoxConstraints(0.0<=w<=240.0, 0.0<=h<=64.0)
  size: Size(240.0, 64.0)
  direction: vertical
  mainAxisAlignment: spaceBetween
  mainAxisSize: max
  crossAxisAlignment: center
  verticalDirection: down
  spacing: 0.0
◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤
════════════════════════════════════════════════════════════════════════════════════════════════════

Warning: A call to tap() with finder "Found 1 widget with text "Import local work": [
  Text("Import local work", dependencies: [DefaultSelectionStyle, DefaultTextStyle, MediaQuery]),
]" derived an Offset (Offset(155.8, 1350.0)) that would not hit test on the specified widget.
Maybe the widget is actually off-screen, or another widget is obscuring it, or the widget cannot receive pointer events.
Indeed, Offset(155.8, 1350.0) is outside the bounds of the root of the render tree, Size(240.0, 200.0).
The finder corresponds to this RenderBox: RenderParagraph#a3b98 relayoutBoundary=up35
The hit test result at that offset is: HitTestResult(HitTestEntry<HitTestTarget>#040a1(_ReusableRenderView#f4e0c), HitTestEntry<HitTestTarget>#1f3d0(<AutomatedTestWidgetsFlutterBinding>))
#0      WidgetController._getElementPoint (package:flutter_test/src/controller.dart:2158:25)
#1      WidgetController.getCenter (package:flutter_test/src/controller.dart:1942:12)
#2      WidgetController.tap (package:flutter_test/src/controller.dart:1075:7)
#3      main.<anonymous closure> (file:///workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/account_state_widget_test.dart:1895:20)
<asynchronous suspension>
#4      testWidgets.<anonymous closure>.<anonymous closure> (package:flutter_test/src/widget_tester.dart:192:15)
<asynchronous suspension>
#5      TestWidgetsFlutterBinding._runTestBody (package:flutter_test/src/binding.dart:1682:5)
<asynchronous suspension>
#6      StackZoneSpecification._registerCallback.<anonymous closure> (package:stack_trace/src/stack_zone_specification.dart:114:42)
<asynchronous suspension>
To silence this warning, pass "warnIfMissed: false" to "tap()".
To make this warning fatal, set WidgetController.hitTestWarningShouldBeFatal to true.

══╡ EXCEPTION CAUGHT BY FLUTTER TEST FRAMEWORK ╞════════════════════════════════════════════════════
The following assertion was thrown running a test:
The finder "Found 0 widgets with text "Import selected work": []" (used in a call to "tap()") could
not find any matching widgets.

When the exception was thrown, this was the stack:
#0      WidgetController._getElementPoint (package:flutter_test/src/controller.dart:2090:7)
#1      WidgetController.getCenter (package:flutter_test/src/controller.dart:1942:12)
#2      WidgetController.tap (package:flutter_test/src/controller.dart:1075:7)
#3      main.<anonymous closure> (file:///workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/account_state_widget_test.dart:1897:20)
<asynchronous suspension>
#4      testWidgets.<anonymous closure>.<anonymous closure> (package:flutter_test/src/widget_tester.dart:192:15)
<asynchronous suspension>
#5      TestWidgetsFlutterBinding._runTestBody (package:flutter_test/src/binding.dart:1682:5)
<asynchronous suspension>
<asynchronous suspension>
(elided one frame from package:stack_trace)

The test description was:
  pending selected account import blocks shell navigation until confirmed
════════════════════════════════════════════════════════════════════════════════════════════════════
══╡ EXCEPTION CAUGHT BY FLUTTER TEST FRAMEWORK ╞════════════════════════════════════════════════════
The following message was thrown:
Multiple exceptions (4) were detected during the running of the current test, and at least one was
unexpected.
════════════════════════════════════════════════════════════════════════════════════════════════════
00:10 +48 -24: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/account_state_widget_test.dart: pending selected account import blocks shell navigation until confirmed [E]
  Test failed. See exception logs above.
  The test description was: pending selected account import blocks shell navigation until confirmed
  
00:10 +48 -24: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/account_state_widget_test.dart: permanent import rejection releases navigation while transient failure stays guarded
══╡ EXCEPTION CAUGHT BY RENDERING LIBRARY ╞═════════════════════════════════════════════════════════
The following assertion was thrown during layout:
A RenderFlex overflowed by 10.0 pixels on the bottom.

The relevant error-causing widget was:
  AppBar
  AppBar:file:///workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/lib/features/guest/presentation/guest_workspace_page.dart:1663:19

The overflowing RenderFlex has an orientation of Axis.vertical.
The edge of the RenderFlex that is overflowing has been marked in the rendering with a yellow and
black striped pattern. This is usually caused by the contents being too big for the RenderFlex.
Consider applying a flex factor (e.g. using an Expanded widget) to force the children of the
RenderFlex to fit within the available space instead of being sized to their natural size.
This is considered an error condition because it indicates that there is content that cannot be
seen. If the content is legitimately bigger than the available space, consider clipping it with a
ClipRect widget before putting it in the flex, or using a scrollable container rather than a Flex,
like a ListView.
The specific RenderFlex in question is: RenderFlex#6d66e relayoutBoundary=up9 OVERFLOWING:
  creator: Column ← MediaQuery ← Padding ← SafeArea ← Align ← Semantics ← DefaultTextStyle ←
    AnimatedDefaultTextStyle ← _InkFeatures-[GlobalKey#7eefa ink renderer] ←
    NotificationListener<LayoutChangedNotification> ← PhysicalModel ← AnimatedPhysicalModel ← ⋯
  parentData: offset=Offset(0.0, 0.0) (can use size)
  constraints: BoxConstraints(0.0<=w<=240.0, 0.0<=h<=64.0)
  size: Size(240.0, 64.0)
  direction: vertical
  mainAxisAlignment: spaceBetween
  mainAxisSize: max
  crossAxisAlignment: center
  verticalDirection: down
  spacing: 0.0
◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤
════════════════════════════════════════════════════════════════════════════════════════════════════
══╡ EXCEPTION CAUGHT BY RENDERING LIBRARY ╞═════════════════════════════════════════════════════════
The following assertion was thrown during layout:
A RenderFlex overflowed by 56 pixels on the right.

The relevant error-causing widget was:
  MaterialBanner
  MaterialBanner:file:///workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/lib/features/guest/presentation/guest_workspace_page.dart:1780:23

The overflowing RenderFlex has an orientation of Axis.horizontal.
The edge of the RenderFlex that is overflowing has been marked in the rendering with a yellow and
black striped pattern. This is usually caused by the contents being too big for the RenderFlex.
Consider applying a flex factor (e.g. using an Expanded widget) to force the children of the
RenderFlex to fit within the available space instead of being sized to their natural size.
This is considered an error condition because it indicates that there is content that cannot be
seen. If the content is legitimately bigger than the available space, consider clipping it with a
ClipRect widget before putting it in the flex, or using a scrollable container rather than a Flex,
like a ListView.
The specific RenderFlex in question is: RenderFlex#d7447 relayoutBoundary=up18 OVERFLOWING:
  creator: Row ← Padding ← Column ← DefaultTextStyle ← AnimatedDefaultTextStyle ←
    _InkFeatures-[GlobalKey#85c5e ink renderer] ← NotificationListener<LayoutChangedNotification> ←
    PhysicalModel ← AnimatedPhysicalModel ← Material ← Padding ← MaterialBanner ← ⋯
  parentData: offset=Offset(16.0, 2.0) (can use size)
  constraints: BoxConstraints(0.0<=w<=224.0, 0.0<=h<=Infinity)
  size: Size(224.0, 2200.0)
  direction: horizontal
  mainAxisAlignment: start
  mainAxisSize: max
  crossAxisAlignment: center
  textDirection: ltr
  verticalDirection: down
  spacing: 0.0
◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤
════════════════════════════════════════════════════════════════════════════════════════════════════
══╡ EXCEPTION CAUGHT BY RENDERING LIBRARY ╞═════════════════════════════════════════════════════════
The following assertion was thrown during layout:
A RenderFlex overflowed by 228 pixels on the right.

The relevant error-causing widget was:
  AppBar
  AppBar:file:///workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/lib/shared/widgets/app_shell.dart:299:15

The overflowing RenderFlex has an orientation of Axis.horizontal.
The edge of the RenderFlex that is overflowing has been marked in the rendering with a yellow and
black striped pattern. This is usually caused by the contents being too big for the RenderFlex.
Consider applying a flex factor (e.g. using an Expanded widget) to force the children of the
RenderFlex to fit within the available space instead of being sized to their natural size.
This is considered an error condition because it indicates that there is content that cannot be
seen. If the content is legitimately bigger than the available space, consider clipping it with a
ClipRect widget before putting it in the flex, or using a scrollable container rather than a Flex,
like a ListView.
The specific RenderFlex in question is: RenderFlex#d49b7 relayoutBoundary=up13 OVERFLOWING:
  creator: Row ← Padding ← IconTheme ← Builder ← IconButtonTheme ← LayoutId-[<_ToolbarSlot.trailing>]
    ← CustomMultiChildLayout ← NavigationToolbar ← DefaultTextStyle ← IconTheme ← Builder ←
    CustomSingleChildLayout ← ⋯
  parentData: offset=Offset(0.0, 0.0) (can use size)
  constraints: BoxConstraints(0.0<=w<=240.0, 0.0<=h<=56.0)
  size: Size(240.0, 24.0)
  direction: horizontal
  mainAxisAlignment: start
  mainAxisSize: min
  crossAxisAlignment: center
  textDirection: ltr
  verticalDirection: down
  spacing: 0.0
◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤
════════════════════════════════════════════════════════════════════════════════════════════════════

Warning: A call to tap() with finder "Found 1 widget with text "Import local work": [
  Text("Import local work", dependencies: [DefaultSelectionStyle, DefaultTextStyle, MediaQuery]),
]" derived an Offset (Offset(155.8, 1350.0)) that would not hit test on the specified widget.
Maybe the widget is actually off-screen, or another widget is obscuring it, or the widget cannot receive pointer events.
Indeed, Offset(155.8, 1350.0) is outside the bounds of the root of the render tree, Size(240.0, 200.0).
The finder corresponds to this RenderBox: RenderParagraph#e2603 relayoutBoundary=up35
The hit test result at that offset is: HitTestResult(HitTestEntry<HitTestTarget>#eba77(_ReusableRenderView#f4e0c), HitTestEntry<HitTestTarget>#4fdc4(<AutomatedTestWidgetsFlutterBinding>))
#0      WidgetController._getElementPoint (package:flutter_test/src/controller.dart:2158:25)
#1      WidgetController.getCenter (package:flutter_test/src/controller.dart:1942:12)
#2      WidgetController.tap (package:flutter_test/src/controller.dart:1075:7)
#3      main.<anonymous closure> (file:///workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/account_state_widget_test.dart:1939:20)
<asynchronous suspension>
#4      testWidgets.<anonymous closure>.<anonymous closure> (package:flutter_test/src/widget_tester.dart:192:15)
<asynchronous suspension>
#5      TestWidgetsFlutterBinding._runTestBody (package:flutter_test/src/binding.dart:1682:5)
<asynchronous suspension>
#6      StackZoneSpecification._registerCallback.<anonymous closure> (package:stack_trace/src/stack_zone_specification.dart:114:42)
<asynchronous suspension>
To silence this warning, pass "warnIfMissed: false" to "tap()".
To make this warning fatal, set WidgetController.hitTestWarningShouldBeFatal to true.

══╡ EXCEPTION CAUGHT BY FLUTTER TEST FRAMEWORK ╞════════════════════════════════════════════════════
The following assertion was thrown running a test:
The finder "Found 0 widgets with text "Import selected work": []" (used in a call to "tap()") could
not find any matching widgets.

When the exception was thrown, this was the stack:
#0      WidgetController._getElementPoint (package:flutter_test/src/controller.dart:2090:7)
#1      WidgetController.getCenter (package:flutter_test/src/controller.dart:1942:12)
#2      WidgetController.tap (package:flutter_test/src/controller.dart:1075:7)
#3      main.<anonymous closure> (file:///workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/account_state_widget_test.dart:1941:20)
<asynchronous suspension>
#4      testWidgets.<anonymous closure>.<anonymous closure> (package:flutter_test/src/widget_tester.dart:192:15)
<asynchronous suspension>
#5      TestWidgetsFlutterBinding._runTestBody (package:flutter_test/src/binding.dart:1682:5)
<asynchronous suspension>
<asynchronous suspension>
(elided one frame from package:stack_trace)

The test description was:
  permanent import rejection releases navigation while transient failure stays guarded
════════════════════════════════════════════════════════════════════════════════════════════════════
══╡ EXCEPTION CAUGHT BY FLUTTER TEST FRAMEWORK ╞════════════════════════════════════════════════════
The following message was thrown:
Multiple exceptions (4) were detected during the running of the current test, and at least one was
unexpected.
════════════════════════════════════════════════════════════════════════════════════════════════════
00:10 +48 -25: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/account_state_widget_test.dart: permanent import rejection releases navigation while transient failure stays guarded [E]
  Test failed. See exception logs above.
  The test description was: permanent import rejection releases navigation while transient failure stays guarded
  
00:10 +48 -25: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/account_state_widget_test.dart: unconfirmed account import remains guarded and retains its local original
══╡ EXCEPTION CAUGHT BY RENDERING LIBRARY ╞═════════════════════════════════════════════════════════
The following assertion was thrown during layout:
A RenderFlex overflowed by 10.0 pixels on the bottom.

The relevant error-causing widget was:
  AppBar
  AppBar:file:///workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/lib/features/guest/presentation/guest_workspace_page.dart:1663:19

The overflowing RenderFlex has an orientation of Axis.vertical.
The edge of the RenderFlex that is overflowing has been marked in the rendering with a yellow and
black striped pattern. This is usually caused by the contents being too big for the RenderFlex.
Consider applying a flex factor (e.g. using an Expanded widget) to force the children of the
RenderFlex to fit within the available space instead of being sized to their natural size.
This is considered an error condition because it indicates that there is content that cannot be
seen. If the content is legitimately bigger than the available space, consider clipping it with a
ClipRect widget before putting it in the flex, or using a scrollable container rather than a Flex,
like a ListView.
The specific RenderFlex in question is: RenderFlex#bc23e relayoutBoundary=up9 OVERFLOWING:
  creator: Column ← MediaQuery ← Padding ← SafeArea ← Align ← Semantics ← DefaultTextStyle ←
    AnimatedDefaultTextStyle ← _InkFeatures-[GlobalKey#7a769 ink renderer] ←
    NotificationListener<LayoutChangedNotification> ← PhysicalModel ← AnimatedPhysicalModel ← ⋯
  parentData: offset=Offset(0.0, 0.0) (can use size)
  constraints: BoxConstraints(0.0<=w<=240.0, 0.0<=h<=64.0)
  size: Size(240.0, 64.0)
  direction: vertical
  mainAxisAlignment: spaceBetween
  mainAxisSize: max
  crossAxisAlignment: center
  verticalDirection: down
  spacing: 0.0
◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤
════════════════════════════════════════════════════════════════════════════════════════════════════
══╡ EXCEPTION CAUGHT BY RENDERING LIBRARY ╞═════════════════════════════════════════════════════════
The following assertion was thrown during layout:
A RenderFlex overflowed by 56 pixels on the right.

The relevant error-causing widget was:
  MaterialBanner
  MaterialBanner:file:///workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/lib/features/guest/presentation/guest_workspace_page.dart:1780:23

The overflowing RenderFlex has an orientation of Axis.horizontal.
The edge of the RenderFlex that is overflowing has been marked in the rendering with a yellow and
black striped pattern. This is usually caused by the contents being too big for the RenderFlex.
Consider applying a flex factor (e.g. using an Expanded widget) to force the children of the
RenderFlex to fit within the available space instead of being sized to their natural size.
This is considered an error condition because it indicates that there is content that cannot be
seen. If the content is legitimately bigger than the available space, consider clipping it with a
ClipRect widget before putting it in the flex, or using a scrollable container rather than a Flex,
like a ListView.
The specific RenderFlex in question is: RenderFlex#7d2f5 relayoutBoundary=up18 OVERFLOWING:
  creator: Row ← Padding ← Column ← DefaultTextStyle ← AnimatedDefaultTextStyle ←
    _InkFeatures-[GlobalKey#f399e ink renderer] ← NotificationListener<LayoutChangedNotification> ←
    PhysicalModel ← AnimatedPhysicalModel ← Material ← Padding ← MaterialBanner ← ⋯
  parentData: offset=Offset(16.0, 2.0) (can use size)
  constraints: BoxConstraints(0.0<=w<=224.0, 0.0<=h<=Infinity)
  size: Size(224.0, 2200.0)
  direction: horizontal
  mainAxisAlignment: start
  mainAxisSize: max
  crossAxisAlignment: center
  textDirection: ltr
  verticalDirection: down
  spacing: 0.0
◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤
════════════════════════════════════════════════════════════════════════════════════════════════════
══╡ EXCEPTION CAUGHT BY RENDERING LIBRARY ╞═════════════════════════════════════════════════════════
The following assertion was thrown during layout:
A RenderFlex overflowed by 228 pixels on the right.

The relevant error-causing widget was:
  AppBar
  AppBar:file:///workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/lib/shared/widgets/app_shell.dart:299:15

The overflowing RenderFlex has an orientation of Axis.horizontal.
The edge of the RenderFlex that is overflowing has been marked in the rendering with a yellow and
black striped pattern. This is usually caused by the contents being too big for the RenderFlex.
Consider applying a flex factor (e.g. using an Expanded widget) to force the children of the
RenderFlex to fit within the available space instead of being sized to their natural size.
This is considered an error condition because it indicates that there is content that cannot be
seen. If the content is legitimately bigger than the available space, consider clipping it with a
ClipRect widget before putting it in the flex, or using a scrollable container rather than a Flex,
like a ListView.
The specific RenderFlex in question is: RenderFlex#232d9 relayoutBoundary=up13 OVERFLOWING:
  creator: Row ← Padding ← IconTheme ← Builder ← IconButtonTheme ← LayoutId-[<_ToolbarSlot.trailing>]
    ← CustomMultiChildLayout ← NavigationToolbar ← DefaultTextStyle ← IconTheme ← Builder ←
    CustomSingleChildLayout ← ⋯
  parentData: offset=Offset(0.0, 0.0) (can use size)
  constraints: BoxConstraints(0.0<=w<=240.0, 0.0<=h<=56.0)
  size: Size(240.0, 24.0)
  direction: horizontal
  mainAxisAlignment: start
  mainAxisSize: min
  crossAxisAlignment: center
  textDirection: ltr
  verticalDirection: down
  spacing: 0.0
◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤
════════════════════════════════════════════════════════════════════════════════════════════════════

Warning: A call to tap() with finder "Found 1 widget with text "Import local work": [
  Text("Import local work", dependencies: [DefaultSelectionStyle, DefaultTextStyle, MediaQuery]),
]" derived an Offset (Offset(155.8, 1350.0)) that would not hit test on the specified widget.
Maybe the widget is actually off-screen, or another widget is obscuring it, or the widget cannot receive pointer events.
Indeed, Offset(155.8, 1350.0) is outside the bounds of the root of the render tree, Size(240.0, 200.0).
The finder corresponds to this RenderBox: RenderParagraph#ea0df relayoutBoundary=up35
The hit test result at that offset is: HitTestResult(HitTestEntry<HitTestTarget>#1f8d9(_ReusableRenderView#f4e0c), HitTestEntry<HitTestTarget>#5957b(<AutomatedTestWidgetsFlutterBinding>))
#0      WidgetController._getElementPoint (package:flutter_test/src/controller.dart:2158:25)
#1      WidgetController.getCenter (package:flutter_test/src/controller.dart:1942:12)
#2      WidgetController.tap (package:flutter_test/src/controller.dart:1075:7)
#3      main.<anonymous closure> (file:///workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/account_state_widget_test.dart:1976:20)
<asynchronous suspension>
#4      testWidgets.<anonymous closure>.<anonymous closure> (package:flutter_test/src/widget_tester.dart:192:15)
<asynchronous suspension>
#5      TestWidgetsFlutterBinding._runTestBody (package:flutter_test/src/binding.dart:1682:5)
<asynchronous suspension>
#6      StackZoneSpecification._registerCallback.<anonymous closure> (package:stack_trace/src/stack_zone_specification.dart:114:42)
<asynchronous suspension>
To silence this warning, pass "warnIfMissed: false" to "tap()".
To make this warning fatal, set WidgetController.hitTestWarningShouldBeFatal to true.

══╡ EXCEPTION CAUGHT BY FLUTTER TEST FRAMEWORK ╞════════════════════════════════════════════════════
The following assertion was thrown running a test:
The finder "Found 0 widgets with text "Import selected work": []" (used in a call to "tap()") could
not find any matching widgets.

When the exception was thrown, this was the stack:
#0      WidgetController._getElementPoint (package:flutter_test/src/controller.dart:2090:7)
#1      WidgetController.getCenter (package:flutter_test/src/controller.dart:1942:12)
#2      WidgetController.tap (package:flutter_test/src/controller.dart:1075:7)
#3      main.<anonymous closure> (file:///workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/account_state_widget_test.dart:1978:20)
<asynchronous suspension>
#4      testWidgets.<anonymous closure>.<anonymous closure> (package:flutter_test/src/widget_tester.dart:192:15)
<asynchronous suspension>
#5      TestWidgetsFlutterBinding._runTestBody (package:flutter_test/src/binding.dart:1682:5)
<asynchronous suspension>
<asynchronous suspension>
(elided one frame from package:stack_trace)

The test description was:
  unconfirmed account import remains guarded and retains its local original
════════════════════════════════════════════════════════════════════════════════════════════════════
══╡ EXCEPTION CAUGHT BY FLUTTER TEST FRAMEWORK ╞════════════════════════════════════════════════════
The following message was thrown:
Multiple exceptions (4) were detected during the running of the current test, and at least one was
unexpected.
════════════════════════════════════════════════════════════════════════════════════════════════════
00:11 +48 -26: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/account_state_widget_test.dart: unconfirmed account import remains guarded and retains its local original [E]
  Test failed. See exception logs above.
  The test description was: unconfirmed account import remains guarded and retains its local original
  
00:11 +48 -26: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/account_state_widget_test.dart: new verified-user Interact sessions save privately by default
00:11 +49 -26: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/account_state_widget_test.dart: existing-account sign-in errors do not reveal Firebase details
00:11 +50 -26: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/account_state_widget_test.dart: unexpected sign-in errors show a safe recovery message
00:11 +51 -26: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/account_state_widget_test.dart: registered account without membership is not shown as signed out
00:11 +52 -26: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/account_state_widget_test.dart: unverified registered accounts see the Groups gate
00:11 +53 -26: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/account_state_widget_test.dart: verified account without an organisation can open groups
00:11 +54 -26: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/account_state_widget_test.dart: anonymous Groups prompt preserves local account flow without API calls
00:11 +55 -26: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/account_state_widget_test.dart: inactive and unavailable memberships are distinct states
00:12 +56 -26: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/account_state_widget_test.dart: organisation account menu uses membership display metadata
00:12 +57 -26: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/account_state_widget_test.dart: Groups navigation is hidden for anonymous and unverified users
00:12 +58 -26: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/account_state_widget_test.dart: Personal workspace navigation omits organisation destinations
00:12 +59 -26: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/account_state_widget_test.dart: registered account with no membership stays in local workspace
00:12 +60 -26: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/account_state_widget_test.dart: auth loading is not presented as a signed-out guest
00:12 +61 -26: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/account_state_widget_test.dart: auth errors retain the signed-in status as unavailable
00:12 +62 -26: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/account_state_widget_test.dart: membership lookup errors do not claim the account has no member
00:12 +63 -26: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/account_state_widget_test.dart: unverified accounts do not query Groups
00:12 +64 -26: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/account_state_widget_test.dart: registration from anonymous session uses separate account flow
00:12 +65 -26: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/account_state_widget_test.dart: account creation sends verification email
00:12 +66 -26: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/account_state_widget_test.dart: separate signup explains an email already in use safely
00:12 +67 -26: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/account_state_widget_test.dart: separate signup explains weak passwords safely
00:12 +68 -26: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/account_state_widget_test.dart: sign-in proceeds without local-work ownership confirmation
00:13 +69 -26: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/account_state_widget_test.dart: account creation does not prompt before normal registration
00:13 +70 -26: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/account_state_widget_test.dart: sign-in errors are shown without guest ownership warnings
00:13 +71 -26: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/account_state_widget_test.dart: opening sign-in never preflights Groups ownership
00:13 +72 -26: Some tests failed.

```
