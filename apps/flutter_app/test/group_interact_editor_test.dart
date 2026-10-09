import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:int_qa_flow/core/theme/app_theme.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:int_qa_flow/core/api/api_exception.dart';
import 'package:int_qa_flow/core/auth/auth_providers.dart';
import 'package:int_qa_flow/features/guest/data/guest_group_repository.dart';
import 'package:int_qa_flow/features/guest/presentation/guest_workspace_page.dart';

Map<String, dynamic> _copy(Map<String, dynamic> value) =>
    jsonDecode(jsonEncode(value)) as Map<String, dynamic>;

class _User implements User {
  _User(this.uid);
  @override
  final String uid;
  @override
  bool get isAnonymous => false;
  @override
  bool get emailVerified => true;
  @override
  String get email => '$uid@example.test';
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Auth implements FirebaseAuth {
  User? user = _User('owner');
  @override
  User? get currentUser => user;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Map<String, dynamic> _question(String id, String text, {int depth = 0}) => {
  'id': id,
  'text': text,
  'scope': id == 'root' ? 'shared' : 'participant',
  if (id != 'root') 'target_participant_id': 'alice',
  'answers': [
    {
      'participant_id': 'alice',
      'body': 'Answer $id',
      'branches_collapsed': false,
      'follow_ups': [
        if (depth > 0)
          _question('$id-child', 'Follow-up $depth', depth: depth - 1),
      ],
    },
    if (id == 'root')
      {
        'participant_id': 'bob',
        'body': 'Bob original',
        'branches_collapsed': false,
        'follow_ups': [],
      },
  ],
};

class _Repository extends GuestGroupRepository {
  _Repository({this.role = 'editor', this.creator = 'owner', int depth = 2})
    : super(Dio()) {
    entry = {
      'id': 'entry-1',
      'kind': 'interact_session',
      'title': 'Shared interview',
      'created_by_uid': creator,
      'revision': 1,
      'data': {
        'id': 'session-stable',
        'participants': [
          {'id': 'alice', 'name': 'Alice', 'description': 'First participant'},
          {'id': 'bob', 'name': 'Bob', 'description': 'Second participant'},
        ],
        'questions': [
          _question('root', 'Root question', depth: depth),
          _question('target', 'Alice targeted question'),
        ],
      },
    };
    original = _copy(entry);
    history.add(_copy(entry));
  }

  String role;
  final String creator;
  late Map<String, dynamic> entry;
  late final Map<String, dynamic> original;
  final history = <Map<String, dynamic>>[];
  final writes = <Map<String, dynamic>>[];
  int exports = 0;
  int histories = 0;
  int entryReads = 0;
  int searches = 0;
  bool excludeFromEmptySearch = false;
  int? entryDenied;
  int? denied;
  int? writeDenied;
  bool deleted = false;
  bool uncertain = false;
  bool applyUncertain = false;
  String groupName = 'Study group';
  Completer<Map<String, dynamic>>? pendingGroup;
  Completer<Map<String, dynamic>>? pendingEntry;
  Completer<Map<String, dynamic>>? pendingExport;
  Completer<void>? pendingWrite;

  Map<String, dynamic> get group => {
    'id': 'group-1',
    'name': groupName,
    'role': role,
    'members': [],
  };

  @override
  Future<List<Map<String, dynamic>>> listGroups() async => [_copy(group)];
  @override
  Future<List<Map<String, dynamic>>> listArchivedGroups() async => [];
  @override
  Future<List<Map<String, dynamic>>> listInvitations(String groupId) async =>
      [];
  @override
  Future<Map<String, dynamic>> getGroup(String groupId) async {
    if (groupId != 'group-1') {
      throw const ApiException('Wrong group', statusCode: 404);
    }
    if (pendingGroup != null) return pendingGroup!.future;
    if (denied != null) throw ApiException('Denied', statusCode: denied);
    return _copy(group);
  }

  @override
  Future<List<Map<String, dynamic>>> searchEntries({
    required String groupId,
    String query = '',
  }) async {
    searches++;
    if (groupId != 'group-1') {
      throw const ApiException('Wrong group', statusCode: 404);
    }
    if (denied != null) throw ApiException('Denied', statusCode: denied);
    if (excludeFromEmptySearch && query.isEmpty) {
      return List.generate(
        50,
        (index) => {
          ..._copy(entry),
          'id': 'newer-entry-$index',
          'title': 'Newer entry $index',
        },
      );
    }
    return deleted ? [] : [_copy(entry)];
  }

  @override
  Future<Map<String, dynamic>> getEntry({
    required String groupId,
    required String entryId,
  }) async {
    entryReads++;
    if (groupId != 'group-1' || entryId != entry['id'] || deleted) {
      throw const ApiException('Missing copy', statusCode: 404);
    }
    if (pendingEntry != null) return pendingEntry!.future;
    final code = entryDenied ?? denied;
    if (code != null) throw ApiException('Denied', statusCode: code);
    return _copy(entry);
  }

  @override
  Future<Map<String, dynamic>> updateEntry({
    required String groupId,
    required String entryId,
    required int expectedRevision,
    required String title,
    required Map<String, dynamic> data,
  }) async {
    writes.add({
      'group_id': groupId,
      'entry_id': entryId,
      'expected_revision': expectedRevision,
      'title': title,
      'data': _copy(data),
    });
    if (groupId != 'group-1' || entryId != entry['id']) {
      throw const ApiException('Wrong copy', statusCode: 404);
    }
    if (denied != null) throw ApiException('Denied', statusCode: denied);
    if (writeDenied != null) {
      throw ApiException('Write denied', statusCode: writeDenied);
    }
    if (role == 'viewer' || (role == 'contributor' && creator != 'owner')) {
      throw const ApiException('Forbidden', statusCode: 403);
    }
    if (deleted) throw const ApiException('Deleted', statusCode: 404);
    if (entry['revision'] != expectedRevision) {
      throw const ApiException('Conflict', statusCode: 409);
    }
    if (!uncertain || applyUncertain) {
      entry = {
        ...entry,
        'title': title,
        'data': _copy(data),
        'revision': expectedRevision + 1,
      };
      history.add(_copy(entry));
    }
    if (pendingWrite != null) await pendingWrite!.future;
    if (uncertain) throw const ApiException('Connection lost');
    return _copy(entry);
  }

  @override
  Future<Map<String, dynamic>> exportEntry({
    required String groupId,
    required String entryId,
  }) async {
    exports++;
    if (groupId != 'group-1' || entryId != entry['id'] || deleted) {
      throw const ApiException('Wrong copy', statusCode: 404);
    }
    if (pendingExport != null) return pendingExport!.future;
    if (denied != null) throw ApiException('Denied', statusCode: denied);
    return _copy(entry);
  }

  @override
  Future<List<Map<String, dynamic>>> entryHistory({
    required String groupId,
    required String entryId,
  }) async {
    histories++;
    if (groupId != 'group-1' || entryId != entry['id'] || deleted) {
      throw const ApiException('Wrong copy', statusCode: 404);
    }
    if (denied != null) throw ApiException('Denied', statusCode: denied);
    return history.map(_copy).toList();
  }
}

Finder _field(String label) => find.byWidgetPredicate(
  (widget) => widget is TextField && widget.decoration?.labelText == label,
);

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _openEntry(WidgetTester tester, String title) async {
  final finder = find.text(title);
  if (finder.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      finder,
      200,
      scrollable: find.byType(Scrollable).first,
    );
  }
  await _tap(tester, finder);
}

Future<void> _mount(
  WidgetTester tester,
  _Repository repository, {
  _Auth? auth,
  Stream<User?>? events,
  bool edit = true,
}) async {
  final identity = auth ?? _Auth();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        firebaseAuthProvider.overrideWithValue(identity),
        authStateProvider.overrideWith(
          (ref) => events ?? Stream.value(identity.currentUser),
        ),
        guestGroupRepositoryProvider.overrideWithValue(repository),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        builder: AppTheme.responsiveBuilder,
        home: const SharedGuestGroupsPage(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await _openEntry(tester, 'Shared interview');
  if (edit) {
    await _tap(tester, find.widgetWithText(TextButton, 'Edit'));
    expect(find.text('Edit shared copy'), findsOneWidget);
  }
}

Future<void> _rename(WidgetTester tester, String title) async {
  await _tap(tester, find.byTooltip('More session actions'));
  await _tap(tester, find.text('Rename session'));
  await tester.enterText(_field('Session title'), title);
  await _tap(tester, find.text('Update Group draft'));
}

Future<void> _export(WidgetTester tester) async {
  await _tap(tester, find.byTooltip('More session actions'));
  await _tap(tester, find.text('Copy session JSON backup'));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final clipboard = <String>[];
  final sharedFiles = <MethodCall>[];

  setUp(() {
    clipboard.clear();
    sharedFiles.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('dev.fluttercommunity.plus/share'),
          (call) async {
            sharedFiles.add(call);
            return 'success';
          },
        );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') {
            clipboard.add((call.arguments as Map)['text'] as String);
          }
          return null;
        });
  });
  tearDown(() {
    expect(sharedFiles, isEmpty);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('dev.fluttercommunity.plus/share'),
          null,
        );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  testWidgets(
    'save and reload preserve graph IDs targets nested branches and clear a blank answer without mutating original',
    (tester) async {
      final repository = _Repository();
      await _mount(tester, repository);
      final questionEdit = find.byKey(
        const ValueKey('guest-question-text-root'),
      );
      await tester.scrollUntilVisible(
        questionEdit,
        180,
        scrollable: find
            .descendant(
              of: find.byKey(const ValueKey('guest-session-editor-scroll')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await _tap(tester, questionEdit.first);
      await tester.enterText(_field('Question text'), 'Revised root question');
      await tester.pumpAndSettle();
      await _tap(tester, _field('Group copy answer').first);
      await tester.enterText(_field('Group copy answer').first, '');
      await _tap(tester, find.text('Save Group copy'));

      final expected = _copy(
        repository.original['data'] as Map<String, dynamic>,
      );
      final root = (expected['questions'] as List).first as Map;
      root['text'] = 'Revised root question';
      (root['answers'] as List).first['body'] = '';
      expect(repository.entry['data'], expected);
      expect(repository.original['revision'], 1);
      expect(
        (repository.original['data']['questions'] as List).first['text'],
        'Root question',
      );
      expect(repository.writes.single['expected_revision'], 1);
      expect(repository.entry['revision'], 2);
      await _tap(tester, find.byTooltip('Close Group editor'));
      await _openEntry(tester, 'Shared interview');
      await tester.tap(find.text('History'));
      for (var frame = 0; frame < 30; frame++) {
        await tester.pump(const Duration(milliseconds: 100));
        if (find.text('Revision 2 · Shared interview').evaluate().isNotEmpty) {
          break;
        }
      }
      expect(find.text('Revision 1 · Shared interview'), findsOneWidget);
      expect(find.text('Revision 2 · Shared interview'), findsOneWidget);
      expect(repository.histories, 1);
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog).last,
          matching: find.widgetWithText(FilledButton, 'Done'),
        ),
      );
      await tester.pumpAndSettle();
      await _tap(tester, find.text('Edit'));
      await tester.scrollUntilVisible(
        find.text('Revised root question'),
        180,
        scrollable: find
            .descendant(
              of: find.byKey(const ValueKey('guest-session-editor-scroll')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(find.text('Revised root question'), findsOneWidget);
      expect(
        tester
            .widget<TextField>(_field('Group copy answer').first)
            .controller!
            .text,
        '',
      );
      expect(tester.takeException(), isNull);
    },
  );

  for (final role in ['admin', 'editor', 'contributor']) {
    testWidgets('$role can edit its own shared Interact copy', (tester) async {
      final repository = _Repository(role: role);
      await _mount(tester, repository);
      await _rename(tester, '$role saved');
      await _tap(tester, find.text('Save Group copy'));
      expect(repository.writes, hasLength(1));
      expect(repository.entry['title'], '$role saved');
      expect(repository.entry['revision'], 2);
      expect(repository.original['title'], 'Shared interview');
    });
  }

  for (final role in ['viewer', 'contributor']) {
    testWidgets('$role cannot edit another member shared Interact copy', (
      tester,
    ) async {
      final repository = _Repository(role: role, creator: 'someone-else');
      await _mount(tester, repository, edit: false);
      expect(find.widgetWithText(TextButton, 'Edit'), findsNothing);
      expect(find.text('History'), findsOneWidget);
      expect(repository.writes, isEmpty);
    });
  }

  for (final role in ['admin', 'editor']) {
    testWidgets('$role can edit another member shared Interact copy', (
      tester,
    ) async {
      final repository = _Repository(role: role, creator: 'someone-else');
      await _mount(tester, repository);
      await _rename(tester, 'Changed by $role');
      await _tap(tester, find.text('Save Group copy'));
      expect(repository.writes.single['expected_revision'], 1);
      expect(repository.entry['title'], 'Changed by $role');
      expect(repository.entry['created_by_uid'], 'someone-else');
    });
  }

  testWidgets('409 competing edit keeps draft and review never retries', (
    tester,
  ) async {
    final repository = _Repository()..writeDenied = 409;
    await _mount(tester, repository);
    await _rename(tester, 'My draft');
    await _tap(tester, find.text('Save Group copy'));
    repository.entry['title'] = 'Other member version';
    repository.entry['revision'] = 2;
    expect(find.textContaining('Conflict: draft kept'), findsWidgets);
    await _tap(tester, find.text('Review latest copy'));
    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.textContaining('My draft'),
      ),
      findsOneWidget,
    );
    expect(find.textContaining('Other member version'), findsOneWidget);
    await _tap(tester, find.text('Keep draft'));
    expect(find.text('My draft'), findsOneWidget);
    expect(repository.writes, hasLength(1));
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Save Group copy'),
          )
          .onPressed,
      isNull,
    );
    await _tap(tester, find.text('Review latest copy'));
    await _tap(tester, find.text('Discard draft and load latest'));
    expect(find.text('Other member version'), findsOneWidget);
    expect(repository.writes, hasLength(1));
  });

  testWidgets('revision changed before save prevents even the first write', (
    tester,
  ) async {
    final repository = _Repository();
    await _mount(tester, repository);
    await _rename(tester, 'My draft');
    repository.entry['revision'] = 2;
    await _tap(tester, find.text('Save Group copy'));
    expect(find.textContaining('Conflict: draft kept'), findsWidgets);
    expect(repository.writes, isEmpty);
    expect(find.text('My draft'), findsOneWidget);
  });

  for (final applied in [true, false]) {
    testWidgets(
      'uncertain save applied=$applied reconciles before safe retry',
      (tester) async {
        final repository = _Repository()
          ..uncertain = true
          ..applyUncertain = applied;
        await _mount(tester, repository);
        await _rename(tester, 'Unconfirmed draft');
        await _tap(tester, find.text('Save Group copy'));
        expect(repository.writes, hasLength(1));
        expect(find.text('Check save status'), findsOneWidget);
        expect(
          tester
              .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Save Group copy'),
              )
              .onPressed,
          isNull,
        );
        await _tap(tester, find.text('Check save status'));
        if (applied) {
          expect(
            find.textContaining('Saved Group copy confirmed'),
            findsWidgets,
          );
          expect(repository.entry['revision'], 2);
          expect(repository.writes, hasLength(1));
        } else {
          expect(find.textContaining('safe to retry'), findsWidgets);
          repository.uncertain = false;
          await _tap(tester, find.text('Save Group copy'));
          expect(repository.writes, hasLength(2));
          expect(repository.writes.last['expected_revision'], 1);
          expect(repository.entry['revision'], 2);
        }
        expect(repository.entry['title'], 'Unconfirmed draft');
        expect(repository.history, hasLength(2));
      },
    );
  }

  testWidgets(
    'applied uncertain save after resume clears conflict on confirmation',
    (tester) async {
      final repository = _Repository()
        ..uncertain = true
        ..applyUncertain = true;
      await _mount(tester, repository);
      await _rename(tester, 'Lost response');
      await _tap(tester, find.text('Save Group copy'));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(find.textContaining('Conflict: draft kept'), findsWidgets);
      await _tap(tester, find.text('Check save status'));
      expect(find.textContaining('Saved Group copy confirmed'), findsWidgets);
      repository.uncertain = false;
      await _rename(tester, 'Next edit');
      await _tap(tester, find.text('Save Group copy'));
      expect(repository.entry['title'], 'Next edit');
      expect(repository.entry['revision'], 3);
      expect(repository.writes, hasLength(2));
    },
  );

  testWidgets(
    'uncertain save with newer content requires review without retry',
    (tester) async {
      final repository = _Repository()..uncertain = true;
      await _mount(tester, repository);
      await _rename(tester, 'Unconfirmed draft');
      await _tap(tester, find.text('Save Group copy'));
      repository.entry
        ..['revision'] = 2
        ..['title'] = 'Newer remote content';
      await _tap(tester, find.text('Check save status'));
      expect(find.textContaining('Conflict: draft kept'), findsWidgets);
      await _tap(tester, find.text('Review latest copy'));
      expect(find.textContaining('Newer remote content'), findsWidgets);
      await _tap(tester, find.text('Keep draft'));
      expect(find.text('Unconfirmed draft'), findsOneWidget);
      expect(repository.writes, hasLength(1));
      expect(repository.entry['title'], 'Newer remote content');
    },
  );

  for (final signOut in [true, false]) {
    testWidgets(
      'delayed PATCH completion after signout=$signOut never restores draft',
      (tester) async {
        final auth = _Auth();
        final repository = _Repository();
        await _mount(tester, repository, auth: auth);
        await _rename(tester, 'Origin draft');
        final pending = Completer<void>();
        repository.pendingWrite = pending;
        await tester.tap(find.text('Save Group copy'));
        await tester.pump();
        expect(repository.writes, hasLength(1));
        auth.user = signOut ? null : _User('new-account');
        pending.complete();
        await tester.pumpAndSettle();
        expect(find.text('Edit shared copy'), findsNothing);
        expect(find.text('Origin draft'), findsNothing);
        expect(repository.writes.single['group_id'], 'group-1');
        expect(repository.writes.single['entry_id'], 'entry-1');
        expect(clipboard, isEmpty);
      },
    );
  }

  testWidgets('older searched entry opens despite exclusion from newest 50', (
    tester,
  ) async {
    final repository = _Repository();
    await _mount(tester, repository, edit: false);
    repository.excludeFromEmptySearch = true;
    expect(await repository.searchEntries(groupId: 'group-1'), hasLength(50));
    expect(
      (await repository.searchEntries(
        groupId: 'group-1',
      )).any((entry) => entry['id'] == 'entry-1'),
      isFalse,
    );
    expect(
      (await repository.searchEntries(
        groupId: 'group-1',
        query: 'Shared interview',
      )).single['id'],
      'entry-1',
    );
    final searches = repository.searches;
    await _tap(tester, find.widgetWithText(TextButton, 'Edit'));
    expect(find.text('Edit shared copy'), findsOneWidget);
    expect(find.textContaining('Group copy unavailable'), findsNothing);
    expect(repository.entryReads, 1);
    expect(repository.searches, searches);
    await _rename(tester, 'Older saved copy');
    await _tap(tester, find.text('Save Group copy'));
    expect(repository.entry['title'], 'Older saved copy');
    expect(repository.entry['revision'], 2);
    expect(repository.writes, hasLength(1));
    expect(repository.searches, searches);
  });

  for (final applied in [true, false]) {
    testWidgets(
      'entry pushed beyond cutoff still reconciles applied=$applied and exports',
      (tester) async {
        final repository = _Repository()
          ..uncertain = true
          ..applyUncertain = applied;
        await _mount(tester, repository);
        final searches = repository.searches;
        repository.excludeFromEmptySearch = true;
        await _rename(tester, 'Beyond cutoff draft');
        await _tap(tester, find.text('Save Group copy'));
        expect(find.text('Check save status'), findsOneWidget);
        await _tap(tester, find.text('Check save status'));
        if (!applied) {
          expect(find.textContaining('safe to retry'), findsWidgets);
          repository.uncertain = false;
          await _tap(tester, find.text('Save Group copy'));
        } else {
          expect(
            find.textContaining('Saved Group copy confirmed'),
            findsWidgets,
          );
        }
        expect(repository.entry['title'], 'Beyond cutoff draft');
        expect(repository.entry['revision'], 2);
        await _export(tester);
        await _tap(tester, find.text('Copy saved JSON'));
        expect(jsonDecode(clipboard.single), repository.entry);
        expect(repository.searches, searches);
        expect(find.textContaining('Group copy unavailable'), findsNothing);
      },
    );
  }

  for (final code in [403, 404]) {
    testWidgets(
      'direct entry HTTP $code removes draft after successful group read',
      (tester) async {
        final repository = _Repository();
        await _mount(tester, repository);
        await _rename(tester, 'Denied draft');
        repository.entryDenied = code;
        final reads = repository.entryReads;
        await _tap(tester, find.text('Save Group copy'));
        expect(repository.entryReads, reads + 1);
        expect(find.textContaining('Group copy unavailable'), findsWidgets);
        expect(find.text('Denied draft'), findsNothing);
        expect(repository.writes, isEmpty);
        expect(clipboard, isEmpty);
      },
    );
  }

  testWidgets(
    'pending direct entry read after signout cannot write or disclose',
    (tester) async {
      final auth = _Auth();
      final repository = _Repository();
      await _mount(tester, repository, auth: auth);
      await _rename(tester, 'Pending direct draft');
      final pending = Completer<Map<String, dynamic>>();
      repository.pendingEntry = pending;
      final reads = repository.entryReads;
      await tester.tap(find.text('Save Group copy'));
      await tester.pump();
      expect(repository.entryReads, reads + 1);
      auth.user = null;
      pending.complete(_copy(repository.entry));
      await tester.pumpAndSettle();
      expect(find.text('Edit shared copy'), findsNothing);
      expect(find.text('Pending direct draft'), findsNothing);
      expect(repository.writes, isEmpty);
      expect(clipboard, isEmpty);
    },
  );

  for (final operation in ['entry', 'export']) {
    testWidgets(
      'delayed $operation response after UID switch cannot disclose',
      (tester) async {
        final auth = _Auth();
        final repository = _Repository();
        await _mount(tester, repository, auth: auth);
        final entry = Completer<Map<String, dynamic>>();
        final exported = Completer<Map<String, dynamic>>();
        final before = repository.entryReads;
        if (operation == 'entry') {
          await _rename(tester, 'Delayed draft');
          repository.pendingEntry = entry;
          await tester.tap(find.text('Save Group copy'));
        } else {
          repository.pendingExport = exported;
          await _tap(tester, find.byTooltip('More session actions'));
          await tester.tap(find.text('Copy session JSON backup'));
        }
        await tester.pump();
        if (operation == 'entry') {
          expect(repository.entryReads, before + 1);
        } else {
          expect(repository.exports, 1);
        }
        auth.user = _User('new-account');
        if (operation == 'entry') {
          entry.complete(_copy(repository.entry));
        } else {
          exported.complete(_copy(repository.entry));
        }
        await tester.pumpAndSettle();
        expect(find.text('Copy saved Group session JSON?'), findsNothing);
        expect(find.text('Edit shared copy'), findsNothing);
        expect(repository.writes, isEmpty);
        expect(clipboard, isEmpty);
      },
    );
  }

  for (final stage in ['scope', 'preview', 'confirmation']) {
    testWidgets('entry report $stage is disposed on UID change', (
      tester,
    ) async {
      final auth = _Auth();
      final events = StreamController<User?>.broadcast();
      addTearDown(events.close);
      final repository = _Repository();
      await _mount(
        tester,
        repository,
        auth: auth,
        events: events.stream,
        edit: false,
      );
      await _tap(tester, find.text('Download / Share PDF'));
      if (stage != 'scope') {
        await _tap(tester, find.text('All participants'));
      }
      if (stage == 'confirmation') {
        await _tap(tester, find.text('Share PDF'));
      }
      auth.user = _User('new-account');
      events.add(auth.user);
      await tester.pumpAndSettle();
      expect(find.text('Choose report scope'), findsNothing);
      expect(find.text('Preview PDF'), findsNothing);
      expect(find.text('Share a PDF copy?'), findsNothing);
      expect(repository.writes, isEmpty);
      expect(clipboard, isEmpty);
    });
  }

  for (final code in [403, 404]) {
    testWidgets('entry report confirmation rechecks actual $code permission', (
      tester,
    ) async {
      final repository = _Repository();
      await _mount(tester, repository, edit: false);
      await _tap(tester, find.text('Download / Share PDF'));
      await _tap(tester, find.text('All participants'));
      await _tap(tester, find.text('Share PDF'));
      repository.denied = code;
      await _tap(tester, find.text('Continue'));
      expect(find.text('Preview PDF'), findsNothing);
      expect(find.textContaining('Group export unavailable'), findsOneWidget);
      expect(repository.writes, isEmpty);
      expect(clipboard, isEmpty);
    });
  }

  testWidgets('same UID lifecycle refresh invalidates report generation', (
    tester,
  ) async {
    final repository = _Repository();
    await _mount(tester, repository, edit: false);
    await _tap(tester, find.text('Download / Share PDF'));
    await _tap(tester, find.text('All participants'));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.text('Preview PDF'), findsNothing);
    expect(repository.writes, isEmpty);
  });

  testWidgets('uncertain Save and close keeps editor and admits remote write', (
    tester,
  ) async {
    final repository = _Repository()
      ..uncertain = true
      ..applyUncertain = true;
    await _mount(tester, repository);
    await _rename(tester, 'Uncertain closing draft');
    await _tap(tester, find.byTooltip('Close Group editor'));
    await _tap(tester, find.text('Save and close'));
    expect(find.text('Edit shared copy'), findsOneWidget);
    await _tap(tester, find.byTooltip('Close Group editor'));
    expect(find.textContaining('may have applied'), findsOneWidget);
    expect(find.text('Save and close'), findsNothing);
    await _tap(tester, find.text('Discard draft'));
    expect(find.text('Edit shared copy'), findsNothing);
    expect(repository.entry['title'], 'Uncertain closing draft');
    expect(repository.writes, hasLength(1));
  });

  testWidgets('system Back during pending save cannot dismiss editor', (
    tester,
  ) async {
    final repository = _Repository();
    await _mount(tester, repository);
    await _rename(tester, 'Pending draft');
    final pending = Completer<void>();
    repository.pendingWrite = pending;
    await tester.tap(find.text('Save Group copy'));
    await tester.pump();
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(find.text('Edit shared copy'), findsOneWidget);
    expect(find.text('Leave Group copy editor?'), findsNothing);
    pending.complete();
    await tester.pumpAndSettle();
    expect(repository.entry['title'], 'Pending draft');
    expect(repository.writes, hasLength(1));
  });
  for (final code in [403, 404]) {
    testWidgets('actual $code write response removes editable draft', (
      tester,
    ) async {
      final repository = _Repository()..writeDenied = code;
      await _mount(tester, repository);
      await _rename(tester, 'Private draft');
      await _tap(tester, find.text('Save Group copy'));
      expect(find.textContaining('Group copy unavailable'), findsWidgets);
      expect(find.text('Private draft'), findsNothing);
      expect(find.text('Save Group copy'), findsNothing);
      expect(repository.writes, hasLength(1));
      expect(clipboard, isEmpty);
    });
  }

  for (final deleted in [true, false]) {
    testWidgets(
      're-read catches ${deleted ? 'deletion' : 'revocation'} before write',
      (tester) async {
        final repository = _Repository();
        await _mount(tester, repository);
        await _rename(tester, 'Private draft');
        repository.deleted = deleted;
        if (!deleted) repository.role = 'viewer';
        await _tap(tester, find.text('Save Group copy'));
        expect(find.textContaining('Group copy unavailable'), findsWidgets);
        expect(repository.writes, isEmpty);
        expect(find.text('Private draft'), findsNothing);
      },
    );
  }

  for (final signOut in [true, false]) {
    testWidgets(
      'delayed capability read after ${signOut ? 'signout' : 'UID switch'} cannot write',
      (tester) async {
        final auth = _Auth();
        final events = StreamController<User?>.broadcast();
        addTearDown(events.close);
        final repository = _Repository();
        await _mount(tester, repository, auth: auth, events: events.stream);
        await _rename(tester, 'Private draft');
        final pending = Completer<Map<String, dynamic>>();
        repository.pendingGroup = pending;
        await tester.tap(find.text('Save Group copy'));
        await tester.pump();
        auth.user = signOut ? null : _User('new-account');
        repository.pendingGroup = null;
        pending.complete(repository.group);
        await tester.pumpAndSettle();
        expect(repository.writes, isEmpty);
        expect(clipboard, isEmpty);
        expect(find.text('Edit shared copy'), findsNothing);
        expect(find.text('Private draft'), findsNothing);
      },
    );
  }

  for (final signOut in [true, false]) {
    testWidgets(
      'delayed export capability read after ${signOut ? 'signout' : 'UID switch'} cannot disclose JSON',
      (tester) async {
        final auth = _Auth();
        final repository = _Repository();
        await _mount(tester, repository, auth: auth);
        await _tap(tester, find.byTooltip('More session actions'));
        final pending = Completer<Map<String, dynamic>>();
        repository.pendingGroup = pending;
        await tester.tap(find.text('Copy session JSON backup'));
        await tester.pump();
        auth.user = signOut ? null : _User('new-account');
        repository.pendingGroup = null;
        pending.complete(repository.group);
        await tester.pumpAndSettle();
        expect(repository.exports, 0);
        expect(clipboard, isEmpty);
        expect(find.text('Copy saved Group session JSON?'), findsNothing);
        expect(find.text('Edit shared copy'), findsNothing);
      },
    );
  }

  testWidgets('auth event signout disposes open draft without writing', (
    tester,
  ) async {
    final auth = _Auth();
    final events = StreamController<User?>.broadcast();
    addTearDown(events.close);
    final repository = _Repository();
    await _mount(tester, repository, auth: auth, events: events.stream);
    await _rename(tester, 'Private draft');
    auth.user = null;
    events.add(null);
    await tester.pumpAndSettle();
    expect(find.text('Edit shared copy'), findsNothing);
    expect(find.text('Private draft'), findsNothing);
    expect(repository.writes, isEmpty);
    expect(clipboard, isEmpty);
  });

  testWidgets(
    'actual export menu confirms saved JSON and excludes unsaved draft',
    (tester) async {
      final repository = _Repository();
      await _mount(tester, repository);
      await _rename(tester, 'Not exported draft');
      await _export(tester);
      expect(find.text('Copy saved Group session JSON?'), findsOneWidget);
      expect(clipboard, isEmpty);
      await _tap(tester, find.text('Cancel'));
      expect(clipboard, isEmpty);
      await _export(tester);
      await _tap(tester, find.text('Copy saved JSON'));
      expect(jsonDecode(clipboard.single), repository.entry);
      expect(clipboard.single, isNot(contains('Not exported draft')));
      expect(repository.exports, 2);
      expect(repository.writes, isEmpty);
    },
  );

  testWidgets('editor revision history reads persisted saves not draft', (
    tester,
  ) async {
    final repository = _Repository();
    await _mount(tester, repository);
    await _rename(tester, 'Persisted revision');
    await _tap(tester, find.text('Save Group copy'));
    await _rename(tester, 'Unsaved revision');
    await _tap(tester, find.byTooltip('Group copy revision history'));
    expect(find.text('Revision 1 · Shared interview'), findsOneWidget);
    expect(find.text('Revision 2 · Persisted revision'), findsOneWidget);
    expect(find.textContaining('Revision 3'), findsNothing);
    expect(repository.histories, 1);
    await _tap(
      tester,
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(TextButton, 'Done'),
      ),
    );
    expect(find.text('Unsaved revision'), findsOneWidget);
    expect(repository.writes, hasLength(1));
  });

  for (final all in [false, true]) {
    testWidgets(
      'saved Group PDF ${all ? 'all' : 'selected'} participant preview excludes unsaved draft',
      (tester) async {
        final repository = _Repository();
        await _mount(tester, repository);
        await _rename(tester, 'Unsaved PDF title');
        await tester.scrollUntilVisible(
          find.text('Root question'),
          180,
          scrollable: find
              .descendant(
                of: find.byKey(const ValueKey('guest-session-editor-scroll')),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        await tester.enterText(
          _field('Group copy answer').first,
          'Unsaved PDF answer',
        );
        await tester.scrollUntilVisible(
          find.text('Download / Share PDF'),
          -180,
          scrollable: find
              .descendant(
                of: find.byKey(const ValueKey('guest-session-editor-scroll')),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        await _tap(tester, find.text('Download / Share PDF'));
        expect(find.text('Saved Group copy report scope'), findsOneWidget);
        await _tap(
          tester,
          find.text(all ? 'All participants' : 'Selected participant'),
        );
        expect(find.text('Preview PDF'), findsOneWidget);
        expect(
          find.text(all ? 'Participants: Alice, Bob' : 'Participants: Alice'),
          findsOneWidget,
        );
        expect(find.text('Answer root'), findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.text('Unsaved PDF answer'),
          ),
          findsNothing,
        );
        expect(find.text('Bob original'), all ? findsOneWidget : findsNothing);
        expect(repository.exports, 1);
        expect(repository.entry['title'], 'Shared interview');
        expect(repository.writes, isEmpty);
        expect(clipboard, isEmpty);
        await _tap(
          tester,
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.text('Close'),
          ),
        );
        await tester.scrollUntilVisible(
          find.text('Unsaved PDF title'),
          -180,
          scrollable: find
              .descendant(
                of: find.byKey(const ValueKey('guest-session-editor-scroll')),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        expect(find.text('Unsaved PDF title'), findsOneWidget);
      },
    );
  }

  for (final code in [403, 404]) {
    testWidgets('PDF confirmation actual $code recheck prevents export', (
      tester,
    ) async {
      final repository = _Repository();
      await _mount(tester, repository);
      await _tap(tester, find.text('Download / Share PDF'));
      await _tap(tester, find.text('All participants'));
      await _tap(tester, find.text('Download PDF'));
      expect(find.text('Export a saved Group PDF copy?'), findsOneWidget);
      repository.denied = code;
      await _tap(tester, find.text('Continue'));
      expect(find.textContaining('Group copy unavailable'), findsWidgets);
      expect(find.text('Preview PDF'), findsNothing);
      expect(clipboard, isEmpty);
      expect(repository.writes, isEmpty);
      expect(repository.exports, 1);
    });
  }

  for (final transition in ['switch', 'signout', 'revoke', 'delete']) {
    testWidgets(
      'export confirmation $transition prevents clipboard disclosure',
      (tester) async {
        final auth = _Auth();
        final repository = _Repository();
        await _mount(tester, repository, auth: auth);
        await _export(tester);
        if (transition == 'switch') auth.user = _User('new-account');
        if (transition == 'signout') auth.user = null;
        if (transition == 'revoke') repository.denied = 403;
        if (transition == 'delete') repository.denied = 404;
        await _tap(tester, find.text('Copy saved JSON'));
        expect(clipboard, isEmpty);
        expect(repository.writes, isEmpty);
      },
    );
  }

  for (final action in ['Cancel', 'Discard draft', 'Save and close']) {
    testWidgets(
      'close editor $action has explicit draft and persistence semantics',
      (tester) async {
        final repository = _Repository();
        await _mount(tester, repository);
        await _rename(tester, 'Closing draft');
        await _tap(tester, find.byTooltip('Close Group editor'));
        expect(find.text('Leave Group copy editor?'), findsOneWidget);
        await _tap(tester, find.text(action));
        if (action == 'Cancel') {
          expect(find.text('Edit shared copy'), findsOneWidget);
          expect(find.text('Closing draft'), findsOneWidget);
          expect(repository.writes, isEmpty);
        } else {
          expect(find.text('Edit shared copy'), findsNothing);
          expect(
            repository.entry['title'],
            action == 'Save and close' ? 'Closing draft' : 'Shared interview',
          );
          expect(
            repository.writes,
            hasLength(action == 'Save and close' ? 1 : 0),
          );
        }
      },
    );
  }

  testWidgets(
    'Group participant management preserves graph and blocks content removal',
    (tester) async {
      final repository = _Repository();
      await _mount(tester, repository);
      final originalQuestions = _copy(
        repository.entry['data'] as Map<String, dynamic>,
      )['questions'];
      await _tap(tester, find.byTooltip('Active participant actions'));
      await _tap(tester, find.text('Remove active participant'));
      expect(find.textContaining('cannot be removed'), findsWidgets);
      await _tap(tester, find.text('Close'));
      await _tap(tester, find.byTooltip('Add participant'));
      await tester.enterText(_field('Participant name'), 'Carol');
      await _tap(tester, find.text('Add to Group draft'));
      await _tap(tester, find.byTooltip('Active participant actions'));
      await _tap(tester, find.text('Rename active participant'));
      await tester.enterText(_field('Participant name'), 'Carol renamed');
      await _tap(tester, find.text('Update Group draft'));
      await _tap(tester, find.text('Save Group copy'));
      final data = repository.entry['data'] as Map<String, dynamic>;
      final participants = data['participants'] as List;
      expect(participants, hasLength(3));
      final carol = participants.last as Map;
      expect(carol['name'], 'Carol renamed');
      final root = (data['questions'] as List).first as Map;
      expect((root['answers'] as List).last, {
        'participant_id': carol['id'],
        'body': '',
        'branches_collapsed': false,
        'follow_ups': [],
      });
      expect(
        (root['answers'] as List).take(2).toList(),
        (((originalQuestions as List).first as Map)['answers']),
      );
      expect((data['questions'] as List)[1], originalQuestions[1]);
      expect(repository.original['data']['participants'], hasLength(2));
      await _tap(tester, find.byTooltip('Active participant actions'));
      await _tap(tester, find.text('Remove active participant'));
      await _tap(tester, find.text('Remove participant'));
      await _tap(tester, find.text('Undo'));
      await _tap(tester, find.text('Save Group copy'));
      expect(repository.entry['data']['participants'].last['id'], carol['id']);
      await _tap(tester, find.byTooltip('Close Group editor'));
      await _openEntry(tester, 'Shared interview');
      await _tap(tester, find.widgetWithText(TextButton, 'Edit'));
      await _tap(tester, find.byType(DropdownButtonFormField<String>).last);
      await _tap(tester, find.text('Carol renamed').last);
      await _tap(tester, find.byTooltip('Active participant actions'));
      await _tap(tester, find.text('Remove active participant'));
      await _tap(tester, find.text('Remove participant'));
      await _tap(tester, find.text('Save Group copy'));
      expect(repository.entry['data']['participants'], hasLength(2));
      expect(repository.entry['data']['questions'], originalQuestions);
    },
  );

  for (final dialog in ['participant', 'question', 'history', 'review']) {
    testWidgets('signout disposes nested $dialog dialog and draft', (
      tester,
    ) async {
      final auth = _Auth();
      final events = StreamController<User?>.broadcast();
      addTearDown(events.close);
      final repository = _Repository();
      await _mount(tester, repository, auth: auth, events: events.stream);
      if (dialog == 'participant') {
        await _tap(tester, find.byTooltip('Add participant'));
      } else if (dialog == 'question') {
        await tester.scrollUntilVisible(
          find.text('Add shared question'),
          160,
          scrollable: find
              .descendant(
                of: find.byKey(const ValueKey('guest-session-editor-scroll')),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        await _tap(tester, find.text('Add shared question'));
      } else if (dialog == 'history') {
        await _tap(tester, find.byTooltip('Group copy revision history'));
      } else {
        await _rename(tester, 'Scoped draft');
        repository.entry['revision'] = 2;
        await _tap(tester, find.text('Save Group copy'));
        await _tap(tester, find.text('Review latest copy'));
      }
      expect(find.byType(AlertDialog), findsWidgets);
      auth.user = null;
      events.add(null);
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('Edit shared copy'), findsNothing);
      expect(repository.writes, isEmpty);
      expect(clipboard, isEmpty);
    });
  }

  testWidgets(
    'phone long names keeps participant and question controls reachable with answer keyboard',
    (tester) async {
      tester.view.physicalSize = const Size(320, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      final repository = _Repository(depth: 4)
        ..groupName = List.filled(6, 'Long shared research group').join(' ');
      repository.entry['data']['participants'][0]['name'] = List.filled(
        8,
        'Long participant name',
      ).join(' ');
      await _mount(tester, repository);
      final scrollable = find
          .descendant(
            of: find.byKey(const ValueKey('guest-session-editor-scroll')),
            matching: find.byType(Scrollable),
          )
          .first;
      await tester.scrollUntilVisible(
        find.text('Follow-up 1'),
        160,
        scrollable: scrollable,
        maxScrolls: 100,
      );
      final deepAnswer = find.byWidgetPredicate(
        (widget) =>
            widget is TextField &&
            widget.controller?.text == 'Answer root-child-child-child-child',
      );
      await tester.scrollUntilVisible(
        deepAnswer,
        160,
        scrollable: scrollable,
        maxScrolls: 100,
      );
      final controller = tester.widget<TextField>(deepAnswer).controller;
      final answer = find.byWidgetPredicate(
        (widget) =>
            widget is TextField && identical(widget.controller, controller),
      );
      await _tap(tester, answer);
      await tester.enterText(answer, 'Phone deep answer');
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pumpAndSettle();
      await tester.ensureVisible(answer);
      await tester.pumpAndSettle();
      final activeBar = find.byKey(
        const ValueKey('guest-active-participant-bar'),
      );
      expect(activeBar, findsOneWidget);
      expect(tester.getRect(activeBar).bottom, lessThanOrEqualTo(420));
      expect(find.byTooltip('Add a question'), findsNothing);
      await tester.scrollUntilVisible(
        find.byTooltip('Add participant'),
        -160,
        scrollable: scrollable,
      );
      await _tap(tester, find.byTooltip('Add participant'));
      await tester.enterText(
        _field('Participant name'),
        'Keyboard participant',
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.text('Add to Group draft'), findsNothing);
      await tester.scrollUntilVisible(
        find.text('Add shared question'),
        160,
        scrollable: scrollable,
        maxScrolls: 100,
      );
      await _tap(tester, find.text('Add shared question'));
      await tester.enterText(
        find.descendant(
          of: find.byType(AlertDialog).last,
          matching: find.byType(TextFormField),
        ),
        'Keyboard question',
      );
      await _tap(tester, find.widgetWithText(FilledButton, 'Add question'));
      await _tap(tester, find.text('Save Group copy'));
      expect(repository.entry['data']['participants'], hasLength(3));
      expect(
        jsonEncode(repository.entry['data']),
        contains('Keyboard question'),
      );
      expect(
        jsonEncode(repository.entry['data']),
        contains('Phone deep answer'),
      );
      expect(repository.writes, hasLength(1));
      await _tap(tester, find.byTooltip('Close Group editor'));
      expect(find.text('Edit shared copy'), findsNothing);
    },
  );

  testWidgets(
    'narrow phone keyboard long deep branches keep editing controls reachable',
    (tester) async {
      tester.view.physicalSize = const Size(320, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      final repository = _Repository(depth: 4);
      await _mount(tester, repository);
      final scrollable = find
          .descendant(
            of: find.byKey(const ValueKey('guest-session-editor-scroll')),
            matching: find.byType(Scrollable),
          )
          .first;
      await tester.scrollUntilVisible(
        find.text('Follow-up 1'),
        160,
        scrollable: scrollable,
        maxScrolls: 100,
      );
      final field = find.byKey(
        const ValueKey('guest-question-text-root-child-child-child-child'),
      );
      await _tap(tester, field);
      await tester.enterText(
        field,
        List.filled(12, 'Long nested question').join(' '),
      );
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      tester.view.resetViewInsets();
      await tester.pumpAndSettle();
      await _tap(tester, find.text('Save Group copy'));
      expect(repository.writes, hasLength(1));
      expect(
        jsonEncode(repository.entry['data']),
        contains('Long nested question'),
      );
      expect(repository.entry['revision'], 2);
    },
  );
}
