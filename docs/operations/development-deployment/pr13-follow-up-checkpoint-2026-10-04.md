# PR13 follow-up checkpoint — 2026-10-04

This is a source and test update for the existing draft PR, not acceptance of a
development deployment. No production configuration, organisation membership,
test accounts, or persisted data were changed.

## Addressed in this follow-up

- Corrected the malformed widget-tree closures reported in
  `guest_workspace_page.dart` and `guided_page.dart`.
- Renamed the guest-link action to **Create account from this guest**. On
  successful linking the app requests email verification when needed, refreshes
  the Firebase user, reports the result, and returns to the guest workspace.
  Verification-send and refresh failures are reported separately. Cancelling
  separate-account creation now explains that guest identity, group access, and
  local work are unchanged.
- Kept local work explicitly device-local; account linking does not upload it
  or create organisation membership.
- Made registered-account guest-group lookup failures visible and retryable
  without interpreting a failed lookup as “no groups.” Error text is sanitized.
  The shared-groups page also no longer shows its empty-state message while the
  group lookup is failing.
  The client requests `/api/v1/guest/groups` with Firebase ID-token and App
  Check headers. The separately mounted API route validates those claims and
  lists groups by Firebase UID; this route does not require organisation
  membership. These source contracts do not establish why an unidentified
  development server returned an error.
- Added client/repository coverage for the guest-group route, token headers,
  sanitized authorization errors, and retryable lookup failures.
- Added a template-created all-participant report assertion for distinct answer
  owners, nested content, and print pagination rules. Clarified that direct
  download attempts to save a PDF file while browser print opens a separate
  report for the browser’s **Print → Save as PDF** flow. The web download anchor
  is now attached to the document while clicked, and the UI reports that a
  download was requested rather than claiming it completed.

## Verification status

The independent report for the exact prior head `0079511d244a1a8648e61f2cee4b1529ac89a9fb`
recorded 82 backend tests passing, 59 Flutter tests passing with five test files
failing to load, 21 analyzer issues, and a failed release web build due to the
reported syntax blockers. Those results apply only to that prior head.

In this coding environment, Flutter and Dart are unavailable. The added Flutter
tests, analyzer, and release web build have therefore not been run against this
follow-up. `git diff --check` is a source whitespace check, not a compilation or
runtime result. Backend code was not changed here; prior backend test results
are not a live-auth or guest-group acceptance test.

## Still blocked on independent environment checks

- Re-run backend and Flutter tests, analyzer, and release web build on the new
  PR head.
- Verify live guest-group listing, invitation, membership, conflict, and privacy
  behavior on the intended development build. The served source SHA was not
  identified, so the reported group request failure cannot be assigned to this
  PR source.
- Verify real email delivery with the founder’s real-account flow.
- Verify browser download behavior, rendered print-to-PDF pagination, full
  nested report output, and the guest backup/import menu on the served build.
  Source-level report and backup tests do not establish browser behavior.
- Complete the existing PR9 wide-screen outline/narrow-screen branch navigation
  and pending-edit-flush gaps separately; this follow-up does not claim them
  fixed.

## Account/workspace follow-up — 2026-10-05

The guest path presents account creation from this guest first. It links the
credential to the current Firebase UID, retaining that identity's group
memberships/admin roles; local drafts remain local and no organisation
membership is created. “Start fresh with a separate account” is an explicit
alternative; no dedicated account-switch or guest-profile feature is added.
The intended model is one guest workspace per normal device/browser. Existing-
account sign-in remains a normal sign-in action and is not blocked by an empty
anonymous bootstrap identity. Meaningful local work or group access gets a
concise warning. It explains that local work remains in this browser unless the
user explicitly clears only the local copy under Workspace options.
Sign-in/account creation never clears local drafts or group data. Registered
accounts without an organisation are labelled as a registered workspace; group
and organisation roles remain separate.

Before sign-in or start-fresh from a guest identity, the client checks current
group membership and active administrator counts. It blocks the action if the
current identity is the sole active administrator or if group ownership cannot
be verified. Administration transfer is now a seven-day proposal to an active
member. The requester remains admin until that recipient accepts; acceptance
atomically makes the recipient admin and requester contributor. Decline,
cancellation, or expiry leaves roles unchanged.

