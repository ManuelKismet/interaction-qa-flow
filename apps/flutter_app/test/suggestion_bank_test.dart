import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:int_qa_flow/features/suggestions/suggestion_bank_page.dart';
import 'package:int_qa_flow/features/suggestions/suggestion_bank_repository.dart';

class FakeBank extends SuggestionBankRepository {
  FakeBank() : super(Dio());
  final writes = <BankJson>[];
  bool failOnce = true;
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
      return <dynamic>[
            {
              'scope_type': 'organisation',
              'scope_id': 'org-1',
              'label': 'Organisation',
            },
          ]
          as T;
    }
    if (path == '/reviewers') {
      return <dynamic>[
            {'id': 'reviewer-1', 'name': 'Facilities owner'},
          ]
          as T;
    }
    if (data != null) {
      writes.add(Map<String, dynamic>.from(data));
      if (failOnce) {
        failOnce = false;
        throw StateError('Network acknowledgement unavailable');
      }
      return <String, dynamic>{'id': 'item-1'} as T;
    }
    return <String, dynamic>{
          'related': <dynamic>[],
          'knowledge': <dynamic>[],
          'prompts': <dynamic>[],
          'method': 'Scoped keyword matching',
        }
        as T;
  }
}

BankJson item({bool manager = false, bool contributor = true}) => {
  'id': 'item-1',
  'scope_type': 'organisation',
  'scope_id': 'org-1',
  'kind': 'etiquette',
  'title': 'Refill printer paper',
  'status': 'submitted',
  'revision': 1,
  'owner_name': null,
  'author_name': 'Employee',
  'review_due_at': '2026-11-10',
  'problem': 'The tray is empty',
  'proposal': 'Refill after the last sheet',
  'benefit': 'Colleagues can print',
  'can_manage': manager,
  'can_contribute': contributor,
  'following': false,
  'activities': <dynamic>[],
  'unanswered': true,
  'overdue': true,
  'unread': true,
};
void main() {
  testWidgets('summary shows overdue review and unread update', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BankSummaryCard(item: item(), onTap: () {}),
        ),
      ),
    );
    expect(find.textContaining('Review overdue'), findsOneWidget);
    expect(find.textContaining('New update'), findsOneWidget);
  });
  testWidgets('contributors can comment but do not receive decision controls', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: BankDetail(
                uid: 'worker',
                realm: 'organisation',
                item: item(),
                onChanged: () {},
              ),
            ),
          ),
        ),
      ),
    );
    expect(find.text('Add contribution'), findsOneWidget);
    expect(find.text('Respond'), findsNothing);
    expect(find.text('Assign'), findsNothing);
  });
  testWidgets(
    'viewers cannot contribute and agreed practices survive closed status',
    (tester) async {
      final closed = {
        ...item(contributor: false),
        'status': 'implemented',
        'practice': 'Refill the tray after using its last sheet.',
      };
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: BankDetail(
                  uid: 'viewer',
                  realm: 'group',
                  item: closed,
                  onChanged: () {},
                ),
              ),
            ),
          ),
        ),
      );
      expect(find.text('Add contribution'), findsNothing);
      expect(find.text('Support and follow'), findsNothing);
      expect(find.text('Agreed workplace practice'), findsOneWidget);
      expect(find.text(closed['practice'] as String), findsOneWidget);
    },
  );
  testWidgets(
    'official response draft and retry key survive failed acknowledgement',
    (tester) async {
      final repo = FakeBank();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [suggestionBankRepositoryProvider.overrideWithValue(repo)],
          child: MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => showDialog<bool>(
                    context: context,
                    builder: (_) => BankDecisionDialog(
                      uid: 'reviewer',
                      realm: 'organisation',
                      item: item(manager: true),
                      action: 'respond',
                    ),
                  ),
                  child: const Text('Open response'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open response'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextField),
        'Facilities will review this by Friday.',
      );
      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Update not confirmed'), findsOneWidget);
      expect(
        find.text('Facilities will review this by Friday.'),
        findsOneWidget,
      );
      expect(find.byType(BankDecisionDialog), findsOneWidget);
      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();
      expect(find.byType(BankDecisionDialog), findsNothing);
      expect(repo.writes.length, 2);
      expect(repo.writes[0]['client_key'], repo.writes[1]['client_key']);
      expect(repo.writes[0]['expected_revision'], 1);
    },
  );
  testWidgets(
    'submission keeps original draft and retry key after network failure',
    (tester) async {
      final repo = FakeBank();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [suggestionBankRepositoryProvider.overrideWithValue(repo)],
          child: MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => showDialog<BankJson>(
                    context: context,
                    barrierDismissible: false,
                    builder: (_) => const BankSubmissionDialog(
                      uid: 'worker',
                      realm: 'organisation',
                      scope: {
                        'scope_type': 'organisation',
                        'scope_id': 'org-1',
                        'label': 'Organisation',
                      },
                    ),
                  ),
                  child: const Text('Open submission'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open submission'));
      await tester.pumpAndSettle();
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'Refill printer');
      await tester.enterText(fields.at(1), 'Last sheet used');
      await tester.enterText(fields.at(2), 'Please refill it');
      await tester.tap(find.text('Submit'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Could not confirm submission'),
        findsOneWidget,
      );
      expect(find.text('Refill printer'), findsOneWidget);
      await tester.tap(find.text('Submit'));
      await tester.pumpAndSettle();
      expect(repo.writes.length, 2);
      expect(repo.writes[0]['client_key'], repo.writes[1]['client_key']);
      expect(find.byType(BankSubmissionDialog), findsNothing);
    },
  );
}
