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

### Hosted department and team acceptance

- Created E2E Operations Department through the new admin form (API 201). regularuser1 now visibly has Employee role and that primary department.
- Added regularuser1 to existing cross-functional E2E Operations Team with readable account selection, verified member row, removed it, verified absent row, and re-added it, verified restored row.
- Created E2E Department Handover Team with parent E2E Operations Department; title and department displayed correctly. Added regularuser1; membership outcome verification follows. Supports retaining membership in multiple teams.
- Dropdown menus visually show account labels but the Flutter accessibility tree initially exposes only the hint; screenshot-based option selection was necessary. Record this accessibility limitation without confusing it with absent data.

### Hosted Reopen repair and next account checks

- Department-linked team membership visibly confirmed for regularuser1. Team ID 0a2022ba-6667-4889-868a-2c3c6b5dd2cc; cross-functional team e877da4a-d9ca-4e24-bdb6-7b5fe2ac13d3. Both member additions API 201.
- Reopen on synthetic verified question 95d78939-fd71-48bb-9f75-0ab50c123218 passed HTTP 200 at 06:52:44 UTC, replacing the previous missing-body 422. UI became open and retained the verified answer; Accept answer restored resolved/accepted/verified state with original answer text.
- Department owner form correctly refuses assignment without an active Answer owner member. Both accounts remain Admin/Employee. Role promotion and department-scoped owner assignment/revoke are not yet executed.
- Remaining account-specific acceptance: employee sign-in, post-admin approved/verified content restrictions, department/team selection, organisation-visible session read/edit boundary, current keyword/prefix search, and answer-owner governance. Earlier common guest/employee lifecycle checks are retained without repetition. Browser printed CJK/emoji PDF glyph verification remains pending; old local DB and production excluded.

### Employee sign-in handoff gate

- Admin signed out after completed admin checks. Secure browserAuth submitted existing email/password sign-in, but visible site response was auth/invalid-email. Employee sign-in is not verified; credentials were not read or logged, and no blind retry performed. Manual handoff requested for regularuser1@test.com.
- Retain pending employee permission, department/team selection, current search and organisation-session visibility checks. Answer-owner role/assignment needs a scoped account and action-time approval before increasing governance permissions. No role changed; admin/employee roles retained. Documentation and checkpoint PR15 latest published outcome remains the source of truth; full suite 105 pass and dev frontend ed24b0a remain green.

### Employee sign-in and access boundary verified

- Manual sign-in succeeded. Account menu freshly confirms regularuser1@test.com, organisation Employee role.
- Verified accepted own answer is visible with Suggest update/History but without edit/remove/verify/review actions; approved question has Request review. Direct /admin route renders Administrator access is required.
- Admin-owned organisation-visible session 231a10a3-76c3-4e77-a186-720c52c3d854 loads for employee (read boundary passed). Enabled Start produced HTTP403 at 07:06:00 UTC, session remained draft (write boundary passed). UI still shows enabled edit controls without a durable explanation: frontend usability defect, Copilot comment5989758071 requests read-only non-owner employee view with reports/export retained. No access bypass or session mutation observed.

### Employee scoped Knowledge acceptance and governance fixture

- Current employee prefix search handov returned both verified fixtures with Keyword match labels. Department choice exposed E2E Operations Department; with that department selected, team menu correctly exposed E2E Department Handover Team and excluded cross-functional mismatch.
- Created question 2d4b9691-67ac-4d62-928c-28990fcf18f9, How should the E2E department team verify its scoped checkpoint?, by regularuser1. Detail shows the saved E2E Operations Department and E2E Department Handover Team. Submitted community answer: The E2E department owner verifies the synthetic checkpoint and records the responsible team. Question is answered, unaccepted/unverified, ready for governance testing.
- Employee can edit/remove its own unapproved community answer and accept it; Verify and Review as current are absent. Question itself now offers Request review after contribution. Previously verified own answer remains protected.
- Proposed next scoped check: temporarily promote regularuser1 from Employee to Answer owner, assign only E2E Operations Department, verify/review the scoped fixture, demonstrate no power over department-free fixtures, revoke the department assignment, and restore Employee role. Requires action-time confirmation before increasing governance permissions under browser rules. No promotion/assignment has occurred.
- Remaining: answer-owner assign/revoke and role boundary, read-only UI correction for non-owner organisation sessions, browser print CJK/emoji glyph verification. Preserve historical common flows without repetition. Production, old local DB and merges remain excluded.

### Approved temporary answer-owner acceptance

- User explicitly approved temporary regularuser1 Answer owner promotion for E2E Operations Department, scoped verification/revocation test, then restoration to Employee (2026-10-05 08:13 London). This authorization is retained; no repeated permission question needed for that same scope.
- Signed out regularuser1 after baseline employee checks; manual adminuser@test.com sign-in handoff prepared using established manual sign-in preference after secure form produced invalid-email. No role promotion or department owner assignment has happened yet.
- Execution sequence: admin promotes/assigns; regularuser1 tests scoped fixture 2d4b9691-67ac-4d62-928c-28990fcf18f9 and absence of broader powers; admin revokes/returns Employee. Preserve synthetic organisation and both team memberships.

### Approved owner assignment executed; separate sign-in prepared

- Fresh account menu confirmed adminuser@test.com/Admin after manual sign-in. Saved regularuser1 role Department answer owner with primary E2E Operations Department retained; member row now shows answer_owner.
- Assigned regularuser1 only to E2E Operations Department, ID dc65db82-a4e6-4188-8e90-59620d4f8c7d. POST department answer-owners returned201 at07:21:31 UTC; owner list displays regularuser1/E2E Operations Department and Remove owner. No other department assigned.
- Cleanup obligation remains active: revoke this assignment and restore Employee after scoped verification/negative-boundary test. Admin tab9 stays signed in for cleanup.
- Verified alternate development origin https://intqaflow-dev.firebaseapp.com serves the exact deployed main.dart.js hash (4400648 bytes). Browser tab14 is independently signed out on that origin and prepared for manual regularuser1 sign-in; admin web.app origin remains signed in. This allows the two test identities to coexist without repeated admin credential handoffs. No production or app configuration change.
- Lesson: using the two existing development Hosting origins isolates origin-local authentication for multi-account E2E while preserving the admin session for reliable rollback. Verify identical build and actual signed-out state before relying on isolation.

### Browser transport recovered without replaying setup

- User requested retry at 08:53 London. Browser inventory and live tab observations now succeed. Admin tab9 is still in Admin with regularuser1 Answer owner role and the existing E2E Operations Department owner assignment; no setup action was replayed.
- Isolated regular-user tab14 remains at the existing sign-in form on firebaseapp.com. Manual sign-in as regularuser1 is the next blocking step; admin web.app tab stays available for revocation and Employee restoration. Neither cleanup nor scoped verification is claimed complete.
- Codespace terminal is available. Previous published grant checkpoint and PR15 interruption comment5990063182 remain valid.
- Lesson: after a transport failure, inventory and inspect existing surfaces before navigating, logging out, recreating fixtures or repeating a grant. Preserve the admin rollback session and verify actual state; an interrupted handoff is not a successful login.

### Scoped Answer-owner verification and complete cleanup — 2026-10-05 09:09 London
- Isolated regular-user sign-in succeeded without disturbing the admin session. Exact deployed frontend ed24b0ae and API 80b0c61 unchanged.
- Scoped question 2d4b9691-67ac-4d62-928c-28990fcf18f9 / answer 79ea1fea-325c-4d44-b36a-53fc0995a26e: Verify HTTP 200 at 07:59:05Z, Review as current HTTP 200 at 07:59:40Z. UI resolved/accepted, verified by regularuser1@test.com, review 2027-04-03. History shows only v1 verified; review did not add a content version.
- Out-of-scope department-free answer e5111344-d4d2-49ec-8458-2bde0b58c947: UI wrongly offers Review as current, submitted once and correctly denied HTTP 403 at 08:04:41Z; original resolved/verified state retained. Backend scope PASS, UI affordance FAIL.
- Admin removed the only Operations department owner assignment; UI shows No answer owners assigned. Before role demotion, fresh regular-user reload still offered Review as current on previously scoped answer; submitted once and correctly denied HTTP 403 at 08:06:32Z. Backend assignment revocation PASS, UI affordance FAIL.
- Admin restored regularuser1@test.com to Employee. Persisted member row confirms employee and E2E Operations Department; both department-linked and cross-functional teams still contain this employee. Temporary grant is no longer active. No admin grant, production change, old local database operation, or merge occurred.
- Proof: intqaflow-owner-restored-employee-20261005.jpg captured and inspected. Scope/revocation UI defect sent to Copilot PR13 for assignment-aware button gating and regression tests; do not broaden backend permissions.
- Lesson: evaluate scope and revocation independently of organisation role. A visible button is not evidence of API authority; preserve separate UI/API outcomes and prove rollback before handoff. After interrupted dropdown actions, read settled state before repeating selection.
- Remaining: Copilot organisation-session read-only UI and governance-scope UI fixes/retest; audit uncovered review/challenge/merge feature flows; browser PDF CJK/emoji printed glyph proof remains platform-blocked. Do not label the full user/admin feature matrix complete.

### Employee challenge -> administrator rejection E2E — 2026-10-05 09:20 London
- Copilot PR13 checked: no new commit, still bae1eed; assignment-aware governance UI and non-owner Interact read-only UI fixes remain pending.
- Existing synthetic scoped answer used without extra permissions. Employee Suggest update submitted a synthetic rationale and replacement that explicitly must not be applied: POST answer challenges HTTP 201 at 08:15:30Z.
- Admin Review queue listed the department challenge; detail offered Reject/Accept. Admin rejected with reviewer note: POST /api/v1/challenges/c45e8e1e-3615-4f24-af0f-af1f03f39f1e/reject HTTP 200 at 08:16:53Z.
- Verified restoration: original text, accepted/resolved status, verified attribution, and review 2027-04-03 unchanged. History remains only v1. Fresh employee detail also shows verified answer with no owner governance controls.
- Open queue empty after rejection. Rejected status filter returns the challenge, demonstrating retained closed-record traceability. Proof intqaflow-rejected-challenge-20261005.jpg captured/inspected. This completes the rejection path, not acceptance/other challenge types.
- Lesson: check both removal from the actionable queue and retention in a closed-status queue; empty open queue alone does not demonstrate retained history. No old local database, production, permanent deletion, or repository merge.

