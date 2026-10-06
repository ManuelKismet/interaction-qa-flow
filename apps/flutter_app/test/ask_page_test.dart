import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:int_qa_flow/features/ask/application/ask_controller.dart';
import 'package:int_qa_flow/features/ask/application/ask_suggestions_controller.dart';
import 'package:int_qa_flow/features/ask/presentation/ask_page.dart';
import 'package:int_qa_flow/features/guest/data/guest_group_repository.dart';
import 'package:int_qa_flow/features/guest/data/guest_storage.dart';
import 'package:int_qa_flow/features/guest/data/guest_workspace_store.dart';
import 'package:int_qa_flow/features/guest/data/personal_workspace_repository.dart';
import 'package:int_qa_flow/features/guest/domain/guest_workspace_data.dart';
import 'package:int_qa_flow/features/questions/data/questions_repository.dart';
import 'package:int_qa_flow/features/questions/domain/question_models.dart';

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

  @override
  Future<List<SemanticSearchResult>> searchQuestions(
    String query, {
    int limit = 5,
  }) async => [
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

class _PersonalRepository extends PersonalWorkspaceRepository {
  _PersonalRepository() : super(Dio());

  @override
  Future<Map<String, dynamic>> searchKnowledge(
    String query, {
    required String expectedUid,
  }) async => {
    'partial': false,
    'results': [
      {
        'source_id': 'private-id',
        'title': 'Private account policy',
        'data': {'answer': 'Keep account passwords unique.'},
        'snippet': 'Keep account passwords unique.',
        'relevance_score': 1.5,
        'match_method': 'keyword',
      },
    ],
  };
}

class _GroupRepository extends GuestGroupRepository {
  _GroupRepository() : super(Dio());

  @override
  Future<Map<String, dynamic>> searchKnowledge(String query) async => {
    'partial': false,
    'results': [
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
    ],
  };
}

void main() {
  testWidgets('Ask suggestions show unified source badges and open source', (
    tester,
  ) async {
    final storage = _MemoryGuestStorage();
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
        GoRoute(path: '/', builder: (_, _) => const AskPage()),
        GoRoute(
          path: '/personal',
          builder: (_, state) => Scaffold(
            body: Text(
              'Opened personal: '
              '${(state.extra as Map?)?['knowledgeItemId']}',
            ),
          ),
        ),
        GoRoute(
          path: '/questions/:id',
          builder: (_, state) => Text('Opened organisation: ${state.pathParameters['id']}'),
        ),
        GoRoute(
          path: '/guest/groups',
          builder: (_, state) => Text(
            'Opened group: ${(state.extra as Map)['entryId']}',
          ),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          questionsRepositoryProvider.overrideWithValue(_QuestionsRepository()),
          departmentsProvider.overrideWith((ref) async => const []),
          teamsProvider.overrideWith((ref) async => const []),
          personalWorkspaceRepositoryProvider.overrideWithValue(
            _PersonalRepository(),
          ),
          guestGroupRepositoryProvider.overrideWithValue(_GroupRepository()),
          guestWorkspaceStoreProvider.overrideWithValue(
            GuestWorkspaceStore(storage),
          ),
          askSearchIdentityProvider.overrideWithValue(
            const AskSearchIdentity(verifiedUid: 'verified-uid'),
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
    expect(find.text('Opened personal: private-id'), findsOneWidget);
  });
}
