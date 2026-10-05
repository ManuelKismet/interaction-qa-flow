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
