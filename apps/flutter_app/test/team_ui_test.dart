import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:int_qa_flow/core/auth/auth_providers.dart';
import 'package:int_qa_flow/features/admin/presentation/admin_page.dart';
import 'package:int_qa_flow/features/ask/application/ask_controller.dart';
import 'package:int_qa_flow/features/ask/presentation/ask_page.dart';
import 'package:int_qa_flow/features/governance/data/governance_repository.dart';
import 'package:int_qa_flow/features/governance/application/governance_providers.dart';
import 'package:int_qa_flow/features/governance/domain/governance_models.dart';
import 'package:int_qa_flow/features/questions/data/questions_repository.dart';
import 'package:int_qa_flow/features/questions/domain/question_models.dart';
import 'package:int_qa_flow/features/organisation/application/organisation_providers.dart';
import 'package:int_qa_flow/features/organisation/domain/organisation_models.dart';

const finance = DepartmentSummary(id: 'department-1', name: 'Finance');
const payroll = TeamSummary(
  id: 'team-1',
  name: 'Payroll',
  departmentId: 'department-1',
  department: finance,
  status: 'active',
);
const adminMember = OrganisationMember(
  id: 'member-1',
  email: 'member@example.test',
  displayName: 'Member One',
  role: 'employee',
  status: 'active',
  departmentId: 'department-1',
  departmentName: 'Finance',
);
const answerOwnerMember = OrganisationMember(
  id: 'answer-owner-1',
  email: 'a-very-long-answer-owner-address@example.test',
  displayName: 'Answer Owner With A Long Display Name',
  role: 'answer_owner',
  status: 'active',
);

class _FakeQuestionsRepository extends QuestionsRepository {
  _FakeQuestionsRepository() : super(Dio());

  final departments = <DepartmentSummary>[];

  @override
  Future<DepartmentSummary> createDepartment(String name) async {
    final department = DepartmentSummary(
      id: 'created-department-${departments.length + 1}',
      name: name,
    );
    departments.add(department);
    return department;
  }
}

class _FakeGovernanceRepository extends GovernanceRepository {
  _FakeGovernanceRepository() : super(Dio());

  String? assignedDepartmentId;
  String? assignedOwnerId;
  String? teamMemberId;
  List<TeamMembership> teamMemberships = const [];

  @override
  Future<void> assignOwner(String departmentId, String userId) async {
    assignedDepartmentId = departmentId;
    assignedOwnerId = userId;
  }

  @override
  Future<void> addTeamMember(String teamId, String userId) async {
    teamMemberId = userId;
    teamMemberships = [
      ...teamMemberships,
      TeamMembership(
        id: 'membership-${teamMemberships.length + 1}',
        teamId: teamId,
        user: UserSummary(
          id: userId,
          displayName: 'Answer Owner',
          role: 'answer_owner',
        ),
      ),
    ];
  }

  @override
  Future<List<TeamMembership>> teamMembers(String teamId) async =>
      teamMemberships;
}

