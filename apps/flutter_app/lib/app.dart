import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:int_qa_flow/core/auth/auth_providers.dart';
import 'package:int_qa_flow/core/auth/sign_in_page.dart';
import 'package:int_qa_flow/core/routing/app_router.dart';
import 'package:int_qa_flow/core/theme/app_theme.dart';

class IntQaFlowApp extends ConsumerWidget {
  const IntQaFlowApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authStateProvider);
    return auth.when(
      loading: () => _messageApp(const CircularProgressIndicator()),
      error: (_, _) => _messageApp(
        const Text('Unable to check your sign-in session.'),
      ),
      data: (user) {
        if (user == null) {
          return MaterialApp(
            title: 'IntQAFlow',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light,
            home: const SignInPage(),
          );
        }
        return ref.watch(currentMembershipProvider).when(
              loading: () => _messageApp(
                const CircularProgressIndicator(),
              ),
              error: (_, _) => _messageApp(
                const _MembershipError(),
              ),
              data: (_) => MaterialApp.router(
                title: 'IntQAFlow',
                debugShowCheckedModeBanner: false,
                theme: AppTheme.light,
                routerConfig: ref.watch(appRouterProvider),
              ),
            );
      },
    );
  }

  MaterialApp _messageApp(Widget child) => MaterialApp(
        title: 'IntQAFlow',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        home: Scaffold(body: Center(child: child)),
      );
}

class _MembershipError extends ConsumerWidget {
  const _MembershipError();

  @override
  Widget build(BuildContext context, WidgetRef ref) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Your account does not have an active IntQAFlow membership.'),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => ref.read(firebaseAuthProvider).signOut(),
            child: const Text('Sign out'),
          ),
        ],
      );
}