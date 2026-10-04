import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:int_qa_flow/app.dart';
import 'package:int_qa_flow/core/auth/auth_providers.dart';
import 'package:int_qa_flow/core/auth/sign_in_page.dart';
import 'package:int_qa_flow/features/guest/data/guest_group_repository.dart';
import 'package:int_qa_flow/features/guest/data/guest_storage_interface.dart';
import 'package:int_qa_flow/features/guest/data/guest_workspace_store.dart';
import 'package:int_qa_flow/features/guest/domain/guest_workspace_data.dart';
import 'package:int_qa_flow/features/guest/presentation/guest_workspace_page.dart';
import 'package:int_qa_flow/shared/widgets/app_shell.dart';

class _TestUser extends Fake implements User {
  _TestUser({
    required this.isAnonymous,
    this.linkError,
    this.verificationEmailError,
    this.reloadError,
  });

  @override
  bool isAnonymous;

  @override
  bool get emailVerified => false;

  @override
  String? get email => 'account@example.test';

  @override
  String get uid => 'account-uid';

  final FirebaseAuthException? linkError;
  final FirebaseAuthException? verificationEmailError;
  final FirebaseAuthException? reloadError;
  int verificationEmailAttempts = 0;
  int linkAttempts = 0;
  int reloadAttempts = 0;

  @override
  Future<void> sendEmailVerification([
    ActionCodeSettings? actionCodeSettings,
  ]) async {
    verificationEmailAttempts++;
    if (verificationEmailError != null) throw verificationEmailError!;
  }

  @override
  Future<void> reload() async {
    reloadAttempts++;
    if (reloadError != null) throw reloadError!;
  }

