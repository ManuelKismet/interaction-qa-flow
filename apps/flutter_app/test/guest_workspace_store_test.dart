import 'package:flutter_test/flutter_test.dart';
import 'package:int_qa_flow/features/guest/data/guest_storage.dart';
import 'package:int_qa_flow/features/guest/data/guest_workspace_store.dart';
import 'package:int_qa_flow/features/guest/domain/guest_workspace_data.dart';

void main() {
  test('guest item IDs stay unique across rapid same-clock generation', () {
    final ids = List.generate(256, (_) => newGuestItemId());

    expect(ids.toSet(), hasLength(ids.length));
    expect(ids.every((id) => id.startsWith('guest-v2-')), isTrue);
  });

  test(
    'malformed nested local and backup data are rejected unchanged',
    () async {
      final malformed = jsonEncode({
        'schema_version': 1,
        'knowledge': [],
        'sessions': [
          {
            'id': 'session',
            'participants': 'not a list',
            'questions': [],
          },
        ],
        'templates': [],
      });
      final storage = MemoryGuestStorage()..write(malformed);
      final store = GuestWorkspaceStore(storage);

      await expectLater(store.load(), throwsFormatException);
      expect(storage.read(), malformed);
      expect(
        () => GuestWorkspaceData.decodeBackup(malformed),
        throwsFormatException,
      );

      for (final invalid in [
        {
          'schema_version': 1,
          'knowledge': [],
          'sessions': [
            {'id': 'missing-participants'},
          ],
          'templates': [],
        },
        {
          'schema_version': 1,
          'knowledge': [],
          'sessions': [
            {
              'id': 'missing-questions',
              'participants': [
                {'id': 'p1'},
              ],
            },
          ],
          'templates': [],
        },
        {
          'schema_version': 1,
          'knowledge': [],
          'sessions': [
            {
              'id': 'session',
              'participants': [
                {'id': 'participant', 'name': 'Alice'},
              ],
              'questions': [
                {
                  'answers': [
                    {
                      'follow_ups': [
                        {'answers': 'not a list'},
                      ],
                    },
                    {
                      'schema_version': 1,
                      'knowledge': [],
                      'sessions': [
                        {
                          'id': 'session',
                          'participants': [
                            {'name': 'Missing ID'},
                          ],
                          'questions': [],
                        },
                      ],
                      'templates': [],
                    },
                    {
                      'schema_version': 1,
                      'knowledge': [],
                      'sessions': [
                        {
                          'id': 'session',
                          'participants': [
                            {'id': 'p1'},
                          ],
                          'questions': [
                            {
                              'id': 'question',
                              'text': 'Question',
                              'answers': [
                                {
                                  'participant_id': 'p1',
                                  'branches_collapsed': 'yes',
                                },
                              ],
                            },
                          ],
                        },
                      ],
                      'templates': [],
                    },
                  ],
                },
              ],
            },
          ],
          'templates': [],
        },
        {
          'schema_version': 1,
          'knowledge': [],
          'sessions': [],
          'templates': [
            {
              'id': 'template',
              'participant_slots': [
                {'id': 7},
              ],
            },
          ],
        },
      ]) {
        expect(
          () => GuestWorkspaceData.decodeBackup(jsonEncode(invalid)),
          throwsFormatException,
        );
      }
    },
  );

  test('local guest workspace persists Knowledge, templates and answer branches', () async {
    final storage = MemoryGuestStorage();
    final store = GuestWorkspaceStore(storage);
    final guestData = GuestWorkspaceData(
      knowledge: [
        {'id': 'k1', 'title': 'Password rotation', 'body': 'Rotate quarterly.'},
      ],
      templates: [
        {
          'id': 't1',
          'name': 'Incident interview',
          'questions': [
            {'id': 'tq1', 'text': 'What happened?'},
          ],
        },
      ],
      sessions: [
        {
          'id': 's1',
          'title': 'Incident review',
          'participants': [
            {'id': 'p1', 'name': 'Alice'},
            {'id': 'p2', 'name': 'Bob'},
          ],
          'questions': [
            {
              'id': 'q1',
              'text': 'What changed?',
              'answers': [
                {
                  'participant_id': 'p1',
                  'body': 'The service restarted.',
                  'follow_ups': [
                    {
                      'id': 'q2',
                      'text': 'Which service?',
                      'answers': [
                        {
                          'participant_id': 'p1',
                          'body': 'The API.',
                          'follow_ups': [],
                        },
                      ],
                    },
                  ],
                },
                {
                  'participant_id': 'p2',
                  'body': 'A node was replaced.',
                  'follow_ups': [],
                },
              ],
            },
          ],
        },
      ],
    );

    await store.save(guestData);
    final restored = await GuestWorkspaceStore(storage).load();

    expect(restored.knowledge.single['title'], 'Password rotation');
    expect(restored.templates.single['name'], 'Incident interview');
    final questions = restored.sessions.single['questions'] as List;
    final root = questions.single as Map<String, dynamic>;
    final answers = root['answers'] as List;
    expect((answers[0] as Map<String, dynamic>)['participant_id'], 'p1');
    expect((answers[1] as Map<String, dynamic>)['participant_id'], 'p2');
    final followUps = (answers[0] as Map<String, dynamic>)['follow_ups'] as List;
    expect((followUps.single as Map<String, dynamic>)['text'], 'Which service?');
  });

  test('loading a session with colliding participant IDs does not rewrite it', () async {
    final storage = MemoryGuestStorage();
    final store = GuestWorkspaceStore(storage);
    final session = <String, dynamic>{
      'id': 'legacy-collision',
      'participants': [
        {'id': 'duplicate-id', 'name': 'Alice'},
        {'id': 'duplicate-id', 'name': 'Bob'},
      ],
      'questions': [
        {
          'id': 'shared-question',
          'scope': 'shared',
          'answers': [
            {
              'participant_id': 'duplicate-id',
              'body': 'Existing answer',
              'follow_ups': [],
            },
          ],
        },
      ],
    };
    final original = GuestWorkspaceData(sessions: [session]);
    await store.save(original);
    final savedValue = storage.read();

    final restored = await store.load();

    expect(restored.sessions.single, session);
    expect(storage.read(), savedValue);
  });

  test('guest Knowledge search is keyword and prefix only', () {
    const entry = {'title': 'Password rotation', 'body': 'Change service keys.'};

    expect(matchesGuestKeywordOrPrefix('passw', entry), isTrue);
    expect(matchesGuestKeywordOrPrefix('rotation keys', entry), isTrue);
    expect(matchesGuestKeywordOrPrefix('recover account access', entry), isFalse);
  });

  test('selected backup import is idempotent and preserves existing guest work', () async {
    final storage = MemoryGuestStorage();
    final store = GuestWorkspaceStore(storage);
    await store.save(
      const GuestWorkspaceData(
        knowledge: [
          {'id': 'local-1', 'title': 'Keep me'},
        ],
      ),
    );
    final backup = GuestWorkspaceData.decodeBackup(
      const GuestWorkspaceData(
        knowledge: [
          {'id': 'selected-1', 'title': 'Selected'},
          {'id': 'not-selected', 'title': 'Not selected'},
        ],
        sessions: [
          {
            'id': 'branch-session',
            'questions': [
              {
                'id': 'q',
                'answers': [
                  {
                    'participant_id': 'p',
                    'follow_ups': [
                      {'id': 'nested'},
                    ],
                  },
                ],
              },
            ],
          },
        ],
      ).encodeBackup(),
    );

    await store.importSelected(
      imported: backup,
      knowledgeIds: {'selected-1'},
      sessionIds: {'branch-session'},
      templateIds: {},
    );
    final retried = await store.importSelected(
      imported: backup,
      knowledgeIds: {'selected-1'},
      sessionIds: {'branch-session'},
      templateIds: {},
    );

    expect(retried.knowledge.map((item) => item['id']).toSet(), {
      'local-1',
      'selected-1',
    });
    expect(retried.sessions.single['id'], 'branch-session');
    final root = (retried.sessions.single['questions'] as List).single;
    final branch = ((root as Map)['answers'] as List).single;
    expect((((branch as Map)['follow_ups'] as List).single as Map)['id'], 'nested');
  });
}

class MemoryGuestStorage implements GuestStorage {
  String? value;

  @override
  void remove() => value = null;

  @override
  String? read() => value;

  @override
  void write(String value) => this.value = value;
}
