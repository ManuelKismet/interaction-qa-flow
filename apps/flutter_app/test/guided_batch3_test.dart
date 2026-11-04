import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:int_qa_flow/core/auth/auth_providers.dart';
import 'package:int_qa_flow/features/guided/application/guided_providers.dart';
import 'package:int_qa_flow/features/guided/data/guided_repository.dart';
import 'package:int_qa_flow/features/guided/domain/guided_models.dart';
import 'package:int_qa_flow/features/guided/presentation/guided_session_page.dart';
import 'package:int_qa_flow/features/organisation/application/organisation_providers.dart';

import 'guided_test_support.dart';

GuidedAnswer _answer(
  String id,
  String question,
  String participant,
  String body,
) => GuidedAnswer(
  id: id,
  questionId: question,
  participantId: participant,
  body: body,
  branchesCollapsed: false,
);

GuidedSessionDetail _session({String status = 'draft'}) => GuidedSessionDetail(
  id: 'session-1',
  title: 'Organisation session',
  status: status,
  visibility: 'organisation',
  revision: 4,
  updatedAt: DateTime.utc(2026),
  createdById: 'session-owner',
  ownerText: 'People team',
  participants: const [
    GuidedParticipant(id: 'p-a', name: 'Participant Alpha With Long Name'),
    GuidedParticipant(id: 'p-b', name: 'Beta'),
  ],
  questions: [
    GuidedQuestion(
      id: 'q-shared',
      text: 'What happened?',
      scope: 'shared',
      source: 'manual',
      answers: [
        _answer('a-1', 'q-shared', 'p-a', 'Secret answer A'),
        _answer('a-2', 'q-shared', 'p-b', 'Secret answer B'),
      ],
      followUps: [
        GuidedQuestion(
          id: 'f-1',
          text: 'Why for them?',
          scope: 'participant',
          source: 'follow_up',
          targetParticipantId: 'p-b',
          triggeringAnswerId: 'a-2',
          answers: [_answer('a-3', 'f-1', 'p-b', 'Nested secret')],
          followUps: [
            GuidedQuestion(
              id: 'f-2',
              text: 'And then?',
              scope: 'participant',
              source: 'follow_up',
              targetParticipantId: 'p-b',
              triggeringAnswerId: 'a-3',
              answers: const [],
              followUps: const [],
            ),
          ],
        ),
        GuidedQuestion(
          id: 'f-deleted',
          text: 'Deleted follow-up',
          scope: 'participant',
          source: 'follow_up',
          targetParticipantId: 'p-a',
          deletedAt: '2026-01-01T00:00:00Z',
          answers: const [],
          followUps: const [],
        ),
      ],
    ),
    GuidedQuestion(
      id: 'q-alpha',
      text: 'Alpha only?',
      scope: 'participant',
      source: 'manual',
      targetParticipantId: 'p-a',
      answers: [_answer('a-4', 'q-alpha', 'p-a', '')],
      followUps: const [],
    ),
  ],
  preparedQuestionCount: 2,
  followUpCount: 2,
);

class _FakeRepository extends GuidedRepository {
  _FakeRepository(this.session) : super(Dio());

  GuidedSessionDetail session;
  final calls = <String>[];
  Object? removeError;
  Object? templateError;
  List<Map<String, dynamic>>? templateQuestions;
  Map<String, Object?>? details;

  @override
  Future<GuidedSessionDetail> getSession(
    String id, {
    String? participantId,
    GuidedViewMode mode = GuidedViewMode.allRelevant,
  }) async {
    calls.add('get:${participantId ?? 'all'}');
    return session;
  }

  @override
  Future<void> transition(String sessionId, String action) async {
    calls.add('transition:$action');
    if (action == 'reopen') session = _session(status: 'active');
  }

  @override
  Future<void> removeParticipant(String participantId) async {
    calls.add('remove:$participantId');
    final error = removeError;
    if (error != null) throw error;
  }

