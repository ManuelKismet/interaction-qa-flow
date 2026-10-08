# Personal workspace workflow lessons — 2026-10-06

## Outcome and evidence boundary

Reviewed source `aafc112fbbf220eda1077895334dc16b4930eeab` is deployed
to development. The [current checkpoint](README.md) records tests, runtime,
Hosting releases, schema and rollback. Live authenticated personal
import/edit/multi-device acceptance remains outstanding. This document records
lessons from implementation and independent validation, not closure of that gap.

## Product and data model

- Establish identity and storage rules before implementation. Browser-only guest
  work needs no anonymous UID. Registration creates a separate account;
  verified personal accounts and Groups do not require an organisation.
- Make transfer explicit: selected import only, no automatic upload on
  registration/sign-in, and no automatic removal of local originals.
- Label actual storage origin and confirmation state. A signed-in user can still
  have local work. Removing an account copy can reveal its retained Local source.
  Search naming must reflect both loaded origins without moving its placement.
- Keep personal data private and outside shared/semantic indexes. Bind requests
  and response generations to the expected UID; clear private UI on identity
  transitions. Preserve retry, revision/conflict and delete guards.

## Code handoff and review

Copilot owns application and test code; Codex owns configuration, docs,
independent validation and authorised development deployment. Apply unchanged
Copilot patches against the exact reviewed parent and record both authored and
applied commits. Do not mix intermediate trees or regenerate an entire patch
chain after patches have been applied.

Consolidate failures into one durable handoff with the exact base, file paths,
error output and required behavior. Steering sent near the end of an active
Copilot task was missed; confirm task status, published commit and actual patch
contents before claiming a fix is ready. Avoid competing tasks and repeated
round trips. Confirm available Flutter/Python tooling early and distinguish
static inspection from tests actually executed.

## Validation lessons

1. Run compilation/analyzer checks before a long suite. Simple missing fields,
   unbound context and a function used as a string caused avoidable full runs.
2. Validate the API/Flutter payload contract on import and update, including root
   title/body/answer fields, session titles and nested participant/question/answer
   branches. Validate the whole batch before mutation, preserve meaningful
   unknown fields and content spacing, and enforce stable IDs strictly.
3. SQLite API tests do not prove PostgreSQL locking or migration behavior. Use
   an isolated PostgreSQL integration test for concurrent reverse-order imports
   and migration cycles. Keep fixtures consistent with required schema fields;
   never run destructive regression cycles against the hosted database.
4. UI tests must follow the actual Saved Q&A route, scroll the active vertical
   list and account for lazy construction. Settle, center and hit-test taps;
   advance the fake clock beyond the existing 250 ms save debounce. The first
   Scrollable was a horizontal TabBarView and produced misleading failures.
   Retain selection, retry, local retention and no-auto-upload assertions.
5. Record complete exit codes and pass counts. Codespace extension activation
   interrupted foreground checks; detached runners with private logs and result
   files made completion verifiable. Do not infer a pass from partial output.
6. Run the full relevant suites once behavior is stable. After a purely
   behavior-preserving warning cleanup, focused account tests, zero
   analyzer errors/warnings and a successful release build were sufficient;
   record which source ran the full suite and which ran the focused checks.
   Existing informational notices remain separate from warnings.

## Development rollout sequence

1. Record exact source and patch provenance; independently validate backend,
   isolated PostgreSQL migration/concurrency, Flutter behavior, analysis and build.
2. Push and verify the exact source SHA. Build the backend and stage at zero
   traffic; compare service identity, SQL/VPC attachment and runtime configuration.
3. Apply only the authorised additive development migration. Check runtime CRUD
   privileges and existing data counts; do not grant privileges already present.
4. Confirm health/readiness before switching traffic and publishing the frontend.
5. Match release bundle hashes on both Hosting origins. Check unauthenticated
   private API rejection and guest retention/navigation in the live browser.
6. Record the remaining authenticated acceptance gap explicitly. Health, bundle
   hashes and automated tests are different evidence from signed-in browser flows.
