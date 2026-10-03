import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:int_qa_flow/features/admin/presentation/admin_page.dart';
import 'package:int_qa_flow/features/ask/application/ask_controller.dart';
import 'package:int_qa_flow/features/ask/presentation/ask_page.dart';
import 'package:int_qa_flow/features/governance/application/governance_providers.dart';
import 'package:int_qa_flow/features/governance/domain/governance_models.dart';
import 'package:int_qa_flow/features/questions/domain/question_models.dart';

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

  testWidgets('ask form exposes team selector and selects parent department',
      (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        departmentsProvider.overrideWith((ref) async => const [finance]),
        teamsProvider.overrideWith((ref) async => const [payroll]),
      ],
      child: const MaterialApp(home: Scaffold(body: AskPage())),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Team (optional)'), findsOneWidget);
    await tester.tap(find.text('No team'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Finance · Payroll').last);
    await tester.pumpAndSettle();

    expect(find.text('Finance'), findsOneWidget);
  });

  testWidgets('admin surface shows team creation and membership controls',
      (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        departmentsProvider.overrideWith((ref) async => const [finance]),
        teamsProvider.overrideWith((ref) async => const [payroll]),
        departmentOwnersProvider.overrideWith((ref) async => const []),
        organisationMembersProvider.overrideWith(
          (ref) async => const [adminMember],
        ),
        teamMembersProvider(payroll.id).overrideWith((ref) async => const []),
      ],
      child: const MaterialApp(
        home: Scaffold(body: AdminPage(adminOverride: true)),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Departments'), findsOneWidget);
    expect(find.text('Members'), findsOneWidget);
    expect(find.text('Add member'), findsOneWidget);
    expect(find.text('Member One'), findsOneWidget);
    expect(
      find.text('member@example.test · employee · Finance'),
      findsOneWidget,
    );
    expect(find.text('Teams'), findsOneWidget);
    expect(find.text('Create team'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Payroll'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Payroll'));
    await tester.pumpAndSettle();
    expect(find.text('Add member'), findsNWidgets(2));
  });
}