An active admin can archive a group. Members/content/revisions are retained,
outstanding invitations are revoked, and all active group operations are denied.
Only the same recorded archiver Firebase UID while still an active admin can
restore it for 30 days. A separate account does not inherit recovery. Restore
does not revive invitations or activate pending/removed members. After 30 days
data remains stored pending a separately reviewed retention decision; archived
groups are excluded from expiry cleanup and are not silently purged. The UI
discloses member impact and recovery scope before archive and account departure.

### Observed retention behavior

- Web solo drafts use origin-scoped `localStorage` key
  `intqaflow.guest.workspace.v1`; the app does not apply expiry or automatically
  clear local drafts on sign-in/account creation. Browser storage policies can
  evict data; the user can also clear it in the UI or remove browser/site data.
  Same-origin tabs share
  local storage and Firebase auth context; tabs are not isolated profiles.
- The non-web storage implementation is in-memory only. Firebase identity
  persistence is left to the Firebase SDK; this app configures no identity
  expiry, and hosted/device persistence behavior has not been independently
  verified. Firebase anonymous-account cleanup/project retention configuration
  is also unverified.
- The backend stores explicitly shared group records, not private solo drafts.
  Group access expires after 90 days without an authorized request, which denies
  access but does not itself delete rows. Cleanup is a bounded dry run by
  default; deletion requires a separate reviewed manual `--apply` run. The
  repository configures no scheduler; hosted scheduler state is unverified.
- Invitations expire after their configured lifetime (24 hours by default,
  API range one hour to seven days); expiry/revocation prevents redemption but
  does not itself mean the row was deleted.
- Backend draft storage is not part of this UX work. Any such proposal needs an
  explicit identity model, access controls, expiry, and cleanup design.

### Browser-profile notice and product surfaces

The workspace notice now states that a guest sign-in is active in this browser
profile and that people using the same profile share its sign-in and local
drafts. It separately identifies Shared groups as online content only when
deliberately shared; group membership is not the same as the local browser
workspace/session. The wording for a registered local workspace likewise
explains same-profile draft visibility without applying guest labels.

The founder-approved product direction is end-user delivery through browser
extensions and application plugins such as Microsoft Teams, with the web
interface serving administration and capabilities unsupported by those clients.
The standalone web interface remains supported. The architecture document
continues to mark Teams and browser-extension implementation as deferred; this
UX follow-up does not change phase status or build client integrations. Keep
identity/session copy portable to those surfaces by referring to the active
client/profile rather than assuming separate accounts or sessions per tab.

Sign-in now snapshots the trimmed email and password at submission before any
confirmation dialog, then uses the captured values. Optional
`AUTH_DIAGNOSTICS=true` output includes only the sanitized Firebase error code,
Firebase app name, and project ID; passwords, tokens, and email addresses are
not logged. This source change cannot establish whether the hosted
`auth/invalid-credential` response was caused by a mistyped/incorrect password,
autofill behavior, or another remote credential condition. No password was read
or reset, no hosted credential retry was performed, and the submitted account's
password correctness remains unknown.

Focused widget coverage was added for empty-anonymous sign-in, meaningful-work
warnings, form-value capture across confirmation, same-UID default linking,
explicit start-fresh disclosure, sole-admin blocking, unavailable-ownership
fail-closed behavior, and registered-workspace labels. Existing linking
coverage asserts that the same Firebase user/UID remains active. These Flutter
tests, analyzer, and web build have not been run here because Flutter/Dart are
unavailable. Backend behavior and authorization were not changed. The exact
pre-clarification head `2f4186c` backend-validation run was `action_required`
with zero jobs/logs; it did not execute.

### Development-only authentication diagnostics — 2026-10-06

This source follow-up adds opt-in diagnostics for existing-account sign-in. They
record credential-presence booleans, guest confirmation outcome, Firebase SDK
call outcome, auth-state category, and subsequent account-state/membership lookup
outcomes. Each structured event has a random ephemeral attempt ID, UTC stage
timestamp, elapsed milliseconds, Firebase app/project identity, and optional
`APP_BUILD_ID`. Firebase exception codes map to a finite allowlist; unknown
values become `other`. Email/password values and lengths, credential hashes,
tokens, UIDs, raw exceptions, request/response bodies, and headers are never
included. Attempts are in-memory only, expire after two minutes, and clear after
failure or completion of account/membership lookup. The Firebase UID is compared
transiently in memory to correlate the SDK result with the auth-state event;
mismatches discard the attempt before account lookups are recorded, and the UID
is never serialized or persisted.

