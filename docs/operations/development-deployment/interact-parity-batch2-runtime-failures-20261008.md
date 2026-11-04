# Batch 2 runtime check after compilation repair — 2026-10-08

Source844e328181669039476226ae5fed720bdfb1809c/app subtreeb60ccc6a59a7f610d565aa12c1681f45eec06379. Mailbox104998bytes/SHA256fe61f4d00ece4aac30b5c20f6e6e78fee8d386faa1b2e2e2eb9d29c48e7a188d applied unchanged fromb408dbe, exact app equality verified. Fresh local repository/worktree batch2-final-repo/batch2-final-tests restored isolated git metadata after prior parent scratch clone disappeared; preserved old validation files.

Flutter3.41.4/Dart3.11.1, CI=true --suppress-analytics, offline enforced-lockfile pubgetPASS. Analyze0errors0warnings12existinginfos8.6s exit1 solely infos. Focused same five-file suite86PASS12FAIL exit1 in13s; full suite/release withheld pending these failures. Formatting10files1would-change (guest_group_dialog_test); original app untouched.

Full focused log:

```
Waiting for another flutter command to release the startup lock...
00:00 +0: loading /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/account_state_widget_test.dart
00:00 +0: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/account_state_widget_test.dart: local guest account menu explains local-only work
00:01 +1: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/account_state_widget_test.dart: local guest account menu explains local-only work
00:01 +2: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/account_state_widget_test.dart: local guest account menu explains local-only work
00:01 +3: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/ask_page_test.dart: Ask suggestions show unified source badges and open source
00:01 +4: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/ask_page_test.dart: Ask suggestions show unified source badges and open source
00:01 +5: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/ask_page_test.dart: Ask suggestions show unified source badges and open source
00:01 +6: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/ask_page_test.dart: Ask suggestions show unified source badges and open source
00:01 +7: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/ask_page_test.dart: Ask suggestions show unified source badges and open source
00:02 +8: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/ask_page_test.dart: Ask suggestions show unified source badges and open source
00:02 +9: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/ask_page_test.dart: Ask suggestions show unified source badges and open source
00:02 +10: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/ask_page_test.dart: Ask suggestions show unified source badges and open source
00:02 +11: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/ask_page_test.dart: Ask suggestions show unified source badges and open source
00:02 +12: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/guest_interact_widget_test.dart: Saved Q&A search edits and removes local entries and returns to the form
00:02 +13: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/guest_interact_widget_test.dart: Saved Q&A search edits and removes local entries and returns to the form
00:02 +14: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/guest_interact_widget_test.dart: Saved Q&A search edits and removes local entries and returns to the form
00:02 +15: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/guest_interact_widget_test.dart: Saved Q&A search edits and removes local entries and returns to the form
00:03 +16: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/guest_interact_widget_test.dart: Saved Q&A search edits and removes local entries and returns to the form
00:03 +17: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/guest_interact_widget_test.dart: Saved Q&A search edits and removes local entries and returns to the form
00:03 +18: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/guest_interact_widget_test.dart: Saved Q&A search edits and removes local entries and returns to the form
00:03 +19: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/guest_group_dialog_test.dart: failed remote forms retain drafts without replaying writes
00:03 +20: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/guest_group_dialog_test.dart: failed remote forms retain drafts without replaying writes
00:03 +21: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/guest_group_dialog_test.dart: failed remote forms retain drafts without replaying writes
00:04 +22: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/guest_group_dialog_test.dart: failed remote forms retain drafts without replaying writes
00:04 +23: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/guest_group_dialog_test.dart: failed remote forms retain drafts without replaying writes
00:04 +24: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/guest_interact_widget_test.dart: long labels and nested branches fit a narrow guest layout
00:04 +25: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/widget_test.dart: opens the local guest workspace without a login gate
00:04 +26: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/widget_test.dart: opens the local guest workspace without a login gate
00:04 +27: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/widget_test.dart: opens the local guest workspace without a login gate
00:04 +28: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/widget_test.dart: opens the local guest workspace without a login gate
00:04 +29: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/widget_test.dart: opens the local guest workspace without a login gate
00:05 +30: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/widget_test.dart: opens the local guest workspace without a login gate
00:05 +30: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/account_state_widget_test.dart: personal import retries selected items without removing locals

Warning: A call to tap() with finder "Found 1 widget with text "Saved Q&A": [
  Text("Saved Q&A", dependencies: [DefaultSelectionStyle, DefaultTextStyle, MediaQuery]),
]" derived an Offset (Offset(696.5, 574.0)) that would not hit test on the specified widget.
Maybe the widget is actually off-screen, or another widget is obscuring it, or the widget cannot receive pointer events.
The finder corresponds to this RenderBox: RenderParagraph#51e27 relayoutBoundary=up19
The hit test result at that offset is: HitTestResult(RenderParagraph#823ff@Offset(672.5, 28.0), RenderPadding#a3ad0@Offset(672.5, 42.0), RenderFlex#926e7@Offset(672.5, 42.0), RenderWrap#b8d1a@Offset(672.5, 42.0), RenderPadding#7a7ec@Offset(696.5, 42.0), RenderPadding#50dc6@Offset(696.5, 42.0), _RenderInkFeatures#65cad@Offset(696.5, 42.0), RenderPhysicalModel#c660f@Offset(696.5, 42.0), RenderPointerListener#2c6df@Offset(696.5, 42.0), RenderSemanticsGestureHandler#4990b@Offset(696.5, 42.0), RenderSemanticsAnnotations#8feb6@Offset(696.5, 42.0), RenderPositionedBox#dfaa4@Offset(696.5, 42.0), RenderClipRect#09b25@Offset(696.5, 42.0), RenderOffstage#124a6@Offset(696.5, 42.0), RenderConstrainedBox#a38a9@Offset(696.5, 42.0), RenderCustomMultiChildLayoutBox#89dfe@Offset(696.5, 574.0), _RenderInkFeatures#36f97@Offset(696.5, 574.0), RenderPhysicalModel#565e6@Offset(696.5, 574.0), RenderSemanticsAnnotations#ec4b0@Offset(696.5, 574.0), RenderRepaintBoundary#bbb64@Offset(696.5, 574.0), RenderIgnorePointer#fdbe1@Offset(696.5, 574.0), RenderAnimatedOpacity#3e9d7@Offset(696.5, 574.0), RenderAnimatedOpacity#6d45b@Offset(696.5, 574.0), _RenderColoredBox#a8d48@Offset(696.5, 574.0), RenderAnimatedOpacity#5b352@Offset(696.5, 574.0), RenderIgnorePointer#6b247@Offset(696.5, 574.0), RenderAnimatedOpacity#79564@Offset(696.5, 574.0), RenderRepaintBoundary#d77cd@Offset(696.5, 574.0), RenderSemanticsAnnotations#8a52d@Offset(696.5, 574.0), RenderOffstage#f559c@Offset(696.5, 574.0), RenderSemanticsAnnotations#2d0f9@Offset(696.5, 574.0), _RenderTheater#b84fc@Offset(696.5, 574.0), RenderAbsorbPointer#2b56b@Offset(696.5, 574.0), RenderPointerListener#44582@Offset(696.5, 574.0), RenderSemanticsAnnotations#fa5a3@Offset(696.5, 574.0), RenderCustomPaint#2ddbc@Offset(696.5, 574.0), RenderSemanticsAnnotations#bc9c2@Offset(696.5, 574.0), RenderSemanticsAnnotations#436be@Offset(696.5, 574.0), RenderSemanticsAnnotations#4352d@Offset(696.5, 574.0), RenderTapRegionSurface#79661@Offset(696.5, 574.0), RenderSemanticsAnnotations#1bb4a@Offset(696.5, 574.0), RenderSemanticsAnnotations#29052@Offset(696.5, 574.0), HitTestEntry<HitTestTarget>#ebd8d(_ReusableRenderView#88f9b), HitTestEntry<HitTestTarget>#3e380(<AutomatedTestWidgetsFlutterBinding>))
#0      WidgetController._getElementPoint (package:flutter_test/src/controller.dart:2158:25)
#1      WidgetController.getCenter (package:flutter_test/src/controller.dart:1942:12)
#2      WidgetController.tap (package:flutter_test/src/controller.dart:1075:7)
#3      main.<anonymous closure> (file:///workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/account_state_widget_test.dart:1193:20)
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
The following StateError was thrown running a test:
Bad state: No element

When the exception was thrown, this was the stack:
#0      Iterable.first (dart:core/iterable.dart:663:7)
#1      _FirstFinderMixin.filter (package:flutter_test/src/finders.dart:1340:28)
#3      Iterable.single (dart:core/iterable.dart:694:13)
#4      WidgetController.widget (package:flutter_test/src/controller.dart:823:30)
#5      main.<anonymous closure> (file:///workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/account_state_widget_test.dart:1202:16)
<asynchronous suspension>
#6      testWidgets.<anonymous closure>.<anonymous closure> (package:flutter_test/src/widget_tester.dart:192:15)
<asynchronous suspension>
#7      TestWidgetsFlutterBinding._runTestBody (package:flutter_test/src/binding.dart:1682:5)
<asynchronous suspension>
<asynchronous suspension>
(elided 2 frames from dart:async-patch and package:stack_trace)

The test description was:
  personal import retries selected items without removing locals
════════════════════════════════════════════════════════════════════════════════════════════════════
00:05 +30 -1: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/widget_test.dart: opens the local guest workspace without a login gate
00:05 +30 -1: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/account_state_widget_test.dart: personal import retries selected items without removing locals [E]
  Test failed. See exception logs above.
  The test description was: personal import retries selected items without removing locals
  
00:05 +31 -1: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/widget_test.dart: opens the local guest workspace without a login gate
00:05 +32 -1: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/guest_interact_widget_test.dart: switching active participants keeps answers and targeted branches after reload
00:05 +33 -1: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/guest_interact_widget_test.dart: switching active participants keeps answers and targeted branches after reload
00:05 +34 -1: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/guest_interact_widget_test.dart: switching active participants keeps answers and targeted branches after reload
00:06 +35 -1: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/guest_interact_widget_test.dart: switching active participants keeps answers and targeted branches after reload
00:06 +36 -1: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/guest_interact_widget_test.dart: switching active participants keeps answers and targeted branches after reload
00:06 +37 -1: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/guest_interact_widget_test.dart: switching active participants keeps answers and targeted branches after reload
00:06 +37 -1: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/account_state_widget_test.dart: revision conflicts reload before an explicit pending-edit save
══╡ EXCEPTION CAUGHT BY FLUTTER TEST FRAMEWORK ╞════════════════════════════════════════════════════
The following TestFailure was thrown running a test:
Expected: [1]
  Actual: [1, 2]
   Which: at location [1] is [1, 2] which longer than expected

When the exception was thrown, this was the stack:
#4      main.<anonymous closure> (file:///workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/account_state_widget_test.dart:1342:7)
<asynchronous suspension>
#5      testWidgets.<anonymous closure>.<anonymous closure> (package:flutter_test/src/widget_tester.dart:192:15)
<asynchronous suspension>
#6      TestWidgetsFlutterBinding._runTestBody (package:flutter_test/src/binding.dart:1682:5)
<asynchronous suspension>
<asynchronous suspension>
(elided one frame from package:stack_trace)

This was caught by the test expectation on the following line:
  file:///workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/account_state_widget_test.dart line 1342
The test description was:
  revision conflicts reload before an explicit pending-edit save
════════════════════════════════════════════════════════════════════════════════════════════════════
00:06 +37 -2: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/guest_interact_widget_test.dart: switching active participants keeps answers and targeted branches after reload
00:06 +37 -2: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/account_state_widget_test.dart: revision conflicts reload before an explicit pending-edit save [E]
  Test failed. See exception logs above.
  The test description was: revision conflicts reload before an explicit pending-edit save
  
00:06 +38 -2: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/guest_interact_widget_test.dart: switching active participants keeps answers and targeted branches after reload
00:06 +39 -2: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/account_state_widget_test.dart: editing an imported nested session updates the account copy
00:06 +40 -2: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/account_state_widget_test.dart: editing an imported nested session updates the account copy
00:06 +41 -2: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/account_state_widget_test.dart: editing an imported nested session updates the account copy
00:06 +42 -2: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/guest_interact_widget_test.dart: PDF report preview uses the active participant scope
00:07 +43 -2: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/guest_group_dialog_test.dart: account transition remounts group state for recipient
00:07 +44 -2: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/account_state_widget_test.dart: new local work is not uploaded before explicit import
00:07 +45 -2: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/account_state_widget_test.dart: new local work is not uploaded before explicit import
══╡ EXCEPTION CAUGHT BY FLUTTER TEST FRAMEWORK ╞════════════════════════════════════════════════════
The following StateError was thrown running a test:
Bad state: No element

When the exception was thrown, this was the stack:
#0      Iterable.first (dart:core/iterable.dart:663:7)
#1      _FirstFinderMixin.filter (package:flutter_test/src/finders.dart:1340:28)
#3      Iterable.single (dart:core/iterable.dart:694:13)
#4      WidgetController.widget (package:flutter_test/src/controller.dart:823:30)
#5      main.<anonymous closure> (file:///workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/account_state_widget_test.dart:1503:14)
<asynchronous suspension>
#6      testWidgets.<anonymous closure>.<anonymous closure> (package:flutter_test/src/widget_tester.dart:192:15)
<asynchronous suspension>
#7      TestWidgetsFlutterBinding._runTestBody (package:flutter_test/src/binding.dart:1682:5)
<asynchronous suspension>
<asynchronous suspension>
(elided 2 frames from dart:async-patch and package:stack_trace)

The test description was:
  new local work is not uploaded before explicit import
════════════════════════════════════════════════════════════════════════════════════════════════════
00:07 +45 -3: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/guest_interact_widget_test.dart: local JSON backup import previews and merges selected items
00:07 +45 -3: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/account_state_widget_test.dart: new local work is not uploaded before explicit import [E]
  Test failed. See exception logs above.
  The test description was: new local work is not uploaded before explicit import
  
00:07 +46 -3: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/guest_group_dialog_test.dart: archived group deletion requires confirmation and refreshes
00:07 +47 -3: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/account_state_widget_test.dart: new verified-user Knowledge saves privately and reconciles an uncertain create
00:07 +48 -3: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/account_state_widget_test.dart: new verified-user Knowledge saves privately and reconciles an uncertain create
00:07 +49 -3: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/account_state_widget_test.dart: new verified-user Knowledge saves privately and reconciles an uncertain create
══╡ EXCEPTION CAUGHT BY FLUTTER TEST FRAMEWORK ╞════════════════════════════════════════════════════
The following TestFailure was thrown running a test:
Expected: exactly one matching candidate
  Actual: _TextWidgetFinder:<Found 0 widgets with text "Save to private account": []>
   Which: means none were found but one was expected

When the exception was thrown, this was the stack:
#4      main.<anonymous closure> (file:///workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/account_state_widget_test.dart:1544:7)
<asynchronous suspension>
#5      testWidgets.<anonymous closure>.<anonymous closure> (package:flutter_test/src/widget_tester.dart:192:15)
<asynchronous suspension>
#6      TestWidgetsFlutterBinding._runTestBody (package:flutter_test/src/binding.dart:1682:5)
<asynchronous suspension>
<asynchronous suspension>
(elided one frame from package:stack_trace)

This was caught by the test expectation on the following line:
  file:///workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/account_state_widget_test.dart line 1544
The test description was:
  new verified-user Knowledge saves privately and reconciles an uncertain create
════════════════════════════════════════════════════════════════════════════════════════════════════
00:07 +49 -4: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/guest_interact_widget_test.dart: incompatible backup shows diagnostics without import success
00:07 +49 -4: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/account_state_widget_test.dart: new verified-user Knowledge saves privately and reconciles an uncertain create [E]
  Test failed. See exception logs above.
  The test description was: new verified-user Knowledge saves privately and reconciles an uncertain create
  
00:07 +50 -4: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/guest_group_dialog_test.dart: uncertain deletion keeps item and blocks retry until refresh
00:07 +51 -4: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/account_state_widget_test.dart: pending private write blocks shell navigation and browser back until saved
00:07 +52 -4: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/account_state_widget_test.dart: pending private write blocks shell navigation and browser back until saved
00:07 +53 -4: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/account_state_widget_test.dart: pending private write blocks shell navigation and browser back until saved
00:07 +54 -4: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/account_state_widget_test.dart: pending private write blocks shell navigation and browser back until saved
00:08 +55 -4: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/account_state_widget_test.dart: pending private write blocks shell navigation and browser back until saved
00:08 +56 -4: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/account_state_widget_test.dart: pending private write blocks shell navigation and browser back until saved
══╡ EXCEPTION CAUGHT BY FLUTTER TEST FRAMEWORK ╞════════════════════════════════════════════════════
The following assertion was thrown running a test:
The finder "Found 0 widgets with text "Save to private account": []" (used in a call to "tap()")
could not find any matching widgets.

When the exception was thrown, this was the stack:
#0      WidgetController._getElementPoint (package:flutter_test/src/controller.dart:2090:7)
#1      WidgetController.getCenter (package:flutter_test/src/controller.dart:1942:12)
#2      WidgetController.tap (package:flutter_test/src/controller.dart:1075:7)
#3      main.<anonymous closure> (file:///workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/account_state_widget_test.dart:1628:20)
<asynchronous suspension>
#4      testWidgets.<anonymous closure>.<anonymous closure> (package:flutter_test/src/widget_tester.dart:192:15)
<asynchronous suspension>
#5      TestWidgetsFlutterBinding._runTestBody (package:flutter_test/src/binding.dart:1682:5)
<asynchronous suspension>
<asynchronous suspension>
(elided one frame from package:stack_trace)

The test description was:
  pending private write blocks shell navigation and browser back until saved
════════════════════════════════════════════════════════════════════════════════════════════════════
00:08 +56 -5: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/guest_interact_widget_test.dart: failed local save still allows backup copy with accurate status
00:08 +56 -5: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/account_state_widget_test.dart: pending private write blocks shell navigation and browser back until saved [E]
  Test failed. See exception logs above.
  The test description was: pending private write blocks shell navigation and browser back until saved
  
00:08 +56 -5: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/account_state_widget_test.dart: UID transition isolates queued writes while an earlier create is unresolved
══╡ EXCEPTION CAUGHT BY FLUTTER TEST FRAMEWORK ╞════════════════════════════════════════════════════
The following assertion was thrown running a test:
The finder "Found 0 widgets with text "Save to private account": []" (used in a call to "tap()")
could not find any matching widgets.

When the exception was thrown, this was the stack:
#0      WidgetController._getElementPoint (package:flutter_test/src/controller.dart:2090:7)
#1      WidgetController.getCenter (package:flutter_test/src/controller.dart:1942:12)
#2      WidgetController.tap (package:flutter_test/src/controller.dart:1075:7)
#3      main.<anonymous closure> (file:///workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/account_state_widget_test.dart:1701:20)
<asynchronous suspension>
#4      testWidgets.<anonymous closure>.<anonymous closure> (package:flutter_test/src/widget_tester.dart:192:15)
<asynchronous suspension>
#5      TestWidgetsFlutterBinding._runTestBody (package:flutter_test/src/binding.dart:1682:5)
<asynchronous suspension>
<asynchronous suspension>
(elided one frame from package:stack_trace)

The test description was:
  UID transition isolates queued writes while an earlier create is unresolved
════════════════════════════════════════════════════════════════════════════════════════════════════
00:08 +56 -6: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/guest_interact_widget_test.dart: failed local save still allows backup copy with accurate status
00:08 +56 -6: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/account_state_widget_test.dart: UID transition isolates queued writes while an earlier create is unresolved [E]
  Test failed. See exception logs above.
  The test description was: UID transition isolates queued writes while an earlier create is unresolved
  
00:08 +57 -6: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/account_state_widget_test.dart: deleting during uncertain create confirms creation before account deletion
══╡ EXCEPTION CAUGHT BY FLUTTER TEST FRAMEWORK ╞════════════════════════════════════════════════════
The following assertion was thrown running a test:
The finder "Found 0 widgets with text "Save to private account": []" (used in a call to "tap()")
could not find any matching widgets.

When the exception was thrown, this was the stack:
#0      WidgetController._getElementPoint (package:flutter_test/src/controller.dart:2090:7)
#1      WidgetController.getCenter (package:flutter_test/src/controller.dart:1942:12)
#2      WidgetController.tap (package:flutter_test/src/controller.dart:1075:7)
#3      main.<anonymous closure> (file:///workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/account_state_widget_test.dart:1753:20)
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
00:08 +57 -7: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/guest_interact_widget_test.dart: failed backup import preserves source and current local data
00:08 +57 -7: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/account_state_widget_test.dart: deleting during uncertain create confirms creation before account deletion [E]
  Test failed. See exception logs above.
  The test description was: deleting during uncertain create confirms creation before account deletion
  
00:09 +58 -7: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/account_state_widget_test.dart: personal refresh overlapping a create cannot replace the acknowledged item
══╡ EXCEPTION CAUGHT BY FLUTTER TEST FRAMEWORK ╞════════════════════════════════════════════════════
The following assertion was thrown running a test:
The finder "Found 0 widgets with text "Save to private account": []" (used in a call to "tap()")
could not find any matching widgets.

When the exception was thrown, this was the stack:
#0      WidgetController._getElementPoint (package:flutter_test/src/controller.dart:2090:7)
#1      WidgetController.getCenter (package:flutter_test/src/controller.dart:1942:12)
#2      WidgetController.tap (package:flutter_test/src/controller.dart:1075:7)
#3      main.<anonymous closure> (file:///workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/account_state_widget_test.dart:1792:20)
<asynchronous suspension>
#4      testWidgets.<anonymous closure>.<anonymous closure> (package:flutter_test/src/widget_tester.dart:192:15)
<asynchronous suspension>
#5      TestWidgetsFlutterBinding._runTestBody (package:flutter_test/src/binding.dart:1682:5)
<asynchronous suspension>
<asynchronous suspension>
(elided one frame from package:stack_trace)

The test description was:
  personal refresh overlapping a create cannot replace the acknowledged item
════════════════════════════════════════════════════════════════════════════════════════════════════
00:09 +58 -8: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/guest_interact_widget_test.dart: backup input can close and unmount during its reverse transition
00:09 +58 -8: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/account_state_widget_test.dart: personal refresh overlapping a create cannot replace the acknowledged item [E]
  Test failed. See exception logs above.
  The test description was: personal refresh overlapping a create cannot replace the acknowledged item
  
00:09 +59 -8: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/account_state_widget_test.dart: pending selected account import blocks shell navigation until confirmed
00:09 +60 -8: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/account_state_widget_test.dart: pending selected account import blocks shell navigation until confirmed
00:09 +61 -8: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/account_state_widget_test.dart: pending selected account import blocks shell navigation until confirmed
00:09 +62 -8: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/account_state_widget_test.dart: pending selected account import blocks shell navigation until confirmed
══╡ EXCEPTION CAUGHT BY FLUTTER TEST FRAMEWORK ╞════════════════════════════════════════════════════
The following assertion was thrown running a test:
The finder "Found 0 widgets with widget matching predicate: []" (used in a call to "tap()") could
not find any matching widgets.

When the exception was thrown, this was the stack:
#0      WidgetController._getElementPoint (package:flutter_test/src/controller.dart:2090:7)
#1      WidgetController.getCenter (package:flutter_test/src/controller.dart:1942:12)
#2      WidgetController.tap (package:flutter_test/src/controller.dart:1075:7)
#3      main.<anonymous closure> (file:///workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/account_state_widget_test.dart:1840:20)
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
00:09 +62 -9: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/guest_interact_widget_test.dart: required Knowledge and session fields show inline errors
00:09 +62 -9: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/account_state_widget_test.dart: pending selected account import blocks shell navigation until confirmed [E]
  Test failed. See exception logs above.
  The test description was: pending selected account import blocks shell navigation until confirmed
  
00:09 +63 -9: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/account_state_widget_test.dart: permanent import rejection releases navigation while transient failure stays guarded
══╡ EXCEPTION CAUGHT BY RENDERING LIBRARY ╞═════════════════════════════════════════════════════════
The following assertion was thrown during layout:
A RenderFlex overflowed by 2.0 pixels on the bottom.

The relevant error-causing widget was:
  Column
  Column:file:///workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/lib/features/guest/presentation/guest_workspace_page.dart:1734:17

The overflowing RenderFlex has an orientation of Axis.vertical.
The edge of the RenderFlex that is overflowing has been marked in the rendering with a yellow and
black striped pattern. This is usually caused by the contents being too big for the RenderFlex.
Consider applying a flex factor (e.g. using an Expanded widget) to force the children of the
RenderFlex to fit within the available space instead of being sized to their natural size.
This is considered an error condition because it indicates that there is content that cannot be
seen. If the content is legitimately bigger than the available space, consider clipping it with a
ClipRect widget before putting it in the flex, or using a scrollable container rather than a Flex,
like a ListView.
The specific RenderFlex in question is: RenderFlex#958d5 relayoutBoundary=up1 OVERFLOWING:
  needs compositing
  creator: Column ← KeyedSubtree-[GlobalKey#16632] ← _BodyBuilder ← MediaQuery ←
    LayoutId-[<_ScaffoldSlot.body>] ← CustomMultiChildLayout ← _ActionsScope ← Actions ←
    AnimatedBuilder ← DefaultTextStyle ← AnimatedDefaultTextStyle ← _InkFeatures-[GlobalKey#15610 ink
    renderer] ← ⋯
  parentData: offset=Offset(0.0, 130.0); id=_ScaffoldSlot.body (can use size)
  constraints: BoxConstraints(0.0<=w<=585.8, 0.0<=h<=470.0)
  size: Size(585.8, 470.0)
  direction: vertical
  mainAxisAlignment: start
  mainAxisSize: max
  crossAxisAlignment: center
  verticalDirection: down
  spacing: 0.0
◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤
════════════════════════════════════════════════════════════════════════════════════════════════════
══╡ EXCEPTION CAUGHT BY FLUTTER TEST FRAMEWORK ╞════════════════════════════════════════════════════
The following assertion was thrown running a test:
The finder "Found 0 widgets with widget matching predicate: []" (used in a call to "tap()") could
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
  permanent import rejection releases navigation while transient failure stays guarded
════════════════════════════════════════════════════════════════════════════════════════════════════
══╡ EXCEPTION CAUGHT BY FLUTTER TEST FRAMEWORK ╞════════════════════════════════════════════════════
The following message was thrown:
Multiple exceptions (2) were detected during the running of the current test, and at least one was
unexpected.
════════════════════════════════════════════════════════════════════════════════════════════════════
00:10 +63 -10: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/account_state_widget_test.dart: permanent import rejection releases navigation while transient failure stays guarded [E]
  Test failed. See exception logs above.
  The test description was: permanent import rejection releases navigation while transient failure stays guarded
  
00:10 +63 -10: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/account_state_widget_test.dart: unconfirmed account import remains guarded and retains its local original
══╡ EXCEPTION CAUGHT BY FLUTTER TEST FRAMEWORK ╞════════════════════════════════════════════════════
The following assertion was thrown running a test:
The finder "Found 0 widgets with widget matching predicate: []" (used in a call to "tap()") could
not find any matching widgets.

When the exception was thrown, this was the stack:
#0      WidgetController._getElementPoint (package:flutter_test/src/controller.dart:2090:7)
#1      WidgetController.getCenter (package:flutter_test/src/controller.dart:1942:12)
#2      WidgetController.tap (package:flutter_test/src/controller.dart:1075:7)
#3      main.<anonymous closure> (file:///workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/account_state_widget_test.dart:1940:20)
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
00:10 +63 -11: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/account_state_widget_test.dart: unconfirmed account import remains guarded and retains its local original [E]
  Test failed. See exception logs above.
  The test description was: unconfirmed account import remains guarded and retains its local original
  
00:10 +63 -11: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/account_state_widget_test.dart: new verified-user Interact sessions save privately by default
00:11 +64 -11: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/account_state_widget_test.dart: existing-account sign-in errors do not reveal Firebase details
00:11 +65 -11: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/account_state_widget_test.dart: unexpected sign-in errors show a safe recovery message
00:11 +66 -11: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/account_state_widget_test.dart: registered account without membership is not shown as signed out
00:11 +67 -11: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/account_state_widget_test.dart: unverified registered accounts see the Groups gate
00:11 +68 -11: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/account_state_widget_test.dart: verified account without an organisation can open groups
00:11 +69 -11: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/account_state_widget_test.dart: anonymous Groups prompt preserves local account flow without API calls
00:11 +70 -11: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/account_state_widget_test.dart: inactive and unavailable memberships are distinct states
00:11 +71 -11: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/account_state_widget_test.dart: organisation account menu uses membership display metadata
00:11 +72 -11: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/account_state_widget_test.dart: Groups navigation is hidden for anonymous and unverified users
00:11 +73 -11: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/account_state_widget_test.dart: Personal workspace navigation omits organisation destinations
00:11 +74 -11: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/account_state_widget_test.dart: registered account with no membership stays in local workspace
══╡ EXCEPTION CAUGHT BY FLUTTER TEST FRAMEWORK ╞════════════════════════════════════════════════════
The following TestFailure was thrown running a test:
Expected: exactly one matching candidate
  Actual: _TextWidgetFinder:<Found 0 widgets with text "IntQAFlow workspace": []>
   Which: means none were found but one was expected

When the exception was thrown, this was the stack:
#4      main.<anonymous closure> (file:///workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/account_state_widget_test.dart:2385:5)
<asynchronous suspension>
#5      testWidgets.<anonymous closure>.<anonymous closure> (package:flutter_test/src/widget_tester.dart:192:15)
<asynchronous suspension>
#6      TestWidgetsFlutterBinding._runTestBody (package:flutter_test/src/binding.dart:1682:5)
<asynchronous suspension>
<asynchronous suspension>
(elided one frame from package:stack_trace)

This was caught by the test expectation on the following line:
  file:///workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/account_state_widget_test.dart line 2385
The test description was:
  registered account with no membership stays in local workspace
════════════════════════════════════════════════════════════════════════════════════════════════════
00:12 +74 -12: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/account_state_widget_test.dart: registered account with no membership stays in local workspace [E]
  Test failed. See exception logs above.
  The test description was: registered account with no membership stays in local workspace
  
00:12 +74 -12: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/account_state_widget_test.dart: auth loading is not presented as a signed-out guest
00:12 +75 -12: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/account_state_widget_test.dart: auth errors retain the signed-in status as unavailable
00:12 +76 -12: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/account_state_widget_test.dart: membership lookup errors do not claim the account has no member
00:12 +77 -12: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/account_state_widget_test.dart: unverified accounts do not query Groups
00:12 +78 -12: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/account_state_widget_test.dart: registration from anonymous session uses separate account flow
00:12 +79 -12: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/account_state_widget_test.dart: account creation sends verification email
00:12 +80 -12: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/account_state_widget_test.dart: separate signup explains an email already in use safely
00:12 +81 -12: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/account_state_widget_test.dart: separate signup explains weak passwords safely
00:12 +82 -12: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/account_state_widget_test.dart: sign-in proceeds without local-work ownership confirmation
00:13 +83 -12: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/account_state_widget_test.dart: account creation does not prompt before normal registration
00:13 +84 -12: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/account_state_widget_test.dart: sign-in errors are shown without guest ownership warnings
00:13 +85 -12: /workspace/scratch/634b5dd13590/batch2-final-tests/apps/flutter_app/test/account_state_widget_test.dart: opening sign-in never preflights Groups ownership
00:13 +86 -12: Some tests failed.

```

Receipts /workspace/scratch/634b5dd13590/batch2-final-{pubget,analyze,focused,format}.{log,exit}. No deployment/merge/schema/DB/proxy/Codespace. Batch2 unaccepted.
