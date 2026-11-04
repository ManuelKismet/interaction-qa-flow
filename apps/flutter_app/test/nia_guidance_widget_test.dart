import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:int_qa_flow/core/nia/nia_guidance.dart';
import 'package:int_qa_flow/features/suggestions/suggestion_bank_page.dart';
import 'package:int_qa_flow/features/suggestions/suggestion_bank_repository.dart';

Widget host(Widget child, {String user = 'alice', String authority = 'v1'}) =>
    NiaHost(
      subject: user,
      authorityRevision: authority,
      child: MaterialApp(home: Scaffold(body: child)),
    );

class _RelatedRepository extends SuggestionBankRepository {
  _RelatedRepository() : super(Dio());
  final reads = <Completer<BankJson>>[];
  final queries = <String>[];
  @override
  Future<T> request<T>(
    String uid,
    String realm,
    String path, {
    BankJson query = const {},
    BankJson? data,
    CancelToken? cancelToken,
  }) async {
    if (path != '/nia') throw StateError('Unexpected request');
    queries.add(query['query'] as String);
    final result = Completer<BankJson>();
    reads.add(result);
    return await result.future as T;
  }
}

BankJson related(String title) => {
  'related': [
    {'id': title, 'title': title, 'status': 'submitted'},
  ],
  'knowledge': <dynamic>[],
  'prompts': <dynamic>[],
};
void main() {
  testWidgets(
    'dialog bridge withdraws related results after workspace authority changes',
    (tester) async {
      final role = ValueNotifier('editor');
      addTearDown(role.dispose);
      final repository = _RelatedRepository();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            suggestionBankRepositoryProvider.overrideWithValue(repository),
          ],
          child: host(
            ValueListenableBuilder<String>(
              valueListenable: role,
              builder: (context, value, _) => NiaWorkspaceScope(
                workspace: 'organisation:org-one',
                authorityRevision: value,
                child: Builder(
                  builder: (source) => TextButton(
                    child: const Text('Compose'),
                    onPressed: () {
                      showDialog<void>(
                        context: source,
                        builder: (_) => NiaHost.preserve(
                          source,
                          const BankSubmissionDialog(
                            uid: 'alice',
                            realm: 'organisation',
                            scope: {
                              'scope_type': 'organisation',
                              'scope_id': 'org-one',
                              'label': 'Operations',
                            },
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Compose'));
      await tester.pumpAndSettle();
      final title = find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.labelText == 'Title',
      );
      await tester.enterText(title, 'Printer proposal');
      final check = find.text('Check related suggestions before submitting');
      await tester.ensureVisible(check);
      await tester.tap(check);
      await tester.pump();
      repository.reads.single.complete(related('Visible related result'));
      await tester.pumpAndSettle();
      expect(find.text('Visible related result'), findsOneWidget);
      role.value = 'viewer';
      await tester.pumpAndSettle();
      expect(find.text('Visible related result'), findsNothing);
      expect(
        tester.widget<TextField>(title).controller?.text,
        'Printer proposal',
      );
      await tester.ensureVisible(check);
      await tester.tap(check);
      await tester.pumpAndSettle();
      expect(repository.queries.length, 1);
    },
  );

  testWidgets('ordinary workflow stays quiet without a generic NIA card', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(const NiaInlineGuidance(topic: NiaTopic.suggestion)),
    );
    await tester.pumpAndSettle();
    expect(find.byType(Card), findsNothing);
    expect(find.textContaining('NIA'), findsNothing);
    expect(find.textContaining('Who will respond'), findsNothing);
    expect(find.byTooltip('Dismiss guidance'), findsNothing);
  });
  testWidgets('overdue context yields a useful action that can be dismissed', (
    tester,
  ) async {
    var opened = false;
    await tester.pumpWidget(
      host(
        NiaInlineGuidance(
          topic: NiaTopic.suggestion,
          facts: const {'overdue': true},
          actions: {'overdue': ('Review overdue', () => opened = true)},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('A review date has passed'), findsOneWidget);
    expect(find.byType(Card), findsNothing);
    await tester.tap(find.text('Review overdue'));
    expect(opened, isTrue);
    await tester.tap(find.byTooltip('Dismiss guidance'));
    await tester.pumpAndSettle();
    expect(find.textContaining('A review date has passed'), findsNothing);
  });
  testWidgets(
    'busy and completed states do not produce automatic interruptions',
    (tester) async {
      await tester.pumpWidget(
        host(
          const NiaInlineGuidance(
            topic: NiaTopic.suggestion,
            facts: {'overdue': true},
            busy: true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byTooltip('Dismiss guidance'), findsNothing);
      await tester.pumpWidget(
        host(
          const NiaInlineGuidance(
            topic: NiaTopic.suggestion,
            facts: {'overdue': true},
            complete: true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byTooltip('Dismiss guidance'), findsNothing);
    },
  );
  testWidgets(
    'requested guidance uses current storage facts rather than a fixed blob',
    (tester) async {
      await tester.pumpWidget(
        host(
          const NiaHelpButton(
            topic: NiaTopic.storage,
            tooltip: 'Storage help',
            title: 'Current storage',
            facts: {'private': true, 'saveStatus': 'Saved on this device'},
          ),
        ),
      );
      expect(find.textContaining('New Knowledge'), findsNothing);
      await tester.tap(find.byTooltip('Storage help'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining(
          'New Knowledge and Interact sessions are saved privately',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('Saved on this device'), findsOneWidget);
      expect(find.textContaining('Guest workspace'), findsNothing);
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
    },
  );
  for (final accountChange in [true, false]) {
    testWidgets(
      'open guidance withdraws on ' +
          (accountChange ? 'account' : 'authority') +
          ' change',
      (tester) async {
        final revision = ValueNotifier(0);
        addTearDown(revision.dispose);
        await tester.pumpWidget(
          ValueListenableBuilder<int>(
            valueListenable: revision,
            builder: (context, value, _) => host(
              const NiaHelpButton(
                topic: NiaTopic.groups,
                tooltip: 'Group help',
                title: 'Group access',
                facts: {'verified': true, 'role': 'editor'},
              ),
              user: accountChange && value == 1 ? 'bob' : 'alice',
              authority: 'v' + value.toString(),
            ),
          ),
        );
        await tester.tap(find.byTooltip('Group help'));
        await tester.pumpAndSettle();
        expect(
          find.textContaining('Your Group role is editor'),
          findsOneWidget,
        );
        revision.value = 1;
        await tester.pumpAndSettle();
        expect(find.textContaining('Your Group role is editor'), findsNothing);
        expect(
          find.textContaining('workspace context changed'),
          findsOneWidget,
        );
        await tester.tap(find.text('Close'));
        await tester.pumpAndSettle();
      },
    );
  }
  testWidgets(
    'workspace authority changes invalidate open guidance without another account owner',
    (tester) async {
      final role = ValueNotifier('editor');
      addTearDown(role.dispose);
      await tester.pumpWidget(
        host(
          ValueListenableBuilder<String>(
            valueListenable: role,
            builder: (context, value, _) => NiaWorkspaceScope(
              workspace: 'group:one',
              authorityRevision: value,
              child: NiaHelpButton(
                topic: NiaTopic.groups,
                tooltip: 'Group help',
                title: 'Group access',
                facts: {'verified': true, 'role': value},
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byTooltip('Group help'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Your Group role is editor'), findsOneWidget);
      role.value = 'viewer';
      await tester.pumpAndSettle();
      expect(find.textContaining('Your Group role is editor'), findsNothing);
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
    },
  );
  testWidgets('old read cancellation cannot revoke a newer request', (
    tester,
  ) async {
    NiaReadGuard? old, newer;
    await tester.pumpWidget(
      host(
        Builder(
          builder: (context) => Column(
            children: [
              TextButton(
                onPressed: () => old = NiaReadGuard.begin(
                  context,
                  subject: 'alice',
                  workspace: 'group:one',
                  purpose: 'related',
                  facts: const {'query': 'old'},
                ),
                child: const Text('Old request'),
              ),
              TextButton(
                onPressed: () => newer = NiaReadGuard.begin(
                  context,
                  subject: 'alice',
                  workspace: 'group:one',
                  purpose: 'related',
                  facts: const {'query': 'new'},
                ),
                child: const Text('New request'),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.tap(find.text('Old request'));
    expect(old?.current, isTrue);
    await tester.tap(find.text('New request'));
    expect(old?.current, isFalse);
    expect(newer?.current, isTrue);
    old?.dispose();
    expect(newer?.current, isTrue);
    newer?.dispose();
  });
  testWidgets(
    'related lookup drops late results after title changes and preserves the draft',
    (tester) async {
      final repository = _RelatedRepository();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            suggestionBankRepositoryProvider.overrideWithValue(repository),
          ],
          child: host(
            const BankSubmissionDialog(
              uid: 'alice',
              realm: 'organisation',
              scope: {
                'scope_type': 'organisation',
                'scope_id': 'org-one',
                'label': 'Operations',
              },
            ),
          ),
        ),
      );
      final title = find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.labelText == 'Title',
      );
      await tester.enterText(title, 'Old printer proposal');
      final check = find.text('Check related suggestions before submitting');
      await tester.ensureVisible(check);
      await tester.tap(check);
      await tester.pump();
      expect(repository.queries, ['Old printer proposal']);
      await tester.ensureVisible(title);
      await tester.enterText(title, 'New printer proposal');
      repository.reads.first.complete(related('Old related result'));
      await tester.pumpAndSettle();
      expect(find.text('Old related result'), findsNothing);
      await tester.ensureVisible(check);
      await tester.tap(check);
      await tester.pump();
      expect(repository.queries, [
        'Old printer proposal',
        'New printer proposal',
      ]);
      repository.reads.last.complete(related('Current related result'));
      await tester.pumpAndSettle();
      expect(find.text('Current related result'), findsOneWidget);
      expect(
        tester.widget<TextField>(title).controller?.text,
        'New printer proposal',
      );
    },
  );
}
