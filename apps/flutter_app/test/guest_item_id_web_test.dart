import 'package:flutter_test/flutter_test.dart';
import 'package:int_qa_flow/features/guest/domain/guest_interact_helpers.dart';
import 'package:int_qa_flow/features/guest/domain/guest_workspace_data.dart';

void main() {
  test('production guest IDs work across recursive template creation', () {
    final knowledgeId = newGuestItemId();
    final source = <String, dynamic>{
      'participants': [
        {'id': 'source-a', 'name': 'Alice'},
        {'id': 'source-b', 'name': 'Bob'},
      ],
      'questions': [
        {
          'id': 'source-root',
          'scope': 'shared',
          'text': 'What happened?',
          'answers': [
            {
              'participant_id': 'source-a',
              'body': 'Answer A',
              'follow_ups': [
                {
                  'id': 'source-follow-up',
                  'scope': 'participant',
                  'target_participant_id': 'source-a',
                  'text': 'Which component?',
                  'answers': [
                    {
                      'participant_id': 'source-a',
                      'body': 'Component A',
                      'follow_ups': [],
                    },
                  ],
                },
              ],
            },
            {
              'participant_id': 'source-b',
              'body': 'Answer B',
              'follow_ups': [],
            },
          ],
        },
      ],
    };
    final template = createGuestTemplateFromSession(
      session: source,
      id: newGuestItemId(),
      name: 'Reusable interview',
    );
    final session = createGuestSessionFromTemplate(
      template: template,
      id: newGuestItemId(),
      title: 'New interview',
      firstParticipantName: 'Charlie',
    );
    final participants = (session['participants'] as List).cast<Map>();

    final generatedIds = [
      knowledgeId,
      template['id'] as String,
      session['id'] as String,
      ..._questionIds(template['questions'] as List),
      ...participants.map((participant) => participant['id'] as String),
      ..._questionIds(session['questions'] as List),
    ];

    expect(generatedIds.every((id) => id.startsWith('guest-v2-')), isTrue);
    expect(generatedIds.toSet(), hasLength(generatedIds.length));
    expect(
      participants.map((participant) => participant['id']).toSet(),
      hasLength(2),
    );
    expect(
      (((session['questions'] as List).single as Map)['answers'] as List)
          .map((answer) => (answer as Map)['body']),
      ['', ''],
    );
  });
}

List<String> _questionIds(List questions) => [
  for (final item in questions)
    if (item is Map) ...[
      item['id'] as String,
      for (final answer in item['answers'] as List? ?? const [])
        if (answer is Map)
          ..._questionIds(answer['follow_ups'] as List? ?? const []),
    ],
];