### Employee challenge -> administrator acceptance and restoration E2E — 2026-10-05
- Employee submitted a second Suggest update with the original text plus harmless synthetic checkpoint sentence: HTTP 201 at 08:19:28Z. Admin saw the prefilled replacement and added a review note.
- Challenge dd61082a-f23e-4d8d-869d-fac6532a463b accepted HTTP 200 at 08:20:50Z. Replacement became the accepted verified admin answer; original employee answer remained as community content. History retained v1 verified original, v2 superseded original, and v3 verified replacement. This demonstrates replacement/provenance, not an in-place author rewrite.
- Restored admin replacement answer 314f73af-bb83-4905-8db5-865038f901bf to original wording with audit reason: PATCH HTTP 200 at 08:24:43Z. Edit correctly cleared verification/acceptance and put question under review. Admin then verified original employee answer 79ea1fea-325c-4d44-b36a-53fc0995a26e HTTP 200 at 08:25:21Z: resolved, accepted original text, employee attribution, verified by admin, review 2027-04-03. Restored admin community answer retained for audit; no permanent deletion.
- Initial restoration attempt did not write: focus/text replacement was not reliably committed by native input. DOM-observed textbox fill plus explicit reason verification succeeded. Do not report the initial input failure as a product defect. Lesson: verify all form values before Save; validate persistent result and API request, not temporary DOM text or a closed dialog.
- Acceptance history proof intqaflow-accepted-challenge-history-20261005.jpg; restoration proof intqaflow-challenge-restored-answer-20261005.jpg. Open review queue empty after cleanup. Employee role/department/team cleanup from prior checkpoint remains valid, no additional grant.

### Independent exact-head validation of Copilot 7296b51 — 2026-10-05
- Copilot pushed 7296b51b733eaf8ce96111cab89ecd0962185ab1 and completion reply 5990941008: actual department-owner assignment gating, non-owner Interact view-only controls, keyed Payroll test, and backend mine-assignment endpoint. PR13 remains draft/unmerged.
- Clean review checkout switched to exact 7296b51, no application edits. Backend full suite on fresh isolated PostgreSQL/pgvector: 84 passed in 22.59s, one existing Starlette deprecation warning. Ephemeral server stopped and temporary password file removed by harness. Old local database untouched.
- Full Flutter suite: 109 passed, 2 failed, 65s. Both new guided_session_page_test.dart cases fail: non-owner read-only report/export case at line78; owner editing case at line144. Primary layout exception RenderFlex overflowed40px at active participant DropdownButtonFormField in guided_session_page.dart:141:30, fixed width230 without isExpanded. Secondary deactivated-widget-ancestor diagnostics followed the overflow. Scoped governance assignment/out-of-scope/department-free/revoked regressions and keyed Payroll test passed.
- Copilot notified with exact evidence in PR13 comment5991050543. Requested real dropdown layout correction, preserve assertions, no exception suppression or viewport-only workaround. Analyzer/build withheld by serial test gate; no new deployment. Existing hosted frontend ed24b0ae and backend80b0c61 remain unchanged.
- Source audit: Save history invokes read-only revision listing, not a mutation, so retaining it in view-only UI is appropriate. New department-answer-owners/mine API requires coordinated backend rollout once the entire head passes; do not deploy frontend alone.
- Private validation logs: review-7296b51-flutter-test.log, review-7296b51-backend-test.log, review-7296b51-isolated-postgres.log. Lesson: completion report is not independent runtime validation; new permission tests can expose pre-existing responsive layout problems. Separate backend PASS from frontend FAIL and do not claim runtime permission flow verified on a head that has not shipped.

### Remaining registered-account collaboration scope check — 2026-10-05
- Continuing the feature audit without repeating anonymous guest coverage: regularuser1 Employee opened Shared guest groups in deployed ed24b0ae. Create group and Join with invitation are disabled; UI states linked accounts can retain approved groups but creation/redemption requires Firebase anonymous guest identity.
- The earlier consolidated handoff's registered-user group create/join enhancement is therefore still pending in the deployed frontend, not passed by the anonymous guest tests. No group created, invite redeemed, identity switched, account permission granted, or new credential needed for this read-only observation. Do not conflate guest collaboration with registered-user acceptance.
- Current immediate implementation blocker remains Copilot dropdown overflow task5991050543; PR13 recheck still7296b51. Keep scope separate rather than interrupting that fix with a duplicate implementation.

### Exact965957c validation and logical viewport diagnosis — 2026-10-05
- Fetched clean exact965957c78207f8f23e81c99fcbdfa5965cadf948. Changes from7296b51 limited to participant dropdown expansion/ellipsis and two narrow widget-test setups. Backend diff empty; prior fresh84-test backend result still applies to identical backend source/tests.
- Full Flutter suite109passed,2failed,57s. Horizontal40px dropdown overflow fixed. New failure is vertical970px/1072px Column overflow at guided_session_page.dart:94:16 in the same new two tests. Harness sets physicalSize360x800 without defining devicePixelRatio, so it does not establish360logical-pixel coverage.
- Temporary diagnostic only: set devicePixelRatio=1 in both tests with addTearDown(resetDevicePixelRatio), retaining physicalSize360x800 and all assertions. Focused two-test suite passes in1second, including takeException==null, permission gates, report and export. Original test restored from private backup, review remains clean exact965957c; no application edit committed/deployed.
- Copilot notified in comment5991226602 to commit the verified narrow harness correction, no viewport enlargement or exception suppression. Analyzer/build/rollout remain withheld until committed exacthead fullsuite passes. Existing hosted frontend ed24b0ae/API80b0c61 unchanged; no cloud or account permission mutation.
- Lesson: physical viewport size is not logical viewport size. Set/reset pixel density explicitly in responsive widget tests, and distinguish test harness failures from application overflow using a reversible focused probe before proposing app changes.

### Workflow reread, green a4ec6c1, and unrelated review rejection — 2026-10-05
- Founder explicitly directed continued unrelated acceptance while Copilot fixes validation issues. Reread canonical consolidated-solution-handoff-2026-10-03.md via GitHub exact f4180b8651ee5ae0182dbe1fb0b78e2486565234 (not present in this local branch), plus current checkpoints. Retain Copilot code/tests vs Codex independent verification, identity/audience/action separation, no guest-flow repetition. Later authorised development rollout supersedes original handoff's no-deploy scope; production, IAM/AppCheck changes, old local database and repository merges remain excluded.
- Copilot committed logical viewport correction a4ec6c1801d05cd584ef543417bd5ca9eb131bc3. Clean exacthead fullFlutter111passed62s; analyze passed9.2s,noerrors/warnings,12existinginfos; releasewebbuild passed51.0s. Backend source/tests identical to7296b51, carrying fresh isolated84-test pass22.59s; no unnecessary database rerun.
- Unrelated live gap tested on existing hosted frontend ed24b0ae/API80b0c61 while validation ran: employee request a synthetic unnecessary question rename201 at09:04:00Z on question7b1e2087-b9a2-48f5-9c98-403203fc1fa6. Admin rejected request9f1d3235-48e0-4e1a-8b28-46853bfff8ab via review endpoint200 at09:05:15Z (ID must be checked against safe log before reuse). Review queue no pending changes; original question title/detail,resolved accepted verified answer,review2027-04-02 and existing discussion1 retained. Proof intqaflow-question-review-rejected-20261005.jpg captured/inspected/nonempty.
- Coordinated development rollout preparation started: backend a4ec6c1 cloud build and no-traffic revision staging in progress. No live traffic or Hosting switch yet at this checkpoint. Rollback backend review80b0c61 and Hosting version3bbec4254fc5fdc1 (ed24b0ae) retained. New mine endpoint must ship before assignment-aware frontend. Runtime env/serviceaccount/CloudSQL/VPC equality and readiness gate before traffic switch.
- Lesson: use independent task time for uncovered acceptance paths; a fix pending upstream does not block unrelated verification. Preserve exact source/deployment attribution and publish stage state before claiming rollout complete.

### 2026-10-05 — a4ec6c1 coordinated development rollout and populated view-only acceptance

- Exact commit: a4ec6c1801d05cd584ef543417bd5ca9eb131bc3. Full Flutter suite: 111 passed; analysis passed (12 existing informational findings); release build passed. Backend source/tests are identical to the independently tested 7296b51 version (84 passed).
- Backend revision intqaflow-dev-api-reviewa4ec6c1 is Ready, receives 100% traffic, and returns health HTTP 200. Service account, environment and Cloud SQL/VPC runtime configuration preservation passed before switching traffic. Hosting release 1791191062153600 / version 6d1293539c97c22c published 36 files. Both Hosting origins served main.dart.js identical to the local release build (4,412,978 bytes). Rollback references remain review80b0c61 and Hosting 3bbec4254fc5fdc1. No production, IAM, App Check, migration or repository merge action.
- Hosted organisation-visible session 231a10a3-76c3-4e77-a186-720c52c3d854 now contains synthetic participant E2E Organisation Participant, one shared question and one saved answer (revision 4). Employee sees the explicit view-only notice and readable question/answer, with no text inputs, Start, participant/question creation, deletion, follow-up or Knowledge proposal controls. Admin owner retains these controls. Draft status preserved.
- Employee revision history opens with revisions 2–4; active-participant report displays the saved question and answer and offers Print / Save PDF. Export control remains present; actual export payload and PDF glyph rendering are not claimed from this check.
- Earlier question-change rejection identifier was independently confirmed from the safe path/status log: 9f1d3235-48e0-4e1a-8b28-46853bfff8ab. Original resolved question, verified answer and discussion remained intact after rejection.
- Remaining affected regression: assignment-aware scoped-owner UI positive/out-of-scope/revocation, plus employee-own-private-session controls. Registered collaboration enhancement and the wider workflow acceptance gaps remain pending; old local database stays excluded.
- Lesson: verify populated read-only content, not only an empty session; preserve history/report access while removing mutations. Refresh accessibility state after input or modal changes before using numeric controls. Independent hosted-byte verification must accompany source/build checks.

### 2026-10-05 — private-owner positive controls and navigation issue sent to Copilot

- Employee-owned private completed session ca40e2aa-916a-4544-a564-99d2f264d2df loads correctly after one reload on a4ec6c1; participant/question creation, editable question/answer fields, deletion, follow-up and Knowledge proposal controls remain present for its owner. Content/status were not changed.
- Direct navigation from the organisation fixture initially remained on a spinner. Safe request evidence showed repeated private-session GET 404 at 09:22:12/16/23/30/36 UTC; one reload recovered. Cause is unconfirmed. Copilot investigation requested in PR13 comment 5991668390, including route/auth/provider transition and terminal-error handling, without broadening private-session access. Continue unrelated checks while investigation runs.
- Lesson: owner-control rendering and successful deep-link reload do not establish reliable live route transitions; retain separate evidence and avoid declaring the full navigation flow passed.

### 2026-10-05 — unrelated template creation/version pinning and read-only export

