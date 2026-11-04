import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:int_qa_flow/core/api/api_exception.dart';
import 'package:int_qa_flow/features/questions/data/questions_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:int_qa_flow/core/auth/auth_providers.dart';
import 'package:int_qa_flow/features/ask/application/ask_controller.dart';
import 'package:int_qa_flow/features/governance/application/governance_providers.dart';
import 'package:int_qa_flow/features/questions/application/question_providers.dart';
import 'package:int_qa_flow/features/questions/domain/question_models.dart';
import 'package:int_qa_flow/features/questions/presentation/question_detail_page.dart';

QuestionDetail _questionWithVerifiedAnswer(DepartmentSummary? department) =>
    QuestionDetail(
      id: 'question-1',
      title: 'How do I fix a mileage claim?',
      body: null,
      status: 'resolved',
      author: const UserSummary(
        id: 'author-1',
        displayName: 'Question Author',
        role: 'employee',
      ),
      department: department,
      team: null,
      answers: [
        AnswerDetail(
          id: 'answer-1',
          body: 'Submit an expense correction.',
          status: 'verified',
          author: const UserSummary(
            id: 'answer-author',
            displayName: 'Answer Author',
            role: 'answer_owner',
          ),
          helpfulCount: 0,
          notHelpfulCount: 0,
          isAccepted: false,
          createdAt: DateTime.utc(2026),
          challengeCount: 0,
          hasOpenChallenge: false,
        ),
      ],
      acceptedAnswer: null,
      commentCount: 0,
      aliases: const [],
    );

void main() {
  testWidgets(
    'restricted Knowledge link gives safe denial without automatic retries',
    (tester) async {
      final repository = _DeniedQuestionsRepository();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            questionsRepositoryProvider.overrideWithValue(repository),
          ],
          child: const MaterialApp(
            home: Scaffold(body: QuestionDetailPage(questionId: 'restricted')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Unable to load this question.'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byTooltip('Back to Questions'), findsOneWidget);
      await tester.pump(const Duration(seconds: 10));
      expect(repository.reads, 1);
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(repository.reads, 2);
    },
  );
  testWidgets('question author can open prefilled correction dialog', (
    tester,
  ) async {
    const department = DepartmentSummary(id: 'department-1', name: 'Finance');
    const team = TeamSummary(
      id: 'team-1',
      name: 'Expenses',
      departmentId: 'department-1',
      department: department,
      status: 'active',
    );
    const question = QuestionDetail(
      id: 'question-1',
      title: 'How do I fix a mileage claim?',
      body: 'The amount is incorrect.',
      visibility: 'team',
      status: 'open',
      author: UserSummary(
        id: 'user-1',
        displayName: 'Question Author',
        role: 'employee',
      ),
      department: department,
      team: team,
      answers: [],
      acceptedAnswer: null,
      commentCount: 0,
      aliases: [],
      canonicalQuestion: CanonicalQuestionSummary(
        id: 'canonical-1',
        title: 'Mileage claims',
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          questionDetailProvider(
            'question-1',
          ).overrideWith((ref) async => question),
          currentMembershipProvider.overrideWith(
            (ref) async => const ActiveMembership(
              userId: 'user-1',
              organisationId: 'organisation-1',
              email: 'author@example.invalid',
              displayName: 'Question Author',
              role: 'employee',
            ),
          ),
          departmentsProvider.overrideWith((ref) async => [department]),
          teamsProvider.overrideWith((ref) async => [team]),
        ],
        child: const MaterialApp(
          home: Scaffold(body: QuestionDetailPage(questionId: 'question-1')),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byTooltip('Edit question'), findsOneWidget);
    expect(find.byTooltip('Archive question'), findsOneWidget);

    await tester.tap(find.byTooltip('Edit question'));
    await tester.pumpAndSettle();

    expect(find.text('Edit question'), findsOneWidget);
    expect(
      find.widgetWithText(TextField, 'How do I fix a mileage claim?'),
      findsOneWidget,
    );
    expect(
      find.widgetWithText(TextField, 'The amount is incorrect.'),
      findsOneWidget,
    );
    expect(find.text('Finance'), findsOneWidget);
    expect(find.text('Finance · Expenses'), findsOneWidget);
    expect(find.text('Selected team only'), findsOneWidget);
  });

  for (final testCase in [
    (
      name: 'assigned department answer owner',
      departmentId: 'department-1',
      assigned: true,
      expected: true,
    ),
    (
      name: 'out-of-scope department answer owner',
      departmentId: 'department-2',
      assigned: true,
      expected: false,
    ),
    (
      name: 'department-free answer owner',
      departmentId: null,
      assigned: true,
      expected: false,
    ),
    (
      name: 'answer owner after assignment is revoked',
      departmentId: 'department-1',
      assigned: false,
      expected: false,
    ),
  ]) {
    testWidgets(
      '${testCase.name} ${testCase.expected ? 'can' : 'cannot'} review a verified answer',
      (tester) async {
        const department = DepartmentSummary(
          id: 'department-1',
          name: 'Finance',
        );
        final ownerDepartmentIds = testCase.assigned
            ? {'department-1'}
            : <String>{};
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              questionDetailProvider('question-1').overrideWith(
                (ref) async =>
                    _questionWithVerifiedAnswer(switch (testCase.departmentId) {
                      'department-1' => department,
                      'department-2' => const DepartmentSummary(
                        id: 'department-2',
                        name: 'Operations',
                      ),
                      _ => null,
                    }),
              ),
              currentMembershipProvider.overrideWith(
                (ref) async => const ActiveMembership(
                  userId: 'answer-owner-1',
                  organisationId: 'organisation-1',
                  email: 'owner@example.invalid',
                  displayName: 'Answer Owner',
                  role: 'answer_owner',
                ),
              ),
              myDepartmentOwnerIdsProvider.overrideWith(
                (ref) async => ownerDepartmentIds,
              ),
              duplicateCandidatesProvider(
                'question-1',
              ).overrideWith((ref) async => const []),
            ],
            child: const MaterialApp(
              home: Scaffold(
                body: QuestionDetailPage(questionId: 'question-1'),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.text('Review as current'),
          testCase.expected ? findsOneWidget : findsNothing,
        );
      },
    );
  }
}

class _DeniedQuestionsRepository extends QuestionsRepository {
  _DeniedQuestionsRepository() : super(Dio());
  var reads = 0;
  @override
  Future<QuestionDetail> getQuestion(String id) async {
    reads++;
    throw const ApiException('Unavailable', statusCode: 403);
  }
}
