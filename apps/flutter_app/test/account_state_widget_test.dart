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
import 'package:int_qa_flow/features/guest/presentation/guest_workspace_page.dart';
import 'package:int_qa_flow/shared/widgets/app_shell.dart';

class _TestUser extends Fake implements User {
  _TestUser({required this.isAnonymous, this.linkError});

  @override
  final bool isAnonymous;

  @override
  String get uid => 'account-uid';

  final FirebaseAuthException? linkError;

  @override
  Future<UserCredential> linkWithCredential(AuthCredential credential) async {
    if (linkError != null) throw linkError!;
    throw StateError('Unexpected account-link request.');
  }
}

class _TestFirebaseAuth extends Fake implements FirebaseAuth {
  _TestFirebaseAuth(this.currentUser);

  @override
  final User? currentUser;

  int createAttempts = 0;
  int signInAttempts = 0;
  int signOutAttempts = 0;

  @override
  Future<UserCredential> createUserWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    createAttempts++;
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

void main() {
  Future<void> pumpGuestWorkspace(
    WidgetTester tester, {
    User? user,
    AccountMembershipStatus? membershipStatus,
    bool sharedIdentityActive = false,
    bool authUnavailable = false,
    List<Map<String, dynamic>> existingGuestGroups =
        const <Map<String, dynamic>>[],
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          guestWorkspaceStoreProvider.overrideWithValue(
            GuestWorkspaceStore(_MemoryGuestStorage()),
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
    expect(find.text('Link guest recovery'), findsOneWidget);
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
    await tester.enterText(find.byType(TextField).first, 'account@example.test');
    await tester.enterText(find.byType(TextField).last, 'secure-passphrase');
    await tester.tap(
      find.widgetWithText(FilledButton, 'Link guest recovery'),
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
    await tester.tap(find.text('Create account'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('does not transfer the current guest group membership'),
      findsOneWidget,
    );
    await tester.tap(find.text('Keep guest identity'));
    await tester.pumpAndSettle();
    expect(auth.createAttempts, 0);
    expect(identical(auth.currentUser, user), isTrue);
  });
}
