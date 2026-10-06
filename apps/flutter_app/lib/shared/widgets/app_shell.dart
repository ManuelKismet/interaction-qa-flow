import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:int_qa_flow/core/auth/auth_providers.dart';
import 'package:int_qa_flow/shared/models/app_destination.dart';
import 'package:int_qa_flow/shared/utils/responsive.dart';

class AppShell extends ConsumerWidget {
  const AppShell({
    required this.currentPath,
    required this.child,
    super.key,
  });

  final String currentPath;
  final Widget child;

  List<AppDestination> _destinations(
    String role, {
    required bool showGroups,
  }) => [
    AppDestination(
      label: 'Knowledge',
      path: '/',
      icon: Icons.search_outlined,
      selectedIcon: Icons.search,
    ),
    AppDestination(
      label: 'Interact',
      path: '/guided',
      icon: Icons.account_tree_outlined,
      selectedIcon: Icons.account_tree,
    ),
    if (showGroups)
      AppDestination(
        label: 'Groups',
        path: '/guest/groups',
        icon: Icons.group_outlined,
        selectedIcon: Icons.groups,
      ),
    AppDestination(
      label: 'Review',
      path: '/review-queue',
      icon: Icons.fact_check_outlined,
      selectedIcon: Icons.fact_check,
    ),
    if (role == 'admin')
      AppDestination(
        label: 'Admin',
        path: '/admin',
        icon: Icons.admin_panel_settings_outlined,
        selectedIcon: Icons.admin_panel_settings,
      ),
  ];

  int _selectedIndex(List<AppDestination> destinations, String role) {
    final selectedPath = switch (currentPath) {
      final path when path.startsWith('/questions') => '/',
      final path when path.startsWith('/guided') => '/guided',
      final path when path.startsWith('/guest') => '/guest/groups',
      _ => currentPath,
    };
    if (currentPath == '/review-queue' &&
        !{'admin', 'answer_owner'}.contains(role)) {
      return 0;
    }
    final index = destinations.indexWhere(
      (destination) => destination.path == selectedPath,
    );
    return index < 0 ? 0 : index;
  }

  void _navigate(
    BuildContext context,
    int index,
    List<AppDestination> destinations,
  ) {
    context.go(destinations[index].path);
  }

  Widget _accountMenu(
    BuildContext context,
    WidgetRef ref,
    ActiveMembership membership, {
    bool showLabel = true,
  }) =>
      PopupMenuButton<String>(
        tooltip: 'Account',
        onSelected: (value) {
          if (value == 'sign-out') {
            ref.read(firebaseAuthProvider).signOut();
          } else if (value == 'personal') {
            context.go('/personal');
          }
        },
        itemBuilder: (context) => [
          PopupMenuItem(
            enabled: false,
            child: SizedBox(
              width: 260,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    membership.displayName,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Text(membership.email),
                  Text('Organisation workspace · ${membership.role}'),
                  const Text(
                    'Group roles are separate from organisation roles.',
                  ),
                ],
              ),
            ),
          ),
          const PopupMenuDivider(),
          const PopupMenuItem(
            value: 'personal',
            child: Text('Personal workspace'),
          ),
          const PopupMenuItem(value: 'sign-out', child: Text('Sign out')),
        ],
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: showLabel
              ? const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.account_circle_outlined),
                    SizedBox(width: 4),
                    Text('Account'),
                  ],
                )
              : const Icon(Icons.account_circle_outlined),
          ),
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membership = ref.watch(currentMembershipProvider).value;
    final role = membership?.role ?? '';
    final user =
        ref.watch(authStateProvider).value ??
        ref.watch(firebaseAuthProvider).currentUser;
    final destinations = _destinations(
      role,
      showGroups: isVerifiedRegisteredFirebaseUser(user),
    ).where((destination) {
      return destination.path != '/review-queue' ||
          {'admin', 'answer_owner'}.contains(role);
    }).toList();
    final isWide = MediaQuery.sizeOf(context).width >=
        Responsive.navigationRailBreakpoint;

    return Scaffold(
      appBar: isWide
          ? null
          : AppBar(
              backgroundColor: const Color(0xFFFFFBF4),
              title: const Text('IntQAFlow'),
              actions: [
                if (membership != null)
                  _accountMenu(context, ref, membership, showLabel: true),
              ],
            ),
      body: Row(
        children: [
          if (isWide)
            NavigationRail(
              selectedIndex: _selectedIndex(destinations, role),
              onDestinationSelected: (index) =>
                  _navigate(context, index, destinations),
              extended: MediaQuery.sizeOf(context).width >= 1100,
              leading: const Padding(
                padding: EdgeInsets.fromLTRB(16, 24, 16, 32),
                child: Text(
                  'IntQAFlow',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
              ),
              trailing: membership == null
                  ? null
                  : _accountMenu(
                      context,
                      ref,
                      membership,
                      showLabel: MediaQuery.sizeOf(context).width >= 1100,
                    ),
              destinations: [
                for (final destination in destinations)
                  NavigationRailDestination(
                    icon: Icon(destination.icon),
                    selectedIcon: Icon(destination.selectedIcon),
                    label: Text(destination.label),
                  ),
              ],
            ),
          Expanded(child: child),
        ],
      ),
      bottomNavigationBar: isWide
          ? null
          : NavigationBar(
              selectedIndex: _selectedIndex(destinations, role),
              onDestinationSelected: (index) =>
                  _navigate(context, index, destinations),
              destinations: [
                for (final destination in destinations)
                  NavigationDestination(
                    icon: Icon(destination.icon),
                    selectedIcon: Icon(destination.selectedIcon),
                    label: destination.label,
                  ),
              ],
            ),
    );
  }
}