- Admin created E2E Organisation Handover Template v1 with two shared questions; POST /api/v1/guided/templates returned 201 at 09:30:50 UTC. Starting it created private draft session 7a1288b6-380b-4290-8284-97f39faa472f (POST sessions 201 at 09:31:05 UTC), with default Participant 1 and two prepared questions. No answers or identity grants were copied.
- Save as new version added a third shared question, What is the next synthetic handover action?, while preserving both original questions. POST template versions returned 200 at 09:32:39 UTC. Listing shows v2 with three questions. Reopening the existing v1 session through visible list navigation still shows two questions: version pinning passed. Synthetic template/session retained as acceptance fixtures.
- Employee read-only organisation-session Export > JSON opens a populated export dialog displaying the expected session identifier, revision 4, draft/organisation visibility, synthetic participant/question/answer. This is a dialog/copy workflow, not a browser download. Clipboard contents did not update verifiably through browser instrumentation; do not claim clipboard-copy or parsed export payload acceptance.
- Browser input lesson: accessibility values can appear before Flutter focus/render state settles. Initial template attempt made no API creation request and produced no persisted fixture. Focus each field, observe settled state, enter/replace content, and verify a later screenshot before submitting. This is an automation timing issue, not a confirmed template product defect. rg is unavailable in the Codespace; use git grep as the available repository search fallback.
- Copilot navigation investigation remains separate; visible app Back/list navigation worked for the new admin session. Scoped-owner UI and the previously documented broader workflow gaps remain open.

### 2026-10-05 — template duplicate/archive and recovery gap

- Duplicating synthetic E2E Organisation Handover Template v2 creates E2E Organisation Handover Template copy v1 with the same three questions. Archiving only that copy preserves a visible archived record and removes its start button. Original v2 template and private v1 session remain intact.
- Archived copy menu still offers Save as new version, Duplicate and Archive, with no Restore/Unarchive option. Recovery acceptance remains pending, reported to Copilot in PR13 comment 5991877023 for intended lifecycle review and a narrow fix if required. No permanent deletion performed. Archived synthetic copy retained as audit fixture.
- Copilot acknowledged the separate navigation investigation with an eyes reaction at 09:23:15 UTC. Latest independently checked PR13 head remains a4ec6c1; no new fix has been validated. Do not report acknowledgement as completion.
- Lesson: retained archived data is not equivalent to a user-accessible recovery flow; verify the available restore control independently.

### 2026-10-05 — Copilot follow-up commits under independent validation

- PR13 advanced to exact head 07c17a98f6b309cb6e41ae574a4a7837bd54da09. cd184f0 adds only a mocked session 404/error/retry widget regression; Copilot could not reproduce or confirm the hosted spinner cause and changed no route/auth/access logic. Hosted navigation remains open.
- 07c17a9 adds creator/admin-restricted template restore with a distinct audit action, archived-only conflict guard, and an archived-menu Restore action preserving version/questions and startability. Backend/widget coverage added. Source review confirms tenant lookup and permissions remain explicit.
- Clean detached exact-head worktree checked before launching full Flutter suite, analysis/release build, and full backend tests against a fresh disposable local PostgreSQL cluster. Tests are in progress; deployed development remains a4ec6c1 until independent checks pass and a coordinated backend/frontend rollout is verified. No old local database used.
- Lesson: a mocked 404/retry test is useful regression coverage but is not evidence that an observed hosted route transition was reproduced or fixed. Keep those statuses separate.

### 2026-10-05 — exact 07c17a9 backend pass and Flutter failure returned to Copilot

- Backend independently passed 85 tests in 24.47s with one existing Starlette deprecation warning; fresh disposable PostgreSQL stopped and password file removed. Audit action column is String(80), so the added restore audit value requires no enum/schema migration.
- Full Flutter suite: 112 passed, 1 failed in 69s. Template restore widget regression passed. New session 404/retry regression failed at guided_session_page_test.dart:99:5: expected initial request count 1, actual 3. Mock fails only on its first invocation and then succeeds; initial terminal-error state is not deterministic across provider calls. Copilot comment 5992124422 requests a stable error/manual-retry fixture retaining generic-error/no-data-leak/read-only assertions.
- Check runner correctly stopped before analyze/build on test failure. Independent analyze/build launched separately to continue unrelated checks; no rollout or merge. Development remains validated a4ec6c1. Source review and a test addition do not establish a fix for the hosted navigation issue.

### 2026-10-05 — corrected retry fixture green and hosted scoped-owner UI complete

- Exact head 8e243bfec77807c514cea33d6249e462489bd651 changes only the retry widget fixture: ProviderScope disables automatic retries and the manual recovery assertion accounts for participant-query loading. Independent full Flutter suite: 113 passed in 54s; analysis passed in 5.0s (12 existing informational findings); exact-head release build passed (incremental compile 1.907s). Backend is bit-identical to 07c17a9, retaining independent 85 passed/24.47s. Clean checkout and all three gate markers confirmed.
- Hosted a4ec6c1 assignment-aware UI regression passed with the previously approved temporary Operations-only test scope. With answer_owner role but no assignment, the scoped question has no Verify/Review controls. After assigning only E2E Operations Department, its verified answer offers Review as current and its community answer offers Verify. The department-free question exposes neither governance action. Revoking the assignment while retaining answer_owner role removes governance actions again after identity/provider refresh. No answer text, verification or review date was changed by this UI test.
- Cleanup verified in admin UI: regularuser1@test.com restored to Employee with its existing E2E Operations Department; owner assignment list is empty. No broader role/department/organisation grant remains.
- Coordinated development rollout of 8e243bf prepared using reviewed helpers: backend staged with no traffic first, runtime-configuration/Ready gates before switching, then exact tested Hosting build. Rollback API reference is reviewa4ec6c1; Hosting rollback is version 6d1293539c97c22c. Stage is in progress; hosted template restore is not yet claimed.
- Lesson: provider automatic retries must be controlled in terminal-error widget fixtures; keep full error/no-leak/manual-recovery assertions. Scope UI acceptance includes role-only denial, assigned positive, out-of-scope denial and revoked-assignment denial, then cleanup verification.


### 2026-10-05 10:18 UTC — exact-head rollout and hosted Restore acceptance

- PR13 latest head remains `8e243bfec77807c514cea33d6249e462489bd651`, draft/unmerged. Independent Flutter 113 passed, analyze passed with 12 existing informational findings, exact-head release build passed. Backend is bit-identical to tested 07c17a9: 85 passed.
- Development Cloud Run `intqaflow-dev-api-review8e243bf` Ready, runtime configuration preserved, 100% traffic, health 200. Hosting release sites/intqaflow-dev/releases/1791194729075000, version sites/intqaflow-dev/versions/e77eef5d15d47d0c, 36 files; both origins' main.dart.js hash matches the tested build (4,413,639 bytes). Rollback remains API reviewa4ec6c1 and Hosting 6d1293539c97c22c.
- Hosted admin Restore returned 200 at 10:08:56Z. Synthetic archived copy retained v1 and all three questions; a new private draft session opened with three questions and empty answers. Copy re-archived to baseline at 10:11:29Z. Audit/version retention has automated coverage; hosted audit storage was not separately inspected.
- Non-owner Employee Restore returned 403 at 10:13:35Z and 10:17:45Z; copy remains archived. UI still exposes Restore and no persistent actionable feedback was observed after the menu closes. Reported to Copilot in comment 5992506890 for creator/admin gating and failure feedback; this UI check is OPEN, backend boundary PASS.
- Scoped-owner UI positive, role-without-assignment negative, department-free negative, and revocation checks passed. Regular account is restored to Employee and no answer-owner assignments remain; no answer mutations or wider grants.
- Lessons: settle Flutter transitions and obtain fresh accessibility indexes before selecting a template menu; stale indexes selected the wrong template, which is not evidence of caching failure. Error-state test coverage does not establish a fix for the separately reported hosted navigation spinner.
- Continue independent remaining flows while Copilot addresses the UI defect. Team sharing/privacy, registered guest collaboration, actual CJK/emoji PDF output, export clipboard verification, and hosted navigation root cause remain pending; do not claim full acceptance. Old local database and production remain excluded.

### 2026-10-05 10:21 UTC — employee native JSON clipboard verification

- Completed private Employee session opened through Completed sessions without a spinner. Export > JSON > Copy placed valid 2,261-character JSON on the browser clipboard. Parsed kind `intqaflow-guided-session`, version 1, completed/private state, expected synthetic title, one participant, one prepared question and one nonempty nested answer. Question text matches the fixture. Clipboard export verification is now PASS; no downloaded-file claim.
- Lesson: native session answers are nested under questions in this export format; validate the actual schema rather than assuming top-level answers. Session content was not modified. Other pending checks in the preceding checkpoint remain open.

### 2026-10-05 10:34 UTC — Copilot ownership UI fix under independent review

- Copilot pushed `bd0ae0557438ee4698608a2ac8d2deb0da7cda8f` (Gate template mutations by ownership). Reviewed model parsing of existing created_by, membership creator/admin gate, and friendly persistent failure SnackBar. Backend unchanged relative to 8e243bf; existing independent 85-pass backend result carries forward.
- Exact clean head checked out in isolated review worktree. Full Flutter tests, analyze and exact-head release build running; no new rollout or hosted UI pass claimed yet. Added widget coverage includes non-owner denial, creator/admin actions and failed Restore. Deployed development remains 8e243bf pending all gates.


### 2026-10-05 10:38 UTC — template authority fix independently verified and deployed

- Exact bd0ae0557438ee4698608a2ac8d2deb0da7cda8f: full Flutter 115 passed/57s, analyze passed/5.9s (12 existing infos), release build passed/50.5s; diff check clean. Backend unchanged, prior full 85-pass result retained.
- Frontend-only development release sites/intqaflow-dev/releases/1791196604987000, version sites/intqaflow-dev/versions/31e9a528a9ab376a, 36 files. Both origins independently match the exact tested bundle (4,414,296 bytes). Cloud Run remains validated review8e243bf; no backend/security/database change. Hosting rollback version e77eef5d15d47d0c.
- Hosted Employee sees active admin-created original and archived copy without mutation menus; own General Interaction QA menu remains. Admin archived-copy menu still offers Restore. Copy remains archived; no account/fixture mutation. New hosted authority check PASS. Persistent failure SnackBar verified by full widget suite, not by injecting a hosted outage.
- Saved screenshot of non-owner template list. Existing route reload to root and separately observed session-navigation spinner remain unresolved; successful completed-session reload here does not close those findings. Remaining broader acceptance checks unchanged.

### 2026-10-05 10:57 UTC — founder approves Shared groups and registered collaboration

- Founder accepts independent shared groups, linked guest-to-registered identity continuity, optional organisation membership, and user-facing rename from Guest groups to Shared groups. Verified registered users should be able to create/join groups alongside anonymous guests, subject to existing invitation and individual approval rules.
- Copilot handoff 5993071761 requests implementation/tests from bd0ae05. Preserve UID/memberships/group-admin role on linking; separate-account creation does not transfer membership. Organisation enrollment/admin promotion must not convert groups to teams or expose group data to organisation admins. No automatic guest-member organisation enrollment. Current implementation blocks registered create/join and permits one organisation per account; these facts are not yet reported fixed.
- Pending acceptance includes guest creator -> linked registered account -> organisation Employee -> organisation Admin with original group continuity, verified registered invitation join/pending approval, and organisation/group access independence. Founder authorization covers implementation and testing; any concrete new security-sensitive role grant remains subject to action-time confirmation. No current approval pending or account grant active.
- Continue unrelated remaining checks while Copilot works. Old local database and production remain excluded; no merges, security-mode changes or destructive database work.

