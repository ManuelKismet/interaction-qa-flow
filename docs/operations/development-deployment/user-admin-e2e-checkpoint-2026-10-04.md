# Development guest, regular-user and admin end-to-end acceptance

User scope: finish remaining guest checks, regular-user account creation and complete user/admin flows. Exclude old local database. Reuse already verified common features rather than repeat unchanged flows. All work targets intqaflow-dev; there is no production environment.

Deployed reviewed code: dca98b796e00b77b947b2176f9060df51ee884b3. Source checks: 101 Flutter and 82 backend tests passed; analysis/release build passed. Coordinated dev rollout and stale API rejection passed. One-page nested PDF verified. Detailed prior evidence in codespace-appcheck-2026-10-04.md and pr13-follow-up-checkpoint-2026-10-04.md. Prior multi-account live artifact reports private-session/private-Knowledge, organisation visibility and foreign-tenant denials passed; that artifact used observation-mode App Check and does not establish current full UI flow acceptance.

| Coverage | Current status | Remaining evidence |
|---|---|---|
| Guest shared groups and pending/invitation boundaries | Passed | Reuse earlier results; targeted regression for changed paths |
| Guest PDF structure and attribution | One-page pass | Multipage, long answers, unusual glyphs; record supported limitations |
| Guest optimistic concurrency | API rejection and normal frontend save pass | Frontend 409 refresh/retry interaction |
| Registered account creation | Signup form prepared | User manual signup, outcome and onboarding |
| Guest local-work boundary on separate signup | Explicit UI message inspected | Verify after signup/signout; no implicit upload |
| Regular Knowledge | Pending UI verification | Ask/search/create/edit/answer/comments/reactions/status/history/archive/export and permissions |
| Regular Interact | Shared report/recursive feature evidence reused | Registered lifecycle, visibility, templates/import/export, proposals and deep links |
| Admin organisation management | Pending | Organisation/department/team/membership/role settings exposed by app |
| Admin governance | Pending | Review/verify/unverify/challenge/change requests/merge-unmerge/archive/audit and authority boundaries |
| Repository closure | Pending | Reconcile old checklist, sync local docs safely, exact-head PR review closure |

Existing private synthetic identities found for same/foreign organisation; credential values not read or output. Signup uses the normal hosted frontend. Browser authentication guidance requires manual handoff for account creation, so automation stops before new credentials or submission. Signup form states separate account does not transfer guest-group access or upload local work. Await manual completion, then inspect fresh signed-in evidence. Admin sign-in will use secure browserAuth or existing authorised session; no passwords in chat.

Lessons: API tests and old source suites do not replace role-specific UI acceptance. Historical checklist failures must be reconciled against later evidence, not silently treated as current. Preserve the owner local workspace during identity transitions. Revoked debug tokens/profiles from earlier acceptance stay revoked; any new debug credential needs its own justified scope.


