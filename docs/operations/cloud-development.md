# IntQAFlow hosted development checkpoint

Updated 2026-10-03. Founder authorized a real hosted development backend,
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
3. Exercise Knowledge, Interact, Review and recursive participant branches with
   a freshly registered account and explicitly provisioned membership.

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

### Manual account acceptance and account inventory

Do not use a pre-created or synthetic account for live/manual browser testing.
Use **Create account** in the app with a newly created, explicitly disposable
email address, complete Firebase's email verification, sign out, and then use
the normal **Sign in** flow. Confirm that `/api/v1/auth/me` reports no
organisation membership until an administrator/operator explicitly provisions
one. Account creation does not enroll users or grant guest-group access.

For a new disposable organisation, an authorized operator may use
`scripts/provision_organisation_admin.py` with that verified Firebase account;
the command creates the tenant and first admin and writes an audit event. For
an existing organisation, an existing org admin uses **Admin → Members** to
add the verified account or change its role/primary department. That endpoint
resolves the account through Firebase Admin, verifies email, limits changes to
the caller's organisation, and audits membership/role/department changes.
Verify the resulting role in `/api/v1/auth/me` after re-authentication or token
refresh, and then exercise the admin UI. Never pass a caller-selected user,
organisation, or role as proof of identity. These steps are procedures only;
this change did not create accounts, memberships, or grants.

Repository inventory (source inspection only; no hosted Firebase Auth or
database listing was accessed):

| Identifier | Definition and persistence |
| --- | --- |
| `synthetic-admin@invalid.example`, display name `Synthetic Development Admin`, tenant slug `synthetic-development` (tenant UUID `3efed8c4-6ba8-5656-bad6-105211c41151`) | Defined by the removed `backend/scripts/seed_synthetic_membership.py`. When run, it wrote a synthetic admin row and a Firebase-UID mapping to whichever configured database it targeted. Its user UUID depends on the supplied Firebase UID. It did not create a Firebase Auth account. The repository cannot establish whether this script was run against hosted development. |
| Firebase Auth account/UID previously described as the “dedicated synthetic Firebase user” | An old procedure asked an operator to create one, but this repository contains no corresponding actual Firebase email or UID. The seed script accepted a UID parameter; its value and whether an account exists are unknown here. |
| `synthetic@example.invalid` / UID `synthetic-user-uid` | `backend/tests/test_firebase_auth.py` fixture only: rows go into the per-test in-memory SQLite database, and token verification is monkeypatched. Not a Firebase Auth account or hosted membership. |
| `new-member@example.test` / UID `verified-new-user` | `backend/tests/test_organisation_members.py` fixture only: Firebase Admin account lookup is monkeypatched and membership rows use the test's in-memory SQLite database. Not a Firebase Auth account or hosted membership. |
| `unverified@example.test` / UID `unverified-user`; `employee@governance.test` / UID `linked-employee`; `admin@governance.test` / UID `alternate-admin-identity` | `backend/tests/test_organisation_members.py` fixtures only. Firebase Admin lookup is monkeypatched; identities/memberships exist only in the isolated API test database. |
| `test@example.invalid` / UID `test-uid`; `test-<provider>-<uid>` bearer tokens | `backend/tests/conftest.py` and `backend/tests/test_guest_groups.py` fixtures only. The app dependencies are overridden or Firebase token verification is monkeypatched; database state is isolated SQLite. |
| `account@example.test` / UID `account-uid`; `test-anonymous-uid`; `admin@example.test` / UID `admin-user`; `member@example.test` / `member-1` | Flutter `Fake`/test-double identities or mocked membership-provider data in widget tests, with FirebaseAuth/provider overrides. They never authenticate with Firebase. |
| Other `*.example.test`, `*.example.invalid`, and `*.governance.test` emails, including `registered@example.invalid` | Backend fixtures in per-test in-memory SQLite or mocked Firebase Admin lookup; not live Firebase users. Guest IDs such as `guest-owner`, `guest-outsider`, `guest-joiner`, `guest-other`, `guest-editor`, `transfer-host`, `transfer-viewer`, `registered-org-user`, `new-anonymous-user`, `invite-host`, and `invite-joiner` are fabricated token subjects in guest API tests with token verification monkeypatched. |
| Admin UI shortcut `AdminPage(adminOverride: true)` | Removed from production widget API. Admin widget tests now supply a mocked `ActiveMembership` provider; this tests rendering/controls only, not authentication or server authorization. |

The repository does not provide evidence of which Firebase users or rows
currently exist in the hosted project. No live account or database record was
deleted. Cleanup must be performed by the project owner/operator only after
inventorying Firebase Auth users and database mappings in the approved project:
match the exact synthetic email/display name, tenant slug/UUID, and associated
UID mapping; inspect all referencing rows/data and confirm the account is
disposable; export/audit as required; then remove only the confirmed synthetic
Auth user (if one exists) and its associated synthetic tenant/user/mapping data
through the reviewed retention/backup procedure. Do not delete by email alone,
remove an unknown UID, or delete real users or unrelated tenant data.

