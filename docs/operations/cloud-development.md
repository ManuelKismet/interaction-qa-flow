# IntQAFlow hosted development checkpoint

Updated 2026-10-02. Founder authorized a real hosted development backend,
Google Cloud/Firebase access, and a GBP 25 monthly backend spending allowance.
Knowledge and Interact remain one platform. Production comes later.

## Verified cloud foundation

- Dedicated project: intqaflow-dev (398672910103).
- Firebase project ACTIVE; addFirebase operation completed successfully.
- Billing linked to the existing open GBP account.
- Project-only monthly budget: GBP 25, excluding credits; actual alerts at
  50%, 80%, 100%, plus a forecasted 100% alert. Budget alerts are not a hard cap.
- Budget ID: 996a1e77-086f-482a-a71a-0f1fe4fe8fb4.
- Cloud SQL creation submitted: intqaflow-dev-pg, PostgreSQL 16, Enterprise,
  db-f1-micro, europe-west2 (London), zonal, 10 GB SSD, no automatic disk growth.
- Seven daily backups configured, starting at 02:00 UTC; PITR disabled for this
  small development instance. Connector enforcement REQUIRED, encrypted
  connections only, IAM database authentication enabled. No IP allowlist added.
- The devcontainer no longer creates a PostgreSQL sidecar. Its database URL is
  a deliberately unusable cloud-connection placeholder until a scoped
  authenticated proxy/connector is configured. Loopback proxying would connect
  to the managed cloud database; it does not host a local database.
- Existing sidecar volume was not deleted. Rebuild the Codespace only after
  recording required state and verifying the cloud connection.

## Application gates and ownership

The platform is NOT deployed. Founder explicitly requested the startup fix
before authentication integration on 2026-10-02. Added deferred annotations
in TeamService to avoid the list-method/builtin-type collision. Clean FastAPI
import passed and all 38 existing fake-provider backend tests passed (4.71s).
These tests use isolated in-memory SQLite, not the hosted PostgreSQL instance.
IQ-01 remediation is implemented on the draft branch; joint review remains. Codex owns this infrastructure/configuration setup; Copilot owns
application fixes and relevant tests; founder + Codex review together.

Prepared Copilot scope (not yet assigned):
1. Preserve and review the IQ-01 fix in f836415; import and 38 tests pass.
2. Implement Firebase Auth in Flutter and validate Firebase ID tokens on the
   backend. Derive user/organisation/role from server-controlled membership;
   reject forged development identity headers and cross-tenant requests.
3. Add repeatable synthetic tenant/user seeding and verify Knowledge, Interact,
   Review and recursive participant branches against managed PostgreSQL.

Pending infrastructure acceptance: database RUNNABLE status, database creation,
pgvector installation, scoped database roles/credentials, Cloud Run container
build and private service deployment, application Firebase integration, browser
access rejection outside the permitted boundary, migrations and live checks.
Do not publish the unauthenticated development-identity API to solve access.
No production environment, application deployment or release was performed.

## Resume

Use Codespace bookish-happiness-w974vpwgq7j3g95v and draft PR #2 on
chore/intqaflow-private-dev-isolation. Google Cloud SDK is installed at
$HOME/.local/share/intqaflow/gcloud/google-cloud-sdk/bin/gcloud.
Use explicit --project=intqaflow-dev and --billing-project=intqaflow-dev
where required; do not change other applications' resources or defaults.
Do not print tokens, passwords or credential files. User login remains in
the private Codespace for the authorized task; no credentials are committed.

Firebase development web app verified ACTIVE: 1:398672910103:web:e968506023d8eab9290952.

## Firebase authentication checkpoint
Authentication initialized successfully. Configuration readback confirmed
email/password enabled with passwordRequired=true. Anonymous and phone
authentication are disabled. Authorized domains are only
intqaflow-dev.firebaseapp.com and intqaflow-dev.web.app. No users created.

Application acceptance: Flutter sign-in, sign-out and password reset; current
Firebase Bearer tokens on API calls; backend verifies signature, expiry,
audience and issuer. Missing, malformed, expired and wrong-project tokens
return 401. UID maps to server-controlled membership, rejecting forged caller
identity and cross-tenant access. Test session expiry and tenant isolation,
then verify the actual browser-to-API flow. Never log tokens or secrets.

Cloud SQL remains PENDING_CREATE. The application is not publicly deployed.
