import 'dart:async';

import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:int_qa_flow/app.dart';
import 'package:int_qa_flow/core/auth/auth_providers.dart';
import 'package:int_qa_flow/core/auth/sign_in_page.dart';
import 'package:int_qa_flow/features/guest/data/guest_group_repository.dart';
import 'package:int_qa_flow/features/guest/data/personal_workspace_repository.dart';
import 'package:int_qa_flow/features/guest/data/guest_storage_interface.dart';
import 'package:int_qa_flow/features/guest/data/guest_workspace_store.dart';
import 'package:int_qa_flow/features/guest/domain/guest_workspace_data.dart';
import 'package:int_qa_flow/features/guest/presentation/guest_workspace_page.dart';
import 'package:int_qa_flow/features/organisation/application/organisation_providers.dart';
import 'package:int_qa_flow/shared/widgets/app_shell.dart';
import 'package:int_qa_flow/shared/widgets/knowledge_section_tabs.dart';

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
  _TestFirebaseAuth(this.currentUser, {this.createError, this.signInError});

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
  Future<Map<String, dynamic>> Function(String query)? searchHandler;

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

  @override
  Future<Map<String, dynamic>> searchKnowledge(String query) =>
      searchHandler?.call(query) ??
      Future.value({'results': <Map<String, dynamic>>[], 'partial': false});
}

class _TestPersonalWorkspaceRepository extends PersonalWorkspaceRepository {
  _TestPersonalWorkspaceRepository(this.items) : super(Dio());

  List<Map<String, dynamic>> items;
  var listCalls = 0;
  var failedImports = 0;
  int? importFailureStatus;
  final imports = <List<Map<String, dynamic>>>[];
  final importUids = <String>[];
  int updateConflicts = 0;
  List<Map<String, dynamic>>? conflictItems;
  final updateRevisions = <int>[];
  var deleteCalls = 0;
  final searches = <(String, String)>[];
  Completer<List<Map<String, dynamic>>>? nextListResponse;
  Completer<void>? nextImportGate;
  Future<Map<String, dynamic>> Function(String query, String expectedUid)?
  searchHandler;

  @override
  Future<List<Map<String, dynamic>>> listItems({
    required String expectedUid,
  }) async {
    listCalls++;
    final response = nextListResponse;
    nextListResponse = null;
    if (response != null) return response.future;
    return items;
  }

  @override
  Future<Map<String, dynamic>> searchKnowledge(
    String query, {
    required String expectedUid,
  }) {
    searches.add((query, expectedUid));
    return searchHandler?.call(query, expectedUid) ??
        Future.value({'results': <Map<String, dynamic>>[], 'partial': false});
  }

