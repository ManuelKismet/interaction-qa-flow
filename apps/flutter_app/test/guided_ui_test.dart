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

Widget flow({GuidedQuestion question = shared, String participant = 'alice'}) {
  return MaterialApp(
    home: Scaffold(
      body: GuidedFlowView(
        questions: [question],
        participantId: participant,
        participantName: participant == 'alice' ? 'Alice' : 'Bob',
        onEditing: () {},
        onSaveQuestion: (_, _) async {},
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

Future<void> scrollToListItem(
  WidgetTester tester,
  Finder item, {
  required String listKey,
}) async {
  final scrollable = find
      .descendant(
        of: find.byKey(ValueKey(listKey)),
        matching: find.byType(Scrollable),
      )
      .first;
  await tester.scrollUntilVisible(
    item,
    400,
    scrollable: scrollable,
    maxScrolls: 100,
  );
}

GuidedQuestion nestedQuestions(int depth) {
  GuidedQuestion? child;
  for (var index = depth; index >= 0; index--) {
    final longText =
        'Question $index · ${List.filled(18, 'detailed follow-up context').join(' ')}';
    child = GuidedQuestion(
      id: 'deep-$index',
      text: longText,
      scope: index == 0 ? 'shared' : 'participant',
      source: index == 0 ? 'manual' : 'follow_up',
      targetParticipantId: index == 0 ? null : 'alice',
      answers: [
        GuidedAnswer(
          id: 'alice-$index',
          questionId: 'deep-$index',
          participantId: 'alice',
          body:
              'Alice answer $index · ${List.filled(12, 'long answer detail').join(' ')}',
          branchesCollapsed: false,
        ),
        GuidedAnswer(
          id: 'bob-$index',
          questionId: 'deep-$index',
          participantId: 'bob',
          body: 'Bob answer $index',
          branchesCollapsed: false,
        ),
      ],
      followUps: child == null ? const [] : [child],
    );
  }
  return child!;
}

void main() {
  testWidgets('active participant shows their shared answer and recursive branch', (tester) async {
    await tester.pumpWidget(flow());

    expect(find.text('I received an email.'), findsOneWidget);
    expect(find.text('I received a phone call.'), findsNothing);
    await scrollToListItem(
      tester,
      find.byKey(const ValueKey('question-follow')),
      listKey: 'guided-flow-list',
    );
    expect(find.text('Who sent the email?'), findsOneWidget);
    expect(find.textContaining('Return to parent'), findsOneWidget);
    await scrollToListItem(
      tester,
      find.byKey(const ValueKey('question-nested')),
      listKey: 'guided-flow-list',
    );
    expect(find.text('Which Finance employee?'), findsOneWidget);
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

  for (final width in [360.0, 768.0, 1366.0]) {
    for (final depth in [0, 1, 3, 8, 12]) {
      testWidgets(
        'keeps depth $depth editor wide at $width logical pixels',
        (tester) async {
          tester.view.physicalSize = Size(width, 936);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final root = nestedQuestions(depth);
          await tester.pumpWidget(flow(question: root));

          final deepQuestion = find.byKey(
            ValueKey('question-deep-$depth'),
          );
          await scrollToListItem(
            tester,
            deepQuestion,
            listKey: 'guided-flow-list',
          );
          await tester.pumpAndSettle();

          expect(deepQuestion, findsOneWidget);
          expect(tester.getSize(deepQuestion).width, greaterThan(180));
          expect(
            find.textContaining(
              'Path ${List.filled(depth + 1, '1').join('.')}',
            ),
            findsOneWidget,
          );
          if (depth > 0) {
            expect(
              find.text('Parent: ${rootTextAtDepth(depth - 1)}'),
              findsOneWidget,
            );
          }
          expect(find.text('Add follow-up'), findsWidgets);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets('report includes collapsed and deeply nested follow-ups', (
    tester,
  ) async {
    final root = nestedQuestions(12);
    final collapsedRoot = GuidedQuestion(
      id: root.id,
      text: root.text,
      scope: root.scope,
      source: root.source,
      answers: [
        for (final answer in root.answers)
          GuidedAnswer(
            id: answer.id,
            questionId: answer.questionId,
            participantId: answer.participantId,
            body: answer.body,
            branchesCollapsed: true,
          ),
      ],
      followUps: root.followUps,
    );
    final session = GuidedSessionDetail(
      id: 'session',
      title: 'Session report',
      status: 'completed',
      visibility: 'private',
      revision: 1,
      updatedAt: DateTime.utc(2026),
      participants: const [GuidedParticipant(id: 'alice', name: 'Alice')],
      questions: [collapsedRoot],
      preparedQuestionCount: 1,
      followUpCount: 12,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GuidedReportView(session: session, allParticipants: true),
        ),
      ),
    );

    await scrollToListItem(
      tester,
      find.text(rootTextAtDepth(12)),
      listKey: 'guided-report-list',
    );
    expect(find.text(rootTextAtDepth(12)), findsOneWidget);
    expect(find.textContaining('Alice answer 12'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

String rootTextAtDepth(int depth) =>
    'Question $depth · ${List.filled(18, 'detailed follow-up context').join(' ')}';