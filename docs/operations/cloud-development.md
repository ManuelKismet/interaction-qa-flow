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

Pending infrastructure acceptance: Cloud Run container
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

Cloud SQL is RUNNABLE. Hosted intqaflow_dev created; pgvector 0.8.5 installed.
All migrations completed through 0007. Runtime table reads succeed and schema
creation is denied. SQLAlchemy runtime connection and API health smoke checks
passed. No public listener opened. Runtime connection stored in Secret Manager
as intqaflow-dev-database-url. Credentials stay in private mode-0600 files
outside the repository. The application is not publicly deployed.

## Prepared application handoff (not assigned)
Title: Integrate development Firebase Auth and App Check into IntQAFlow

Keep intqaflow-dev and the existing isolation branch; preserve the startup fix.
Replace backend/app/api/dependencies.py caller identity with verified Firebase
ID tokens. Add a unique Firebase UID mapping migration. Resolve active user,
organisation and role from server-controlled membership. Protect all tenant
and user administration endpoints; reject forged caller identity headers.

In apps/flutter_app, initialize the registered dev Firebase app, implement
email/password sign-in, sign-out, reset and current Bearer token attachment.
Use explicit hosted dev CORS origins. Add App Check client attestation and
custom-backend verification as a separate gate. Observe client traffic first;
enforce after valid hosted traffic and rejection paths pass. Keep developer
debug registration private. App Check does not replace user authentication.

Acceptance: reject missing, expired, wrong-project user tokens; unmapped and
inactive users; forged headers and cross-tenant requests. When enforced, reject
missing, invalid and wrong-app App Check tokens. Test real Flutter auth and
hosted database access. No production resources, secrets committed or tokens
logged. Joint review before release. Copilot owns application coding under the
agreed workflow; Codex owns configuration and environment setup.

## Application integration status

The application change is on the draft isolation-branch PR. It does not deploy
the service, change IAM, or create cloud resources.

- API requests now require a Firebase ID token whose verified UID maps to one
  active `users` membership. Organisation, user, and role are taken from that
  database row. `X-User-ID`, `X-Organisation-ID`, and caller-provided actor
  fields do not establish identity. The organisation-creation API is not
  registered; tenant setup is a private operator action.
- Migration `0008` adds the unique `firebase_uid_mappings` relationship. Apply it
  to the hosted development database only after Codex review.
- Firebase Admin uses Application Default Credentials and
  `FIREBASE_PROJECT_ID`; do not configure downloaded service-account keys.
- App Check is a distinct API dependency. `APP_CHECK_MODE=observe` explicitly
  permits a missing App Check token while validating any provided token.
  `APP_CHECK_MODE=enforce` rejects missing, invalid, and wrong-web-app tokens.
  Keep observation mode until the real hosted web client passes the browser
  matrix below. Codex must configure the approved reCAPTCHA Enterprise provider,
  register the actual hosted web origins and the web app ID with Firebase App
  Check, and provide its public site key as a build define. Firebase App Check
  debug tokens are not enabled in this app.
- Set `CORS_ORIGINS` to an explicit JSON list of hosted web origins (for example,
  `["https://intqaflow-dev.web.app"]`). A configured hosted-origin list disables
  the local-only development origin pattern. Wildcard origins are rejected.
- The Flutter web app requires non-secret build defines for Firebase API key,
  registered web app/project IDs, and the registered reCAPTCHA Enterprise site key.
  Firebase email/password sign-in, password reset and sign-out are supported.
  The client sends refreshed ID and App Check tokens and obtains its active
  membership from `/api/v1/auth/me`.

### Private synthetic tenant seed

Create the dedicated synthetic Firebase user in the private development
project, then use its Firebase UID with the API database URL already supplied
to the private Codex runtime. The procedure is repeatable, restricted in code
to `APP_ENV=development` and project `intqaflow-dev`, and only creates a fixed
synthetic tenant/admin. It does not create a Firebase account or credentials.
Never use a real person's UID, email, or data.