  @override
  Future<List<Map<String, dynamic>>> importItems(
    List<Map<String, dynamic>> payload, {
    required String expectedUid,
  }) async {
    imports.add(payload);
    importUids.add(expectedUid);
    final gate = nextImportGate;
    nextImportGate = null;
    if (gate != null) await gate.future;
    final uncertainOutcome = failedImports > 0;
    if (uncertainOutcome) {
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
    }
    final imported = <Map<String, dynamic>>[];
    for (final item in payload) {
      final existing = items
          .where((record) => record['source_key'] == item['source_key'])
          .firstOrNull;
      if (existing != null) {
        imported.add(existing);
        continue;
      }
      final record = {
        ...item,
        'id': 'record-${item['source_key']}',
        'revision': 1,
        'created_at': '2026-10-06T00:00:00+00:00',
        'updated_at': '2026-10-06T00:00:00+00:00',
      };
      items = [...items, record];
      imported.add(record);
    }
    if (uncertainOutcome) throw StateError('Simulated uncertain response.');
    return imported;
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
        response: Response(requestOptions: request, statusCode: 409),
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
    items = items.where((item) => item['id'] != id).toList();
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
  await tester.tap(find.widgetWithText(FilledButton, 'Create account'));
  await tester.pumpAndSettle();

  expect(find.textContaining(expectedMessage), findsOneWidget);
  final renderedMessages = tester.widgetList<Text>(
    find.descendant(of: find.byType(SignInPage), matching: find.byType(Text)),
  );
  final renderedMessageText = renderedMessages.map(
    (widget) => widget.data ?? '',
  );
  expect(
    renderedMessageText,
    isNot(contains('Sensitive credential details must not be shown.')),
  );
  expect(renderedMessageText, isNot(contains('secret-password')));
  expect(auth.createAttempts, 1);
}

Future<void> _openGroupsFromPersonalOptions(WidgetTester tester) async {
  await tester.tap(
    find.byWidgetPredicate(
      (widget) =>
          widget is PopupMenuButton<String> &&
          (widget.tooltip == 'Workspace options' ||
              widget.tooltip == 'Guest workspace options'),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('Groups').last);
  await tester.pumpAndSettle();
}

Future<void> _ensureVisibleInVerticalList(
  WidgetTester tester,
  Finder target, {
  required Finder anchor,
}) async {
  final scrollable = find
      .ancestor(of: anchor, matching: find.byType(Scrollable))
      .first;
  expect(
    tester.widget<Scrollable>(scrollable).axisDirection,
    AxisDirection.down,
  );
  await tester.scrollUntilVisible(target, 220, scrollable: scrollable);
  await tester.pumpAndSettle();
  print(
    'DEBUG after scroll target=${target.evaluate().length} '
    'hit=${target.hitTestable().evaluate().length} '
    'scroll=${tester.state<ScrollableState>(scrollable).position.pixels} '
    'targetRect=${tester.getRect(target)} '
    'scrollRect=${tester.getRect(scrollable)} '
    'viewport=${tester.view.physicalSize}',
  );
  expect(target.hitTestable(), findsOneWidget);
}

Future<void> _tapVisibleTarget(WidgetTester tester, Finder target) async {
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  final hitTarget = target.hitTestable();
  expect(hitTarget, findsOneWidget);
  await tester.tap(hitTarget);
}

Future<void> _ensureVisibleInDialog(WidgetTester tester, Finder target) async {
  final scrollable = find
      .descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(Scrollable),
      )
      .first;
  await tester.scrollUntilVisible(target, 140, scrollable: scrollable);
  await tester.pumpAndSettle();
  await Scrollable.ensureVisible(tester.element(target.first), alignment: 0.5);
  await tester.pumpAndSettle();
  expect(target.hitTestable(), findsOneWidget);
}

Future<void> _tapPersonalNavigation(WidgetTester tester, String label) async {
  final railLabel = find.descendant(
    of: find.byType(NavigationRail),
    matching: find.text(label),
  );
  if (railLabel.evaluate().isNotEmpty) {
    final destination = find.ancestor(
      of: railLabel,
      matching: find.byType(InkResponse),
    );
    expect(destination, findsOneWidget);
    await tester.tap(destination);
  } else {
    final destination = find.ancestor(
      of: find.text(label),
      matching: find.byType(NavigationDestination),
    );
    expect(destination, findsOneWidget);
    await tester.tap(destination);
  }
  await tester.pumpAndSettle();
}

void main() {
  Future<void> pumpGuestWorkspace(
    WidgetTester tester, {
    User? user,
    AccountMembershipStatus? membershipStatus,
    bool personalWorkspaceEnabled = false,
    bool sharedIdentityActive = false,
    bool authUnavailable = false,
    GuestWorkspaceStore? store,
    PersonalWorkspaceRepository? personalRepository,
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
          if (personalRepository != null)
            personalWorkspaceRepositoryProvider.overrideWithValue(
              personalRepository,
            ),
        ],
        child: MaterialApp(
          home: GuestWorkspacePage(
            firebaseReady: true,
            personalWorkspaceEnabled: personalWorkspaceEnabled,
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

  Future<GoRouter> pumpPersonalRouter(
    WidgetTester tester, {
    required _TestUser user,
    required _TestPersonalWorkspaceRepository repository,
    required GuestWorkspaceStore store,
    Stream<User?>? authChanges,
    String initialLocation = '/personal/ask',
  }) async {
    tester.view.physicalSize = const Size(720, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    Widget page({
      int tab = 0,
      KnowledgeSection section = KnowledgeSection.ask,
    }) => Consumer(
      builder: (context, ref, _) => GuestWorkspacePage(
        firebaseReady: true,
        personalWorkspaceEnabled: true,
        accountUser: ref.watch(authStateProvider).value,
        membershipStatus: AccountMembershipStatus.active,
        initialWorkspaceTab: tab,
        initialKnowledgeSection: section,
      ),
    );
    final router = GoRouter(
      initialLocation: initialLocation,
      routes: [
        ShellRoute(
          builder: (context, state, child) =>
              AppShell(currentPath: state.uri.path, child: child),
          routes: [
            GoRoute(
              path: '/',
              builder: (context, state) =>
                  const Scaffold(body: Text('Organisation route')),
            ),
            GoRoute(path: '/personal/ask', builder: (context, state) => page()),
            GoRoute(
              path: '/personal/questions',
              builder: (context, state) =>
                  page(section: KnowledgeSection.questions),
            ),
            GoRoute(
              path: '/personal/interact',
              builder: (context, state) => page(tab: 1),
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith(
            (ref) => authChanges ?? Stream.value(user),
          ),
          firebaseAuthProvider.overrideWithValue(_TestFirebaseAuth(user)),
          currentMembershipProvider.overrideWith(
            (ref) async => const ActiveMembership(
              userId: 'app-user',
              organisationId: 'org',
              email: 'member@example.test',
              displayName: 'Member',
              role: 'owner',
            ),
          ),
          organisationProfileProvider.overrideWith(
            (ref) async => throw StateError('Profile not needed in this test.'),
          ),
          guestWorkspaceStoreProvider.overrideWithValue(store),
          personalWorkspaceRepositoryProvider.overrideWithValue(repository),
          currentGuestGroupsProvider.overrideWith(
            (ref) async => const <Map<String, dynamic>>[],
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    return router;
  }

  testWidgets('local guest account menu explains local-only work', (
    tester,
  ) async {
    await pumpGuestWorkspace(tester);

    expect(find.text('Guest workspace · Saved on this device'), findsOneWidget);
    expect(find.byTooltip('Groups'), findsNothing);
    await tester.tap(find.byTooltip('Guest workspace options'));
    await tester.pumpAndSettle();
    expect(find.text('Groups'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
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
  });

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

  testWidgets('leaving sign-in keeps the local workspace available', (
    tester,
  ) async {
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
  });

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
      find.textContaining('Guest workspace active in this browser profile.'),
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

    await tester.enterText(
      find.byType(TextField).first,
      'account@example.test',
    );
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
    await _ensureVisibleInVerticalList(
      tester,
      find.text('Account A private item'),
      anchor: find.text('Saved Q&A'),
    );
    expect(find.text('Account A private item'), findsOneWidget);
    expect((await storage.load()).knowledge, isEmpty);
    await _ensureVisibleInVerticalList(
      tester,
      find.text('Back to Ask & search'),
      anchor: find.text('Saved Q&A'),
    );
    await _tapVisibleTarget(tester, find.text('Back to Ask & search'));
    await tester.pumpAndSettle();

    repository.items = [personalItem('b', 'Account B private item')];
    await tester.pumpWidget(
      page(_TestUser(isAnonymous: false, isEmailVerified: true, testUid: 'b')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Saved Q&A'));
    await tester.pumpAndSettle();

    expect(find.text('Account A private item'), findsNothing);
    await _ensureVisibleInVerticalList(
      tester,
      find.text('Account B private item'),
      anchor: find.text('Saved Q&A'),
    );
    expect(find.text('Account B private item'), findsOneWidget);
    expect(repository.listCalls, 2);
    expect((await storage.load()).knowledge, isEmpty);
  });

  testWidgets(
    'stale personal search results are ignored after account switch',
    (tester) async {
      final store = GuestWorkspaceStore(_MemoryGuestStorage());
      final staleResponse = Completer<Map<String, dynamic>>();
      final userA = _TestUser(
        isAnonymous: false,
        isEmailVerified: true,
        testUid: 'search-account-a',
      );
      final userB = _TestUser(
        isAnonymous: false,
        isEmailVerified: true,
        testUid: 'search-account-b',
      );
      final authEvents = StreamController<User?>.broadcast();
      final repository = _TestPersonalWorkspaceRepository([])
        ..searchHandler = (query, uid) => uid == userA.uid
            ? staleResponse.future
            : Future.value({
                'results': [
                  {
                    'id': 'account-b-record',
                    'source_id': 'account-b-item',
                    'title': 'Account B result',
                    'data': {
                      'id': 'account-b-item',
                      'body': 'account-b needle',
                    },
                    'match_method': 'keyword',
                    'relevance_score': 1.1,
                  },
                ],
                'partial': false,
              });
      final groups = _TestGuestGroupRepository([], {});
      Widget page(User user) => ProviderScope(
        overrides: [
          authStateProvider.overrideWith((ref) => authEvents.stream),
          firebaseAuthProvider.overrideWithValue(_TestFirebaseAuth(user)),
          guestWorkspaceStoreProvider.overrideWithValue(store),
          personalWorkspaceRepositoryProvider.overrideWithValue(repository),
          guestGroupRepositoryProvider.overrideWithValue(groups),
        ],
        child: MaterialApp(
          home: GuestWorkspacePage(
            firebaseReady: true,
            personalWorkspaceEnabled: true,
            accountUser: user,
            membershipStatus: AccountMembershipStatus.noMembership,
          ),
        ),
      );
      final searchField = find.byWidgetPredicate(
        (widget) =>
            widget is TextField &&
            widget.decoration?.labelText == 'Search Knowledge',
      );

      await tester.pumpWidget(page(userA));
      await tester.pumpAndSettle();
      await tester.enterText(searchField, 'needle');
      await tester.pump(const Duration(milliseconds: 301));
      expect(repository.searches, [('needle', userA.uid)]);

      await tester.pumpWidget(page(userB));
      authEvents.add(userB);
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 301));
      await tester.pumpAndSettle();
      expect(repository.searches.last, ('needle', userB.uid));
      expect(find.text('Account B result'), findsOneWidget);

      staleResponse.complete({
        'results': [
          {
            'id': 'account-a-record',
            'source_id': 'account-a-item',
            'title': 'Account A stale result',
            'data': {'id': 'account-a-item', 'body': 'account-a needle'},
            'match_method': 'keyword',
            'relevance_score': 1.1,
          },
        ],
        'partial': false,
      });
      await tester.pumpAndSettle();
      expect(find.text('Account A stale result'), findsNothing);
      expect(find.text('Account B result'), findsOneWidget);
      await authEvents.close();
    },
  );

  testWidgets('partial personal search can be retried from the widget', (
    tester,
  ) async {
    final user = _TestUser(isAnonymous: false, isEmailVerified: true);
    var searchCount = 0;
    final repository = _TestPersonalWorkspaceRepository([])
      ..searchHandler = (query, uid) async {
        searchCount++;
        return {
          'results': [
            {
              'id': 'personal-record-$searchCount',
              'source_id': 'personal-item-$searchCount',
              'title': searchCount == 1 ? 'Partial result' : 'Complete result',
              'data': {'id': 'personal-item-$searchCount', 'body': query},
              'match_method': 'keyword',
              'relevance_score': 1.1,
            },
          ],
          'partial': searchCount == 1,
        };
      };
    final groups = _TestGuestGroupRepository([], {});
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith((ref) => Stream.value(user)),
          firebaseAuthProvider.overrideWithValue(_TestFirebaseAuth(user)),
          guestWorkspaceStoreProvider.overrideWithValue(
            GuestWorkspaceStore(_MemoryGuestStorage()),
          ),
          personalWorkspaceRepositoryProvider.overrideWithValue(repository),
          guestGroupRepositoryProvider.overrideWithValue(groups),
        ],
        child: MaterialApp(
          home: GuestWorkspacePage(
            firebaseReady: true,
            personalWorkspaceEnabled: true,
            accountUser: user,
            membershipStatus: AccountMembershipStatus.noMembership,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final searchField = find.byWidgetPredicate(
      (widget) =>
          widget is TextField &&
          widget.decoration?.labelText == 'Search Knowledge',
    );
    await tester.enterText(searchField, 'partial');
    await tester.pump(const Duration(milliseconds: 301));
    await tester.pumpAndSettle();

    expect(searchCount, 1);
    expect(find.text('Partial result'), findsOneWidget);
    expect(
      find.text(
        'Personal-account search reached its result limit. Some matches may be omitted.',
      ),
      findsOneWidget,
    );
    final retryButton = find.text('Retry available sources');
    await tester.ensureVisible(retryButton);
    await tester.tap(retryButton);
    await tester.pump(const Duration(milliseconds: 301));
    await tester.pumpAndSettle();

    expect(searchCount, 2);
    expect(find.text('Complete result'), findsOneWidget);
    expect(
      find.text(
        'Personal-account search reached its result limit. Some matches may be omitted.',
      ),
      findsNothing,
    );
  });

  testWidgets(
    'local and private answer matches outrank semantic-only results without '
    'uploading local content',
    (tester) async {
      const query = 'needle phrase';
      final localItem = {
        'id': 'local-answer-match',
        'title': 'Local answer evidence',
        'body': '',
        'answer': 'A precise needle phrase appears in this answer.',
      };
      final store = GuestWorkspaceStore(_MemoryGuestStorage());
      await store.save(GuestWorkspaceData(knowledge: [localItem]));
      final user = _TestUser(isAnonymous: false, isEmailVerified: true);
      final repository =
          _TestPersonalWorkspaceRepository([
              {
                'id': 'private-record',
                'kind': 'knowledge',
                'source_key': 'knowledge:private-answer-match',
                'title': 'Private answer evidence',
                'data': {
                  'id': 'private-answer-match',
                  'title': 'Private answer evidence',
                  'body': '',
                  'answer': 'Another precise needle phrase appears here.',
                },
                'revision': 1,
                'created_at': '2026-10-06T00:00:00+00:00',
                'updated_at': '2026-10-06T00:00:00+00:00',
              },
            ])
            ..searchHandler = (searchQuery, uid) async {
              expect(searchQuery, query);
              expect(uid, user.uid);
              return {
                'results': [
                  {
                    'id': 'semantic-record',
                    'source_id': 'semantic-only',
                    'title': 'Remote semantic match',
                    'data': {
                      'id': 'semantic-only',
                      'title': 'Remote semantic match',
                      'body': 'Related guidance without the query words.',
                      'answer': '',
                    },
                    'snippet': 'Related guidance without the query words.',
                    'match_method': 'semantic',
                    'relevance_score': 1,
                  },
                ],
                'partial': false,
              };
            };
      final groups = _TestGuestGroupRepository([], {});
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            firebaseAuthProvider.overrideWithValue(_TestFirebaseAuth(user)),
            guestWorkspaceStoreProvider.overrideWithValue(store),
            personalWorkspaceRepositoryProvider.overrideWithValue(repository),
            guestGroupRepositoryProvider.overrideWithValue(groups),
          ],
          child: MaterialApp(
            home: GuestWorkspacePage(
              firebaseReady: true,
              personalWorkspaceEnabled: true,
              accountUser: user,
              membershipStatus: AccountMembershipStatus.noMembership,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final searchField = find.byWidgetPredicate(
        (widget) =>
            widget is TextField &&
            widget.decoration?.labelText == 'Search Knowledge',
      );
      await tester.enterText(searchField, query);
      await tester.pump(const Duration(milliseconds: 301));
      await tester.pumpAndSettle();

      Finder resultCard(String title) =>
          find.ancestor(of: find.text(title), matching: find.byType(Card));

      final localCard = resultCard('Local answer evidence');
      final privateCard = resultCard('Private answer evidence');
      final semanticCard = resultCard('Remote semantic match');
      expect(localCard, findsOneWidget);
      expect(privateCard, findsOneWidget);
      expect(semanticCard, findsOneWidget);
      expect(
        find.descendant(
          of: localCard,
          matching: find.widgetWithText(Chip, 'Local'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: privateCard,
          matching: find.widgetWithText(Chip, 'Private'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: privateCard,
          matching: find.text('Personal account · saved'),
        ),
        findsOneWidget,
      );
      expect(
        tester.getTopLeft(localCard).dy,
        lessThan(tester.getTopLeft(semanticCard).dy),
      );
      expect(
        tester.getTopLeft(privateCard).dy,
        lessThan(tester.getTopLeft(semanticCard).dy),
      );
      expect(repository.searches, [(query, user.uid)]);
      expect(repository.imports, isEmpty);
      expect(
        (await store.load()).knowledge.single['answer'],
        localItem['answer'],
      );
    },
  );

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
    await _ensureVisibleInVerticalList(
      tester,
      find.text('Personal account item'),
      anchor: find.text('Saved Q&A'),
    );
    expect(find.text('Personal account item'), findsOneWidget);
    expect(repository.deleteCalls, 0);
  });

  testWidgets(
    'personal import retries selected items without removing locals',
    (tester) async {
      final localData = GuestWorkspaceData(
        knowledge: [
          {'id': 'selected', 'title': 'Import this item', 'body': 'Selected'},
          {
            'id': 'local-only',
            'title': 'Keep this item local',
            'body': 'Private',
          },
        ],
      );
      final store = GuestWorkspaceStore(_MemoryGuestStorage());
      await store.save(localData);
      final repository = _TestPersonalWorkspaceRepository([])
        ..failedImports = 1;
      await pumpPersonalRouter(
        tester,
        user: _TestUser(isAnonymous: false, isEmailVerified: true),
        repository: repository,
        store: store,
      );
      await _tapVisibleTarget(tester, find.text('Import local work'));
      await tester.pumpAndSettle();
      await _ensureVisibleInDialog(tester, find.text('Keep this item local'));
      await tester.tap(find.text('Keep this item local').hitTestable());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Import selected work'));
      await tester.pumpAndSettle();

      expect(repository.imports, hasLength(1));
      expect(repository.imports.single, hasLength(1));
      expect(
        repository.imports.single.single['source_key'],
        'knowledge:selected',
      );
      expect(find.text('Retry import'), findsOneWidget);
      await tester.tap(find.text('Retry import'));
      await tester.pumpAndSettle();

      expect(repository.imports, hasLength(2));
      expect(
        repository.imports[0].single['source_key'],
        repository.imports[1].single['source_key'],
      );
      expect((await store.load()).knowledge, hasLength(2));
      await tester.tap(find.text('Questions').first);
      await tester.pumpAndSettle();
      expect(find.text('Back to Ask & search'), findsOneWidget);
      final savedListScrollable = find
          .ancestor(
            of: find.text('Questions').first,
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
      await tester.pumpAndSettle();
      await Scrollable.ensureVisible(
        tester.element(find.text('Keep this item local')),
        alignment: 0.5,
      );
      await tester.pumpAndSettle();
      expect(find.text('Import this item'), findsOneWidget);
      expect(find.text('Keep this item local'), findsOneWidget);
    },
  );

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
    await _tapVisibleTarget(tester, find.text('Import local work'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Import selected work'));
    await tester.pumpAndSettle();

    expect(repository.imports, hasLength(1));
    expect(
      find.textContaining('Select fewer items or smaller items'),
      findsOneWidget,
    );
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

  testWidgets(
    'revision conflicts reload before an explicit pending-edit save',
    (tester) async {
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

      final latestAccountItem = item(
        title: 'Latest account title',
        revision: 2,
      );
      final repository =
          _TestPersonalWorkspaceRepository([
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
      await _ensureVisibleInVerticalList(
        tester,
        find.byTooltip('Edit personal-account Knowledge'),
        anchor: find.text('Saved Q&A'),
      );
      await tester.tap(
        find.byTooltip('Edit personal-account Knowledge').hitTestable(),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find
            .descendant(
              of: find.byType(AlertDialog),
              matching: find.byType(TextFormField),
            )
            .first,
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
      await _tapVisibleTarget(tester, find.text('Review account change'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Latest saved version (revision 2)'),
        findsOneWidget,
      );
      expect(find.text('Your pending edit: My pending edit'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('My pending edit'), findsOneWidget);

      await _tapVisibleTarget(tester, find.text('Review account change'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save my pending edit'));
      await tester.pumpAndSettle();

      expect(repository.updateRevisions, [1, 2]);
      expect(find.text('My pending edit'), findsOneWidget);
      expect(find.text('Latest account title'), findsNothing);
    },
  );

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
    await _ensureVisibleInVerticalList(
      tester,
      find.text('Imported nested session'),
      anchor: find.text('Create private session'),
    );
    await tester.tap(find.text('Imported nested session').hitTestable());
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

  testWidgets('local work stays separate until explicit account import', (
    tester,
  ) async {
    final store = GuestWorkspaceStore(_MemoryGuestStorage());
    const localItem = {
      'id': 'local-knowledge',
      'title': 'Keep this Knowledge item local',
      'body': 'Local original',
    };
    await store.save(const GuestWorkspaceData(knowledge: [localItem]));
    final repository = _TestPersonalWorkspaceRepository([]);
    final user = _TestUser(isAnonymous: false, isEmailVerified: true);
    await pumpPersonalRouter(
      tester,
      user: user,
      repository: repository,
      store: store,
    );

    expect(repository.imports, isEmpty);
    expect((await store.load()).knowledge.single['id'], 'local-knowledge');
    await _tapVisibleTarget(tester, find.text('Import local work'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Import selected work'));
    await tester.pumpAndSettle();

    expect(repository.imports, hasLength(1));
    expect(
      repository.imports.single.single['source_key'],
      'knowledge:local-knowledge',
    );
    expect(
      (await store.load()).knowledge.single['title'],
      'Keep this Knowledge item local',
    );
  });

  testWidgets(
    'new verified-user Knowledge saves privately and reconciles an uncertain create',
    (tester) async {
      final user = _TestUser(
        isAnonymous: false,
        isEmailVerified: true,
        testUid: 'private-user',
      );
      final repository = _TestPersonalWorkspaceRepository([])
        ..failedImports = 1;
      final store = GuestWorkspaceStore(_MemoryGuestStorage());
      await pumpGuestWorkspace(
        tester,
        user: user,
        personalWorkspaceEnabled: true,
        personalRepository: repository,
        store: store,
      );

      await _ensureVisibleInVerticalList(
        tester,
        find.text('Save to private account'),
        anchor: find.widgetWithText(TextFormField, 'Question'),
      );
      expect(find.text('Save to private account'), findsOneWidget);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Question'),
        'Private default question',
      );
      await tester.enterText(
        find.byWidgetPredicate(
          (widget) =>
              widget is TextField && widget.decoration?.labelText == 'Details',
        ),
        'Account-only detail',
      );
      await tester.enterText(
        find.byWidgetPredicate(
          (widget) =>
              widget is TextField && widget.decoration?.labelText == 'Answer',
        ),
        'Account-only answer',
      );
      await _ensureVisibleInVerticalList(
        tester,
        find.text('Save to private account'),
        anchor: find.widgetWithText(TextFormField, 'Question'),
      );
      await tester.tap(find.text('Save to private account').hitTestable());
      await tester.pumpAndSettle();

      expect(find.text('Retry account save'), findsOneWidget);
      expect(repository.imports, hasLength(1));
      expect(repository.items, hasLength(1));
      expect(repository.items.single['kind'], 'knowledge');
      expect(
        (repository.items.single['data'] as Map)['visibility'],
        'private_account',
      );
      expect((await store.load()).knowledge, isEmpty);

      await tester.tap(find.text('Retry account save'));
      await tester.pumpAndSettle();
      expect(repository.imports, hasLength(2));
      await _ensureVisibleInVerticalList(
        tester,
        find.text('Saved Q&A'),
        anchor: find.text('Save to private account'),
      );
      await tester.tap(find.text('Saved Q&A').hitTestable());
      await tester.pumpAndSettle();
      await _ensureVisibleInVerticalList(
        tester,
        find.byTooltip('Edit personal-account Knowledge'),
        anchor: find.text('Saved Q&A'),
      );
      await tester.tap(
        find.byTooltip('Edit personal-account Knowledge').hitTestable(),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find
            .descendant(
              of: find.byType(AlertDialog),
              matching: find.byType(TextFormField),
            )
            .first,
        'Edited while create confirmation was uncertain',
      );
      await tester.tap(find.text('Save account changes'));
      await tester.pumpAndSettle();

      expect(repository.imports, hasLength(2));
      expect(
        repository.imports.first.single['source_key'],
        repository.imports.last.single['source_key'],
      );
      expect(repository.items, hasLength(1));
      expect(
        repository.items.single['title'],
        'Edited while create confirmation was uncertain',
      );
      expect(find.text('Personal account · saved'), findsOneWidget);
    },
  );

  testWidgets(
    'pending private write blocks shell navigation and browser back until saved',
    (tester) async {
      final user = _TestUser(
        isAnonymous: false,
        isEmailVerified: true,
        testUid: 'delayed-private-user',
      );
      final repository = _TestPersonalWorkspaceRepository([]);
      final writeGate = Completer<void>();
      repository.nextImportGate = writeGate;
      final store = GuestWorkspaceStore(_MemoryGuestStorage());
      final router = await pumpPersonalRouter(
        tester,
        user: user,
        repository: repository,
        store: store,
        initialLocation: '/',
      );
      unawaited(router.push<void>('/personal/ask'));
      await tester.pumpAndSettle();
      await _ensureVisibleInVerticalList(
        tester,
        find.widgetWithText(TextFormField, 'Question'),
        anchor: find.text('Search Knowledge'),
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Question'),
        'Held private question',
      );
      await _ensureVisibleInVerticalList(
        tester,
        find.text('Save to private account'),
        anchor: find.widgetWithText(TextFormField, 'Question'),
      );
      await tester.tap(find.text('Save to private account').hitTestable());
      await tester.pump();
      await tester.pump();

      await _tapPersonalNavigation(tester, 'Interact');
      expect(find.text('Save to private account'), findsOneWidget);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Save to private account'), findsOneWidget);

      await tester.tap(find.byTooltip('Switch workspace'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Organisation workspace'));
      await tester.pumpAndSettle();
      expect(find.text('Save to private account'), findsOneWidget);

      writeGate.complete();
      await tester.pumpAndSettle();
      expect(repository.items, hasLength(1));
      expect((await store.load()).knowledge, isEmpty);
      await tester.pump(const Duration(seconds: 5));
      await tester.tap(find.byTooltip('Switch workspace'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Organisation workspace'));
      await tester.pumpAndSettle();
      expect(find.text('Organisation route'), findsOneWidget);
      unawaited(router.push<void>('/personal/interact'));
      await tester.pumpAndSettle();
      await tester.pumpAndSettle();
      expect(find.text('Create private session'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'UID transition isolates queued writes while an earlier create is unresolved',
    (tester) async {
      final firstUser = _TestUser(
        isAnonymous: false,
        isEmailVerified: true,
        testUid: 'first-private-uid',
      );
      final secondUser = _TestUser(
        isAnonymous: false,
        isEmailVerified: true,
        testUid: 'second-private-uid',
      );
      final authChanges = StreamController<User?>();
      addTearDown(authChanges.close);
      authChanges.add(firstUser);
      final repository = _TestPersonalWorkspaceRepository([]);
      final firstWriteGate = Completer<void>();
      repository.nextImportGate = firstWriteGate;
      final store = GuestWorkspaceStore(_MemoryGuestStorage());
      await pumpPersonalRouter(
        tester,
        user: firstUser,
        repository: repository,
        store: store,
        authChanges: authChanges.stream,
      );
      await _ensureVisibleInVerticalList(
        tester,
        find.widgetWithText(TextFormField, 'Question'),
        anchor: find.text('Search Knowledge'),
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Question'),
        'First identity private question',
      );
      await _ensureVisibleInVerticalList(
        tester,
        find.text('Save to private account'),
        anchor: find.widgetWithText(TextFormField, 'Question'),
      );
      await tester.tap(find.text('Save to private account').hitTestable());
      await tester.pump();
      await tester.pump();
      expect(repository.importUids, ['first-private-uid']);

      authChanges.add(secondUser);
      await tester.pumpAndSettle();
      expect(find.text('First identity private question'), findsNothing);
      await _ensureVisibleInVerticalList(
        tester,
        find.widgetWithText(TextFormField, 'Question'),
        anchor: find.text('Save to private account'),
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Question'),
        'Second identity private question',
      );
      await _ensureVisibleInVerticalList(
        tester,
        find.text('Save to private account'),
        anchor: find.widgetWithText(TextFormField, 'Question'),
      );
      await tester.tap(find.text('Save to private account').hitTestable());
      await tester.pump();
      await tester.pump();
      expect(repository.importUids, ['first-private-uid']);

      firstWriteGate.complete();
      await tester.pumpAndSettle();

      expect(repository.importUids, [
        'first-private-uid',
        'second-private-uid',
      ]);
      expect(find.text('First identity private question'), findsNothing);
      expect(find.text('Second identity private question'), findsOneWidget);
      expect((await store.load()).knowledge, isEmpty);
    },
  );

  testWidgets(
    'deleting during uncertain create confirms creation before account deletion',
    (tester) async {
      final user = _TestUser(
        isAnonymous: false,
        isEmailVerified: true,
        testUid: 'uncertain-delete-user',
      );
      final repository = _TestPersonalWorkspaceRepository([])
        ..failedImports = 1;
      final store = GuestWorkspaceStore(_MemoryGuestStorage());
      await pumpGuestWorkspace(
        tester,
        user: user,
        personalWorkspaceEnabled: true,
        personalRepository: repository,
        store: store,
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Question'),
        'Remove uncertain private create',
      );
      await _ensureVisibleInVerticalList(
        tester,
        find.text('Save to private account'),
        anchor: find.widgetWithText(TextFormField, 'Question'),
      );
      await tester.tap(find.text('Save to private account').hitTestable());
      await tester.pumpAndSettle();
      expect(repository.items, hasLength(1));

      await _ensureVisibleInVerticalList(
        tester,
        find.text('Saved Q&A'),
        anchor: find.text('Save to private account'),
      );
      await tester.tap(find.text('Saved Q&A').hitTestable());
      await tester.pumpAndSettle();
      await _ensureVisibleInVerticalList(
        tester,
        find.byTooltip('Remove personal-account Knowledge'),
        anchor: find.text('Saved Q&A'),
      );
      await tester.tap(find.byTooltip('Remove personal-account Knowledge'));
      await tester.pumpAndSettle();

      expect(repository.imports, hasLength(2));
      expect(repository.deleteCalls, 1);
      expect(repository.items, isEmpty);
      expect((await store.load()).knowledge, isEmpty);
      expect(find.text('Retry account save'), findsNothing);
    },
  );

  testWidgets(
    'personal refresh overlapping a create cannot replace the acknowledged item',
    (tester) async {
      final user = _TestUser(
        isAnonymous: false,
        isEmailVerified: true,
        testUid: 'refresh-race-user',
      );
      final repository = _TestPersonalWorkspaceRepository([]);
      final staleRefresh = Completer<List<Map<String, dynamic>>>();
      repository.nextListResponse = staleRefresh;
      final store = GuestWorkspaceStore(_MemoryGuestStorage());
      await pumpGuestWorkspace(
        tester,
        user: user,
        personalWorkspaceEnabled: true,
        personalRepository: repository,
        store: store,
      );
      expect(repository.listCalls, 1);
      await _ensureVisibleInVerticalList(
        tester,
        find.widgetWithText(TextFormField, 'Question'),
        anchor: find.text('Search Knowledge'),
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Question'),
        'Refresh race question',
      );
      await _ensureVisibleInVerticalList(
        tester,
        find.text('Save to private account'),
        anchor: find.widgetWithText(TextFormField, 'Question'),
      );
      await tester.tap(find.text('Save to private account').hitTestable());
      await tester.pumpAndSettle();
      expect(repository.items, hasLength(1));

      staleRefresh.complete(const []);
      await tester.pumpAndSettle();

      expect(repository.listCalls, greaterThanOrEqualTo(2));
      expect(repository.items, hasLength(1));
      await _ensureVisibleInVerticalList(
        tester,
        find.text('Saved Q&A'),
        anchor: find.text('Save to private account'),
      );
      await tester.tap(find.text('Saved Q&A').hitTestable());
      await tester.pumpAndSettle();
      await _ensureVisibleInVerticalList(
        tester,
        find.text('Refresh race question'),
        anchor: find.text('Saved Q&A'),
      );
      expect(find.text('Refresh race question'), findsOneWidget);
      expect(find.text('Personal account · saved'), findsOneWidget);
    },
  );

  testWidgets(
    'pending selected account import blocks shell navigation until confirmed',
    (tester) async {
      final user = _TestUser(
        isAnonymous: false,
        isEmailVerified: true,
        testUid: 'delayed-import-user',
      );
      final repository = _TestPersonalWorkspaceRepository([]);
      final importGate = Completer<void>();
      repository.nextImportGate = importGate;
      final store = GuestWorkspaceStore(_MemoryGuestStorage());
      await store.save(
        const GuestWorkspaceData(
          knowledge: [
            {'id': 'selected-local', 'title': 'Selected local work'},
          ],
        ),
      );
      final router = await pumpPersonalRouter(
        tester,
        user: user,
        repository: repository,
        store: store,
        initialLocation: '/',
      );
      unawaited(router.push<void>('/personal/ask'));
      await tester.pumpAndSettle();
      await _tapVisibleTarget(tester, find.text('Import local work'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Import selected work'));
      await tester.pump();
      await tester.pump();

      await _tapPersonalNavigation(tester, 'Interact');
      expect(find.text('Import local work'), findsOneWidget);

      importGate.complete();
      await tester.pumpAndSettle();
      expect(repository.items, hasLength(1));
      expect((await store.load()).knowledge.single['id'], 'selected-local');
      await tester.pump(const Duration(seconds: 5));
      await _tapPersonalNavigation(tester, 'Interact');
      expect(find.text('Create private session'), findsOneWidget);
    },
  );

  testWidgets(
    'permanent import rejection releases navigation while transient failure stays guarded',
    (tester) async {
      final user = _TestUser(
        isAnonymous: false,
        isEmailVerified: true,
        testUid: 'rejected-import-user',
      );
      final repository = _TestPersonalWorkspaceRepository([])
        ..failedImports = 1
        ..importFailureStatus = 413;
      final store = GuestWorkspaceStore(_MemoryGuestStorage());
      await store.save(
        const GuestWorkspaceData(
          knowledge: [
            {'id': 'local-original', 'title': 'Original stays local'},
          ],
        ),
      );
      await pumpPersonalRouter(
        tester,
        user: user,
        repository: repository,
        store: store,
      );
      await _tapVisibleTarget(tester, find.text('Import local work'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Import selected work'));
      await tester.pumpAndSettle();
      expect(find.text('Change selection'), findsOneWidget);
      expect((await store.load()).knowledge.single['id'], 'local-original');

      await _tapPersonalNavigation(tester, 'Interact');
      expect(find.text('Create private session'), findsOneWidget);
    },
  );

  testWidgets(
    'unconfirmed account import remains guarded and retains its local original',
    (tester) async {
      final user = _TestUser(
        isAnonymous: false,
        isEmailVerified: true,
        testUid: 'uncertain-import-user',
      );
      final repository = _TestPersonalWorkspaceRepository([])
        ..failedImports = 1
        ..importFailureStatus = 500;
      final store = GuestWorkspaceStore(_MemoryGuestStorage());
      await store.save(
        const GuestWorkspaceData(
          knowledge: [
            {'id': 'retry-local', 'title': 'Retry keeps original'},
          ],
        ),
      );
      await pumpPersonalRouter(
        tester,
        user: user,
        repository: repository,
        store: store,
      );
      await _tapVisibleTarget(tester, find.text('Import local work'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Import selected work'));
      await tester.pumpAndSettle();
      expect(find.text('Retry import'), findsOneWidget);
      expect((await store.load()).knowledge.single['id'], 'retry-local');

      await _tapPersonalNavigation(tester, 'Interact');
      expect(find.text('Create private session'), findsNothing);
      expect(find.text('Import local work'), findsOneWidget);
    },
  );

  testWidgets('new verified-user Interact sessions save privately by default', (
    tester,
  ) async {
    final user = _TestUser(
      isAnonymous: false,
      isEmailVerified: true,
      testUid: 'private-interact-user',
    );
    final repository = _TestPersonalWorkspaceRepository([]);
    final store = GuestWorkspaceStore(_MemoryGuestStorage());
    await pumpGuestWorkspace(
      tester,
      user: user,
      personalWorkspaceEnabled: true,
      personalRepository: repository,
      store: store,
    );

    await tester.tap(find.text('Interact').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Interact privacy information'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('New sessions are private to your account.'),
      findsOneWidget,
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('Create private session'), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'New Interact session'),
      'Private session',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'First participant'),
      'Participant One',
    );
    await tester.tap(find.text('Create private session'));
    await tester.pumpAndSettle();

    expect(repository.items, hasLength(1));
    expect(repository.items.single['kind'], 'interact_session');
    expect(
      (repository.items.single['data'] as Map)['visibility'],
      'private_account',
    );
    expect((await store.load()).sessions, isEmpty);
    expect(find.text('Private session'), findsOneWidget);
  });

  testWidgets(
    'existing-account sign-in errors do not reveal Firebase details',
    (tester) async {
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
      await tester.enterText(
        find.byType(TextField).first,
        'account@example.test',
      );
      await tester.enterText(find.byType(TextField).last, 'secret-password');
      expect(
        tester.widget<TextField>(find.byType(TextField).last).obscureText,
        isTrue,
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
      await tester.pumpAndSettle();

      expect(auth.signInAttempts, 1);
      expect(
        find.text(
          'Sign-in failed. Check your email and password and try again.',
        ),
        findsOneWidget,
      );
      final renderedText = tester
          .widgetList<Text>(
            find.descendant(
              of: find.byType(SignInPage),
              matching: find.byType(Text),
            ),
          )
          .map((widget) => widget.data ?? '');
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
    },
  );

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
    await tester.enterText(
      find.byType(TextField).first,
      'account@example.test',
    );
    await tester.enterText(find.byType(TextField).last, 'secret-password');
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();

    expect(auth.signInAttempts, 1);
    expect(
      find.text('Unable to complete this account request. Please try again.'),
      findsOneWidget,
    );
    final renderedText = tester
        .widgetList<Text>(
          find.descendant(
            of: find.byType(SignInPage),
            matching: find.byType(Text),
          ),
        )
        .map((widget) => widget.data ?? '');
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

  testWidgets(
    'registered account without membership is not shown as signed out',
    (tester) async {
      await pumpGuestWorkspace(
        tester,
        user: _TestUser(isAnonymous: false),
        membershipStatus: AccountMembershipStatus.noMembership,
      );

      expect(find.textContaining('no organisation membership'), findsOneWidget);
      await tester.tap(find.text('Account'));
      await tester.pumpAndSettle();
      expect(find.text('No organisation membership'), findsOneWidget);
      expect(find.text('Sign out'), findsOneWidget);
      expect(find.text('Sign in'), findsNothing);
      expect(find.text('Create account'), findsNothing);
    },
  );

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

    expect(find.byTooltip('Groups'), findsNothing);
    expect(
      find.textContaining('Verify this account’s email before using Groups'),
      findsOneWidget,
    );
    await _openGroupsFromPersonalOptions(tester);
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
    expect(find.byTooltip('Groups'), findsNothing);
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
      await _openGroupsFromPersonalOptions(tester);
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
    expect(find.text('Group access information'), findsOneWidget);
    expect(find.text('Groups'), findsNothing);
    expect(find.text('Sign out'), findsOneWidget);
  });

  testWidgets(
    'Groups navigation is hidden for anonymous and unverified users',
    (tester) async {
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
    },
  );

  testWidgets('Personal workspace navigation omits organisation destinations', (
    tester,
  ) async {
    final user = _TestUser(isAnonymous: false, isEmailVerified: true);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentMembershipProvider.overrideWith(
            (ref) async => const ActiveMembership(
              userId: 'app-user',
              organisationId: 'org',
              email: 'member@example.test',
              displayName: 'Member',
              role: 'owner',
            ),
          ),
          firebaseAuthProvider.overrideWithValue(_TestFirebaseAuth(user)),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: AppShell(
              currentPath: '/personal/ask',
              child: Center(child: Text('Personal content')),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Personal content'), findsOneWidget);
    expect(find.byTooltip('Switch workspace'), findsOneWidget);
    expect(find.text('Knowledge'), findsOneWidget);
    expect(find.text('Interact'), findsOneWidget);
    expect(find.text('Groups'), findsOneWidget);
    expect(find.text('My organisation'), findsNothing);
    expect(find.text('Review'), findsNothing);
    expect(find.text('Admin'), findsNothing);
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

    expect(find.text('Registered local workspace'), findsOneWidget);
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

  testWidgets(
    'membership lookup errors do not claim the account has no member',
    (tester) async {
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

      expect(find.textContaining('could not be verified'), findsOneWidget);
      expect(find.text('private test detail'), findsNothing);
      expect(find.text('No organisation membership'), findsNothing);
    },
  );

  testWidgets('unverified accounts do not query Groups', (tester) async {
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
    expect(
      find.text('No approved groups are linked to this identity.'),
      findsNothing,
    );
    expect(attempts, 0);
  });

  testWidgets(
    'registration from anonymous session uses separate account flow',
    (tester) async {
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
      await tester.enterText(
        find.byType(TextField).first,
        'account@example.test',
      );
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
    },
  );

  testWidgets('account creation sends verification email', (tester) async {
    final user = _TestUser(isAnonymous: false);
    final auth = _TestFirebaseAuth(null)
      ..createCredential = _TestUserCredential(user);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [firebaseAuthProvider.overrideWithValue(auth)],
        child: const MaterialApp(home: SignInPage(createAccount: true)),
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
    expect(find.textContaining('guest identity remains active'), findsNothing);
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
    await tester.enterText(
      find.byType(TextField).first,
      ' member@example.test ',
    );
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
      ..createCredential = _TestUserCredential(_TestUser(isAnonymous: false));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [firebaseAuthProvider.overrideWithValue(auth)],
        child: const MaterialApp(home: SignInPage(createAccount: true)),
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
        child: const MaterialApp(home: SignInPage()),
      ),
    );
    await tester.enterText(
      find.byType(TextField).first,
      'destination@example.test',
    );
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
    await tester.enterText(
      find.byType(TextField).first,
      'destination@example.test',
    );
    await tester.enterText(find.byType(TextField).last, 'safe-test-password');
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();

    expect(auth.signInAttempts, 1);
    expect(find.text('Keep this group identity'), findsNothing);
    expect(identical(auth.currentUser, guest), isTrue);
  });
}
