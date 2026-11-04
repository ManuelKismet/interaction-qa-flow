import 'package:flutter_test/flutter_test.dart';
import 'package:int_qa_flow/features/guided/domain/guided_models.dart';
import 'package:int_qa_flow/features/guided/presentation/guided_report_document.dart';

const alice = GuidedParticipant(id: 'alice', name: 'Alice');
const bob = GuidedParticipant(id: 'bob', name: 'Bob');

GuidedSessionDetail reportSession({String title = 'Quarterly review'}) {
  const aliceAnswer = GuidedAnswer(
    id: 'answer-alice',
    questionId: 'root',
    participantId: 'alice',
    body: 'Alice answer',
    branchesCollapsed: true,
  );
  const bobAnswer = GuidedAnswer(
    id: 'answer-bob',
    questionId: 'root',
    participantId: 'bob',
    body: 'Bob answer',
    branchesCollapsed: false,
  );
  const aliceFollowUp = GuidedQuestion(
    id: 'follow-alice',
    text: 'Alice follow-up',
    scope: 'participant',
    source: 'follow_up',
    targetParticipantId: 'alice',
    triggeringAnswerId: 'answer-alice',
    answers: [
      GuidedAnswer(
        id: 'follow-answer-alice',
        questionId: 'follow-alice',
        participantId: 'alice',
        body: 'Alice follow-up answer',
        branchesCollapsed: false,
      ),
    ],
    followUps: [
      GuidedQuestion(
        id: 'nested-alice',
        text: 'Nested Alice detail',
        scope: 'participant',
        source: 'follow_up',
        targetParticipantId: 'alice',
        triggeringAnswerId: 'follow-answer-alice',
        answers: [
          GuidedAnswer(
            id: 'nested-answer-alice',
            questionId: 'nested-alice',
            participantId: 'alice',
            body: 'Nested answer',
            branchesCollapsed: false,
          ),
        ],
        followUps: [],
      ),
    ],
  );
  const bobFollowUp = GuidedQuestion(
    id: 'follow-bob',
    text: 'Bob follow-up',
    scope: 'participant',
    source: 'follow_up',
    targetParticipantId: 'bob',
    triggeringAnswerId: 'answer-bob',
    answers: [
      GuidedAnswer(
        id: 'follow-answer-bob',
        questionId: 'follow-bob',
        participantId: 'bob',
        body: 'Bob follow-up answer',
        branchesCollapsed: false,
      ),
    ],
    followUps: [],
  );

  return GuidedSessionDetail(
    id: 'session',
    title: title,
    status: 'completed',
    visibility: 'private',
    revision: 4,
    updatedAt: DateTime.utc(2026),
    ownerText: 'Review owner',
    contextReference: 'Case-42',
    participants: const [alice, bob],
    questions: [
      const GuidedQuestion(
        id: 'root',
        text: 'Root question',
        scope: 'shared',
        source: 'manual',
        answers: [aliceAnswer, bobAnswer],
        followUps: [aliceFollowUp, bobFollowUp],
      ),
      const GuidedQuestion(
        id: 'unanswered',
        text: 'Question not answered',
        scope: 'shared',
        source: 'manual',
        answers: [],
        followUps: [],
      ),
    ],
    preparedQuestionCount: 2,
    followUpCount: 4,
  );
}

String buildReport({
  required GuidedSessionDetail session,
  required bool allParticipants,
  String? participantId = 'alice',
}) => buildGuidedReportDocument(
  session: session,
  allParticipants: allParticipants,
  participantId: participantId,
  generatedAt: DateTime.utc(2026, 10, 2, 23, 0),
);

void main() {
  test('active report keeps answers and follow-up branches participant-specific', () {
    final html = buildReport(session: reportSession(), allParticipants: false);

    expect(html, contains('Active participant — Alice'));
    expect(html, contains('Answer — Alice'));
    expect(html, contains('Alice answer'));
    expect(html, contains('Alice follow-up'));
    expect(html, contains('Nested Alice detail'));
    expect(html, contains('Parent question: Root question'));
    expect(html, contains('Triggered by Alice: Alice answer'));
    expect(html, contains('Unanswered.'));
    expect(html, isNot(contains('Bob answer')));
    expect(html, isNot(contains('Bob follow-up')));
  });

  test('all-participants report retains attribution and complete nested branches', () {
    final html = buildReport(
      session: reportSession(),
      allParticipants: true,
      participantId: null,
    );

    expect(html, contains('Report scope:</strong> All participants'));
    expect(html, contains('Participants:</strong> Alice, Bob'));
    expect(html, contains('Answer — Alice'));
    expect(html, contains('Alice answer'));
    expect(html, contains('Alice follow-up answer'));
    expect(html, contains('Answer — Bob'));
    expect(html, contains('Bob answer'));
    expect(html, contains('Bob follow-up answer'));
    expect(html, contains('Triggered by Bob: Bob answer'));
    expect(html, contains('Nested Alice detail'));
    expect(html.indexOf('Alice answer'), lessThan(html.indexOf('Alice follow-up')));
    expect(html.indexOf('Bob answer'), lessThan(html.indexOf('Bob follow-up')));
  });

  test('report metadata and user content are escaped in a complete print document', () {
    final html = buildReport(
      session: reportSession(title: '<script>alert("title")</script>'),
      allParticipants: false,
    );

    expect(html, startsWith('<!doctype html>'));
    expect(html, contains('<title>&lt;script&gt;alert(&quot;title&quot;)&lt;/script&gt;'));
    expect(html, contains('Owner:</strong> Review owner'));
    expect(html, contains('Context / reference:</strong> Case-42'));
    expect(html, contains('Session status:</strong> completed'));
    expect(html, contains('Generated at (UTC):</strong> 2026-10-02T23:00:00.000Z'));
    expect(html, isNot(contains('<script>')));
    expect(html, contains('Print / Save PDF'));
    expect(html, contains('@page'));
    expect(html, contains('break-after: avoid-page'));
  });

  test('active report with no selected participant does not expose participant answers', () {
    final html = buildReport(
      session: reportSession(),
      allParticipants: false,
      participantId: null,
    );

    expect(html, contains('Active participant — Not selected'));
    expect(html, contains('Unanswered.'));
    expect(html, isNot(contains('Alice answer')));
    expect(html, isNot(contains('Bob answer')));
  });
}