## Signup error diagnosis and independent guest progress — 2026-10-04 20:12 UTC
User manually attempted separate signup; UI reported generic Sign-in failed. Please try again. Cause remains unconfirmed; credentials neither inspected nor retried by automation. Source safely sanitises FirebaseAuthException codes behind AUTH_DIAGNOSTICS, but unknown codes use generic sign-in wording during signup, weak-password has no dedicated mapping, and already-in-use uses guest-link wording. Copilot notified in PR13 comment 5983867417 to improve operation-specific safe messages and assess PDF glyph support. Don't assume the actual signup failure was weak-password.
Dev config-only diagnostic frontend published from unchanged dca98b7 with AUTH_DIAGNOSTICS=true; backend unchanged. First compile terminated with exit -15 plus optional Wasm dry-run failure; serial retry --no-wasm-dry-run passed (48.5s). Hosting release 1791144463288000, version b236e7e8ce3850c6. Safe diagnostic displays/logs sanitised error code only; no raw exceptions or credentials. Manual signup retry needed on reloaded form to establish cause.
Independent guest PDF fixture with 12 long questions plus original nested Alice/Bob fixture downloaded: 67,670 bytes, valid PDF, 13 pages. First/last long-question, nested follow-up and unanswered markers extracted. All-page text-bound scan: zero spans outside page rectangles. Rendered middle page inspected; long-answer flow stays within margins. Latin accents and Omega preserved; Chinese and emoji missing in extraction and visually shown as missing-glyph boxes. Existing preview warning is accurate, but broad Unicode support remains a confirmed limitation; no full PDF edge-case signoff until resolution or explicit supported-scope decision.
Actual two-tab guest frontend conflict recovery completed on disposable shared Knowledge: both tabs opened revision7; current writer saved revision8; stale save rejected with refresh/review guidance; Retry reloaded revision8; editor visibly retained current writer answer; reviewed edit saved revision9. Original owner shared entry stays revision1. Stale editor dialog closes on conflict; unsaved draft isn't preserved by that UI, a usability follow-up rather than an overwrite failure. Owner local draft retained after diagnostic frontend reload.
Admin role model confirmed in backend auth routes: Firebase provides identity and verified email, while organisation membership supplies authoritative role; Firebase-only role changes are insufficient. Obtain and record regular/admin test emails without passwords. Await account creation and verified onboarding, then use documented server-managed membership path with scoped authorisation for admin grant.

### Signup investigation, 2026-10-04 20:25 UTC

User manually attempted separate-account creation with user1@me.com; confirmation appeared, then generic sign-in failure. Creation remains unconfirmed. Hosted JavaScript matches diagnostic build SHA-256; marker present and AUTH_DIAGNOSTICS=true has no conflicting file define. Handler always appends sanitized code, but open tab showed none. Stale running frontend suspected, not proven; Firebase rejection unknown. Reload preserved guest workspace and original local draft. Avoid blind credential retries.

Copilot head 8755edd5f4ed2a38d85951e52fdff337f5107e2f adds signup-operation messages and PDF font-gap guards, plus tests. Review worktree prepared; checks and rollout pending. Guest, user and admin scope retained; old local database excluded. Lesson: deployed-file equality does not prove an open tab runs the latest bundle.

Validation head 8755edd: full Flutter run completed in 61 seconds: 101 passed, 3 failed. New email-in-use and weak-password signup widget tests found no matching candidates; unsupported-glyph PDF test leaked UnsupportedPdfCharactersException. Rollout held. Copilot correction requested; do not claim fixes accepted. PDF change guards unsupported glyphs, it does not add Chinese/emoji font support.

### Follow-up validation, 2026-10-04 20:45 UTC

Reviewed 520ee01 operation snapshot and normalized auth code; diagnostic release build passed (66.1s, exit 0). Analyzer failed one unused signInError fake parameter warning. Overlapping test run ended without a footer; serial rerun completed 101 passed/3 failed. Signup expected-message assertions passed, but helper incorrectly searched obscured editable password state as though it were displayed error text. Reported precise correction to Copilot. Lesson: test displayed error leakage independently from obscured input state; record process exit codes and run compilation checks serially when resources are constrained.

Reviewed d2810c890af1f2d9bd9027fadb4d49e0a471c25a (only account test changes since 520ee01). Full Flutter suite completed 103 passed/1 failed in 67s. Signup message and obscuring checks now pass. Unsupported-glyph PDF test still leaks UnsupportedPdfCharactersException after asset load; Copilot notified with source/test lines and requested consistent binding/error-zone investigation. Analyzer completed with 12 informational findings and no warning shown; --no-fatal-infos check completed. Release application source is unchanged from successful 520ee01 build. No new development rollout; PDF blocker unresolved. Signup success, user E2E and admin E2E remain unconfirmed. No old local database work.

### PDF async rejection diagnosis, 2026-10-04 20:54 UTC

