import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:int_qa_flow/core/api/api_exception.dart';
import 'package:int_qa_flow/core/auth/auth_providers.dart';
import 'package:int_qa_flow/features/guided/application/guided_providers.dart';
import 'package:int_qa_flow/features/guided/domain/guided_models.dart';
import 'package:int_qa_flow/features/guided/data/guided_repository.dart';
import 'package:int_qa_flow/features/guided/presentation/guided_session_page.dart';
import 'package:int_qa_flow/features/organisation/application/organisation_providers.dart';

import 'guided_test_support.dart';

final _session = GuidedSessionDetail(
  id: 'session-1',
  title: 'Organisation session',
  status: 'draft',
  visibility: 'organisation',
  revision: 1,
  updatedAt: DateTime.utc(2026),
  createdById: 'session-owner',
  participants: [
    GuidedParticipant(
      id: 'participant-1',
      name: 'Participant One With A Long Display Name',
    ),
  ],
  questions: [
    GuidedQuestion(
      id: 'question-1',
      text: 'What happened?',
      scope: 'shared',
      source: 'manual',
      answers: [
        GuidedAnswer(
          id: 'answer-1',
          questionId: 'question-1',
          participantId: 'participant-1',
          body: 'The shipment arrived.',
          branchesCollapsed: false,
        ),
      ],
      followUps: [],
    ),
  ],
  preparedQuestionCount: 1,
  followUpCount: 0,
);

void main() {
  testWidgets('session 404 exits loading and retry reloads session', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.physicalSize = const Size(360, 800);
    addTearDown(tester.view.resetPhysicalSize);
    var requestCount = 0;
    Future<GuidedSessionDetail> loadSession() async {
      requestCount++;
      if (requestCount == 1) {
        throw const ApiException('That item could not be found.');
      }
      return _session;
    }

    final noParticipantQuery = (
      sessionId: _session.id,
      participantId: null,
      viewMode: GuidedViewMode.allRelevant,
    );
    final participantQuery = (
      sessionId: _session.id,
      participantId: 'participant-1',
      viewMode: GuidedViewMode.allRelevant,
    );
    await tester.pumpWidget(
      ProviderScope(
        retry: (_, _) => null,
        overrides: [
          organisationProfileProvider.overrideWith(
            (ref) async => guidedProfile(),
          ),
          guidedSessionProvider(
            noParticipantQuery,
          ).overrideWith((ref) => loadSession()),
          guidedSessionProvider(
            participantQuery,
          ).overrideWith((ref) => loadSession()),
          currentMembershipProvider.overrideWith(
            (ref) async => const ActiveMembership(
              userId: 'employee-1',
              organisationId: 'organisation-1',
              email: 'employee@example.invalid',
              displayName: 'Employee',
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

    expect(requestCount, 1);
    expect(find.text('Unable to load this Interact session.'), findsOneWidget);
    expect(find.text('What happened?'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();

    expect(requestCount, 3);
    expect(find.text('Unable to load this Interact session.'), findsNothing);
    expect(find.text('What happened?'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('guided-session-read-only-notice')),
      findsOneWidget,
    );
  });

  testWidgets(
    'non-owner employee sees session read-only but can report/export',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.view.physicalSize = const Size(360, 800);
      addTearDown(tester.view.resetPhysicalSize);
      final noParticipantQuery = (
        sessionId: _session.id,
        participantId: null,
        viewMode: GuidedViewMode.allRelevant,
      );
      final participantQuery = (
        sessionId: _session.id,
        participantId: 'participant-1',
        viewMode: GuidedViewMode.allRelevant,
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            organisationProfileProvider.overrideWith(
              (ref) async => guidedProfile(),
            ),
            guidedSessionProvider(
              noParticipantQuery,
            ).overrideWith((ref) async => _session),
            guidedSessionProvider(
              participantQuery,
            ).overrideWith((ref) async => _session),
            currentMembershipProvider.overrideWith(
              (ref) async => const ActiveMembership(
                userId: 'employee-1',
                organisationId: 'organisation-1',
                email: 'employee@example.invalid',
                displayName: 'Employee',
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

      expect(
        find.byKey(const ValueKey('guided-session-read-only-notice')),
        findsOneWidget,
      );
      expect(
        find.textContaining(
          'Private sessions can only be edited by their creator.',
        ),
        findsOneWidget,
      );
      expect(find.text('Add participant'), findsNothing);
      expect(find.text('Shared question'), findsNothing);
      expect(find.text('Participant question'), findsNothing);
      expect(find.text('Start'), findsNothing);
      expect(find.text('What happened?'), findsOneWidget);
      expect(find.text('The shipment arrived.'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      expect(find.byTooltip('Reports and export'), findsOneWidget);
      await tester.tap(find.byTooltip('Reports and export'));
      await tester.pumpAndSettle();
      expect(find.text('Active participant report'), findsOneWidget);
      expect(find.text('All participants report'), findsOneWidget);
      await tester.tap(find.text('Active participant report'));
      await tester.pumpAndSettle();
      expect(find.text('What happened?'), findsOneWidget);

      await tester.tap(find.byTooltip('Reports and export'));
      await tester.pumpAndSettle();
      expect(find.text('JSON'), findsOneWidget);
      expect(find.text('CSV'), findsOneWidget);
    },
  );

  testWidgets('session owner retains editing controls', (tester) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.physicalSize = const Size(360, 800);
    addTearDown(tester.view.resetPhysicalSize);
    final noParticipantQuery = (
      sessionId: _session.id,
      participantId: null,
      viewMode: GuidedViewMode.allRelevant,
    );
    final participantQuery = (
      sessionId: _session.id,
      participantId: 'participant-1',
      viewMode: GuidedViewMode.allRelevant,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          organisationProfileProvider.overrideWith(
            (ref) async => guidedProfile(),
          ),
          guidedRepositoryProvider.overrideWithValue(GuidedRepository(Dio())),
          guidedSessionProvider(
            noParticipantQuery,
          ).overrideWith((ref) async => _session),
          guidedSessionProvider(
            participantQuery,
          ).overrideWith((ref) async => _session),
          currentMembershipProvider.overrideWith(
            (ref) async => const ActiveMembership(
              userId: 'session-owner',
              organisationId: 'organisation-1',
              email: 'owner@example.invalid',
              displayName: 'Owner',
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

    expect(
      find.byKey(const ValueKey('guided-session-read-only-notice')),
      findsNothing,
    );
    expect(find.text('Add participant'), findsOneWidget);
    expect(find.text('Start'), findsOneWidget);
    expect(find.byType(TextField), findsWidgets);
    await tester.scrollUntilVisible(
      find.text('Shared question'),
      200,
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
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('guided-flow-list')),
        matching: find.text('Shared question'),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
