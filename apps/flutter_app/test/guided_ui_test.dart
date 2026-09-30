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

void main() {
  testWidgets('active participant shows their shared answer and recursive branch', (tester) async {
    await tester.pumpWidget(flow());

    expect(find.text('I received an email.'), findsOneWidget);
    expect(find.text('I received a phone call.'), findsNothing);
    expect(find.text('Who sent the email?'), findsOneWidget);
    expect(find.text('Which Finance employee?'), findsOneWidget);
    expect(find.textContaining('Return to'), findsWidgets);
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
}