### 2026-10-05 11:01 UTC — registered CSV clipboard acceptance

- Employee completed private session Export > CSV > Copy passes: 259 characters, header plus one data row, expected session question, participant and complete answer present. Header session_title,participant,scope,type,depth,question,answer,returns_to. Export dialog closed; session unmodified.
- This is basic native clipboard/content acceptance, not spreadsheet-formula safety or a downloaded-file claim. IQ08 escaping remains separately pending. Shared-group implementation handoff remains queued/under Copilot work; no new implementation head independently checked yet.

### 2026-10-05 11:04 UTC — IQ08 current-service reproduction

- Actual bd0ae05 GuidedService.export_csv invoked with in-memory synthetic get_session result: parsed cells retain raw =1+1 title, +1+1 participant, @SUM(1,1) question and -1+1 answer. CSV formula safety FAIL confirmed; no database/network used, no hosted fixture changed. Copilot queued sequential fix after shared-group scope in comment 5993136447. Require spreadsheet-safe policy across user-controlled cells, control-whitespace cases, quoting/newlines/nesting and faithful JSON.
- Lesson: review worktree has no backend .venv; use existing /workspaces/intqaflow/backend/.venv interpreter with review backend as cwd to execute exact reviewed source. First nonexistent-interpreter attempt did not execute a test. Basic browser CSV export remains PASS independently of this safety failure.

### 2026-10-05 11:17 UTC — previously uncovered admin canonical merge/unmerge

- Read checkpoint first; selected canonical merge/unmerge because browser acceptance was uncovered. Did not repeat passed account/template/export/governance checks.
- Empty archived synthetic duplicate e700114c-05a4-4bba-84d9-9b999cab85e6 compared with existing resolved canonical 7b1e2087-b9a2-48f5-9c98-403203fc1fa6. Merge into existing confirmation states original questions/history preserved. Merge POST /questions/7b1e2087-b9a2-48f5-9c98-403203fc1fa6/merge returned 200 at 11:15:07Z. Alias UI showed linked answer, View current answer and Unmerge.
- View current answer opened the correct canonical: accepted answer unchanged, verified by admin, review 2027-04-02 and Discussion (1), with Also asked as alias visible. This focused preservation check is necessary after merge, not repetition of general answer acceptance.
- Unmerge POST /questions/e700114c-05a4-4bba-84d9-9b999cab85e6/unmerge returned 200 at 11:16:09Z. Duplicate returned to archived/unlinked Possible duplicates state and Discussion (0). Baseline retained; no restore/rearchive required. Saved merged and unmerged screenshots. Admin canonical merge/unmerge UI PASS; no direct hosted audit-storage claim.
- Initial attempted Restore dialog produced no request or state change; not counted as a pass or product defect. Merge accepts the archived empty fixture, so restoration was unnecessary. Initial question loading recovered after one reload/visible Questions navigation; no root-cause fix inferred.
- Existing passed checks remain closed. Shared-group/CSV changes await independent validation; broader privacy, identity-continuity and operational items remain pending.

### 2026-10-05 11:24 UTC — new shared-group/CSV head validation blocked by two tests

- Exact reviewed head 07c1bc938af4cee601666e44ef76ce5eb8646d64 incorporates shared-group identity scope and CSV safety. New eligibility uses verified Firebase email claim for non-anonymous create/join; existing UID memberships and org boundaries retained. CSV user cells receive apostrophe for formula/control-prefixed text; JSON fidelity covered.
- Independent full backend: 86 passed, 1 failed/19.92s, one existing deprecation warning. Fresh disposable PostgreSQL stopped/password removed. test_guest_groups.py:85 expects linked unprovisioned /auth/me401 but global app_client override returns synthetic Employee200. Source confirms bypass in fixture; not evidence of hosted authorization expansion. Copilot comment5993413435 requests real boundary validation without weakening assertion.
- Independent full Flutter: 117 passed, 1 failed/67s. account_state_widget_test.dart:405 expects old Guest-group roles sentence after Shared groups rename. Copilot comment5993437347 requests updated wording with role-independence assertions retained.
- Set-e runner stopped before analyze/build as required; separate independent analyze/build running, no rollout. Development remains frontend bd0ae05/backend review8e243bf. Required repeats are limited to regressions affected by new identity/CSV code. Previously passed unrelated flows stay closed.

- 11:25 UTC follow-up: separate exact07c1bc9 analyze and release build both PASS. Both test failures still block rollout; no job remains running.

### 2026-10-05 11:28 UTC — exact corrected identity head under validation

- Copilot current head 0f87f47c9ccbd1c2826938e7feed6780f4a15156. Reviewed diff from 07c1bc9: test-only auth override removal/restoration in finally with401 assertion retained, and updated Shared-group wording assertion. Application unchanged from reviewed shared-group/CSV implementation.
- Exact clean head isolated full Flutter/analyze/build and backend suite running; disposable PostgreSQL only. Rollout helpers prepared with previous API review8e243bf rollback, not executed. No passed unrelated browser flow repeated. Hosted identity continuity and registered join checks will follow green gates and development rollout.

### 2026-10-05 11:31 UTC — corrected head all independent gates green

- Exact clean0f87f47c9ccbd1c2826938e7feed6780f4a15156: backend87 passed/18.56s, one existing deprecation warning, fresh disposable PostgreSQL stopped/password removed; Flutter118 passed/60s; analyzePASS; exact-head release buildPASS1.299s incremental. Both prior failing assertions corrected without production permission changes. Copilot notified5993545149.
- Development backend staging started with no traffic; readiness/config preservation gates before switch. Deployed state remains frontendbd0ae05/backendreview8e243bf until actual completion evidence. Rollback APIreview8e243bf and Hosting3a19ea528a9ab376a. Hosted Shared groups and CSV safety acceptance pending, no full acceptance claim.


### 2026-10-05 11:51 UTC — deployment complete and registered shared-group acceptance

- Exact0f87f47 deployed: API intqaflow-dev-api-review0f87f47 Ready/config preserved/100% traffic/health200. Hosting release1791199919218000/version331eb642df81e56c,36 files. Both origins match exact tested4415003-byte bundle. Earlier staging state superseded. Rollback review8e243bf / Hosting3a19ea528a9ab376a. Backend87, Flutter118, analyze/build passed.
- Registered Employee created E2E Registered Shared Group a12cb842-a072-4cd8-b6a4-cb8fbefc9171 as groupadmin (POST201). Organisation Admin had no automatic group access; invited as viewer, join200 at11:39:36.112623Z created pending membership, owner approval200 at11:43:08.272558Z. Viewer UI disables Add Knowledge, Preview/share and Invite despite orgAdmin role. Registered create/join/approval and UI role independence PASS.
- CORRECTION: comment5993725444 misread screenshot join200 as400; fresh membership view showed pending. Retracted5993806116. Lesson: reconcile timestamped sanitized log and settled member view before classifying a failure. No actual join400 evidence.
- Invitation revoked/active invitation list empty. Remove member twice blanks owner page with no removal POST; reload recovers Knowledge root and viewer remains active. Second attempt used screenshot-grounded visible menu action. Report5993845396 requests navigation/dialog lifecycle regression. Viewer remains in empty synthetic group; removal cleanup NOT passed. No organisation grants changed.
- New test-only a67a2461d054af5406ac553ca8a0890868723507 independently backend87 passed/12.54s, one existing warning, fresh PostgreSQL stopped/password removed. Guard400 does not consume invitation; legitimate join still pending. No application changes/new deployment needed.
- Previously passed unrelated checks remain closed. Linked-account identity journey, no-org registered browser acceptance, hosted dangerous CSV cells and broader privacy/operational checks remain pending. Production/old local database excluded.


### 2026-10-05 12:11 UTC — hosted CSV safety and operational audit

- Deployed0f87f47 Employee private fixture69d4afaf-5f1c-4459-a3b4-77da6deafa91: =title,+participant,@question,-answer with comma/quotes. Native CSV Copy203chars, parsed2rows/8columns; all4 risky text cells prefixed apostrophe, comma/quoted text preserved. JSON backup retains original values. Hosted formula neutralization/fidelity PASS, not spreadsheet execution or full hosted control-character matrix. Private draft retained; no Knowledge publication.
- Operational sourcea67a246: /health static status/environment and liveness test only; no tracked GitHub workflow/backend lock, dependency ranges. Recovery doc requires restore/PITR procedure but no rehearsal evidence inspected. Readiness/reproducibility/CI/recovery remain OPEN.
- GuidedKnowledgeService.decide invokes QuestionService.create which commits before answer creation/final proposal audit. Source atomicity concern, not reproduced hosted outage. Copilot5994126124 requests disposable failure test and transaction fix if failure, plus scoped operational improvements. No live DB/provider fault injection or IAM/schema changes.
- Copilot stilla67a246; member removal cleanup pending. Previously passed unrelated checks remain closed.
- Lesson: parse CSV before asserting quote integrity; JSON original-value fidelity is separate. Historical checklist is dated baseline; current checkpoint supersedes old pending/fail labels.


### 2026-10-05 12:28 UTC — Copilot trigger correction and IQ07 independently reproduced

- Latest PR13 head stilla67a246, no member-removal completion reply. Prior task comments5993845396/5994126124 lacked explicit mention; sent @copilot action request5994399042. Lesson: an issue comment alone does not prove agent receipt/activity; explicitly trigger and inspect acknowledgement/new commit.
- Exacta67a246 independent disposable in-memory SQLite ASGI/fake-embedding observation: seed synthetic Employee/admin, create proposal, inject RuntimeError in AnswerService.create during accept. Fresh DB session after failure shows matching Knowledge question count1, proposal pending, created_question_idNone. Restore method/retry same proposal200; matching question count2. Probe1passed/1.77s is successful DEFECT REPRODUCTION, not atomicity acceptance. Hosted DB/provider untouched; fixture engine disposed.
- Confirmed partial publication/duplicate retry IQ07 blocker. Copilot5994427545 receives exact reproduction; acceptance regression must assert zero partial publication and one question on retry, retaining standalone create and embedding fallback. Reproducible historical probe saved under docs/operations/review-probes/proposal_atomicity_observation.py, invoked explicitly; not auto suite.
- Member removal and operational improvements pending; hosted CSV formula gate remains closed/pass. No repeat of previously passed unrelated flow.


### 2026-10-05 12:37 UTC — linked guest account continuity precondition ready

