import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:int_qa_flow/app.dart';
import 'package:int_qa_flow/core/auth/auth_providers.dart';
import 'package:int_qa_flow/core/auth/sign_in_page.dart';
import 'package:int_qa_flow/features/guest/data/guest_group_repository.dart';
import 'package:int_qa_flow/features/guest/data/personal_workspace_repository.dart';
import 'package:int_qa_flow/features/guest/data/guest_storage_interface.dart';
import 'package:int_qa_flow/features/guest/data/guest_workspace_store.dart';
import 'package:int_qa_flow/features/guest/domain/guest_workspace_data.dart';
import 'package:int_qa_flow/features/guest/presentation/guest_workspace_page.dart';
import 'package:int_qa_flow/shared/widgets/app_shell.dart';

class _TestUser extends Fake implements User {
  _TestUser({
    required this.isAnonymous,
    this.isEmailVerified = false,
    this.testUid = 'account-uid',
  });

  @override
  bool isAnonymous;

  @override
  bool get emailVerified => isEmailVerified;

  final bool isEmailVerified;

  @override
  String? get email => 'account@example.test';

  @override
  String get uid => testUid;

  final String testUid;
  int verificationEmailAttempts = 0;
  int linkAttempts = 0;
  int reloadAttempts = 0;

  @override
  Future<void> sendEmailVerification([
    ActionCodeSettings? actionCodeSettings,
  ]) async {
    verificationEmailAttempts++;
  }

  @override
  Future<void> reload() async {
    reloadAttempts++;
  }

  @override
  Future<UserCredential> linkWithCredential(AuthCredential credential) async {
    linkAttempts++;
    isAnonymous = false;
    return _TestUserCredential(this);
  }
}

class _TestUserCredential extends Fake implements UserCredential {
  _TestUserCredential(this.user);

  @override
  final User? user;
}

class _TestFirebaseAuth extends Fake implements FirebaseAuth {
  _TestFirebaseAuth(
    this.currentUser, {
    this.createError,
    this.signInError,
  });

  @override
  final User? currentUser;

  @override
  Stream<User?> authStateChanges() => Stream.value(currentUser);

  final FirebaseAuthException? createError;
  final FirebaseAuthException? signInError;
  int createAttempts = 0;
  int signInAttempts = 0;
  int signOutAttempts = 0;
  UserCredential? createCredential;
  UserCredential? signInCredential;
  String? lastSignInEmail;
  String? lastSignInPassword;

  @override
  Future<UserCredential> createUserWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    createAttempts++;
    if (createError != null) throw createError!;
    if (createCredential != null) return createCredential!;
    throw StateError('Unexpected account creation.');
  }

  @override
  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    signInAttempts++;
    lastSignInEmail = email;
    lastSignInPassword = password;
    if (signInError != null) throw signInError!;
    if (signInCredential != null) return signInCredential!;
    throw StateError('Unexpected sign-in.');
  }

  @override
  Future<void> signOut() async {
    signOutAttempts++;
  }
}

class _UnexpectedSignInAuth extends _TestFirebaseAuth {
  _UnexpectedSignInAuth() : super(null);

  @override
  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    signInAttempts++;
    throw StateError('private transport detail');
  }
}

class _MemoryGuestStorage implements GuestStorage {
  String? value;

  @override
  String? read() => value;

  @override
  void write(String value) => this.value = value;

  @override
  void remove() => value = null;
}

class _TestGuestGroupRepository extends GuestGroupRepository {
  _TestGuestGroupRepository(this.groups, this.details) : super(Dio());

  final List<Map<String, dynamic>> groups;
  final Map<String, Map<String, dynamic>> details;
  var listGroupsCalls = 0;
  var listArchivedGroupsCalls = 0;
  var getGroupCalls = 0;

  @override
  Future<List<Map<String, dynamic>>> listGroups() async {
    listGroupsCalls++;
    return groups;
  }

  @override
  Future<List<Map<String, dynamic>>> listArchivedGroups() async {
    listArchivedGroupsCalls++;
    return const [];
  }

  @override
  Future<Map<String, dynamic>> getGroup(String groupId) async {
    getGroupCalls++;
    return details[groupId]!;
  }
}

class _TestPersonalWorkspaceRepository extends PersonalWorkspaceRepository {
  _TestPersonalWorkspaceRepository(this.items) : super(Dio());

  List<Map<String, dynamic>> items;
  var listCalls = 0;
  var failedImports = 0;
  int? importFailureStatus;
  final imports = <List<Map<String, dynamic>>>[];
  int updateConflicts = 0;
  List<Map<String, dynamic>>? conflictItems;
  final updateRevisions = <int>[];
  var deleteCalls = 0;

  @override
  Future<List<Map<String, dynamic>>> listItems({
    required String expectedUid,
  }) async {
    listCalls++;
    return items;
  }

  @override
  Future<List<Map<String, dynamic>>> importItems(
    List<Map<String, dynamic>> payload, {
    required String expectedUid,
  }) async {
    imports.add(payload);
    if (failedImports > 0) {
      failedImports--;
      if (importFailureStatus != null) {
        final request = RequestOptions(path: '/api/v1/personal/items/import');
        throw DioException(
          requestOptions: request,
          response: Response(
            requestOptions: request,
            statusCode: importFailureStatus,
          ),
        );
      }
      throw StateError('Simulated uncertain response.');
    }
    return [
      for (final item in payload)
        {
          ...item,
          'id': 'record-${item['source_key']}',
          'revision': 1,
          'created_at': '2026-10-06T00:00:00+00:00',
          'updated_at': '2026-10-06T00:00:00+00:00',
        },
    ];
  }

  @override
  Future<Map<String, dynamic>> updateItem({
    required String id,
    required String expectedUid,
    required int expectedRevision,
    required String title,
    required Map<String, dynamic> data,
  }) async {
    updateRevisions.add(expectedRevision);
    if (updateConflicts > 0) {
      updateConflicts--;
      items = conflictItems ?? items;
      final request = RequestOptions(path: '/api/v1/personal/items/$id');
      throw DioException(
        requestOptions: request,
        response: Response(
          requestOptions: request,
          statusCode: 409,
        ),
      );
    }
    final current = items.firstWhere((item) => item['id'] == id);
    final saved = {
      ...current,
      'title': title,
      'data': data,
      'revision': expectedRevision + 1,
    };
    items = [
      for (final item in items)
        if (item['id'] == id) saved else item,
    ];
    return saved;
  }

