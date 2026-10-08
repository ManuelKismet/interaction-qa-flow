import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:int_qa_flow/core/auth/auth_providers.dart';
import 'package:int_qa_flow/features/ask/application/ask_controller.dart';
import 'package:int_qa_flow/features/ask/application/ask_suggestions_controller.dart';
import 'package:int_qa_flow/features/ask/presentation/ask_page.dart';
import 'package:int_qa_flow/features/guest/data/guest_group_repository.dart';
import 'package:int_qa_flow/features/guest/data/guest_storage.dart';
import 'package:int_qa_flow/features/guest/data/guest_workspace_store.dart';
import 'package:int_qa_flow/features/guest/data/personal_workspace_repository.dart';
import 'package:int_qa_flow/features/guest/domain/guest_workspace_data.dart';
import 'package:int_qa_flow/features/guest/presentation/guest_workspace_page.dart';
import 'package:int_qa_flow/features/questions/data/questions_repository.dart';
import 'package:int_qa_flow/features/questions/domain/question_models.dart';
import 'package:int_qa_flow/shared/widgets/knowledge_section_tabs.dart';

class _MemoryGuestStorage implements GuestStorage {
  String? value;

  @override
  String? read() => value;

  @override
  void write(String value) => this.value = value;

  @override
  void remove() => value = null;
}

class _QuestionsRepository extends QuestionsRepository {
  _QuestionsRepository() : super(Dio());

  final createdQuestions = <Map<String, String?>>[];
  var returnNoResults = false;

  @override
  Future<List<SemanticSearchResult>> searchQuestions(
    String query, {
    int limit = 5,
  }) async {
    if (returnNoResults) return [];
    return [
      SemanticSearchResult(
        questionId: 'org-question',
        title: 'Organisation password recovery',
        acceptedAnswerBody: 'Contact support to recover access.',
        similarity: 0.9,
        confidence: 'high_confidence',
        answerStatus: 'verified',
        answerId: 'org-answer',
        challengeCount: 0,
        hasOpenChallenge: false,
        canonicalQuestionId: 'org-question',
        canonicalTitle: 'Organisation password recovery',
        matchedQuestionId: 'org-question',
        matchedQuestionIds: const ['org-question'],
        matchedText: 'Contact support to recover access.',
        matchSource: 'canonical',
        matchMethod: 'hybrid',
        department: const DepartmentSummary(id: 'dept', name: 'Security'),
        team: const TeamSummary(id: 'team', name: 'Identity'),
        organisationName: 'Northwind',
        relevanceScore: 1.4,
      ),
    ];
  }

  @override
  Future<String> createQuestion({
    required String title,
    String? body,
    String? departmentId,
    String? teamId,
  }) async {
    createdQuestions.add({
      'title': title,
      'body': body,
      'departmentId': departmentId,
      'teamId': teamId,
    });
    return 'created-question';
  }
}

class _PersonalRepository extends PersonalWorkspaceRepository {
  _PersonalRepository() : super(Dio());

  final searchQueries = <String>[];
  final results = <Map<String, dynamic>>[
    {
      'source_id': 'private-id',
      'title': 'Private account policy',
      'data': {'answer': 'Keep account passwords unique.'},
      'snippet': 'Keep account passwords unique.',
      'relevance_score': 1.5,
      'match_method': 'keyword',
    },
  ];
  final writes = <String>[];

  @override
  Future<Map<String, dynamic>> searchKnowledge(
    String query, {
    required String expectedUid,
  }) async {
    searchQueries.add(query);
    return {'partial': false, 'results': results};
  }

  @override
  Future<List<Map<String, dynamic>>> listItems({
    required String expectedUid,
  }) async => [
    {
      'kind': 'knowledge',
      'data': {
        'id': 'private-id',
        'title': 'Private account policy',
        'answer': 'Keep account passwords unique.',
      },
    },
  ];

  @override
  Future<List<Map<String, dynamic>>> importItems(
    List<Map<String, dynamic>> items, {
    required String expectedUid,
  }) async {
    writes.add('import');
    return items;
  }

  @override
  Future<Map<String, dynamic>> updateItem({
    required String id,
    required String expectedUid,
    required int expectedRevision,
    required String title,
    required Map<String, dynamic> data,
  }) async {
    writes.add('update');
    return {};
  }