Copilot head 8f8ba9d4f53d103b91401317d7bd8be44fd70939 changes only the PDF test harness to testWidgets/runAsync. Full Flutter run: 103 pass/1 fail in 57s; analyzer exit0. Isolated PDF test also fails in 1s, excluding prior-test dependency. A disposable broad-catch diagnostic confirmed the correct exception type is caught, but framework reports unhandled failure first. Temporary source diagnostic yielded after rootBundle.load using await Future<void>.delayed(Duration.zero) in both PDF builders; focused test passed exit0. Original source restored byte-for-byte, git status clean, diagnostic test files removed. Copilot received evidence and requested async-delivery boundary in both builders. Lesson: synchronous asset completion can report a rejecting Future before caller attaches handling; a catch matching the correct type alone is insufficient. No rollout yet; official fix and verification pending.

### Validated frontend rollout, 2026-10-04 21:19 UTC

Copilot 58e199f chained report validation; 104 Flutter tests passed and analyzer exit0. Follow-up b3d64911cad22d56d41f0d64b3c360e211f0330f adds a shared asynchronous font-load boundary for both report and portable Knowledge PDF builders, plus typed unsupported-glyph portable coverage. Final head: all 104 Flutter tests passed in 48s, analyzer exit0 (12 existing informational findings), diagnostic release build passed in 48.7s. No backend source changes since dca98b7; no backend rollout. Frontend Hosting release 1791148349613000, version 685a23bf5da673fe, 36 files, exit0. Live JavaScript SHA-256 equals built artifact. Previous diagnostic Hosting version b236e7e8ce3850c6 retained as rollback.

Live reload preserved original local Knowledge and guest group access. Synthetic shared entry rev9 to rev10 with cafe/Greek/CJK/emoji answer. Direct Download PDF correctly opened a browser-print fallback tab; application preview visually retained cafe, Omega, Chinese and emoji. Control of generated tab13 failed with Emulation.setLocaleOverride duplicate-locale error; fallback document/printed glyphs not independently inspected and no new saved PDF claimed. Original synthetic answer restored at rev11; original shared entry still rev1. Proof: intqaflow-b3d6491-pdf-fallback-proof.jpg. Browser-print tab unmarked for ephemeral cleanup.

Signup operation messages and safe auth-code diagnostics now deployed; actual user1@me.com signup remains unconfirmed. Regular/admin full UI E2E still pending. Old local database excluded. Lesson: a successful unit fallback check plus opened preview is not a saved-PDF glyph rendering sign-off; retain this distinction when browser tooling blocks inspection. Docs are local review checkpoints; publication/closure reconciliation remains pending.


### Signup and manual development verification — 2026-10-04T22:06:19.213457+00:00

- Separate-account signup succeeded in the deployed app for `regularuser1@test.com`; this is the actual successful account, distinct from the earlier `user1@me.com` attempt.
- At the user’s explicit request, development Firebase email verification was set manually for this exact enabled account. Lookup HTTP 200, prior emailVerified false, update HTTP 200, independent lookup confirmed true and matching identity. No password, provider, role or organisation membership changed.
- This is a scoped test setup exception: mailbox delivery and normal email verification have not passed E2E.
- Signed-in UI reports no organisation membership, as expected. Organisation enrolment and full regular-user/admin flows remain pending; separate signup does not transfer anonymous guest group access.
- Lesson: distinguish authentication, verified email and authoritative server organisation membership; record the actual successful identity before enrolment.


### Admin identity and test organisation plan — 2026-10-04T22:11:06.637042+00:00

- User selected `adminuser@test.com` for the development admin test account and authorised a test organisation plus departments/teams and regular-user assignment coverage.
- Regular account signed out successfully; local guest Knowledge remained visible. Separate admin signup form prepared for manual credential entry. Admin signup, verification and role grant are not yet confirmed.
- Bootstrap only the organisation and first admin through the authoritative server membership model. Exercise regular member enrolment, department/team creation and assignment through the admin UI to retain meaningful E2E coverage. Firebase-only role flags are insufficient.
- Keep all fixtures synthetic and confined to intqaflow-dev. Do not repeat already covered guest features or touch the old local database.
- Lesson: bootstrap the minimum access needed to test admin onboarding; avoid pre-seeding the user assignments that the E2E scenario must exercise.


