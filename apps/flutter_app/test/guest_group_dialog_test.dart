import 'dart:async';

import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:int_qa_flow/core/auth/auth_providers.dart';
import 'package:int_qa_flow/features/guest/data/guest_group_repository.dart';
import 'package:int_qa_flow/features/guest/data/guest_storage_interface.dart';
import 'package:int_qa_flow/features/guest/data/guest_workspace_store.dart';
import 'package:int_qa_flow/features/guest/domain/guest_workspace_data.dart';
import 'package:int_qa_flow/features/guest/presentation/guest_workspace_page.dart';

class _TestFirebaseAuth implements FirebaseAuth {
  @override
  User? get currentUser => _TestUser();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _TestUser implements User {
  @override
  String get uid => 'test-anonymous-uid';

  @override
  bool get isAnonymous => true;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _PendingEntryRepository extends GuestGroupRepository {
  _PendingEntryRepository() : super(Dio());

  final exportResult = Completer<Map<String, dynamic>>();
  final historyResult = Completer<List<Map<String, dynamic>>>();
  var exportRequested = false;
  var historyRequested = false;

  @override
  Future<List<Map<String, dynamic>>> listGroups() async => [
    {'id': 'group-1', 'name': 'Group', 'role': 'viewer'},
  ];

  @override
  Future<Map<String, dynamic>> getGroup(String groupId) async => {
    'id': groupId,
    'role': 'viewer',
    'members': [],
  };

  @override
  Future<List<Map<String, dynamic>>> searchEntries({
    required String groupId,
    String query = '',
  }) async => [
    {
      'id': 'entry-1',
      'kind': 'knowledge',
      'title': 'Shared entry',
      'revision': 1,
      'data': {'answer': 'Shared answer'},
    },
  ];

  @override
  Future<Map<String, dynamic>> exportEntry({
    required String groupId,
    required String entryId,
  }) {
    exportRequested = true;
    return exportResult.future;
  }

  @override
  Future<List<Map<String, dynamic>>> entryHistory({
    required String groupId,
    required String entryId,
  }) {
    historyRequested = true;
    return historyResult.future;
  }
}

class _FailingGroupsRepository extends GuestGroupRepository {
  _FailingGroupsRepository() : super(Dio());

  var attempts = 0;

  @override
  Future<List<Map<String, dynamic>>> listGroups() async {
    attempts++;
    throw StateError('private test detail');
  }
}

class _ShareRepository extends GuestGroupRepository {
  _ShareRepository() : super(Dio());

  Set<String>? sharedKnowledgeIds;
  Set<String>? sharedSessionIds;

  @override
  Future<List<Map<String, dynamic>>> listGroups() async => [
    {'id': 'group-1', 'name': 'Local Safety Team', 'role': 'editor'},
  ];

  @override
  Future<Map<String, dynamic>> getGroup(String groupId) async => {
    'id': groupId,
    'name': 'Local Safety Team',
    'role': 'editor',
    'members': [],
  };

  @override
  Future<List<Map<String, dynamic>>> searchEntries({
    required String groupId,
    String query = '',
  }) async => [];

  @override
  Future<List<Map<String, dynamic>>> importSelected({
    required String groupId,
    required GuestWorkspaceData data,
    required Set<String> knowledgeIds,
    required Set<String> sessionIds,
  }) async {
    sharedKnowledgeIds = knowledgeIds;
    sharedSessionIds = sessionIds;
    return const [];
  }
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

void main() {
  testWidgets('group lookup failure does not claim there are no groups', (
    tester,
  ) async {
    final repository = _FailingGroupsRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          firebaseAuthProvider.overrideWithValue(_TestFirebaseAuth()),
          guestGroupRepositoryProvider.overrideWithValue(repository),
        ],
        child: const MaterialApp(home: SharedGuestGroupsPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.textContaining('The guest group request could not be verified'),
      findsOneWidget,
    );
    expect(find.textContaining('No approved guest groups are linked'), findsNothing);
    expect(find.text('private test detail'), findsNothing);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(repository.attempts, 2);
  });

  testWidgets('group sharing is opt-in and describes online destination', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = _ShareRepository();
    final store = GuestWorkspaceStore(_MemoryGuestStorage());
    await store.save(
      const GuestWorkspaceData(
        knowledge: [
          {'id': 'knowledge-1', 'title': 'Local knowledge'},
        ],
        sessions: [
          {
            'id': 'session-1',
            'title': 'Private interview',
            'participants': [
              {'id': 'participant-1', 'name': 'Alice'},
            ],
            'questions': [
              {
                'id': 'question-1',
                'text': 'Prompt',
                'answers': [
                  {'participant_id': 'participant-1', 'body': 'Private answer'},
                ],
              },
            ],
          },
        ],
        templates: [
          {'id': 'template-1', 'name': 'Local template'},
        ],
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          firebaseAuthProvider.overrideWithValue(_TestFirebaseAuth()),
          guestGroupRepositoryProvider.overrideWithValue(repository),
          guestWorkspaceStoreProvider.overrideWithValue(store),
        ],
        child: const MaterialApp(home: SharedGuestGroupsPage()),
      ),
    );
    await _pumpUntilEnabled(
      tester,
      find.widgetWithText(OutlinedButton, 'Preview and share local work'),
    );

    await tester.tap(find.text('Preview and share local work'));
    await _pumpUntilFound(
      tester,
      find.text('Preview sharing to Local Safety Team'),
    );
    expect(find.text('Preview sharing to Local Safety Team'), findsOneWidget);
    expect(
      find.textContaining('uploads selected copies online to Local Safety Team'),
      findsOneWidget,
    );
    expect(find.textContaining('Approved group members'), findsOneWidget);
    expect(
      find.textContaining('local originals stay on this device'),
      findsOneWidget,
    );
    expect(
      find.text('Sharing uploads all participants and answer-owned branches'),
      findsOneWidget,
    );
    expect(find.text('Local templates remain on this device'), findsOneWidget);
    expect(
      find.textContaining(
        'existing group copy is reused without being overwritten',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('added locally'), findsNothing);
    expect(
      tester.widget<CheckboxListTile>(
        find.ancestor(
          of: find.text('Local knowledge'),
          matching: find.byType(CheckboxListTile),
        ),
      ).value,
      isFalse,
    );
    expect(
      tester.widget<CheckboxListTile>(
        find.ancestor(
          of: find.text('Private interview'),
          matching: find.byType(CheckboxListTile),
        ),
      ).value,
      isFalse,
    );
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Share selected with group'),
          )
          .onPressed,
      isNull,
    );

    await tester.tap(find.text('Cancel'));
    await _pumpUntilGone(
      tester,
      find.text('Preview sharing to Local Safety Team'),
    );
    expect(repository.sharedKnowledgeIds, isNull);
    expect((await store.load()).sessions.single['title'], 'Private interview');

    await tester.tap(find.text('Preview and share local work'));
    await _pumpUntilFound(
      tester,
      find.text('Preview sharing to Local Safety Team'),
    );
    await tester.tap(find.text('Local knowledge'));
    await tester.pump();
    await tester.tap(find.text('Share selected with group'));
    await tester.pumpAndSettle();

    expect(repository.sharedKnowledgeIds, {'knowledge-1'});
    expect(repository.sharedSessionIds, isEmpty);
    expect((await store.load()).knowledge.single['title'], 'Local knowledge');
    expect((await store.load()).sessions.single['title'], 'Private interview');
  });

  for (final action in ['Download / Share PDF', 'History']) {
    testWidgets(
      'does not open $action result after the entry dialog is dismissed',
      (tester) async {
        final repository = _PendingEntryRepository();
        final navigatorKey = GlobalKey<NavigatorState>();
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              firebaseAuthProvider.overrideWithValue(_TestFirebaseAuth()),
              guestGroupRepositoryProvider.overrideWithValue(repository),
            ],
            child: MaterialApp(
              navigatorKey: navigatorKey,
              home: const SharedGuestGroupsPage(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Shared entry'));
        await tester.pumpAndSettle();
        await tester.tap(find.text(action).last);
        await tester.pump();
        expect(
          action == 'Download / Share PDF'
              ? repository.exportRequested
              : repository.historyRequested,
          isTrue,
        );

        navigatorKey.currentState!.pop();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pump();
        expect(find.byType(AlertDialog), findsNothing);

        if (action == 'Download / Share PDF') {
          repository.exportResult.complete({'answer': 'Authorized export'});
        } else {
          repository.historyResult.complete([
            {'revision': 1},
          ]);
        }
        await tester.pumpAndSettle();
        expect(find.text('Authorized group export'), findsNothing);
        expect(find.text('Entry revisions'), findsNothing);
      },
    );
  }
}

Future<void> _pumpUntilEnabled(WidgetTester tester, Finder finder) async {
  for (var attempt = 0; attempt < 40; attempt++) {
    await tester.pump(const Duration(milliseconds: 50));
    if (finder.evaluate().isNotEmpty &&
        tester.widget<OutlinedButton>(finder).onPressed != null) {
      return;
    }
  }
  fail('Widget did not become enabled: $finder');
}

Future<void> _pumpUntilFound(WidgetTester tester, Finder finder) async {
  for (var attempt = 0; attempt < 40; attempt++) {
    await tester.pump(const Duration(milliseconds: 50));
    if (finder.evaluate().isNotEmpty) return;
  }
  fail('Widget did not appear: $finder');
}

Future<void> _pumpUntilGone(WidgetTester tester, Finder finder) async {
  for (var attempt = 0; attempt < 40; attempt++) {
    await tester.pump(const Duration(milliseconds: 50));
    if (finder.evaluate().isEmpty) return;
  }
  fail('Widget did not disappear: $finder');
}
