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
  testWidgets(
    'Saved Q&A search edits and removes local entries and returns to the form',
    (tester) async {
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

      final localSearch = _field('Search local Knowledge');
      expect(localSearch, findsOneWidget);
      expect(tester.widget<TextField>(localSearch).decoration!.helperText, isNull);
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
          'Keyword and prefix search on this device; no semantic search.',
        ),
        findsOneWidget,
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);

      await tester.enterText(localSearch, 'passw');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Saved Q&A'));
      await tester.pumpAndSettle();
      expect(localSearch, findsOneWidget);
      expect(find.text('Password rotation'), findsOneWidget);
      expect(find.text('Incident response'), findsNothing);

      await tester.enterText(localSearch, '');
      await tester.pumpAndSettle();
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
      expect(
        saved.knowledge.map((item) => item['title']),
        ['New local question', 'Rotated guidance'],
      );
      expect(storage.read(), isNotEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('long labels and nested branches fit a narrow guest layout', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final store = GuestWorkspaceStore(_MemoryGuestStorage());
    await store.save(
      GuestWorkspaceData(
        sessions: [_narrowSession()],
      ),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          guestWorkspaceStoreProvider.overrideWithValue(store),
        ],
        child: const MaterialApp(
          home: GuestWorkspacePage(firebaseReady: false),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Interact').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('A long session title that should truncate cleanly'));
    await tester.pumpAndSettle();

    expect(find.text('Active participant'), findsOneWidget);
    expect(find.text('Add shared question'), findsOneWidget);
    expect(find.text('Add follow-up'), findsWidgets);
    expect(
      find.text('Add participant question'),
      findsOneWidget,
      reason: 'The narrow action label must fit while preserving its meaning.',
    );
    expect(
      find.text(
        'A participant name with enough words to wrap at a narrow mobile width',
      ),
      findsOneWidget,
    );
    expect(
      find.text('A nested follow-up question with a deliberately long label 8'),
      findsOneWidget,
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
      reason: 'Deeply nested answer actions should compact before they overflow.',
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
    expect(participantHelp, findsOneWidget);
    await tester.ensureVisible(participantHelp);
    await tester.pumpAndSettle();
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

  testWidgets('legacy duplicate participant IDs are preserved and not editable', (
    tester,
  ) async {
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
    await tester.tap(find.text('Legacy session'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('duplicate participant IDs'),
      findsOneWidget,
    );
    expect(find.text('Active participant'), findsNothing);
    expect(find.text('Prepared question'), findsNothing);
    expect(find.text('Download / Share PDF'), findsOneWidget);
    expect((await store.load()).sessions.single, session);
    expect(storage.read(), savedValue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('desktop guest Knowledge and Interact forms stay readable width', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final store = GuestWorkspaceStore(_MemoryGuestStorage());
    await store.save(
      GuestWorkspaceData(
        templates: const [
          {
            'id': 'template-1',
            'name': 'Interview template',
            'questions': [],
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

    expect(_field('Search local Knowledge'), findsOneWidget);
    await tester.tap(find.text('Saved Q&A'));
    await tester.pumpAndSettle();
    expect(
      tester.getSize(_field('Search local Knowledge')).width,
      lessThanOrEqualTo(840),
    );
    await tester.tap(find.text('Back to add a local question'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Interact').first);
    await tester.pumpAndSettle();
    expect(
      find.text('Interact sessions stay private on this device.'),
      findsOneWidget,
    );
    await tester.tap(find.byTooltip('Interact privacy information'));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Interact sessions stay private on this device until you explicitly select one for a shared group.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    expect(tester.getSize(_field('New Interact session')).width, lessThan(1040));
    final templatePicker = find.byWidgetPredicate(
      (widget) =>
          widget is DropdownButtonFormField<String?> &&
          widget.decoration.labelText == 'Optional local template',
    );
    expect(tester.getSize(templatePicker).width, lessThanOrEqualTo(1040));
  });

  testWidgets(
    'switching active participants keeps answers and targeted branches after reload',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final storage = _MemoryGuestStorage();
      final store = GuestWorkspaceStore(storage);
      await store.save(
        GuestWorkspaceData(
          sessions: [_twoParticipantSession()],
        ),
      );

      Future<void> showWorkspace() async {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              guestWorkspaceStoreProvider.overrideWithValue(store),
            ],
            child: const MaterialApp(
              home: GuestWorkspacePage(firebaseReady: false),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Interact').first);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Two-person interview'));
        await tester.pumpAndSettle();
      }

      await showWorkspace();
      expect(find.byTooltip('Active participant help'), findsOneWidget);
      expect(find.byTooltip('Prepared question help'), findsOneWidget);
      await tester.tap(find.byTooltip('Prepared question help'));
      await tester.pumpAndSettle();
      expect(
        find.text('Shared questions get separate answers from each participant.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      expect(_answerField(tester).controller!.text, 'Alice answer');
      expect(find.text('Bob-only question'), findsNothing);

      await _selectParticipant(tester, 'Bob');
      expect(_answerField(tester).controller!.text, 'Bob answer');
      expect(find.text('Bob-only question'), findsOneWidget);
      expect(find.text('Bob follow-up'), findsOneWidget);

      await tester.enterText(_field('Prepared question'), 'Bob-only addition');
      await tester.tap(find.text('Add question for selected participant'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 300));
      final saved = await store.load();
      final savedQuestions = saved.sessions.single['questions'] as List;
      final added = savedQuestions
          .cast<Map<String, dynamic>>()
          .singleWhere((question) => question['text'] == 'Bob-only addition');
      expect(added['scope'], 'participant');
      expect(added['target_participant_id'], 'bob-id');

      await _selectParticipant(tester, 'Alice');
      expect(_answerField(tester).controller!.text, 'Alice answer');
      expect(find.text('Bob-only addition'), findsNothing);
      await _selectParticipant(tester, 'Bob');
      expect(find.text('Bob-only addition'), findsOneWidget);

      await showWorkspace();
      await _selectParticipant(tester, 'Bob');
      expect(_answerField(tester).controller!.text, 'Bob answer');
      expect(find.text('Bob-only addition'), findsOneWidget);
      expect(find.text('Bob follow-up'), findsOneWidget);
    },
  );

  testWidgets('PDF report preview uses the active participant scope', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

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
    await tester.tap(find.descendant(of: preview, matching: find.text('Close')));
    await tester.pumpAndSettle();
    expect(find.text('Preview PDF'), findsNothing);
  });

  testWidgets('local JSON backup import previews and merges selected items', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

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

  testWidgets('failed local save preserves the latest work for explicit retry', (
    tester,
  ) async {
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

    storage.failWrites = false;
    await tester.tap(find.text('Retry saving'));
    await tester.pumpAndSettle();

    expect((await store.load()).knowledge.single['title'], 'Kept after failure');
    expect(
      find.text('Your changes are not saved. Keep this page open and retry.'),
      findsNothing,
    );
    expect(find.textContaining('Saved on this device'), findsOneWidget);
  });

  testWidgets('queued local work is persisted when the page is disposed', (
    tester,
  ) async {
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
    await tester.enterText(_field('Question'), 'Saved while leaving');
    final saveButton = find.widgetWithText(FilledButton, 'Save locally');
    await tester.ensureVisible(saveButton);
    await tester.pumpAndSettle();
    await tester.tap(saveButton);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();

    expect(
      (await store.load()).knowledge.single['title'],
      'Saved while leaving',
    );
  });

  testWidgets('in-flight local save completes after the page is disposed', (
    tester,
  ) async {
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
        GuestWorkspaceData.decodeBackup(copiedText!).knowledge.single['title'],
        'Latest rescue work',
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
      expect(
        find.text('Local JSON backup copied to clipboard.'),
        findsNothing,
      );
      expect(
        find.text('Your changes are not saved. Keep this page open and retry.'),
        findsOneWidget,
      );
    },
  );

  testWidgets('failed backup import preserves source and current local data', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
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
    await tester.pumpAndSettle();
    await tester.tap(find.text('Import selected locally'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'The backup could not be imported. Your current local work was kept.',
      ),
      findsOneWidget,
    );
    expect(storage.value, existingStoredValue);
    expect((await store.load()).knowledge.single['title'], 'Existing local item');

    await tester.tap(find.byTooltip('Guest workspace options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Import local JSON backup'));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(_field('Paste backup JSON')).controller!.text, backup);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
  });

  testWidgets('a stale save completion never reports newer edits as saved', (
    tester,
  ) async {
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
    expect(find.textContaining('Saving locally…'), findsOneWidget);

    store.releaseFirstWrite();
    await tester.pumpAndSettle();
    final saved = await store.load();
    expect(saved.knowledge.map((item) => item['title']), [
      'Latest change',
      'First change',
    ]);
    expect(store.writeSnapshots.last, ['Latest change', 'First change']);
    expect(find.textContaining('Saved on this device'), findsOneWidget);
  });

  testWidgets('corrupt local data is preserved and the initial load can retry', (
    tester,
  ) async {
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

    expect(find.textContaining('stored copy was not changed'), findsOneWidget);
    expect(find.text('Retry loading'), findsOneWidget);
    expect(storage.value, '{corrupt local data');
    storage.value = validStoredValue;
    await tester.tap(find.text('Retry loading'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Saved Q&A'));
    await tester.pumpAndSettle();

    expect(find.text('Recoverable item'), findsOneWidget);
    expect((await store.load()).knowledge.single['title'], 'Recoverable item');
  });

  testWidgets('local read failure retains storage and exposes retry', (
    tester,
  ) async {
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
    expect(tester.widget<TextField>(_field('Question')).focusNode!.hasFocus, isTrue);
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
    await tester.enterText(_field('First participant'), '');
    await tester.tap(find.text('Create session locally'));
    await tester.pumpAndSettle();
    expect(find.text('Enter a participant name.'), findsOneWidget);
    await tester.enterText(_field('First participant'), 'Alice');
    await tester.tap(find.text('Create session locally'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 300));
    expect((await store.load()).sessions.single['title'], 'Interview');
  });
}

Finder _field(String label) => find.byWidgetPredicate(
  (widget) => widget is TextField && widget.decoration?.labelText == label,
);

TextField _answerField(WidgetTester tester) =>
    tester.widget<TextField>(_field('Local answer').first);

Future<void> _selectParticipant(WidgetTester tester, String name) async {
  final selector = find.byWidgetPredicate(
    (widget) =>
        widget is DropdownButtonFormField<String> &&
        widget.decoration.labelText == 'Active participant',
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
        {
          'participant_id': 'bob-id',
          'body': '',
          'follow_ups': [],
        },
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

  @override
  void remove() => value = null;

  @override
  String? read() {
    if (failReads) throw StateError('secret-password storage read failure');
    return value;
  }

  @override
  void write(String value) {
    if (failWrites) throw StateError('secret-password storage failure');
    this.value = value;
  }
}

class _DelayedFirstSaveStore extends GuestWorkspaceStore {
  _DelayedFirstSaveStore(GuestStorage storage) : super(storage);

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
