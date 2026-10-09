import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:int_qa_flow/shared/widgets/app_shell.dart';
import 'package:int_qa_flow/core/theme/app_theme.dart';
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
  bool shell = false,
  OrganisationProfile? profile,
  Future<ActiveMembership> Function(Ref ref)? membershipLoader,
}) {
  final router = GoRouter(
    initialLocation: '/organisation',
    routes: [
      GoRoute(
        path: '/organisation',
        builder: (context, state) => shell
            ? const AppShell(
                currentPath: '/organisation',
                child: OrganisationPage(),
              )
            : const Scaffold(body: OrganisationPage()),
      ),
    ],
  );
  return ProviderScope(
    overrides: [
      firebaseAuthProvider.overrideWithValue(_Auth()),
      authStateProvider.overrideWith((ref) => Stream.value(_User())),
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
    child: MaterialApp.router(
      theme: AppTheme.light,
      builder: AppTheme.responsiveBuilder,
      routerConfig: router,
    ),
  );
}

void _setViewport(WidgetTester tester, double width) {
  tester.view.physicalSize = Size(width, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

class _User implements User {
  @override
  String get uid => 'firebase-member';
  @override
  bool get isAnonymous => false;
  @override
  bool get emailVerified => true;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Auth implements FirebaseAuth {
  @override
  User get currentUser => _User();
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  for (final width in [320.0, 390.0, 500.0, 600.0, 760.0, 1100.0]) {
    testWidgets('five-destination organisation navigation fits at $width', (
      tester,
    ) async {
      _setViewport(tester, width);
      await tester.pumpWidget(
        _routedPage(
          status: AccountMembershipStatus.active,
          profile: _profile(owner: true),
          shell: true,
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      if (width < 760) {
        expect(find.byType(NavigationBar), findsOneWidget);
        expect(
          tester.widget<NavigationBar>(find.byType(NavigationBar)).destinations,
          hasLength(5),
        );
        await tester.tap(find.byTooltip('Switch workspace'));
        await tester.pumpAndSettle();
        expect(find.text('Personal workspace'), findsOneWidget);
        expect(tester.takeException(), isNull);
      } else {
        expect(find.byType(NavigationRail), findsOneWidget);
      }
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    });
  }

  for (final width in [320.0, 360.0, 390.0, 600.0, 1100.0]) {
    testWidgets('organisation owner controls fit at $width', (tester) async {
      _setViewport(tester, width);
      await tester.pumpWidget(
        _routedPage(
          status: AccountMembershipStatus.active,
          profile: _profile(owner: true),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Your permissions'));
      await tester.tap(find.text('Your permissions'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Request type'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final fields = find.byType(DropdownButtonFormField<String>);
      for (final element in fields.evaluate()) {
        final rect = tester.getRect(
          find.byElementPredicate((e) => identical(e, element)),
        );
        expect(rect.left, greaterThanOrEqualTo(0));
        expect(rect.right, lessThanOrEqualTo(width));
      }
      await tester.ensureVisible(find.text('Owner administration'));
      await tester.tap(find.text('Owner administration'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Grant permission'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(
        tester
            .getSize(find.widgetWithText(FilledButton, 'Grant permission'))
            .height,
        greaterThanOrEqualTo(48),
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    });
  }
}
