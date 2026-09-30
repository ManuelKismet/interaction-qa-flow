abstract final class AppConfig {
  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8000',
  );

  // TODO(auth): replace these development IDs with token-derived identity.
  static const developmentOrganisationId = String.fromEnvironment(
    'DEV_ORGANISATION_ID',
  );
  static const developmentUserId = String.fromEnvironment('DEV_USER_ID');
  static const developmentUserRole = String.fromEnvironment(
    'DEV_USER_ROLE',
    defaultValue: 'employee',
  );
}