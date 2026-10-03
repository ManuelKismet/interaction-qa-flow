import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:int_qa_flow/features/guest/data/guest_storage_interface.dart';
import 'package:int_qa_flow/features/guest/data/guest_workspace_store.dart';
import 'package:int_qa_flow/features/guest/domain/guest_workspace_data.dart';
import 'package:int_qa_flow/features/guest/presentation/guest_workspace_page.dart';

void main() {
  testWidgets('long labels and nested branches fit a narrow guest layout', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final store = GuestWorkspaceStore(_MemoryGuestStorage());
    await store.save(
      GuestWorkspaceData(
        sessions: [_narrowSession()],
      ),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          guestWorkspaceStoreProvider.overrideWithValue(store),
        ],
        child: const MaterialApp(
          home: GuestWorkspacePage(firebaseReady: false),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Interact').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('A long session title that should truncate cleanly'));
    await tester.pumpAndSettle();

    expect(find.text('Active participant'), findsOneWidget);
    expect(find.text('Add shared question'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'switching active participants keeps answers and targeted branches after reload',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final storage = _MemoryGuestStorage();
      final store = GuestWorkspaceStore(storage);
      await store.save(
        GuestWorkspaceData(
          sessions: [_twoParticipantSession()],
        ),
      );

      Future<void> showWorkspace() async {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              guestWorkspaceStoreProvider.overrideWithValue(store),
            ],
            child: const MaterialApp(
              home: GuestWorkspacePage(firebaseReady: false),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Interact').first);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Two-person interview'));
        await tester.pumpAndSettle();
      }

      await showWorkspace();
      expect(_answerField(tester).controller!.text, 'Alice answer');
      expect(find.text('Bob-only question'), findsNothing);

      await _selectParticipant(tester, 'Bob');
      expect(_answerField(tester).controller!.text, 'Bob answer');
      expect(find.text('Bob-only question'), findsOneWidget);
      expect(find.text('Bob follow-up'), findsOneWidget);

      await tester.enterText(_field('Prepared question'), 'Bob-only addition');
      await tester.tap(find.text('Add question for selected participant'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 300));
      final saved = await store.load();
      final savedQuestions = saved.sessions.single['questions'] as List;
      final added = savedQuestions
          .cast<Map<String, dynamic>>()
          .singleWhere((question) => question['text'] == 'Bob-only addition');
      expect(added['scope'], 'participant');
      expect(added['target_participant_id'], 'bob-id');

      await _selectParticipant(tester, 'Alice');
      expect(_answerField(tester).controller!.text, 'Alice answer');
      expect(find.text('Bob-only addition'), findsNothing);
      await _selectParticipant(tester, 'Bob');
      expect(find.text('Bob-only addition'), findsOneWidget);

      await showWorkspace();
      await _selectParticipant(tester, 'Bob');
      expect(_answerField(tester).controller!.text, 'Bob answer');
      expect(find.text('Bob-only addition'), findsOneWidget);
      expect(find.text('Bob follow-up'), findsOneWidget);
    },
  );

  testWidgets('PDF report preview uses the active participant scope', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final store = GuestWorkspaceStore(_MemoryGuestStorage());
    await store.save(GuestWorkspaceData(sessions: [_twoParticipantSession()]));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [guestWorkspaceStoreProvider.overrideWithValue(store)],
        child: const MaterialApp(
          home: GuestWorkspacePage(firebaseReady: false),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Interact').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Two-person interview'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Download / Share PDF'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Selected participant'));
    await tester.pumpAndSettle();

    expect(find.text('Preview PDF'), findsOneWidget);
    expect(find.text('Alice answer'), findsOneWidget);
    expect(find.text('Bob answer'), findsNothing);
    expect(find.text('Share PDF'), findsOneWidget);
    expect(find.text('Download PDF'), findsOneWidget);
    expect(find.text('Print / Save PDF fallback'), findsOneWidget);
  });
}

Finder _field(String label) => find.byWidgetPredicate(
  (widget) => widget is TextField && widget.decoration?.labelText == label,
);

TextField _answerField(WidgetTester tester) =>
    tester.widget<TextField>(_field('Local answer').first);

Future<void> _selectParticipant(WidgetTester tester, String name) async {
  final selector = find.byWidgetPredicate(
    (widget) =>
        widget is DropdownButtonFormField<String> &&
        widget.decoration?.labelText == 'Active participant',
  );
  await tester.tap(selector);
  await tester.pumpAndSettle();
  await tester.tap(find.text(name).last);
  await tester.pumpAndSettle();
}

Map<String, dynamic> _twoParticipantSession() => {
  'id': 'two-person-session',
  'title': 'Two-person interview',
  'visibility': 'private_local',
  'participants': [
    {'id': 'alice-id', 'name': 'Alice'},
    {'id': 'bob-id', 'name': 'Bob'},
  ],
  'questions': [
    {
      'id': 'shared-root',
      'text': 'Shared prompt',
      'scope': 'shared',
      'answers': [
        {
          'participant_id': 'alice-id',
          'body': 'Alice answer',
          'follow_ups': [],
        },
        {
          'participant_id': 'bob-id',
          'body': 'Bob answer',
          'follow_ups': [
            {
              'id': 'bob-branch',
              'text': 'Bob follow-up',
              'scope': 'participant',
              'target_participant_id': 'bob-id',
              'answers': [
                {
                  'participant_id': 'bob-id',
                  'body': 'Bob branch answer',
                  'follow_ups': [],
                },
              ],
            },
          ],
        },
      ],
    },
    {
      'id': 'bob-root',
      'text': 'Bob-only question',
      'scope': 'participant',
      'target_participant_id': 'bob-id',
      'answers': [
        {
          'participant_id': 'bob-id',
          'body': '',
          'follow_ups': [],
        },
      ],
    },
  ],
};

Map<String, dynamic> _narrowSession() {
  Map<String, dynamic> branch(int depth) => {
    'id': 'branch-$depth',
    'text': 'A nested follow-up question with a deliberately long label $depth',
    'scope': 'participant',
    'target_participant_id': 'long-name',
    'answers': [
      {
        'participant_id': 'long-name',
        'body': 'Answer $depth',
        'follow_ups': depth == 8 ? [] : [branch(depth + 1)],
      },
    ],
  };
  return {
    'id': 'narrow-session',
    'title': 'A long session title that should truncate cleanly',
    'participants': [
      {
        'id': 'long-name',
        'name':
            'A participant name with enough words to wrap at a narrow mobile width',
      },
    ],
    'questions': [
      {
        'id': 'narrow-root',
        'text': 'A prepared prompt with a long but readable question label',
        'scope': 'shared',
        'answers': [
          {
            'participant_id': 'long-name',
            'body': 'Local answer',
            'follow_ups': [branch(1)],
          },
        ],
      },
    ],
  };
}

class _MemoryGuestStorage implements GuestStorage {
  String? value;

  @override
  void remove() => value = null;

  @override
  String? read() => value;

  @override
  void write(String value) => this.value = value;
}
