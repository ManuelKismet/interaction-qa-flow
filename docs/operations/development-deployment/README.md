# Development deployment checkpoint

## Current continuation status — 2026-10-03

Start with [the current continuation checkpoint](continuation-checkpoint-2026-10-03.md). PR13 candidate `abb224fee28355a671b9cd8828c090bdb86353b1` independently passed 82 backend tests, all 79 Flutter tests, dependency resolution/pip check and the release JavaScript web build. Analysis has zero errors/warnings and twelve informational style notices (exit 1); the checkpoint lists every notice. Both previously failing UI tests now pass.

The three synthetic registered identities and twenty disposable anonymous identities, plus their specifically reviewed hosted throwaway data, were deleted and verified. Do not recreate these old seeded identities. Live acceptance starts with ordinary fresh UI registration/email verification/sign-in, newly created content and explicitly authorized backend admin provisioning where needed. Anonymous sign-in remains enabled; automatic Auth cleanup was observed OFF.

Current verification made no deployment or merge. The current candidate has not completed hosted real-auth, group/privacy/account-switch or rendered-PDF/download/share acceptance. These and broader consolidated-handoff gaps remain in the continuation checkpoint. Codex owns environment/independent checks; Copilot owns code/tests. The founder authorizes verification after new commits without repeat confirmation; recurring failures return to the founder for discussion.

## Historical initial deployment record — 2026-10-02

The following is historical evidence, not current account state or instructions to recreate synthetic users. Use the continuation checkpoint for current testing and cleanup status.

Development deployment was authorized on 2026-10-02; production deployment and merging are not authorized. Candidate source: ca93a14856dddbd0176f71b3e75c96b1e54d9389. Independent Codespace verification passed 60 checks (54 backend tests and six independent acceptance probes) with fake embeddings, SQLite and mocked Firebase verification. Canonical privacy regression now passes. Live auth, App Check and Phase 6 browser acceptance remain pending.

Prepared: non-root Python container, secret-excluding Docker context, explicit development runtime settings, exact Firebase Hosting CORS origins and SPA hosting configuration. DATABASE_URL must come from the existing Secret Manager secret; Cloud Run uses the approved API service identity and Cloud SQL attachment. Planned runtime: min instances 0, max instances 1, request-based CPU billing, 512MiB memory, fake embeddings. Budget alerts are not a hard spending cap.

Additional permission approved by the user, applied and independently verified: roles/firebaseauth.viewer on intqaflow-dev for intqaflow-dev-api@intqaflow-dev.iam.gserviceaccount.com. This permits Firebase user metadata reads needed for revoked/disabled-account checks. The initial automatic review rejection was resolved by explicit user approval. Existing Cloud SQL Client and secret-scoped accessor grants remain in place. No keys are needed.

Hosted migration 0008 has succeeded. Runtime SELECT permission on firebase_uid_mappings is verified. Cloud Run revision intqaflow-dev-api-00001-w2m is Ready and serving all traffic with the configured identity, SQL attachment and secret. API URL: https://intqaflow-dev-api-bycdjb22qq-nw.a.run.app.

Latest Flutter dependency resolution and analysis pass, all 20 tests pass, and the configured release JavaScript build succeeds. A synthetic Firebase account and server-managed tenant membership were created; passwords remain in a private 0600 Codespace file. Live Firebase password sign-in succeeds. /api/v1/auth/me returns 200 for its verified ID token, 401 for missing/invalid identity, and 403 for a foreign organisation ID. Hosting-origin CORS preflight passes. App Check remains observation; no live Enterprise attestation has yet been proven. Firebase Hosting release sites/intqaflow-dev/releases/1790973271382000 published 35 files from version 544339e0bb49fb9b. The deployed https://intqaflow-dev.web.app/ was opened in the cloud browser and displays the IntQAFlow sign-in screen. Browser sign-in, real App Check token verification and Phase 6 manual acceptance remain pending.