  @override
  Future<GuidedParticipant> renameParticipant(
    String participantId,
    String name,
  ) async {
    calls.add('rename:$participantId:$name');
    return GuidedParticipant(id: participantId, name: name);
  }

  @override
  Future<GuidedParticipant> addParticipant(
    String sessionId,
    String name,
  ) async {
    calls.add('add:$name');
    final participant = GuidedParticipant(id: 'p-new', name: name);
    session = GuidedSessionDetail(
      id: session.id,
      title: session.title,
      status: session.status,
      visibility: session.visibility,
      revision: session.revision + 1,
      updatedAt: session.updatedAt,
      createdById: session.createdById,
      participants: [...session.participants, participant],
      questions: session.questions,
      preparedQuestionCount: session.preparedQuestionCount,
      followUpCount: session.followUpCount,
    );
    return participant;
  }

  @override
  Future<void> updateSessionDetails(
    String sessionId, {
    required String title,
    required String? ownerText,
    required String? contextReference,
    required int expectedRevision,
  }) async {
    calls.add('details');
    details = {
      'title': title,
      'owner': ownerText,
      'context': contextReference,
      'revision': expectedRevision,
    };
  }

  @override
  Future<GuidedTemplate> createTemplateFromQuestions(
    String name,
    List<Map<String, dynamic>> questions, {
    String? description,
  }) async {
    calls.add('template:$name');
    final error = templateError;
    if (error != null) throw error;
    templateQuestions = questions;
    return GuidedTemplate(
      id: 't-1',
      name: name,
      status: 'active',
      currentVersion: 1,
      questions: const [],
    );
  }
}

