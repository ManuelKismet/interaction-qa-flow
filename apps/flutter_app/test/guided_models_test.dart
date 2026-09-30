import 'package:flutter_test/flutter_test.dart';
import 'package:int_qa_flow/features/guided/domain/guided_models.dart';

void main() {
  test('shared question resolves a separate answer for each participant', () {
    final question = GuidedQuestion.fromJson({
      'id': 'question-1',
      'text': 'What happened?',
      'scope': 'shared',
      'source': 'manual',
      'answers': [
        {
          'id': 'answer-a',
          'question_id': 'question-1',
          'participant_id': 'alice',
          'body': 'I received an email.',
          'branches_collapsed': false,
        },
        {
          'id': 'answer-b',
          'question_id': 'question-1',
          'participant_id': 'bob',
          'body': 'I received a phone call.',
          'branches_collapsed': false,
        },
      ],
      'follow_ups': [],
    });

    expect(question.answerFor('alice')?.body, 'I received an email.');
    expect(question.answerFor('bob')?.body, 'I received a phone call.');
  });

  test('nested answer-specific branches remain recursive', () {
    final question = GuidedQuestion.fromJson({
      'id': 'root',
      'text': 'What happened?',
      'scope': 'shared',
      'source': 'manual',
      'answers': const [],
      'follow_ups': [
        {
          'id': 'follow-1',
          'text': 'Who sent the email?',
          'scope': 'participant',
          'source': 'follow_up',
          'target_participant_id': 'alice',
          'answers': const [],
          'follow_ups': [
            {
              'id': 'follow-2',
              'text': 'Which Finance employee?',
              'scope': 'participant',
              'source': 'follow_up',
              'target_participant_id': 'alice',
              'answers': const [],
              'follow_ups': const [],
            },
          ],
        },
      ],
    });

    expect(question.followUps.single.followUps.single.text, 'Which Finance employee?');
  });
}