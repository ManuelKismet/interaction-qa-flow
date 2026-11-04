import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:int_qa_flow/core/nia/nia_guidance.dart';
import 'package:int_qa_flow/shared/widgets/workspace_tabs.dart';

NiaTeaching freshTeaching() => NiaTeaching(read: (_) => null, write: (_, _) {});
Widget app(Widget child, NiaTeaching teaching, {String account = 'alice'}) =>
    NiaHost(
      subject: account,
      authorityRevision: 'v1',
      teaching: teaching,
      child: MaterialApp(home: Scaffold(body: child)),
    );

void main() {
  test(
    'seen lessons and explicit off preference persist only for their account',
    () async {
      final storage = <String, String>{};
      NiaTeaching create() => NiaTeaching(
        read: (key) => storage[key],
        write: (key, value) => storage[key] = value,
      );
      final first = create()..bind('alice');
      final owner = Object();
      expect(first.claim(owner, 'knowledge.search'), isTrue);
      first.shown(owner, 'knowledge.search');
      first.release(owner);
      first.setEnabled(false);
      first.dispose();
      final reopened = create()..bind('alice');
      expect(reopened.enabled, isFalse);
      expect(reopened.seen('knowledge.search'), isTrue);
      reopened.bind('bob');
      expect(reopened.enabled, isTrue);
      expect(reopened.seen('knowledge.search'), isFalse);
      reopened.dispose();
    },
  );
  test(
    'one owner; unseen cancellation and stale callbacks cannot consume another lesson',
    () async {
      final teaching = freshTeaching()..bind('alice');
      final old = Object(), current = Object();
      expect(teaching.claim(old, 'knowledge.search'), isTrue);
      expect(teaching.claim(current, 'groups.access'), isFalse);
      teaching.release(old);
      expect(teaching.seen('knowledge.search'), isFalse);
      expect(teaching.claim(current, 'groups.access'), isTrue);
      teaching.shown(old, 'groups.access');
      teaching.release(old);
      expect(teaching.owns(current), isTrue);
      expect(teaching.seen('groups.access'), isFalse);
      teaching.dispose();
    },
  );
  test(
    'unreadable preferences fail quiet and failed persistence still suppresses this session',
    () async {
      final unavailable = NiaTeaching(
        read: (_) => throw StateError('storage'),
        write: (_, _) {},
      )..bind('alice');
      expect(unavailable.claim(Object(), 'knowledge.search'), isFalse);
      unavailable.dispose();
      final failing = NiaTeaching(
        read: (_) => null,
        write: (_, _) => throw StateError('quota'),
      )..bind('alice');
      final owner = Object();
      expect(failing.claim(owner, 'knowledge.search'), isTrue);
      failing.shown(owner, 'knowledge.search');
      failing.release(owner);
      expect(failing.claim(owner, 'knowledge.search'), isFalse);
      failing.dispose();
    },
  );
  testWidgets(
    'useful guidance appears inline, dismisses and stays quiet when revisited',
    (tester) async {
      final teaching = freshTeaching();
      const hint = NiaInlineGuidance(
        topic: NiaTopic.knowledge,
        lessonId: 'knowledge.search',
      );
      await tester.pumpWidget(app(hint, teaching));
      await tester.pumpAndSettle();
      expect(find.textContaining('This search covers'), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(Card), findsNothing);
      await tester.tap(find.byTooltip('Got it — hide this tip'));
      await tester.pumpAndSettle();
      expect(find.textContaining('This search covers'), findsNothing);
      await tester.pumpWidget(app(const SizedBox.shrink(), teaching));
      await tester.pumpAndSettle();
      await tester.pumpWidget(app(hint, teaching));
      await tester.pumpAndSettle();
      expect(find.textContaining('This search covers'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );
  testWidgets(
    'typing and focus suppress teaching without losing text or stealing focus',
    (tester) async {
      final teaching = freshTeaching(), input = TextEditingController();
      final focus = FocusNode();
      await tester.pumpWidget(
        app(
          Column(
            children: [
              NiaInlineGuidance(
                topic: NiaTopic.knowledge,
                lessonId: 'knowledge.search',
                inputs: [input],
              ),
              TextField(controller: input, focusNode: focus),
            ],
          ),
          teaching,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('This search covers'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'My unsaved proposal');
      await tester.pumpAndSettle();
      expect(find.textContaining('This search covers'), findsNothing);
      expect(input.text, 'My unsaved proposal');
      expect(focus.hasFocus, isTrue);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      input.dispose();
      focus.dispose();
    },
  );
  testWidgets(
    'busy, completed and inactive tabs do not spend a teaching receipt',
    (tester) async {
      final teaching = freshTeaching();
      await tester.pumpWidget(
        app(
          DefaultTabController(
            length: 2,
            child: Column(
              children: [
                const TabBar(
                  tabs: [
                    Tab(text: 'One'),
                    Tab(text: 'Two'),
                  ],
                ),
                const NiaInlineGuidance(
                  topic: NiaTopic.knowledge,
                  lessonId: 'busy',
                  busy: true,
                ),
                const NiaInlineGuidance(
                  topic: NiaTopic.knowledge,
                  lessonId: 'complete',
                  complete: true,
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      const SizedBox.shrink(),
                      const NiaTabSurface(
                        index: 1,
                        child: NiaInlineGuidance(
                          topic: NiaTopic.knowledge,
                          lessonId: 'knowledge.search',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          teaching,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('This search covers'), findsNothing);
      expect(teaching.seen('knowledge.search'), isFalse);
      await tester.tap(find.text('Two'));
      await tester.pumpAndSettle();
      expect(find.textContaining('This search covers'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );
  testWidgets(
    'guidance expires; disabling it leaves ordinary product content available',
    (tester) async {
      final teaching = freshTeaching();
      await tester.pumpWidget(
        app(
          const Column(
            children: [
              Text('Keep working'),
              NiaInlineGuidance(
                topic: NiaTopic.knowledge,
                lessonId: 'knowledge.search',
              ),
            ],
          ),
          teaching,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('This search covers'), findsOneWidget);
      await tester.pump(const Duration(seconds: 9));
      await tester.pumpAndSettle();
      expect(find.textContaining('This search covers'), findsNothing);
      teaching.setEnabled(false);
      await tester.pumpAndSettle();
      expect(find.text('Keep working'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );
  testWidgets(
    'focused empty editors suppress optional guidance without a controller input',
    (tester) async {
      final teaching = freshTeaching();
      final focus = FocusNode();
      await tester.pumpWidget(
        app(
          Column(
            children: [
              const NiaInlineGuidance(
                topic: NiaTopic.knowledge,
                lessonId: 'knowledge.search',
              ),
              TextField(focusNode: focus),
            ],
          ),
          teaching,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('This search covers'), findsOneWidget);
      focus.requestFocus();
      await tester.pumpAndSettle();
      expect(find.textContaining('This search covers'), findsNothing);
      expect(focus.hasFocus, isTrue);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      focus.dispose();
    },
  );
  testWidgets(
    'account changes bind separate teaching and withdraw the old explanation',
    (tester) async {
      final values = <String, String>{};
      final teaching = NiaTeaching(
        read: (key) => values[key],
        write: (key, value) => values[key] = value,
      );
      await tester.pumpWidget(
        app(
          const NiaInlineGuidance(
            topic: NiaTopic.knowledge,
            lessonId: 'knowledge.search',
            facts: {'private': true},
          ),
          teaching,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Search includes accessible'), findsOneWidget);
      await tester.pumpWidget(
        app(
          const NiaInlineGuidance(
            topic: NiaTopic.knowledge,
            lessonId: 'knowledge.search',
          ),
          teaching,
          account: 'bob',
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Search includes accessible'), findsNothing);
      expect(find.textContaining('This search covers'), findsOneWidget);
      expect(values.keys.any((key) => key.endsWith('.alice')), isTrue);
      expect(values.keys.any((key) => key.endsWith('.bob')), isTrue);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );
  testWidgets(
    'three equal-width tabs keep the prior selection when Group entry is guarded',
    (tester) async {
      var attempted = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DefaultTabController(
              length: 2,
              child: Column(
                children: [
                  WorkspaceBodyTabs(
                    groupsAvailable: true,
                    onTabChanged: (_) {},
                    onGroups: (_) => attempted++,
                  ),
                  const Expanded(
                    child: TabBarView(
                      children: [Text('Knowledge body'), Text('Interact body')],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      final bar = tester.widget<TabBar>(find.byType(TabBar));
      expect(bar.tabs.length, 3);
      final first = tester.getCenter(find.text('Knowledge')).dx;
      final second = tester.getCenter(find.text('Interact')).dx;
      final third = tester.getCenter(find.text('Groups')).dx;
      expect(((second - first) - (third - second)).abs(), lessThan(1));
      await tester.tap(find.text('Groups'));
      await tester.pumpAndSettle();
      expect(attempted, 1);
      expect(bar.controller!.index, 0);
      expect(find.text('Knowledge body'), findsOneWidget);
      await tester.tap(find.text('Interact'));
      await tester.pumpAndSettle();
      expect(find.text('Interact body'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );
}
