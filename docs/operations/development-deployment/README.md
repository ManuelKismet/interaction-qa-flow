# Development deployment checkpoint

## Current development checkpoint — unified Ask/search, 2026-10-07

Exact independently reviewed source `f662a6cff70526f287fb521bea25ec24860d8f4a`
on `fix/unified-search-dev-20261006` is deployed to intqaflow-dev only.

- Backend `intqaflow-dev-api-reviewf662a6c`,100% traffic; staged at zero traffic
  with preserved runtime identity/Cloud SQL/VPC/security, health/readiness200
  before and after switch. Backend unchanged from105a528; reused immutable
  reviewed image digest31d1eb5487847352ff25e9b10de2711e8afca3a1f30d758f26cf28adee61be34.
- Cloud SQL schema0014 already present; read-only existing-data/runtime
  privileges/extensions/trigram indexes verified, no hosted migration/grants.
- Hosting release1791360928018000/version3e8209ddae71b73b,36 files.
  Both Hosting origins match exact tested index/bootstrap/main bytes.
- Independent backend111PASS4SKIP; fresh PostgreSQL4PASS and isolated migration
  round-tripPASS; Flutter180PASS; analyzer0errors/0warnings13existing infos;
  configured web release buildPASS.
- Main JS4508459 bytes/SHA256
  `68e41529159ff413ed29eed8ccd1b5bf872ec4674320acde618a84c7c7a54a34`.
- Ask suggestions now share unified retrieval/source handling with Knowledge
  search. Automated source/scope/stale-response/partial-failure/navigation and
  manual-only submission regressions pass. Browser-local content never
  automatically uploads; Private content stays owner-scoped.
- Live guest answer-only search, Local badge, and navigation to exact original
  Saved Q&A verified after frontend reload; existing local data retained.
- Rollback:backendreview105a528 and Hosting4eb839685c6f21c7
  (release1791323636722000). Retain additive schema0014/private data.
- Remaining: real semantic-provider quality in fake-provider DEV; hosted
  registered Ask/search source/scope acceptance; authenticated personal-import/
  edit/multi-device E2E/F04/F08/F09. Non-mutating format check7of7changed Dart
  files would change; advisory outstanding, no Codex application/test edits.
- Copilot PR20 incremental mailbox applied unchanged, source pushed/readback;
  old stalled PR13 output remains quarantined. No production or merge.
  Temporary PostgreSQL/proxy stopped; Codespace stopped, files/four dirty docs
  preserved. Organisation improvements authorised2026-10-07; active Copilot task
  8a480ce0-4a41-465c-9b0e-a453ab56de03, no organisation rollout yet.
  Real semantic-provider activation deferred until first customer;
  monitoring already cancelled.
- Detailed evidence:
  [unified-search checkpoint](unified-knowledge-search-checkpoint-2026-10-06.md).

This snapshot supersedes historical current-state and rollback entries below.

## Historical personal-workspace checkpoint — 2026-10-06

The personal account workspace change is implemented and deployed to development.
Reviewed source: `aafc112fbbf220eda1077895334dc16b4930eeab` on
`fix/saved-qa-dev-20261006`. This snapshot supersedes older current-state
statements below; dated entries remain historical evidence.

| Component | Verified development state |
|---|---|
| Frontend | [web.app](https://intqaflow-dev.web.app/) and [firebaseapp.com](https://intqaflow-dev.firebaseapp.com/) serve the same app |
| Authentication | Firebase Authentication; guests use browser-local content without an anonymous account |
| API | [Cloud Run API](https://intqaflow-dev-api-bycdjb22qq-nw.a.run.app), service `intqaflow-dev-api`, London |
| Database | PostgreSQL in Google Cloud SQL, instance `intqaflow-dev-pg`, project `intqaflow-dev`, region `europe-west2`; not a Firebase database |
| Backend release | `intqaflow-dev-api-reviewaafc112`, 100% traffic |
| Database schema | `0013`; additive `personal_workspace_items` table |
| Hosting release | `1791307395456000`, version `49afc5b14f53f3b0`, 36 files |

The browser calls the separate API; the API connects to PostgreSQL. Guests'
Knowledge and Interact content stays in their browser. Registration creates a
separate real account and never uploads local content automatically. Verified
registered users can explicitly import selected items to their private account
while retaining local originals. New local work stays local until selected for
import. Personal content and Groups require no organisation membership; personal
content is excluded from organisation/group/global and semantic indexes.

### Independent verification and limits

- Backend: **106 passed**, no skips, including an actual isolated PostgreSQL
  concurrent import regression and migration cycle. Most API tests use SQLite;
  the suite is not entirely PostgreSQL-backed.
- Flutter: **164 passed** on `3efc327`. After the behavior-preserving warning
  cleanup, the final source passed **35 focused account tests**, analysis with
  **zero errors/warnings** (13 existing informational notices), and a release
  web build.
- Live development: API health/readiness returned 200; missing/invalid personal
  API identity returned 401. Migration `0012 → 0013` preserved all six groups,
  and runtime CRUD privileges were verified without additional grants.
- Both Hosting origins matched the release bundle: 4,480,260 bytes,
  SHA-256 `687215d3c46ab8e77bd1b8ef8a4d5d8019756659ced1804259f0e679aa9acb6a`.
  Guest browser reload retained Knowledge/Interact content and confirmed storage
  labels, navigation placement and the registered/verified Groups gate.
- **Live authenticated personal import/edit/multi-device browser acceptance
  remains outstanding.** Automated tests, health checks and bundle matching do
  not establish that result. Do not close F04/F08/F09 solely from this rollout.

### Resume and rollback

Next acceptance step: use an authorised ordinary verified registered account to
check selected import, local-original retention, account editing/deletion,
sign-out/account switching and retrieval on another browser/device. Record
actual results against the deployed source before closing related acceptance
items. Keep production, data purges and security weakening outside this scope.

Rollback backend traffic to `intqaflow-dev-api-reviewfc9f5cc` and Hosting to
release `1791296037202000` (version `62ab4165c63e4fc3`) if needed.
Retain schema 0013 and personal data; do not downgrade or purge the live database.
The temporary database proxy was terminated and the Codespace stopped after
source/docs were pushed; pre-existing dirty documentation was preserved.

Copilot owns application/test changes; Codex owns configuration, documentation,
independent review/validation and the authorised development rollout. Continue
routine work within the user's existing authorisation without repeat permission
prompts. See [workflow lessons](personal-workspace-workflow-lessons-2026-10-06.md)
for the implementation and verification sequence.

Detailed evidence: [user/admin acceptance log](user-admin-e2e-checkpoint-2026-10-04.md),
[acceptance index](user-flow-acceptance-index.md), and
[feature backlog](feature-implementation-backlog.md).

## Historical continuation status — 2026-10-03

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


Historical 2026-10-04 development acceptance: backend review80b0c61 passed 84 tests including fresh PostgreSQL16 lexical integration and now serves 100 percent of development traffic; health200 and hosted short-query search passed. Frontend remains b3d6491 pending admin dropdown/test and Reopen request fixes. Admin governance approval, answer verification, periodic review, recoverable archive/restore, and denial of employee private session passed. See user-admin-e2e-checkpoint-2026-10-04.md for evidence and remaining department/team/employee assignment acceptance. Production and old local database are excluded.
