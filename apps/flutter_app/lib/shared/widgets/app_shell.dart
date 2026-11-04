import 'package:int_qa_flow/core/nia/nia_guidance.dart';
import 'package:int_qa_flow/features/guided/presentation/guided_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:int_qa_flow/core/auth/auth_providers.dart';
import 'package:int_qa_flow/features/guest/application/personal_workspace_status.dart';
import 'package:int_qa_flow/features/organisation/application/organisation_providers.dart';
import 'package:int_qa_flow/shared/models/app_destination.dart';
import 'package:int_qa_flow/shared/utils/responsive.dart';

class AppShell extends ConsumerWidget {
  const AppShell({required this.currentPath, required this.child, super.key});

  final String currentPath;
  final Widget child;

  List<AppDestination> _destinations({
    required bool personalWorkspace,
    required bool showGroups,
    required bool showOrganisation,
    required bool showAdmin,
    required bool showReview,
  }) {
    if (personalWorkspace) {
      return [
        AppDestination(
          label: 'Knowledge',
          path: '/personal/ask',
          icon: Icons.search_outlined,
          selectedIcon: Icons.search,
        ),
        AppDestination(
          label: 'Interact',
          path: '/personal/interact',
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
      ];
    }
    return [
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
      AppDestination(
        label: 'Suggestions',
        path: '/suggestions',
        icon: Icons.lightbulb_outline,
        selectedIcon: Icons.lightbulb,
      ),
      if (showOrganisation)
        AppDestination(
          label: 'My organisation',
          path: '/organisation',
          icon: Icons.business_outlined,
          selectedIcon: Icons.business,
        ),
      if (showReview)
        AppDestination(
          label: 'Review',
          path: '/review-queue',
          icon: Icons.fact_check_outlined,
          selectedIcon: Icons.fact_check,
        ),
      if (showAdmin)
        AppDestination(
          label: 'Admin',
          path: '/admin',
          icon: Icons.admin_panel_settings_outlined,
          selectedIcon: Icons.admin_panel_settings,
        ),
    ];
  }

  int _selectedIndex(List<AppDestination> destinations) {
    final selectedPath = switch (currentPath) {
      final path when path.startsWith('/suggestions') => '/suggestions',
      final path when path.startsWith('/group-suggestions') => '/guest/groups',
      final path when path.startsWith('/questions') => '/',
      final path
          when path.startsWith('/personal/questions') ||
              path.startsWith('/personal/ask') =>
        '/personal/ask',
      final path when path.startsWith('/guided') => '/guided',
      final path when path.startsWith('/personal/interact') =>
        '/personal/interact',
      final path when path.startsWith('/guest') => '/guest/groups',
      final path when path.startsWith('/organisation') => '/organisation',
      _ => currentPath,
    };
    final index = destinations.indexWhere(
      (destination) => destination.path == selectedPath,
    );
    return index < 0 ? 0 : index;
  }

  void _navigate(
    BuildContext context,
    WidgetRef ref,
    int index,
    List<AppDestination> destinations,
  ) {
    if (ref.read(personalWorkspaceStatusProvider).hasPendingChanges) {
      _showPendingSaveMessage(context);
      return;
    }
    context.go(destinations[index].path);
  }

  void _showPendingSaveMessage(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Finish or retry pending private account changes before leaving '
          'this workspace.',
        ),
      ),
    );
  }

  Widget _accountMenu(
    BuildContext context,
    WidgetRef ref,
    ActiveMembership membership, {
    bool showLabel = true,
  }) => PopupMenuButton<String>(
    tooltip: 'Account',
    onSelected: (value) {
      if (value == 'sign-out') {
        if (ref.read(personalWorkspaceStatusProvider).hasPendingChanges) {
          _showPendingSaveMessage(context);
          return;
        }
        ref.read(firebaseAuthProvider).signOut();
      } else if (value == 'nia-guidance') {
        final teaching = NiaHost.teachingOf(context);
        teaching?.setEnabled(!teaching.enabled);
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
            ],
          ),
        ),
      ),
      const PopupMenuDivider(),
      const PopupMenuItem(
        value: 'nia-guidance',
        child: ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.info_outline),
          title: Text('Group access information'),
        ),
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

  Widget _workspaceSwitcher(
    BuildContext context, {
    required WidgetRef ref,
    required bool personalWorkspace,
    required bool showLabel,
  }) => PopupMenuButton<String>(
    tooltip: 'Switch workspace',
    onSelected: (value) {
      if (ref.read(personalWorkspaceStatusProvider).hasPendingChanges) {
        _showPendingSaveMessage(context);
        return;
      }
      context.go(value);
    },
    itemBuilder: (context) => [
      PopupMenuItem(
        value: '/personal/ask',
        enabled: !personalWorkspace,
        child: const Text('Personal workspace'),
      ),
      PopupMenuItem(
        value: '/',
        enabled: personalWorkspace,
        child: const Text('Organisation workspace'),
      ),
    ],
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: showLabel
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.workspaces_outlined),
                const SizedBox(width: 4),
                Text(
                  personalWorkspace
                      ? 'Personal workspace'
                      : 'Organisation workspace',
                ),
                const Icon(Icons.arrow_drop_down),
              ],
            )
          : const Icon(Icons.workspaces_outlined),
    ),
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendingWorkspaceChanges = ref.watch(
      personalWorkspaceStatusProvider.select(
        (status) => status.hasPendingChanges,
      ),
    );
    final membership = ref.watch(currentMembershipProvider).value;
    final role = membership?.role ?? '';
    final authorityState = ref.watch(organisationProfileProvider);
    final organisation = authorityState.value;
    final user =
        ref.watch(authStateProvider).value ??
        ref.watch(firebaseAuthProvider).currentUser;
    final personalWorkspace =
        currentPath.startsWith('/personal') ||
        currentPath.startsWith('/guest/groups') ||
        currentPath.startsWith('/group-suggestions');
    final destinations =
        _destinations(
          personalWorkspace: personalWorkspace,
          showGroups: isVerifiedRegisteredFirebaseUser(user),
          showOrganisation: membership != null,
          showAdmin:
              organisation?.isOwner == true ||
              organisation?.permissions.contains('legacy_admin') == true ||
              organisation?.can('team_create') == true ||
              organisation?.can('team_membership') == true,
          showReview:
              role == 'answer_owner' ||
              organisation?.can('review') == true ||
              organisation?.can('answer_approval') == true,
        ).where((destination) {
          return destination.path != '/review-queue' ||
              role == 'answer_owner' ||
              organisation?.can('review') == true ||
              organisation?.can('answer_approval') == true;
        }).toList();
    final isWide =
        MediaQuery.sizeOf(context).width >= Responsive.navigationRailBreakpoint;
    final compactToolbar =
        MediaQuery.sizeOf(context).width < Responsive.phoneBreakpoint;

    final permissionNames = organisation?.permissions.toList() ?? <String>[];
    permissionNames.addAll(
      organisation?.permissionScopes.map(
            (grant) =>
                grant.permission +
                ':' +
                grant.scopeType +
                ':' +
                (grant.scopeId ?? ''),
          ) ??
          <String>[],
    );
    permissionNames.addAll(organisation?.teams ?? <String>[]);
    permissionNames.add(organisation?.primaryDepartment ?? '');
    permissionNames.add(organisation?.isOwner.toString() ?? 'unknown');
    permissionNames.add(organisation?.role ?? 'unknown');
    permissionNames.sort();
    return NiaWorkspaceScope(
      available:
          personalWorkspace ||
          (!authorityState.isLoading &&
              !authorityState.hasError &&
              organisation != null),
      workspace: personalWorkspace
          ? 'personal'
          : 'organisation:' + (membership?.organisationId ?? 'unavailable'),
      authorityRevision: personalWorkspace
          ? 'identity:' + (user?.emailVerified.toString() ?? 'unknown')
          : (membership?.userId ?? 'unknown') +
                ':' +
                role +
                ':' +
                Object.hashAll(permissionNames).toString(),
      child: Builder(
        builder: (context) => PopScope(
          canPop: !pendingWorkspaceChanges,
          onPopInvokedWithResult: (didPop, result) {
            if (!didPop && pendingWorkspaceChanges) {
              _showPendingSaveMessage(context);
            }
          },
          child: Scaffold(
            appBar: isWide && currentPath != '/guided'
                ? null
                : AppBar(
                    backgroundColor: const Color(0xFFFFFBF4),
                    title: MediaQuery.sizeOf(context).width < 280
                        ? null
                        : const Text('IntQAFlow'),
                    actions: [
                      if (currentPath == '/guided') const GuidedInteractMenu(),
                      if (membership != null)
                        _workspaceSwitcher(
                          context,
                          ref: ref,
                          personalWorkspace: personalWorkspace,
                          showLabel: !compactToolbar,
                        ),
                      if (membership != null)
                        _accountMenu(
                          context,
                          ref,
                          membership,
                          showLabel: !compactToolbar,
                        ),
                    ],
                  ),
            body: Row(
              children: [
                if (isWide)
                  NavigationRail(
                    selectedIndex: _selectedIndex(destinations),
                    onDestinationSelected: (index) =>
                        _navigate(context, ref, index, destinations),
                    extended: MediaQuery.sizeOf(context).width >= 1100,
                    leading: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
                      child: Column(
                        children: [
                          const Text(
                            'IntQAFlow',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (membership != null)
                            _workspaceSwitcher(
                              context,
                              ref: ref,
                              personalWorkspace: personalWorkspace,
                              showLabel: false,
                            ),
                        ],
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
                    selectedIndex: _selectedIndex(destinations),
                    onDestinationSelected: (index) =>
                        _navigate(context, ref, index, destinations),
                    destinations: [
                      for (final destination in destinations)
                        NavigationDestination(
                          icon: Icon(destination.icon),
                          selectedIcon: Icon(destination.selectedIcon),
                          label: destination.label,
                        ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
