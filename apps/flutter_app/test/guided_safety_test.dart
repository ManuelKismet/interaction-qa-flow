import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
  for (final transition in ['uid', 'organisation', 'user', 'permission']) {
    test('real guided provider rejects delayed read after $transition change', () async {
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
      final subscription = h.container.listen(
        guidedSessionProvider(query),
        (_, next) {
          if (next.hasValue && !next.isLoading) {
            renderedTitles.add(next.requireValue.title);
          }
        },
      );
      addTearDown(subscription.close);
      final old = h.container.read(guidedSessionProvider(query).future);
      final checked = old.then<Object?>(
        (value) => value.title,
        onError: (Object error) => error,
      );
      await _waitFor(() => h.adapter.readGate != null);
      final originalRepository = h.container.read(guidedRepositoryProvider);
      h.adapter.holdReads = false;
      h.change(transition);
      await h.ready();
      h.adapter.readGate!.complete(_response(h.adapter.session(title: 'Old private marker')));
      expect(await checked, isNot('Old private marker'));
      final current = await h.container.read(guidedSessionProvider(query).future);
      expect(current.title, 'Organisation session');
      expect(renderedTitles, isNot(contains('Old private marker')));
      await expectLater(
        originalRepository.updateAnswer('answer-1', body: 'stale'),
        throwsStateError,
      );
      expect(h.adapter.writes, isEmpty);
    });
  }

  test('real repository binds delayed mutation token acquisition to original UID', () async {
    final h = _Harness();
    addTearDown(h.close);
    await h.ready();
    final repository = h.container.read(guidedRepositoryProvider);
    h.tokens.tokenGate = Completer<String?>();
    final write = repository.updateAnswer('answer-1', body: 'A private edit', expectedRevision: 1);
    final checked = expectLater(write, throwsA(anything));
    await _waitFor(() => h.tokens.tokenWaits == 1);
    h.change('uid');
    h.tokens.tokenGate!.complete('uid-a');
    await checked;
    expect(h.adapter.writes, isEmpty);
  });

  test('real repository preserves import warnings and rejects 409 as conflict', () async {
    final h = _Harness();
    addTearDown(h.close);
    await h.ready();
    final repository = h.container.read(guidedRepositoryProvider);
    final imported = await repository.importLegacy('{"meta":{},"participants":[],"flow":[]}');
    expect(imported.warnings, ['Missing legacy participant name was replaced.']);
    expect(imported.session.id, 'session-1');
    h.adapter.revision = 2;
    await expectLater(
      repository.updateQuestion('question-1', 'New title', expectedRevision: 1),
      throwsA(isA<GuidedConflict>()),
    );
    expect(h.adapter.title, 'What happened?');
  });

  for (final changedTarget in ['question', 'answer', 'participant', 'follow-up']) {
    for (final complete in [true, false]) {
      test('retains $changedTarget draft on disappeared or re-owned target (complete=$complete)', () async {
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
          question, question.answerFor('participant-1'), 'participant-1', 'Retained original draft',
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
        pending.reconcile(await repository.getSession('session-1'), complete: complete);
        await pending.flush();
        expect(pending.conflict, isTrue);
        expect(pending.values.values, contains('Retained original draft'));
        expect(pending.state, GuidedSaveState.failed);
        expect(h.adapter.writes, isEmpty);
        await pending.retry();
        expect(pending.conflict, isTrue);
        expect(h.adapter.writes, isEmpty);
      });
    }
  }

  testWidgets('blank answer persists, reloads blank, but blank question remains unsaved', (tester) async {
    final h = _Harness();
    addTearDown(h.close);
    await _mount(tester, h);
    await tester.enterText(find.byKey(const ValueKey('answer-question-1-participant-1')), '');
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
    expect(tester.widget<TextField>(
      find.descendant(
        of: find.byKey(const ValueKey('answer-question-1-participant-1')),
        matching: find.byType(TextField),
      ),
    ).controller!.text, '');

    await tester.enterText(find.byKey(const ValueKey('question-question-1')), '   ');
    await tester.pump(const Duration(milliseconds: 651));
    await tester.pumpAndSettle();
    expect(h.adapter.title, 'What happened?');
    expect(h.adapter.writes, hasLength(1));
    expect(find.textContaining('Question title cannot be blank'), findsOneWidget);
    expect(find.text('Saved'), findsNothing);
  });

  testWidgets('clearing an existing collapsed answer uses PATCH and preserves its recursive branch', (tester) async {
    final h = _Harness();
    h.adapter.showFollowUp = true;
    h.adapter.collapsed = true;
    addTearDown(h.close);
    await _mount(tester, h);
    await tester.enterText(find.byKey(const ValueKey('answer-question-1-participant-1')), '');
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
    final reloaded = await h.container.read(guidedRepositoryProvider).getSession('session-1');
    expect(reloaded.questions.first.followUps.single.id, 'follow-up-1');
    expect(reloaded.questions.first.answerFor('participant-1')!.branchesCollapsed, isTrue);
  });

  testWidgets('retry of failed new blank answer must create a real answer before reporting Saved', (tester) async {
    final h = _Harness();
    h.adapter.removeAnswer = true;
    addTearDown(h.close);
    await _mount(tester, h);
    h.adapter.failWrites = true;
    final field = find.byKey(const ValueKey('answer-question-1-participant-1'));
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
    final reloaded = await h.container.read(guidedRepositoryProvider).getSession('session-1');
    expect(reloaded.questions.first.answerFor('participant-1'), isNotNull);
    expect(reloaded.questions.first.answerFor('participant-1')!.body, '');
    expect(find.text('Saved'), findsOneWidget);
  });

  testWidgets('rapid route disposal flushes original session and preserves a failed edit for retry', (tester) async {
    final h = _Harness();
    addTearDown(h.close);
    final router = await _mount(tester, h);
    h.adapter.failWrites = true;
    await tester.enterText(find.byKey(const ValueKey('answer-question-1-participant-1')), 'Navigation edit');
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
    expect(h.adapter.writes.last.headers['Authorization'], '$_authorizationScheme uid-a');
  });

  testWidgets('concurrent refresh retains local edit and explicit conflict does not overwrite server', (tester) async {
    final h = _Harness();
    addTearDown(h.close);
    await _mount(tester, h);
    await tester.enterText(find.byKey(const ValueKey('answer-question-1-participant-1')), 'Local pending');
    h.adapter.body = 'Other device answer';
    h.adapter.revision++;
    h.container.invalidate(guidedSessionProvider);
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 700));
    expect(h.adapter.writes, isEmpty);
    expect(find.text('Local pending'), findsOneWidget);
    expect(find.textContaining('Your pending edits are retained'), findsOneWidget);
    await tester.tap(find.text('Review and retry'));
    await tester.pumpAndSettle();
    expect(h.adapter.writes, isEmpty);
    expect(h.adapter.body, 'Other device answer');
    await tester.tap(find.text('Use server version'));
    await tester.pumpAndSettle();
    expect(find.text('Other device answer'), findsOneWidget);
    expect(find.text('Local pending'), findsNothing);
  });

  testWidgets('clean external refresh reconciles stable text controllers', (tester) async {
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

  testWidgets('ambiguous failed save is reconciled without replaying an acknowledged edit', (tester) async {
    final h = _Harness();
    addTearDown(h.close);
    await _mount(tester, h);
    h.adapter.failAfterWrite = true;
    await tester.enterText(find.byKey(const ValueKey('answer-question-1-participant-1')), 'Committed but response failed');
    await tester.pump(const Duration(milliseconds: 651));
    await tester.pumpAndSettle();
    expect(h.adapter.body, 'Committed but response failed');
    expect(find.text('Saved'), findsNothing);
    expect(find.textContaining('Not saved:'), findsOneWidget);
    await tester.tap(find.text('Review and retry'));
    await tester.pumpAndSettle();
    expect(h.adapter.writes, hasLength(1));
    expect(find.text('Saved'), findsOneWidget);
  });

  testWidgets('multiple dirty fields serialize expected revisions and report Saved only after all writes', (tester) async {
    final h = _Harness();
    addTearDown(h.close);
    await _mount(tester, h);
    await tester.enterText(find.byKey(const ValueKey('question-question-1')), 'Changed question');
    await tester.enterText(find.byKey(const ValueKey('answer-question-1-participant-1')), 'Changed answer');
    await tester.pump(const Duration(milliseconds: 651));
    await tester.pumpAndSettle();
    expect(h.adapter.writes.map((request) => request.data['expected_revision']), [1, 2]);
    expect(h.adapter.title, 'Changed question');
    expect(h.adapter.body, 'Changed answer');
    expect(find.text('Saved'), findsOneWidget);
  });

  testWidgets('queued edits use the actual server session revision acknowledgement', (tester) async {
    final h = _Harness();
    h.adapter.revisionStep = 3;
    addTearDown(h.close);
    await _mount(tester, h);
    await tester.enterText(find.byKey(const ValueKey('question-question-1')), 'Revision-aware title');
    await tester.enterText(find.byKey(const ValueKey('answer-question-1-participant-1')), 'Revision-aware answer');
    await tester.pump(const Duration(milliseconds: 651));
    await tester.pumpAndSettle();
    expect(h.adapter.writes.map((request) => request.data['expected_revision']), [1, 4]);
    expect(h.container.read(guidedPendingEditsProvider('session-1')).revision, 7);
    expect(find.text('Saved'), findsOneWidget);
  });

  testWidgets('typing during an in-flight save retains the newest value and revision', (tester) async {
    final h = _Harness();
    addTearDown(h.close);
    await _mount(tester, h);
    h.adapter.holdWrites = true;
    final field = find.byKey(const ValueKey('answer-question-1-participant-1'));
    await tester.enterText(field, 'First version');
    await tester.pump(const Duration(milliseconds: 651));
    await tester.pumpAndSettle();
    expect(find.text('Saved'), findsNothing);
    await tester.enterText(field, 'Newest version');
    h.adapter.holdWrites = false;
    h.adapter.writeGate!.complete(_response({}));
    await tester.pumpAndSettle();
    expect(h.adapter.writes.map((request) => request.data['expected_revision']), [1, 2]);
    expect(h.adapter.body, 'Newest version');
    expect(find.text('Saved'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 700));
    expect(h.adapter.writes, hasLength(2));
  });

  testWidgets('participant switch cannot redirect a pending answer to the newly selected participant', (tester) async {
    final h = _Harness();
    h.adapter.filterToActiveParticipant = true;
    addTearDown(h.close);
    await _mount(tester, h);
    final fullReadsBeforeSwitch = h.adapter.reads.where(
      (request) => request.queryParameters['participant_id'] == null,
    ).length;
    await tester.enterText(find.byKey(const ValueKey('answer-question-1-participant-1')), 'Alice pending edit');
    await tester.tap(find.text('Alice').last);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('Bob').last);
    await tester.pump(const Duration(milliseconds: 100));
    expect(h.adapter.writes, isEmpty);
    await tester.pump(const Duration(milliseconds: 651));
    await tester.pumpAndSettle();
    expect(h.adapter.writes.single.path, '/api/v1/guided/answers/answer-1');
    expect(h.adapter.body, 'Alice pending edit');
    expect(h.adapter.bobBody, 'Bob original answer');
    expect(find.text('Bob original answer'), findsOneWidget);
    expect(find.textContaining('Not saved:'), findsNothing);
    expect(h.adapter.reads.where(
      (request) => request.queryParameters['participant_id'] == null,
    ).length, greaterThan(fullReadsBeforeSwitch));
  });

  testWidgets('permission change cancels pending debounce and does not transfer drafts', (tester) async {
    final h = _Harness();
    h.userId = 'not-creator';
    h.isOwner = true;
    addTearDown(h.close);
    await _mount(tester, h);
    await tester.enterText(find.byKey(const ValueKey('answer-question-1-participant-1')), 'Do not transfer');
    h.isOwner = false;
    h.change('permission');
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 700));
    expect(h.adapter.writes, isEmpty);
    expect(find.text('Do not transfer'), findsNothing);
    expect(find.byKey(const ValueKey('guided-session-read-only-notice')), findsOneWidget);
  });

  testWidgets('equivalent same-UID authority refresh preserves pending edits', (tester) async {
    final h = _Harness();
    addTearDown(h.close);
    await _mount(tester, h);
    final original = h.container.read(guidedRepositoryProvider);
    await tester.enterText(find.byKey(const ValueKey('answer-question-1-participant-1')), 'Survives token refresh');
    h.events.add(GuidedTestUser(h.uid));
    await tester.pumpAndSettle();
    expect(identical(h.container.read(guidedRepositoryProvider), original), isTrue);
    await tester.pump(const Duration(milliseconds: 651));
    await tester.pumpAndSettle();
    expect(h.adapter.body, 'Survives token refresh');
    expect(h.adapter.writes, hasLength(1));
    expect(find.text('Saved'), findsOneWidget);
  });

  testWidgets('delayed same-identity authority refresh pauses saves but retains a visible retry draft', (tester) async {
    final h = _Harness();
    addTearDown(h.close);
    await _mount(tester, h);
    final repository = h.container.read(guidedRepositoryProvider);
    final pending = h.container.read(guidedPendingEditsProvider('session-1'));
    await tester.enterText(find.byKey(const ValueKey('answer-question-1-participant-1')), 'Retained during refresh');
    h.authorityGate = Completer<void>();
    h.container.invalidate(organisationProfileProvider);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 651));
    expect(h.adapter.writes, isEmpty);
    expect(identical(h.container.read(guidedRepositoryProvider), repository), isTrue);
    expect(pending.values.values, contains('Retained during refresh'));
    h.authorityGate!.complete();
    await tester.pumpAndSettle();
    expect(find.text('Retained during refresh'), findsOneWidget);
    expect(find.textContaining('Not saved:'), findsOneWidget);
    await tester.tap(find.text('Review and retry'));
    await tester.pumpAndSettle();
    expect(h.adapter.body, 'Retained during refresh');
    expect(find.text('Saved'), findsOneWidget);
  });

  testWidgets('session visibility revocation stops pending timers without a mutation', (tester) async {
    final h = _Harness()
      ..userId = 'not-creator'
      ..isOwner = true;
    addTearDown(h.close);
    await _mount(tester, h);
    await tester.enterText(find.byKey(const ValueKey('answer-question-1-participant-1')), 'Before private transition');
    h.adapter.visibility = 'private';
    h.adapter.revision++;
    h.container.invalidate(guidedSessionProvider);
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 700));
    expect(h.adapter.writes, isEmpty);
    expect(find.byKey(const ValueKey('guided-session-read-only-notice')), findsOneWidget);
    final pending = h.container.read(guidedPendingEditsProvider('session-1'));
    expect(pending.state, GuidedSaveState.failed);
    expect(pending.values.values, contains('Before private transition'));
  });

  testWidgets('new session route saves pending text to original session only', (tester) async {
    final h = _Harness();
    addTearDown(h.close);
    final router = await _mount(tester, h);
    await tester.enterText(find.byKey(const ValueKey('answer-question-1-participant-1')), 'Original session edit');
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

  testWidgets('delayed write acknowledgement cannot publish Saved under another UID', (tester) async {
    final h = _Harness();
    addTearDown(h.close);
    await _mount(tester, h);
    h.adapter.holdWrites = true;
    await tester.enterText(find.byKey(const ValueKey('answer-question-1-participant-1')), 'First account edit');
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
  });

  testWidgets('open session export clears on identity change', (tester) async {
    final h = _Harness();
    addTearDown(h.close);
    await _mount(tester, h);
    await tester.tap(find.byTooltip('Export'));
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

  testWidgets('dialog opened by original user cannot mutate after identity switch', (tester) async {
    final h = _Harness();
    addTearDown(h.close);
    await _mount(tester, h);
    await tester.tap(find.text('Shared question'));
    await tester.pumpAndSettle();
    final input = find.byWidgetPredicate(
      (widget) => widget is TextField && widget.decoration?.labelText == 'Question',
    );
    await tester.enterText(input, 'Original user draft');
    h.change('uid');
    await tester.pumpAndSettle();
    expect(find.text('Original user draft'), findsNothing);
    expect(find.text('Add shared question'), findsNothing);
    expect(h.adapter.writes, isEmpty);
    expect(tester.takeException(), isNull);
  });

  for (final actor in ['owner', 'legacy', 'role-only', 'delegate', 'creator']) {
    for (final visibility in ['organisation', 'private']) {
      testWidgets('$actor authority on $visibility session matches backend', (tester) async {
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
        final canEdit = actor == 'creator' ||
            (visibility != 'private' && (actor == 'owner' || actor == 'legacy'));
        expect(find.text('Shared question'), canEdit ? findsOneWidget : findsNothing);
        expect(find.byType(TextField), canEdit ? findsWidgets : findsNothing);
        expect(find.byTooltip('Export'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
    testWidgets('$actor template management uses grants, not role labels', (tester) async {
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

  testWidgets('organisation import warnings remain visible before opening imported session', (tester) async {
    final h = _Harness();
    addTearDown(h.close);
    final router = await _mount(tester, h);
    router.go('/guided/import');
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Import legacy Interact JSON'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '{"meta":{},"participants":[],"flow":[]}');
    await tester.tap(find.text('Import'));
    await tester.pumpAndSettle();
    expect(find.text('Imported with warnings'), findsOneWidget);
    expect(find.text('Missing legacy participant name was replaced.'), findsOneWidget);
    expect(find.text('Organisation session'), findsNothing);
    await tester.tap(find.text('Review session'));
    await tester.pumpAndSettle();
    expect(find.text('Organisation session'), findsOneWidget);
  });

  testWidgets('unsupported guest backup import has a visible failure and no navigation', (tester) async {
    final h = _Harness();
    addTearDown(h.close);
    final router = await _mount(tester, h);
    router.go('/guided/import');
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Import legacy Interact JSON'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '{"sessions":[],"templates":[],"knowledge":[]}');
    await tester.tap(find.text('Import'));
    await tester.pumpAndSettle();
    expect(find.text('Import failed'), findsOneWidget);
    expect(find.textContaining('not a guest workspace backup'), findsOneWidget);
    expect(find.text('Organisation session'), findsNothing);
  });
}

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
      GoRoute(path: '/guided', builder: (_, _) => const Scaffold(body: Text('Session list'))),
      GoRoute(path: '/guided/import', builder: (_, _) => const Scaffold(body: GuidedPage())),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(UncontrolledProviderScope(
    container: h.container,
    child: MaterialApp.router(routerConfig: router),
  ));
  await tester.pumpAndSettle();
  return router;
}

class _Harness {
  _Harness() {
    tokens = _Tokens(() => uid);
    client = createApiClient(tokens, adapter: adapter);
    container = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        apiClientProvider.overrideWithValue(client),
        authStateProvider.overrideWith((ref) => Stream<User?>.multi((controller) {
          controller.add(GuidedTestUser(uid));
          final subscription = events.stream.listen(controller.add);
          controller.onCancel = subscription.cancel;
        })),
        currentMembershipProvider.overrideWith((ref) async {
          await ref.watch(authStateProvider.future);
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

  Future<void> ready() async {
    await container.read(authStateProvider.future);
    await container.read(currentMembershipProvider.future);
    await container.read(organisationProfileProvider.future);
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

  void close() {
    container.dispose();
    client.close();
    events.close();
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
  bool holdReads = false;
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
  Completer<ResponseBody>? readGate;
  Completer<ResponseBody>? writeGate;
  String body = 'Original answer';
  String title = 'What happened?';
  String visibility = 'organisation';
  int revision = 1;
  int revisionStep = 1;
  String secondBody = 'Second session answer';
  String bobBody = 'Bob original answer';

  Map<String, Object?> session({String title = 'Organisation session', String id = 'session-1'}) => {
    'id': id,
    'title': title,
    'created_by': 'db-a',
    'status': 'draft',
    'visibility': visibility,
    'revision': revision,
    'updated_at': '2026-10-07T00:00:00Z',
    'participants': [
      if (!removeParticipant)
        {'id': id == 'session-1' ? 'participant-1' : 'participant-2', 'name': 'Alice'},
      if (id == 'session-1') {'id': 'bob', 'name': 'Bob'},
    ],
    'questions': [if (!removeQuestion) {
      'id': id == 'session-1' ? 'question-1' : 'question-2',
      'text': this.title,
      'scope': 'shared',
      'source': 'manual',
      'answers': [if (!removeAnswer) {
        'id': id == 'session-1' ? 'answer-1' : 'answer-2',
        'question_id': id == 'session-1' ? 'question-1' : 'question-2',
        'participant_id': id == 'session-1' ? 'participant-1' : 'participant-2',
        'body': id == 'session-1' ? body : secondBody,
        'branches_collapsed': collapsed,
      },
      if (id == 'session-1') {
        'id': 'answer-bob',
        'question_id': 'question-1',
        'participant_id': 'bob',
        'body': bobBody,
        'branches_collapsed': false,
      }],
      'follow_ups': [
        if (showFollowUp) {
          'id': 'follow-up-1',
          'text': 'Original follow-up',
          'scope': 'participant',
          'source': 'follow_up',
          'target_participant_id': followUpOwner,
          'triggering_answer_id': followUpOwner == 'bob' ? 'answer-bob' : 'answer-1',
          'answers': [{
            'id': 'follow-answer-1',
            'question_id': 'follow-up-1',
            'participant_id': followUpOwner,
            'body': 'Original follow-up answer',
            'branches_collapsed': false,
          }],
          'follow_ups': [],
        },
      ],
    }],
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
      if (payload.containsKey('sessions')) return _response({'detail': 'Unsupported guest backup'}, status: 409);
      return _response({
        'session': session(),
        'warnings': ['Missing legacy participant name was replaced.'],
      });
    }
    if (options.method != 'GET') {
      writes.add(options);
      if (failWrites) return _response({}, status: 503);
      final expected = options.data['expected_revision'];
      if (expected != null && expected != revision) return _response({}, status: 409);
      if (options.method == 'POST' && options.path.endsWith('/answers')) {
        removeAnswer = false;
      }
      if (options.data['body'] != null) body = options.data['body'] as String;
      if (options.data['branches_collapsed'] != null) {
        collapsed = options.data['branches_collapsed'] as bool;
      }
      if (options.data['text'] != null) title = options.data['text'] as String;
      revision += revisionStep;
      if (failAfterWrite) {
        failAfterWrite = false;
        return _response({}, status: 503);
      }
      if (holdWrites) {
        writeGate ??= Completer<ResponseBody>();
        return writeGate!.future;
      }
      return _response({'session_revision': revision});
    }
    if (options.path.contains('/sessions/session-')) {
      reads.add(options);
      if (holdReads) {
        readGate ??= Completer<ResponseBody>();
        return readGate!.future;
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
                    if ((answer as Map)['participant_id'] == participant) answer,
                ],
                'follow_ups': [
                  for (final followUp in raw['follow_ups'] as List)
                    if ((followUp as Map)['target_participant_id'] == participant) followUp,
                ],
              },
        ];
      }
      return _response(detail);
    }
    if (options.path == '/api/v1/guided/templates' && showTemplate) {
      return _response([{
        'id': 'template-1',
        'name': 'Template',
        'created_by': 'db-a',
        'status': 'active',
        'current_version': 1,
        'questions': [],
      }]);
    }
    return _response([]);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _response(Object? data, {int status = 200}) => ResponseBody.fromString(
  jsonEncode(data),
  status,
  headers: {Headers.contentTypeHeader: ['application/json']},
);

Future<void> _waitFor(bool Function() condition) async {
  for (var attempt = 0; attempt < 200 && !condition(); attempt++) {
    await Future<void>.delayed(const Duration(milliseconds: 1));
  }
  expect(condition(), isTrue);
}
