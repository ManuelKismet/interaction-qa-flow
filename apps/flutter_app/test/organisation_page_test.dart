import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:int_qa_flow/core/auth/auth_providers.dart';
import 'package:int_qa_flow/features/ask/application/ask_controller.dart';
import 'package:int_qa_flow/features/governance/application/governance_providers.dart';
import 'package:int_qa_flow/features/organisation/application/organisation_providers.dart';
import 'package:int_qa_flow/features/organisation/domain/organisation_models.dart';
import 'package:int_qa_flow/features/organisation/presentation/organisation_page.dart';

const _activeMembership = ActiveMembership(
  userId: 'member-1',
  organisationId: 'org-1',
  email: 'member@example.test',
  displayName: 'Member',
  role: 'admin',
);

OrganisationProfile _profile({
  bool owner = false,
  Set<String> permissions = const {},
  List<OrganisationCapability> scopes = const [],
}) => OrganisationProfile(
  organisationId: 'org-1',
  organisationName: 'Example organisation',
  userId: 'member-1',
  role: 'admin',
  primaryDepartment: 'People',
  teams: const ['People ops'],
  isOwner: owner,
  permissions: permissions,
  permissionScopes: scopes,
  assignmentManagers: const ['Owner'],
);

Widget _routedPage({
  required AccountMembershipStatus status,
  OrganisationProfile? profile,
  Future<ActiveMembership> Function(Ref ref)? membershipLoader,
}) {
  final router = GoRouter(
    initialLocation: '/organisation',
    routes: [
      GoRoute(
        path: '/organisation',
        builder: (context, state) => const Scaffold(body: OrganisationPage()),
      ),
    ],
  );
  return ProviderScope(
    overrides: [
      accountMembershipStatusProvider.overrideWith((ref) async => status),
      if (status == AccountMembershipStatus.active) ...[
        currentMembershipProvider.overrideWith(
          membershipLoader ?? (ref) async => _activeMembership,
        ),
        organisationProfileProvider.overrideWith(
          (ref) async => profile ?? _profile(),
        ),
        departmentsProvider.overrideWith((ref) async => const []),
        teamsProvider.overrideWith((ref) async => const []),
        myOrganisationJoinRequestsProvider.overrideWith(
          (ref) async => const [],
        ),
        pendingOrganisationJoinRequestsProvider.overrideWith(
          (ref) async => const [],
        ),
        organisationMembersProvider.overrideWith((ref) async => const []),
        organisationPermissionsProvider.overrideWith((ref) async => const []),
        organisationOwnersProvider.overrideWith((ref) async => const []),
      ],
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

void _setViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(900, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  testWidgets('routed organisation page explains when no organisation exists', (
    tester,
  ) async {
    _setViewport(tester);
    await tester.pumpWidget(
      _routedPage(status: AccountMembershipStatus.noMembership),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('No organisation is assigned to this account.'),
      findsOneWidget,
    );
    expect(find.text('Example organisation'), findsNothing);
  });

  testWidgets('admin title alone displays no delegated permissions', (
    tester,
  ) async {
    _setViewport(tester);
    await tester.pumpWidget(
      _routedPage(status: AccountMembershipStatus.active, profile: _profile()),
    );
    await tester.pumpAndSettle();
    expect(find.text('Example organisation'), findsOneWidget);
    expect(find.text('Create Teams'), findsNothing);
    await tester.tap(find.text('Your permissions'));
    await tester.pumpAndSettle();
    final noPermissions = find.text(
      'The administrator title alone grants no organisation permissions.',
    );
    expect(noPermissions, findsOneWidget);
    expect(find.text('Owner administration'), findsNothing);
  });

  testWidgets('membership load failure is explicit and can be retried', (
    tester,
  ) async {
    _setViewport(tester);
    var attempts = 0;
    await tester.pumpWidget(
      _routedPage(
        status: AccountMembershipStatus.active,
        membershipLoader: (ref) async {
          attempts++;
          throw StateError('membership unavailable');
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Your organisation details could not be loaded.'),
      findsOneWidget,
    );
    expect(find.text('Example organisation'), findsNothing);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(attempts, 2);
  });

  testWidgets('owner sees assigned scoped capability and owner controls', (
    tester,
  ) async {
    _setViewport(tester);
    await tester.pumpWidget(
      _routedPage(
        status: AccountMembershipStatus.active,
        profile: _profile(
          owner: true,
          scopes: const [
            OrganisationCapability(
              permission: 'team_membership',
              scopeType: 'department',
              scopeId: 'department-1',
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Role: Organisation owner'), findsOneWidget);
    final ownerControls = find.text('Owner administration');
    expect(ownerControls, findsOneWidget);
    await tester.tap(find.text('Your permissions'));
    await tester.pumpAndSettle();
    expect(find.text('Organisation-wide'), findsWidgets);
    expect(find.text('Appoint admin'), findsNothing);
    await tester.ensureVisible(ownerControls);
    await tester.tap(ownerControls);
    await tester.pumpAndSettle();
    expect(find.text('Appoint admin'), findsOneWidget);
  });

  testWidgets('scoped reviewer is shown the exact department scope', (
    tester,
  ) async {
    _setViewport(tester);
    await tester.pumpWidget(
      _routedPage(
        status: AccountMembershipStatus.active,
        profile: _profile(
          scopes: const [
            OrganisationCapability(
              permission: 'review',
              scopeType: 'department',
              scopeId: 'department-1',
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Your permissions'));
    await tester.pumpAndSettle();
    final departmentScope = find.text('department department-1');
    expect(departmentScope, findsOneWidget);
    expect(find.text('Owner administration'), findsNothing);
  });
}
