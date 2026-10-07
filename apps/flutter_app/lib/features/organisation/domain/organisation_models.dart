class OrganisationProfile {
  const OrganisationProfile({
    required this.organisationId,
    required this.organisationName,
    required this.userId,
    required this.role,
    required this.primaryDepartment,
    required this.teams,
    required this.isOwner,
    required this.permissions,
    required this.permissionScopes,
    required this.assignmentManagers,
  });

  final String organisationId;
  final String organisationName;
  final String userId;
  final String role;
  final String? primaryDepartment;
  final List<String> teams;
  final bool isOwner;
  final Set<String> permissions;
  final List<OrganisationCapability> permissionScopes;
  final List<String> assignmentManagers;

  factory OrganisationProfile.fromJson(Map<String, dynamic> json) =>
      OrganisationProfile(
        organisationId: json['organisation_id'] as String,
        organisationName: json['organisation_name'] as String,
        userId: json['user_id'] as String,
        role: json['role'] as String,
        primaryDepartment: json['primary_department'] as String?,
        teams: (json['teams'] as List<dynamic>).cast<String>(),
        isOwner: json['is_owner'] as bool,
        permissions: (json['permissions'] as List<dynamic>)
            .cast<String>()
            .toSet(),
        permissionScopes: (json['permission_scopes'] as List<dynamic>)
            .map(
              (item) =>
                  OrganisationCapability.fromJson(item as Map<String, dynamic>),
            )
            .toList(),
        assignmentManagers: (json['assignment_managers'] as List<dynamic>)
            .cast<String>(),
      );

  bool can(String permission, {String? scopeType, String? scopeId}) =>
      isOwner ||
      permissions.contains('legacy_admin') ||
      permissionScopes.any(
        (grant) =>
            grant.permission == permission &&
            (grant.scopeType == 'organisation' ||
                (grant.scopeType == scopeType &&
                    grant.scopeId != null &&
                    grant.scopeId == scopeId)),
      );
}

class OrganisationCapability {
  const OrganisationCapability({
    required this.permission,
    required this.scopeType,
    required this.scopeId,
  });

  final String permission;
  final String scopeType;
  final String? scopeId;

  factory OrganisationCapability.fromJson(Map<String, dynamic> json) =>
      OrganisationCapability(
        permission: json['permission'] as String,
        scopeType: json['scope_type'] as String,
        scopeId: json['scope_id'] as String?,
      );
}

class OrganisationPermissionGrant {
  const OrganisationPermissionGrant({
    required this.id,
    required this.userId,
    required this.permission,
    required this.scopeType,
    required this.scopeId,
  });

  final String id;
  final String userId;
  final String permission;
  final String scopeType;
  final String? scopeId;

  factory OrganisationPermissionGrant.fromJson(Map<String, dynamic> json) =>
      OrganisationPermissionGrant(
        id: json['id'] as String,
        userId: json['user_id'] as String,
        permission: json['permission'] as String,
        scopeType: json['scope_type'] as String,
        scopeId: json['scope_id'] as String?,
      );
}

class OrganisationJoinRequest {
  const OrganisationJoinRequest({
    required this.id,
    required this.requestType,
    required this.targetId,
    required this.status,
    required this.reason,
  });

  final String id;
  final String requestType;
  final String targetId;
  final String status;
  final String? reason;

  factory OrganisationJoinRequest.fromJson(Map<String, dynamic> json) =>
      OrganisationJoinRequest(
        id: json['id'] as String,
        requestType: json['request_type'] as String,
        targetId: json['target_id'] as String,
        status: json['status'] as String,
        reason: json['reason'] as String?,
      );
}

class OrganisationOwner {
  const OrganisationOwner({
    required this.userId,
    required this.displayName,
    required this.email,
    required this.active,
  });

  final String userId;
  final String displayName;
  final String email;
  final bool active;

  factory OrganisationOwner.fromJson(Map<String, dynamic> json) =>
      OrganisationOwner(
        userId: json['user_id'] as String,
        displayName: json['display_name'] as String,
        email: json['email'] as String,
        active: json['active'] as bool,
      );
}