- Signed out Employee on firebaseapp origin; admin web.app session retained. Enabled anonymous shared-group identity and created E2E Linked Account Continuity with E2E Linking Guest Owner. Settled hosted UI shows groupadmin with manage/invite/add controls. Empty synthetic fixture is the precondition for previously untested guest-to-linked-registered/no-org journey, not a repeat acceptance run. Pre-link ownership proof intqaflow-linking-guest-group-20261005.jpg.
- Selected Account > Create account from this guest (not separate account). Manual signup handoff required by browserAuth rule: do not use browserAuth to create accounts, offer manual handoff. New email/password must be entered by user in browser, never chat. Group preservation/no-org registered use and verification remain pending until signup; no org grants changed.
- Input lesson: AX/semantic fill value can precede actual Flutter controller/rendered content. Separate focus/native input calls and verify settled visible form before submit. Initial empty-controller submission sent no observed create request and is not product failure; eventual hosted groupadmin view proves creation.


### 2026-10-05 12:47 UTC — reconcile prior guesttester1 linking evidence; cancel duplicate signup

- User correctly recalled guesttester1@test.com prior guest test. Historical commits9eaa93a (continuation-checkpoint-2026-10-03.md) and6d89698 prove founder submitted Link guest recovery; explicit reload showed signed-in guesttester1/no organisation, local Knowledge/both Interact sessions/reusable template accessible.9eaa93a explicitly says Do not repeat signup/linking.6d89698 additionally records authoritative manual verification and signout/signin/local preservation. Normal verification-mail delivery remains deferred.
- Supersedes current checkpoint implication that linked signup/no-org local use is wholly untested. Reuse historical passes; new signup handoff cancelled, no additional account created. E2E Linked Account Continuity fixture remains anonymous owner/empty and retained, not migrated.
- Historical record explicitly did NOT establish complete group-boundary acceptance; remaining narrow gap is original group membership/admin continuity after linking, followed by org enrolment/role independence. Use existing guesttester1 for targeted checks when secure signin needed; do not repeat common guest sessions/templates/signup.
- Lesson: search git history as well as current tracked docs before proposing repeat; older checkpoints may not appear in current branch. Distinguish linked local continuity proof from shared-group server membership proof.


### 2026-10-05 12:55 UTC — full history reconciliation and new Copilot head

- All-history searches for guesttester1, Guest acceptance group, group continuity and org assignment locate9eaa93a/6d89698 linked local/no-org passes and9032f23 later new-anonymous group selective sharing. No exact original-group after-link or guesttester1 organisation assignment completion found. Mark UNCERTAIN rather than imply no work ever happened; user permits narrow retest if inconclusive. Existing regularuser1 enrolment/assignment remains passed and distinct.
- Added user-flow-acceptance-index.md as required starting point; actor/fixture/status/evidence/retest reasons and workflow prevent chronological checkpoint gaps. No new signup required.
- Copilotdaadc665b0d59174e4e915bf5e2d0bff0dfcdfb2 contains removal dialog navigation fix, transaction coordination and stronger rollback/retry assertions, separate DB readiness, pinned lock/CI, recovery runbook. Independent full backend90 passed/11.92s, existing warning, fresh PostgreSQL stopped/password removed. Flutter/analyze/build and clean-lock/lint/compile running. Reviewed outer commit/rollback and preserved standalone creates. GitHub CI action_required/zero jobs per Copilot, not CI success. Development still0f87f47; no rollout yet.

### Locked deployment staging and packaging lesson — 5 October 2026
Independent daadc66 gates: backend 90, Flutter 119, analyze/build and clean lock install passed. First temporary Cloud Build context failed because .dockerignore admitted requirements.txt but excluded requirements.lock; no traffic changed. Updated both temporary Dockerfile and ignore allowlist to requirements.lock and restarted no-traffic staging. Lesson: when switching a deployment to a lock file, update COPY, pip install and context allowlist together. Keep hosting and traffic switch gated on successful staging, preserved runtime configuration and readiness. Prior running API remains review0f87f47 until a verified switch.

### Development rollout verified — 5 October 2026
daadc66 deployed: Cloud Run intqaflow-dev-api-reviewdaadc66 Ready, runtime configuration preserved, 100% traffic, /health and database-backed /ready both 200. Hosting release 1791205666163000, version d283dab943f1089c, 36 files. Both Hosting origins main.dart.js hash-match the exact validated build. Rollback targets: API review0f87f47; Hosting version 331eb642df81e56c. Hosted member removal and normal proposal approval still require targeted UI acceptance; do not mark them passed from deployment alone. Historical guesttester1 linking/local continuity and CSV remain reused. No new account created.

### Existing-owner authentication blocker — 5 October 2026, 13:30 UTC
Hosted removal regression remains BLOCKED, not failed or passed: regularuser1@test.com login received Firebase auth/invalid-credential after the intended Switch account confirmation, including the founder manual retry. No member removal request was made. Admin session remains available; updated app loads and Review has no pending Interact proposals. Do not repeat signup, reset credentials automatically, or infer successful authentication from the switch confirmation. Resume owner-only removal and fresh approval fixture after verified existing-owner sign-in.

### Read-only Firebase diagnosis — 5 October 2026, 14:05 UTC
Founder reports another invalid-credential after Switch account. Confirmed visible auth/invalid-credential. Read-only development Firebase accounts:lookup confirms regularuser1@test.com and guesttester1@test.com both exist, enabled, email verified, password provider configured. No credentials read or changed. Reviewed sign_in_page: anonymous switch dialog only asks confirmation, then calls normal signInWithEmailAndPassword with trimmed email and password controller; no account recreation or password mutation. This excludes missing/disabled/password-provider account as the observed blocker; it does not prove entered password validity or exclude input synchronization issues. Do not repeat failed attempts in a loop. Existing-owner hosted checks remain blocked pending successful sign-in or founder-operated password recovery.

### Account UX review and scope decision — 5 October 2026, 15:12 UTC
Reviewed Copilot head dfb17ad04bec93d32f37a1e27dac686de82a1bbb (new changes limited to Flutter auth/workspace, widget tests, architecture, checkpoint and retention docs). Founder confirms keep browser-local guest drafts and shared browser-profile session; provide a notice distinct from online Shared groups. No backend draft migration or multiple guest-profile UI. Extension/Teams/plugin implementation remains deferred until core feature/function acceptance is complete. Default account creation links current guest UID; explicit start fresh creates a separate account; organization membership stays optional. Source captures credentials before async confirmation but hosted invalid-credential cause remains unresolved. Source now blocks leaving a sole-admin guest group or unverifiable ownership. Immediate admin transfer exists; recipient acceptance and recoverable group closure remain NOT IMPLEMENTED, tracked as pending product work. Our disposable anonymous fixture owns an empty group, so this guard can block owner-account sign-in after deployment; do not pretend that is fixed by wording or repeatedly ask founder to log in. Resolve the fixture/group lifecycle deliberately before resuming owner-only removal. Backend unchanged from 90-pass daadc66; reuse that evidence. Independent exact-head Flutter tests/analyze/build running; no new deployment yet.

### Independent UX regression result — 5 October 2026
Exact dfb17ad full Flutter suite: 126 passed, 1 failed in 48 seconds. New test shared guest account creation defaults to same-UID linking fails at account_state_widget_test.dart:397 because a broad text finder matches both heading and action label (2 versus expected 1). This is a test ambiguity, not evidence linking failed. Sent precise fix request to @copilot comment 5997334521. Analyzer/build running separately for additional compile evidence; deployment blocked until meaningful corrected test passes. Lifecycle proposal requested in comment 5997297812; accepted transfer/group closure remain pending. Do not repeat signup or credential retries while reviewing these changes.

### Analyzer follow-up — 5 October 2026
Exact dfb17ad analyzer exits 1: new warnings sign_in_page.dart:182 dead_code/dead_null_aware_expression because FirebaseOptions.projectId is non-null; test account_state_widget_test.dart:80 unused signInError fake parameter. Sent to @copilot comment 5997362220. Existing info-level lints are separate. Build still pending at this observation. No deployment until corrected test/analyzer gates pass.

Exact dfb17ad release web build completed successfully in 53.4 seconds. Validation summary: 126 Flutter passes / 1 ambiguous test failure; analyzer blocked on three new warnings; backend unchanged and prior 90 passes reused. No deployment. Resume with Copilot fix review and affected automated tests before hosted account regression.

### Linked feature backlog — 5 October 2026
See [feature/function backlog](feature-implementation-backlog.md), F01–F20, for implementation status, priorities, acceptance criteria and task links. Update it with this index/checkpoint. Current deployed head remains daadc66; review head f1eadad. Affected account tests 29 passed / 1 new finder ambiguity; original default-link test passes. Fix request 5997983931 sent; no deployment. Accepted transfer/archive proposal needs recovery authority/window decision. Extension/plugins remain deferred until core acceptance.

### Recovery policy and validation update — 5 October 2026
Founder selected 30-day archive recovery, same-account existing group-admin authority. No ownership/recovery transfer to a fresh UID. No automatic purge authorized; archive excluded from existing cleanup until reviewed retention implementation. Accepted transfer/archive source implementation assigned to Copilot 5998051498; authored migration/disposable DB tests permitted, hosted migration and cleanup not performed. Exact f1eadad analyzer now passes with 13 info-level lints and no warnings/errors; web release build passes in 45.8s. Affected account test 29 pass / 1 erroneous secret-finder failure remains; no deployment.
Lesson: password-disclosure assertions must inspect rendered error Text separately from intentionally retained obscured EditableText input; inspect obscureText explicitly. Do not mistake test finder scope for a product leak.

### Corrected account gates and operations evidence — 5 October 2026
Exact 52f3b1e account-suite, analyzer and release web build gates passed. Latest change only fixes test finder; reuse unchanged backend 90-pass and prior unaffected Flutter evidence. No hosted rollout yet: accepted transfer/archive still pending task 5998051498, and sole-admin anonymous test fixture would block departure without supported lifecycle. Read-only development Cloud SQL metadata: intqaflow-dev-pg, PostgreSQL16, europe-west2, backups enabled with retainedBackups=7, PITR disabled; latest three returned automated backups SUCCESSFUL. No restore/rehearsal performed. Scheduler europe-west2 inventory unavailable, so no claim of zero jobs or automated cleanup. F17 metadata prerequisite completed; restore evidence remains pending.

