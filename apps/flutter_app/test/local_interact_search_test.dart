import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:int_qa_flow/features/knowledge/application/interact_search.dart';

void main() {
  test('matches collapsed recursive answers without changing the graph', () {
    final session = <String, dynamic>{
      'id': 'session',
      'title': 'Interview',
      'questions': [
        {
          'id': 'root',
          'text': 'Main prompt',
          'answers': [
            {
              'participant_id': 'alice',
              'body': 'Ordinary',
              'branches_collapsed': true,
              'follow_ups': [
                {
                  'id': 'branch',
                  'text': 'sentinel follow-up',
                  'answers': [
                    {
                      'participant_id': 'alice',
                      'body': 'ordinary',
                      'follow_ups': [
                        {
                          'id': 'deep',
                          'text': 'sentinel recursive detail',
                          'answers': [],
                        },
                      ],
                    },
                  ],
                },
              ],
            },
            {
              'participant_id': 'bob',
              'body': 'sentinel answer',
              'follow_ups': [],
            },
          ],
        },
        {
          'id': 'deleted',
          'text': 'sentinel deleted',
          'deleted_at': 'now',
          'follow_ups': [
            {'id': 'hidden', 'text': 'sentinel hidden', 'answers': []},
          ],
        },
      ],
    };
    final before = jsonEncode(session);
    final hits = searchLocalInteract('sentinel', [session]);
    expect(hits.map((h) => h['question_id']).toSet(), {
      'root',
      'branch',
      'deep',
    });
    expect(
      hits.singleWhere((h) => h['question_id'] == 'root')['participant_id'],
      'bob',
    );
    expect(
      hits
          .where((h) => h['question_id'] != 'root')
          .every((h) => h['participant_id'] == 'alice'),
      isTrue,
    );
    expect(
      hits.every((h) => h['source'] == 'Local' && h['session_id'] == 'session'),
      isTrue,
    );
    expect(jsonEncode(session), before);
    expect(
      searchLocalInteract('Interview', [session]).single['matched_in'],
      'session title',
    );
    expect(searchLocalInteract('missing', [session]), isEmpty);
  });
}