7. Save current checkpoint, rollback releases and cleanup state. Terminate
   temporary proxies, stop unused Codespaces and preserve existing dirty files.
   Rollback traffic/Hosting while retaining the additive schema and personal data.

Routine review, corrections and development rollout continue within the user's
existing authorisation. Production changes, destructive data changes and security
weakening are outside this completed scope. Do not reset existing work or replace
historical checkpoint evidence with an unqualified current-state claim.

## Checkpoint contents for future resumptions

Record source branch/SHA, patch provenance, tests and their source commits,
unresolved acceptance items, API revision/traffic, Hosting release/version/hash,
database schema/migration outcome, rollback targets and cleanup state. Put a
readable current snapshot before the dated history so the next session does not
resume an obsolete pending state.

## Copilot Flutter environment and two-stage validation — 2026-10-08

Founder authorised installing Flutter for Copilot while retaining independent
Codex validation. Copilot must implement AND execute compilation/analyzer,
official formatting and affected tests before delivery; Codex independently
reviews the exact delivered source and runs acceptance gates. Tool availability
does not establish acceptance, and Copilot's green checks do not replace the
independent gate.

Automatic setup lives on default branch main in
`.github/workflows/copilot-setup-steps.yml`, tooling-only commit
`f6b1c9e7b0841fa6182d2dcf278e701498712026` (corrected setup). It uses official Flutter tag
3.41.4, verifies revision ff37bef603469fb030f2b72995ab929ccfc227f0 and
Dart3.11.1, prepares web tooling and enforces the existing pubspec lockfile.
The checkout action is SHA-pinned and does not persist credentials; workflow
permissions are contents:read. No application merge, runtime deployment or
credential/firewall changes are included.

Every Flutter invocation uses CI=true and --suppress-analytics to avoid the
cloud metadata detector and analytics. Setup exports CI and the SDK PATH for
later steps. Do not access metadata endpoints or credentials. A live session
that started before this workflow landed must explicitly install the same
official pinned SDK and prepare dependencies at its own app checkout; a new
session receives automatic setup. Re-run locked pubget if the agent checks out
a different app baseline.

Verify the session logs show `COPILOT_FLUTTER_SETUP_READY` and actual
Flutter/Dart versions. GitHub can start the agent even if setup fails: report
that blocker and never claim unavailable checks passed. Do not bypass network
restrictions or expand access to repair installation. Setup YAML/job structure
and embedded Bash syntax were locally validated; hosted installation success
must be recorded separately after the setup run finishes.

Copilot validation sequence: verify exact baseline and SDK, format touched Dart
files, analyze with zero errors/warnings (record existing infos separately),
run focused meaningful tests, fix regressions and rerun affected checks, then
run coherent full suites/configured release when behavior stabilizes. Retain
full logs, exit codes and source provenance. Diagnose actual layout/scrolling
causes rather than increasing viewports, hiding overflow/hit-test exceptions or
removing assertions. Preserve local originals, explicit import, UID/privacy,
pending-save and explicit conflict-resolution behavior.

Codex validates the unchanged artifact against the declared base/app tree,
reviews behavior and meaningful coverage, then independently runs scoped/full
acceptance checks as appropriate. Preserve the two-stage workflow and separate
deployment authorisation. Batch2 remains unaccepted and DEV remains unchanged
until its runtime failures are resolved.


Hosted setup verified: Actions run37766017527/job113273759089 succeeded,
including exact Flutter3.41.4/Dart3.11.1 verification, web precache and enforced
lockfile pubget; logs emitted COPILOT_FLUTTER_SETUP_READY. Initial run37765832906
failed JSON parsing because first-launch output preceded machine JSON; corrected
setup initializes Flutter before the machine-version check. This is environment
readiness, not batch2 application acceptance. SAME task tenth session started
for actual formatter/analyzer/focused tests and subsequent repairs; setup
correction was visibly delivered to the active session. Config pushes also
triggered existing GitHub Pages build/deployment; no app source changed and no
Cloud Run/Firebase DEV rollout was performed.
