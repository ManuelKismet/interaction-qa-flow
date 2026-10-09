import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:int_qa_flow/core/auth/auth_providers.dart';
import 'package:int_qa_flow/core/routing/app_router.dart';
import 'package:int_qa_flow/core/theme/app_theme.dart';
import 'package:int_qa_flow/features/guest/presentation/guest_workspace_page.dart';

class IntQaFlowApp extends ConsumerWidget {
  const IntQaFlowApp({this.firebaseReady = true, super.key});

  final bool firebaseReady;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(initialAppLocationProvider);
    if (!firebaseReady) return _guestApp(firebaseReady: false);
    return ref
        .watch(authStateProvider)
        .when(
          loading: () => _accountStatusApp(
            'Checking account',
            'Checking whether this device has a signed-in identity.',
          ),
          error: (_, _) {
            final user = ref.read(firebaseAuthProvider).currentUser;
            final guestApp = _guestApp(
              firebaseReady: true,
              accountUser: user,
              membershipStatus: AccountMembershipStatus.unavailable,
              authUnavailable: true,
              onRetryAccount: () => ref.invalidate(authStateProvider),
            );
            return user == null
                ? guestApp
                : ProviderScope(key: ValueKey(user.uid), child: guestApp);
          },
          data: (user) {
            if (user == null) {
              return _guestApp(firebaseReady: true);
            }
            if (user.isAnonymous) {
              return ProviderScope(
                key: ValueKey(user.uid),
                child: _AnonymousSessionToLocalWorkspace(user: user),
              );
            }
            return ProviderScope(
              key: ValueKey(user.uid),
              child: _RegisteredAccountApp(
                firebaseReady: firebaseReady,
                user: user,
              ),
            );
          },
        );
  }
}

class _AnonymousSessionToLocalWorkspace extends ConsumerStatefulWidget {
  const _AnonymousSessionToLocalWorkspace({required this.user});

  final User user;

  @override
  ConsumerState<_AnonymousSessionToLocalWorkspace> createState() =>
      _AnonymousSessionToLocalWorkspaceState();
}

class _AnonymousSessionToLocalWorkspaceState
    extends ConsumerState<_AnonymousSessionToLocalWorkspace> {
  var _signOutFailed = false;

  @override
  void initState() {
    super.initState();
    unawaited(_endAnonymousSession());
  }

  Future<void> _endAnonymousSession() async {
    try {
      final auth = ref.read(firebaseAuthProvider);
      final currentUser = auth.currentUser;
      if (currentUser?.uid == widget.user.uid && currentUser!.isAnonymous) {
        await auth.signOut();
      }
    } on Object {
      if (mounted) setState(() => _signOutFailed = true);
    }
  }

  @override
  Widget build(BuildContext context) => _guestApp(
    firebaseReady: _signOutFailed,
    accountUser: _signOutFailed ? widget.user : null,
  );
}

