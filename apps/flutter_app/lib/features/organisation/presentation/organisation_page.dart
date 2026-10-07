import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:int_qa_flow/core/auth/auth_providers.dart';
import 'package:int_qa_flow/features/ask/application/ask_controller.dart';
import 'package:int_qa_flow/features/governance/application/governance_providers.dart';
import 'package:int_qa_flow/features/organisation/application/organisation_providers.dart';
import 'package:int_qa_flow/features/organisation/data/organisation_repository.dart';
import 'package:int_qa_flow/features/organisation/domain/organisation_models.dart';
import 'package:int_qa_flow/features/questions/domain/question_models.dart';

class OrganisationPage extends ConsumerStatefulWidget {
  const OrganisationPage({super.key});

  @override
  ConsumerState<OrganisationPage> createState() => _OrganisationPageState();
}

class _OrganisationPageState extends ConsumerState<OrganisationPage> {
  String _requestType = 'team';
  String? _targetId;
  bool _busy = false;

  Future<void> _request(OrganisationProfile profile) async {
    final uid = ref.read(firebaseAuthProvider).currentUser?.uid;
    if (uid == null || _targetId == null) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(organisationRepositoryProvider)
          .requestMembership(
            uid,
            requestType: _requestType,
            targetId: _targetId!,
          );
      ref.invalidate(myOrganisationJoinRequestsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Membership request saved.')),
        );
      }
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Request could not be saved: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final membershipStatus = ref.watch(accountMembershipStatusProvider);
    return membershipStatus.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => _state(
        'Organisation membership is unavailable.',
        retry: () => ref.invalidate(accountMembershipStatusProvider),
      ),
      data: (status) => switch (status) {
        AccountMembershipStatus.noMembership => _state(
          'No organisation is assigned to this account.',
        ),
        AccountMembershipStatus.inactive => _state(
          'This organisation membership is inactive.',
        ),
        AccountMembershipStatus.unavailable => _state(
          'Organisation membership is unavailable.',
          retry: () => ref.invalidate(accountMembershipStatusProvider),
        ),
        AccountMembershipStatus.active => _activeOrganisation(),
      },
    );
  }

  Widget _activeOrganisation() {
    final membership = ref.watch(currentMembershipProvider);
    return membership.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => _state(
        'Your organisation details could not be loaded.',
        retry: () => ref.invalidate(currentMembershipProvider),
      ),
      data: (_) {
        final profile = ref.watch(organisationProfileProvider);
        return profile.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => _state(
            'Your organisation details could not be loaded.',
            retry: () => ref.invalidate(organisationProfileProvider),
          ),
          data: (value) => _profile(value),
        );
      },
    );
  }

  Widget _profile(OrganisationProfile profile) {
    final departments = ref.watch(departmentsProvider);
    final teams = ref.watch(teamsProvider);
    final myRequests = ref.watch(myOrganisationJoinRequestsProvider);
    final canReviewRequests =
        profile.permissions.contains('review') ||
        profile.permissions.contains('team_membership') ||
        profile.isOwner ||
        profile.permissions.contains('legacy_admin');
    final pending = canReviewRequests
        ? ref.watch(pendingOrganisationJoinRequestsProvider)
        : null;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          'My organisation',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 20),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile.organisationName,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                _detail(
                  'Primary department',
                  profile.primaryDepartment ?? 'Not assigned',
                ),
                _detail(
                  'Role',
                  profile.isOwner ? 'Organisation owner' : profile.role,
                ),
                _detail(
                  'Teams',
                  profile.teams.isEmpty
                      ? 'No Teams assigned'
                      : profile.teams.join(', '),
                ),
                _detail(
                  'Assignment managers',
                  profile.assignmentManagers.isEmpty
                      ? 'No active assignment manager is configured.'
                      : profile.assignmentManagers.join(', '),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text('Your permissions', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        for (final item in const [
          ('team_create', 'Create Teams'),
          ('team_membership', 'Manage Team membership'),
          ('review', 'Review requests and proposals'),
          ('answer_approval', 'Approve answers'),
        ])
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              profile.can(item.$1) ||
                      profile.permissionScopes.any(
                        (grant) => grant.permission == item.$1,
                      )
                  ? Icons.check_circle_outline
                  : Icons.lock_outline,
            ),
            title: Text(item.$2),
            subtitle: Text(_permissionScopes(profile, item.$1)),
          ),
        if (profile.role == 'admin' &&
            !profile.isOwner &&
            !profile.permissions.contains('legacy_admin'))
          const Text(
            'The administrator title alone grants no organisation permissions.',
          ),
        const SizedBox(height: 16),
        Text('Request a change', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.end,
          children: [
            SizedBox(
              width: 220,
              child: DropdownButtonFormField<String>(
                initialValue: _requestType,
                decoration: const InputDecoration(labelText: 'Request type'),
                items: const [
                  DropdownMenuItem(
                    value: 'team',
                    child: Text('Team membership'),
                  ),
                  DropdownMenuItem(
                    value: 'department',
                    child: Text('Department change'),
                  ),
                ],
                onChanged: _busy
                    ? null
                    : (value) {
                        setState(() {
                          _requestType = value ?? 'team';
                          _targetId = null;
                        });
                      },
              ),
            ),
            SizedBox(width: 280, child: _targetDropdown(departments, teams)),
            FilledButton(
              onPressed: _busy || _targetId == null
                  ? null
                  : () => _request(profile),
              child: const Text('Submit request'),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Text('Your requests', style: Theme.of(context).textTheme.titleLarge),
        myRequests.when(
          loading: () => const LinearProgressIndicator(),
          error: (_, _) => _inlineError(
            'Requests could not be loaded.',
            () => ref.invalidate(myOrganisationJoinRequestsProvider),
          ),
          data: (requests) => requests.isEmpty
              ? const Text('No pending or recent requests.')
              : Column(
                  children: [
                    for (final request in requests)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          '${request.requestType == 'team' ? 'Team' : 'Department'} request · ${request.status}',
                        ),
                        subtitle: Text('Target ${request.targetId}'),
                      ),
                  ],
                ),
        ),
        if (pending != null) ...[
          const SizedBox(height: 20),
          Text(
            'Requests you can review',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          pending.when(
            loading: () => const LinearProgressIndicator(),
            error: (_, _) => _inlineError(
              'Review requests could not be loaded.',
              () => ref.invalidate(pendingOrganisationJoinRequestsProvider),
            ),
            data: (requests) => requests.isEmpty
                ? const Text('No requests are pending in your scopes.')
                : Column(
                    children: [
                      for (final request in requests)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            '${request.requestType == 'team' ? 'Team membership' : 'Department change'} · target ${request.targetId}',
                          ),
                          subtitle: Text('Request ${request.id}'),
                          trailing: Wrap(
                            children: [
                              TextButton(
                                onPressed: _busy
                                    ? null
                                    : () => _decide(request, false),
                                child: const Text('Decline'),
                              ),
                              TextButton(
                                onPressed: _busy
                                    ? null
                                    : () => _decide(request, true),
                                child: const Text('Approve'),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
          ),
        ],
        if (profile.isOwner) ...[
          const SizedBox(height: 24),
          _OwnerAdministration(profile: profile),
        ],
      ],
    );
  }

  Widget _targetDropdown(
    AsyncValue<List<DepartmentSummary>> departments,
    AsyncValue<List<TeamSummary>> teams,
  ) {
    if (_requestType == 'team') {
      return teams.when(
        loading: () => const LinearProgressIndicator(),
        error: (_, _) => const Text('Available Teams could not be loaded.'),
        data: (items) =>
            _targetOptions(items.map((item) => (item.id, item.name)).toList()),
      );
    }
    return departments.when(
      loading: () => const LinearProgressIndicator(),
      error: (_, _) => const Text('Available departments could not be loaded.'),
      data: (items) =>
          _targetOptions(items.map((item) => (item.id, item.name)).toList()),
    );
  }

  Widget _targetOptions(List<(String, String)> options) =>
      DropdownButtonFormField<String>(
        key: ValueKey('organisation-request-$_requestType'),
        initialValue: options.any((item) => item.$1 == _targetId)
            ? _targetId
            : null,
        decoration: InputDecoration(
          labelText: _requestType == 'team' ? 'Team' : 'Department',
        ),
        items: [
          for (final option in options)
            DropdownMenuItem(value: option.$1, child: Text(option.$2)),
        ],
        onChanged: (value) => setState(() => _targetId = value),
      );

  Future<void> _decide(OrganisationJoinRequest request, bool approve) async {
    final uid = ref.read(firebaseAuthProvider).currentUser?.uid;
    if (uid == null) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(organisationRepositoryProvider)
          .decideJoinRequest(uid, request.id, approve: approve);
      ref.invalidate(pendingOrganisationJoinRequestsProvider);
      ref.invalidate(myOrganisationJoinRequestsProvider);
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Decision was not saved: $error')),
        );
      }
      ref.invalidate(pendingOrganisationJoinRequestsProvider);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _permissionScopes(OrganisationProfile profile, String permission) {
    if (profile.isOwner || profile.permissions.contains('legacy_admin')) {
      return 'Organisation-wide';
    }
    final scopes = profile.permissionScopes
        .where((grant) => grant.permission == permission)
        .map(
          (grant) => grant.scopeType == 'organisation'
              ? 'Organisation-wide'
              : '${grant.scopeType} ${grant.scopeId}',
        )
        .toSet();
    return scopes.isEmpty ? 'Not granted' : scopes.join(', ');
  }

  Widget _detail(String label, String value) => Padding(
    padding: const EdgeInsets.only(top: 6),
    child: Text('$label: $value'),
  );

  Widget _state(String message, {VoidCallback? retry}) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message, textAlign: TextAlign.center),
          if (retry != null) ...[
            const SizedBox(height: 12),
            OutlinedButton(onPressed: retry, child: const Text('Retry')),
          ],
        ],
      ),
    ),
  );

  Widget _inlineError(String message, VoidCallback retry) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(message),
      TextButton(onPressed: retry, child: const Text('Retry')),
    ],
  );
}