```sh
cd backend
APP_ENV=development FIREBASE_PROJECT_ID=intqaflow-dev \
  python -m scripts.seed_synthetic_membership \
  --firebase-uid <synthetic-firebase-uid> --confirm-development
```

The Firebase UID is an identifier, not a token or credential. The script reads
the database URL from the private runtime environment and prints no database
configuration. Do not place that URL or ID token in source control.

### Hosted browser-to-API acceptance matrix

| Check | Expected result |
| --- | --- |
| Sign in at `intqaflow-dev.web.app` with the seeded synthetic account; load Knowledge and Interact | `/api/v1/auth/me` succeeds; API calls carry current ID and App Check tokens |
| Sign out, then reload or call a protected API | UI returns to sign-in; protected API returns 401 without an ID token |
| Missing, malformed, expired, wrong-project ID token | API returns 401 |
| Valid Firebase UID without an active mapping | API returns 401 |
| Forged `X-User-ID`, `X-Organisation-ID`, or actor fields | Identity is still token-derived; conflicting tenant/actor values are rejected |
| Employee role attempts a tenant administration action | API returns 403 |
| Request selects another organisation | API returns 403 or a tenant-scoped not-found response |
| App Check observation mode without token | Request is admitted and missing-token observation is logged without token contents |
| App Check enforcement with no token, invalid token, or token for another app | API returns 401 |
| Valid App Check token for registered web app with enforcement enabled | Request proceeds to Firebase Auth and membership checks |

### Validation and pending cloud checks

The local synthetic-token tests cover membership resolution, invalid claims,
expired tokens, inactive/unmapped users, forged development headers, tenant
scoping, role restriction, and App Check observation/enforcement. PostgreSQL 16
with pgvector accepted migrations 0001–0008 on a disposable local database; the
synthetic seed completed twice idempotently there. The backend suite reports 46
passed and one existing guided-proposal test failure. That same
`MissingGreenlet` failure reproduces on base commit `80dc87d` with the currently
resolved dependency versions, so it is not introduced by this change.

Flutter tests/analyzer/release build, actual hosted browser-to-API tests, and
service ADC verification require the Flutter SDK and private Codex runtime/site
key; they remain pending. Do not enable App Check enforcement or deploy until
those hosted checks pass. No production deployment, IAM change, credential
retrieval, or cloud resource provisioning was performed.

## Shared guest-group implementation checkpoint

Shared guest groups are implemented in the application draft but are not
enabled in hosted Firebase or deployed. The last verified Firebase checkpoint
above has anonymous authentication disabled. The Flutter client requires the
existing registered Firebase web configuration, App Check provider/site key,
and API connection; guest API calls still pass through App Check. Local guest
Knowledge and Interact remain available without those cloud services.

Before hosted guest acceptance, the project owner must explicitly review and
approve enabling Firebase anonymous authentication in the development project,
then separately configure any required App Check web settings. Apply migration
`0011_guest_groups` only through the reviewed development migration process and
test the API with synthetic guest identities before hosting group data. This
implementation did not change Firebase settings, IAM, App Check mode, Cloud
SQL, or deployment state.

Group access expires after 90 days without an authorized request. A bounded
dry-run-first cleanup command is available at
`backend/app/maintenance/guest_retention.py`; it is not scheduled or enabled by
this implementation. See
[`guest-group-retention.md`](guest-group-retention.md) for backup, recovery,
permissions, and scheduler review requirements. Do not treat access expiry as
deletion or promise that exported copies can be revoked.

Backend guest-group tests use isolated SQLite and synthetic verified-token
fixtures. PostgreSQL migration SQL generation was checked offline; no hosted
migration or Firebase emulator/browser acceptance was performed. Flutter
analyzer, tests, and web build remain pending when the SDK is unavailable.
