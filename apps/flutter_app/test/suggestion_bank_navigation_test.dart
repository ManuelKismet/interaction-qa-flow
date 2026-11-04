import 'dart:async';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:int_qa_flow/core/auth/auth_providers.dart';
import 'package:int_qa_flow/core/routing/session_deep_link.dart';
import 'package:int_qa_flow/features/suggestions/group_suggestion_workspace.dart';
import 'package:int_qa_flow/features/suggestions/suggestion_bank_page.dart';
import 'package:int_qa_flow/features/suggestions/suggestion_bank_repository.dart';
import 'suggestion_bank_test.dart' show item;

class BankUser implements User {
  BankUser(this.uid);
  @override
  final String uid;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class GroupBankRepository extends SuggestionBankRepository {
  GroupBankRepository() : super(Dio());
  @override
  Future<T> request<T>(
    String uid,
    String realm,
    String path, {
    BankJson query = const {},
    BankJson? data,
    CancelToken? cancelToken,
  }) async {
    if (path == '/scopes') {
      return (uid == 'other'
              ? <dynamic>[]
              : <dynamic>[
                  {
                    'scope_type': 'group',
                    'scope_id': 'group-1',
                    'label': 'Facilities',
                  },
                ])
          as T;
    }
    final record = {...item(), 'scope_type': 'group', 'scope_id': 'group-1'};
    if (path == '') {
      return <String, dynamic>{
            'items': [record],
            'has_more': false,
          }
          as T;
    }
    if (path == '/item-1') return record as T;
    return <String, dynamic>{
          'method': 'Scoped matching',
          'related': <dynamic>[],
          'knowledge': <dynamic>[],
          'prompts': <dynamic>[],
        }
        as T;
  }
}

void main() {
  test('suggestion URLs survive launch and reload', () {
    expect(
      sessionDeepLinkInitialLocation(
        Uri.parse('https://example.invalid/#/suggestions/abc'),
      ),
      '/suggestions/abc',
    );
    expect(
      sessionDeepLinkInitialLocation(
        Uri.parse('https://example.invalid/group-suggestions/abc'),
      ),
      '/group-suggestions/abc',
    );
  });
  testWidgets(
    'Group-only accounts navigate without an organisation or nested browser router',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authStateProvider.overrideWith(
              (ref) => Stream.value(BankUser('worker')),
            ),
            suggestionBankRepositoryProvider.overrideWithValue(
              GroupBankRepository(),
            ),
          ],
          child: const MaterialApp(
            home: GroupSuggestionWorkspace(groupId: 'group-1'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Refill printer paper'), findsOneWidget);
      await tester.tap(find.text('Refill printer paper'));
      await tester.pumpAndSettle();
      expect(find.byType(BankDetail), findsOneWidget);
      expect(find.textContaining('Audience: Facilities'), findsOneWidget);
      await tester.tap(find.text('Back to suggestions'));
      await tester.pumpAndSettle();
      expect(find.byType(BankDetail), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('account changes discard stale displayed Group context', (
    tester,
  ) async {
    final accounts = StreamController<User?>();
    addTearDown(accounts.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith((ref) => accounts.stream),
          suggestionBankRepositoryProvider.overrideWithValue(
            GroupBankRepository(),
          ),
        ],
        child: const MaterialApp(
          home: GroupSuggestionWorkspace(groupId: 'group-1'),
        ),
      ),
    );
    accounts.add(BankUser('worker'));
    await tester.pumpAndSettle();
    expect(find.text('Refill printer paper'), findsOneWidget);
    accounts.add(BankUser('other'));
    await tester.pumpAndSettle();
    expect(find.text('Refill printer paper'), findsNothing);
    expect(
      find.text('Join an active Group to use its Suggestion Bank.'),
      findsOneWidget,
    );
  });
}