### Verified admin and first organisation bootstrap — 2026-10-04T22:23:37.046647+00:00

- Hosted separate signup confirmed `adminuser@test.com`. At the user’s request, development Firebase emailVerified changed false to true: lookup/update HTTP 200 and independent identity-matched readback true. Normal mailbox verification remains untested.
- Unmodified `backend/scripts/provision_organisation_admin.py` created `IntQAFlow E2E Test Organisation`, slug `intqaflow-e2e-test-20261004`. Independent database readback confirms active admin membership and Firebase UID mapping for adminuser@test.com; exactly one ORGANISATION_ADMIN_PROVISIONED audit event.
- Organisation ID: 15f73358-dbee-46e4-a5fa-c30c3301a282. No regular-member assignment, department or team was pre-seeded; these remain admin UI scenarios.
- Initial SQL proxy attempt failed before database access because gcloud was missing from PATH after restart. Corrected PATH; transient loopback-only proxy terminated after checks. Tokens/database credentials stayed in memory and were not printed.
- An import defect report was based on a misread screenshot and was retracted in PR13 comment 5985099607; the committed import was already correct. An overly restrictive operator assertion stopped the second attempt before provisioning. Final execution used the unmodified script.
- Lesson: verify exact committed text before reporting a defect; include setup stage labels and independently read back both membership and audit evidence.


### Admin UI enrolment and team creation — 2026-10-04T22:26:55.079148+00:00

- After refresh, admin navigation and organisation Knowledge workspace loaded. Admin member list shows adminuser@test.com as admin.
- Through Add organisation member, enrolled verified regularuser1@test.com as Employee with no primary department. Refreshed member list confirms both identities/roles. Empty email validation was observed before successful entry/submission.
- Created `E2E Operations Team` with synthetic description and cross-functional scope through the admin UI; team appears and expands. Assignment has not passed.
- Confirmed blockers against source: Departments lists entries but offers no create control although backend admin-gated POST /departments exists; fresh-org department assignment picker only offers no department. Team membership and answer-owner assignment require raw User ID, while member management displays email/role without an accessible ID. Requested department creation and readable org-member selectors from Copilot in PR13 comment 5985131741.
- Remaining: department creation/assignment, team membership/answer owners, governance/admin permissions, regular-user UI E2E, saved print-fallback PDF glyph verification and documentation reconciliation/publication. Manual verification does not prove mailbox flow.
- Lesson: fresh-organisation UI acceptance exposes gaps that API-only pre-seeded tests miss. Keep IDs in the API implementation and provide readable member selection to administrators.


### Regular-user sign-in continuation — 2026-10-04T22:30:03.549973+00:00

- Admin signed out; original local guest Knowledge persisted. Existing-account secure browserAuth sign-in submitted, but rendered Firebase diagnostic was `[auth/invalid-email]`. Credential values were not inspected or recorded; this does not establish an invalid password or successful sign-in.
- Automated credential retries stopped. Manual handoff offered to correct the email and complete regularuser1@test.com sign-in. Employee membership remains confirmed from admin UI. Full regular-user UI coverage pending.


### Employee Knowledge acceptance and new Copilot validation — 2026-10-04T22:40:35.515120+00:00