void main() {
  test('linked team suggests its parent department', () {
    expect(
      suggestedDepartmentForTeam(const [payroll], payroll.id, null),
      finance.id,
    );
    expect(
      suggestedDepartmentForTeam(const [payroll], null, finance.id),
      finance.id,
    );
  });

  testWidgets('ask form exposes team selector and selects parent department', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentMembershipProvider.overrideWith(
            (ref) async => const ActiveMembership(
              userId: 'admin-user',
              organisationId: 'test-organisation',
              email: 'admin@example.test',
              displayName: 'Test Admin',
              role: 'admin',
            ),
          ),
          departmentsProvider.overrideWith((ref) async => const [finance]),
          teamsProvider.overrideWith((ref) async => const [payroll]),
        ],
        child: const MaterialApp(home: Scaffold(body: AskPage())),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Team (optional)'), findsOneWidget);
    await tester.tap(find.text('No team'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Finance · Payroll').last);
    await tester.pumpAndSettle();

    expect(find.text('Finance'), findsOneWidget);
  });

  testWidgets('admin surface shows team creation and membership controls', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final questionsRepository = _FakeQuestionsRepository();
    final governanceRepository = _FakeGovernanceRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentMembershipProvider.overrideWith(
            (ref) async => const ActiveMembership(
              userId: 'admin-user',
              organisationId: 'test-organisation',
              email: 'admin@example.test',
              displayName: 'Test Admin',
              role: 'admin',
            ),
          ),
          organisationProfileProvider.overrideWith(
            (ref) async => const OrganisationProfile(
              organisationId: 'test-organisation',
              organisationName: 'Test organisation',
              userId: 'admin-user',
              role: 'admin',
              primaryDepartment: null,
              teams: [],
              isOwner: false,
              permissions: {'legacy_admin'},
              permissionScopes: [],
              assignmentManagers: [],
            ),
          ),
          governanceRepositoryProvider.overrideWithValue(governanceRepository),
          questionsRepositoryProvider.overrideWithValue(questionsRepository),
          departmentsProvider.overrideWith(
            (ref) async => questionsRepository.departments.toList(),
          ),
          teamsProvider.overrideWith((ref) async => const [payroll]),
          departmentOwnersProvider.overrideWith((ref) async => const []),
          organisationMembersProvider.overrideWith(
            (ref) async => const [adminMember, answerOwnerMember],
          ),
          teamMembersProvider(
            payroll.id,
          ).overrideWith((ref) async => governanceRepository.teamMemberships),
        ],
        child: const MaterialApp(home: Scaffold(body: AdminPage())),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Departments'), findsOneWidget);
    expect(find.text('Members'), findsOneWidget);
    final addOrganisationMember = find.widgetWithText(
      FilledButton,
      'Add organisation member',
    );
    expect(addOrganisationMember, findsOneWidget);
    await tester.tap(addOrganisationMember);
    await tester.pumpAndSettle();
    final organisationMemberDialog = find.byType(AlertDialog);
    expect(
      find.descendant(
        of: organisationMemberDialog,
        matching: find.text('Add organisation member'),
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Member One'), findsOneWidget);
    expect(
      find.text('member@example.test · employee · Finance'),
      findsOneWidget,
    );
    final noDepartmentsMessage = find.text(
      'No departments yet. Create one to assign members.',
    );
    await tester.scrollUntilVisible(
      noDepartmentsMessage,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(noDepartmentsMessage, findsOneWidget);
    const departmentName = 'Operations and Compliance Department';
    final createDepartmentButton = find.byKey(
      const ValueKey('create-department-button'),
    );
    await tester.scrollUntilVisible(
      createDepartmentButton,
      -300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(createDepartmentButton);
    await tester.enterText(find.byType(TextField).at(0), departmentName);
    await tester.tap(createDepartmentButton);
    await tester.pumpAndSettle();
    expect(questionsRepository.departments.single.name, departmentName);
    expect(find.text(departmentName), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Select a department'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Select a department'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(departmentName).last);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(
      find.descendant(
        of: find.byKey(
          const ValueKey('department-answer-owner-department-selector'),
        ),
        matching: find.text(departmentName),
      ),
      findsOneWidget,
    );
    await tester.scrollUntilVisible(
      find.text('Select a member').first,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Select a member').first);
    await tester.pumpAndSettle();
    await tester.tap(
      find
          .text(
            'Answer Owner With A Long Display Name · '
            'a-very-long-answer-owner-address@example.test',
          )
          .last,
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('department-answer-owner-selector')),
        matching: find.text('Answer Owner With A Long Display Name'),
      ),
      findsOneWidget,
    );
    final assignOwnerButton = find.widgetWithText(FilledButton, 'Assign owner');
    await tester.scrollUntilVisible(
      assignOwnerButton,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(assignOwnerButton);
    await tester.pumpAndSettle();
    expect(governanceRepository.assignedDepartmentId, 'created-department-1');
    expect(governanceRepository.assignedOwnerId, answerOwnerMember.id);

    expect(find.text('Teams'), findsOneWidget);
    expect(find.text('Create team'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Payroll'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    final payrollTile = find.ancestor(
      of: find.text('Payroll'),
      matching: find.byType(ExpansionTile),
    );
    await tester.tap(find.text('Payroll'));
    await tester.pumpAndSettle();
    final payrollSelector = find.byKey(
      const ValueKey('team-member-selector-team-1'),
    );
    await tester.ensureVisible(payrollSelector);
    expect(find.text('User ID'), findsNothing);
    expect(
      find.descendant(
        of: payrollTile,
        matching: find.widgetWithText(FilledButton, 'Add team member'),
      ),
      findsOneWidget,
    );
    await tester.tap(payrollSelector);
    await tester.pumpAndSettle();
    await tester.tap(
      find.text(
        'Answer Owner With A Long Display Name · '
        'a-very-long-answer-owner-address@example.test',
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('team-member-selector-team-1')),
        matching: find.text('Answer Owner With A Long Display Name'),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await tester.tap(find.widgetWithText(FilledButton, 'Add team member'));
    await tester.pumpAndSettle();
    expect(governanceRepository.teamMemberId, answerOwnerMember.id);
  });
}