### Full lifecycle independent review — 5 October 2026
Exact 05092fb reviewed independently. Backend full suite 94 passed in 26.38s; Flutter full suite 128 passed / 3 failed in 61s (recipient transfer notice absent; two existing dismissed-entry PDF/history tests tap an offscreen row then fail). Requests 5998788154 and 5998865716 sent to Copilot. Analyzer passed with 14 info-level lints, no warnings/errors; release web build passed in 50.9s. Disposable PostgreSQL full Alembic base to 0011 to 0012, downgrade0011/re-upgrade0012 passed with legacy group/admin preserved and one-pending-transfer index enforced. Twelve races passed: duplicate acceptance, remove/accept, archive/accept, duplicate proposals (three each). Additional deterministic same-UID invitation-list versus group-list probe reproduced SQLSTATE40P01 deadlock: group TTL autoflush lock then read-rate row versus read-rate row then group. This is a DEFECT REPRODUCED, not acceptance. Different-action invite-create/archive probe did not reproduce; discarded that hypothesis. All disposable instances stopped and random password files removed by runner. No hosted migration/deployment/cleanup. F04/F05 now implemented but unverified, not still absent; hosted regression and last-admin fixture remain pending. Reproduction script retained under docs/operations/review-probes.
Lessons: SQLite cannot prove PostgreSQL locking; exercise cross-endpoint lock order as well as obvious lifecycle races. Widget actor replacement must not accidentally retain prior actor state; scroll targets into view before taps. Keep probe/harness failure separate from product defect.


### Superseding Flutter validation — 5 October 2026

Exact PR13 head `c9efbd63260653ce66f56ffaa565a3529a11c7ca` changes only Flutter test setup: fresh recipient ProviderScope and scrolling entries before taps, without weakening acceptance/dismissal assertions. Independent full Flutter suite: **132 passed, 49s**; analyzer and release web build passed. The previous 128-pass/3-failure result applies to 05092fb and is superseded for these tests. Backend source is unchanged: independent 94-test PostgreSQL pass, migration round-trip and 12 lifecycle race passes remain applicable; no unnecessary backend rerun. Ruff E4/E7/E9/F821, compileall and diff checks passed. F21 PostgreSQL read-lock inversion remains BLOCKED and assigned to Copilot comment 5998865716; this test-only commit does not fix it. Hosted lifecycle/registration acceptance, member removal, original guesttester group continuity and organisation assignment remain pending; no deployment or hosted migration.

Lesson/workflow: separate actor fixtures must receive fresh widget state; ensure scroll targets are visible. Run background Flutter processes with detached stdin to avoid raw-terminal interference; a fresh terminal safely recovered access to completed logs. Preserve exact-head evidence and distinguish automated verification from hosted acceptance.


### Copilot lock-order fix awaiting independent validation — 5 October 2026, 18:28 London

PR13 now has exact head `02bf074130ed7e39e8a17d3cd4c9af00f61a6008` (Fix guest lock ordering and account transition coverage). Source review confirms affected read/search/export/member operations acquire rate-limit rows before reading/locking groups. A deterministic PostgreSQL regression and app-level auth UID-transition widget test were added. Copilot reports 93 backend passes/2 skips and a separate PostgreSQL regression pass; these are author results, not independent acceptance. F21 remains blocked pending independent fresh-PostgreSQL regression and affected suite validation. Previous independent c9efbd6 Flutter 132-pass/analyze/build evidence remains historical, not evidence that the new widget test compiles or passes.

The browser reconnected to the same Codespace with a new profile. VS Code Restricted Mode displays “Creating a terminal process requires executing code” and requires “Trust Folder & Continue”. No trust setting was changed. Independent execution is paused for explicit founder confirmation of trusting `/workspaces/intqaflow` in this development Codespace. The docs update uses the existing GitHub connector and does not depend on that terminal. No deployment, hosted migration, IAM/App Check change, cleanup or credential action occurred.

Next: fetch and pin 02bf074 in the clean review worktree; review the exact delta; run backend tests and the new lock-order test against disposable PostgreSQL with a compatible async driver URL; run the new auth-transition Flutter test and analysis. Do not rerun unchanged migration/schema checks or earlier passed hosted flows. The original deterministic deadlock reproducer asserts the old defect; adapt the scheduling/expectation for fixed lock order rather than claiming a failing defect-expectation harness means the fix failed. Continue hosted acceptance only after independent gates and reviewed development rollout.

Lesson: browser profile reconnection can reset VS Code trust and tab handles; restore known tab identity from observed state and record the environmental blocker separately from product failures. Never mark author-reported tests as independently verified.


### Independent lock fix and account-transition gate — 5 October 2026, 18:45 London

Founder explicitly approved the IntQAFlow folder trust prompt; trusted folder and terminal access restored. Exact 02bf074: full backend **95 passed, no skips, 1 existing deprecation warning, 21.86s** on fresh PostgreSQL16; includes the deterministic same-UID invitation/group listing lock-order regression. Runner exit0; isolated server stopped and random password removed. Ruff E4/E7/E9/F821, compileall and diff checks passed. Full Flutter **132 passed / 1 failed (~61s)**: the new app-level auth UID-transition test lacked User.email and threw before transition assertions. Whole-app analysis passed (14 infos, no warnings/errors, 12.8s); release web build passed (4.2s, cached unchanged application source). Copilot notified 5999972471.

Copilot test-fixture-only 18f4aa4 added the missing email getter. Exact affected guest_group_dialog_test.dart suite: **10 passed / 1 failed (~4s)**. The test now reaches :782/:783 and finds no recipient administration-acceptance notice after changing auth UID, although the initial requester notice passes. This remains unclassified between auth-stream test synchronization and actual app/router state retention; task 6000049490 requests investigation with recipient/acceptedByUid assertions preserved. The shared GoRouter is read above the UID-keyed ProviderScope; review whether Navigator state survives account changes. F21 lock-order defect is independently Verified in the stated PostgreSQL scope; the separate account-transition gate remains BLOCKED. Hosted F01/F04/F05/F06/F08/F09 acceptance is not inferred from automated tests.

No deployment, hosted migration, cleanup, credential change or IAM/App Check change. Development remains deployed daadc66 with database revision0011; lifecycle source needs reviewed additive0012 migration before deployment. No repeat of unchanged migration round-trip, 12 prior lifecycle races or passed hosted flows. 18f4aa4 changes only the fake; backend and app build evidence above remain applicable to unchanged production source. Targeted rerun replaced another unnecessary full-suite rerun.

Lessons/workflow: real-app test doubles must implement getters used during transient loading screens. Once those setup errors are fixed, evaluate the real assertion independently; do not assume the original fixture diagnosis explains later failure. A private diagnostic runner had a quoting SyntaxError before creating a probe file or running Flutter; discarded when actual Copilot fix arrived, not product evidence. Detached test jobs use setsid and closed stdin to prevent Flutter raw-input side effects. Record skipped/author tests separately from independently executed PostgreSQL tests.


### Routed account state fix — 5 October 2026

Exact 5cdcd92421d18859ab0ba9059184a01381b18b11 scopes production GoRouter instances to authenticated Firebase UID via an autoDispose provider family, watched by the registered account app. Previous shared-router ownership was the issue under investigation. Regression now asserts distinct owner/recipient routers, new recipient notice and acceptance performed as recipient UID. Independent full Flutter **133 passed, 52s**. Backend source unchanged: retain 95 PostgreSQL passes including lock-order regression. Release gate remains blocked by analyzer **14 infos + 1 warning**: guest_group_dialog_test.dart:36:10 unused_element_parameter testEmail, introduced by the fake correction. Sent Copilot 6000144886; no warning suppression authorized. Release build executing separately, not yet claimed passed. No hosted migration/deployment. Rollout source context and manifest privately prepared for candidate5cdcd92: additive schema0011→0012, API stage without traffic, runtime-config preservation, readiness checks, then API/Hosting rollout and only missing hosted acceptance. Rollback uses known-good API reviewdaadc66 and Hosting versiond283dab943f1089c, with additive schema retained; no automatic downgrade or data deletion.

F22 routed account-state isolation is implemented and automated runtime verified; hosted actor-change/cache/privacy acceptance remains pending. F01/F04/F05 and hosted account/group checks remain pending. Lesson: a getter correction can expose a real state-lifetime failure; preserve assertions and fix production ownership. A full suite is warranted when app/router source changes, while a test-only lint correction should use the affected suite and analyzer and retain unchanged backend/build evidence.


### Final validated rollout candidate — 5 October 2026

Candidate **1b73ee66d1785b40f30d228776d30a596f74653d** removes only unused fake-email configurability. Exact affected suite **11 passed (3s)**, including actual owner→recipient UID transition and recipient-UID acceptance; whole-app analyzer **14 infos, no warnings/errors (3.7s)**; diff check passed. Retain the independent **133-test full Flutter pass (52s)** and **release web build pass (44.3s)** at 5cdcd92: git diff verifies backend/lib/web/pubspec and lockfile production sources are identical at candidate1b73ee6. Backend **95 PostgreSQL passes/no skips** at unchanged02bf074, including deterministic no-deadlock regression. F21 automated lock-order blocker and the routed account-transition/analyzer gates are cleared. Hosted F01/F04/F05/F06/F08/F09/F22 remain pending; not all E2E is complete.

Immutable web artifact and private backend context prepared; candidate manifest records built-from source, production-source equality and bundle SHA256. No hosted migration/deployment occurred. Concrete next rollout: confirm current development backup/schema, apply reviewed additive migration0011→0012 to intqaflow-dev-pg, stage candidate API without traffic preserving configuration, check health/readiness, switch development API and publish the exact tested web artifact. Known-good application rollback: API reviewdaadc66 and Hosting versiond283dab943f1089c; keep additive schema on rollback, with no automatic downgrade/data loss. Request founder review/approval for this shared development schema rollout before executing it; prior approval in this turn was folder trust.

Lessons: standalone recipient UI pass alone did not establish account-change state isolation. Production router lifetime must follow Firebase UID; keep same-UID continuity and supported session deep-link behavior, and preserve backend authorization. A test-only follow-up uses affected runtime tests plus whole-app analyzer; unchanged backend/full-suite/build evidence is retained with explicit exact-head provenance. No fixture secrets, hosted credentials or production data used.


### Approved development rollout in progress — 5 October 2026, 19:20 London

Founder explicitly approved migration0012 and candidate `1b73ee66d1785b40f30d228776d30a596f74653d` development rollout. Latest read-only Cloud SQL backup prerequisite: backup1791165600000 SUCCESSFUL at 2026-10-05T03:55:48.777Z. Live preflight confirmed schema0011 and **3** groups (the spoken 39-group count was a screenshot misread and corrected). Initial runtime-account upgrade stopped at its first ALTER with “must be owner”; no successful schema change. Located existing private dedicated intqaflow_migrator operator credentials without displaying values or changing passwords/permissions. Reviewed Alembic upgrade0012 then succeeded; independent live readback schema0012 and group count3 unchanged. Loopback proxy stopped. API/web remain reviewdaadc66/versiond283dab943f1089c until successful staging and verified traffic/Hosting switch. Candidate staging is in progress; no hosted lifecycle acceptance claimed.

Lesson/workflow: use the dedicated schema migrator, not the runtime role, for DDL. Query schema and aggregate fixture preservation before/after; record unsuccessful commands separately from completed migration. Preserve least-privilege runtime credentials, App Check, IAM and the existing browser/local-work boundaries. Remaining hosted F01/F04/F05/F06/F08/F09/F22 tests stay pending, unchanged passed guest flows stay reused; no old local database, restore, purge or account recreation.