- Manual sign-in confirmed regularuser1@test.com as Employee. Retained admin view denies access; Admin/Review navigation hidden. Knowledge navigation recovers normal workspace.
- Created question 7b1e2087-b9a2-48f5-9c98-403203fc1fa6 (`How should E2E operations record a verified handover?`), submitted and revised its own answer, added discussion (count1), accepted answer (resolved). After acceptance direct answer edit/remove controls disappear. Resolved question listing includes the fixture.
- A question wording review request was submitted; admin-queue persistence/review is still to verify. Intended wording adds `and review`. No direct mutation of protected question occurred.
- During answer editing, automation initially appended text rather than replacing. Field-bound Control+a was visually verified, final saved answer contains exactly one intended revised sentence. Historical revisions retain the synthetic intermediate text.
- Live search POST /api/v1/questions/search fails HTTP500 (22:33:22 and 22:37:59 UTC). Server UndefinedFunctionError: setweight(tsvector, character varying) does not exist. Copilot notified with PostgreSQL integration-test requirement (comment5985227132). Saved-question CRUD/listing still works.
- New Copilot head5e1cd91 adds department creation/readable member selectors. Full Flutter103pass/1fail40s: owner assignment expected answer-owner-1 actualnull plus dropdown RenderFlex overflow, team_ui_test.dart256. Analyzer/build/deployment held after failure. Copilot notified5985205394. New first-admin help smoke passes1 in1.03s. Backend app source unchanged at this head.
- Began private organisation-backed Interact fixture ca40e2aa-916a-4544-a564-99d2f264d2df titled E2E Employee Private Handover; participant E2E Participant One added. Session lifecycle/persistence/report and admin denial remain pending.
- Lesson: real PostgreSQL function parameter types require execution tests; mock query tests did not expose the weighted lexical bind mismatch.

### Recovery checkpoint — 2026-10-04 22:55 UTC

- Regular-user private Interact session `ca40e2aa-916a-4544-a564-99d2f264d2df`: draft creation, participant/question addition, start, answer autosave, completion, and reload persistence passed. Private/completed status and 1/1 answer persisted; history revisions 2–6 recorded these operations.
- Explicit Knowledge proposal was clicked twice while the success toast was not observed. Sanitised Cloud Run request logs independently show two POST `/api/v1/guided/knowledge-proposals` responses with HTTP 201 (22:42:40 and 22:43:49 UTC). Admin queue persistence and possible duplicate handling remain pending; no approval/publication is claimed.
- Employee sign-out completed. Current browser is on the existing-account sign-in form, ready for secure admin sign-in. Admin governance, department creation, member/team assignment and current-session access-denial checks remain pending.
- Head `871d698` failed full Flutter validation: 103 pass, one fail, RenderFlex overflow of 95 pixels at team_ui_test.dart:220. Analyzer/build/deployment withheld; Copilot notified in comment 5985275375.
- Head `2958d72327e629c5d0a31f6c355592c5f577590d` failed full Flutter validation: 103 pass, one fail in 39 seconds. team_ui_test.dart:195 expects the empty-department text but finds zero widgets. Analyzer/build/deployment withheld; Copilot notified in comment 5985330130.
- The latest PostgreSQL search fix replaces bound weight strings with literal A/B SQL constants. Full backend validation with the actual PostgreSQL regression test has been launched through a loopback-only SQL proxy; result pending. Test creates a UUID-named temporary schema and removes it in its cleanup; existing app schema and the excluded old local database are not test targets.

Lessons: verify selection before replacing Flutter text; bind-aware PostgreSQL function signatures require real PostgreSQL coverage; full admin widget validation must include empty-state and narrow-width selected-value rendering. HTTP 201 proves a request succeeded but does not replace review-queue and approval acceptance. Recovery must read logs rather than infer success from a background process exiting.

### Admin governance and real PostgreSQL verification — 2026-10-04 23:10 UTC

