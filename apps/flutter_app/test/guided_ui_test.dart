import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:int_qa_flow/features/guided/domain/guided_models.dart';
import 'package:int_qa_flow/features/guided/presentation/guided_session_page.dart';

const aliceAnswer = GuidedAnswer(
  id: 'answer-a',
  questionId: 'shared-1',
  participantId: 'alice',
  body: 'I received an email.',
  branchesCollapsed: false,
);

const bobAnswer = GuidedAnswer(
  id: 'answer-b',
  questionId: 'shared-1',
  participantId: 'bob',
  body: 'I received a phone call.',
  branchesCollapsed: false,
);

const nested = GuidedQuestion(
  id: 'nested',
  text: 'Which Finance employee?',
  scope: 'participant',
  source: 'follow_up',
  targetParticipantId: 'alice',
  answers: [],
  followUps: [],
);

const followUp = GuidedQuestion(
  id: 'follow',
  text: 'Who sent the email?',
  scope: 'participant',
  source: 'follow_up',
  targetParticipantId: 'alice',
  answers: [],
  followUps: [nested],
);

const shared = GuidedQuestion(
  id: 'shared-1',
  text: 'What happened?',
  scope: 'shared',
  source: 'manual',
  answers: [aliceAnswer, bobAnswer],
  followUps: [followUp],
);

Widget flow({
  GuidedQuestion question = shared,
  String participant = 'alice',
  Future<void> Function(GuidedQuestion, String)? onSaveQuestion,
}) {
  return MaterialApp(
    home: Scaffold(
      body: GuidedFlowView(
        questions: [question],
        participantId: participant,
        participantName: participant == 'alice' ? 'Alice' : 'Bob',
        onEditing: () {},
        onSaveQuestion: onSaveQuestion ?? (_, _) async {},
        onSaveAnswer: (_, _, _) async {},
        onAddFollowUp: (_) {},
        onToggleBranch: (_) {},
        onDelete: (_) {},
        onKnowledgeSearch: (_) {},
        onPropose: (_, _) {},
      ),
    ),
  );
}

GuidedQuestion deepQuestion(int followUpDepth, [int level = 0]) {
  final id = 'deep-$level';
  return GuidedQuestion(
    id: id,
    text: 'Question $level ${'long question text ' * 12}',
    scope: level == 0 ? 'shared' : 'participant',
    source: level == 0 ? 'manual' : 'follow_up',
    targetParticipantId: level == 0 ? null : 'alice',
    answers: [
      GuidedAnswer(
        id: 'answer-$level',
        questionId: id,
        participantId: 'alice',
        body: 'Answer $level ${'long answer text ' * 12}',
        branchesCollapsed: false,
      ),
    ],
    followUps: level < followUpDepth
        ? [deepQuestion(followUpDepth, level + 1)]
        : const [],
  );
}

