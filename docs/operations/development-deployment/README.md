# Development deployment checkpoint

Development deployment was authorized on 2026-10-02; production deployment and merging are not authorized. Candidate source: ca93a14856dddbd0176f71b3e75c96b1e54d9389. Independent Codespace verification passed 60 checks (54 backend tests and six independent acceptance probes) with fake embeddings, SQLite and mocked Firebase verification. Canonical privacy regression now passes. Live auth, App Check and Phase 6 browser acceptance remain pending.

Prepared: non-root Python container, secret-excluding Docker context, explicit development runtime settings, exact Firebase Hosting CORS origins and SPA hosting configuration. DATABASE_URL must come from the existing Secret Manager secret; Cloud Run uses the approved API service identity and Cloud SQL attachment. Planned runtime: min instances 0, max instances 1, request-based CPU billing, 512MiB memory, fake embeddings. Budget alerts are not a hard spending cap.

Additional required permission, not applied: roles/firebaseauth.viewer on intqaflow-dev for intqaflow-dev-api@intqaflow-dev.iam.gserviceaccount.com. This permits Firebase user metadata reads needed for revoked/disabled-account checks. Automatic approval review rejected that new grant because exact user approval is required. Existing Cloud SQL Client and secret-scoped accessor grants remain in place. No keys are needed.

No deployment or hosted migration has been executed at this checkpoint.
