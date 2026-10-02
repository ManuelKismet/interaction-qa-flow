import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:int_qa_flow/core/api/api_exception.dart';
import 'package:int_qa_flow/core/auth/auth_providers.dart';
import 'package:int_qa_flow/features/ask/application/ask_controller.dart';
import 'package:int_qa_flow/features/governance/application/governance_providers.dart';
import 'package:int_qa_flow/features/governance/data/governance_repository.dart';
import 'package:int_qa_flow/features/governance/domain/governance_models.dart';
import 'package:int_qa_flow/features/questions/domain/question_models.dart';

class AdminPage extends ConsumerStatefulWidget {
  const AdminPage({super.key, this.adminOverride});

  final bool? adminOverride;

  @override
  ConsumerState<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends ConsumerState<AdminPage> {
  final _userIdController = TextEditingController();
  final _teamNameController = TextEditingController();
  final _teamDescriptionController = TextEditingController();
  String? _departmentId;
  String? _teamDepartmentId;
  bool _busy = false;

  @override
  void dispose() {
    _userIdController.dispose();
    _teamNameController.dispose();
    _teamDescriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = widget.adminOverride ??
        ref.watch(currentMembershipProvider).value?.role == 'admin';
    if (!isAdmin) {
      return const Center(child: Text('Administrator access is required.'));
    }
    final owners = ref.watch(departmentOwnersProvider);
    final departments = ref.watch(departmentsProvider);
    final teams = ref.watch(teamsProvider);
    return ListView(
      padding: const EdgeInsets.all(32),
      children: [
        Text('Admin', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 8),
        const Text('Assign departmental responsibility for verified answers.'),
        const SizedBox(height: 24),
        Text('Departments', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        departments.when(
          data: (items) => Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [for (final item in items) Chip(label: Text(item.name))],
          ),
          loading: () => const LinearProgressIndicator(),
          error: (_, _) => const Text('Departments unavailable'),
        ),
        const SizedBox(height: 32),
        Text('Teams', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.end,
          children: [
            SizedBox(
              width: 220,
              child: TextField(
                controller: _teamNameController,
                decoration: const InputDecoration(labelText: 'Team name'),
              ),
            ),
            SizedBox(
              width: 280,
              child: TextField(
                controller: _teamDescriptionController,
                decoration: const InputDecoration(labelText: 'Description (optional)'),
              ),
            ),
            SizedBox(
              width: 220,
              child: departments.when(
                data: (items) => DropdownButtonFormField<String?>(
                  initialValue: _teamDepartmentId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Parent department'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Cross-functional')),
                    for (final item in items)
                      DropdownMenuItem(value: item.id, child: Text(item.name)),
                  ],
                  onChanged: (value) => setState(() => _teamDepartmentId = value),
                ),
                loading: () => const LinearProgressIndicator(),
                error: (_, _) => const Text('Departments unavailable'),
              ),
            ),
            FilledButton.icon(
              onPressed: _busy ? null : _createTeam,
              icon: const Icon(Icons.group_add_outlined),
              label: const Text('Create team'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        teams.when(
          data: (items) => items.isEmpty
              ? const Text('No teams created.')
              : Column(
                  children: [
                    for (final team in items) _TeamAdminTile(team: team),
                  ],
                ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => const Text('Unable to load teams.'),
        ),
        const SizedBox(height: 36),
        Text('Department answer owners', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.end,
          children: [
            SizedBox(
              width: 240,
              child: departments.when(
                data: (items) => DropdownButtonFormField<String>(
                  initialValue: _departmentId,
                  decoration: const InputDecoration(labelText: 'Department'),
                  items: [
                    for (final item in items)
                      DropdownMenuItem(value: item.id, child: Text(item.name)),
                  ],
                  onChanged: (value) => setState(() => _departmentId = value),
                ),
                loading: () => const LinearProgressIndicator(),
                error: (_, _) => const Text('Departments unavailable'),
              ),
            ),
            SizedBox(
              width: 330,
              child: TextField(
                controller: _userIdController,
                decoration: const InputDecoration(labelText: 'User ID'),
              ),
            ),
            FilledButton.icon(
              onPressed: _busy ? null : _assign,
              icon: const Icon(Icons.person_add_alt_1),
              label: const Text('Assign owner'),
            ),
          ],
        ),
        const SizedBox(height: 32),
        Text('Department owners', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        owners.when(
          data: (items) => items.isEmpty
              ? const Text('No answer owners assigned.')
              : Column(
                  children: [
                    for (final owner in items)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(owner.user.displayName),
                        subtitle: Text(owner.department.name),
                        trailing: IconButton(
                          tooltip: 'Remove owner',
                          icon: const Icon(Icons.person_remove_outlined),
                          onPressed: _busy
                              ? null
                              : () => _remove(
                                    owner.department.id,
                                    owner.user.id,
                                  ),
                        ),
                      ),
                  ],
                ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => const Text('Unable to load department owners.'),
        ),
      ],
    );
  }

  Future<void> _assign() async {
    final userId = _userIdController.text.trim();
    if (_departmentId == null || userId.isEmpty) return;
    await _run(() => ref.read(governanceRepositoryProvider).assignOwner(
          _departmentId!,
          userId,
        ));
    _userIdController.clear();
  }

  Future<void> _createTeam() async {
    final name = _teamNameController.text.trim();
    if (name.isEmpty) return;
    await _run(() => ref.read(governanceRepositoryProvider).createTeam(
          name: name,
          departmentId: _teamDepartmentId,
          description: _teamDescriptionController.text.trim(),
        ));
    _teamNameController.clear();
    _teamDescriptionController.clear();
    ref.invalidate(teamsProvider);
  }

  Future<void> _remove(String departmentId, String userId) => _run(
        () => ref.read(governanceRepositoryProvider).removeOwner(
              departmentId,
              userId,
            ),
      );

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
      ref.invalidate(departmentOwnersProvider);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(error is ApiException ? error.message : 'Unable to save assignment.'),
        ));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

class _TeamAdminTile extends ConsumerStatefulWidget {
  const _TeamAdminTile({required this.team});

  final TeamSummary team;

  @override
  ConsumerState<_TeamAdminTile> createState() => _TeamAdminTileState();
}

class _TeamAdminTileState extends ConsumerState<_TeamAdminTile> {
  final _memberIdController = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _memberIdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final members = ref.watch(teamMembersProvider(widget.team.id));
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      title: Text(widget.team.name),
      subtitle: Text(widget.team.department?.name ?? 'Cross-functional'),
      children: [
        members.when(
          data: (items) => Column(
            children: [
              for (final membership in items)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(membership.user.displayName),
                  subtitle: Text(membership.user.role),
                  trailing: IconButton(
                    tooltip: 'Remove team member',
                    icon: const Icon(Icons.person_remove_outlined),
                    onPressed: _busy ? null : () => _remove(membership),
                  ),
                ),
            ],
          ),
          loading: () => const LinearProgressIndicator(),
          error: (_, _) => const Text('Unable to load team members.'),
        ),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _memberIdController,
                decoration: const InputDecoration(labelText: 'User ID'),
              ),
            ),
            const SizedBox(width: 12),
            FilledButton.icon(
              onPressed: _busy ? null : _add,
              icon: const Icon(Icons.person_add_alt_1),
              label: const Text('Add member'),
            ),
          ],
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Future<void> _add() async {
    final userId = _memberIdController.text.trim();
    if (userId.isEmpty) return;
    await _run(
      () => ref.read(governanceRepositoryProvider).addTeamMember(
            widget.team.id,
            userId,
          ),
    );
    _memberIdController.clear();
  }

  Future<void> _remove(TeamMembership membership) => _run(
        () => ref.read(governanceRepositoryProvider).removeTeamMember(
              widget.team.id,
              membership.user.id,
            ),
      );

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
      ref.invalidate(teamMembersProvider(widget.team.id));
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(error is ApiException
              ? error.message
              : 'Unable to update team membership.'),
        ));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}