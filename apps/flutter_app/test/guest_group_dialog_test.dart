import 'dart:async';

import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:int_qa_flow/core/auth/auth_providers.dart';
import 'package:int_qa_flow/features/guest/data/guest_group_repository.dart';
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