Diagnostics are disabled by default and require all three gates: debug build,
explicit `AUTH_DIAGNOSTICS=true`, and `FIREBASE_PROJECT_ID=intqaflow-dev`.
Release builds and other Firebase projects cannot enable them with the flag.
Events go only to debug console output; the app does not persist or transmit
them. Authentication behavior, App Check, email-enumeration protection, and
authorization remain unchanged.
For a controlled local DEV run, supply
`--dart-define=AUTH_DIAGNOSTICS=true`,
`--dart-define=FIREBASE_PROJECT_ID=intqaflow-dev`, and an opaque
`--dart-define=APP_BUILD_ID=dev-auth-review` to `flutter run`; do not pass
credentials as command-line arguments.

Founder-provided DEV server evidence (not independently reproduced here):
Identity Platform end-user activity request logging was temporarily enabled
after explicit approval. One secure browser sign-in produced
`auth/invalid-credential`; its matching Cloud Logging event reported
`SignInWithPassword`, status code 3, and safe code
`INVALID_LOGIN_CREDENTIALS`. Logging was promptly disabled and read back as
false. The event remains subject to existing log retention. This confirms an
actual Firebase rejection rather than only stale UI/backend membership state;
it does not prove that submitted and expected credentials matched or establish
the rejection's cause. No credential values or request bodies were read, and no
reset, retry, account recreation, deployment, or isolated SDK reproduction was
performed.

Added focused tests:

- `account_state_widget_test.dart` — `opt-in diagnostics follow captured
  credentials through confirmation`, exercising controller snapshot, async
  guest confirmation, exact Firebase arguments, and absence of submitted values
  and exception text in emitted diagnostics.
- `auth_diagnostics_test.dart` — `diagnostics require explicit opt-in to a
  debug development build`, `disabled diagnostics emit no events`, `only one
  diagnostic sign-in attempt can be active at a time`, `diagnostics never start
  for a non-development Firebase project`, `diagnostic lifecycle contains only
  allowlisted fields and values`, `auth and membership providers emit the staged
  lookup lifecycle`, `a different UID transition clears the attempt before
  lookups`, `unknown Firebase exception codes collapse to other`, and `unknown
  exception content is not emitted`.

Flutter tests, analyzer, and web build were not run here because Flutter/Dart
are unavailable. The canonical PR15 acceptance index and checkpoint are not
present in this clone; this PR13 checkpoint records the source scope and the
supplied DEV evidence without asserting hosted acceptance.

### Diagnostics review follow-up — 2026-10-06

The review hold identified two callback-ordering defects and a sign-in behavior
coupling. Account and membership instrumentation now captures a request-scoped
handle and the auth UID at request start. Provider disposal, attempt completion,
or an identity mismatch invalidates that handle; a late completion cannot emit
against or clear a later attempt. Auth-state and lookup stages are buffered
until the SDK result UID matches the observed Firebase UID, so either event
ordering is supported without logging events for an unverified identity.
Diagnostics no longer reject sign-in while another diagnostic attempt is
active; the page's existing per-submit `_busy` guard remains the only duplicate
submission guard. The Firebase options project ID nullability check was also
aligned with the SDK's non-null API.

Added coverage for async stale lookup completion, provider-scheduled account
and membership lookups with auth-state-before-SDK and SDK-before-auth ordering,
and equivalent sign-in behavior with enabled versus disabled diagnostics.
Flutter tests and analyzer were not run in this environment because Flutter/Dart
are unavailable. No hosted rollout, credentials, account, or Firebase settings
were changed; development rollout remains on hold pending independent review and
runtime validation.

### Handoff and lessons

- Keep normal sign-in separate from guest account linking and explicit start
  fresh; evaluate current guest data/group-admin responsibilities, not a
  signed-in account's history.
- Linking is the continuity path. A separate account is not a data-transfer
  path, and local browser work remains on the device.
- Never use an `invalid-credential` observation as evidence of a bad password or
  a product defect without a safe, controlled reproduction. Keep diagnostics
  sanitized and avoid credential resets/retries.
- The requested
  `docs/operations/development-deployment/user-flow-acceptance-index.md` and
  PR15 checkpoint were not present in this clone. The available PR13 checkpoint
  above is updated instead; do not infer prior acceptance from this source-only
  change. Historical hosted account evidence remains limited to the statuses
  recorded in the supplied handoff.
