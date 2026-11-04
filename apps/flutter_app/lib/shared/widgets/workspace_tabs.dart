import 'package:flutter/material.dart';

/// One equal-width tab treatment for the three workspace destinations.
/// Selection follows the established route; a guarded navigation attempt never
/// leaves Groups selected while the user remains in Knowledge or Interact.
class WorkspaceTabs extends StatefulWidget implements PreferredSizeWidget {
  const WorkspaceTabs({
    required this.selectedIndex,
    required this.onSelected,
    super.key,
  });
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  @override
  Size get preferredSize => const Size.fromHeight(48);
  @override
  State<WorkspaceTabs> createState() => _WorkspaceTabsState();
}

class _WorkspaceTabsState extends State<WorkspaceTabs>
    with SingleTickerProviderStateMixin {
  late final TabController controller = TabController(
    length: 3,
    initialIndex: widget.selectedIndex,
    vsync: this,
  );
  @override
  void didUpdateWidget(WorkspaceTabs old) {
    super.didUpdateWidget(old);
    if (controller.index != widget.selectedIndex)
      controller.index = widget.selectedIndex;
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TabBar(
    controller: controller,
    onTap: (index) {
      controller.index = widget.selectedIndex;
      if (index != widget.selectedIndex) widget.onSelected(index);
    },
    tabs: const [
      Tab(text: 'Knowledge'),
      Tab(text: 'Interact'),
      Tab(text: 'Groups'),
    ],
  );
}

class WorkspaceBodyTabs extends StatefulWidget implements PreferredSizeWidget {
  const WorkspaceBodyTabs({
    required this.onTabChanged,
    required this.onGroups,
    required this.groupsAvailable,
    super.key,
  });
  final ValueChanged<int> onTabChanged;
  final void Function(ValueChanged<int> onReturn) onGroups;
  final bool groupsAvailable;
  @override
  Size get preferredSize => const Size.fromHeight(48);
  @override
  State<WorkspaceBodyTabs> createState() => _WorkspaceBodyTabsState();
}

class _WorkspaceBodyTabsState extends State<WorkspaceBodyTabs> {
  TabController? body;
  void changed() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final next = DefaultTabController.of(context);
    if (next != body) {
      body?.removeListener(changed);
      body = next;
      body!.addListener(changed);
    }
  }

  void select(int index) {
    if (!mounted) return;
    body!.animateTo(index);
    widget.onTabChanged(index);
  }

  @override
  void dispose() {
    body?.removeListener(changed);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.groupsAvailable
      ? WorkspaceTabs(
          selectedIndex: body!.index,
          onSelected: (index) {
            if (index == 2) {
              widget.onGroups(select);
            } else {
              select(index);
            }
          },
        )
      : TabBar(
          onTap: widget.onTabChanged,
          tabs: const [
            Tab(text: 'Knowledge'),
            Tab(text: 'Interact'),
          ],
        );
}
