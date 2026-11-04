import 'package:firebase_auth/firebase_auth.dart';
import 'package:int_qa_flow/features/organisation/domain/organisation_models.dart';

class GuidedTestUser extends FakeUser {
  GuidedTestUser(this.uid);
  @override
  final String uid;
  @override
  bool get isAnonymous => false;
}

class FakeUser implements User {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

OrganisationProfile guidedProfile({
  String userId = 'session-owner',
  String organisationId = 'organisation-1',
  String role = 'employee',
  bool isOwner = false,
  Set<String> permissions = const {},
  List<OrganisationCapability> scopes = const [],
}) => OrganisationProfile(
  organisationId: organisationId,
  organisationName: 'Organisation',
  userId: userId,
  role: role,
  primaryDepartment: null,
  teams: const [],
  isOwner: isOwner,
  permissions: permissions,
  permissionScopes: scopes,
  assignmentManagers: const [],
);
