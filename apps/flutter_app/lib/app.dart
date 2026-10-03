import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:int_qa_flow/core/auth/auth_providers.dart';
import 'package:int_qa_flow/core/routing/app_router.dart';
import 'package:int_qa_flow/core/theme/app_theme.dart';
import 'package:int_qa_flow/features/guest/data/guest_group_repository.dart';
import 'package:int_qa_flow/features/guest/presentation/guest_workspace_page.dart';

class IntQaFlowApp extends ConsumerWidget {
  const IntQaFlowApp({this.firebaseReady = true, super.key});

  final bool firebaseReady;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    if (!firebaseReady) return _guestApp(false);
    final auth = ref.watch(authStateProvider);
    return auth.when(
      loading: () => _guestApp(firebaseReady),
      error: (_, _) => _guestApp(firebaseReady),
      data: (user) {
        if (user == null || user.isAnonymous) {
          return _guestApp(firebaseReady, sharedIdentityActive: user?.isAnonymous ?? false);
        }
        return _membershipApp(ref, router, firebaseReady);
      },
    );
  }

  Widget _membershipApp(
    WidgetRef ref,
    GoRouter router,
    bool firebaseReady,
  ) => ref.watch(currentMembershipProvider).when(
        loading: () => _messageApp(const CircularProgressIndicator()),
        error: (_, _) => ref.watch(currentGuestGroupsProvider).when(
              data: (groups) => _guestApp(
                firebaseReady,
                sharedIdentityActive: groups.isNotEmpty,
              ),
              loading: () => _guestApp(firebaseReady),
              error: (_, _) => _guestApp(firebaseReady),
            ),
        data: (_) => MaterialApp.router(
          title: 'IntQAFlow',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          routerConfig: router,
        ),
      );

  MaterialApp _guestApp(
    bool firebaseReady, {
    bool sharedIdentityActive = false,
  }) => MaterialApp(
    title: 'IntQAFlow',
    debugShowCheckedModeBanner: false,
    theme: AppTheme.light,
    home: GuestWorkspacePage(
      firebaseReady: firebaseReady,
      sharedIdentityActive: sharedIdentityActive,
    ),
  );

  MaterialApp _messageApp(Widget child) => MaterialApp(
        title: 'IntQAFlow',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        home: Scaffold(body: Center(child: child)),
      );
}