  @override
  Future<void> deleteItem(
    String id, {
    required String expectedUid,
    required int expectedRevision,
  }) async {
    deleteCalls++;
  }
}

class _SignInLauncher extends StatelessWidget {
  const _SignInLauncher();

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: TextButton(
        onPressed: () => Navigator.of(context).push<void>(
          MaterialPageRoute<void>(
            builder: (_) => const SignInPage(createAccount: true),
          ),
        ),
        child: const Text('Open personal account creation'),
      ),
    ),
  );
}

Future<void> _expectSeparateAccountError(
  WidgetTester tester, {
  required String code,
  required String expectedMessage,
}) async {
  final auth = _TestFirebaseAuth(
    null,
    createError: FirebaseAuthException(
      code: code,
      message: 'Sensitive credential details must not be shown.',
    ),
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [firebaseAuthProvider.overrideWithValue(auth)],
      child: const MaterialApp(home: SignInPage(createAccount: true)),
    ),
  );
  await tester.enterText(find.byType(TextField).first, 'new@example.test');
  await tester.enterText(find.byType(TextField).last, 'secret-password');
  final passwordField = tester.widget<TextField>(find.byType(TextField).last);
  expect(passwordField.obscureText, isTrue);
  await tester.tap(
    find.widgetWithText(FilledButton, 'Create account'),
  );
  await tester.pumpAndSettle();

  expect(find.textContaining(expectedMessage), findsOneWidget);
  final renderedMessages = tester.widgetList<Text>(
    find.descendant(
      of: find.byType(SignInPage),
      matching: find.byType(Text),
    ),
  );
  final renderedMessageText = renderedMessages.map((widget) => widget.data ?? '');
  expect(
    renderedMessageText,
    isNot(contains('Sensitive credential details must not be shown.')),
  );
  expect(renderedMessageText, isNot(contains('secret-password')));
  expect(auth.createAttempts, 1);
}

