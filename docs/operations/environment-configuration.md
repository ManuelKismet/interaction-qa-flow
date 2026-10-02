# IntQAFlow development environment configuration

Updated 2026-10-02. Founder requested environment/configuration work only;
deployment and the phase review are deferred. Retain the old local database
until the hosted application passes end-to-end checks.

## Verified settings

| Setting | Development value / status |
| --- | --- |
| Cloud / Firebase project | intqaflow-dev |
| Project number | 398672910103 |
| SQL connection | intqaflow-dev:europe-west2:intqaflow-dev-pg |
| Application database | intqaflow_dev, schema revision 0007 |
| Vector extension | pgvector 0.8.5 |
| Runtime database login | intqaflow_runtime, schema creation denied |
| Connection secret | intqaflow-dev-database-url |
| Firebase web app | 1:398672910103:web:e968506023d8eab9290952 |
| Auth domain | intqaflow-dev.firebaseapp.com |
| Email/password | Enabled, password required |
| Phone / anonymous auth | Disabled |
| Authorized auth domains | intqaflow-dev.firebaseapp.com, intqaflow-dev.web.app |
| Embeddings | Fake provider for isolated development |
| Monthly allowance | GBP 25 alerts; not an enforced spending cap |

Official Firebase web configuration retrieved and saved at
$HOME/.local/share/intqaflow/firebase-dev-web-config.json with mode 0600.
No API key values, passwords, tokens or credential files are committed.
Current App Check provider readback returned HTTP 403; registration and
enforcement are not verified. Diagnose API enablement/permissions before
registration. No attestation provider or debug token has been created.

## Approved development service identity

Created and independently verified development-only service account:
intqaflow-dev-api@intqaflow-dev.iam.gserviceaccount.com

| Grant | Resource | Purpose |
| --- | --- | --- |
| roles/cloudsql.client | Project intqaflow-dev | Allow the future API identity to use the authenticated Cloud SQL connector |
| roles/secretmanager.secretAccessor | Secret intqaflow-dev-database-url only | Read the restricted runtime database connection |

This identity can connect to the dev database and obtain its runtime credential.
It receives no Owner/Editor role, no project-wide secret access, no Firebase
user-administration role and no downloadable service-account key.
The founder explicitly approved this account and the exact two grants on
2026-10-02. Creation and both bindings succeeded. Independent IAM policy
readback confirms this account has only roles/cloudsql.client at project
scope and roles/secretmanager.secretAccessor on the named database secret.
The account is enabled and has zero user-managed keys.
It is not attached to a deployed application.

## Application configuration boundary

Copilot is assigned issue #3; draft PR #4 targets the isolation branch.
Firebase user token verification, membership mapping, Flutter sign-in and
App Check handling remain application work. Final variable names and client
build configuration must be checked against the completed Copilot PR.
Backend project identity must be intqaflow-dev and allowed App Check app ID
must be the registered development web app. Configure explicit development
CORS origins; no wildcard and no production configuration.
App Check enforcement awaits a configured client and valid-traffic checks.

Environment configuration acceptance still pending: App Check API/provider
registration and final configuration mapping to reviewed application code.
The approved service identity and its exact grants are verified.
No deployment performed.
