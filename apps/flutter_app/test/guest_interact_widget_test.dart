import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:int_qa_flow/features/guest/data/guest_storage_interface.dart';
import 'package:int_qa_flow/features/guest/data/guest_workspace_store.dart';
import 'package:int_qa_flow/features/guest/domain/guest_workspace_data.dart';
import 'package:int_qa_flow/features/guest/presentation/guest_workspace_page.dart';

void main() {
  testWidgets('guest workspace heading is compact and subtle', (tester) async {
    _registerGuestCleanup(tester);
    final store = GuestWorkspaceStore(_MemoryGuestStorage());
    await tester.pumpWidget(
      ProviderScope(
        overrides: [guestWorkspaceStoreProvider.overrideWithValue(store)],
        child: const MaterialApp(
          home: GuestWorkspacePage(firebaseReady: false),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('IntQAFlow guest workspace'), findsNothing);
    final heading = find.text('Guest workspace');
    expect(heading, findsOneWidget);
    final label = tester.widget<Text>(heading);
    final context = tester.element(heading);
    expect(label.style?.fontSize, 14);
    expect(label.style?.fontWeight, FontWeight.w400);
    expect(label.style?.color, Theme.of(context).colorScheme.onSurfaceVariant);
    expect(tester.widget<AppBar>(find.byType(AppBar)).toolbarHeight, 48);
    expect(find.byTooltip('Account'), findsOneWidget);
    for (final tooltip in [
      'Workspace storage information',
      'Search help',
      'Interact privacy information',
    ]) {
      expect(
        find.ancestor(
          of: find.byTooltip(tooltip),
          matching: find.byType(AppBar),
        ),
        findsOneWidget,
      );
    }
    expect(find.textContaining('Guest workspace ·'), findsNothing);
    await tester.tap(find.byTooltip('Workspace storage information'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Guest workspace ·'), findsOneWidget);
    expect(find.textContaining('Clearing browser data'), findsOneWidget);
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Interact'));
    await tester.pumpAndSettle();
    final sessionField = tester.widget<TextField>(_field('Session title'));
    expect(sessionField.decoration!.labelText, 'New Interact session');
    expect(
      sessionField.decoration!.floatingLabelBehavior,
      FloatingLabelBehavior.always,
    );
    final participantField = tester.widget<TextField>(_field('Participant'));
    expect(participantField.decoration!.labelText, isNull);
    expect(participantField.decoration!.hintText, 'Participant');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'question dialogs validate cancel and keep actions below new scoped questions',
    (tester) async {
      _registerGuestCleanup(tester);
      tester.view.physicalSize = const Size(1200, 1200);
      tester.view.devicePixelRatio = 1;
      final store = GuestWorkspaceStore(_MemoryGuestStorage());
      await store.save(
        GuestWorkspaceData(sessions: [_twoParticipantSession()]),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [guestWorkspaceStoreProvider.overrideWithValue(store)],
          child: const MaterialApp(
            home: GuestWorkspacePage(
              firebaseReady: false,
              initialWorkspaceTab: 1,
              initialSessionId: 'two-person-session',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(_field('New question'), findsNothing);
      expect(find.byTooltip('Add a question'), findsNothing);
      final addShared = find.text('Add shared question');
      await _ensureVisibleInGuestList(
        tester,
        addShared,
        anchor: _activeParticipantBar,
      );
      await tester.tap(addShared);
      await tester.pumpAndSettle();
      final dialogField = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextFormField),
      );
      await tester.enterText(dialogField, '  ');
      await tester.tap(find.widgetWithText(FilledButton, 'Add question'));
      await tester.pumpAndSettle();
      expect(find.text('Enter a question.'), findsOneWidget);
      expect((await store.load()).sessions.single['questions'], hasLength(2));
      await tester.enterText(dialogField, 'Cancelled draft');
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect((await store.load()).sessions.single['questions'], hasLength(2));
      await tester.tap(addShared);
      await tester.pumpAndSettle();
      await tester.enterText(dialogField, 'New shared question');
      await tester.tap(find.widgetWithText(FilledButton, 'Add question'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 400));
      final questions =
          (await store.load()).sessions.single['questions'] as List;
      final added = questions.last as Map;
      expect(added['scope'], 'shared');
      expect((added['answers'] as List).map((a) => a['participant_id']), [
        'alice-id',
        'bob-id',
      ]);
      final addedField = find.byKey(
        ValueKey('guest-question-text-${added['id']}'),
      );
      await _ensureVisibleInGuestList(
        tester,
        addShared,
        anchor: _activeParticipantBar,
      );
      expect(
        tester.getTopLeft(addShared).dy,
        greaterThan(tester.getBottomLeft(addedField).dy),
      );
      expect(
        find.text('Add question for active participant').hitTestable(),
        findsOneWidget,
      );
      await _selectParticipant(tester, 'Bob');
      final participantAction = find.text(
        'Add question for active participant',
      );
      await _ensureVisibleInGuestList(
        tester,
        participantAction,
        anchor: _activeParticipantBar,
      );
      await tester.tap(participantAction);
      await tester.pumpAndSettle();
      await tester.enterText(dialogField, 'New Bob question');
      await tester.tap(find.widgetWithText(FilledButton, 'Add question'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 400));
      final bob =
          ((await store.load()).sessions.single['questions'] as List).last
              as Map;
      expect(bob['scope'], 'participant');
      expect(bob['target_participant_id'], 'bob-id');
      expect((bob['answers'] as List).single['participant_id'], 'bob-id');
      final bobField = find.byKey(ValueKey('guest-question-text-${bob['id']}'));
      await _ensureVisibleInGuestList(
        tester,
        participantAction,
        anchor: _activeParticipantBar,
      );
      expect(
        tester.getTopLeft(participantAction).dy,
        greaterThan(tester.getBottomLeft(bobField).dy),
      );
      expect(tester.takeException(), isNull);
    },
  );

  for (final width in [360.0, 800.0, 832.0, 1200.0]) {
    testWidgets('session header and inline fields fit ${width}px', (
      tester,
    ) async {
      _registerGuestCleanup(tester);
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      final store = GuestWorkspaceStore(_MemoryGuestStorage());
      final original = _twoParticipantSession();
      await store.save(GuestWorkspaceData(sessions: [original]));
      Future<void> open() async {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        await tester.pumpWidget(
          ProviderScope(
            overrides: [guestWorkspaceStoreProvider.overrideWithValue(store)],
            child: const MaterialApp(
              home: GuestWorkspacePage(
                firebaseReady: false,
                initialWorkspaceTab: 1,
                initialSessionId: 'two-person-session',
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
      }

      await open();
      final title = find.text('Two-person interview');
      final destination = find.text('Destination: Local · this device');
      final pdf = find.text('Download / Share PDF');
      final menu = find.byTooltip('More session actions');
      final destinationControl = find.byKey(
        const ValueKey('guest-session-destination'),
      );
      final pdfControl = find.byKey(const ValueKey('guest-session-pdf-action'));
      expect(
        tester.getSize(destinationControl).height,
        tester.getSize(pdfControl).height,
      );
      expect(tester.getSize(destinationControl).height, 40);
      if (width >= 832) {
        expect(
          (tester.getCenter(destination).dy - tester.getCenter(pdf).dy).abs(),
          lessThan(1),
        );
      }
      // The session list contributes 16px padding on each side.
      if (width >= 832) {
        expect(
          (tester.getCenter(title).dy - tester.getCenter(pdf).dy).abs(),
          lessThan(1),
        );
        expect(
          tester.getCenter(destination).dx,
          greaterThan(tester.getCenter(title).dx),
        );
        expect(tester.getCenter(pdf).dx, lessThan(tester.getCenter(menu).dx));
      } else {
        expect(
          tester.getTopLeft(pdf).dy,
          greaterThan(tester.getTopLeft(title).dy),
        );
      }
      for (final tooltip in [
        'Workspace storage information',
        'Search help',
        'Interact privacy information',
      ]) {
        final icon = tester.widget<Icon>(
          find.descendant(
            of: find.byTooltip(tooltip),
            matching: find.byType(Icon),
          ),
        );
        expect(icon.size, 16);
      }
      final field = find.byKey(
        const ValueKey('guest-question-text-shared-root'),
      );
      await _ensureVisibleInGuestList(
        tester,
        field,
        anchor: _activeParticipantBar,
      );
      expect(
        tester.widget<TextField>(field).decoration?.border,
        isA<OutlineInputBorder>(),
      );
      expect(find.byTooltip('Edit question'), findsNothing);
      final deleteButton = find.byKey(
        const ValueKey('guest-question-delete-shared-root'),
      );
      expect(
        tester.getTopLeft(deleteButton).dx,
        greaterThan(tester.getTopRight(field).dx),
      );
      expect(tester.getTopLeft(deleteButton).dy, tester.getTopLeft(field).dy);
      expect(tester.widget<TextField>(field).decoration?.isDense, isTrue);
      await tester.enterText(field, 'Edited shared question');
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 400));
      final saved = (await store.load()).sessions.single;
      final root = (saved['questions'] as List).first as Map;
      expect(root['text'], 'Edited shared question');
      expect(root['id'], 'shared-root');
      expect(root['answers'], (original['questions'] as List).first['answers']);
      await open();
      await _ensureVisibleInGuestList(
        tester,
        field,
        anchor: _activeParticipantBar,
      );
      expect(
        tester.widget<TextField>(field).controller!.text,
        'Edited shared question',
      );
      expect(tester.takeException(), isNull);
    });
  }

  test('local Knowledge search supports prefixes and one bounded typo', () {
    const item = {
      'title': 'Interaction handover',
      'body': 'Steps for a shift change.',
      'answer': 'Use the approved checklist.',
    };
    expect(matchesGuestKeywordOrPrefix('interact', item), isTrue);
    expect(matchesGuestKeywordOrPrefix('interactoin', item), isTrue);
    expect(matchesGuestKeywordOrPrefix('intrxctoin', item), isFalse);
  });

  test('missing backup collections reports the exact knowledge diagnostic', () {
    expect(
      () => GuestWorkspaceData.decodeBackup('{"schema_version":1}'),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          'Local backup must include a "knowledge" list.',
        ),
      ),
    );
  });

  testWidgets(
    'Saved Q&A search edits and removes local entries and returns to the form',
    (tester) async {
      _registerGuestCleanup(tester);
      final storage = _MemoryGuestStorage();
      final store = GuestWorkspaceStore(storage);
      await store.save(
        const GuestWorkspaceData(
          knowledge: [
            {
              'id': 'password-rotation',
              'title': 'Password rotation',
              'body': 'Rotate keys quarterly.',
              'answer': 'Use the approved vault.',
              'visibility': 'local_guest',
            },
            {
              'id': 'incident-response',
              'title': 'Incident response',
              'body': 'Notify the response lead.',
              'answer': 'Follow the local runbook.',
              'visibility': 'local_guest',
            },
          ],
        ),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [guestWorkspaceStoreProvider.overrideWithValue(store)],
          child: const MaterialApp(
            home: GuestWorkspacePage(firebaseReady: false),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final localSearch = _field('Search Knowledge & Interact');
      expect(localSearch, findsOneWidget);
      expect(
        tester.widget<TextField>(localSearch).decoration!.helperText,
        isNull,
      );
      expect(find.byTooltip('Search help'), findsOneWidget);
      expect(
        tester.getTopLeft(localSearch).dy,
        lessThan(tester.getTopLeft(find.text('Add a local question')).dy),
      );
      expect(find.text('Add a local question'), findsOneWidget);
      expect(find.text('Password rotation'), findsNothing);
      await tester.tap(find.byTooltip('Search help'));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Search local Knowledge on this device and all personal-account '
          'Knowledge in your account, plus authorised organisation and Group '
          'Knowledge when available. Only your query is sent to those services; '
          'local content is never uploaded by search.',
        ),
        findsOneWidget,
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);

      await tester.enterText(localSearch, 'passw');
      await tester.pumpAndSettle();
      expect(find.text('Password rotation'), findsOneWidget);
      expect(find.widgetWithText(Chip, 'Local'), findsOneWidget);
      expect(find.textContaining('Local on this device'), findsOneWidget);
      await tester.tap(find.text('Password rotation'));
      await tester.pumpAndSettle();
      expect(localSearch, findsOneWidget);
      expect(find.text('Password rotation'), findsOneWidget);
      expect(find.text('Incident response'), findsNothing);
      await tester.tap(find.text('Back to all Saved Q&A'));
      await tester.pumpAndSettle();
      expect(find.text('Incident response'), findsNothing);

      await tester.enterText(localSearch, '');
      await tester.pumpAndSettle();
      await _ensureVisibleInGuestList(
        tester,
        find.text('Incident response'),
        anchor: find.text('Saved Q&A'),
      );
      expect(find.text('Password rotation'), findsOneWidget);
      expect(find.text('Incident response'), findsOneWidget);
      final passwordRotationCard = find.ancestor(
        of: find.text('Password rotation'),
        matching: find.byType(Card),
      );
      await tester.tap(
        find.descendant(
          of: passwordRotationCard,
          matching: find.byTooltip('Edit local Knowledge'),
        ),
      );
      await tester.pumpAndSettle();
      final dialogFields = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      );
      await tester.enterText(dialogFields.at(0), '');
      await tester.tap(find.widgetWithText(FilledButton, 'Save locally'));
      await tester.pumpAndSettle();
      expect(find.text('Enter a question.'), findsOneWidget);
      expect(
        tester.widget<TextField>(dialogFields.at(1)).controller!.text,
        'Rotate keys quarterly.',
      );
      expect(
        tester.widget<TextField>(dialogFields.at(0)).focusNode!.hasFocus,
        isTrue,
      );
      await tester.enterText(dialogFields.at(0), 'Rotated guidance');
      await tester.enterText(dialogFields.at(1), 'Updated rotation details.');
      await tester.enterText(dialogFields.at(2), 'Updated vault answer.');
      await tester.tap(find.widgetWithText(FilledButton, 'Save locally'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 300));

      var saved = await store.load();
      final edited = saved.knowledge.singleWhere(
        (item) => item['id'] == 'password-rotation',
      );
      expect(edited['title'], 'Rotated guidance');
      expect(edited['body'], 'Updated rotation details.');
      expect(edited['answer'], 'Updated vault answer.');

      await tester.enterText(localSearch, '');
      await tester.pumpAndSettle();
      final incidentCard = find.ancestor(
        of: find.text('Incident response'),
        matching: find.byType(Card),
      );
      final removeIncident = find.descendant(
        of: incidentCard,
        matching: find.byTooltip('Remove local Knowledge'),
      );
      await tester.ensureVisible(removeIncident);
      await tester.pumpAndSettle();
      await tester.tap(removeIncident);
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 300));
      saved = await store.load();
      expect(saved.knowledge.map((item) => item['id']), ['password-rotation']);

      final backButton = find.text('Back to add a local question');
      await tester.ensureVisible(backButton);
      await tester.pumpAndSettle();
      await tester.tap(backButton);
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.widgetWithText(OutlinedButton, 'Saved Q&A'),
      );
      await tester.pumpAndSettle();
      expect(find.text('Add a local question'), findsOneWidget);
      expect(find.text('Saved Q&A'), findsOneWidget);
      final knowledgeScrollable = find
          .ancestor(
            of: find.text('Add a local question'),
            matching: find.byType(Scrollable),
          )
          .first;
      await tester.scrollUntilVisible(
        localSearch,
        -200,
        scrollable: knowledgeScrollable,
      );
      await tester.pumpAndSettle();
      expect(localSearch, findsOneWidget);
      final questionField = _field('Question');
      final detailsField = _field('Details');
      final answerField = _field('Answer');
      await tester.ensureVisible(questionField);
      await tester.pumpAndSettle();
      await tester.enterText(questionField, 'New local question');
      await tester.ensureVisible(detailsField);
      await tester.pumpAndSettle();
      await tester.enterText(detailsField, 'Details');
      await tester.ensureVisible(answerField);
      await tester.pumpAndSettle();
      await tester.enterText(answerField, 'Answer');
      await tester.drag(find.byType(SnackBar), const Offset(0, 100));
      await tester.pumpAndSettle();
      final saveLocalQuestion = find.widgetWithText(
        FilledButton,
        'Save locally',
      );
      await tester.ensureVisible(saveLocalQuestion);
      await tester.pumpAndSettle();
      await tester.tap(saveLocalQuestion);
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 300));
      saved = await store.load();
      expect(saved.knowledge.map((item) => item['title']), [
        'New local question',
        'Rotated guidance',
      ]);
      expect(storage.read(), isNotEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'deep-linked editor edits follow-up text and guards participant removal',
    (tester) async {
      _registerGuestCleanup(tester);
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      final store = GuestWorkspaceStore(_MemoryGuestStorage());
      await store.save(
        GuestWorkspaceData(sessions: [_twoParticipantSession()]),
      );
      final routes = <String?>[];
      await tester.pumpWidget(
        ProviderScope(
          overrides: [guestWorkspaceStoreProvider.overrideWithValue(store)],
          child: MaterialApp(
            home: GuestWorkspacePage(
              firebaseReady: false,
              initialWorkspaceTab: 1,
              initialSessionId: 'two-person-session',
              onSessionRouteChanged: routes.add,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byTooltip('Back to sessions'), findsWidgets);
      expect(find.text('Destination: Local · this device'), findsOneWidget);
      await _selectParticipant(tester, 'Bob');
      expect(find.textContaining('Active participant: Bob'), findsOneWidget);

      final field = find.byKey(
        const ValueKey('guest-question-text-bob-branch'),
      );
      await _ensureVisibleInGuestList(
        tester,
        field,
        anchor: _activeParticipantBar,
      );
      expect(
        tester.widget<TextField>(field).decoration?.hintText,
        startsWith('e.g.'),
      );
      expect(find.byTooltip('Edit follow-up question'), findsNothing);
      await tester.enterText(field, '   ');
      await tester.pumpAndSettle();
      expect(
        find.text('Enter a question. The last saved text is kept.'),
        findsOneWidget,
      );
      expect(
        ((await store.load()).sessions.single['questions'] as List)
            .first['answers'][1]['follow_ups'][0]['text'],
        'Bob follow-up',
      );
      await tester.enterText(field, 'Bob follow-up, reworded');
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();

      final saved = (await store.load()).sessions.single;
      final shared = (saved['questions'] as List).first as Map;
      expect(shared['id'], 'shared-root');
      expect(shared['text'], 'Shared prompt');
      final bobAnswer =
          (shared['answers'] as List).firstWhere(
                (item) => (item as Map)['participant_id'] == 'bob-id',
              )
              as Map;
      expect(bobAnswer['body'], 'Bob answer');
      final branch = (bobAnswer['follow_ups'] as List).single as Map;
      expect(branch['id'], 'bob-branch');
      expect(branch['text'], 'Bob follow-up, reworded');
      expect(branch['target_participant_id'], 'bob-id');
      expect(
        ((branch['answers'] as List).single as Map)['body'],
        'Bob branch answer',
      );
      final aliceAnswer =
          (shared['answers'] as List).firstWhere(
                (item) => (item as Map)['participant_id'] == 'alice-id',
              )
              as Map;
      expect(aliceAnswer['body'], 'Alice answer');

      final actions = find.byTooltip('Active participant actions');
      await _ensureVisibleInGuestList(
        tester,
        actions,
        anchor: _activeParticipantBar,
      );
      await tester.tap(actions);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove active participant'));
      await tester.pumpAndSettle();
      expect(find.text('Participant cannot be removed'), findsOneWidget);
      expect(find.textContaining('nothing was changed'), findsOneWidget);
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      expect(
        ((await store.load()).sessions.single['participants'] as List).length,
        2,
      );

      await _ensureVisibleInGuestList(
        tester,
        find.byTooltip('Back to sessions'),
        anchor: _activeParticipantBar,
      );
      await tester.tap(find.byTooltip('Back to sessions').first);
      await tester.pumpAndSettle();
      expect(routes.last, isNull);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('empty participant removal is confirmed and can be undone', (
    tester,
  ) async {
    _registerGuestCleanup(tester);
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    final store = GuestWorkspaceStore(_MemoryGuestStorage());
    final session = _twoParticipantSession();
    (session['participants'] as List).add({'id': 'cara-id', 'name': 'Cara'});
    await store.save(GuestWorkspaceData(sessions: [session]));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [guestWorkspaceStoreProvider.overrideWithValue(store)],
        child: const MaterialApp(
          home: GuestWorkspacePage(
            firebaseReady: false,
            initialWorkspaceTab: 1,
            initialSessionId: 'two-person-session',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await _selectParticipant(tester, 'Cara');
    final actions = find.byTooltip('Active participant actions');
    await _ensureVisibleInGuestList(
      tester,
      actions,
      anchor: _activeParticipantBar,
    );
    await tester.tap(actions);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove active participant'));
    await tester.pumpAndSettle();
    expect(find.text('Remove participant?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Remove participant'));
    await tester.pumpAndSettle();
    expect(find.text('Participant removed locally.'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    var participants =
        (await store.load()).sessions.single['participants'] as List;
    expect(participants.map((item) => (item as Map)['id']), [
      'alice-id',
      'bob-id',
    ]);
    await tester.tap(find.text('Undo').hitTestable());
    await tester.pumpAndSettle();
    expect(find.text('Participant restored locally.'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    participants = (await store.load()).sessions.single['participants'] as List;
    expect(participants.map((item) => (item as Map)['id']), [
      'alice-id',
      'bob-id',
      'cara-id',
    ]);
    final shared =
        ((await store.load()).sessions.single['questions'] as List).first
            as Map;
    final bodies = {
      for (final answer in shared['answers'] as List)
        (answer as Map)['participant_id']: answer['body'],
    };
    expect(bodies, {
      'alice-id': 'Alice answer',
      'bob-id': 'Bob answer',
      'cara-id': '',
    });
    expect(tester.takeException(), isNull);
  });

  testWidgets('missing deep-linked session offers a safe return', (
    tester,
  ) async {
    _registerGuestCleanup(tester);
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    final store = GuestWorkspaceStore(_MemoryGuestStorage());
    await store.save(GuestWorkspaceData(sessions: [_twoParticipantSession()]));
    final routes = <String?>[];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [guestWorkspaceStoreProvider.overrideWithValue(store)],
        child: MaterialApp(
          home: GuestWorkspacePage(
            firebaseReady: false,
            initialWorkspaceTab: 1,
            initialSessionId: 'deleted-session',
            onSessionRouteChanged: routes.add,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.textContaining('This session is not available.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Back to sessions').hitTestable().first);
    await tester.pumpAndSettle();
    expect(routes.last, isNull);
    expect(find.text('Two-person interview'), findsWidgets);
    expect(
      (await store.load()).sessions.single['id'],
      'two-person-session',
      reason: 'Opening a missing link never creates or deletes local data.',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('long labels and nested branches fit a narrow guest layout', (
    tester,
  ) async {
    _registerGuestCleanup(tester);
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;

    final store = GuestWorkspaceStore(_MemoryGuestStorage());
    await store.save(GuestWorkspaceData(sessions: [_narrowSession()]));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [guestWorkspaceStoreProvider.overrideWithValue(store)],
        child: const MaterialApp(
          home: GuestWorkspacePage(firebaseReady: false),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Interact').first);
    await tester.pumpAndSettle();
    await _ensureVisibleInGuestList(
      tester,
      find.text('A long session title that should truncate cleanly'),
      anchor: find.text('Create session locally'),
    );
    await tester.tap(
      find.text('A long session title that should truncate cleanly'),
    );
    await tester.pumpAndSettle();

    expect(find.byTooltip('Back to sessions'), findsOneWidget);
    expect(find.text('Destination: Local · this device'), findsOneWidget);
    expect(find.text('Local · saved on this device'), findsOneWidget);
    expect(find.text('Active participant'), findsOneWidget);
    expect(
      find.text(
        'A participant name with enough words to wrap at a narrow mobile width',
      ),
      findsOneWidget,
    );
    final editorAnchor = _activeParticipantBar;
    await _ensureVisibleInGuestList(
      tester,
      find.text('Add shared question'),
      anchor: editorAnchor,
    );
    expect(find.text('Add shared question'), findsOneWidget);
    expect(
      find.text('Add participant question'),
      findsOneWidget,
      reason: 'The narrow action label must fit while preserving its meaning.',
    );
    await _ensureVisibleInGuestList(
      tester,
      find.text('A prepared prompt with a long but readable question label'),
      anchor: editorAnchor,
    );
    expect(find.text('Add follow-up'), findsWidgets);
    await _ensureVisibleInGuestList(
      tester,
      find.text('A nested follow-up question with a deliberately long label 8'),
      anchor: editorAnchor,
    );
    expect(
      find.text('A nested follow-up question with a deliberately long label 8'),
      findsOneWidget,
    );
    expect(
      find.textContaining('Active participant: A participant name'),
      findsOneWidget,
      reason: 'The pinned bar keeps the active participant evident.',
    );
    final compactFollowUpAction = find.byWidgetPredicate(
      (widget) =>
          widget is Tooltip &&
          widget.message == 'Add answer-owned follow-up' &&
          widget.child is IconButton,
    );
    expect(
      compactFollowUpAction,
      findsWidgets,
      reason:
          'Deeply nested answer actions should compact before they overflow.',
    );
    await _ensureVisibleInGuestList(
      tester,
      _activeParticipantSelector,
      anchor: editorAnchor,
    );
    final participantGuidance = tester.widget<DropdownButtonFormField<String>>(
      find.byWidgetPredicate(
        (widget) =>
            widget is DropdownButtonFormField<String> &&
            widget.decoration.labelText == 'Active participant',
      ),
    );
    expect(participantGuidance.decoration.helperText, isNull);
    expect(participantGuidance.decoration.helperMaxLines, isNull);
    final participantHelp = find.byTooltip('Active participant help');
    await _ensureVisibleInGuestList(
      tester,
      participantHelp,
      anchor: editorAnchor,
    );
    expect(participantHelp, findsOneWidget);
    await tester.tap(participantHelp);
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Answers and individual questions are shown for this participant.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'legacy duplicate participant IDs are preserved and not editable',
    (tester) async {
      _registerGuestCleanup(tester);
      final session = <String, dynamic>{
        'id': 'legacy-collision',
        'title': 'Legacy session',
        'participants': [
          {'id': 'duplicate-id', 'name': 'Alice'},
          {'id': 'duplicate-id', 'name': 'Bob'},
        ],
        'questions': [
          {
            'id': 'shared-question',
            'text': 'Existing question',
            'scope': 'shared',
            'answers': [
              {
                'participant_id': 'duplicate-id',
                'body': 'Alice answer',
                'follow_ups': [],
              },
              {
                'participant_id': 'duplicate-id',
                'body': 'Bob answer',
                'follow_ups': [],
              },
            ],
          },
        ],
      };
      final data = GuestWorkspaceData(sessions: [session]);
      final storage = _MemoryGuestStorage();
      final store = GuestWorkspaceStore(storage);
      await store.save(data);
      final savedValue = storage.read();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [guestWorkspaceStoreProvider.overrideWithValue(store)],
          child: const MaterialApp(
            home: GuestWorkspacePage(firebaseReady: false),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Interact').first);
      await tester.pumpAndSettle();
      await _ensureVisibleInGuestList(
        tester,
        find.text('Legacy session'),
        anchor: find.text('Create session locally'),
      );
      await tester.tap(find.text('Legacy session').hitTestable());
      await tester.pumpAndSettle();

      expect(find.textContaining('duplicate participant IDs'), findsOneWidget);
      expect(find.text('Active participant'), findsNothing);
      expect(find.text('New question'), findsNothing);
      expect(find.text('Prepared question'), findsNothing);
      expect(find.text('Download / Share PDF'), findsOneWidget);
      expect((await store.load()).sessions.single, session);
      expect(storage.read(), savedValue);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'desktop guest Knowledge and Interact forms stay readable width',
    (tester) async {
      _registerGuestCleanup(tester);
      tester.view.physicalSize = const Size(1280, 1000);
      tester.view.devicePixelRatio = 1;

      final store = GuestWorkspaceStore(_MemoryGuestStorage());
      await store.save(
        GuestWorkspaceData(
          templates: const [
            {'id': 'template-1', 'name': 'Interview template', 'questions': []},
          ],
        ),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [guestWorkspaceStoreProvider.overrideWithValue(store)],
          child: const MaterialApp(
            home: GuestWorkspacePage(firebaseReady: false),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(_field('Search Knowledge & Interact'), findsOneWidget);
      await tester.tap(find.text('Saved Q&A'));
      await tester.pumpAndSettle();
      expect(
        tester.getSize(_field('Search Knowledge & Interact')).width,
        lessThanOrEqualTo(840),
      );
      await tester.tap(find.text('Back to add a local question'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Interact').first);
      await tester.pumpAndSettle();
      expect(
        find.text(
          'New Interact sessions stay local. '
          'Imported sessions stay in your personal account.',
        ),
        findsNothing,
      );
      await tester.tap(find.byTooltip('Interact privacy information'));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'New sessions stay on this device unless you explicitly import them. '
          'Imported sessions and their edits stay in your personal account; '
          'group sharing is separate.',
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      expect(
        tester.getSize(_field('New Interact session')).width,
        lessThan(1040),
      );
      final templatePicker = find.byWidgetPredicate(
        (widget) =>
            widget is DropdownButtonFormField<String?> &&
            widget.decoration.labelText == 'Optional template',
      );
      expect(tester.getSize(templatePicker).width, lessThanOrEqualTo(1040));
    },
  );

  testWidgets(
    'switching active participants keeps answers and targeted branches after reload',
    (tester) async {
      _registerGuestCleanup(tester);
      tester.view.physicalSize = const Size(1200, 1200);
      tester.view.devicePixelRatio = 1;

      final storage = _MemoryGuestStorage();
      final store = GuestWorkspaceStore(storage);
      await store.save(
        GuestWorkspaceData(sessions: [_twoParticipantSession()]),
      );

      Future<void> showWorkspace() async {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        await tester.pumpWidget(
          ProviderScope(
            overrides: [guestWorkspaceStoreProvider.overrideWithValue(store)],
            child: const MaterialApp(
              home: GuestWorkspacePage(firebaseReady: false),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Interact').first);
        await tester.pumpAndSettle();
        await _ensureVisibleInGuestList(
          tester,
          find.text('Two-person interview'),
          anchor: find.text('Create session locally'),
        );
        await tester.tap(find.text('Two-person interview').hitTestable());
        await tester.pumpAndSettle();
      }

      await showWorkspace();
      expect(find.byTooltip('Active participant help'), findsOneWidget);
      expect(find.byTooltip('Question help'), findsOneWidget);
      expect(find.text('Prepared question'), findsNothing);
      expect(find.byTooltip('Prepared question help'), findsNothing);
      await _ensureVisibleInGuestList(
        tester,
        find.byTooltip('Question help'),
        anchor: find.byTooltip('Back to sessions'),
      );
      await tester.tap(find.byTooltip('Question help').hitTestable());
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Shared questions get separate answers from each '
          'participant. Participant questions are asked only of '
          'the active participant. Templates are optional.',
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      expect(_answerField(tester).controller!.text, 'Alice answer');
      await _ensureVisibleInGuestList(
        tester,
        find.text(_editorFooter),
        anchor: find.byTooltip('Back to sessions'),
      );
      expect(find.text('Bob-only question'), findsNothing);

      await _selectParticipant(tester, 'Bob');
      expect(_answerField(tester).controller!.text, 'Bob answer');
      expect(find.text('Bob follow-up'), findsOneWidget);
      await _ensureVisibleInGuestList(
        tester,
        find.text('Bob-only question'),
        anchor: _activeParticipantBar,
      );

      await _ensureVisibleInGuestList(
        tester,
        find.text('Add question for active participant'),
        anchor: _activeParticipantBar,
      );
      await tester.tap(find.text('Add question for active participant'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(TextFormField),
        ),
        'Bob-only addition',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Add question'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 300));
      final saved = await store.load();
      final savedQuestions = saved.sessions.single['questions'] as List;
      final added = savedQuestions.cast<Map<String, dynamic>>().singleWhere(
        (question) => question['text'] == 'Bob-only addition',
      );
      expect(added['scope'], 'participant');
      expect(added['target_participant_id'], 'bob-id');

      await _selectParticipant(tester, 'Alice');
      expect(_answerField(tester).controller!.text, 'Alice answer');
      await _ensureVisibleInGuestList(
        tester,
        find.text(_editorFooter),
        anchor: _activeParticipantBar,
      );
      expect(find.text('Bob-only addition'), findsNothing);
      await _selectParticipant(tester, 'Bob');
      await _ensureVisibleInGuestList(
        tester,
        find.text('Bob-only addition'),
        anchor: _activeParticipantBar,
      );

      await showWorkspace();
      await _selectParticipant(tester, 'Bob');
      expect(_answerField(tester).controller!.text, 'Bob answer');
      expect(find.text('Bob follow-up'), findsOneWidget);
      await _ensureVisibleInGuestList(
        tester,
        find.text('Bob-only addition'),
        anchor: _activeParticipantBar,
      );
    },
  );

  testWidgets('PDF report preview uses the active participant scope', (
    tester,
  ) async {
    _registerGuestCleanup(tester);
    tester.view.physicalSize = const Size(1200, 1200);
    tester.view.devicePixelRatio = 1;

    final store = GuestWorkspaceStore(_MemoryGuestStorage());
    await store.save(GuestWorkspaceData(sessions: [_twoParticipantSession()]));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [guestWorkspaceStoreProvider.overrideWithValue(store)],
        child: const MaterialApp(
          home: GuestWorkspacePage(firebaseReady: false),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Interact').first);
    await tester.pumpAndSettle();
    await _ensureVisibleInGuestList(
      tester,
      find.text('Two-person interview'),
      anchor: find.text('Create session locally'),
    );
    await tester.tap(find.text('Two-person interview'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Download / Share PDF'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Selected participant'));
    await tester.pumpAndSettle();

    final preview = find.ancestor(
      of: find.text('Preview PDF'),
      matching: find.byType(AlertDialog),
    );
    expect(preview, findsOneWidget);
    expect(
      find.descendant(of: preview, matching: find.text('Alice answer')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: preview, matching: find.text('Bob answer')),
      findsNothing,
    );
    expect(
      find.descendant(of: preview, matching: find.text('Share PDF')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: preview, matching: find.text('Download PDF')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: preview,
        matching: find.text('Browser print / Save PDF'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: preview,
        matching: find.textContaining(
          'Download PDF saves a file directly. Browser print opens a separate report',
        ),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: preview,
        matching: find.textContaining(
          'If the bundled font lacks a character, direct PDF is skipped',
        ),
      ),
      findsOneWidget,
    );
    await tester.tap(
      find.descendant(of: preview, matching: find.text('Close')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Preview PDF'), findsNothing);
  });

  testWidgets('local JSON backup import previews and merges selected items', (
    tester,
  ) async {
    _registerGuestCleanup(tester);
    tester.view.physicalSize = const Size(1000, 1000);
    tester.view.devicePixelRatio = 1;

    final store = GuestWorkspaceStore(_MemoryGuestStorage());
    await store.save(
      const GuestWorkspaceData(
        knowledge: [
          {'id': 'same-id', 'title': 'Keep existing copy'},
        ],
      ),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [guestWorkspaceStoreProvider.overrideWithValue(store)],
        child: const MaterialApp(
          home: GuestWorkspacePage(firebaseReady: false),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Guest workspace options'));
    await tester.pumpAndSettle();
    expect(find.text('Copy local JSON backup'), findsOneWidget);
    await tester.tap(find.text('Import local JSON backup'));
    await tester.pumpAndSettle();
    await tester.enterText(
      _field('Paste backup JSON'),
      const GuestWorkspaceData(
        knowledge: [
          {'id': 'same-id', 'title': 'Backup duplicate'},
          {'id': 'new-id', 'title': 'New backup item'},
        ],
      ).encodeBackup(),
    );
    await tester.tap(find.text('Preview import'));
    await tester.pumpAndSettle();
    expect(find.text('Preview local backup import'), findsOneWidget);
    expect(
      find.text(
        'Selected items are added locally. Existing items with matching IDs are kept unchanged.',
      ),
      findsOneWidget,
    );
    expect(
      tester
          .widget<CheckboxListTile>(
            find.ancestor(
              of: find.text('New backup item'),
              matching: find.byType(CheckboxListTile),
            ),
          )
          .value,
      isTrue,
    );
    await tester.tap(find.text('Import selected locally'));
    await tester.pumpAndSettle();

    final saved = await store.load();
    expect(saved.knowledge.map((item) => item['title']), [
      'Keep existing copy',
      'New backup item',
    ]);
  });

  testWidgets('incompatible backup shows diagnostics without import success', (
    tester,
  ) async {
    _registerGuestCleanup(tester);
    final storage = _MemoryGuestStorage();
    final store = GuestWorkspaceStore(storage);
    await store.save(
      const GuestWorkspaceData(
        knowledge: [
          {'id': 'original', 'title': 'Keep original'},
        ],
      ),
    );
    final original = await store.load();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [guestWorkspaceStoreProvider.overrideWithValue(store)],
        child: const MaterialApp(
          home: GuestWorkspacePage(firebaseReady: false),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Guest workspace options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Import local JSON backup'));
    await tester.pumpAndSettle();
    await tester.enterText(_field('Paste backup JSON'), '{"schema_version":1}');
    expect(
      tester.widget<TextField>(_field('Paste backup JSON')).controller!.text,
      '{"schema_version":1}',
    );
    await tester.tap(find.text('Preview import'));
    await tester.pump();
    expect(tester.takeException(), isNull);
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Local backup must include a "knowledge" list.'),
      findsOneWidget,
    );
    expect(
      find.widgetWithText(
        SnackBar,
        'This is not a valid IntQAFlow local JSON backup. '
        'Local backup must include a "knowledge" list.',
      ),
      findsOneWidget,
    );
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('Preview local backup import'), findsNothing);
    expect(find.text('Selected backup items imported locally.'), findsNothing);
    expect((await store.load()).toJson(), original.toJson());
    await tester.tap(find.byTooltip('Guest workspace options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Import local JSON backup'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(_field('Paste backup JSON')).controller!.text,
      '{"schema_version":1}',
    );
    await tester.tap(find.text('Cancel'));
    await tester.pump();
    expect(tester.takeException(), isNull);
    await tester.pumpAndSettle();
    expect((await store.load()).toJson(), original.toJson());
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'failed local save preserves the latest work for explicit retry',
    (tester) async {
      _registerGuestCleanup(tester);
      final storage = _MemoryGuestStorage()..failWrites = true;
      final store = GuestWorkspaceStore(storage);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [guestWorkspaceStoreProvider.overrideWithValue(store)],
          child: const MaterialApp(
            home: GuestWorkspacePage(firebaseReady: false),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(_field('Question'), 'Kept after failure');
      final saveButton = find.widgetWithText(FilledButton, 'Save locally');
      await tester.ensureVisible(saveButton);
      await tester.pumpAndSettle();
      await tester.tap(saveButton);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      expect(
        find.text('Your changes are not saved. Keep this page open and retry.'),
        findsOneWidget,
      );
      expect(find.textContaining('secret-password'), findsNothing);
      expect((await store.load()).knowledge, isEmpty);
      expect(storage.value, isNull);
      expect(
        tester.widget<TextField>(_field('Question')).focusNode!.hasFocus,
        isFalse,
      );
      expect(tester.takeException(), isNull);

      await tester.enterText(_field('Question'), 'Latest work after failure');
      await _ensureVisibleInGuestList(
        tester,
        saveButton,
        anchor: _field('Question'),
      );
      await tester.tap(saveButton);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      expect(storage.value, isNull);
      expect(
        find.text('Your changes are not saved. Keep this page open and retry.'),
        findsOneWidget,
      );

      storage.failWrites = false;
      await tester.tap(find.text('Retry saving'));
      await tester.pumpAndSettle();

      expect((await store.load()).knowledge.map((item) => item['title']), [
        'Latest work after failure',
        'Kept after failure',
      ]);
      expect(
        find.text('Your changes are not saved. Keep this page open and retry.'),
        findsNothing,
      );
      await tester.tap(find.byTooltip('Workspace storage information'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Saved on this device'), findsOneWidget);
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('queued local work is persisted when the page is disposed', (
    tester,
  ) async {
    _registerGuestCleanup(tester);
    final storage = _MemoryGuestStorage();
    final store = GuestWorkspaceStore(storage);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [guestWorkspaceStoreProvider.overrideWithValue(store)],
        child: const MaterialApp(
          home: GuestWorkspacePage(firebaseReady: false),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(_field('Question'), 'Saved while leaving');
    final saveButton = find.widgetWithText(FilledButton, 'Save locally');
    await tester.ensureVisible(saveButton);
    await tester.pumpAndSettle();
    await tester.tap(saveButton);
    expect(storage.value, isNull);
    expect(storage.writeAttempts, 0);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();

    expect(
      (await store.load()).knowledge.single['title'],
      'Saved while leaving',
    );
    expect(storage.writeAttempts, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('in-flight local save completes after the page is disposed', (
    tester,
  ) async {
    _registerGuestCleanup(tester);
    final storage = _MemoryGuestStorage();
    await GuestWorkspaceStore(storage).save(const GuestWorkspaceData());
    final store = _DelayedFirstSaveStore(storage);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [guestWorkspaceStoreProvider.overrideWithValue(store)],
        child: const MaterialApp(
          home: GuestWorkspacePage(firebaseReady: false),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(_field('Question'), 'In-flight work');
    final saveButton = find.widgetWithText(FilledButton, 'Save locally');
    await tester.ensureVisible(saveButton);
    await tester.pumpAndSettle();
    await tester.tap(saveButton);
    await tester.pump(const Duration(milliseconds: 300));
    await store.firstWriteStarted.future;
    await tester.pumpWidget(const SizedBox.shrink());
    store.releaseFirstWrite();
    await tester.pumpAndSettle();

    expect((await store.load()).knowledge.single['title'], 'In-flight work');
  });

  testWidgets(
    'failed local save still allows backup copy with accurate status',
    (tester) async {
      _registerGuestCleanup(tester);
      final storage = _MemoryGuestStorage()..failWrites = true;
      final store = GuestWorkspaceStore(storage);
      String? copiedText;
      var failClipboard = false;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
            if (call.method == 'Clipboard.setData') {
              if (failClipboard) {
                throw PlatformException(code: 'clipboard-unavailable');
              }
              copiedText = (call.arguments as Map)['text'] as String;
            }
            return null;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [guestWorkspaceStoreProvider.overrideWithValue(store)],
          child: const MaterialApp(
            home: GuestWorkspacePage(firebaseReady: false),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(_field('Question'), 'Rescue this work');
      final saveButton = find.widgetWithText(FilledButton, 'Save locally');
      await tester.ensureVisible(saveButton);
      await tester.pumpAndSettle();
      await tester.tap(saveButton);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      await tester.enterText(_field('Question'), 'Latest rescue work');
      await _ensureVisibleInGuestList(
        tester,
        saveButton,
        anchor: _field('Question'),
      );
      await tester.tap(saveButton);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Guest workspace options'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Copy local JSON backup'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Copy backup'));
      await tester.pumpAndSettle();
      expect(
        GuestWorkspaceData.decodeBackup(
          copiedText!,
        ).knowledge.map((item) => item['title']).toList(),
        ['Latest rescue work', 'Rescue this work'],
      );
      expect(
        find.textContaining(
          'copied to clipboard. Local changes are still not saved',
        ),
        findsOneWidget,
      );
      expect(
        find.text('Your changes are not saved. Keep this page open and retry.'),
        findsOneWidget,
      );

      failClipboard = true;
      await tester.tap(find.byTooltip('Guest workspace options'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Copy local JSON backup'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Copy backup'));
      await tester.pumpAndSettle();
      expect(
        find.text('Unable to copy the local JSON backup.'),
        findsOneWidget,
      );
      expect(find.text('Local JSON backup copied to clipboard.'), findsNothing);
      expect(
        find.text('Your changes are not saved. Keep this page open and retry.'),
        findsOneWidget,
      );
    },
  );

  testWidgets('failed backup import preserves source and current local data', (
    tester,
  ) async {
    _registerGuestCleanup(tester);
    tester.view.physicalSize = const Size(1000, 1000);
    tester.view.devicePixelRatio = 1;
    final storage = _MemoryGuestStorage();
    final store = GuestWorkspaceStore(storage);
    await store.save(
      const GuestWorkspaceData(
        knowledge: [
          {'id': 'existing', 'title': 'Existing local item'},
        ],
      ),
    );
    final existingStoredValue = storage.value;
    final backup = const GuestWorkspaceData(
      knowledge: [
        {'id': 'new', 'title': 'New backup item'},
      ],
    ).encodeBackup();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [guestWorkspaceStoreProvider.overrideWithValue(store)],
        child: const MaterialApp(
          home: GuestWorkspacePage(firebaseReady: false),
        ),
      ),
    );
    await tester.pumpAndSettle();
    storage.failWrites = true;
    await tester.tap(find.byTooltip('Guest workspace options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Import local JSON backup'));
    await tester.pumpAndSettle();
    await tester.enterText(_field('Paste backup JSON'), backup);
    await tester.tap(find.text('Preview import'));
    await tester.pump();
    expect(tester.takeException(), isNull);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Import selected locally'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Unable to import the selected backup. Your current work was kept.',
      ),
      findsOneWidget,
    );
    expect(storage.value, existingStoredValue);
    expect(
      (await store.load()).knowledge.single['title'],
      'Existing local item',
    );
    expect(find.text('Selected backup items imported locally.'), findsNothing);
    expect(find.textContaining('secret-password'), findsNothing);
    await tester.drag(find.byType(SnackBar), const Offset(0, 100));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Unable to import the selected backup. Your current work was kept.',
      ),
      findsNothing,
    );
    await tester.tap(find.text('Saved Q&A'));
    await tester.pumpAndSettle();
    expect(find.text('Existing local item'), findsOneWidget);
    expect(find.text('New backup item'), findsNothing);

    await tester.tap(find.byTooltip('Guest workspace options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Import local JSON backup'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(_field('Paste backup JSON')).controller!.text,
      backup,
    );
    storage.failWrites = false;
    await tester.tap(find.text('Preview import'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Import selected locally'));
    await tester.pumpAndSettle();
    expect((await store.load()).knowledge.map((item) => item['title']), [
      'Existing local item',
      'New backup item',
    ]);
    expect(find.text('Existing local item'), findsOneWidget);
    expect(find.text('New backup item'), findsOneWidget);
    expect(
      find.text('Selected backup items imported locally.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'backup input can close and unmount during its reverse transition',
    (tester) async {
      _registerGuestCleanup(tester);
      final storage = _MemoryGuestStorage();
      final store = GuestWorkspaceStore(storage);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [guestWorkspaceStoreProvider.overrideWithValue(store)],
          child: const MaterialApp(
            home: GuestWorkspacePage(firebaseReady: false),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Guest workspace options'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Import local JSON backup'));
      await tester.pumpAndSettle();
      await tester.enterText(
        _field('Paste backup JSON'),
        '{"schema_version":1}',
      );
      await tester.tap(find.text('Cancel'));
      await tester.pump();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      expect(storage.value, isNull);
      expect(storage.writeAttempts, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('a stale save completion never reports newer edits as saved', (
    tester,
  ) async {
    _registerGuestCleanup(tester);
    final storage = _MemoryGuestStorage();
    await GuestWorkspaceStore(storage).save(const GuestWorkspaceData());
    final store = _DelayedFirstSaveStore(storage);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [guestWorkspaceStoreProvider.overrideWithValue(store)],
        child: const MaterialApp(
          home: GuestWorkspacePage(firebaseReady: false),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(_field('Question'), 'First change');
    final saveButton = find.widgetWithText(FilledButton, 'Save locally');
    await tester.ensureVisible(saveButton);
    await tester.pumpAndSettle();
    await tester.tap(saveButton);
    await tester.pump(const Duration(milliseconds: 300));
    await store.firstWriteStarted.future;

    await tester.enterText(_field('Question'), 'Latest change');
    await tester.tap(saveButton);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byTooltip('Workspace storage information'));
    await tester.pump();
    expect(find.textContaining('Saving locally…'), findsOneWidget);
    await tester.tap(find.text('Close'));
    await tester.pump();

    store.releaseFirstWrite();
    await tester.pumpAndSettle();
    final saved = await store.load();
    expect(saved.knowledge.map((item) => item['title']), [
      'Latest change',
      'First change',
    ]);
    expect(store.writeSnapshots.last, ['Latest change', 'First change']);
    await tester.tap(find.byTooltip('Workspace storage information'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Saved on this device'), findsOneWidget);
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
  });

  testWidgets(
    'corrupt local data is preserved and the initial load can retry',
    (tester) async {
      _registerGuestCleanup(tester);
      final storage = _MemoryGuestStorage();
      final store = GuestWorkspaceStore(storage);
      await store.save(
        const GuestWorkspaceData(
          knowledge: [
            {'id': 'recoverable', 'title': 'Recoverable item'},
          ],
        ),
      );
      final validStoredValue = storage.value!;
      storage.value = '{corrupt local data';
      await tester.pumpWidget(
        ProviderScope(
          overrides: [guestWorkspaceStoreProvider.overrideWithValue(store)],
          child: const MaterialApp(
            home: GuestWorkspacePage(firebaseReady: false),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.textContaining('stored copy was not changed'),
        findsOneWidget,
      );
      expect(find.text('Retry loading'), findsOneWidget);
      expect(storage.value, '{corrupt local data');
      storage.value = validStoredValue;
      await tester.tap(find.text('Retry loading'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Saved Q&A'));
      await tester.pumpAndSettle();

      expect(find.text('Recoverable item'), findsOneWidget);
      expect(
        (await store.load()).knowledge.single['title'],
        'Recoverable item',
      );
    },
  );

  testWidgets('local read failure retains storage and exposes retry', (
    tester,
  ) async {
    _registerGuestCleanup(tester);
    final storage = _MemoryGuestStorage();
    final store = GuestWorkspaceStore(storage);
    await store.save(
      const GuestWorkspaceData(
        knowledge: [
          {'id': 'kept', 'title': 'Kept item'},
        ],
      ),
    );
    final originalValue = storage.value;
    storage.failReads = true;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [guestWorkspaceStoreProvider.overrideWithValue(store)],
        child: const MaterialApp(
          home: GuestWorkspacePage(firebaseReady: false),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('stored copy was not changed'), findsOneWidget);
    expect(find.text('Retry loading'), findsOneWidget);
    expect(storage.value, originalValue);
    storage.failReads = false;
    await tester.tap(find.text('Retry loading'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Saved Q&A'));
    await tester.pumpAndSettle();

    expect(find.text('Kept item'), findsOneWidget);
    expect(storage.value, originalValue);
  });

  testWidgets('required Knowledge and session fields show inline errors', (
    tester,
  ) async {
    _registerGuestCleanup(tester);
    final store = GuestWorkspaceStore(_MemoryGuestStorage());
    await tester.pumpWidget(
      ProviderScope(
        overrides: [guestWorkspaceStoreProvider.overrideWithValue(store)],
        child: const MaterialApp(
          home: GuestWorkspacePage(firebaseReady: false),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final knowledgeSave = find.widgetWithText(FilledButton, 'Save locally');
    await tester.ensureVisible(knowledgeSave);
    await tester.pumpAndSettle();
    await tester.tap(knowledgeSave);
    await tester.pumpAndSettle();
    expect(find.text('Enter a question.'), findsOneWidget);
    expect(
      tester.widget<TextField>(_field('Question')).focusNode!.hasFocus,
      isTrue,
    );
    await tester.enterText(_field('Question'), '  ');
    await tester.tap(knowledgeSave);
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(_field('Question')).controller!.text, '  ');
    expect(find.text('Enter a question.'), findsOneWidget);
    expect((await store.load()).knowledge, isEmpty);

    await tester.tap(find.text('Interact').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create session locally'));
    await tester.pumpAndSettle();
    expect(find.text('Enter a session title.'), findsOneWidget);
    await tester.enterText(_field('New Interact session'), 'Interview');
    await tester.enterText(_field('Participant'), '');
    await tester.tap(find.text('Create session locally'));
    await tester.pumpAndSettle();
    expect(find.text('Enter a participant name.'), findsOneWidget);
    await tester.enterText(_field('Participant'), 'Alice');
    await tester.tap(find.text('Create session locally'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 300));
    expect((await store.load()).sessions.single['title'], 'Interview');
  });
}

void _registerGuestCleanup(WidgetTester tester) {
  addTearDown(() async {
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    // Reset view metrics only after MediaQuery and editable fields unmount.
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

Finder _field(String label) => find.byWidgetPredicate(
  (widget) =>
      widget is TextField &&
      (widget.decoration?.labelText == label ||
          widget.decoration?.hintText == label),
);

const _pinnedHeaderClearance = 120.0;
const _editorFooter = 'Changes are saved to this device as you type.';

Future<void> _ensureVisibleInGuestList(
  WidgetTester tester,
  Finder target, {
  required Finder anchor,
}) async {
  final verticalAncestors = find
      .ancestor(of: anchor, matching: find.byType(Scrollable))
      .evaluate()
      .where((element) {
        final finder = find.byElementPredicate(
          (candidate) => identical(candidate, element),
        );
        return tester.widget<Scrollable>(finder).axisDirection ==
            AxisDirection.down;
      })
      .toList();
  expect(verticalAncestors, isNotEmpty);
  verticalAncestors.sort((first, second) {
    final firstFinder = find.byElementPredicate(
      (element) => identical(element, first),
    );
    final secondFinder = find.byElementPredicate(
      (element) => identical(element, second),
    );
    return tester
        .state<ScrollableState>(firstFinder)
        .position
        .viewportDimension
        .compareTo(
          tester
              .state<ScrollableState>(secondFinder)
              .position
              .viewportDimension,
        );
  });
  final outerVerticalScrollable = verticalAncestors.last;
  final scrollable = find.byElementPredicate(
    (element) => identical(element, outerVerticalScrollable),
  );
  expect(
    tester.widget<Scrollable>(scrollable).axisDirection,
    AxisDirection.down,
  );
  final position = tester.state<ScrollableState>(scrollable).position;
  var restartedFromTop = false;
  for (var attempt = 0; attempt < 80; attempt++) {
    await tester.pumpAndSettle();
    if (target.evaluate().isNotEmpty) {
      if (target.hitTestable().evaluate().isNotEmpty) return;
      final targetRect = tester.getRect(target);
      final listRect = tester.getRect(scrollable);
      var delta = targetRect.bottom > listRect.bottom
          ? targetRect.bottom - listRect.bottom
          : targetRect.top < listRect.top
          ? targetRect.top - listRect.top
          : 0.0;
      if (delta == 0) {
        // Inside the viewport but covered, e.g. by a pinned editor header:
        // move it lower so it is clear of anything pinned at the top.
        delta = targetRect.top - listRect.top - _pinnedHeaderClearance;
        if (delta >= 0 || position.pixels <= position.minScrollExtent) break;
      }
      position.jumpTo(
        (position.pixels + delta)
            .clamp(position.minScrollExtent, position.maxScrollExtent)
            .toDouble(),
      );
      continue;
    }
    if (position.pixels >= position.maxScrollExtent) {
      // Lazily built targets may be above the current offset: rescan once
      // from the top before failing.
      if (restartedFromTop) break;
      restartedFromTop = true;
      position.jumpTo(position.minScrollExtent);
      continue;
    }
    position.jumpTo(
      (position.pixels + 180)
          .clamp(position.minScrollExtent, position.maxScrollExtent)
          .toDouble(),
    );
  }
  expect(target.hitTestable(), findsOneWidget);
}

TextField _answerField(WidgetTester tester) =>
    tester.widget<TextField>(_field('Local answer').first);

final _activeParticipantBar = find.byKey(
  const ValueKey('guest-active-participant-bar'),
);

final _activeParticipantSelector = find.byWidgetPredicate(
  (widget) =>
      widget is DropdownButtonFormField<String> &&
      widget.decoration.labelText == 'Active participant',
);

Future<void> _selectParticipant(WidgetTester tester, String name) async {
  final selector = _activeParticipantSelector;
  await _ensureVisibleInGuestList(
    tester,
    selector,
    anchor: _activeParticipantBar,
  );
  await tester.tap(selector);
  await tester.pumpAndSettle();
  await tester.tap(find.text(name).last);
  await tester.pumpAndSettle();
}

Map<String, dynamic> _twoParticipantSession() => {
  'id': 'two-person-session',
  'title': 'Two-person interview',
  'visibility': 'private_local',
  'participants': [
    {'id': 'alice-id', 'name': 'Alice'},
    {'id': 'bob-id', 'name': 'Bob'},
  ],
  'questions': [
    {
      'id': 'shared-root',
      'text': 'Shared prompt',
      'scope': 'shared',
      'answers': [
        {
          'participant_id': 'alice-id',
          'body': 'Alice answer',
          'follow_ups': [],
        },
        {
          'participant_id': 'bob-id',
          'body': 'Bob answer',
          'follow_ups': [
            {
              'id': 'bob-branch',
              'text': 'Bob follow-up',
              'scope': 'participant',
              'target_participant_id': 'bob-id',
              'answers': [
                {
                  'participant_id': 'bob-id',
                  'body': 'Bob branch answer',
                  'follow_ups': [],
                },
              ],
            },
          ],
        },
      ],
    },
    {
      'id': 'bob-root',
      'text': 'Bob-only question',
      'scope': 'participant',
      'target_participant_id': 'bob-id',
      'answers': [
        {'participant_id': 'bob-id', 'body': '', 'follow_ups': []},
      ],
    },
  ],
};

Map<String, dynamic> _narrowSession() {
  Map<String, dynamic> branch(int depth) => {
    'id': 'branch-$depth',
    'text': 'A nested follow-up question with a deliberately long label $depth',
    'scope': 'participant',
    'target_participant_id': 'long-name',
    'answers': [
      {
        'participant_id': 'long-name',
        'body': 'Answer $depth',
        'follow_ups': depth == 8 ? [] : [branch(depth + 1)],
      },
    ],
  };
  return {
    'id': 'narrow-session',
    'title': 'A long session title that should truncate cleanly',
    'participants': [
      {
        'id': 'long-name',
        'name':
            'A participant name with enough words to wrap at a narrow mobile width',
      },
    ],
    'questions': [
      {
        'id': 'narrow-root',
        'text': 'A prepared prompt with a long but readable question label',
        'scope': 'shared',
        'answers': [
          {
            'participant_id': 'long-name',
            'body': 'Local answer',
            'follow_ups': [branch(1)],
          },
        ],
      },
    ],
  };
}

class _MemoryGuestStorage implements GuestStorage {
  String? value;
  bool failWrites = false;
  bool failReads = false;
  int writeAttempts = 0;

  @override
  void remove() => value = null;

  @override
  String? read() {
    if (failReads) throw StateError('secret-password storage read failure');
    return value;
  }

  @override
  void write(String value) {
    writeAttempts++;
    if (failWrites) throw StateError('secret-password storage failure');
    this.value = value;
  }
}

class _DelayedFirstSaveStore extends GuestWorkspaceStore {
  _DelayedFirstSaveStore(super.storage);

  final firstWriteStarted = Completer<void>();
  final _firstWriteGate = Completer<void>();
  final writeSnapshots = <List<String>>[];

  @override
  Future<void> save(GuestWorkspaceData data) async {
    writeSnapshots.add(
      data.knowledge.map((item) => item['title'] as String).toList(),
    );
    if (writeSnapshots.length == 1) {
      firstWriteStarted.complete();
      await _firstWriteGate.future;
    }
    await super.save(data);
  }

  void releaseFirstWrite() => _firstWriteGate.complete();
}