void main() {
  Future<void> pumpGuestWorkspace(
    WidgetTester tester, {
    User? user,
    AccountMembershipStatus? membershipStatus,
    bool sharedIdentityActive = false,
    bool authUnavailable = false,
    GuestWorkspaceStore? store,
    List<Map<String, dynamic>> existingGuestGroups =
        const <Map<String, dynamic>>[],
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          guestWorkspaceStoreProvider.overrideWithValue(
            store ?? GuestWorkspaceStore(_MemoryGuestStorage()),
          ),
          currentGuestGroupsProvider.overrideWith(
            (ref) async => existingGuestGroups,
          ),
          firebaseAuthProvider.overrideWithValue(_TestFirebaseAuth(user)),
        ],
        child: MaterialApp(
          home: GuestWorkspacePage(
            firebaseReady: true,
            accountUser: user,
            membershipStatus: membershipStatus,
            sharedIdentityActive: sharedIdentityActive,
            authUnavailable: authUnavailable,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'local guest account menu explains local-only work',
    (tester) async {
      await pumpGuestWorkspace(tester);

      expect(find.text('Guest workspace · Saved on this device'), findsOneWidget);
      final groupsButton = tester.widget<IconButton>(
        find.byWidgetPredicate(
          (widget) =>
              widget is IconButton && widget.tooltip == 'Groups',
        ),
      );
      expect((groupsButton.icon as Icon).icon, Icons.group_outlined);
      expect(
        find.textContaining('People using this profile can see its local work.'),
        findsNothing,
      );
      await tester.tap(find.byTooltip('Workspace storage information'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('People using this profile can see its local work.'),
        findsOneWidget,
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);

      await tester.tap(find.byTooltip('Account'));
      await tester.pumpAndSettle();
      expect(find.text('Local guest workspace'), findsOneWidget);
      expect(find.text('Already have an account? Sign in'), findsOneWidget);
      expect(find.text('Create account'), findsOneWidget);
      expect(find.text('Sign out'), findsNothing);
    },
  );

  testWidgets('local workspace does not access Firebase when unavailable', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          guestWorkspaceStoreProvider.overrideWithValue(
            GuestWorkspaceStore(_MemoryGuestStorage()),
          ),
        ],
        child: const MaterialApp(
          home: GuestWorkspacePage(firebaseReady: false),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('IntQAFlow guest workspace'), findsOneWidget);
    expect(find.byTooltip('Groups'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'leaving sign-in keeps the local workspace available',
    (tester) async {
      final store = GuestWorkspaceStore(_MemoryGuestStorage());
      await store.save(
        const GuestWorkspaceData(
          sessions: [
            {
              'id': 'local-session',
              'title': 'Work in progress',
              'participants': [],
              'questions': [],
            },
          ],
        ),
      );
      await pumpGuestWorkspace(tester, store: store);

      await tester.tap(find.byTooltip('Account'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Already have an account? Sign in'));
      await tester.pumpAndSettle();
      expect(find.text('Back to workspace'), findsOneWidget);
      await tester.tap(find.text('Back to workspace'));
      await tester.pumpAndSettle();

      expect(find.text('IntQAFlow guest workspace'), findsOneWidget);
      await tester.tap(find.text('Interact').first);
      await tester.pumpAndSettle();
      expect(find.text('Work in progress'), findsOneWidget);

      final saved = await store.load();
      expect(saved.sessions.single['title'], 'Work in progress');
    },
  );

  testWidgets('local-work clear option clears only the device copy', (
    tester,
  ) async {
    final store = GuestWorkspaceStore(_MemoryGuestStorage());
    await store.save(
      const GuestWorkspaceData(
        sessions: [
          {
            'id': 'local-session',
            'title': 'Keep or clear me',
            'participants': [],
            'questions': [],
          },
        ],
      ),
    );
    await pumpGuestWorkspace(tester, store: store);
    await tester.tap(find.byTooltip('Guest workspace options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Clear local guest copy'));
    await tester.pumpAndSettle();
    expect(find.text('Clear this device’s local work?'), findsOneWidget);
    await tester.tap(find.text('Keep my work'));
    await tester.pumpAndSettle();
    expect((await store.load()).sessions.single['title'], 'Keep or clear me');

    await tester.tap(find.byTooltip('Guest workspace options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Clear local guest copy'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Clear local copy'));
    await tester.pumpAndSettle();

    expect((await store.load()).sessions, isEmpty);
  });

  testWidgets('anonymous auth is treated as a local guest workspace', (
    tester,
  ) async {
    await pumpGuestWorkspace(
      tester,
      user: _TestUser(isAnonymous: true),
      sharedIdentityActive: true,
    );

    expect(find.text('Guest workspace · Saved on this device'), findsOneWidget);
    await tester.tap(find.byTooltip('Workspace storage information'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining(
        'Guest workspace active in this browser profile.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Account'));
    await tester.pumpAndSettle();
    expect(find.text('Local guest workspace'), findsOneWidget);
    expect(find.text('Already have an account? Sign in'), findsOneWidget);
    expect(find.text('Create account'), findsOneWidget);
    expect(find.text('Create account from this guest'), findsNothing);
    expect(find.text('Start fresh with a separate account'), findsNothing);
    expect(find.text('Sign out'), findsNothing);
    expect(find.text('Organisation admin'), findsNothing);
  });

  testWidgets('local guest account creation uses normal registration', (
    tester,
  ) async {
    final user = _TestUser(isAnonymous: true);
    final registered = _TestUser(isAnonymous: false);
    final auth = _TestFirebaseAuth(user)
      ..createCredential = _TestUserCredential(registered);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          firebaseAuthProvider.overrideWithValue(auth),
          guestWorkspaceStoreProvider.overrideWithValue(
            GuestWorkspaceStore(_MemoryGuestStorage()),
          ),
        ],
        child: MaterialApp(
          home: GuestWorkspacePage(
            firebaseReady: true,
            accountUser: user,
            sharedIdentityActive: true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Account'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create account'));
    await tester.pumpAndSettle();

    expect(find.byType(SignInPage), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Create account'), findsOneWidget);
    expect(
      find.textContaining('A personal account is separate from local work.'),
      findsOneWidget,
    );

    await tester.enterText(find.byType(TextField).first, 'account@example.test');
    await tester.enterText(find.byType(TextField).last, 'secure-passphrase');
    await tester.tap(find.widgetWithText(FilledButton, 'Create account'));
    await tester.pumpAndSettle();

    expect(user.linkAttempts, 0);
    expect(user.isAnonymous, isTrue);
    expect(auth.createAttempts, 1);
    expect(auth.signInAttempts, 0);
  });

  testWidgets('personal workspace data is cleared between account identities', (
    tester,
  ) async {
    Map<String, dynamic> personalItem(String id, String title) => {
      'id': 'record-$id',
      'kind': 'knowledge',
      'source_key': 'knowledge:$id',
      'title': title,
      'data': {'id': id, 'title': title, 'body': 'Private content'},
      'revision': 1,
      'created_at': '2026-10-06T00:00:00+00:00',
      'updated_at': '2026-10-06T00:00:00+00:00',
    };

    final repository = _TestPersonalWorkspaceRepository([
      personalItem('a', 'Account A private item'),
    ]);
    final storage = GuestWorkspaceStore(_MemoryGuestStorage());
    Widget page(User user) => ProviderScope(
      overrides: [
        firebaseAuthProvider.overrideWithValue(_TestFirebaseAuth(user)),
        guestWorkspaceStoreProvider.overrideWithValue(storage),
        personalWorkspaceRepositoryProvider.overrideWithValue(repository),
      ],
      child: MaterialApp(
        home: GuestWorkspacePage(
          firebaseReady: true,
          personalWorkspaceEnabled: true,
          accountUser: user,
        ),
      ),
    );

    await tester.pumpWidget(
      page(_TestUser(isAnonymous: false, isEmailVerified: true, testUid: 'a')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Saved Q&A'));
    await tester.pumpAndSettle();
    expect(find.text('Account A private item'), findsOneWidget);
    expect((await storage.load()).knowledge, isEmpty);
    await tester.tap(find.text('Back to add a local question'));
    await tester.pumpAndSettle();

    repository.items = [personalItem('b', 'Account B private item')];
    await tester.pumpWidget(
      page(_TestUser(isAnonymous: false, isEmailVerified: true, testUid: 'b')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Saved Q&A'));
    await tester.pumpAndSettle();

    expect(find.text('Account A private item'), findsNothing);
    expect(find.text('Account B private item'), findsOneWidget);
    expect(repository.listCalls, 2);
    expect((await storage.load()).knowledge, isEmpty);
  });

  testWidgets('clearing local work does not delete personal account items', (
    tester,
  ) async {
    final store = GuestWorkspaceStore(_MemoryGuestStorage());
    await store.save(
      const GuestWorkspaceData(
        knowledge: [
          {'id': 'local-id', 'title': 'Local item', 'body': 'Local'},
        ],
      ),
    );
    final repository = _TestPersonalWorkspaceRepository([
      {
        'id': 'remote-record',
        'kind': 'knowledge',
        'source_key': 'knowledge:remote-id',
        'title': 'Personal account item',
        'data': {
          'id': 'remote-id',
          'title': 'Personal account item',
          'body': 'Remote',
        },
        'revision': 1,
        'created_at': '2026-10-06T00:00:00+00:00',
        'updated_at': '2026-10-06T00:00:00+00:00',
      },
    ]);
    final user = _TestUser(isAnonymous: false, isEmailVerified: true);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          firebaseAuthProvider.overrideWithValue(_TestFirebaseAuth(user)),
          guestWorkspaceStoreProvider.overrideWithValue(store),
          personalWorkspaceRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp(
          home: GuestWorkspacePage(
            firebaseReady: true,
            personalWorkspaceEnabled: true,
            accountUser: user,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Workspace options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Clear local copy on this device'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Clear local copy'));
    await tester.pumpAndSettle();

    expect((await store.load()).knowledge, isEmpty);
    await tester.tap(find.text('Saved Q&A'));
    await tester.pumpAndSettle();
    expect(find.text('Personal account item'), findsOneWidget);
    expect(repository.deleteCalls, 0);
  });

  testWidgets('personal import retries selected items without removing locals', (
    tester,
  ) async {
    final localData = GuestWorkspaceData(
      knowledge: [
        {'id': 'selected', 'title': 'Import this item', 'body': 'Selected'},
        {'id': 'local-only', 'title': 'Keep this item local', 'body': 'Private'},
      ],
    );
    final store = GuestWorkspaceStore(_MemoryGuestStorage());
    await store.save(localData);
    final repository = _TestPersonalWorkspaceRepository([])..failedImports = 1;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          firebaseAuthProvider.overrideWithValue(
            _TestFirebaseAuth(
              _TestUser(isAnonymous: false, isEmailVerified: true),
            ),
          ),
          guestWorkspaceStoreProvider.overrideWithValue(store),
          personalWorkspaceRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp(
          home: GuestWorkspacePage(
            firebaseReady: true,
            personalWorkspaceEnabled: true,
            accountUser: _TestUser(isAnonymous: false, isEmailVerified: true),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Import local work'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Keep this item local'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Import selected work'));
    await tester.pumpAndSettle();

    expect(repository.imports, hasLength(1));
    expect(repository.imports.single, hasLength(1));
    expect(repository.imports.single.single['source_key'], 'knowledge:selected');
    expect(find.text('Retry import'), findsOneWidget);
    await tester.tap(find.text('Retry import'));
    await tester.pumpAndSettle();

    expect(repository.imports, hasLength(2));
    expect(
      repository.imports[0].single['source_key'],
      repository.imports[1].single['source_key'],
    );
    expect((await store.load()).knowledge, hasLength(2));
    await tester.tap(find.text('Saved Q&A'));
    await tester.pumpAndSettle();
    final savedListScrollable = find
        .ancestor(
          of: find.text('Back to add a local question'),
          matching: find.byType(Scrollable),
        )
        .first;
    expect(
      tester.widget<Scrollable>(savedListScrollable).axisDirection,
      AxisDirection.down,
    );
    await tester.scrollUntilVisible(
      find.text('Keep this item local'),
      250,
      scrollable: savedListScrollable,
    );
    expect(find.text('Import this item'), findsOneWidget);
    expect(find.text('Keep this item local'), findsOneWidget);
  });

  testWidgets('permanent import limit errors ask for a smaller selection', (
    tester,
  ) async {
    final store = GuestWorkspaceStore(_MemoryGuestStorage());
    await store.save(
      const GuestWorkspaceData(
        knowledge: [
          {'id': 'large', 'title': 'Large item', 'body': 'Keep the local copy'},
          {'id': 'small', 'title': 'Small item', 'body': 'Keep this too'},
        ],
      ),
    );
    final repository = _TestPersonalWorkspaceRepository([])
      ..failedImports = 1
      ..importFailureStatus = 422;
    final user = _TestUser(isAnonymous: false, isEmailVerified: true);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          firebaseAuthProvider.overrideWithValue(_TestFirebaseAuth(user)),
          guestWorkspaceStoreProvider.overrideWithValue(store),
          personalWorkspaceRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp(
          home: GuestWorkspacePage(
            firebaseReady: true,
            personalWorkspaceEnabled: true,
            accountUser: user,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Import local work'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Import selected work'));
    await tester.pumpAndSettle();

    expect(repository.imports, hasLength(1));
    expect(find.textContaining('Select fewer items or smaller items'), findsOneWidget);
    expect(find.text('Change selection'), findsOneWidget);
    expect(find.text('Retry import'), findsNothing);
    expect((await store.load()).knowledge, hasLength(2));

    await tester.tap(find.text('Change selection'));
    await tester.pumpAndSettle();
    expect(find.text('Import selected work'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(repository.imports, hasLength(1));
  });

  testWidgets('revision conflicts reload before an explicit pending-edit save', (
    tester,
  ) async {
    Map<String, dynamic> item({
      required String title,
      required int revision,
    }) => {
      'id': 'remote-record',
      'kind': 'knowledge',
      'source_key': 'knowledge:remote-id',
      'title': title,
      'data': {
        'id': 'remote-id',
        'title': title,
        'body': 'Remote details',
        'answer': 'Remote answer',
      },
      'revision': revision,
      'created_at': '2026-10-06T00:00:00+00:00',
      'updated_at': '2026-10-06T00:00:00+00:00',
    };

    final latestAccountItem = item(title: 'Latest account title', revision: 2);
    final repository = _TestPersonalWorkspaceRepository([
      item(title: 'Original account title', revision: 1),
    ])
      ..updateConflicts = 1
      ..conflictItems = [latestAccountItem];
    final user = _TestUser(isAnonymous: false, isEmailVerified: true);
    final store = GuestWorkspaceStore(_MemoryGuestStorage());
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          firebaseAuthProvider.overrideWithValue(_TestFirebaseAuth(user)),
          guestWorkspaceStoreProvider.overrideWithValue(store),
          personalWorkspaceRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp(
          home: GuestWorkspacePage(
            firebaseReady: true,
            personalWorkspaceEnabled: true,
            accountUser: user,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Saved Q&A'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Edit personal-account Knowledge'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextFormField),
      ).first,
      'My pending edit',
    );
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Save account changes'),
      ),
    );
    await tester.pumpAndSettle();

    expect(repository.updateRevisions, [1]);
    expect(find.text('My pending edit'), findsOneWidget);
    await tester.tap(find.text('Review account change'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Latest saved version (revision 2)'), findsOneWidget);
    expect(find.text('Your pending edit: My pending edit'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('My pending edit'), findsOneWidget);

    await tester.tap(find.text('Review account change'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save my pending edit'));
    await tester.pumpAndSettle();

    expect(repository.updateRevisions, [1, 2]);
    expect(find.text('My pending edit'), findsOneWidget);
    expect(find.text('Latest account title'), findsNothing);
  });

  testWidgets('editing an imported nested session updates the account copy', (
    tester,
  ) async {
    final session = <String, dynamic>{
      'id': 'session-id',
      'title': 'Imported nested session',
      'participants': [
        {'id': 'alice', 'name': 'Alice'},
      ],
      'questions': [
        {
          'id': 'root-question',
          'text': 'Root question',
          'scope': 'shared',
          'answers': [
            {
              'participant_id': 'alice',
              'body': 'Original answer',
              'branches_collapsed': false,
              'follow_ups': [
                {
                  'id': 'nested-question',
                  'text': 'Existing nested follow-up',
                  'scope': 'participant',
                  'target_participant_id': 'alice',
                  'answers': [
                    {
                      'participant_id': 'alice',
                      'body': 'Nested answer',
                      'branches_collapsed': false,
                      'follow_ups': <Map<String, dynamic>>[],
                    },
                  ],
                },
              ],
            },
          ],
        },
      ],
    };
    final repository = _TestPersonalWorkspaceRepository([
      {
        'id': 'remote-session',
        'kind': 'interact_session',
        'source_key': 'interact_session:session-id',
        'title': 'Imported nested session',
        'data': session,
        'revision': 1,
        'created_at': '2026-10-06T00:00:00+00:00',
        'updated_at': '2026-10-06T00:00:00+00:00',
      },
    ]);
    final store = GuestWorkspaceStore(_MemoryGuestStorage());
    final user = _TestUser(isAnonymous: false, isEmailVerified: true);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          firebaseAuthProvider.overrideWithValue(_TestFirebaseAuth(user)),
          guestWorkspaceStoreProvider.overrideWithValue(store),
          personalWorkspaceRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp(
          home: GuestWorkspacePage(
            firebaseReady: true,
            personalWorkspaceEnabled: true,
            accountUser: user,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Interact'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Imported nested session'));
    await tester.pumpAndSettle();

    expect(find.text('Existing nested follow-up'), findsOneWidget);
    final answer = find
        .byWidgetPredicate(
          (widget) =>
              widget is TextField &&
              widget.decoration?.labelText == 'Personal-account answer',
        )
        .first;
    await tester.ensureVisible(answer);
    await tester.enterText(answer, 'Updated account answer');
    await tester.pumpAndSettle();

    expect(repository.updateRevisions, [1]);
    final savedSession = repository.items.single['data'] as Map;
    final rootQuestion = (savedSession['questions'] as List).single as Map;
    final rootAnswer = (rootQuestion['answers'] as List).single as Map;
    expect(rootAnswer['body'], 'Updated account answer');
    expect(
      ((rootAnswer['follow_ups'] as List).single as Map)['text'],
      'Existing nested follow-up',
    );
    expect((await store.load()).sessions, isEmpty);
    expect(find.textContaining('Personal account · saved'), findsOneWidget);
  });

  testWidgets('new local work is not uploaded before explicit import', (
    tester,
  ) async {
    final storage = _MemoryGuestStorage();
    final store = GuestWorkspaceStore(storage);
    final repository = _TestPersonalWorkspaceRepository([]);
    final user = _TestUser(isAnonymous: false, isEmailVerified: true);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          firebaseAuthProvider.overrideWithValue(_TestFirebaseAuth(user)),
          guestWorkspaceStoreProvider.overrideWithValue(store),
          personalWorkspaceRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp(
          home: GuestWorkspacePage(
            firebaseReady: true,
            personalWorkspaceEnabled: true,
            accountUser: user,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextFormField).first,
      'Keep this Knowledge item local',
    );
    final saveLocally = find.text('Save locally');
    final addQuestionScrollable = find
        .ancestor(
          of: find.text('Add a local question'),
          matching: find.byType(Scrollable),
        )
        .first;
    expect(
      tester.widget<Scrollable>(addQuestionScrollable).axisDirection,
      AxisDirection.down,
    );
    await tester.scrollUntilVisible(
      saveLocally,
      250,
      scrollable: addQuestionScrollable,
    );
    await tester.pumpAndSettle();
    await Scrollable.ensureVisible(
      tester.element(saveLocally),
      alignment: 0.5,
    );
    await tester.pumpAndSettle();
    await tester.tap(saveLocally.hitTestable());
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    expect(repository.imports, isEmpty);
    expect(
      (await store.load()).knowledge.single['title'],
      'Keep this Knowledge item local',
    );
  });

  testWidgets('existing-account sign-in errors do not reveal Firebase details', (
    tester,
  ) async {
    final auth = _TestFirebaseAuth(
      null,
      signInError: FirebaseAuthException(
        code: 'invalid-credential',
        message: 'Sensitive credential details must not be shown.',
      ),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [firebaseAuthProvider.overrideWithValue(auth)],
        child: const MaterialApp(home: SignInPage()),
      ),
    );
    await tester.enterText(find.byType(TextField).first, 'account@example.test');
    await tester.enterText(find.byType(TextField).last, 'secret-password');
    expect(
      tester.widget<TextField>(find.byType(TextField).last).obscureText,
      isTrue,
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();

    expect(auth.signInAttempts, 1);
    expect(
      find.text('Sign-in failed. Check your email and password and try again.'),
      findsOneWidget,
    );
    final renderedText = tester.widgetList<Text>(
      find.descendant(
        of: find.byType(SignInPage),
        matching: find.byType(Text),
      ),
    ).map((widget) => widget.data ?? '');
    expect(
      renderedText.any(
        (text) => text.contains('Sensitive credential details'),
      ),
      isFalse,
    );
    expect(
      renderedText.any((text) => text.contains('secret-password')),
      isFalse,
    );
  });

  testWidgets('unexpected sign-in errors show a safe recovery message', (
    tester,
  ) async {
    final auth = _UnexpectedSignInAuth();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [firebaseAuthProvider.overrideWithValue(auth)],
        child: const MaterialApp(home: SignInPage()),
      ),
    );
    await tester.enterText(find.byType(TextField).first, 'account@example.test');
    await tester.enterText(find.byType(TextField).last, 'secret-password');
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();

    expect(auth.signInAttempts, 1);
    expect(
      find.text('Unable to complete this account request. Please try again.'),
      findsOneWidget,
    );
    final renderedText = tester.widgetList<Text>(
      find.descendant(
        of: find.byType(SignInPage),
        matching: find.byType(Text),
      ),
    ).map((widget) => widget.data ?? '');
    expect(
      renderedText.any((text) => text.contains('private transport')),
      isFalse,
    );
    expect(
      renderedText.any((text) => text.contains('secret-password')),
      isFalse,
    );
    expect(find.text('Please wait…'), findsNothing);
  });

  testWidgets('registered account without membership is not shown as signed out', (
    tester,
  ) async {
    await pumpGuestWorkspace(
      tester,
      user: _TestUser(isAnonymous: false),
      membershipStatus: AccountMembershipStatus.noMembership,
    );

    expect(
      find.textContaining('no organisation membership'),
      findsOneWidget,
    );
    await tester.tap(find.text('Account'));
    await tester.pumpAndSettle();
    expect(find.text('No organisation membership'), findsOneWidget);
    expect(find.text('Sign out'), findsOneWidget);
    expect(find.text('Sign in'), findsNothing);
    expect(find.text('Create account'), findsNothing);
  });

  testWidgets('unverified registered accounts see the Groups gate', (
    tester,
  ) async {
    await pumpGuestWorkspace(
      tester,
      user: _TestUser(isAnonymous: false),
      membershipStatus: AccountMembershipStatus.noMembership,
      existingGuestGroups: const [
        {'id': 'existing-group', 'name': 'Existing group', 'role': 'viewer'},
      ],
    );

    expect(find.byTooltip('Groups'), findsOneWidget);
    expect(
      find.textContaining('Verify this account’s email before using Groups'),
      findsOneWidget,
    );
    await tester.tap(find.byTooltip('Groups'));
    await tester.pumpAndSettle();
    expect(find.text('Verify your email to use Groups'), findsOneWidget);
    expect(
      find.textContaining(
        'Check your email for the verification link. After verifying,',
      ),
      findsOneWidget,
    );
    expect(find.text('Create an account'), findsNothing);
    expect(find.text('Create account'), findsNothing);
  });

  testWidgets('verified account without an organisation can open groups', (
    tester,
  ) async {
    await pumpGuestWorkspace(
      tester,
      user: _TestUser(isAnonymous: false, isEmailVerified: true),
      membershipStatus: AccountMembershipStatus.noMembership,
    );

    expect(find.textContaining('no organisation membership'), findsOneWidget);
    expect(find.byTooltip('Groups'), findsOneWidget);
    expect(find.byTooltip('Enable groups'), findsNothing);
  });

  testWidgets(
    'anonymous Groups prompt preserves local account flow without API calls',
    (tester) async {
      final guest = _TestUser(isAnonymous: true);
      final repository = _TestGuestGroupRepository(
        const [
          {'id': 'group-1', 'name': 'Existing group', 'role': 'admin'},
        ],
        const {
          'group-1': {
            'members': [
              {'id': 'member-1', 'role': 'admin', 'status': 'active'},
            ],
          },
        },
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            firebaseAuthProvider.overrideWithValue(_TestFirebaseAuth(guest)),
            guestGroupRepositoryProvider.overrideWithValue(repository),
            guestWorkspaceStoreProvider.overrideWithValue(
              GuestWorkspaceStore(_MemoryGuestStorage()),
            ),
          ],
          child: MaterialApp(
            home: GuestWorkspacePage(
              firebaseReady: true,
              accountUser: guest,
              sharedIdentityActive: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Groups'));
      await tester.pumpAndSettle();
      expect(find.text('Create an account to use Groups'), findsOneWidget);
      expect(repository.listGroupsCalls, 0);
      expect(repository.listArchivedGroupsCalls, 0);
      expect(repository.getGroupCalls, 0);

      await tester.tap(find.text('Create an account'));
      await tester.pumpAndSettle();
      expect(find.byType(SignInPage), findsOneWidget);
      expect(repository.listGroupsCalls, 0);
      expect(repository.getGroupCalls, 0);
    },
  );

  testWidgets('inactive and unavailable memberships are distinct states', (
    tester,
  ) async {
    for (final state in [
      AccountMembershipStatus.inactive,
      AccountMembershipStatus.unavailable,
    ]) {
      await pumpGuestWorkspace(
        tester,
        user: _TestUser(isAnonymous: false),
        membershipStatus: state,
      );
      await tester.tap(find.text('Account'));
      await tester.pumpAndSettle();
      expect(
        find.text(
          state == AccountMembershipStatus.inactive
              ? 'Organisation membership inactive'
              : 'Organisation membership unavailable',
        ),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    }
  });

  testWidgets('organisation account menu uses membership display metadata', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentMembershipProvider.overrideWith(
            (ref) async => const ActiveMembership(
              userId: 'user-1',
              organisationId: 'org-1',
              email: 'member@example.test',
              displayName: 'Member One',
              role: 'answer_owner',
            ),
          ),
          firebaseAuthProvider.overrideWithValue(
            _TestFirebaseAuth(
              _TestUser(isAnonymous: false, isEmailVerified: true),
            ),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: AppShell(
              currentPath: '/',
              child: Center(child: Text('Organisation content')),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Account'));
    await tester.pumpAndSettle();
    expect(find.text('Member One'), findsOneWidget);
    expect(find.text('member@example.test'), findsOneWidget);
    expect(find.text('Organisation workspace · answer_owner'), findsOneWidget);
    expect(
      find.text('Group roles are separate from organisation roles.'),
      findsOneWidget,
    );
    expect(find.text('Groups'), findsOneWidget);
    expect(find.text('Sign out'), findsOneWidget);
  });

  testWidgets('Groups navigation is hidden for anonymous and unverified users', (
    tester,
  ) async {
    for (final user in [
      _TestUser(isAnonymous: true),
      _TestUser(isAnonymous: false, isEmailVerified: false),
    ]) {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authStateProvider.overrideWith((ref) => Stream.value(user)),
            firebaseAuthProvider.overrideWithValue(_TestFirebaseAuth(user)),
            currentMembershipProvider.overrideWith(
              (ref) async => const ActiveMembership(
                userId: 'app-user',
                organisationId: 'org',
                email: 'member@example.test',
                displayName: 'Member',
                role: 'member',
              ),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: AppShell(
                currentPath: '/',
                child: Center(child: Text('Organisation content')),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Groups'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    }
  });

  testWidgets('registered account with no membership stays in local workspace', (
    tester,
  ) async {
    final user = _TestUser(isAnonymous: false);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith((ref) => Stream.value(user)),
          accountMembershipStatusProvider.overrideWith(
            (ref) async => AccountMembershipStatus.noMembership,
          ),
          firebaseAuthProvider.overrideWithValue(_TestFirebaseAuth(user)),
          guestWorkspaceStoreProvider.overrideWithValue(
            GuestWorkspaceStore(_MemoryGuestStorage()),
          ),
          currentGuestGroupsProvider.overrideWith(
            (ref) async => const <Map<String, dynamic>>[],
          ),
        ],
        child: const IntQaFlowApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('IntQAFlow workspace'), findsOneWidget);
    expect(find.text('IntQAFlow guest workspace'), findsNothing);
    expect(find.byTooltip('Workspace options'), findsOneWidget);
    expect(find.byTooltip('Guest workspace options'), findsNothing);
    expect(find.textContaining('guest'), findsNothing);
    expect(
      find.text(
        'Registered personal account · Local copy · Saved on this device',
      ),
      findsOneWidget,
    );
    await tester.tap(find.byTooltip('Workspace storage information'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining(
        'Local drafts stay in this browser profile and may be visible to people using it.',
      ),
      findsOneWidget,
    );
    expect(
      find.textContaining('Group and organisation access are separate'),
      findsOneWidget,
    );
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    expect(find.textContaining('no organisation membership'), findsOneWidget);
    expect(find.text('Checking account'), findsNothing);
    await tester.tap(find.text('Account'));
    await tester.pumpAndSettle();
    expect(find.text('No organisation membership'), findsOneWidget);
    expect(find.text('Sign out'), findsOneWidget);
    expect(find.text('Sign in'), findsNothing);
  });

  testWidgets('auth loading is not presented as a signed-out guest', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith((ref) => const Stream<User?>.empty()),
          firebaseAuthProvider.overrideWithValue(_TestFirebaseAuth(null)),
        ],
        child: const IntQaFlowApp(),
      ),
    );
    await tester.pump();

    expect(find.text('Checking account'), findsOneWidget);
    expect(find.text('IntQAFlow guest workspace'), findsNothing);
  });

  testWidgets('auth errors retain the signed-in status as unavailable', (
    tester,
  ) async {
    final user = _TestUser(isAnonymous: false);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith(
            (ref) => Stream<User?>.error(StateError('private test detail')),
          ),
          firebaseAuthProvider.overrideWithValue(_TestFirebaseAuth(user)),
          guestWorkspaceStoreProvider.overrideWithValue(
            GuestWorkspaceStore(_MemoryGuestStorage()),
          ),
          currentGuestGroupsProvider.overrideWith(
            (ref) async => const <Map<String, dynamic>>[],
          ),
        ],
        child: const IntQaFlowApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Account status could not be verified.'),
      findsOneWidget,
    );
    expect(find.text('private test detail'), findsNothing);
    await tester.tap(find.text('Account'));
    await tester.pumpAndSettle();
    expect(find.text('Account status unavailable'), findsOneWidget);
    expect(find.text('Retry account check'), findsOneWidget);
    expect(find.text('Sign out'), findsOneWidget);
    expect(find.text('Create account'), findsNothing);
  });

  testWidgets('membership lookup errors do not claim the account has no member', (
    tester,
  ) async {
    final user = _TestUser(isAnonymous: false);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith((ref) => Stream.value(user)),
          accountMembershipStatusProvider.overrideWith(
            (ref) async => throw StateError('private test detail'),
          ),
          firebaseAuthProvider.overrideWithValue(_TestFirebaseAuth(user)),
          guestWorkspaceStoreProvider.overrideWithValue(
            GuestWorkspaceStore(_MemoryGuestStorage()),
          ),
          currentGuestGroupsProvider.overrideWith(
            (ref) async => const <Map<String, dynamic>>[],
          ),
        ],
        child: const IntQaFlowApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.textContaining('could not be verified'),
      findsOneWidget,
    );
    expect(find.text('private test detail'), findsNothing);
    expect(find.text('No organisation membership'), findsNothing);
  });

  testWidgets('unverified accounts do not query Groups', (
    tester,
  ) async {
    final user = _TestUser(isAnonymous: false);
    var attempts = 0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith((ref) => Stream.value(user)),
          accountMembershipStatusProvider.overrideWith(
            (ref) async => AccountMembershipStatus.noMembership,
          ),
          firebaseAuthProvider.overrideWithValue(_TestFirebaseAuth(user)),
          guestWorkspaceStoreProvider.overrideWithValue(
            GuestWorkspaceStore(_MemoryGuestStorage()),
          ),
          currentGuestGroupsProvider.overrideWith((ref) async {
            attempts++;
            throw StateError('private test detail');
          }),
        ],
        child: MaterialApp(
          home: GuestWorkspacePage(
            firebaseReady: true,
            accountUser: user,
            membershipStatus: AccountMembershipStatus.noMembership,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Verify this account’s email before using Groups'),
      findsOneWidget,
    );
    expect(find.text('private test detail'), findsNothing);
    expect(find.text('No approved groups are linked to this identity.'), findsNothing);
    expect(attempts, 0);
  });

  testWidgets('registration from anonymous session uses separate account flow', (
    tester,
  ) async {
    final anonymousUser = _TestUser(isAnonymous: true);
    final registeredUser = _TestUser(isAnonymous: false);
    final auth = _TestFirebaseAuth(anonymousUser)
      ..createCredential = _TestUserCredential(registeredUser);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [firebaseAuthProvider.overrideWithValue(auth)],
        child: const MaterialApp(home: _SignInLauncher()),
      ),
    );
    await tester.tap(find.text('Open personal account creation'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'account@example.test');
    await tester.enterText(find.byType(TextField).last, 'secure-passphrase');
    await tester.tap(find.widgetWithText(FilledButton, 'Create account'));
    await tester.pumpAndSettle();

    expect(anonymousUser.linkAttempts, 0);
    expect(anonymousUser.isAnonymous, isTrue);
    expect(auth.createAttempts, 1);
    expect(registeredUser.verificationEmailAttempts, 1);
    expect(
      find.textContaining('nothing is uploaded unless you choose items'),
      findsOneWidget,
    );
  });

  testWidgets('account creation sends verification email', (tester) async {
    final user = _TestUser(isAnonymous: false);
    final auth = _TestFirebaseAuth(null)
      ..createCredential = _TestUserCredential(user);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          firebaseAuthProvider.overrideWithValue(auth),
        ],
        child: const MaterialApp(
          home: SignInPage(createAccount: true),
        ),
      ),
    );
    expect(
      find.textContaining('A personal account is separate from local work.'),
      findsOneWidget,
    );
    await tester.enterText(find.byType(TextField).first, 'new@example.test');
    await tester.enterText(find.byType(TextField).last, 'secure-passphrase');
    await tester.tap(find.widgetWithText(FilledButton, 'Create account'));
    await tester.pumpAndSettle();

    expect(auth.createAttempts, 1);
    expect(user.verificationEmailAttempts, 1);
    expect(
      find.textContaining('Check your email to verify it'),
      findsOneWidget,
    );
    expect(
      find.textContaining('nothing is uploaded unless you choose items'),
      findsOneWidget,
    );
  });

  testWidgets('separate signup explains an email already in use safely', (
    tester,
  ) async {
    await _expectSeparateAccountError(
      tester,
      code: 'email-already-in-use',
      expectedMessage:
          'An account already uses this email. Sign in or reset the password instead.',
    );
    expect(
      find.textContaining('guest identity remains active'),
      findsNothing,
    );
  });

  testWidgets('separate signup explains weak passwords safely', (tester) async {
    await _expectSeparateAccountError(
      tester,
      code: 'weak-password',
      expectedMessage:
          'Choose a stronger password and try creating the account again.',
    );
  });

  testWidgets('sign-in proceeds without local-work ownership confirmation', (
    tester,
  ) async {
    final auth = _TestFirebaseAuth(null)
      ..signInCredential = _TestUserCredential(
        _TestUser(isAnonymous: false, isEmailVerified: true),
      );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [firebaseAuthProvider.overrideWithValue(auth)],
        child: const MaterialApp(home: SignInPage()),
      ),
    );
    await tester.enterText(find.byType(TextField).first, ' member@example.test ');
    await tester.enterText(find.byType(TextField).last, 'safe-test-password');
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();

    expect(find.text('Sign in to your existing account?'), findsNothing);
    expect(find.text('Start fresh with a separate account?'), findsNothing);
    expect(auth.signInAttempts, 1);
    expect(auth.lastSignInEmail, 'member@example.test');
    expect(auth.lastSignInPassword, 'safe-test-password');
  });

  testWidgets('account creation does not prompt before normal registration', (
    tester,
  ) async {
    final auth = _TestFirebaseAuth(null)
      ..createCredential = _TestUserCredential(
        _TestUser(isAnonymous: false),
      );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [firebaseAuthProvider.overrideWithValue(auth)],
        child: const MaterialApp(
          home: SignInPage(createAccount: true),
        ),
      ),
    );
    await tester.enterText(find.byType(TextField).first, 'new@example.test');
    await tester.enterText(find.byType(TextField).last, 'safe-test-password');
    await tester.tap(find.widgetWithText(FilledButton, 'Create account'));
    await tester.pumpAndSettle();

    expect(find.text('Sign in to your existing account?'), findsNothing);
    expect(find.text('Start fresh with a separate account?'), findsNothing);
    expect(auth.createAttempts, 1);
  });

  testWidgets('sign-in errors are shown without guest ownership warnings', (
    tester,
  ) async {
    final auth = _TestFirebaseAuth(
      null,
      signInError: FirebaseAuthException(code: 'network-request-failed'),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [firebaseAuthProvider.overrideWithValue(auth)],
        child: const MaterialApp(
          home: SignInPage(),
        ),
      ),
    );
    await tester.enterText(find.byType(TextField).first, 'destination@example.test');
    await tester.enterText(find.byType(TextField).last, 'safe-test-password');
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();

    expect(find.text('Sign in to your existing account?'), findsNothing);
    expect(find.textContaining('group access'), findsNothing);
    expect(find.text('Keep this group identity'), findsNothing);
    expect(auth.signInAttempts, 1);
    expect(
      find.textContaining('Unable to reach the sign-in service'),
      findsOneWidget,
    );
  });

  testWidgets('opening sign-in never preflights Groups ownership', (
    tester,
  ) async {
    final guest = _TestUser(isAnonymous: true);
    final auth = _TestFirebaseAuth(guest);
    final repository = _TestGuestGroupRepository(
      const [
        {'id': 'sole-admin-group', 'name': 'Sole admin group', 'role': 'admin'},
      ],
      const {
        'sole-admin-group': {
          'members': [
            {'id': 'current-member', 'role': 'admin', 'status': 'active'},
          ],
        },
      },
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          firebaseAuthProvider.overrideWithValue(auth),
          guestGroupRepositoryProvider.overrideWithValue(repository),
          guestWorkspaceStoreProvider.overrideWithValue(
            GuestWorkspaceStore(_MemoryGuestStorage()),
          ),
        ],
        child: MaterialApp(
          home: GuestWorkspacePage(
            firebaseReady: true,
            accountUser: guest,
            sharedIdentityActive: true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Account'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Already have an account? Sign in'));
    await tester.pumpAndSettle();
    expect(repository.listGroupsCalls, 0);
    expect(repository.listArchivedGroupsCalls, 0);
    expect(repository.getGroupCalls, 0);
    await tester.enterText(find.byType(TextField).first, 'destination@example.test');
    await tester.enterText(find.byType(TextField).last, 'safe-test-password');
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();

    expect(auth.signInAttempts, 1);
    expect(find.text('Keep this group identity'), findsNothing);
    expect(identical(auth.currentUser, guest), isTrue);
  });
}