- Manual admin sign-in succeeded; account menu independently showed `adminuser@test.com`, organisation workspace admin.
- Review queue showed the employee title change and one pending Interact proposal despite two earlier proposal HTTP 201 responses. No duplicate rejection was necessary.
- Admin approved the title change; question `7b1e2087-b9a2-48f5-9c98-403203fc1fa6` displayed the proposed title, entered under review, and was verified by admin. Final resolved/accepted answer retained the correct single handover text, with Verified by adminuser@test.com and review date 2027-04-02.
- Admin Create new Q&A from the explicit Interact proposal succeeded. New question `95d78939-fd71-48bb-9f75-0ab50c123218` retained employee authorship, synthetic answer and source session reference. Proposal queue became empty. Admin verification then resolved this new question.
- Backend full suite at 2958d72: 83 pass, one integration failure, one warning, 13.32s. PostgreSQL test stopped at CREATE SCHEMA with InsufficientPrivilegeError; application DB privileges were not widened.
- Actual PostgreSQL read-only SearchRepository lexical query passed and returned the expected existing verified employee fixture. SQL transaction was READ ONLY; loopback SQL proxy terminated. Initial probe assertions were incorrect (results are tuples) and corrected to candidate[0].id; this is test-harness correction, not an app defect. Copilot's integration assertion also needs this correction; comment 5985413277 records it.
- New head de242bf696e94c2fa56ea2de1ff7967fa27cdcda failed full Flutter validation: 103 pass, one fail, 50s. Department selector at admin_page.dart:211:34 overflowed 95 pixels at 212x24; team_ui_test.dart:208 could not find the lazy Create department FilledButton. Copilot notified in 5985424800. Analyzer/build/deployment withheld. Existing frontend b3d6491 and backend reviewdca98b7 remain live.
- Department/member/team assignment acceptance remains pending the corrected frontend. Actual isolated PostgreSQL integration test remains pending test-database permissions and corrected assertion, even though existing-fixture lexical execution passed.

Lessons: selectedItemBuilder fixes must cover each constrained dropdown, including department selectors; lazy ListView tests must scroll to the action itself, not just nearby text. Do not broaden app database privileges for test setup. Distinguish source query execution from hosted endpoint acceptance; deployed search/duplicate checks still show the existing backend error until rollout.

- Current admin-private-session boundary passed: same-organisation admin could not open employee private session ca40e2aa-916a-4544-a564-99d2f264d2df; sanitized Cloud Run requests returned 403, and UI eventually displayed Unable to load this Interact session. Automatic retries delayed the final message; a clear immediate forbidden state is a usability follow-up. No private answer content displayed.

### Backend green and admin lifecycle follow-up

- Admin Review as current passed: POST /answers/17113f16-1a9d-4505-8eed-25cb305a5e9d/review HTTP 200 at 23:08:00 UTC. History still showed only v1 community / v2 verified, confirming no new content version.
- Synthetic proposal Q&A archive HTTP 200 at 23:09:21 UTC and restore HTTP 200 at 23:10:32 UTC passed. All-list retained the archived item for governance; archived detail retained verified answer and source reference. Restore returned resolved state and retained accepted/verified answer.
- Reopen failed HTTP 422 at 23:10:49 UTC, leaving question resolved. Frontend questions_repository.dart reopen sends no body; backend requires QuestionAction payload. Copilot notified in 5985482530; fix/retest pending.
- Head 80b0c61f5feba0fcb681ce1ee0f7fb97133d6be7 backend full suite PASSED: 84 tests, one existing deprecation warning, 13.07s. This includes actual isolated PostgreSQL16 lexical integration with pgvector, UUID test schema cleanup, and corrected tuple assertion. Fresh database was initialized specifically for this run; no old/local legacy DB was used. Server stopped and generated password file removed. First run lacked vector extension and failed test setup; after installing the already-available extension in this fresh DB, full suite passed.
- Backend source is the reviewed PostgreSQL weight fix; frontend still blocked by de242bf admin widget failure. Development backend build and no-traffic staging launched for exact reviewed 80b0c61, using minimal Docker context (app, requirements, established Dockerfile and ignore rules). Rollout result pending. Existing reviewdca98b7 remains rollback/serving revision until staged readiness and traffic switch are verified.