class _OwnerAdministration extends ConsumerStatefulWidget {
  const _OwnerAdministration({required this.profile});

  final OrganisationProfile profile;

  @override
  ConsumerState<_OwnerAdministration> createState() =>
      _OwnerAdministrationState();
}

class _OwnerAdministrationState extends ConsumerState<_OwnerAdministration> {
  static const _permissions = {
    'team_create': 'Create Teams',
    'team_membership': 'Manage Team membership',
    'review': 'Review',
    'answer_approval': 'Approve answers',
  };

  String? _memberId;
  String _permission = 'team_create';
  String _scopeType = 'organisation';
  String? _scopeId;
  bool _busy = false;

  Future<void> _withAction(Future<void> Function(String uid) action) async {
    final uid = ref.read(firebaseAuthProvider).currentUser?.uid;
    if (uid == null) return;
    setState(() => _busy = true);
    try {
      await action(uid);
      ref.invalidate(organisationPermissionsProvider);
      ref.invalidate(organisationOwnersProvider);
      ref.invalidate(organisationProfileProvider);
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Organisation change failed: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final members = ref.watch(organisationMembersProvider);
    final grants = ref.watch(organisationPermissionsProvider);
    final owners = ref.watch(organisationOwnersProvider);
    final departments = ref.watch(departmentsProvider);
    final teams = ref.watch(teamsProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Owner administration',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const Text('Administrator titles do not grant permissions.'),
        members.when(
          loading: () => const LinearProgressIndicator(),
          error: (_, _) => _retry(
            'Members are unavailable.',
            () => ref.invalidate(organisationMembersProvider),
          ),
          data: (items) => DropdownButtonFormField<String>(
            initialValue: items.any((item) => item.id == _memberId)
                ? _memberId
                : null,
            decoration: const InputDecoration(labelText: 'Member'),
            items: [
              for (final item in items)
                DropdownMenuItem(
                  value: item.id,
                  child: Text('${item.displayName} · ${item.email}'),
                ),
            ],
            onChanged: (value) => setState(() => _memberId = value),
          ),
        ),
        Wrap(
          spacing: 8,
          children: [
            OutlinedButton(
              onPressed: _busy || _memberId == null
                  ? null
                  : () => _withAction(
                      (uid) => ref
                          .read(organisationRepositoryProvider)
                          .appointAdmin(uid, _memberId!),
                    ),
              child: const Text('Appoint admin'),
            ),
            OutlinedButton(
              onPressed: _busy || _memberId == null
                  ? null
                  : () => _withAction(
                      (uid) => ref
                          .read(organisationRepositoryProvider)
                          .appointOwner(uid, _memberId!),
                    ),
              child: const Text('Appoint owner'),
            ),
          ],
        ),
        owners.when(
          loading: () => const LinearProgressIndicator(),
          error: (_, _) => _retry(
            'Owners are unavailable.',
            () => ref.invalidate(organisationOwnersProvider),
          ),
          data: (items) => Column(
            children: [
              for (final owner in items)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(owner.displayName),
                  subtitle: Text(
                    '${owner.email} · ${owner.active ? 'active' : 'inactive'}',
                  ),
                  trailing: TextButton(
                    onPressed: _busy
                        ? null
                        : () => _withAction(
                            (uid) => ref
                                .read(organisationRepositoryProvider)
                                .revokeOwner(uid, owner.userId),
                          ),
                    child: const Text('Revoke'),
                  ),
                ),
            ],
          ),
        ),
        DropdownButtonFormField<String>(
          initialValue: _permission,
          decoration: const InputDecoration(labelText: 'Permission'),
          items: [
            for (final permission in _permissions.entries)
              DropdownMenuItem(
                value: permission.key,
                child: Text(permission.value),
              ),
          ],
          onChanged: (value) => setState(() {
            _permission = value ?? 'team_create';
            if (_permission == 'team_create' && _scopeType == 'team') {
              _scopeType = 'organisation';
              _scopeId = null;
            }
          }),
        ),
        DropdownButtonFormField<String>(
          initialValue: _scopeType,
          decoration: const InputDecoration(labelText: 'Scope type'),
          items: [
            const DropdownMenuItem(
              value: 'organisation',
              child: Text('Organisation'),
            ),
            const DropdownMenuItem(
              value: 'department',
              child: Text('Department'),
            ),
            if (_permission != 'team_create')
              const DropdownMenuItem(value: 'team', child: Text('Team')),
          ],
          onChanged: (value) => setState(() {
            _scopeType = value ?? 'organisation';
            _scopeId = null;
          }),
        ),
        if (_scopeType != 'organisation') _scopeDropdown(departments, teams),
        FilledButton(
          onPressed:
              _busy ||
                  _memberId == null ||
                  (_scopeType != 'organisation' && _scopeId == null)
              ? null
              : () => _withAction(
                  (uid) => ref
                      .read(organisationRepositoryProvider)
                      .grantPermission(
                        uid,
                        userId: _memberId!,
                        permission: _permission,
                        scopeType: _scopeType,
                        scopeId: _scopeId,
                      ),
                ),
          child: const Text('Grant permission'),
        ),
        grants.when(
          loading: () => const LinearProgressIndicator(),
          error: (_, _) => _retry(
            'Delegated permissions are unavailable.',
            () => ref.invalidate(organisationPermissionsProvider),
          ),
          data: (items) => Column(
            children: [
              for (final grant in items)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('${grant.permission} · ${grant.scopeType}'),
                  subtitle: Text(
                    'Member ${grant.userId}${grant.scopeId == null ? '' : ' · ${grant.scopeId}'}',
                  ),
                  trailing: TextButton(
                    onPressed: _busy
                        ? null
                        : () => _withAction(
                            (uid) => ref
                                .read(organisationRepositoryProvider)
                                .revokePermission(uid, grant.id),
                          ),
                    child: const Text('Revoke'),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _scopeDropdown(
    AsyncValue<List<DepartmentSummary>> departments,
    AsyncValue<List<TeamSummary>> teams,
  ) {
    final values = _scopeType == 'team' ? teams : departments;
    return values.when(
      loading: () => const LinearProgressIndicator(),
      error: (_, _) => const Text('Scopes are unavailable.'),
      data: (items) {
        final options = _scopeType == 'team'
            ? (items as List<TeamSummary>)
                  .map((item) => (item.id, item.name))
                  .toList()
            : (items as List<DepartmentSummary>)
                  .map((item) => (item.id, item.name))
                  .toList();
        return DropdownButtonFormField<String>(
          key: ValueKey('grant-scope-$_scopeType'),
          initialValue: options.any((item) => item.$1 == _scopeId)
              ? _scopeId
              : null,
          decoration: InputDecoration(labelText: _scopeType),
          items: [
            for (final option in options)
              DropdownMenuItem(value: option.$1, child: Text(option.$2)),
          ],
          onChanged: (value) => setState(() => _scopeId = value),
        );
      },
    );
  }

  Widget _retry(String text, VoidCallback retry) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(text),
      TextButton(onPressed: retry, child: const Text('Retry')),
    ],
  );
}