### Candidate1b73ee6 development rollout verified — 5 October 2026, 19:27 London

Reviewed candidate `1b73ee66d1785b40f30d228776d30a596f74653d` deployed after founder approval. Cloud SQL schema0012 verified, 3 groups preserved; dedicated migrator used. Runtime SELECT/INSERT/UPDATE/DELETE privilege checks for guest_group_admin_transfers all true under existing default grants; no grants/password changes made. Backend build passed, revision intqaflow-dev-api-review1b73ee6 staged with no traffic, Ready condition and runtime env/service-account/CloudSQL/VPC annotation equality passed. Traffic switched to 100%; /health200 and database-backed /ready200 verified. Hosting release1791224244338000, versionaf10c243f0df9ef8, 36 files; both development origins main.dart.js SHA256 equal immutable reviewed build (4,431,252 bytes). Rollback application targets remain reviewdaadc66 and Hostingd283dab943f1089c; retain additive schema0012.

Live root opens guest workspace in the reconnected browser profile. Shared-browser profile/local-work/explicit online-sharing notice visually and semantically verified (F02 notice scope); this new profile has no historical signed-in identity, so it is not guesttester1 continuity evidence. Local-only guest Create account opens separate-registered-identity explanation; no account created and no linked-guest signup acceptance claimed. Existing-account sign-in form prepared for regularuser1@test.com. F01 linked registration, F04 accepted transfer, F05 archive/restore, F06 owner-only hosted member removal, F08 original guesttester continuity, F09 org/department/team assignment and F22 hosted UID-state isolation remain pending. Resume missing scenarios only after successful authenticated identity readback; no repeat of passed guest/common flows.

PR13 head rechecked unchanged1b73ee6, draft/unmerged. Publisher succeeded but verification harness initially expected HOSTING_RELEASE_OK whereas existing publisher prints HOSTING_RELEASE; corrected only the observation predicate, then verified both live hashes without republishing. Lesson: distinguish publisher failure from a result-parser mismatch. Current deployment verification does not replace role-specific hosted E2E; preserve exact fixture/UID provenance across browser resets. No production/old local database, restore, purge, credential reset, IAM/App Check changes.


### Existing-owner authentication handoff — 5 October 2026, 19:41 London

After the verified candidate1b73ee6 rollout, secure browserAuth reported submitted. Fresh visible app readback shows `[auth/invalid-email]`, so authentication did not succeed. Credential values were not inspected/read/logged; this does not establish a wrong password, reproduce the prior invalid-credential condition, or prove a lifecycle/account-switch defect. No member-removal request or account creation occurred. Stop automated credential retries and offer manual handoff of the existing sign-in page for regularuser1@test.com. Owner-only F06 and other authenticated hosted scenarios remain blocked/pending. Lesson: submitted credential handoff is not authenticated success; require positive target-domain identity evidence, and distinguish safe Firebase error codes rather than conflating their causes.


### Existing owner verified; hosted member removal passed — 5 October 2026, 19:43 London

Founder manual sign-in succeeded. Fresh Account UI positively identifies regularuser1@test.com, Organisation workspace employee; Shared groups identifies E2E Registered Shared Group admin. Existing groupa12cb842-a072-4cd8-b6a4-cb8fbefc9171 displayed active owner and active E2E Registered Viewer. Owner menu Remove member → explicit confirmation → Remove member completed without blank-page regression. Reopened member dialog now lists only active owner. Independent read-only development DB readback confirms exact viewer membership56df1b59-76c1-4b53-9a26-7a7ee27d10ac status=removed; schema0012 and 3 groups unchanged. No account recreation/password change, guest-flow repetition or owner-role mutation. Proof intqaflow-member-removal-1791225812755.jpg. F06 now Partial: owner removal/persistence passed, removed-viewer access denial still needs that viewer's authenticated request. Previous auth blocker superseded by positive manual sign-in.

Small user-facing defect: confirmation says “Remove this guest member?” for registered member. Assigned identity-neutral terminology correction to Copilot PR13 comment6000864733, F23, without behavior/auth/storage changes. Continue independent archive/restore and pending normal approval/lifecycle checks while Copilot works. Lesson: separate owner mutation/persistence evidence from revoked actor's authorization denial; do not mark combined acceptance fully passed until both actors are checked.


### Hosted archive and same-owner restore verified — 5 October 2026, 19:52 London

New synthetic fixture E2E Lifecycle Acceptance 20261005, group1c5e5f52-6eed-4947-af84-9da3f6f74dba, created under existing registered regularuser1 identity solely for changed archive/restore acceptance; no account created. Added retained Knowledge entry00fbaea3-81ba-4f77-a210-b997557669b7 revision1 and one unredeemed contributor invitation; token not copied/output. Read-only baseline captured content digest, entry ID/revision, invitation counts and one active admin. UI Archive confirmation explains retained members/content/revisions, 30-day same-account recovery and no reactivation of invitations/removed/pending members. Archive completed, fixture removed from active selector and shown under Archived groups with recovery deadline; existing removal fixture stays active. Independent archived DB readback: archived=true, archiver matches fixture creator, content ID/revision/digest unchanged, active admin1, invitation total1/revoked1/unrevoked0. UI same-account Restore succeeded; fixture returns to active selector, retained Knowledge visibly opens with original synthetic answer. Restored DB readback: archived=false, content ID/revision/digest unchanged, active admin1, invitation still revoked1/unrevoked0. Proofs intqaflow-group-archive-1791226173985.jpg and intqaflow-group-restore-1791226282202.jpg. Proxies stopped after each readback.

F05 Partial hosted: archive/retention/invitation revocation/same-account restore/non-resurrection passed. Remaining hosted actor boundaries: another identity denied active operations/recovery while archived; pending/removed membership and pending-transfer cancellation scenario. Reuse automated expired-window and race evidence rather than time-travel live DB or re-run unchanged suites. Fixture now active with retained synthetic content and revoked invite, available for remaining lifecycle setup. No purge/downgrade, owner transfer or original guest group mutation. F04 accepted transfer still pending; F07 normal publication next.

Lesson: capture read-only baseline before archive, verify content ID/revision/digest rather than counts alone, then verify restoration does not resurrect revoked invitations. First generator command had an unterminated string before helper creation/execution; corrected with literal heredoc, no product failure or archive mutation from that command. Keep that harness error separate from completed acceptance.


### One normal-approval proposal prepared; scoped Copilot review — 5 October 2026, 19:58 London

Under verified regularuser1 Employee identity, created synthetic private completed session E2E Atomic Approval 20261005, sessionf597de1d-d05b-49f2-9eed-bd267e3fc4f5, one E2E Approval Participant, one uniquely titled question and saved answer. Session lifecycle steps are fixture setup; prior common session acceptance stays reused. Clicked Propose for Knowledge exactly once; no visible toast observed, so did not click again. Independent read-only DB confirms exactly one proposal40b325f0-bc22-446d-94df-1a78ee3a9f09 statuspending, created_question_idnull, matching Knowledge questions0/answers0. F07 normal approval remains pending: next admin reviews and approves this exact proposal, then independent readback must show one approved record and exactly one created question/answer. Readback helper retained privately; no live failure injection or premature publication.

Copilot headbb25739ca2870679cbdfd74792333d9bce09ff1d reviewed versus deployed1b73ee6: exactly two one-line replacements in guest_workspace_page.dart and its existing guest_group_dialog_test.dart assertion, “Remove this guest member?” → “Remove this group member?”. No backend/auth/role/retention/router changes. Separate clean detached worktree prepared and affected widget suite/whole-app analyzer launched; no deploy or full unchanged-suite rerun. Next admin sign-in can cover pending proposal approval and removed-viewer group-list/access evidence without repeating owner removal/archive/restore. Historical original guesttester continuity and organisation assignment stay separately pending. Record positive account identity after any handoff before using admin controls.

Lesson: distinguish missing UI feedback from missing persistence and inspect exact source/session proposal before retrying. A single unique synthetic fixture plus pre-approval counts prevents accidental duplicate publication from contaminating acceptance.


### Scoped terminology gates complete; admin handoff ready — 5 October 2026, 20:00 London

Exactbb25739 independent affected guest_group_dialog_test.dart suite11passed (4s); whole-app analyzer14 existing infos/no warnings/errors (10.2s); diff check passed, runner markers AFFECTED_TEST_PASS/ANALYZE_PASS/REVIEW_GATES_PASS. Review acceptance reported to Copilot comment6001112818. This two-line text/assertion commit has no backend or behavior delta; unchanged backend95/full Flutter133 evidence retained. Release build/hosted wording inspection not performed; development remains1b73ee6. F23 Implemented but unverified hosted; no further implementation task wait needed.

Registered owner signed out normally after confirmed Saved/completed fixture and one pending proposal; UI returned to local guest workspace, then Sign in form prepared. Manual handoff for existing adminuser@test.com is next, following earlier user handoff preference and secure input invalid-email result; no credential inspection or automated retry. Verify positive admin identity before approval or membership actions. Next batch: approve exact proposal40b325f0-bc22-446d-94df-1a78ee3a9f09 once and independently check one question/answer; removed viewer account group-list/access evidence; inspect original guesttester records before any organisation/department/team assignment. F03 intended existing regular sign-in is verified by manual positive account/role readback; earlier invalid-credential cause remains unexplained and secure browserAuth invalid-email is separate, not proof of app/password failure. Remaining F04/F05 actor-boundary/F06 viewer-denial/F08/F09/F22 scope stays tracked.


### Admin normal publication and removed-viewer UI verified — 5 October 2026, 20:07 London

Manual sign-in positively verified Account adminuser@test.com Organisation workspace admin. Review queue contained exact unique proposal question for sessionf597de1d-d05b-49f2-9eed-bd267e3fc4f5. Clicked Create new Q&A once. Pending proposal disappeared; new item appeared as Needs verification. Opened questionb7d13d8c-db9a-4341-8904-213ba87d14b2: source-session reference and original synthetic answer/regularuser1 attribution visibly correct. Independent DB observed one proposal40b325f0-bc22-446d-94df-1a78ee3a9f09 statusaccepted, created_question_id matching that question, matching title count1/question and1/answer. F07 normal hosted publication is Verified in conjunction with retained disposable atomic rollback/retry regression; no hosted failure injection/repeated approval or verification-flow repetition. Proof intqaflow-normal-approval-1791227124781.jpg.

Readback helper initially expected statusapproved and stopped its assertion; exact source enum KnowledgeProposalStatus.ACCEPTED='accepted'. Corrected helper to defined enum and validated the already-observed count/ID result without approving again or another DB mutation. This is a harness assumption, not product failure. Normal published answer remains Community answer until separately verified, as expected.