  @override
  Future<UserCredential> linkWithCredential(AuthCredential credential) async {
    linkAttempts++;
    if (linkError != null) throw linkError!;
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
  });

  @override
  final User? currentUser;

  final FirebaseAuthException? createError;
  int createAttempts = 0;
  int signInAttempts = 0;
  int signOutAttempts = 0;
  UserCredential? createCredential;

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
    throw StateError('Unexpected sign-in.');
  }

  @override
  Future<void> signOut() async {
    signOutAttempts++;
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

class _SignInLauncher extends StatelessWidget {
  const _SignInLauncher();

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: TextButton(
        onPressed: () => Navigator.of(context).push<void>(
          MaterialPageRoute<void>(
            builder: (_) => const SignInPage(linkGuestIdentity: true),
          ),
        ),
        child: const Text('Open account linking'),
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
    find.widgetWithText(FilledButton, 'Create a separate account'),
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

      expect(
        find.textContaining('Stored in this browser only.'),
        findsOneWidget,
      );
      await tester.tap(find.byTooltip('Account'));
      await tester.pumpAndSettle();
      expect(find.text('Local guest workspace'), findsOneWidget);
      expect(find.text('Sign in'), findsOneWidget);
      expect(find.text('Create account'), findsOneWidget);
      expect(find.text('Sign out'), findsNothing);
    },
  );

  testWidgets(
    'sign-in return keeps guest workspace content available',
    (tester) async {
      final store = GuestWorkspaceStore(_MemoryGuestStorage());
      await store.save(
        const GuestWorkspaceData(
          sessions: [
            {'id': 'local-session', 'title': 'Work in progress'},
          ],
        ),
      );
      await pumpGuestWorkspace(tester, store: store);

      await tester.tap(find.byTooltip('Account'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sign in'));
      await tester.pumpAndSettle();
      expect(find.text('Back to guest workspace'), findsOneWidget);

      await tester.tap(find.text('Back to guest workspace'));
      await tester.pumpAndSettle();
      expect(find.text('IntQAFlow guest workspace'), findsOneWidget);
      await tester.tap(find.text('Interact').first);
      await tester.pumpAndSettle();
      expect(find.text('Work in progress'), findsOneWidget);

      final saved = await store.load();
      expect(saved.sessions.single['title'], 'Work in progress');
    },
  );

  testWidgets('shared guest account offers explicit recovery linking', (
    tester,
  ) async {
    await pumpGuestWorkspace(
      tester,
      user: _TestUser(isAnonymous: true),
      sharedIdentityActive: true,
    );

    await tester.tap(find.byTooltip('Account'));
    await tester.pumpAndSettle();
    expect(find.text('Shared guest identity'), findsOneWidget);
    expect(find.text('Create account from this guest'), findsOneWidget);
    expect(find.text('Sign out'), findsOneWidget);
    expect(find.text('Organisation admin'), findsNothing);
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

  testWidgets('registered accounts only expose existing guest-group access', (
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

    expect(find.byTooltip('Shared guest groups'), findsOneWidget);
    expect(find.byTooltip('Enable shared guest groups'), findsNothing);
  });

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
            _TestFirebaseAuth(_TestUser(isAnonymous: false)),
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
      find.text('Guest-group roles are separate from organisation roles.'),
      findsOneWidget,
    );
    expect(find.text('Sign out'), findsOneWidget);
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

    expect(find.text('IntQAFlow guest workspace'), findsOneWidget);
    expect(find.textContaining('no organisation membership'), findsOneWidget);
    expect(find.text('Checking account'), findsNothing);
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

  testWidgets('guest-group lookup errors remain distinct from no access and retry', (
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
      find.textContaining('Existing guest-group access could not be checked'),
      findsOneWidget,
    );
    expect(find.text('private test detail'), findsNothing);
    expect(find.text('No approved guest groups are linked to this device.'), findsNothing);
    await tester.tap(find.text('Retry guest groups'));
    await tester.pumpAndSettle();
    expect(attempts, 2);
  });

  testWidgets('link conflict keeps the current shared guest identity', (
    tester,
  ) async {
    final user = _TestUser(
      isAnonymous: true,
      linkError: FirebaseAuthException(code: 'credential-already-in-use'),
    );
    final auth = _TestFirebaseAuth(user);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [firebaseAuthProvider.overrideWithValue(auth)],
        child: const MaterialApp(
          home: SignInPage(linkGuestIdentity: true),
        ),
      ),
    );
    expect(
      find.textContaining('Create a sign-in account from this guest'),
      findsOneWidget,
    );
    await tester.enterText(find.byType(TextField).first, 'account@example.test');
    await tester.enterText(find.byType(TextField).last, 'secure-passphrase');
    await tester.tap(
      find.widgetWithText(FilledButton, 'Create account from this guest'),
    );
    await tester.pumpAndSettle();

    expect(
      find.textContaining('This guest identity remains active'),
      findsOneWidget,
    );
    expect(auth.createAttempts, 0);
    expect(auth.signInAttempts, 0);
    expect(identical(auth.currentUser, user), isTrue);
  });

  testWidgets('guest account linking verifies, refreshes, and closes on success', (
    tester,
  ) async {
    final user = _TestUser(isAnonymous: true);
    final auth = _TestFirebaseAuth(user);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [firebaseAuthProvider.overrideWithValue(auth)],
        child: const MaterialApp(home: _SignInLauncher()),
      ),
    );
    await tester.tap(find.text('Open account linking'));
    await tester.pumpAndSettle();
    expect(find.text('Create account from this guest'), findsNWidgets(2));

    await tester.enterText(find.byType(TextField).first, 'linked@example.test');
    await tester.enterText(find.byType(TextField).last, 'secure-passphrase');
    await tester.tap(
      find.widgetWithText(FilledButton, 'Create account from this guest'),
    );
    await tester.pumpAndSettle();

    expect(user.linkAttempts, 1);
    expect(user.isAnonymous, isFalse);
    expect(user.verificationEmailAttempts, 1);
    expect(user.reloadAttempts, 1);
    expect(find.byType(SignInPage), findsNothing);
    expect(
      find.textContaining('The guest identity and group access are retained'),
      findsOneWidget,
    );
  });

  testWidgets('guest linking reports verification-email failure after linking', (
    tester,
  ) async {
    final user = _TestUser(
      isAnonymous: true,
      verificationEmailError: FirebaseAuthException(code: 'network-request-failed'),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [firebaseAuthProvider.overrideWithValue(_TestFirebaseAuth(user))],
        child: const MaterialApp(home: _SignInLauncher()),
      ),
    );
    await tester.tap(find.text('Open account linking'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'linked@example.test');
    await tester.enterText(find.byType(TextField).last, 'secure-passphrase');
    await tester.tap(
      find.widgetWithText(FilledButton, 'Create account from this guest'),
    );
    await tester.pumpAndSettle();

    expect(user.isAnonymous, isFalse);
    expect(user.verificationEmailAttempts, 1);
    expect(find.byType(SignInPage), findsNothing);
    expect(
      find.textContaining('verification email could not be sent'),
      findsOneWidget,
    );
    expect(
      find.textContaining('group access remain linked'),
      findsOneWidget,
    );
  });

  testWidgets('guest linking reports account refresh failure after linking', (
    tester,
  ) async {
    final user = _TestUser(
      isAnonymous: true,
      reloadError: FirebaseAuthException(code: 'network-request-failed'),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [firebaseAuthProvider.overrideWithValue(_TestFirebaseAuth(user))],
        child: const MaterialApp(home: _SignInLauncher()),
      ),
    );
    await tester.tap(find.text('Open account linking'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'linked@example.test');
    await tester.enterText(find.byType(TextField).last, 'secure-passphrase');
    await tester.tap(
      find.widgetWithText(FilledButton, 'Create account from this guest'),
    );
    await tester.pumpAndSettle();

    expect(user.isAnonymous, isFalse);
    expect(user.verificationEmailAttempts, 1);
    expect(user.reloadAttempts, 1);
    expect(find.byType(SignInPage), findsNothing);
    expect(
      find.textContaining('account status could not be refreshed'),
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
      find.textContaining('This creates a separate account. It does not transfer guest-group access'),
      findsOneWidget,
    );
    await tester.enterText(find.byType(TextField).first, 'new@example.test');
    await tester.enterText(find.byType(TextField).last, 'secure-passphrase');
    await tester.tap(find.widgetWithText(FilledButton, 'Create a separate account'));
    await tester.pumpAndSettle();

    expect(auth.createAttempts, 1);
    expect(user.verificationEmailAttempts, 1);
    expect(
      find.textContaining('Check your email to verify it'),
      findsOneWidget,
    );
    expect(
      find.textContaining('does not add organisation membership'),
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

  testWidgets('separate account creation warns before leaving guest groups', (
    tester,
  ) async {
    final user = _TestUser(isAnonymous: true);
    final auth = _TestFirebaseAuth(user);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [firebaseAuthProvider.overrideWithValue(auth)],
        child: const MaterialApp(
          home: SignInPage(createAccount: true),
        ),
      ),
    );
    await tester.enterText(find.byType(TextField).first, 'account@example.test');
    await tester.enterText(find.byType(TextField).last, 'secure-passphrase');
    await tester.tap(
      find.widgetWithText(FilledButton, 'Create a separate account'),
    );
    await tester.pumpAndSettle();

    expect(
      find.textContaining('does not transfer the current guest group membership'),
      findsOneWidget,
    );
    await tester.tap(find.text('Cancel account creation'));
    await tester.pumpAndSettle();
    expect(auth.createAttempts, 0);
    expect(identical(auth.currentUser, user), isTrue);
    expect(
      find.textContaining('Account creation cancelled. Your guest identity'),
      findsOneWidget,
    );
  });
}