  @override
  Future<void> deleteItem(
    String id, {
    required String expectedUid,
    required int expectedRevision,
  }) async {
    writes.add('delete');
  }
}

class _VerifiedUser extends Fake implements User {
  @override
  String? get email => 'ask-test@example.invalid';

  @override
  String get uid => 'verified-uid';

  @override
  bool get emailVerified => true;

  @override
  bool get isAnonymous => false;
}

class _TestFirebaseAuth extends Fake implements FirebaseAuth {
  _TestFirebaseAuth(this.user);

  final User user;

  @override
  User get currentUser => user;

  @override
  Stream<User?> authStateChanges() => Stream.value(user);
}

class _GroupRepository extends GuestGroupRepository {
  _GroupRepository() : super(Dio());

  final results = <Map<String, dynamic>>[
    {
      'id': 'group-entry',
      'group_id': 'group-id',
      'group_name': 'Platform team',
      'title': 'Group password notes',
      'data': {'answer': 'Use the team vault.'},
      'snippet': 'Use the team vault.',
      'relevance_score': 1.3,
      'match_method': 'keyword',
    },
  ];

  @override
  Future<List<Map<String, dynamic>>> listGroups() async => const [];

  @override
  Future<Map<String, dynamic>> searchKnowledge(String query) async => {
    'partial': false,
    'results': results,
  };
}

DepartmentSummary _department() =>
    const DepartmentSummary(id: 'dept', name: 'Security');

TeamSummary _team() => TeamSummary(
  id: 'team',
  name: 'Identity',
  departmentId: 'dept',
  department: _department(),
);

void _expectKnowledgeSubtitle({
  required WidgetTester tester,
  required String title,
  required String answer,
  required String storageStatus,
}) {
  final itemTile = find.ancestor(
    of: find.text(title),
    matching: find.byType(ListTile),
  );
  expect(itemTile, findsOneWidget);
  expect(
    find.descendant(
      of: itemTile,
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is Text &&
            widget.data?.contains(answer) == true &&
            widget.data?.contains(storageStatus) == true,
      ),
    ),
    findsOneWidget,
  );
}

