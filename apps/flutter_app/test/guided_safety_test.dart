import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:int_qa_flow/core/api/api_client.dart';
import 'package:int_qa_flow/core/auth/auth_providers.dart';
import 'package:int_qa_flow/features/guided/application/guided_pending_edits.dart';
import 'package:int_qa_flow/features/guided/application/guided_providers.dart';
import 'package:int_qa_flow/features/guided/data/guided_repository.dart';
import 'package:int_qa_flow/features/guided/presentation/guided_page.dart';
import 'package:int_qa_flow/features/guided/presentation/guided_session_page.dart';
import 'package:int_qa_flow/features/guided/domain/guided_models.dart';
import 'package:int_qa_flow/features/organisation/application/organisation_providers.dart';
import 'package:int_qa_flow/features/organisation/domain/organisation_models.dart';

import 'guided_test_support.dart';

const _authorizationScheme = 'Bearer';

void main() {
  testWidgets('transient session load still retries and recovers', (
    tester,
  ) async {
    final h = _Harness(useDefaultRetry: true);
    h.adapter.sessionReadStatuses.add(503);
    addTearDown(h.close);
    await _settleAuthority(tester, h);
    await _mount(tester, h);
    expect(find.text('Organisation session'), findsOneWidget);
    expect(h.adapter.reads, hasLength(2));
  });

  for (final status in [403, 404]) {
    for (final owner in [false, true]) {
      testWidgets(
        '${owner ? 'owner' : 'employee'} sees terminal $status session denial without retry spinner',
        (tester) async {
          // Keep Riverpod's production retry policy: disabling container retry
          // would hide the bug that this regression is intended to catch.
          final h = _Harness(useDefaultRetry: true);
          h.isOwner = owner;
          h.adapter.sessionReadStatus = status;
          addTearDown(h.close);
          // Settle auth/authority first so its startup invalidation is not
          // mistaken for an automatic retry of the session denial.
          await _settleAuthority(tester, h);
          await _mount(tester, h);
          const message =
              'This Interact session is unavailable or you do not have permission to view it.';
          expect(find.text(message), findsOneWidget);
          expect(find.byType(CircularProgressIndicator), findsNothing);
          expect(find.text('Organisation session'), findsNothing);
          expect(find.text('Private secret marker'), findsNothing);
          expect(find.byTooltip('Reports and export'), findsNothing);
          expect(h.adapter.reads, hasLength(1));
          expect(h.adapter.writes, isEmpty);
          await tester.pump(const Duration(seconds: 10));
          expect(h.adapter.reads, hasLength(1));
          await tester.tap(find.text('Try again'));
          await tester.pumpAndSettle();
          expect(h.adapter.reads, hasLength(2));
          expect(find.text(message), findsOneWidget);
          await tester.tap(find.text('Back to Interact'));
          await tester.pumpAndSettle();
          expect(find.text('Session list'), findsOneWidget);
        },
      );
    }
  }

  for (final transition in ['uid', 'organisation', 'user', 'permission']) {
    test(
      'real guided provider rejects delayed read after $transition change',
      () async {
        final h = _Harness();
        addTearDown(h.close);
        await h.ready();
        h.adapter.holdReads = true;
        final query = (
          sessionId: 'session-1',
          participantId: null,
          viewMode: GuidedViewMode.allRelevant,
        );
        final renderedTitles = <String>[];
        final subscription = h.container.listen(guidedSessionProvider(query), (
          _,
          next,
        ) {
          if (next.hasValue && !next.isLoading) {
            renderedTitles.add(next.requireValue.title);
          }
        });
        addTearDown(subscription.close);
        final originalRepository = h.container.read(guidedRepositoryProvider);
        final old = h.container.read(guidedSessionProvider(query).future);
        final checked = old.then<Object?>(
          (value) => value.title,
          onError: (Object error) => error,
        );
        // A provider's .future can follow a rebuild; observe the original request too.
        final originalRead = expectLater(
          originalRepository.getSession('session-1'),
          throwsStateError,
        );
        await _waitFor(
          () => h.adapter.reads.length == 2 && h.adapter.readGate != null,
          reason: 'Both original-scope reads must reach the delayed adapter.',
        );
        final oldGate = h.adapter.readGate!;
        h.adapter.holdReads = false;
        h.change(transition);
        await h.ready();
        expect(originalRepository.cancelToken!.isCancelled, isTrue);
        await _waitFor(
          () => h.adapter.cancelledReads.length == 2,
          reason:
              'Both original-scope reads must be cancelled on $transition change.',
        );
        oldGate.complete(
          _response(h.adapter.session(title: 'Old private marker')),
        );
        await originalRead.timeout(const Duration(seconds: 2));
        expect(
          await checked.timeout(const Duration(seconds: 2)),
          isNot('Old private marker'),
        );
        final current = await h.container
            .read(guidedSessionProvider(query).future)
            .timeout(const Duration(seconds: 2));
        expect(current.title, 'Organisation session');
        expect(renderedTitles, isNot(contains('Old private marker')));
        await expectLater(
          originalRepository.updateAnswer('answer-1', body: 'stale'),
          throwsStateError,
        );
        expect(h.adapter.writes, isEmpty);
      },
    );
  }

  test(
    'real repository binds delayed mutation token acquisition to original UID',
    () async {
      final h = _Harness();
      addTearDown(h.close);
      await h.ready();
      final repository = h.container.read(guidedRepositoryProvider);
      h.tokens.tokenGate = Completer<String?>();
      final write = repository.updateAnswer(
        'answer-1',
        body: 'A private edit',
        expectedRevision: 1,
      );
      final checked = expectLater(write, throwsStateError);
      await _waitFor(() => h.tokens.tokenWaits == 1);
      h.change('uid');
      await h.ready();
      h.tokens.tokenGate!.complete('uid-a');
      await checked.timeout(const Duration(seconds: 2));
      expect(h.adapter.writes, isEmpty);
    },
  );

  test(
    'real repository preserves import warnings and rejects 409 as conflict',
    () async {
      final h = _Harness();
      addTearDown(h.close);
      await h.ready();
      final repository = h.container.read(guidedRepositoryProvider);
      final imported = await repository.importLegacy(
        '{"meta":{},"participants":[],"flow":[]}',
      );
      expect(imported.warnings, [
        'Missing legacy participant name was replaced.',
      ]);
      expect(imported.session.id, 'session-1');
      h.adapter.revision = 2;
      await expectLater(
        repository.updateQuestion(
          'question-1',
          'New title',
          expectedRevision: 1,
        ),
        throwsA(isA<GuidedConflict>()),
      );
      expect(h.adapter.title, 'What happened?');
    },
  );

  for (final changedTarget in [
    'question',
    'answer',
    'participant',
    'follow-up',
  ]) {
    for (final complete in [true, false]) {
      test(
        'retains $changedTarget draft on disappeared or re-owned target (complete=$complete)',
        () async {
          final h = _Harness();
          h.adapter.showFollowUp = changedTarget == 'follow-up';
          addTearDown(h.close);
          await h.ready();
          final repository = h.container.read(guidedRepositoryProvider);
          final initial = await repository.getSession('session-1');
          final question = changedTarget == 'follow-up'
              ? initial.questions.first.followUps.first
              : initial.questions.first;
          final pending = GuidedPendingEdits(
            repository: repository,
            sessionId: 'session-1',
            onChanged: () {},
          );
          addTearDown(pending.close);
          pending.reconcile(initial);
          await pending.answer(
            question,
            question.answerFor('participant-1'),
            'participant-1',
            'Retained original draft',
          );
          switch (changedTarget) {
            case 'question':
              h.adapter.removeQuestion = true;
            case 'answer':
              h.adapter.removeAnswer = true;
            case 'participant':
              h.adapter.removeParticipant = true;
            case 'follow-up':
              h.adapter.followUpOwner = 'bob';
          }
          h.adapter.revision++;
          pending.reconcile(
            await repository.getSession('session-1'),
            complete: complete,
          );
          await pending.flush();
          expect(pending.conflict, isTrue);
          expect(pending.values.values, contains('Retained original draft'));
          expect(pending.state, GuidedSaveState.failed);
          expect(h.adapter.writes, isEmpty);
          await pending.retry();
          expect(pending.conflict, isTrue);
          expect(h.adapter.writes, isEmpty);
        },
      );
    }
  }

  test('failed route flush is not replayed without explicit retry', () async {
    final h = _Harness();
    addTearDown(h.close);
    await h.ready();
    final repository = h.container.read(guidedRepositoryProvider);
    final pending = GuidedPendingEdits(
      repository: repository,
      sessionId: 'session-1',
      onChanged: () {},
    );
    addTearDown(pending.close);
    final session = await repository.getSession('session-1');
    pending.reconcile(session);
    await pending.answer(
      session.questions.first,
      session.questions.first.answerFor('participant-1'),
      'participant-1',
      'Retained route draft',
    );
    h.adapter.failWrites = true;
    await Future.wait([pending.flush(), pending.flush()]);
    await pending.flush();
    expect(h.adapter.writes, hasLength(1));
    expect(pending.state, GuidedSaveState.failed);
    expect(pending.values.values, contains('Retained route draft'));
    h.adapter.failWrites = false;
    await pending.retry();
    expect(h.adapter.writes, hasLength(2));
    expect(
      h.adapter.writes.map((request) => request.path),
      everyElement('/api/v1/guided/answers/answer-1'),
    );
    expect(h.adapter.body, 'Retained route draft');
    expect(pending.state, GuidedSaveState.saved);
  });

  test(
    'concurrent full-read flushes retain the original participant',
    () async {
      final h = _Harness();
      h.adapter.filterToActiveParticipant = true;
      addTearDown(h.close);
      await h.ready();
      final repository = h.container.read(guidedRepositoryProvider);
      final pending = GuidedPendingEdits(
        repository: repository,
        sessionId: 'session-1',
        onChanged: () {},
      );
      addTearDown(pending.close);
      final session = await repository.getSession('session-1');
      pending.reconcile(session);
      await pending.answer(
        session.questions.first,
        session.questions.first.answerFor('participant-1'),
        'participant-1',
        'Alice retained draft',
      );
      pending.reconcile(
        await repository.getSession('session-1', participantId: 'bob'),
        complete: false,
      );
      h.adapter.holdReads = true;
      final readsBeforeFlush = h.adapter.reads.length;
      final drain = Future.wait([pending.flush(), pending.flush()]);
      final rawRead = repository.getSession('session-1');
      await _waitFor(
        () => h.adapter.reads.length == readsBeforeFlush + 2,
        reason: 'The drain and independent read must both wait on the gate.',
      );
      expect(h.adapter.writes, isEmpty);
      h.adapter.holdReads = false;
      h.adapter.readGate!.complete(_response(h.adapter.session()));
      await drain;
      expect((await rawRead).id, 'session-1');
      expect(h.adapter.writes, hasLength(1));
      expect(h.adapter.writes.single.path, '/api/v1/guided/answers/answer-1');
      expect(h.adapter.writes.single.data['expected_revision'], 1);
      expect(h.adapter.body, 'Alice retained draft');
      expect(h.adapter.bobBody, 'Bob original answer');
      expect(pending.state, GuidedSaveState.saved);
    },
  );

  testWidgets(
    'blank answer persists, reloads blank, but blank question remains unsaved',
    (tester) async {
      final h = _Harness();
      addTearDown(h.close);
      await _mount(tester, h);
      await tester.enterText(
        find.byKey(const ValueKey('answer-question-1-participant-1')),
        '',
      );
      await tester.pump(const Duration(milliseconds: 649));
      expect(h.adapter.writes, isEmpty);
      await tester.pump(const Duration(milliseconds: 2));
      await tester.pumpAndSettle();
      expect(h.adapter.body, '');
      expect(h.adapter.writes.single.data['body'], '');
      expect(h.adapter.writes.single.data['expected_revision'], 1);
      expect(find.text('Saved'), findsOneWidget);
      h.container.invalidate(guidedSessionProvider);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(
              find.descendant(
                of: find.byKey(
                  const ValueKey('answer-question-1-participant-1'),
                ),
                matching: find.byType(TextField),
              ),
            )
            .controller!
            .text,
        '',
      );

      await tester.enterText(
        find.byKey(const ValueKey('question-question-1')),
        '   ',
      );
      await tester.pump(const Duration(milliseconds: 651));
      await tester.pumpAndSettle();
      expect(h.adapter.title, 'What happened?');
      expect(h.adapter.writes, hasLength(1));
      expect(
        find.textContaining('Question title cannot be blank'),
        findsOneWidget,
      );
      expect(find.text('Saved'), findsNothing);
    },
  );

  testWidgets(
    'clearing an existing collapsed answer uses PATCH and preserves its recursive branch',
    (tester) async {
      final h = _Harness();
      h.adapter.showFollowUp = true;
      h.adapter.collapsed = true;
      addTearDown(h.close);
      await _mount(tester, h);
      await tester.enterText(
        find.byKey(const ValueKey('answer-question-1-participant-1')),
        '',
      );
      await tester.pump(const Duration(milliseconds: 651));
      await tester.pumpAndSettle();
      final write = h.adapter.writes.single;
      expect(write.method, 'PATCH');
      expect(write.path, '/api/v1/guided/answers/answer-1');
      expect((write.data as Map).containsKey('branches_collapsed'), isFalse);
      expect(h.adapter.body, '');
      expect(h.adapter.collapsed, isTrue);
      expect(find.text('Expand branch'), findsOneWidget);
      expect(find.text('Original follow-up'), findsNothing);
      final reloaded = (await tester.runAsync(
        () =>
            h.container.read(guidedRepositoryProvider).getSession('session-1'),
      ))!;
      expect(reloaded.questions.first.followUps.single.id, 'follow-up-1');
      expect(
        reloaded.questions.first.answerFor('participant-1')!.branchesCollapsed,
        isTrue,
      );
    },
  );

  testWidgets(
    'retry of failed new blank answer must create a real answer before reporting Saved',
    (tester) async {
      final h = _Harness();
      h.adapter.removeAnswer = true;
      addTearDown(h.close);
      await _mount(tester, h);
      h.adapter.failWrites = true;
      final field = find.byKey(
        const ValueKey('answer-question-1-participant-1'),
      );
      await tester.enterText(field, 'Temporary text');
      await tester.enterText(field, '');
      await tester.pump(const Duration(milliseconds: 651));
      await tester.pumpAndSettle();
      expect(h.adapter.removeAnswer, isTrue);
      expect(h.adapter.writes, hasLength(1));
      expect(h.adapter.writes.single.method, 'POST');
      expect(h.adapter.writes.single.data['body'], '');
      expect(find.text('Saved'), findsNothing);
      expect(find.textContaining('Not saved:'), findsOneWidget);
      h.adapter.failWrites = false;
      await tester.tap(find.text('Review and retry'));
      await tester.pumpAndSettle();
      expect(h.adapter.writes, hasLength(2));
      expect(h.adapter.writes.last.method, 'POST');
      expect(h.adapter.writes.last.data['body'], '');
      expect(h.adapter.removeAnswer, isFalse);
      final reloaded = (await tester.runAsync(
        () =>
            h.container.read(guidedRepositoryProvider).getSession('session-1'),
      ))!;
      expect(reloaded.questions.first.answerFor('participant-1'), isNotNull);
      expect(reloaded.questions.first.answerFor('participant-1')!.body, '');
      expect(find.text('Saved'), findsOneWidget);
    },
  );

  testWidgets(
    'rapid route disposal flushes original session and preserves a failed edit for retry',
    (tester) async {
      final h = _Harness();
      addTearDown(h.close);
      final router = await _mount(tester, h);
      h.adapter.failWrites = true;
      await tester.enterText(
        find.byKey(const ValueKey('answer-question-1-participant-1')),
        'Navigation edit',
      );
      await tester.pump(const Duration(milliseconds: 100));
      router.go('/guided');
      await tester.pumpAndSettle();
      expect(h.adapter.writes, hasLength(1));
      expect(h.adapter.writes.single.path, '/api/v1/guided/answers/answer-1');
      expect(h.adapter.body, 'Original answer');
      final pending = h.container.read(guidedPendingEditsProvider('session-1'));
      expect(pending.values.values, contains('Navigation edit'));
      expect(pending.state, GuidedSaveState.failed);
      router.go('/guided/sessions/session-1');
      await tester.pumpAndSettle();
      expect(find.textContaining('Not saved:'), findsOneWidget);
      expect(find.text('Navigation edit'), findsOneWidget);
      h.adapter.failWrites = false;
      await tester.tap(find.text('Review and retry'));
      await tester.pumpAndSettle();
      expect(h.adapter.body, 'Navigation edit');
      expect(find.text('Saved'), findsOneWidget);
      expect(h.adapter.writes.last.extra['expectedFirebaseUid'], 'uid-a');
      expect(
        h.adapter.writes.last.headers['Authorization'],
        '$_authorizationScheme uid-a',
      );
    },
  );

  testWidgets(
    'concurrent refresh retains local edit and explicit conflict does not overwrite server',
    (tester) async {
      final h = _Harness();
      addTearDown(h.close);
      await _mount(tester, h);
      await tester.enterText(
        find.byKey(const ValueKey('answer-question-1-participant-1')),
        'Local pending',
      );
      h.adapter.body = 'Other device answer';
      h.adapter.revision++;
      h.container.invalidate(guidedSessionProvider);
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 700));
      expect(h.adapter.writes, isEmpty);
      expect(find.text('Local pending'), findsOneWidget);
      expect(
        find.textContaining('Your pending edits are retained'),
        findsOneWidget,
      );
      await tester.tap(find.text('Review and retry'));
      await tester.pumpAndSettle();
      expect(h.adapter.writes, isEmpty);
      expect(h.adapter.body, 'Other device answer');
      await tester.tap(find.text('Use server version'));
      await tester.pumpAndSettle();
      expect(find.text('Other device answer'), findsOneWidget);
      expect(find.text('Local pending'), findsNothing);
    },
  );

  testWidgets('clean external refresh reconciles stable text controllers', (
    tester,
  ) async {
    final h = _Harness();
    addTearDown(h.close);
    await _mount(tester, h);
    h.adapter.body = 'Reloaded from another device';
    h.adapter.title = 'Updated server question';
    h.adapter.revision++;
    h.container.invalidate(guidedSessionProvider);
    await tester.pumpAndSettle();
    expect(find.text('Reloaded from another device'), findsOneWidget);
    expect(find.text('Updated server question'), findsOneWidget);
    expect(find.text('Original answer'), findsNothing);
    expect(h.adapter.writes, isEmpty);
  });

  testWidgets(
    'ambiguous failed save is reconciled without replaying an acknowledged edit',
    (tester) async {
      final h = _Harness();
      addTearDown(h.close);
      await _mount(tester, h);
      h.adapter.failAfterWrite = true;
      await tester.enterText(
        find.byKey(const ValueKey('answer-question-1-participant-1')),
        'Committed but response failed',
      );
      await tester.pump(const Duration(milliseconds: 651));
      await tester.pumpAndSettle();
      expect(h.adapter.body, 'Committed but response failed');
      expect(find.text('Saved'), findsNothing);
      expect(find.textContaining('Not saved:'), findsOneWidget);
      await tester.tap(find.text('Review and retry'));
      await tester.pumpAndSettle();
      expect(h.adapter.writes, hasLength(1));
      expect(find.text('Saved'), findsOneWidget);
    },
  );

  testWidgets(
    'multiple dirty fields serialize expected revisions and report Saved only after all writes',
    (tester) async {
      final h = _Harness();
      addTearDown(h.close);
      await _mount(tester, h);
      await tester.enterText(
        find.byKey(const ValueKey('question-question-1')),
        'Changed question',
      );
      await tester.enterText(
        find.byKey(const ValueKey('answer-question-1-participant-1')),
        'Changed answer',
      );
      await tester.pump(const Duration(milliseconds: 651));
      await tester.pumpAndSettle();
      expect(
        h.adapter.writes.map((request) => request.data['expected_revision']),
        [1, 2],
      );
      expect(h.adapter.title, 'Changed question');
      expect(h.adapter.body, 'Changed answer');
      expect(find.text('Saved'), findsOneWidget);
    },
  );

  testWidgets(
    'queued edits use the actual server session revision acknowledgement',
    (tester) async {
      final h = _Harness();
      h.adapter.revisionStep = 3;
      addTearDown(h.close);
      await _mount(tester, h);
      await tester.enterText(
        find.byKey(const ValueKey('question-question-1')),
        'Revision-aware title',
      );
      await tester.enterText(
        find.byKey(const ValueKey('answer-question-1-participant-1')),
        'Revision-aware answer',
      );
      await tester.pump(const Duration(milliseconds: 651));
      await tester.pumpAndSettle();
      expect(
        h.adapter.writes.map((request) => request.data['expected_revision']),
        [1, 4],
      );
      expect(
        h.container.read(guidedPendingEditsProvider('session-1')).revision,
        7,
      );
      expect(find.text('Saved'), findsOneWidget);
    },
  );

  testWidgets(
    'typing during an in-flight save retains the newest value and revision',
    (tester) async {
      final h = _Harness();
      addTearDown(h.close);
      await _mount(tester, h);
      h.adapter.holdWrites = true;
      final field = find.byKey(
        const ValueKey('answer-question-1-participant-1'),
      );
      await tester.enterText(field, 'First version');
      await tester.pump(const Duration(milliseconds: 651));
      await tester.pumpAndSettle();
      expect(find.text('Saved'), findsNothing);
      await tester.enterText(field, 'Newest version');
      h.adapter.holdWrites = false;
      h.adapter.writeGate!.complete(_response({}));
      await tester.pumpAndSettle();
      expect(
        h.adapter.writes.map((request) => request.data['expected_revision']),
        [1, 2],
      );
      expect(h.adapter.body, 'Newest version');
      expect(find.text('Saved'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 700));
      expect(h.adapter.writes, hasLength(2));
    },
  );

  testWidgets(
    'participant switch cannot redirect a pending answer to the newly selected participant',
    (tester) async {
      final h = _Harness();
      h.adapter.filterToActiveParticipant = true;
      addTearDown(h.close);
      await _mount(tester, h);
      final fullReadsBeforeSwitch = h.adapter.reads
          .where((request) => request.queryParameters['participant_id'] == null)
          .length;
      await tester.enterText(
        find.byKey(const ValueKey('answer-question-1-participant-1')),
        'Alice pending edit',
      );
      await tester.tap(find.text('Alice').last);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text('Bob').last);
      await tester.pump(const Duration(milliseconds: 100));
      await _pumpUntil(
        tester,
        () {
          final detail = h.container.read(
            guidedSessionProvider((
              sessionId: 'session-1',
              participantId: 'bob',
              viewMode: GuidedViewMode.allRelevant,
            )),
          );
          return !detail.isLoading &&
              !detail.hasError &&
              detail.hasValue &&
              detail.requireValue.questions.first.answerFor('participant-1') ==
                  null &&
              detail.requireValue.questions.first.answerFor('bob') != null &&
              find
                  .byKey(const ValueKey('answer-question-1-bob'))
                  .evaluate()
                  .isNotEmpty;
        },
        reason: 'Bob’s filtered view must reconcile before debounce expires.',
      );
      await tester.pump();
      expect(h.adapter.writes, isEmpty);
      await tester.pump(const Duration(milliseconds: 651));
      await tester.pumpAndSettle();
      expect(h.adapter.writes.single.path, '/api/v1/guided/answers/answer-1');
      expect(h.adapter.body, 'Alice pending edit');
      expect(h.adapter.bobBody, 'Bob original answer');
      expect(find.text('Bob original answer'), findsOneWidget);
      expect(find.textContaining('Not saved:'), findsNothing);
      expect(
        h.adapter.reads
            .where(
              (request) => request.queryParameters['participant_id'] == null,
            )
            .length,
        greaterThan(fullReadsBeforeSwitch),
      );
    },
  );

  testWidgets(
    'permission change cancels pending debounce and does not transfer drafts',
    (tester) async {
      final h = _Harness();
      h.userId = 'not-creator';
      h.isOwner = true;
      addTearDown(h.close);
      await _mount(tester, h);
      await tester.enterText(
        find.byKey(const ValueKey('answer-question-1-participant-1')),
        'Do not transfer',
      );
      h.isOwner = false;
      h.change('permission');
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 700));
      expect(h.adapter.writes, isEmpty);
      expect(find.text('Do not transfer'), findsNothing);
      expect(
        find.byKey(const ValueKey('guided-session-read-only-notice')),
        findsOneWidget,
      );
    },
  );

  testWidgets('equivalent same-UID authority refresh preserves pending edits', (
    tester,
  ) async {
    final h = _Harness();
    addTearDown(h.close);
    await _mount(tester, h);
    final original = h.container.read(guidedRepositoryProvider);
    await tester.enterText(
      find.byKey(const ValueKey('answer-question-1-participant-1')),
      'Survives token refresh',
    );
    h.events.add(GuidedTestUser(h.uid));
    await tester.pumpAndSettle();
    expect(
      identical(h.container.read(guidedRepositoryProvider), original),
      isTrue,
    );
    await tester.pump(const Duration(milliseconds: 651));
    await tester.pumpAndSettle();
    expect(h.adapter.body, 'Survives token refresh');
    expect(h.adapter.writes, hasLength(1));
    expect(find.text('Saved'), findsOneWidget);
  });

  testWidgets(
    'delayed same-identity authority refresh pauses saves but retains a visible retry draft',
    (tester) async {
      final h = _Harness();
      addTearDown(h.close);
      await _mount(tester, h);
      final repository = h.container.read(guidedRepositoryProvider);
      final pending = h.container.read(guidedPendingEditsProvider('session-1'));
      await tester.enterText(
        find.byKey(const ValueKey('answer-question-1-participant-1')),
        'Retained during refresh',
      );
      h.authorityGate = Completer<void>();
      h.container.invalidate(organisationProfileProvider);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 651));
      expect(h.adapter.writes, isEmpty);
      expect(
        identical(h.container.read(guidedRepositoryProvider), repository),
        isTrue,
      );
      expect(pending.values.values, contains('Retained during refresh'));
      h.authorityGate!.complete();
      await tester.pumpAndSettle();
      expect(find.text('Retained during refresh'), findsOneWidget);
      expect(find.textContaining('Not saved:'), findsOneWidget);
      await tester.tap(find.text('Review and retry'));
      await tester.pumpAndSettle();
      expect(h.adapter.body, 'Retained during refresh');
      expect(find.text('Saved'), findsOneWidget);
    },
  );

  testWidgets(
    'session visibility revocation stops pending timers without a mutation',
    (tester) async {
      final h = _Harness()
        ..userId = 'not-creator'
        ..isOwner = true;
      addTearDown(h.close);
      await _mount(tester, h);
      await tester.enterText(
        find.byKey(const ValueKey('answer-question-1-participant-1')),
        'Before private transition',
      );
      h.adapter.visibility = 'private';
      h.adapter.revision++;
      h.container.invalidate(guidedSessionProvider);
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 700));
      expect(h.adapter.writes, isEmpty);
      expect(
        find.byKey(const ValueKey('guided-session-read-only-notice')),
        findsOneWidget,
      );
      final pending = h.container.read(guidedPendingEditsProvider('session-1'));
      expect(pending.state, GuidedSaveState.failed);
      expect(pending.values.values, contains('Before private transition'));
    },
  );

  testWidgets('new session route saves pending text to original session only', (
    tester,
  ) async {
    final h = _Harness();
    addTearDown(h.close);
    final router = await _mount(tester, h);
    await tester.enterText(
      find.byKey(const ValueKey('answer-question-1-participant-1')),
      'Original session edit',
    );
    await tester.pump(const Duration(milliseconds: 100));
    router.go('/guided/sessions/session-2');
    await tester.pumpAndSettle();
    expect(h.adapter.writes, hasLength(1));
    expect(h.adapter.writes.single.path, '/api/v1/guided/answers/answer-1');
    expect(h.adapter.body, 'Original session edit');
    expect(h.adapter.secondBody, 'Second session answer');
    expect(find.text('Second session'), findsOneWidget);
    expect(find.text('Original session edit'), findsNothing);
  });

  testWidgets(
    'delayed write acknowledgement cannot publish Saved under another UID',
    (tester) async {
      final h = _Harness();
      addTearDown(h.close);
      await _mount(tester, h);
      h.adapter.holdWrites = true;
      await tester.enterText(
        find.byKey(const ValueKey('answer-question-1-participant-1')),
        'First account edit',
      );
      await tester.pump(const Duration(milliseconds: 651));
      await tester.pumpAndSettle();
      expect(h.adapter.writes, hasLength(1));
      h.change('uid');
      await tester.pumpAndSettle();
      h.adapter.writeGate!.complete(_response({}));
      await tester.pumpAndSettle();
      expect(find.text('Saved'), findsNothing);
      expect(h.adapter.writes.single.extra['expectedFirebaseUid'], 'uid-a');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('open session export clears on identity change', (tester) async {
    final h = _Harness();
    addTearDown(h.close);
    await _mount(tester, h);
    await tester.tap(find.byTooltip('Reports and export'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('JSON'));
    await tester.pumpAndSettle();
    expect(find.text('JSON export'), findsOneWidget);
    expect(find.byType(SelectableText), findsOneWidget);
    h.change('uid');
    await tester.pumpAndSettle();
    expect(find.text('JSON export'), findsNothing);
    expect(find.byType(SelectableText), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final destination in ['/guided', '/guided/sessions/session-2']) {
    for (final status in [200, 503]) {
      testWidgets(
        'late export ($status) cannot open a dialog or snackbar after navigating to $destination',
        (tester) async {
          final h = _Harness();
          addTearDown(h.close);
          final router = await _mount(tester, h);
          final originalPage = tester.state(find.byType(GuidedSessionPage));
          final repository = h.container.read(guidedRepositoryProvider);
          h.adapter.holdExports = true;
          await tester.tap(find.byTooltip('Reports and export'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('JSON'));
          await tester.pumpAndSettle();
          expect(
            h.adapter.exports.single.path,
            '/api/v1/guided/sessions/session-1/export/json',
          );
          expect(h.adapter.exportGate, isNotNull);
          final gate = h.adapter.exportGate!;

          router.go(destination);
          await tester.pumpAndSettle();
          if (destination == '/guided') {
            expect(originalPage.mounted, isFalse);
            expect(find.text('Session list'), findsOneWidget);
          } else {
            expect(find.text('Second session'), findsOneWidget);
          }
          // Navigation must exercise the page guards, not repository cancellation.
          expect(
            identical(h.container.read(guidedRepositoryProvider), repository),
            isTrue,
          );
          expect(repository.cancelToken!.isCancelled, isFalse);
          gate.complete(
            _response({'title': 'Old private export marker'}, status: status),
          );
          await tester.pumpAndSettle();
          expect(
            find.text(
              destination == '/guided' ? 'Session list' : 'Second session',
            ),
            findsOneWidget,
          );
          expect(find.text('Organisation session'), findsNothing);
          expect(find.text('JSON export'), findsNothing);
          expect(
            find.textContaining('Old private export marker'),
            findsNothing,
          );
          expect(find.byType(AlertDialog), findsNothing);
          expect(find.byType(SnackBar), findsNothing);
          expect(h.adapter.writes, isEmpty);
          expect(tester.takeException(), isNull);
        },
      );
    }

    testWidgets(
      'late session read cannot render after navigating to $destination',
      (tester) async {
        final h = _Harness();
        addTearDown(h.close);
        final router = await _mount(tester, h);
        final originalPage = tester.state(find.byType(GuidedSessionPage));
        final repository = h.container.read(guidedRepositoryProvider);
        final originalReads = h.adapter.reads.length;
        h.adapter.holdReads = true;
        h.container.invalidate(guidedSessionProvider);
        final rawResults = <Object>[];
        unawaited(
          repository
              .getSession('session-1')
              .then<void>(
                (session) => rawResults.add(session.title),
                onError: (Object error) => rawResults.add(error),
              ),
        );
        await _pumpUntil(
          tester,
          () => h.adapter.reads.length == originalReads + 2,
          reason: 'Both original-session reads must reach the delayed adapter.',
        );
        expect(h.adapter.readGate, isNotNull);
        final gate = h.adapter.readGate!;
        h.adapter.holdReads = false;
        router.go(destination);
        await tester.pumpAndSettle();
        if (destination == '/guided') expect(originalPage.mounted, isFalse);
        expect(repository.cancelToken!.isCancelled, isFalse);
        gate.complete(
          _response(h.adapter.session(title: 'Old private read marker')),
        );
        await _pumpUntil(
          tester,
          () => rawResults.isNotEmpty,
          reason: 'The released original-session read must complete.',
        );
        await tester.pumpAndSettle();
        // The original raw read really arrived; only its abandoned view is stale.
        expect(rawResults, ['Old private read marker']);
        expect(
          find.text(
            destination == '/guided' ? 'Session list' : 'Second session',
          ),
          findsOneWidget,
        );
        expect(find.text('Organisation session'), findsNothing);
        expect(find.text('Old private read marker'), findsNothing);
        expect(find.byType(AlertDialog), findsNothing);
        expect(find.byType(SnackBar), findsNothing);
        expect(h.adapter.writes, isEmpty);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'dialog opened by original user cannot mutate after identity switch',
    (tester) async {
      final h = _Harness();
      addTearDown(h.close);
      await _mount(tester, h);
      await tester.tap(find.text('Shared question'));
      await tester.pumpAndSettle();
      final input = find.byWidgetPredicate(
        (widget) =>
            widget is TextField && widget.decoration?.labelText == 'Question',
      );
      await tester.enterText(input, 'Original user draft');
      h.change('uid');
      await tester.pumpAndSettle();
      expect(find.text('Original user draft'), findsNothing);
      expect(find.text('Add shared question'), findsNothing);
      expect(h.adapter.writes, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  for (final actor in ['owner', 'legacy', 'role-only', 'delegate', 'creator']) {
    for (final visibility in ['organisation', 'private']) {
      testWidgets('$actor authority on $visibility session matches backend', (
        tester,
      ) async {
        final h = _Harness()
          ..userId = actor == 'creator' ? 'db-a' : 'non-creator'
          ..isOwner = actor == 'owner'
          ..permissions = actor == 'legacy'
              ? {'legacy_admin'}
              : actor == 'delegate'
              ? {'review'}
              : {}
          ..role = actor == 'role-only' ? 'admin' : 'employee';
        h.adapter.visibility = visibility;
        addTearDown(h.close);
        await _mount(tester, h);
        final canEdit =
            actor == 'creator' ||
            (visibility != 'private' &&
                (actor == 'owner' || actor == 'legacy'));
        expect(
          find.text('Shared question'),
          canEdit ? findsOneWidget : findsNothing,
        );
        expect(find.byType(TextField), canEdit ? findsWidgets : findsNothing);
        expect(find.byTooltip('Reports and export'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
    testWidgets('$actor template management uses grants, not role labels', (
      tester,
    ) async {
      final h = _Harness()
        ..userId = actor == 'creator' ? 'db-a' : 'non-creator'
        ..isOwner = actor == 'owner'
        ..permissions = actor == 'legacy'
            ? {'legacy_admin'}
            : actor == 'delegate'
            ? {'review'}
            : {}
        ..role = actor == 'role-only' ? 'admin' : 'employee';
      h.adapter.showTemplate = true;
      addTearDown(h.close);
      final router = await _mount(tester, h);
      router.go('/guided/import');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Templates'));
      await tester.pumpAndSettle();
      final menu = find.descendant(
        of: find.byKey(const ValueKey('guided-template-template-1')),
        matching: find.byType(PopupMenuButton<String>),
      );
      final canManage = ['owner', 'legacy', 'creator'].contains(actor);
      expect(menu, canManage ? findsOneWidget : findsNothing);
      if (actor == 'legacy') {
        h.permissions = {};
        h.container.invalidate(organisationProfileProvider);
        await tester.pumpAndSettle();
        expect(menu, findsNothing);
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'organisation import warnings remain visible before opening imported session',
    (tester) async {
      final h = _Harness();
      addTearDown(h.close);
      final router = await _mount(tester, h);
      router.go('/guided/import');
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Interact options'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Import session'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextField),
        '{"meta":{},"participants":[],"flow":[]}',
      );
      await tester.tap(find.text('Import'));
      await tester.pumpAndSettle();
      expect(find.text('Imported with warnings'), findsOneWidget);
      expect(
        find.text('Missing legacy participant name was replaced.'),
        findsOneWidget,
      );
      expect(find.text('Organisation session'), findsNothing);
      await tester.tap(find.text('Review session'));
      await tester.pumpAndSettle();
      expect(find.text('Organisation session'), findsOneWidget);
    },
  );

  testWidgets(
    'unsupported guest backup import has a visible failure and no navigation',
    (tester) async {
      final h = _Harness();
      addTearDown(h.close);
      final router = await _mount(tester, h);
      router.go('/guided/import');
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Interact options'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Import session'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextField),
        '{"sessions":[],"templates":[],"knowledge":[]}',
      );
      await tester.tap(find.text('Import'));
      await tester.pumpAndSettle();
      expect(find.text('Import failed'), findsOneWidget);
      expect(
        find.textContaining('not a guest workspace backup'),
        findsOneWidget,
      );
      expect(find.text('Organisation session'), findsNothing);
    },
  );
}

Future<void> _settleAuthority(WidgetTester tester, _Harness h) => _pumpUntil(
  tester,
  () {
    final state = h.container.read(organisationProfileProvider);
    return !state.isLoading &&
        !state.hasError &&
        state.value?.isOwner == h.isOwner;
  },
  reason:
      'Authentication and organisation authority must settle before the session read.',
);

Future<GoRouter> _mount(WidgetTester tester, _Harness h) async {
  tester.view.physicalSize = const Size(1100, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final router = GoRouter(
    initialLocation: '/guided/sessions/session-1',
    routes: [
      GoRoute(
        path: '/guided/sessions/:id',
        builder: (context, state) => Scaffold(
          body: GuidedSessionPage(sessionId: state.pathParameters['id']!),
        ),
      ),
      GoRoute(
        path: '/guided',
        builder: (_, _) => const Scaffold(body: Text('Session list')),
      ),
      GoRoute(
        path: '/guided/import',
        builder: (_, _) => const Scaffold(body: GuidedPage()),
      ),
    ],
  );
  addTearDown(router.dispose);
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    h.releaseGates();
    await tester.pumpAndSettle();
  });
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: h.container,
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

class _Harness {
  _Harness({bool useDefaultRetry = false}) {
    tokens = _Tokens(() => uid);
    client = createApiClient(tokens, adapter: adapter);
    container = ProviderContainer(
      retry: useDefaultRetry ? null : (_, _) => null,
      overrides: [
        apiClientProvider.overrideWithValue(client),
        authStateProvider.overrideWith(
          (ref) => Stream<User?>.multi((controller) {
            controller.add(GuidedTestUser(uid));
            final subscription = events.stream.listen(
              controller.add,
              onError: controller.addError,
              onDone: controller.close,
            );
            controller.onCancel = subscription.cancel;
          }),
        ),
        currentMembershipProvider.overrideWith((ref) async {
          final auth = ref.watch(authStateProvider);
          if (!auth.hasValue || auth.isLoading) {
            await ref.watch(authStateProvider.future);
          }
          return ActiveMembership(
            userId: userId,
            organisationId: organisationId,
            email: 'test@example.invalid',
            displayName: 'Tester',
            role: role,
          );
        }),
        organisationProfileProvider.overrideWith((ref) async {
          final membership = await ref.watch(currentMembershipProvider.future);
          await authorityGate?.future;
          return guidedProfile(
            userId: membership.userId,
            organisationId: membership.organisationId,
            role: membership.role,
            isOwner: isOwner,
            permissions: permissions,
            scopes: [
              if (permissions.contains('review'))
                const OrganisationCapability(
                  permission: 'review',
                  scopeType: 'department',
                  scopeId: 'dept-a',
                ),
            ],
          );
        }),
      ],
    );
    // Keep streams active and autoDispose authority alive across read/await gaps.
    authoritySubscriptions = [
      container.listen(authStateProvider, (_, _) {}),
      container.listen(currentMembershipProvider, (_, _) {}),
      container.listen(organisationProfileProvider, (_, _) {}),
    ];
  }

  String uid = 'uid-a';
  String userId = 'db-a';
  String organisationId = 'org-a';
  String role = 'employee';
  bool isOwner = false;
  Set<String> permissions = {};
  Completer<void>? authorityGate;
  final events = StreamController<User?>.broadcast();
  final adapter = _Adapter();
  late final _Tokens tokens;
  late final Dio client;
  late final ProviderContainer container;
  late final List<ProviderSubscription<dynamic>> authoritySubscriptions;

  Future<void> ready() async {
    await _waitFor(() {
      final auth = container.read(authStateProvider);
      final membership = container.read(currentMembershipProvider);
      final authority = container.read(organisationProfileProvider);
      return !auth.isLoading &&
          !auth.hasError &&
          auth.value?.uid == uid &&
          !membership.isLoading &&
          !membership.hasError &&
          membership.value?.userId == userId &&
          membership.value?.organisationId == organisationId &&
          !authority.isLoading &&
          !authority.hasError &&
          authority.value?.userId == userId &&
          authority.value?.organisationId == organisationId &&
          authority.value?.isOwner == isOwner &&
          setEquals(authority.value?.permissions, permissions);
    }, reason: 'Authority must settle for $uid / $userId / $organisationId.');
    container.read(guidedRepositoryProvider);
    await container.pump();
  }

  void change(String transition) {
    switch (transition) {
      case 'uid':
        uid = 'uid-b';
        userId = 'db-b';
        events.add(GuidedTestUser(uid));
      case 'organisation':
        organisationId = 'org-b';
        container.invalidate(currentMembershipProvider);
      case 'user':
        userId = 'db-other';
        container.invalidate(currentMembershipProvider);
      case 'permission':
        permissions = {'review'};
        container.invalidate(organisationProfileProvider);
    }
  }

  void releaseGates() {
    final authority = authorityGate;
    if (authority != null && !authority.isCompleted) authority.complete();
    final tokenGate = tokens.tokenGate;
    if (tokenGate != null && !tokenGate.isCompleted) tokenGate.complete(uid);
    adapter.releaseGates();
  }

  Future<void> close() async {
    for (final subscription in authoritySubscriptions.reversed) {
      subscription.close();
    }
    container.dispose();
    releaseGates();
    client.close(force: true);
    await events.close();
  }
}

class _Tokens implements ApiTokenSource {
  _Tokens(this.uid);
  final String Function() uid;
  Completer<String?>? tokenGate;
  int tokenWaits = 0;
  @override
  String? get currentUid => uid();
  @override
  Future<String?> idToken({bool forceRefresh = false}) async {
    if (tokenGate != null) {
      tokenWaits++;
      return tokenGate!.future;
    }
    return uid();
  }

  @override
  Future<String?> appCheckToken() async => 'test-app-check';
  @override
  Future<void> signOut() async {}
}

class _Adapter implements HttpClientAdapter {
  final List<RequestOptions> writes = [];
  final List<RequestOptions> reads = [];
  final List<RequestOptions> cancelledReads = [];
  final List<RequestOptions> exports = [];
  bool holdReads = false;
  int? sessionReadStatus;
  final List<int> sessionReadStatuses = [];
  bool holdExports = false;
  bool failWrites = false;
  bool failAfterWrite = false;
  bool holdWrites = false;
  bool showTemplate = false;
  bool removeQuestion = false;
  bool removeAnswer = false;
  bool removeParticipant = false;
  bool showFollowUp = false;
  bool filterToActiveParticipant = false;
  bool collapsed = false;
  String followUpOwner = 'participant-1';
  Completer<_Response>? readGate;
  Completer<_Response>? writeGate;
  Completer<_Response>? exportGate;
  final Map<Completer<ResponseBody>, RequestOptions> _heldRequests = {};
  String body = 'Original answer';
  String title = 'What happened?';
  String visibility = 'organisation';
  int revision = 1;
  int revisionStep = 1;
  String secondBody = 'Second session answer';
  String bobBody = 'Bob original answer';

  Map<String, Object?> session({
    String title = 'Organisation session',
    String id = 'session-1',
  }) => {
    'id': id,
    'title': title,
    'created_by': 'db-a',
    'status': 'draft',
    'visibility': visibility,
    'revision': revision,
    'updated_at': '2026-10-07T00:00:00Z',
    'participants': [
      if (!removeParticipant)
        {
          'id': id == 'session-1' ? 'participant-1' : 'participant-2',
          'name': 'Alice',
        },
      if (id == 'session-1') {'id': 'bob', 'name': 'Bob'},
    ],
    'questions': [
      if (!removeQuestion)
        {
          'id': id == 'session-1' ? 'question-1' : 'question-2',
          'text': this.title,
          'scope': 'shared',
          'source': 'manual',
          'answers': [
            if (!removeAnswer)
              {
                'id': id == 'session-1' ? 'answer-1' : 'answer-2',
                'question_id': id == 'session-1' ? 'question-1' : 'question-2',
                'participant_id': id == 'session-1'
                    ? 'participant-1'
                    : 'participant-2',
                'body': id == 'session-1' ? body : secondBody,
                'branches_collapsed': collapsed,
              },
            if (id == 'session-1')
              {
                'id': 'answer-bob',
                'question_id': 'question-1',
                'participant_id': 'bob',
                'body': bobBody,
                'branches_collapsed': false,
              },
          ],
          'follow_ups': [
            if (showFollowUp)
              {
                'id': 'follow-up-1',
                'text': 'Original follow-up',
                'scope': 'participant',
                'source': 'follow_up',
                'target_participant_id': followUpOwner,
                'triggering_answer_id': followUpOwner == 'bob'
                    ? 'answer-bob'
                    : 'answer-1',
                'answers': [
                  {
                    'id': 'follow-answer-1',
                    'question_id': 'follow-up-1',
                    'participant_id': followUpOwner,
                    'body': 'Original follow-up answer',
                    'branches_collapsed': false,
                  },
                ],
                'follow_ups': [],
              },
          ],
        },
    ],
    'prepared_question_count': 1,
    'follow_up_count': showFollowUp ? 1 : 0,
  };

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.path == '/api/v1/guided/import/legacy') {
      final payload = options.data['payload'] as Map;
      if (payload.containsKey('sessions')) {
        return _response({
          'detail': 'Unsupported guest backup',
        }, status: 409).open();
      }
      return _response({
        'session': session(),
        'warnings': ['Missing legacy participant name was replaced.'],
      }).open();
    }
    if (options.method != 'GET') {
      writes.add(options);
      if (failWrites) return _response({}, status: 503).open();
      final expected = options.data['expected_revision'];
      if (expected != null && expected != revision) {
        return _response({}, status: 409).open();
      }
      if (options.method == 'POST' && options.path.endsWith('/answers')) {
        removeAnswer = false;
      }
      if (options.data['body'] != null) {
        final value = options.data['body'] as String;
        if (options.path.endsWith('/answer-bob') ||
            options.data['participant_id'] == 'bob') {
          bobBody = value;
        } else if (options.path.endsWith('/answer-2') ||
            options.data['participant_id'] == 'participant-2') {
          secondBody = value;
        } else {
          body = value;
        }
      }
      if (options.data['branches_collapsed'] != null) {
        collapsed = options.data['branches_collapsed'] as bool;
      }
      if (options.data['text'] != null) title = options.data['text'] as String;
      revision += revisionStep;
      if (failAfterWrite) {
        failAfterWrite = false;
        return _response({}, status: 503).open();
      }
      if (holdWrites) {
        writeGate ??= Completer<_Response>();
        return _heldResponse(writeGate!, options, cancelFuture);
      }
      return _response({'session_revision': revision}).open();
    }
    if (options.path.contains('/sessions/') &&
        options.path.contains('/export/')) {
      exports.add(options);
      if (holdExports) {
        exportGate ??= Completer<_Response>();
        return _heldResponse(exportGate!, options, cancelFuture);
      }
      return _response(session()).open();
    }
    if (options.path.contains('/sessions/session-')) {
      reads.add(options);
      final status = sessionReadStatuses.isNotEmpty
          ? sessionReadStatuses.removeAt(0)
          : sessionReadStatus;
      if (status != null) {
        return _response({
          'detail': 'Private secret marker',
        }, status: status).open();
      }
      if (holdReads) {
        readGate ??= Completer<_Response>();
        return _heldResponse(readGate!, options, cancelFuture);
      }
      final id = options.path.split('/').last;
      final detail = session(
        id: id,
        title: id == 'session-1' ? 'Organisation session' : 'Second session',
      );
      final participant = options.queryParameters['participant_id'];
      if (filterToActiveParticipant && participant != null) {
        detail['questions'] = [
          for (final raw in detail['questions'] as List)
            if ((raw as Map)['scope'] == 'shared' ||
                raw['target_participant_id'] == participant)
              {
                ...Map<String, Object?>.from(raw),
                'answers': [
                  for (final answer in raw['answers'] as List)
                    if ((answer as Map)['participant_id'] == participant)
                      answer,
                ],
                'follow_ups': [
                  for (final followUp in raw['follow_ups'] as List)
                    if ((followUp as Map)['target_participant_id'] ==
                        participant)
                      followUp,
                ],
              },
        ];
      }
      return _response(detail).open();
    }
    if (options.path == '/api/v1/guided/templates' && showTemplate) {
      return _response([
        {
          'id': 'template-1',
          'name': 'Template',
          'created_by': 'db-a',
          'status': 'active',
          'current_version': 1,
          'questions': [],
        },
      ]).open();
    }
    return _response([]).open();
  }

  Future<ResponseBody> _heldResponse(
    Completer<_Response> gate,
    RequestOptions options,
    Future<void>? cancelFuture,
  ) {
    final result = Completer<ResponseBody>();
    _heldRequests[result] = options;
    gate.future.then((response) {
      if (result.isCompleted) return;
      _heldRequests.remove(result);
      result.complete(response.open());
    });
    cancelFuture?.then((_) {
      if (result.isCompleted) return;
      _heldRequests.remove(result);
      if (options.method == 'GET') cancelledReads.add(options);
      result.completeError(
        DioException.requestCancelled(
          requestOptions: options,
          reason: 'Interact authority changed.',
        ),
      );
    });
    return result.future;
  }

  void releaseGates() {
    holdReads = false;
    holdWrites = false;
    holdExports = false;
    final read = readGate;
    if (read != null && !read.isCompleted) read.complete(_response(session()));
    final write = writeGate;
    if (write != null && !write.isCompleted) {
      write.complete(_response({'session_revision': revision}));
    }
    final export = exportGate;
    if (export != null && !export.isCompleted) {
      export.complete(_response(session()));
    }
  }

  @override
  void close({bool force = false}) {
    for (final entry in _heldRequests.entries.toList()) {
      entry.key.completeError(
        DioException.requestCancelled(
          requestOptions: entry.value,
          reason: 'Test adapter closed.',
        ),
      );
    }
    _heldRequests.clear();
    releaseGates();
  }
}

_Response _response(Object? data, {int status = 200}) =>
    _Response(jsonEncode(data), status);

class _Response {
  const _Response(this.body, this.status);

  final String body;
  final int status;

  // Each held request owns a stream, including concurrent reads on one gate.
  ResponseBody open() => ResponseBody.fromString(
    body,
    status,
    headers: {
      Headers.contentTypeHeader: ['application/json'],
    },
  );
}

Future<void> _waitFor(bool Function() condition, {String? reason}) async {
  for (var attempt = 0; attempt < 200 && !condition(); attempt++) {
    await Future<void>.delayed(const Duration(milliseconds: 1));
  }

  expect(condition(), isTrue, reason: reason);
}

Future<void> _pumpUntil(
  WidgetTester tester,
  bool Function() condition, {
  String? reason,
}) async {
  for (var attempt = 0; attempt < 200 && !condition(); attempt++) {
    await tester.pump(const Duration(milliseconds: 1));
  }
  expect(condition(), isTrue, reason: reason);
}