### Controlled organisation provisioning and membership

Organisation creation has no public API or self-service bootstrap. An operator
must use the private, authenticated runtime to provision a new organisation and
its first admin from an existing Firebase account with a verified email. Review
the target Firebase project, `APP_ENV`, database URL, organisation name/slug,
verified admin email, and operator identifier before running the command.
The transaction creates the organisation, active admin user, UID mapping, and
`ORGANISATION_ADMIN_PROVISIONED` audit event. It rejects an existing slug or an
account already mapped to an organisation. The operator value is recorded as
metadata and must identify the human performing the controlled action.

```sh
cd backend
python -m scripts.provision_organisation_admin \
  --name "<organisation name>" \
  --slug "<unique-lowercase-slug>" \
  --admin-email "<verified-firebase-account-email>" \
  --operator "<operator identifier>" \
  --confirm-operator-provisioning
```

This command is an operator tool, not an application endpoint. It has not been
run for any real organisation or account in this work. The old
`seed_synthetic_membership` helper has been removed; do not recreate its
synthetic admin shortcut or use it for live acceptance.

After provisioning, an organisation admin can use **Admin → Members** to add
an existing Firebase account by verified email, assign its organisation role
and primary department, or change those values for an active member. The API
resolves the email through Firebase Admin, refuses unverified accounts, checks
that target departments belong to the caller's organisation, and records
member, role, and department changes in `audit_events`. The last active admin
cannot be demoted. Role changes take effect on subsequent API requests because
the role is read from the database membership. This screen does not send email
invitations or create Firebase accounts; accounts must already exist and have
verified email. Department/team membership is not an organisation role, and
organisation admin does not bypass private owner-only content.

### Hosted browser-to-API acceptance matrix

| Check | Expected result |
| --- | --- |
| Create a fresh account through the app, verify its email, sign out, and sign in normally; before explicit provisioning load Knowledge/Interact local workspace | Firebase auth state is real; no membership or org access is assumed |
| Provision the verified test account through the authorized first-admin operator command or have an existing org admin add it in **Admin → Members** | `/api/v1/auth/me` reports the explicitly assigned org and role; admin UI is available only for an admin membership |
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

The local fake-token tests cover membership resolution, invalid claims,
expired tokens, inactive/unmapped users, forged development headers, tenant
scoping, role restriction, and App Check observation/enforcement. PostgreSQL 16
with pgvector accepted migrations 0001–0008 on a disposable local database; the
old synthetic seed completed twice idempotently there. This is historical local
database evidence only and does not establish hosted account/database state; the
seeder is removed. The backend suite reports 46
passed and one existing guided-proposal test failure. That same
`MissingGreenlet` failure reproduces on base commit `80dc87d` with the currently
resolved dependency versions, so it is not introduced by this change.

Flutter tests/analyzer/release build, actual hosted browser-to-API tests, and
service ADC verification require the Flutter SDK and private Codex runtime/site
key; they remain pending. Automated tests currently use fake Firebase users or
monkeypatched token verification and do not cover real sign-up/sign-in. Add a
separate Flutter integration/E2E suite using a disposable Firebase Auth
emulator (not currently configured in this repository) or an explicitly
provisioned disposable dev account, a real backend token-verification path, and
membership setup through the authorized operator or org-admin flow. It must
cover sign-up, verification, sign-out/sign-in, no-membership state, explicit
role assignment, admin UI visibility, and cleanup of only test-created data.
The Flutter package currently has no `integration_test` dependency or E2E
runner. Do not convert widget mocks into claims of real-auth coverage. Do not
enable App Check enforcement or deploy until hosted checks pass. No production
deployment, IAM change, credential retrieval, or cloud resource provisioning
was performed.

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
`0011_guest_groups` only through the reviewed development migration process.
Guest-group API tests use isolated synthetic token fixtures; live acceptance
must use a newly registered Firebase identity through the normal UI. This
implementation did not change Firebase settings, IAM, App Check mode, Cloud
SQL, or deployment state.

Group access expires after 90 days without an authorized request. A bounded
dry-run-first cleanup command is available at
`backend/app/maintenance/guest_retention.py`; it is not scheduled or enabled by
this implementation. See
[`guest-group-retention.md`](guest-group-retention.md) for backup, recovery,
permissions, and scheduler review requirements. Do not treat access expiry as
deletion or promise that exported copies can be revoked.

Backend guest-group tests use isolated SQLite and monkeypatched synthetic
verified-token fixtures. PostgreSQL migration SQL generation was checked
offline; no hosted migration or Firebase emulator/browser acceptance was
performed. Flutter analyzer, tests, and web build remain pending when the SDK
is unavailable.
