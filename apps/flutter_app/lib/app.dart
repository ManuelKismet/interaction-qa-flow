import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:int_qa_flow/core/auth/auth_providers.dart';
import 'package:int_qa_flow/core/routing/app_router.dart';
import 'package:int_qa_flow/core/theme/app_theme.dart';
import 'package:int_qa_flow/features/guest/presentation/guest_workspace_page.dart';

class IntQaFlowApp extends ConsumerWidget {
  const IntQaFlowApp({this.firebaseReady = true, super.key});

  final bool firebaseReady;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    if (!firebaseReady) return _guestApp(firebaseReady: false);
    return ref.watch(authStateProvider).when(
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
            child: _guestApp(
              firebaseReady: true,
              accountUser: user,
              sharedIdentityActive: true,
            ),
          );
        }
        return ProviderScope(
          key: ValueKey(user.uid),
          child: _RegisteredAccountApp(
            firebaseReady: firebaseReady,
            user: user,
            router: router,
          ),
        );
      },
    );
  }

  MaterialApp _accountStatusApp(String title, String message) => MaterialApp(
    title: 'IntQAFlow',
    debugShowCheckedModeBanner: false,
    theme: AppTheme.light,
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
}

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
  home: GuestWorkspacePage(
    firebaseReady: firebaseReady,
    accountUser: accountUser,
    sharedIdentityActive: sharedIdentityActive,
    membershipStatus: membershipStatus,
    authUnavailable: authUnavailable,
    onRetryAccount: onRetryAccount,
  ),
);

class _RegisteredAccountApp extends ConsumerWidget {
  const _RegisteredAccountApp({
    required this.firebaseReady,
    required this.user,
    required this.router,
  });

  final bool firebaseReady;
  final User user;
  final GoRouter router;

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
        return ref.watch(currentMembershipProvider).when(
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
            routerConfig: router,
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
