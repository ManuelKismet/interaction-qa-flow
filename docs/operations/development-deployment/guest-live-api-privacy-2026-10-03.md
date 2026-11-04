# Guest API privacy acceptance — 3 October 2026

Executed PR11 head 153acd2eea20c7abce2499c515994368c26d308c from Codespace with the existing release Python venv. Used the actual ASGI application in process, real Firebase Anonymous ID tokens and Firebase Admin token verification with revocation checks. Database was hosted Cloud SQL PostgreSQL intqaflow_dev through the existing loopback Auth Proxy, using the restricted runtime database account. This is not an acceptance result for a deployed guest backend or browser UI.

26 recorded checks passed, including infrastructure and cleanup assertions:
- Three distinct real anonymous Firebase identities.
- Current database intqaflow_dev.
- Missing token rejected (401).
- Owner group creation and outsider group listing exclusion.
- Outsider group read rejected (404).
- Forged x-user-id rejected (400).
- Invitation creation, pending join, pending member entry denial, owner approval.
- Approved member Knowledge creation and export.
- Outsider entry read/history/export/write rejected (404).
- Interact sharing without explicit consent rejected (422).
- Owner membership removal; removed member read/export rejected (404).
- Outer hosted-database transaction rolled back.

The sole dependency override bound database sessions to a real PostgreSQL outer transaction with savepoints. Service commits were contained within that transaction; no authentication or authorization override was used. Synthetic database data was rolled back. Real anonymous Firebase test identities remain in DEV; no token or credentials were logged or committed.

Recovered the absent loopback proxy by locating the existing proxy and gcloud binaries. Configured the existing gcloud credential with DEV quota project for Firebase Admin verification. Earlier attempts stopped before group creation due to missing proxy, absent ADC or missing quota project; those are harness setup issues, not guest privacy failures. App Check stayed in existing observation mode; enforcement is not validated by this run.

Local sanitized results: /home/vscode/.local/share/intqaflow/guest-live-privacy-153acd2-results.json. Private reproduction runner: guest-live-privacy-run.sh in the same directory; reads credentials from existing private configs, not repository files.

Remaining acceptance: actual browser guest-to-account linking, cross-device identity transitions, local cache/data retention and isolation, organisation/private account boundaries, and rendered print/PDF pagination. Guest/report changes remain unmerged and undeployed. Copilot has since pushed 130648e2295a14adfe8347908009b901e9001ed8; this document does not claim validation of that new commit.