void main() {
  testWidgets('Ask suggestions show unified source badges and open source', (
    tester,
  ) async {
    final storage = _MemoryGuestStorage();
    final questions = _QuestionsRepository();
    final personal = _PersonalRepository();
    final groups = _GroupRepository();
    final user = _VerifiedUser();
    await GuestWorkspaceStore(storage).save(
      const GuestWorkspaceData(
        knowledge: [
          {
            'id': 'local-id',
            'title': 'Password local guide',
            'answer': 'Rotate test credentials regularly.',
          },
        ],
      ),
    );
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const Scaffold(body: AskPage()),
        ),
        GoRoute(
          path: '/personal/questions',
          builder: (_, state) => GuestWorkspacePage(
            firebaseReady: true,
            personalWorkspaceEnabled: true,
            accountUser: user,
            membershipStatus: AccountMembershipStatus.active,
            initialKnowledgeItemId:
                state.uri.queryParameters['knowledgeItemId'],
            initialKnowledgeSection: KnowledgeSection.questions,
          ),
        ),
        GoRoute(
          path: '/questions/:id',
          builder: (_, state) => Text('Opened organisation: ${state.pathParameters['id']}'),
        ),
        GoRoute(
          path: '/guest/groups',
          builder: (_, state) => Text(
            'Opened group: ${state.uri.queryParameters['entryId']}',
          ),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          firebaseAuthProvider.overrideWithValue(_TestFirebaseAuth(user)),
          authStateProvider.overrideWith((ref) => Stream.value(user)),
          questionsRepositoryProvider.overrideWithValue(questions),
          departmentsProvider.overrideWith((ref) async => [_department()]),
          teamsProvider.overrideWith((ref) async => [_team()]),
          personalWorkspaceRepositoryProvider.overrideWithValue(personal),
          guestGroupRepositoryProvider.overrideWithValue(groups),
          guestWorkspaceStoreProvider.overrideWithValue(
            GuestWorkspaceStore(storage),
          ),
          askSearchIdentityProvider.overrideWithValue(
            const AskSearchIdentity(
              verifiedUid: 'verified-uid',
              membershipState: 'active',
              organisationId: 'org-id',
            ),
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    final questionField = find.byWidgetPredicate(
      (widget) =>
          widget is TextField &&
          widget.decoration?.hintText == 'Ask a question',
    );
    await tester.enterText(questionField, 'password');
    await tester.pump(const Duration(milliseconds: 360));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(Chip, 'Local'), findsOneWidget);
    expect(find.widgetWithText(Chip, 'Private'), findsOneWidget);
    expect(find.widgetWithText(Chip, 'Group: Platform team'), findsOneWidget);
    expect(
      find.widgetWithText(Chip, 'Organisation: Northwind'),
      findsOneWidget,
    );
    expect(find.widgetWithText(Chip, 'Department: Security'), findsOneWidget);
    expect(find.widgetWithText(Chip, 'Team: Identity'), findsOneWidget);
    expect(find.text('Keep account passwords unique.'), findsOneWidget);
    expect(find.text('Ask as new question'), findsOneWidget);
    expect(find.text('Department (optional)'), findsOneWidget);
    expect(find.text('Team (optional)'), findsOneWidget);

    await tester.ensureVisible(find.text('Group password notes'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Group password notes'));
    await tester.pumpAndSettle();
    expect(find.text('Opened group: group-entry'), findsOneWidget);

    Future<void> searchAgain() async {
      router.go('/');
      await tester.pumpAndSettle();
      await tester.enterText(questionField, 'password');
      await tester.pump(const Duration(milliseconds: 360));
      await tester.pumpAndSettle();
    }

    await searchAgain();
    await tester.ensureVisible(find.text('Organisation password recovery'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Organisation password recovery'));
    await tester.pumpAndSettle();
    expect(find.text('Opened organisation: org-question'), findsOneWidget);

    await searchAgain();
    await tester.ensureVisible(find.text('Private account policy'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Private account policy'));
    await tester.pumpAndSettle();
    expect(find.text('Saved Q&A'), findsOneWidget);
    expect(find.text('Private account policy'), findsOneWidget);
    _expectKnowledgeSubtitle(
      tester: tester,
      title: 'Private account policy',
      answer: 'Keep account passwords unique.',
      storageStatus: 'Personal account · saved',
    );

    await searchAgain();
    await tester.ensureVisible(find.text('Password local guide'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Password local guide'));
    await tester.pumpAndSettle();
    expect(find.text('Saved Q&A'), findsOneWidget);
    expect(find.text('Password local guide'), findsOneWidget);
    _expectKnowledgeSubtitle(
      tester: tester,
      title: 'Password local guide',
      answer: 'Rotate test credentials regularly.',
      storageStatus: 'Local on this device',
    );
  });

  testWidgets(
    'Ask submits only entered fields when local and private hits exist',
    (tester) async {
      final storage = _MemoryGuestStorage();
      final questions = _QuestionsRepository();
      final personal = _PersonalRepository();
      final groups = _GroupRepository();
      personal.results
        ..clear()
        ..add({
          'source_id': 'private-id',
          'title': 'Private password policy',
          'data': {'answer': 'Private-only account detail.'},
          'snippet': 'Private-only account detail.',
          'relevance_score': 1.5,
          'match_method': 'keyword',
        });
      await GuestWorkspaceStore(storage).save(
        const GuestWorkspaceData(
          knowledge: [
            {
              'id': 'local-id',
              'title': 'Local password guide',
              'answer': 'Local-only secret phrase.',
            },
          ],
        ),
      );
      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => const Scaffold(body: AskPage()),
          ),
          GoRoute(
            path: '/questions/:id',
            builder: (_, _) => const Text('Submitted'),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            questionsRepositoryProvider.overrideWithValue(questions),
            departmentsProvider.overrideWith((ref) async => [_department()]),
            teamsProvider.overrideWith((ref) async => [_team()]),
            personalWorkspaceRepositoryProvider.overrideWithValue(personal),
            guestGroupRepositoryProvider.overrideWithValue(groups),
            guestWorkspaceStoreProvider.overrideWithValue(
              GuestWorkspaceStore(storage),
            ),
            askSearchIdentityProvider.overrideWithValue(
              const AskSearchIdentity(
                verifiedUid: 'verified-uid',
                membershipState: 'active',
                organisationId: 'org-id',
              ),
            ),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      final titleField = find.byWidgetPredicate(
        (widget) =>
            widget is TextField &&
            widget.decoration?.hintText == 'Ask a question',
      );
      await tester.enterText(titleField, 'password');
      await tester.pump(const Duration(milliseconds: 360));
      await tester.pumpAndSettle();
      expect(find.text('Ask as new question'), findsOneWidget);
      expect(find.text('Local-only secret phrase.'), findsOneWidget);
      expect(find.text('Private-only account detail.'), findsOneWidget);

      final detailField = find.byWidgetPredicate(
        (widget) =>
            widget is TextField &&
            widget.decoration?.hintText == 'Add detail (optional)',
      );
      await tester.enterText(detailField, 'I typed this detail.');
      await tester.pump(const Duration(milliseconds: 360));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Department (optional)'));
      await tester.tap(find.text('No department'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Security').last);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Team (optional)'));
      await tester.tap(find.text('No team'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Security · Identity').last);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Ask as new question'));
      await tester.tap(find.text('Ask as new question'));
      await tester.pumpAndSettle();

      expect(find.text('Submitted'), findsOneWidget);
      expect(questions.createdQuestions, [
        {
          'title': 'password',
          'body': 'I typed this detail.',
          'departmentId': 'dept',
          'teamId': 'team',
        },
      ]);
      expect(
        questions.createdQuestions.single.values.join(' '),
        isNot(contains('Local-only secret phrase.')),
      );
      expect(
        questions.createdQuestions.single.values.join(' '),
        isNot(contains('Private-only account detail.')),
      );
      expect(personal.writes, isEmpty);
      expect(personal.searchQueries, ['password', 'password']);
      expect(
        personal.results.single['data']['answer'],
        'Private-only account detail.',
      );
      expect(storage.value, contains('Local-only secret phrase.'));
    },
  );

  testWidgets('Ask mobile chips wrap and keyboard advances', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final storage = _MemoryGuestStorage();
    final questions = _QuestionsRepository();
    final personal = _PersonalRepository();
    final groups = _GroupRepository();
    await GuestWorkspaceStore(storage).save(
      const GuestWorkspaceData(
        knowledge: [
          {
            'id': 'local-id',
            'title': 'Password recovery',
            'answer': 'Recover accounts with the help desk.',
          },
        ],
      ),
    );
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const Scaffold(body: AskPage()),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          questionsRepositoryProvider.overrideWithValue(questions),
          departmentsProvider.overrideWith((ref) async => [_department()]),
          teamsProvider.overrideWith((ref) async => [_team()]),
          personalWorkspaceRepositoryProvider.overrideWithValue(
            personal,
          ),
          guestGroupRepositoryProvider.overrideWithValue(groups),
          guestWorkspaceStoreProvider.overrideWithValue(
            GuestWorkspaceStore(storage),
          ),
          askSearchIdentityProvider.overrideWithValue(
            const AskSearchIdentity(
              verifiedUid: 'verified-uid',
              membershipState: 'active',
              organisationId: 'org-id',
            ),
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    final titleField = find.byWidgetPredicate(
      (widget) =>
          widget is TextField &&
          widget.decoration?.hintText == 'Ask a question',
    );
    await tester.enterText(titleField, 'password');
    await tester.testTextInput.receiveAction(TextInputAction.next);
    await tester.pumpAndSettle();
    final detailField = find.byWidgetPredicate(
      (widget) =>
          widget is TextField &&
          widget.decoration?.hintText == 'Add detail (optional)',
    );
    expect(
      tester
          .widget<EditableText>(
            find.descendant(
              of: detailField,
              matching: find.byType(EditableText),
            ),
          )
          .focusNode
          .hasFocus,
      isTrue,
    );
    await tester.pump(const Duration(milliseconds: 360));
    await tester.pumpAndSettle();
    for (final label in [
      'Local',
      'Private',
      'Group: Platform team',
      'Organisation: Northwind',
      'Department: Security',
      'Team: Identity',
    ]) {
      expect(find.text(label), findsWidgets);
    }
    expect(tester.takeException(), isNull);

    questions.returnNoResults = true;
    personal.results.clear();
    groups.results.clear();
    await tester.enterText(titleField, 'zz');
    await tester.pump(const Duration(milliseconds: 360));
    await tester.pumpAndSettle();
    expect(find.text('No matching Knowledge found.'), findsOneWidget);
  });
}
