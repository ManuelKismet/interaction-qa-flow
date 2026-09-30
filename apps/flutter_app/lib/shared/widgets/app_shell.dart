import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:int_qa_flow/core/config/app_config.dart';
import 'package:int_qa_flow/shared/models/app_destination.dart';
import 'package:int_qa_flow/shared/utils/responsive.dart';

class AppShell extends StatelessWidget {
  const AppShell({
    required this.currentPath,
    required this.child,
    super.key,
  });

  final String currentPath;
  final Widget child;

  List<AppDestination> get _destinations => [
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
      label: 'Review',
      path: '/review-queue',
      icon: Icons.fact_check_outlined,
      selectedIcon: Icons.fact_check,
    ),
    if (AppConfig.developmentUserRole == 'admin')
      AppDestination(
      label: 'Admin',
      path: '/admin',
      icon: Icons.admin_panel_settings_outlined,
      selectedIcon: Icons.admin_panel_settings,
      ),
  ];

  int _selectedIndex(List<AppDestination> destinations) {
    final selectedPath = switch (currentPath) {
      final path when path.startsWith('/questions') => '/',
      final path when path.startsWith('/guided') => '/guided',
      _ => currentPath,
    };
    if (currentPath == '/review-queue' &&
        !{'admin', 'answer_owner'}.contains(AppConfig.developmentUserRole)) {
      return 0;
    }
    final index = destinations.indexWhere(
      (destination) => destination.path == selectedPath,
    );
    return index < 0 ? 0 : index;
  }

  void _navigate(BuildContext context, int index) {
    context.go(_destinations[index].path);
  }

  @override
  Widget build(BuildContext context) {
    final destinations = _destinations.where((destination) {
      return destination.path != '/review-queue' ||
          {'admin', 'answer_owner'}.contains(AppConfig.developmentUserRole);
    }).toList();
    final isWide = MediaQuery.sizeOf(context).width >=
        Responsive.navigationRailBreakpoint;

    return Scaffold(
      appBar: isWide
          ? null
          : AppBar(
              backgroundColor: const Color(0xFFFFFBF4),
              title: const Text('IntQAFlow'),
            ),
      body: Row(
        children: [
          if (isWide)
            NavigationRail(
              selectedIndex: _selectedIndex(destinations),
              onDestinationSelected: (index) => _navigate(context, index),
              extended: MediaQuery.sizeOf(context).width >= 1100,
              leading: const Padding(
                padding: EdgeInsets.fromLTRB(16, 24, 16, 32),
                child: Text(
                  'IntQAFlow',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
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
              onDestinationSelected: (index) => _navigate(context, index),
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