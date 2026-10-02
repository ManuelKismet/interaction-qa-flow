import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:int_qa_flow/features/guided/domain/guided_models.dart';
import 'package:int_qa_flow/features/guided/presentation/guided_page.dart';

void main() {
  testWidgets('edited template draft preserves question relationships and adds questions', (
    tester,
  ) async {
    const questions = [
      GuidedTemplateQuestion(
        id: 'question-parent',
        text: 'Original prepared question',
        scope: 'shared',
        orderIndex: 0,
      ),
      GuidedTemplateQuestion(
        id: 'question-child',
        text: 'Original participant follow-up',
        scope: 'participant',
        orderIndex: 1,
        participantReference: 'Alice',
        parentTemplateQuestionId: 'question-parent',
      ),
    ];
    List<GuidedTemplateQuestion>? savedQuestions;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                savedQuestions = await showDialog<List<GuidedTemplateQuestion>>(
                  context: context,
                  builder: (_) =>
                      const GuidedTemplateVersionDraftDialog(questions: questions),
                );
              },
              child: const Text('Edit template'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Edit template'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('template-question-question-parent')),
      'Revised prepared question',
    );
    await tester.enterText(
      find.byKey(const ValueKey('template-question-question-child')),
      'Revised participant follow-up',
    );
    await tester.tap(find.text('Add question'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'New prepared question');
    await tester.tap(find.text('Save new version'));
    await tester.pumpAndSettle();

    expect(savedQuestions, hasLength(3));
    expect(savedQuestions![0].text, 'Revised prepared question');
    expect(savedQuestions![0].id, 'question-parent');
    expect(savedQuestions![1].text, 'Revised participant follow-up');
    expect(savedQuestions![1].scope, 'participant');
    expect(savedQuestions![1].participantReference, 'Alice');
    expect(savedQuestions![1].parentTemplateQuestionId, 'question-parent');
    expect(savedQuestions![2].text, 'New prepared question');
    expect(savedQuestions![2].scope, 'shared');
    expect(savedQuestions![2].orderIndex, 2);
  });
}
