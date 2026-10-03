import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:int_qa_flow/features/guest/data/guest_storage_interface.dart';
import 'package:int_qa_flow/features/guest/data/guest_workspace_store.dart';
import 'package:int_qa_flow/features/guest/domain/guest_interact_helpers.dart';
import 'package:int_qa_flow/features/guest/domain/guest_workspace_data.dart';
import 'package:int_qa_flow/features/guest/presentation/guest_report_document.dart';

void main() {
  test('local templates preserve scope and nested structure without answers', () async {
    final session = _sessionFixture();
    final original = jsonEncode(session);

    final template = createGuestTemplateFromSession(
      session: session,
      id: 'template-new',
      name: 'Reusable interview',
    );
    final encodedTemplate = jsonEncode(template);

    expect(encodedTemplate, isNot(contains('private Alice answer')));
    expect(encodedTemplate, isNot(contains('private Bob answer')));
    expect(encodedTemplate, isNot(contains('private Alice branch answer')));
    expect(encodedTemplate, isNot(contains('private deep answer')));
    expect(encodedTemplate, isNot(contains('source-shared')));
    expect(encodedTemplate, contains('slot-1'));
    expect(encodedTemplate, contains('slot-2'));
    expect(
      (template['participant_slots'] as List)
          .map((slot) => (slot as Map)['label']),
      ['Participant 1', 'Participant 2'],
    );
    final questions = template['questions'] as List;
    final shared = questions[0] as Map<String, dynamic>;
    expect(shared['scope'], 'shared');
    final sharedAnswers = shared['answers'] as List;
    final aliceFollowUp =
        (sharedAnswers[0] as Map<String, dynamic>)['follow_ups'] as List;
    final firstBranch = aliceFollowUp.single as Map<String, dynamic>;
    expect(firstBranch['scope'], 'participant');
    expect(firstBranch['target_participant_slot'], 'slot-1');
    final secondLevel =
        ((firstBranch['answers'] as List).single as Map<String, dynamic>)['follow_ups']
            as List;
    expect((secondLevel.single as Map<String, dynamic>)['text'], 'Which component?');
    final bobQuestion = questions[1] as Map<String, dynamic>;
    expect(bobQuestion['scope'], 'participant');
    expect(bobQuestion['target_participant_slot'], 'slot-2');
    expect(jsonEncode(session), original);

    final restored = createGuestSessionFromTemplate(
      template: template,
      id: 'new-session',
      title: 'New interview',
      firstParticipantName: 'Charlie',
    );
    final participants = restored['participants'] as List;
    expect((participants[0] as Map)['name'], 'Charlie');
    expect((participants[1] as Map)['name'], 'Participant 2');
    final newAliceId = (participants[0] as Map)['id'] as String;
    final newBobId = (participants[1] as Map)['id'] as String;
    expect(newAliceId, isNot('alice-id'));
    expect(newBobId, isNot('bob-id'));

    final newQuestions = restored['questions'] as List;
    final newShared = newQuestions[0] as Map<String, dynamic>;
    expect(newShared['scope'], 'shared');
    final newAnswers = newShared['answers'] as List;
    expect(newAnswers.map((answer) => (answer as Map)['participant_id']), [
      newAliceId,
      newBobId,
    ]);
    expect(newAnswers.every((answer) => (answer as Map)['body'] == ''), isTrue);
    final newBranch =
        ((newAnswers[0] as Map<String, dynamic>)['follow_ups'] as List).single
            as Map<String, dynamic>;
    expect(newBranch['target_participant_id'], newAliceId);
    final deepBranch =
        ((newBranch['answers'] as List).single as Map<String, dynamic>)['follow_ups']
            as List;
    expect((deepBranch.single as Map<String, dynamic>)['text'], 'Which component?');
    final newBobQuestion = newQuestions[1] as Map<String, dynamic>;
    expect(newBobQuestion['target_participant_id'], newBobId);
    expect(
      _allQuestionIds(newQuestions).toSet().length,
      _allQuestionIds(newQuestions).length,
    );
    expect(
      _allQuestionIds(newQuestions).toSet().intersection({
        'source-shared',
        'source-alice-follow-up',
        'source-deep-follow-up',
        'source-bob-only',
        'bob-branch',
      }),
      isEmpty,
    );

    final backup = GuestWorkspaceData(
      sessions: [restored],
      templates: [template],
    ).encodeBackup();
    final roundTrip = GuestWorkspaceData.decodeBackup(backup);
    final roundTripSession = roundTrip.sessions.single;
    final roundTripRoot =
        (roundTripSession['questions'] as List).first as Map<String, dynamic>;
    final roundTripBranch =
        ((roundTripRoot['answers'] as List).first as Map<String, dynamic>)[
                'follow_ups']
            as List;
    expect(
      (((roundTripBranch.single as Map<String, dynamic>)['answers'] as List)
          .single as Map<String, dynamic>)['follow_ups'],
      isNotEmpty,
    );
    expect(roundTrip.templates.single['participant_slots'], isNotEmpty);

    final storage = _MemoryGuestStorage();
    final store = GuestWorkspaceStore(storage);
    await store.save(GuestWorkspaceData(sessions: [restored], templates: [template]));
    final reloaded = await store.load();
    expect(reloaded.sessions.single['id'], 'new-session');
    expect(reloaded.templates.single['participant_slots'], isNotEmpty);
    expect(
      _allQuestionIds(reloaded.sessions.single['questions'] as List),
      _allQuestionIds(restored['questions'] as List),
    );
  });

  test('legacy root-only templates still create a shared blank question', () {
    final session = createGuestSessionFromTemplate(
      template: {
        'id': 'old-template',
        'name': 'Older backup template',
        'questions': [
          {'id': 'old-question', 'text': 'What happened?'},
        ],
      },
      id: 'created',
      title: 'Legacy session',
      firstParticipantName: 'Alex',
    );
    final question = (session['questions'] as List).single as Map<String, dynamic>;

    expect((session['participants'] as List).length, 1);
    expect(question['scope'], 'shared');
    expect(question['id'], isNot('old-question'));
    expect((question['answers'] as List).single['body'], '');
    expect((question['answers'] as List).single['follow_ups'], isEmpty);
  });

  test('guest reports keep answer ownership, scope and unanswered prompts', () {
    final session = _sessionFixture();
    session['questions'] = [
      ...(session['questions'] as List),
      {
        'id': 'unanswered',
        'text': 'Still open?',
        'scope': 'shared',
        'answers': [],
      },
    ];
    final selected = buildGuestReportDocument(
      session: session,
      allParticipants: false,
      participantId: 'alice-id',
      generatedAt: DateTime.utc(2026, 10, 3),
    );
    final all = buildGuestReportDocument(
      session: session,
      allParticipants: true,
      participantId: 'alice-id',
      generatedAt: DateTime.utc(2026, 10, 3),
    );

    expect(selected, contains('Selected participant — Alice &lt;A&gt;'));
    expect(selected, contains('Report prepared:'));
    expect(selected, contains('private Alice answer'));
    expect(selected, isNot(contains('private Bob answer')));
    expect(selected, isNot(contains('B &amp; B')));
    expect(selected, isNot(contains('Bob only')));
    expect(selected, contains('Which component?'));
    expect(
      selected,
      contains('Triggered by Alice &lt;A&gt;: private Alice branch answer'),
    );
    expect(selected, contains('Still open?'));
    expect(selected, contains('Unanswered.'));
    expect(all, contains('private Alice answer'));
    expect(all, contains('private Bob answer'));
    expect(all, contains('Bob only'));
    expect(all, contains('Which component?'));
    expect(all, contains('Triggered by B &amp; B: private Bob answer'));
    expect(
      all,
      contains('Triggered by Alice &lt;A&gt;: private Alice branch answer'),
    );
    expect(all, contains('All participants'));

    final selectedData = composeGuestReport(
      session: session,
      allParticipants: false,
      participantId: 'alice-id',
      exportedAt: DateTime.utc(2026, 10, 3),
    );
    final allData = composeGuestReport(
      session: session,
      allParticipants: true,
      participantId: 'alice-id',
      exportedAt: DateTime.utc(2026, 10, 3),
    );
    expect(selectedData.scope, 'Selected participant — Alice <A>');
    expect(selectedData.participantNames, ['Alice <A>']);
    expect(selected, contains('Selected participant — Alice &lt;A&gt;'));
    expect(selected, isNot(contains('Alice &amp;lt;A&amp;gt;')));
    expect(selectedData.questions.first.answers.single.participantName, 'Alice <A>');
    expect(
      selectedData.questions.first.answers.single.followUps.single.triggerAnswer,
      'private Alice answer',
    );
    expect(allData.participantNames, ['Alice <A>', 'B & B']);
    expect(allData.questions.first.answers.map((answer) => answer.participantName), [
      'Alice <A>',
      'B & B',
    ]);
  });

  test('guest report escapes all user-controlled HTML text', () {
    final session = {
      'title': '<script>alert("title")</script>',
      'participants': [
        {'id': 'p1', 'name': 'A & <B>'},
      ],
      'questions': [
        {
          'id': 'q1',
          'text': '<img src=x onerror="bad()">',
          'scope': 'shared',
          'answers': [
            {
              'participant_id': 'p1',
              'body': '<script>answer()</script>',
              'follow_ups': [],
            },
          ],
        },
      ],
    };
    final html = buildGuestReportDocument(
      session: session,
      allParticipants: true,
      participantId: null,
      generatedAt: DateTime.utc(2026, 10, 3),
    );

    expect(html, contains('&lt;script&gt;alert(&quot;title&quot;)&lt;/script&gt;'));
    expect(html, contains('&lt;img src=x onerror=&quot;bad()&quot;&gt;'));
    expect(html, contains('&lt;script&gt;answer()&lt;/script&gt;'));
    expect(html, contains('A &amp; &lt;B&gt;'));
    expect(html, isNot(contains('<script>')));
    expect(html, isNot(contains('<img src=x')));
  });

  test('PDF reports are valid portable documents with safe filenames', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final report = composeGuestReport(
      session: _sessionFixture(),
      allParticipants: false,
      participantId: 'alice-id',
      exportedAt: DateTime.utc(2026, 10, 3),
    );

    final pdf = await buildGuestReportPdf(report);

    expect(String.fromCharCodes(pdf.take(5)), '%PDF-');
    expect(pdf.length, greaterThan(1000));
    expect(guestReportFilename(report), 'two-person-interview-2026-10-03.pdf');

    final portablePdf = await buildGuestPortablePdf(
      GuestPortableDocument(
        title: 'Shared guide',
        scope: 'Authorized guest-group Knowledge entry',
        exportedAt: DateTime.utc(2026, 10, 3),
        sections: const [
          GuestPortableSection(heading: 'Answer', body: 'A readable answer'),
        ],
      ),
    );
    expect(String.fromCharCodes(portablePdf.take(5)), '%PDF-');
    expect(
      guestPortableFilename(
        GuestPortableDocument(
          title: 'Shared guide',
          scope: 'Authorized guest-group Knowledge entry',
          exportedAt: DateTime.utc(2026, 10, 3),
          sections: const [],
        ),
      ),
      'shared-guide-2026-10-03.pdf',
    );
  });

  test('Knowledge PDF fallback escapes content and keeps a readable scope', () {
    final html = buildGuestPortableHtml(
      GuestPortableDocument(
        title: '<Shared> guide',
        scope: 'Authorized group entry',
        exportedAt: DateTime.utc(2026, 10, 3),
        sections: const [
          GuestPortableSection(heading: 'Answer', body: '<script>no</script>'),
        ],
      ),
    );

    expect(html, contains('&lt;Shared&gt; guide'));
    expect(html, contains('&lt;script&gt;no&lt;/script&gt;'));
    expect(html, contains('Authorized group entry'));
    expect(html, isNot(contains('<script>no')));
  });
}

