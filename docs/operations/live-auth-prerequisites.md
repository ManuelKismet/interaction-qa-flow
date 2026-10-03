# Live authentication preparation

Verified 2026-10-02 in bookish-happiness. Deployment deferred; no service-account keys, IAM grants, App Check debug registration, Firebase user creation, hosted seeding or hosted migrations were performed in this step.

## Completed

- gcloud active account is signed in.
- Application credentials: GOOGLE_APPLICATION_CREDENTIALS is unset, default ADC file absent, ADC token acquisition fails with credentials-not-found. gcloud login does not establish application ADC.
- API identity project roles read back only roles/cloudsql.client. The previously approved secret-specific accessor remains documented separately. Firebase revocation checking calls user lookup and needs Firebase Authentication read access.
- Saved App Check registration record is Enterprise, app 1:398672910103:web:e968506023d8eab9290952, token TTL 3600s, domains intqaflow-dev.firebaseapp.com and intqaflow-dev.web.app. Codespace preview and localhost are outside those domains.
- Synthetic Phase 6 two-participant nested fixture and role manifest prepared; fixture import/independent answers/nesting/JSON+CSV export passed one opt-in backend test in 1.96 seconds on 2962b2c.

## Application credentials

The user can complete ADC sign-in themselves in this Codespace terminal:

```sh
$HOME/.local/share/intqaflow/gcloud/google-cloud-sdk/bin/gcloud auth application-default login --no-launch-browser
```

Complete the Google flow and paste any returned verification code only into the Codespace prompt. Do not send codes or credential files in chat. Afterwards verify ADC token acquisition without printing the token; configure quota project intqaflow-dev if needed. This is local developer ADC, not proof that the future API service account works or is deployed. Do not commit credential files.

## Exact access proposal, not applied

Grant roles/firebaseauth.viewer on project intqaflow-dev to serviceAccount:intqaflow-dev-api@intqaflow-dev.iam.gserviceaccount.com. This predefined role includes firebaseauth.users.get plus read-only Firebase/project metadata access; it does not permit user creation/deletion or password-hash/config-secret access. Existing SQL/secret roles alone cannot support revocation lookups. A narrower custom role support lookup timed out, so custom-role eligibility is not verified and no custom role was created.

This is additional access beyond the previously approved SQL/secret permissions. Require explicit approval of this exact role and principal before applying it. Verify the binding and a live lookup after approval and suitable service-account credentials; do not disable revocation checking as a workaround.

## Exact local App Check proposal, not applied

Register one temporary debug credential named Codespace acceptance for Firebase web app 1:398672910103:web:e968506023d8eab9290952 in intqaflow-dev. Keep the credential in a private local file and use only in a local review build, never source control or release builds. Firebase recommends its debug provider for local web development rather than adding localhost to reCAPTCHA domains. This bypasses attestation for holders of the credential, while backend Firebase identity and tenant authorization still apply. Ask approval before registration; revoke the registration after acceptance. Do not weaken backend App Check enforcement or add wildcard domains.

A debug-provider exchange verifies development integration, not the real Enterprise browser attestation on the registered hosted domains. That remains a separate later acceptance case. Also verify Firebase Auth authorised domains and backend CORS for the exact private preview origin before starting browser tests; no domains/CORS were expanded in this step.

## Sources and next gates

- https://docs.cloud.google.com/docs/authentication/set-up-adc-local-dev-environment
- https://docs.cloud.google.com/iam/docs/roles-permissions/firebaseauth
- https://firebase.google.com/docs/app-check/flutter/debug-provider

Next: user ADC sign-in and exact access/debug approvals; reviewed source/migration setup; provision synthetic users and UID mapping; local live sign-in/App Check tests; Phase 6 manual cases. Canonical privacy correction remains with Copilot.