MaterialApp _accountStatusApp(String title, String message) => MaterialApp(
  title: 'IntQAFlow',
  debugShowCheckedModeBanner: false,
  theme: AppTheme.light,
  builder: AppTheme.responsiveBuilder,
  home: Scaffold(
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(title),
          const SizedBox(height: 8),
          Text(message),
        ],
      ),
    ),
  ),
);
MaterialApp _guestApp({
  required bool firebaseReady,
  User? accountUser,
  bool sharedIdentityActive = false,
  AccountMembershipStatus? membershipStatus,
  bool authUnavailable = false,
  VoidCallback? onRetryAccount,
}) => MaterialApp(
  title: 'IntQAFlow',
  debugShowCheckedModeBanner: false,
  theme: AppTheme.light,
  builder: AppTheme.responsiveBuilder,
  home: Consumer(
    builder: (context, ref, child) {
      final localGuest = accountUser == null || accountUser.isAnonymous;
      final location = Uri.parse(ref.watch(initialAppLocationProvider));
      final interact =
          localGuest && location.path.startsWith('/personal/interact');
      final segments = location.pathSegments;
      final sessionId =
          interact && segments.length == 4 && segments[2] == 'sessions'
          ? segments[3]
          : null;
      return GuestWorkspacePage(
        firebaseReady: firebaseReady,
        personalWorkspaceEnabled: true,
        accountUser: accountUser,
        sharedIdentityActive: sharedIdentityActive,
        membershipStatus: membershipStatus,
        authUnavailable: authUnavailable,
        onRetryAccount: onRetryAccount,
        initialWorkspaceTab: interact ? 1 : 0,
        initialSessionId: sessionId,
        initialQuestionId: interact
            ? location.queryParameters['questionId']
            : null,
        initialParticipantId: interact
            ? location.queryParameters['participantId']
            : null,
        onGuestLocationChanged: localGuest
            ? (index, id) {
                unawaited(
                  SystemNavigator.routeInformationUpdated(
                    uri: Uri.parse(
                      index == 0
                          ? '/personal'
                          : id == null
                          ? '/personal/interact'
                          : '/personal/interact/sessions/${Uri.encodeComponent(id)}',
                    ),
                    replace: true,
                  ),
                );
              }
            : null,
      );
    },
  ),
);

class _RegisteredAccountApp extends ConsumerWidget {
  const _RegisteredAccountApp({
    required this.firebaseReady,
    required this.user,
  });

  final bool firebaseReady;
  final User user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(accountMembershipStatusProvider);
    return status.when(
      loading: () => _statusApp(
        context,
        'Checking organisation membership',
        'Your account is signed in. Organisation access is being verified.',
        onSignOut: () => ref.read(firebaseAuthProvider).signOut(),
      ),
      error: (_, _) => _guestApp(
        firebaseReady: firebaseReady,
        accountUser: user,
        membershipStatus: AccountMembershipStatus.unavailable,
        onRetryAccount: () {
          ref
            ..invalidate(accountMembershipStatusProvider)
            ..invalidate(currentMembershipProvider);
        },
      ),
      data: (membershipStatus) {
        if (membershipStatus != AccountMembershipStatus.active) {
          return _guestApp(
            firebaseReady: firebaseReady,
            accountUser: user,
            membershipStatus: membershipStatus,
          );
        }
        return ref
            .watch(currentMembershipProvider)
            .when(
              loading: () => _statusApp(
                context,
                'Loading organisation workspace',
                'Your account is signed in. Loading your verified workspace access.',
                onSignOut: () => ref.read(firebaseAuthProvider).signOut(),
              ),
              error: (_, _) => _guestApp(
                firebaseReady: firebaseReady,
                accountUser: user,
                membershipStatus: AccountMembershipStatus.unavailable,
                onRetryAccount: () {
                  ref
                    ..invalidate(accountMembershipStatusProvider)
                    ..invalidate(currentMembershipProvider);
                },
              ),
              data: (_) => MaterialApp.router(
                title: 'IntQAFlow',
                debugShowCheckedModeBanner: false,
                theme: AppTheme.light,
                builder: AppTheme.responsiveBuilder,
                routerConfig: ref.watch(appRouterProvider(user.uid)),
              ),
            );
      },
    );
  }

  MaterialApp _statusApp(
    BuildContext context,
    String title,
    String message, {
    required VoidCallback onSignOut,
  }) => MaterialApp(
    title: 'IntQAFlow',
    debugShowCheckedModeBanner: false,
    theme: AppTheme.light,
    builder: AppTheme.responsiveBuilder,
    home: Scaffold(
      appBar: AppBar(title: const Text('Account')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),
                Text(user.email ?? 'Signed-in account'),
                const SizedBox(height: 8),
                Text(message),
                const SizedBox(height: 20),
                OutlinedButton(
                  onPressed: onSignOut,
                  child: const Text('Sign out'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