Lessons: frontend no-body POST is not equivalent to an empty JSON object for a required Pydantic body; contract checks must cover real route payloads. Fresh isolated PostgreSQL with its required extensions avoids both shared-database writes and widening application database privileges.

### Development search rollout verified

- Exact backend 80b0c61 build succeeded, Cloud Build 1c4ca996-63dc-4f80-afd8-a5e53207be13, 45 seconds. Staged no-traffic revision intqaflow-dev-api-review80b0c61 was Ready. Runtime environment, service account and Cloud SQL/network annotations matched the prior serving revision; no credential/IAM/security configuration changes.
- Development traffic switch completed: intqaflow-dev-api-review80b0c61 serves 100 percent; /health returned HTTP 200. Rollback remains intqaflow-dev-api-reviewdca98b7. Frontend remains b3d6491; PR13 remains draft/unmerged.
- Hosted admin UI short-query search `verified handover` PASSED, displaying both verified synthetic Q&As labelled Keyword match with correct answers. Previous search500/temporarily-unavailable issue fixed for this tested query. Proof: intqaflow-dev-search-rollout-proof.jpg. Regular-user hosted search retest remains pending next employee sign-in.
- Admin created organisation-visible draft Interact fixture 231a10a3-76c3-4e77-a186-720c52c3d854, title E2E Admin Organisation Handover, synthetic context. Owner admin could open it. Employee organisation-visible read/edit boundary remains pending; common session lifecycle coverage reused from employee private flow.
- Remaining active blockers: frontend admin dropdown/lazy-widget failure and no-body Reopen POST. Copilot has precise failures. Department creation, employee primary department, team membership, department answer-owner assignment and associated employee permissions await corrected frontend; no old local DB work.

Lesson: independent tested backend fixes can be rolled out to development while an unrelated frontend remains on its prior version, provided API compatibility, readiness, retained configuration, rollback and hosted acceptance are verified.

### Frontend release still gated at 0f3baaf

- Exact 0f3baafec0eb06a11905ebd425c7188a72f8503d fixes Reopen with explicit empty JSON body. New backend contract test proves missing body422 / empty body200; full backend suite passed84 tests, one existing warning,20.06s, with fresh PostgreSQL integration and server/password cleanup. Backend app remains identical to deployed80b0c61.
- Full Flutter suite failed loading team_ui_test.dart:214:7: No named parameter with the name axisDirection. Remaining tests102 passed; one failed file load,64seconds. Admin widget checks were not executed. Analyzer/build/deployment withheld. Copilot notified in5985544186.
- Hosted development search success proof saved and independently confirmed non-empty. Current admin session retained for department/team/member acceptance after corrected frontend. No additional credential request is needed until employee retest.
- Documentation remains local on the diverged development docs branch; a separate documentation review branch is being prepared so accumulated checkpoints can be published without resetting or force-pushing the development branch.

Lesson: distinguish a failed test assertion from a test file that cannot compile; neither signs off the admin UI. A backend contract test plus live frontend retest is required to close Reopen after deployment.

### Reconnection checkpoint and published documentation

- Published the cumulative four-file documentation checkpoint as commit `2be875197ee73e1d785f2b92735f4fa739b07b6d` on `docs/user-admin-e2e-checkpoint-20261004`; draft PR 15 is open, unmerged.
- Hosted admin prefix search `handov` returned both verified synthetic questions with Keyword match labels. Backend revision `intqaflow-dev-api-review80b0c61` remains live at 100%; frontend remains `b3d6491`.
- Exact frontend head `b37ac7e` passed 104 tests and failed one admin test at line 210: the department creation control was above the current viewport, while the test scrolled downward. Analyzer and release build were withheld after the failed suite.
- A temporary diagnostic changing the second scroll delta to -300 advanced the targeted suite to the team member selector assertion at line 316, which found no matching long display name. Targeted result: two passed, one failed. The diagnostic source edit was restored; it is not a release candidate or committed fix.
- Copilot subsequently pushed `bae1eed5c92b9bf4c360935ee023305f2fbf8d0c`, changing that same scroll delta to -300. Exact-head tests are running; deployment remains gated.
- Lesson: detach background Flutter commands from terminal input with nohup and redirected stdin; an attached background run can disturb the interactive terminal. A new terminal restored command execution.
- Production, the old local database, and the unrelated migration document remain excluded. Remaining department, team, answer-owner, regular-user permission and organisation session checks are still pending.

