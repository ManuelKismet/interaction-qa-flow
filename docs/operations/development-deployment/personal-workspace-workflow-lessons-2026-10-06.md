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