Future<_FakeRepository> _mount(
  WidgetTester tester, {
  String userId = 'session-owner',
  String status = 'draft',
  Size size = const Size(360, 640),
}) async {
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetDevicePixelRatio);
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetPhysicalSize);
  final session = _session(status: status);
  final repository = _FakeRepository(session);
  await tester.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: [
        organisationProfileProvider.overrideWith(
          (ref) async => guidedProfile(userId: userId),
        ),
        guidedRepositoryProvider.overrideWithValue(repository),
        guidedSessionProvider.overrideWith(
          (ref, query) => repository.getSession(
            query.sessionId,
            participantId: query.participantId,
            mode: query.viewMode,
          ),
        ),
        currentMembershipProvider.overrideWith(
          (ref) async => ActiveMembership(
            userId: userId,
            organisationId: 'organisation-1',
            email: 'user@example.invalid',
            displayName: 'User',
            role: 'employee',
          ),
        ),
      ],
      child: const MaterialApp(
        home: Scaffold(body: GuidedSessionPage(sessionId: 'session-1')),
      ),
    ),
  );
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
  return repository;
}

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _sessionAction(WidgetTester tester, String label) async {
  await _tapVisible(tester, find.byTooltip('Session actions'));
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

void main() {
  test(
    'template inputs strip answers and keep targets and nested branches',
    () {
      final inputs = guidedTemplateQuestionsFromSession(_session());
      expect(inputs.map((item) => item['reference']), [
        'q-shared',
        'f-1',
        'f-2',
        'q-alpha',
      ]);
      expect(inputs[0], {
        'text': 'What happened?',
        'scope': 'shared',
        'order_index': 0,
        'participant_reference': null,
        'reference': 'q-shared',
        'parent_reference': null,
      });
      expect(inputs[1]['scope'], 'participant');
      expect(inputs[1]['participant_reference'], 'Participant 2');
      expect(inputs[1]['parent_reference'], 'q-shared');
      expect(inputs[2]['parent_reference'], 'f-1');
      expect(inputs[2]['participant_reference'], 'Participant 2');
      expect(inputs[3]['participant_reference'], 'Participant 1');
      final encoded = inputs.toString();
      for (final hidden in [
        'Secret answer',
        'Nested secret',
        'Alpha With Long Name',
        'Beta',
        'Deleted follow-up',
        'p-a',
        'p-b',
      ]) {
        expect(encoded, isNot(contains(hidden)));
      }
    },
  );

  test('template slots are zero padded to keep server ordering stable', () {
    final base = _session();
    final session = GuidedSessionDetail(
      id: base.id,
      title: base.title,
      status: base.status,
      visibility: base.visibility,
      revision: base.revision,
      updatedAt: base.updatedAt,
      participants: [
        for (var index = 0; index < 11; index++)
          GuidedParticipant(id: 'p$index', name: 'Name $index'),
      ],
      questions: const [
        GuidedQuestion(
          id: 'q',
          text: 'Last participant?',
          scope: 'participant',
          source: 'manual',
          targetParticipantId: 'p10',
          answers: [],
          followUps: [],
        ),
      ],
      preparedQuestionCount: 1,
      followUpCount: 0,
    );
    expect(
      guidedTemplateQuestionsFromSession(
        session,
      ).single['participant_reference'],
      'Participant 11',
    );
    expect(
      guidedTemplateQuestionsFromSession(base)[1]['participant_reference'],
      'Participant 2',
    );
  });

  testWidgets('non-owner cannot see organisation mutation controls', (
    tester,
  ) async {
    final repository = await _mount(tester, userId: 'employee-2');
    await _expectHistoryOnlyActions(tester);
    expect(find.byTooltip('Active participant actions'), findsNothing);
    expect(find.byTooltip('Lifecycle and recovery'), findsOneWidget);
    expect(find.byTooltip('Reports and export'), findsOneWidget);
    await _tapVisible(tester, find.byTooltip('Lifecycle and recovery'));
    expect(find.text('Status: Draft'), findsWidgets);
    expect(
      find.text('You can view this session but cannot change it.'),
      findsOneWidget,
    );
    expect(repository.calls.where((call) => !call.startsWith('get')), isEmpty);
  });

  testWidgets('owner sees destination, status, labels and placeholders', (
    tester,
  ) async {
    await _mount(tester);
    expect(
      find.textContaining(
        'Organisation · Organisation members · Status: Draft',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('prepared'), findsNothing);
    expect(find.textContaining('Prepared'), findsNothing);
    expect(find.text('1/2 answered · 2 follow-ups'), findsOneWidget);
    final question = tester.widget<TextField>(
      find
          .byWidgetPredicate(
            (widget) =>
                widget is TextField &&
                widget.decoration?.labelText == 'Question text',
          )
          .first,
    );
    expect(question.decoration?.hintText, isNotEmpty);
    expect(question.controller?.text, 'What happened?');
    final answer = tester.widget<TextField>(
      find
          .byWidgetPredicate(
            (widget) =>
                widget is TextField &&
                (widget.decoration?.labelText ?? '').startsWith('Answer · '),
          )
          .first,
    );
    expect(answer.decoration?.hintText, startsWith('Record '));
  });

  testWidgets('archive requires confirmation and calls the server transition', (
    tester,
  ) async {
    final repository = await _mount(tester);
    await _sessionAction(tester, 'Archive session');
    expect(find.text('Archive session?'), findsOneWidget);
    expect(find.textContaining('no reopen or restore'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(repository.calls, isNot(contains('transition:archive')));

    await _sessionAction(tester, 'Archive session');
    await tester.tap(find.widgetWithText(FilledButton, 'Archive'));
    await tester.pumpAndSettle();
    expect(repository.calls, contains('transition:archive'));
    expect(
      find.text('Session archived in the organisation workspace.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('completed session is read-only until explicit reopen', (
    tester,
  ) async {
    final repository = await _mount(tester, status: 'completed');
    expect(
      find.byKey(const ValueKey('guided-session-completed-notice')),
      findsOneWidget,
    );
    expect(find.byType(TextField), findsNothing);
    expect(find.text('Add participant'), findsNothing);
    expect(find.byTooltip('Active participant actions'), findsNothing);
    expect(repository.calls.where((call) => !call.startsWith('get')), isEmpty);
    await _tapVisible(tester, find.byTooltip('Session actions'));
    await tester.pumpAndSettle();
    expect(find.text('Edit session details'), findsNothing);
    expect(find.text('Archive session'), findsOneWidget);
    await tester.tapAt(const Offset(4, 4));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Reopen session'));
    await tester.tap(find.text('Reopen session'));
    await tester.pumpAndSettle();
    expect(
      repository.calls.where((call) => call == 'transition:reopen'),
      hasLength(1),
    );
    expect(
      find.byKey(const ValueKey('guided-session-completed-notice')),
      findsNothing,
    );
    expect(find.text('Complete'), findsOneWidget);
    expect(find.byType(TextField), findsWidgets);
    expect(find.text('Add participant'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('completed viewer has reports but no reopen or edit controls', (
    tester,
  ) async {
    await _mount(tester, status: 'completed', userId: 'employee-2');
    expect(
      find.byKey(const ValueKey('guided-session-completed-notice')),
      findsOneWidget,
    );
    expect(find.text('Reopen session'), findsNothing);
    expect(find.byType(TextField), findsNothing);
    await _expectHistoryOnlyActions(tester);
    await _tapVisible(tester, find.byTooltip('Reports and export'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('All participants report'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Secret answer A'), findsWidgets);
    expect(find.textContaining('Secret answer B'), findsWidgets);
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('archived session is read-only with no reopen control', (
    tester,
  ) async {
    await _mount(tester, status: 'archived');
    expect(
      find.byKey(const ValueKey('guided-session-archived-notice')),
      findsOneWidget,
    );
    await _expectHistoryOnlyActions(tester);
    expect(find.textContaining('Reopen'), findsNothing);
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('session details send expected revision and trimmed values', (
    tester,
  ) async {
    final repository = await _mount(tester);
    await _sessionAction(tester, 'Edit session details');
    final title = find.widgetWithText(TextField, 'Session title');
    expect(
      tester.widget<TextField>(title).decoration?.hintText,
      'e.g. Q3 onboarding review',
    );
    await tester.enterText(title, '  Renamed session  ');
    await tester.enterText(find.widgetWithText(TextField, 'Owner'), ' ');
    await tester.enterText(
      find.widgetWithText(TextField, 'Context / reference'),
      'HR-1',
    );
    await tester.tap(find.text('Save details'));
    await tester.pumpAndSettle();
    expect(repository.details, {
      'title': 'Renamed session',
      'owner': null,
      'context': 'HR-1',
      'revision': 4,
    });
    expect(
      find.text('Session details saved to the organisation workspace.'),
      findsOneWidget,
    );
  });

  testWidgets('blank session title is rejected without a request', (
    tester,
  ) async {
    final repository = await _mount(tester);
    await _sessionAction(tester, 'Edit session details');
    await tester.enterText(find.widgetWithText(TextField, 'Session title'), '');
    await tester.tap(find.text('Save details'));
    await tester.pumpAndSettle();
    expect(repository.calls, isNot(contains('details')));
    expect(
      find.text('Session title cannot be blank. Nothing was changed.'),
      findsOneWidget,
    );
  });

  testWidgets('save as template strips answers from the full session', (
    tester,
  ) async {
    final repository = await _mount(tester);
    await _sessionAction(tester, 'Save as organisation template');
    expect(
      find.textContaining('Answers and participant names'),
      findsOneWidget,
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Template name'),
      'Weekly',
    );
    await tester.tap(find.text('Save template'));
    await tester.pumpAndSettle();
    expect(repository.calls, contains('get:all'));
    expect(repository.calls, contains('template:Weekly'));
    expect(repository.templateQuestions, hasLength(4));
    expect(repository.templateQuestions.toString(), isNot(contains('secret')));
    expect(find.textContaining('Answers were not included.'), findsOneWidget);
  });

  testWidgets('duplicate template name reports that nothing was created', (
    tester,
  ) async {
    final repository = await _mount(tester);
    repository.templateError = const GuidedConflict();
    await _sessionAction(tester, 'Save as organisation template');
    await tester.tap(find.text('Save template'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Nothing was created'), findsOneWidget);
    expect(find.textContaining('Saved organisation template'), findsNothing);
  });

  testWidgets('participant rename and guarded removal with Add back', (
    tester,
  ) async {
    final repository = await _mount(tester);
    await _tapVisible(tester, find.byTooltip('Active participant actions'));
    await tester.tap(find.text('Rename participant'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Name'), 'Alpha');
    await tester.tap(find.text('Rename'));
    await tester.pumpAndSettle();
    expect(repository.calls, contains('rename:p-a:Alpha'));
    expect(
      find.text('Participant renamed in the organisation workspace.'),
      findsOneWidget,
    );
    ScaffoldMessenger.of(
      tester.element(find.byType(GuidedSessionPage)),
    ).clearSnackBars();
    await tester.pumpAndSettle();

    repository.removeError = const GuidedConflict();
    await _tapVisible(tester, find.byTooltip('Active participant actions'));
    await tester.tap(find.text('Remove participant'));
    await tester.pumpAndSettle();
    expect(find.textContaining('nothing is removed'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Remove'));
    await tester.pumpAndSettle();
    expect(repository.calls, contains('remove:p-a'));
    expect(find.textContaining('so nothing was removed'), findsOneWidget);
    expect(find.text('Secret answer A'), findsOneWidget);

    ScaffoldMessenger.of(
      tester.element(find.byType(GuidedSessionPage)),
    ).clearSnackBars();
    await tester.pumpAndSettle();
    repository.removeError = null;
    await _tapVisible(tester, find.byTooltip('Active participant actions'));
    await tester.tap(find.text('Remove participant'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Remove'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Removed Participant Alpha'), findsOneWidget);
    await tester.tap(find.text('Add back'));
    await tester.pumpAndSettle();
    expect(repository.calls, contains('add:Participant Alpha With Long Name'));
    expect(
      find.byTooltip('Active participant actions').hitTestable(),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('narrow phone with keyboard keeps question list reachable', (
    tester,
  ) async {
    await _mount(tester, size: const Size(320, 568));
    tester.view.viewInsets = const FakeViewPadding(bottom: 260);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final controls = tester.getRect(
      find.byKey(const ValueKey('guided-session-controls')),
    );
    final list = tester.getRect(find.byKey(const ValueKey('guided-flow-list')));
    expect(list.height, greaterThan(0));
    expect(controls.bottom, lessThanOrEqualTo(list.top + 1));
    final field = find.byWidgetPredicate(
      (widget) =>
          widget is TextField &&
          widget.decoration?.labelText == 'Question text',
    );
    await tester.ensureVisible(field.first);
    await tester.pumpAndSettle();
    await tester.tap(field.first);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final deep = find.text('Path 1.1.1 · Follow-up');
    await tester.scrollUntilVisible(
      deep,
      120,
      scrollable: find
          .descendant(
            of: find.byKey(const ValueKey('guided-flow-list')),
            matching: find.byWidgetPredicate(
              (widget) =>
                  widget is Scrollable &&
                  widget.axisDirection == AxisDirection.down,
            ),
          )
          .first,
    );
    await tester.pumpAndSettle();
    expect(deep.hitTestable(), findsOneWidget);
    await _tapVisible(tester, find.byTooltip('Session actions'));
    expect(
      find.text('Save as organisation template').hitTestable(),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}

Future<void> _expectHistoryOnlyActions(WidgetTester tester) async {
  await _tapVisible(tester, find.byTooltip('Session actions'));
  expect(find.text('Save history'), findsOneWidget);
  expect(find.text('Edit session details'), findsNothing);
  expect(find.text('Save as organisation template'), findsNothing);
  expect(find.text('Archive session'), findsNothing);
  await tester.tapAt(const Offset(5, 5));
  await tester.pumpAndSettle();
}