### Exact bae1eed frontend result

- Full suite on exact `bae1eed5c92b9bf4c360935ee023305f2fbf8d0c`: 104 passed, one failed, 45 seconds. The department creation scroll gate is fixed.
- Remaining failure is `team_ui_test.dart:316`: after tapping the last generic Select a member control and choosing the long-name fixture, the keyed `team-member-selector-team-1` has no selected display-name text. The selected-item builder renders displayName; the test may have opened a different department/team selector. Copilot comment `5985641380` requests a consistently keyed control plus real addTeamMember validation. No conclusion that member assignment itself is broken yet.
- Analyzer and release build remain withheld after the failed test suite. No frontend deployment or merge occurred. Backend 84-test isolated PostgreSQL evidence and the live search fix remain valid because the new head changes only the frontend test.
- Lesson: scope interaction and outcome assertions to the same control when several identical dropdown hints exist; scrolling can change which generic last match is visible.

### Confirmed selector diagnosis and live duplicate flow

- Temporary test-only keyed Payroll selector probe passed all three team UI tests in three seconds, including selected display name and real addTeamMember validation. The generic last Select a member hint opened another dropdown. Original test restored; review worktree clean. Copilot comment `5985673488` contains the exact correction; release still requires committed-head full tests/analyzer/build.
- Live admin duplicate flow passed: synthetic question `e700114c-05a4-4bba-84d9-9b999cab85e6` was created with the existing verified question title, possible duplicate results showed both verified fixtures, and Compare displayed the canonical detail and verified answer correctly. Keep separate closed comparison. The disposable unanswered duplicate was archived with a cleanup reason, API HTTP 200 at 23:38:15 UTC; UI lists it archived with zero answers. Original two verified questions remain resolved. Creation returned HTTP 201; search returned HTTP 200.
- This validates post-creation duplicate detection and comparison, not a pre-creation blocking warning or merge workflow. Recoverable archive retained history; no permanent deletion occurred.

### 2026-10-05 resumed development release gate

- Copilot PR13 remained at bae1eed overnight. Applied the already verified test-only selector correction on separate branch `codex/fix-admin-selector-e2e`, commit `ed24b0ae14fc576668469f0e5e9229cc8c8751cf`; draft PR16 targets the Copilot branch and remains unmerged. Application source unchanged by this correction.
- Restarted the stopped Codespace and launched serial exact-commit full Flutter tests, analyzer and release build. Backend source remains the validated deployed 80b0c61 implementation; no backend rollout required.
- Hosted admin session remained signed in. Both synthetic organisation members and their admin/employee roles loaded correctly after reconnection. Production and the old local database remain excluded.

### Validated frontend published to development

- Exact commit ed24b0ae14fc576668469f0e5e9229cc8c8751cf: all 105 Flutter tests passed (48s), analyzer passed (12 existing infos, no errors/warnings), release web build passed (49.3s). Draft PR16 remains unmerged.
- Development Hosting release `1791182719884000`, version `3bbec4254fc5fdc1`, 36 files. Independent HTTP download of main.dart.js matched the exact local build hash (4400648 bytes). Backend remains review80b0c61 at 100%; prior frontend rollback version 685a23bf5da673fe retained.
- Admin session survived reload. New department creation control is visible. Created synthetic E2E Operations Department and selected it as regularuser1 primary department with Employee role unchanged; hosted membership outcome verification follows.