Map<String, dynamic> _sessionFixture() => {
  'id': 'source-session',
  'title': 'Two-person interview',
  'participants': [
    {'id': 'alice-id', 'name': 'Alice <A>'},
    {'id': 'bob-id', 'name': 'B & B'},
  ],
  'questions': [
    {
      'id': 'source-shared',
      'text': 'Shared prompt',
      'scope': 'shared',
      'answers': [
        {
          'participant_id': 'alice-id',
          'body': 'private Alice answer',
          'follow_ups': [
            {
              'id': 'source-alice-follow-up',
              'text': 'Alice follow-up',
              'scope': 'participant',
              'target_participant_id': 'alice-id',
              'answers': [
                {
                  'participant_id': 'alice-id',
                  'body': 'private Alice branch answer',
                  'follow_ups': [
                    {
                      'id': 'source-deep-follow-up',
                      'text': 'Which component?',
                      'scope': 'participant',
                      'target_participant_id': 'alice-id',
                      'answers': [
                        {
                          'participant_id': 'alice-id',
                          'body': 'private deep answer',
                          'follow_ups': [],
                        },
                      ],
                    },
                  ],
                },
              ],
            },
          ],
        },
        {
          'participant_id': 'bob-id',
          'body': 'private Bob answer',
          'follow_ups': [
            {
              'id': 'bob-branch',
              'text': 'Bob follow-up',
              'scope': 'participant',
              'target_participant_id': 'bob-id',
              'answers': [
                {
                  'participant_id': 'bob-id',
                  'body': 'branch answer',
                  'follow_ups': [],
                },
              ],
            },
          ],
        },
      ],
    },
    {
      'id': 'source-bob-only',
      'text': 'Bob only',
      'scope': 'participant',
      'target_participant_id': 'bob-id',
      'answers': [
        {
          'participant_id': 'bob-id',
          'body': '',
          'follow_ups': [],
        },
      ],
    },
  ],
};

List<String> _allQuestionIds(List questions) {
  final ids = <String>[];
  for (final item in questions) {
    final question = item as Map<String, dynamic>;
    ids.add(question['id'] as String);
    for (final answer in question['answers'] as List? ?? const []) {
      ids.addAll(
        _allQuestionIds(
          (answer as Map<String, dynamic>)['follow_ups'] as List? ?? const [],
        ),
      );
    }
  }
  return ids;
}

class _MemoryGuestStorage implements GuestStorage {
  String? value;

  @override
  void remove() => value = null;

  @override
  String? read() => value;

  @override
  void write(String value) => this.value = value;
}