void main() {
  testWidgets('active participant shows their shared answer and recursive branch', (tester) async {
    await tester.pumpWidget(flow());

    expect(find.text('I received an email.'), findsOneWidget);
    expect(find.text('I received a phone call.'), findsNothing);
    expect(find.text('Who sent the email?'), findsOneWidget);
    expect(find.text('Which Finance employee?'), findsOneWidget);
    expect(find.textContaining('Return to'), findsWidgets);
    expect(find.text('Collapse branch (2)'), findsOneWidget);
  });

  testWidgets('switching participant selects the other shared answer', (tester) async {
    await tester.pumpWidget(flow(participant: 'bob'));

    expect(find.text('I received a phone call.'), findsOneWidget);
    expect(find.text('I received an email.'), findsNothing);
  });

  testWidgets('collapsed answer hides nested follow-ups', (tester) async {
    const collapsed = GuidedQuestion(
      id: 'shared-1',
      text: 'What happened?',
      scope: 'shared',
      source: 'manual',
      answers: [
        GuidedAnswer(
          id: 'answer-a',
          questionId: 'shared-1',
          participantId: 'alice',
          body: 'Email',
          branchesCollapsed: true,
        ),
      ],
      followUps: [followUp],
    );
    await tester.pumpWidget(flow(question: collapsed));

    expect(find.text('Who sent the email?'), findsNothing);
    expect(find.text('Expand branch'), findsOneWidget);
  });

  testWidgets('inline answer edit is debounced before autosave', (tester) async {
    var saves = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: GuidedFlowView(
          questions: const [shared],
          participantId: 'alice',
          participantName: 'Alice',
          onEditing: () {},
          onSaveQuestion: (_, _) async {},
          onSaveAnswer: (_, _, _) async => saves++,
          onAddFollowUp: (_) {},
          onToggleBranch: (_) {},
          onDelete: (_) {},
          onKnowledgeSearch: (_) {},
          onPropose: (_, _) {},
        ),
      ),
    ));

    final answerField = find.widgetWithText(TextField, 'I received an email.');
    await tester.enterText(answerField, 'Updated answer');
    await tester.pump(const Duration(milliseconds: 400));
    expect(saves, 0);
    await tester.pump(const Duration(milliseconds: 300));
    expect(saves, 1);
  });

  testWidgets('deep question editors stay wide at mobile, tablet, and desktop widths', (
    tester,
  ) async {
    const widths = [360.0, 768.0, 1366.0];
    const depths = [0, 1, 3, 8, 12];
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1366, 936);
    try {
      for (final width in widths) {
        tester.view.physicalSize = Size(width, 936);
        for (final depth in depths) {
          final leafId = 'deep-$depth';
          await tester.pumpWidget(flow(question: deepQuestion(depth)));
          final leaf = find.byKey(ValueKey('question-card-$leafId'));
          await tester.scrollUntilVisible(
            leaf,
            320,
            scrollable: find.descendant(
              of: find.byKey(const ValueKey('guided-question-list')),
              matching: find.byType(Scrollable),
            ),
          );
          await tester.pumpAndSettle();

          final editor = find.byKey(
            ValueKey('question-$leafId-Question $depth ${'long question text ' * 12}'),
          );
          expect(tester.getSize(editor).width, greaterThan(width * 0.68));
          expect(
            find.textContaining(
              depth == 0
                  ? 'Question 1'
                  : 'Path 1.${List.filled(depth, '1').join('.')}',
            ),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
        }
      }

      tester.view.physicalSize = const Size(360, 936);
      await tester.pumpWidget(flow(question: deepQuestion(12)));
      final leaf = find.byKey(const ValueKey('question-card-deep-12'));
      await tester.scrollUntilVisible(
        leaf,
        320,
        scrollable: find.descendant(
          of: find.byKey(const ValueKey('guided-question-list')),
          matching: find.byType(Scrollable),
        ),
      );
      final actions = find.descendant(
        of: leaf,
        matching: find.byTooltip('Question actions'),
      );
      await tester.ensureVisible(actions);
      await tester.tap(actions);
      await tester.pumpAndSettle();
      expect(find.text('Delete question'), findsOneWidget);
    } finally {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    }
  });

  testWidgets('deep report retains nested answers for every participant', (tester) async {
    final question = deepQuestion(12);
    final detail = GuidedSessionDetail(
      id: 'session',
      title: 'Long follow-up report',
      status: 'completed',
      visibility: 'private',
      revision: 1,
      updatedAt: DateTime.utc(2026),
      participants: const [
        GuidedParticipant(id: 'alice', name: 'Alice'),
        GuidedParticipant(id: 'bob', name: 'Bob'),
      ],
      questions: [
        GuidedQuestion(
          id: question.id,
          text: question.text,
          scope: question.scope,
          source: question.source,
          answers: [
            ...question.answers,
            const GuidedAnswer(
              id: 'answer-bob',
              questionId: 'deep-0',
              participantId: 'bob',
              body: 'Bob saved a separate answer.',
              branchesCollapsed: false,
            ),
          ],
          followUps: question.followUps,
        ),
      ],
      preparedQuestionCount: 1,
      followUpCount: 12,
    );
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: GuidedReportView(session: detail, allParticipants: true))),
    );

    expect(find.textContaining('Alice: Answer 0'), findsOneWidget);
    expect(find.text('Bob: Bob saved a separate answer.'), findsOneWidget);
    expect(find.textContaining('Parent question:'), findsWidgets);
    await tester.scrollUntilVisible(
      find.textContaining('Question 12'),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.textContaining('Question 12'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('outline focuses branches on wide screens and narrow navigation returns to parent', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    try {
      tester.view.physicalSize = const Size(1366, 936);
      await tester.pumpWidget(flow(question: deepQuestion(3)));
      await tester.tap(find.textContaining('1.1 · Question 1'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('question-card-deep-1')), findsOneWidget);
      expect(find.byKey(const ValueKey('question-card-deep-0')), findsNothing);
      await tester.tap(find.text('Show all questions'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('question-card-deep-0')), findsOneWidget);

      await tester.tap(find.byTooltip('Collapse question outline'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Show question outline'), findsOneWidget);
      await tester.tap(find.byTooltip('Show question outline'));
      await tester.pumpAndSettle();

      tester.view.physicalSize = const Size(360, 936);
      await tester.pumpWidget(flow(question: deepQuestion(3)));
      await tester.tap(find.byKey(const ValueKey('branch-null')));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('1.1 · Question 1').last);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('question-card-deep-1')), findsOneWidget);
      await tester.tap(find.widgetWithText(
        TextButton,
        'Return to parent · Question 0 ${'long question text ' * 12}',
      ));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('question-card-deep-0')), findsOneWidget);
    } finally {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    }
  });

  testWidgets('leaving a focused branch flushes pending question autosave', (tester) async {
    tester.view.physicalSize = const Size(360, 936);
    tester.view.devicePixelRatio = 1;
    final saved = <String>[];
    try {
      await tester.pumpWidget(
        flow(
          question: deepQuestion(1),
          onSaveQuestion: (_, text) async => saved.add(text),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('branch-null')));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('1.1 · Question 1').last);
      await tester.pumpAndSettle();
      final editor = find.byKey(
        ValueKey('question-deep-1-Question 1 ${'long question text ' * 12}'),
      );
      await tester.enterText(editor, 'Edited before navigating away');
      await tester.tap(find.byKey(const ValueKey('branch-deep-1')));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('1 · Question 0').last);
      await tester.pumpAndSettle();

      expect(saved, contains('Edited before navigating away'));
      expect(find.byKey(const ValueKey('question-card-deep-0')), findsOneWidget);
    } finally {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    }
  });
}