As removed E2E Registered Viewer identity adminuser@test.com, Shared groups now has no approved groups, disabled member-management and no owner group/content controls. Previous owner's group selection/content did not remain across UID change. Organisation admin navigation remains available, confirming group and organisation roles are independent. F06 removed-viewer hosted UI availability check passed; direct hosted content-request403 is not exercised by this UI and remains separate authorization evidence pending, do not infer it from an empty list. F22 hosted owner-to-admin routed state isolation observed in this scope; pending transfer-recipient/cache/privacy scenarios remain. Proof intqaflow-removed-viewer-1791227212793.jpg. Continue original guesttester record readback before organisation assignment; do not recreate accounts or repeat completed guest/common flows.


### Existing linked account assigned by admin; original-group evidence gap — 5 October 2026

Read-only Firebase development lookup200 confirms guesttester1@test.com enabled, emailVerifiedtrue, password provider and exact historical UIDCLizPEdEM4b0rbm5CuMoxghMQZf2 unchanged. Pre-enrolment database query against that confirmed UID found **zero guest_group_memberships**, including inactive/removed rows. Historical9eaa93a/6d89698 prove linked local Knowledge/Interact/template and no-org use, but do not identify an original online-group membership. The later E2E Linked Account Continuity fixture belongs to another anonymous identity and cannot be relabelled as guesttester1's original group. F08 now Blocked by original-fixture provenance, not a demonstrated membership-loss regression; do not recreate guesttester1/signup or invent a replacement group as continuity evidence.

Through existing adminuser UI Add organisation member, enrolled the existing verified guesttester1 as Employee with primary E2E Operations Department; member list confirms guesttester1/employee/department while prior regularuser1/admin rows remain. Expanded existing E2E Department Handover Team and selected readable guesttester1@test.com member, Add team member; refreshed team shows guesttester1 and regularuser1 employees. Independent read-only DB confirms active Employee userad5d0eab-942c-400b-a6fe-f7cdf4bb0a13 in exact test organisation15f73358-dbee-46e4-a5fa-c30c3301a282, departmentdc65db82-a4e6-4188-8e90-59620d4f8c7d, team0a2022ba-6667-4889-868a-2c3c6b5dd2cc matching that department. Guesttester group membership snapshot remains equal to zero-row pre-enrolment baseline. No Firebase role/password/verification edit, account recreation, shared-group migration or original-fixture mutation. Proof intqaflow-linked-user-assignment-1791227618346.jpg.

F09 Partial: admin UI enrolment/department/team assignment and authoritative persistence passed; guesttester authenticated user-side intended access/role/group independence remains pending. Reuse earlier no-org local-use/signup evidence. Next transfer acceptance scenario needs distinct owner and active recipient identities; use synthetic fixture setup without pretending it proves original pre-registration group continuity. Remaining hosted wrong-actor archive/direct-content denial boundaries stay separately pending.

Lesson: verify Firebase UID and all membership statuses before claiming historical continuity. Empty current membership and absent historical original fixture is an evidence gap, not proof of lost data or permission inheritance. Treat admin configuration evidence separately from affected user's signed-in experience.


### Accepted-transfer fixture prepared — 5 October 2026, 20:24 London

On deployed1b73ee6, verified adminuser@test.com created synthetic E2E Accepted Transfer 20261005, group75aa2958-6aeb-4fd7-81c2-7ac88c7bef89, owner membership2a123543-193a-4ff3-9e16-ef7bfcce7515 active/admin. Independent setup readback confirms exactly one active owner, no transfer proposals and one unredeemed Contributor invitation. Captured invitation privately; SHA256 comparison to the active database invitation passed without printing its token. A detached-node notice during closing the invitation dialog is not accepted as clipboard success on its own; independent fingerprint comparison resolves the capture check. This is F04 fixture setup only, not accepted-transfer acceptance.

Account readback after reconnection still identifies adminuser@test.com. Next handoff: existing guesttester1@test.com Sign in, no signup. Verify assigned Employee organisation/department/team access and absence of organisation-admin controls; then redeem the private Contributor invitation. Owner approval, pending transfer request and recipient acceptance require distinct authenticated actor round trips; verify roles and unchanged organisation Employee role at each boundary. Historical signup/common invite flows remain reused. F08 original-group fixture provenance remains blocked. No account reset/recreation, purge, production or old local database work.


### Guesttester authentication diagnostics continuation — 6 October 2026

Fresh origin fetch confirms PR13 remains bb25739ca2870679cbdfd74792333d9bce09ff1d; the requested safe stage diagnostics are not committed. Development remains the previously verified 1b73ee6 deployment; no rollout was performed today. Copilot continuation request is PR13 comment 6010746006, referencing the original approved tasks 6002781540 and 6002854083. Implementation and independent candidate review remain pending.

Reconciled prior server evidence from comment 6002854083: app auth/invalid-credential at 2026-10-05T21:00:10.303Z matched Identity Platform SignInWithPassword ERROR at 21:00:10.296Z, status code 3 / INVALID_LOGIN_CREDENTIALS. Temporary development activity logging was disabled immediately after capture, with prior independent readback false. This is historical evidence, not a fresh configuration check. It establishes Firebase rejection before organisation lookup, but neither entered/submitted credential equivalence nor its root cause. Do not attribute it to typing, autofill, membership, or guest storage without controlled evidence. No credentials, tokens, hashes, request bodies or headers were inspected or output today.

Independent Codespace check at bb25739: flutter test test/account_state_widget_test.dart --plain-name 'sign-in' passed 4 tests, including controller-value capture across the asynchronous guest warning, preserved local guest content, sanitized existing-account error UI and archived-group disclosure. Log: /tmp/intqaflow-auth-check-20261006.log. These synthetic tests do not prove actual user credential capture or hosted acceptance. Unchanged backend/full-suite evidence is retained; no unnecessary broad rerun.

F09 remains Partial: admin-side organisation/department/team assignment is verified; guesttester authenticated user-side access remains blocked by sign-in. F04 recipient acceptance remains pending. F08 original shared-group fixture provenance remains an evidence gap. Reuse completed common guest flows; do not reset/recreate guesttester, change passwords, migrate drafts, purge data, merge PRs or touch production/the old local database.

Lessons: distinguish successful regularuser1 sign-in from unresolved guesttester sign-in; use newest PR investigation notes when local docs stop earlier. A widget test using disposable credentials establishes only that synthetic path. Inspect safe stage diagnostics before another real-account attempt. Preserve the diverged local development branch and unrelated untracked migration-review document; validate in an isolated worktree.

Current cloud readback attempt on 6 October: the installed Cloud SDK was located outside PATH. Its existing operator authentication returned HTTP 403 for the Identity Platform config GET; Application Default Credentials were also unavailable. No cloud setting was changed. The logging-disabled result above remains the prior verified result; fresh verification requires authorized operator access.


### Independent auth diagnostics review — 6 October 2026

Exact PR13 candidate `6b0aee0da2f411f46962eec21708673ecec4be43` reviewed in isolated Codespace worktree. Rollout is HOLD. Review sent to Copilot in PR13 comment `6011794911`; application implementation remains Copilot's responsibility.

- Account widget suite: 32 passed in 7 seconds. Other diagnostics unit tests: 8 passed. New provider lifecycle test independently timed out after 20 seconds, with StreamProvider disposed during loading; the initial combined run stalled and was stopped. This is a failed validation gate, not hosted sign-in evidence.
- Analyzer `--no-fatal-infos --no-pub`: exit 1, two new warnings at `auth_diagnostics.dart:222` (non-null projectId null comparison / dead code), plus 18 informational notices, including four new helper style notices. Broad suite and release build withheld pending fixes. Backend unchanged; prior 95/no-skips validation retained.
- Two disposable in-memory review probes failed as expected: a delayed account lookup completion from attempt A was logged against later attempt B and cleared B; auth-state/account lookup stages preceding the SDK future success were silently dropped. Temporary probe file removed; production source unchanged. These establish logger lifecycle defects under controlled ordering, not the cause of guesttester's Firebase rejection.
- Source finding: `sign_in_page.dart:72–76` blocks real sign-in based on an active diagnostic attempt, which can persist awaiting downstream stages for two minutes. Diagnostics must not change authentication behavior; preserve the normal busy guard and decouple logging lifecycle. Lookup callbacks need captured attempt/request/identity handles and stale/disposal checks, plus coverage of both SDK/auth-state event orders.
- Inspected event serialization excludes credential values, lengths/hashes, tokens, raw exceptions, UIDs and request bodies/headers. Default-off/debug/development-project gates are present. Debug-only logging is inert in the existing release Hosting workflow; controlled development reproduction must account for that without automatically publishing, weakening gates or claiming a root cause.

Logs: `/tmp/intqaflow-review-6b0aee0-{account,unit,provider,analyze,probes}.log` in Codespace. No new live credential attempt, cloud configuration change, deployment, account reset/recreation or merge. F09 user-side sign-in, F04 recipient acceptance and F08 historical fixture gap remain unresolved. The Codespace was subsequently observed stopped; its review logs remain on disk, and no restart was needed to record these findings.

Lesson: privacy-safe event fields alone do not ensure trustworthy diagnostics. Correlate each asynchronous callback with its originating attempt, test adverse event ordering, and keep telemetry state out of authentication decisions.


### Scoped Saved Q&A DEV release — 6 October 2026

Founder authorized ONLY the Saved Q&A access fix. Copilot UI289740b and dialog805dfcb were cherry-picked onto deployed1b73ee6; isolated application source7e39550 is preserved on fix/saved-qa-dev-20261006. Later commits change tests only; auth diagnostics excluded.

Knowledge now has Saved Q&A beside Add a local question. It opens saved local entries/search/edit/remove and Back. Local storage/backups/group separation remain unchanged. The edit dialog owns controllers until actual unmount.

Analyzer passed:14infos,no warning/error. Release web build passed using existing DEV defines/AUTH_DIAGNOSTICS flag. Full Flutter133pass/1new-test failure; independent disposable test copy then PASSED complete search/edit/delete/persistence/Back/add flow with target scrolling and downward Undo SnackBar dismissal, retaining assertions and unchanged app source. Temporary file removed. Official test-only correction pending verification: waiting5seconds alone still failed due notification obstruction; proven gesture sent in comment6012632814. Do not claim a single full-suite134-pass run.

DEV Hosting release1791276172690000/versionce894e46fcb0ed4b,36files. Both hosting origins serve main.dart.js identical to tested build4432624bytes. Rollbackaf10c243f0df9ef8 retained. Live browser verified button, Saved Q&A/search/empty state and Back. Screenshot intqaflow-saved-qa-1791276278286.jpg saved. No live test content/account created. Backend unchanged, prior95/no-skips evidence retained. No production/backend/migration/IAM/AppCheck/merge action.

Lesson: bound implementation to agreed user journey. Tests must await frames, scroll controls into view and handle notification overlays; runner failures alone are not product defects. Guesttester sign-in investigation remains separate and unresolved.
