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
    final members = ref.watch(organisationMembersProvider);
    return ListView(
      padding: EdgeInsets.all(MediaQuery.sizeOf(context).width < 600 ? 16 : 32),
      children: [
        Text('Admin', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 8),
        const Text('Assign departmental responsibility for verified answers.'),
        const SizedBox(height: 24),
        Text('Members', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        const Text(
          'Add an existing registered account by its verified email, then assign its organisation role and primary department. This does not grant access to another organisation.',
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            onPressed: _busy || members.value == null
                ? null
                : () => _addMember(
                    departments,
                    members.value ?? const [],
                  ),
            icon: const Icon(Icons.person_add_alt_1),
            label: const Text('Add member'),
          ),
        ),
        members.when(
          data: (items) => items.isEmpty
              ? const Text('No active organisation members.')
              : Column(
                  children: [
                    for (final member in items)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(member.displayName),
                        subtitle: Text(
                          '${member.email} · ${member.role} · '
                          '${member.departmentName ?? 'No primary department'}',
                        ),
                        trailing: TextButton(
                          onPressed: _busy
                              ? null
                              : () => _editMember(member, departments),
                          child: const Text('Manage'),
                        ),
                      ),
                  ],
                ),
          loading: () => const LinearProgressIndicator(),
          error: (_, _) => const Text('Organisation members unavailable.'),
        ),
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
              width: 300,
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

  Future<void> _addMember(
    AsyncValue<List<DepartmentSummary>> departments,
    List<OrganisationMember> members,
  ) async {
    final values = await _showMemberEditor(
      title: 'Add organisation member',
      departments: departments.value ?? const [],
      initialRole: 'employee',
      includeEmail: true,
    );
    if (values == null || !mounted) return;
    final existing = members
        .where(
          (member) =>
              member.email.toLowerCase() ==
              (values['email'] as String).toLowerCase(),
        )
        .firstOrNull;
    final roleChanged = existing != null && existing.role != values['role'];
    final departmentChanged =
        existing != null && existing.departmentId != values['department_id'];
    final grantsAdmin =
        values['role'] == 'admin' && existing?.role != 'admin';
    if (existing != null && (roleChanged || departmentChanged)) {
      final departmentName = departments.value
          ?.where(
            (department) => department.id == values['department_id'],
          )
          .firstOrNull
          ?.name;
      final changes = [
        if (roleChanged) 'Role: ${existing.role} → ${values['role']}',
        if (departmentChanged)
          'Primary department: '
              '${existing.departmentName ?? 'None'} → '
              '${departmentName ?? 'None'}',
        if (grantsAdmin)
          'Organisation admins can manage members and administrative review '
              'tools. Private content remains owner-only.',
      ].join('\n');
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Update existing member?'),
          content: Text(changes),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Confirm changes'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    } else if (grantsAdmin) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Add an organisation admin?'),
          content: Text(
            '${values['email']} will be able to manage organisation members '
                'and access administrative review tools. Private content '
                'remains owner-only.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Add admin'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }
    await _run(() async {
      await ref.read(governanceRepositoryProvider).addOrganisationMember(
            email: values['email'] as String,
            role: values['role'] as String,
            departmentId: values['department_id'] as String?,
          );
    });
  }

  Future<void> _editMember(
    OrganisationMember member,
    AsyncValue<List<DepartmentSummary>> departments,
  ) async {
    final values = await _showMemberEditor(
      title: 'Manage ${member.displayName}',
      departments: departments.value ?? const [],
      initialRole: member.role,
      initialDepartmentId: member.departmentId,
      includeEmail: false,
    );
    if (values == null || !mounted) return;
    final confirmAdmin = values['role'] == 'admin' && member.role != 'admin';
    if (confirmAdmin) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Grant organisation admin?'),
          content: Text(
            '${member.displayName} will be able to manage organisation '
                'members and access administrative review tools. Private '
                'content remains owner-only.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Grant admin role'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }
    await _run(() async {
      await ref.read(governanceRepositoryProvider).updateOrganisationMember(
            member.id,
            role: values['role'] as String,
            departmentId: values['department_id'] as String?,
            clearDepartment: values['department_id'] == null,
          );
    });
  }

  Future<Map<String, dynamic>?> _showMemberEditor({
    required String title,
    required List<DepartmentSummary> departments,
    required String initialRole,
    required bool includeEmail,
    String? initialDepartmentId,
  }) =>
      showDialog<Map<String, dynamic>>(
        context: context,
        builder: (context) => _OrganisationMemberEditorDialog(
          title: title,
          departments: departments,
          initialRole: initialRole,
          initialDepartmentId: initialDepartmentId,
          includeEmail: includeEmail,
        ),
      );

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
      ref.invalidate(organisationMembersProvider);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
            error is ApiException ? error.message : 'Unable to save changes.',
          ),
        ));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

class _OrganisationMemberEditorDialog extends StatefulWidget {
  const _OrganisationMemberEditorDialog({
    required this.title,
    required this.departments,
    required this.initialRole,
    required this.initialDepartmentId,
    required this.includeEmail,
  });

  final String title;
  final List<DepartmentSummary> departments;
  final String initialRole;
  final String? initialDepartmentId;
  final bool includeEmail;

  @override
  State<_OrganisationMemberEditorDialog> createState() =>
      _OrganisationMemberEditorDialogState();
}

class _OrganisationMemberEditorDialogState
    extends State<_OrganisationMemberEditorDialog> {
  final _emailController = TextEditingController();
  late String _role = widget.initialRole;
  late String? _departmentId = widget.initialDepartmentId;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: SizedBox(
      width: (MediaQuery.sizeOf(context).width - 64).clamp(0, 440).toDouble(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.includeEmail)
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Verified registered email',
              ),
            ),
          DropdownButtonFormField<String>(
            initialValue: _role,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Organisation role'),
            items: const [
              DropdownMenuItem(
                value: 'employee',
                child: Text('Employee'),
              ),
              DropdownMenuItem(
                value: 'answer_owner',
                child: Text('Department answer owner'),
              ),
              DropdownMenuItem(value: 'admin', child: Text('Admin')),
            ],
            onChanged: (value) => setState(() => _role = value ?? _role),
          ),
          DropdownButtonFormField<String?>(
            initialValue: _departmentId,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Primary department'),
            items: [
              const DropdownMenuItem<String?>(
                value: null,
                child: Text('No primary department'),
              ),
              if (_departmentId != null &&
                  !widget.departments.any(
                    (department) => department.id == _departmentId,
                  ))
                DropdownMenuItem<String?>(
                  value: _departmentId,
                  child: const Text('Current department unavailable'),
                ),
              for (final department in widget.departments)
                DropdownMenuItem<String?>(
                  value: department.id,
                  child: Text(department.name, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: (value) => setState(() => _departmentId = value),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () {
          final email = _emailController.text.trim();
          if (widget.includeEmail && !email.contains('@')) {
            setState(() => _error = 'Enter the verified account email.');
            return;
          }
          Navigator.pop(context, {
            'email': email,
            'role': _role,
            'department_id': _departmentId,
          });
        },
        child: Text(widget.includeEmail ? 'Add member' : 'Save changes'),
      ),
    ],
  );
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