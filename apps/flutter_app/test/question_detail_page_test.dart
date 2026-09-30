import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:int_qa_flow/core/config/app_config.dart';
import 'package:int_qa_flow/features/ask/application/ask_controller.dart';
import 'package:int_qa_flow/features/questions/application/question_providers.dart';
import 'package:int_qa_flow/features/questions/domain/question_models.dart';
import 'package:int_qa_flow/features/questions/presentation/question_detail_page.dart';

void main() {
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
      status: 'open',
      author: UserSummary(
        id: AppConfig.developmentUserId,
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
  });
}
