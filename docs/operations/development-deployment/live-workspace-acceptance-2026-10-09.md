# DEV live acceptance checkpoint — 2026-10-09

Partial live acceptance; the four-account matrix is not complete. Target source 8704a6d0c17517f0c636b5ae3057faa4d5870860, Hosting release 1791535916149000. Codespace remains stopped. No source or deployment changes made during these live tests.

## Authentication
Regular sign-in works. User confirmed the earlier failure was a credential typo; there is no evidence of App Check or cloud-browser credential rejection.

## Passed live checks
- Organisation employee: regularuser1@test.com in IntQAFlow E2E Test Organisation. Admin/Review navigation hidden. Team creation/membership/review/answer approval explicitly not granted.
- Organisation Knowledge: synthetic question creation, answer, author acceptance to resolved, comment and persisted reopening through Resolved. Accepted answer remains community content without verification controls. Question ID d26aee1e-c7de-4110-a064-00c98654f960.
- Organisation Interact: private draft, two independent participant answers, shared-question editing, B-only answer-owned follow-up, all-participant report, parseable JSON export containing fixture data, Active and Completed transitions. Session 17d72509-e354-4e66-bf0f-563ac41fddef. Completed sessions intentionally remain editable; final archive was not exercised.
- Personal mode of this employee: single header info icon, combined scrollable guidance, Search/Saved labels, no extra Saved search, private Knowledge creation/edit/persistence.
- Private Interact: inline question/answer, follow-up delete/Undo, selected-participant PDF preview and file download. Session guest-v2-4f1f35c3ded320b82170756785e8ef01-1. PDF bytes not independently parsed.
- Desktop session UI: Destination/PDF actions aligned at same height, question fields with adjacent delete, add-question actions below content.
- Isolated group DEV QA 20261009 group acceptance: create, Knowledge create/edit, revision history 1 and 2. Preview & share Interact includes private account sessions; synthetic selected copy retains participant and answer-owned follow-up. Repeated sharing leaves one group copy.
- Personal Search and Organisation Ask & search: query 20261009 includes accessible private/group/organisation Knowledge and Interact with scope/status labels. Interact filter works; private result opens its persisted session.
- Guest isolation: signed-out query initially returned no account/group/organisation fixtures. Local Knowledge create/edit and empty-save validation pass. Local Interact create/question/answer autosave/follow-up/delete-Undo pass. Reload/reopening retains data. Local search shows only local fixtures with Local labels. Groups requires registered verified-email account.

## Findings
1. Signed-in detail reload loses the route: both organisation question and private Interact URLs redirect to root Organisation Ask & search. Authentication and saved data persist. Investigate initial auth/router redirect.
2. Guest reload returns root Knowledge tab. Selecting Interact reveals the saved session list and reopening retains question/answer/follow-up. User previously accepted reopening guest sessions; this particular tab reset is recorded separately.

## Remaining
- Registered account without organisation membership. Employee Personal mode is not equivalent.
- Verified organisation owner/admin administration and permission delegation; do not assume admin means owner.
- Cross-account private-content denial, approved-group membership boundaries and scoped organisation visibility.
- Owner review/verification, team/department scopes, invitation/join, import round-trip, CSV/browser print, templates, more lifecycle edges and live narrow-screen UI.
- Final archive/permanent deletion/security-sensitive permission expansion require action-time browser confirmation if tested; none performed here.

Synthetic fixtures retained for cross-account checks. Existing user content and permissions unchanged. Earlier release receipt records 392 Flutter and 201 backend passing tests; these suites were not rerun in this live test session.

## Admin acceptance update — 2026-10-09
CORRECTION: the deployed backend does have separate OrganisationOwner records in addition to employee, answer_owner and admin roles. Admin capabilities do not establish ownership. Earlier acceptance of adminuser@test.com as owner was incorrect; owner testing is not passed. Firebase Authentication identity is confirmed, but Firebase user-list identity does not establish backend ownership.

Passed live:
- Account menu confirms adminuser@test.com, organisation admin. My organisation lists all four capabilities organisation-wide.
- Member Manage offers Employee/Department answer owner and primary department. Team expansion displays members and add/remove controls. No membership or permission changes applied.
- Created isolated DEV QA 20261009 test department and DEV QA 20261009 test team linked to that department. No members added.
- Admin unified query 20261009 returns organisation Knowledge and local-device items, excludes employee personal Knowledge/private Interact, private organisation session and isolated group content (admin is not a group member).
- Direct employee private-account session URL shows unavailable/belongs to another account; nothing changed.
- Review queue shows synthetic question needing verification. Admin verifies its answer; UI records Verified by adminuser@test.com, review 2027-04-07. Answer history v1 verified/Answer verified. Reopen to open and accept back to resolved preserve verified status.
- Invalid JSON import rejected with No session was imported.
- Valid exported synthetic organisation session imported as a new admin-owned private draft, 74a7d293-a50c-4de5-830d-0fc591ef9067. Sharing/lifecycle/template/account links intentionally reset. All-participant report retains revised question, independent A/B answers and B-only follow-up.

Open finding:
Direct navigation as admin to another creator's private organisation session 17d72509-e354-4e66-bf0f-563ac41fddef remains on a loading spinner across several observations. No private content exposed, but denial UX is unconfirmed and needs investigation. Personal-account private denial displays correctly.

Remaining: no-organisation registered account creation and DEV email verification/sign-in; actual permission-delegation mutations with action-time confirmation; other edges previously listed. No source/deployment changes. Codespace remains stopped.

## No-organisation registration / verification checkpoint
User created regularuser2@test.com through the app registration form. Firebase UID cxfQXQjxpFPP6L7TFwMLRGUrofX2. App confirmed no organisation membership, displayed registered local workspace and required verified email for Groups. Query 20261009 returned only device-local fixtures, excluding other accounts, groups and organisation results.

User approved trusting the existing Codespace folder and DEV-only email verification. Secure GitHub sign-in succeeded. Existing Codespace resumed. Firebase Admin lookup/update/fresh lookup confirmed emailVerified False -> True for this exact DEV account; identity/email asserted before mutation. First read-only lookup failed HTTP 403 because a quota project was missing, fixed by explicit intqaflow-dev quota-project header. No credentials or tokens printed. No organisation membership or other privileges added.

After app reload it shows Personal workspace, but account and group loading fail; account retry remains unsuccessful. Fresh sign-in is needed to distinguish cached pre-verification auth state from an application defect. Verified no-organisation personal CRUD/group acceptance is not yet marked passed. Codespace shutdown follows this checkpoint.

## Fresh verified no-organisation acceptance
Fresh sign-out/sign-in as regularuser2@test.com cleared the account/group loading errors after backend email verification. Those stale-session errors are not currently classified as an app defect.

Passed live:
- Private Knowledge `DEV QA 20261009 no-org Knowledge` saved with Personal account · saved, retained exact question/details/answer after full reload.
- Private Interact `DEV QA 20261009 no-org Interact`, participant QA No-org Participant, shared question `QA no-org shared checkpoint?` and answer `QA no-org answer: persisted privately.` saved and retained after full reload and session-list reopening; content verified visually.
- Unified query 20261009 returns this account's Private Knowledge/Interact and device-local fixtures only; excludes other account/private/organisation/group fixtures.
- Verified no-organisation user can access Groups, create isolated `DEV QA 20261009 no-org group` as admin, preview private Interact and share its selected synthetic copy. Group report retains question, participant and answer.
- Organisation question direct navigation returns the root without exposing organisation question content; explicit denial messaging remains unconfirmed.

Transient Flutter semantics/control delays observed during live browser actions; private-result click navigation in this no-organisation search was not accepted as passed. A reload restored normal tab/session-list interaction. The earlier direct-route reload/spinner findings remain open. Codespace remains stopped; no source/deployment changes.

The full matrix remains partial: actual scoped permission delegation, cross-account invitation/approval, templates, CSV/browser print and live narrow-screen edges are still untested.

## Delegation and template/proposal acceptance update
User approved a temporary regularuser1@test.com Department answer owner role, primary department DEV QA 20261009 test department, scoped verification test and restoration. Two UI saves closed the dialog but did not persist. Fresh reload confirms employee / E2E Operations Department and no department owner assignment. No privilege expansion persisted, so restoration was unnecessary. Backend release 6f33bcc OrganisationMemberService.update_member requires a separate owner record whenever the request includes role or status; the frontend shows Employee/Department answer owner controls to legacy admins and always sends role. This source restriction explains the observed failure, but the exact HTTP response was not captured. Record owner/admin distinction and misleading non-owner role editing as an open UI/permission alignment finding, rather than treating it as a successful delegation test.

Additional live passes:
- Organisation template DEV QA 20261009 admin template created v1 with two shared questions.
- Using template creates admin-private draft session 7c9cd6eb-00aa-4109-9d23-9bc6130abca8. Answer one saves; report retains both questions, exact answer and No answer recorded for question two.
- Check Knowledge dialog opens with organisation candidates.
- Propose for Knowledge submits to admin review queue. Repeated submission created two pending proposals from the same source; success feedback was not visible during immediate observations. Duplicate submission prevention/feedback remains an open finding.
- Approved one synthetic proposal via Create new Q&A: resulting question appears Needs verification. Rejected the duplicate: No Interact proposals pending. Existing proposals/items unchanged.
- After regularuser2 sign-out, guest search returns only Local fixtures and excludes its Private/group content.

Owner identity and scoped delegation remain unconfirmed. No source or deployment changes made.

## Read-only DEV ownership confirmation
Cloud Run request logs confirm the two member PATCH requests at 2026-10-09T11:12:44.867833Z and 11:14:01.177128Z returned HTTP 403. Read-only SQL transaction against intqaflow-dev:europe-west2:intqaflow-dev-pg / intqaflow_dev confirms organisation_owners has no records for organisation 15f73358-dbee-46e4-a5fa-c30c3301a282. adminuser@test.com remains admin with no primary department; regularuser1@test.com remains employee in dc65db82-a4e6-4188-8e90-59620d4f8c7d (E2E Operations Department). This organisation has no actual owner configured. DEV connection credentials stayed in process memory and were not printed. Temporary SQL proxy terminated after the query. No database mutation performed. Initial proxy runtime lookup failed, resolved by adding the existing gcloud binary directory to the proxy's process PATH.

To complete owner/delegation acceptance, a controlled DEV-only assignment of the existing adminuser account as initial owner of this existing test organisation requires separate approval. The previous temporary answer-owner approval does not cover granting organisation ownership. Codespace is stopped again after read-only investigation.

## Owner and request continuation — 9 October 2026, 13:35 London

This section supersedes earlier owner/delegation prerequisites. Founder approved assigning adminuser@test.com as owner of the exact DEV E2E organisation. The preceding session reported the backend assignment and audit event verified; this continuation independently observed My organisation displaying Organisation owner and owner administration controls. No new ownership grant was performed in this continuation.

### Scoped verification and complete restoration
- Fresh regularuser1 sign-in showed answer_owner in DEV QA 20261009 test department; unrelated team-management/request-review capabilities remained ungranted.
- Created synthetic question 28606837-1f2d-48cc-bfc7-21ffefd85d48 in that department, submitted its synthetic answer, and verified through the ordinary confirmation dialog. UI showed resolved and Verified by regularuser1@test.com, review 2027-04-07.
- Existing unassigned question b7d13d8c-db9a-4341-8904-213ba87d14b2 had no Verify control. This is a UI scope check, not a direct API denial test for every other department.
- As owner, restored Employee and E2E Operations Department. A separate department-answer-owner record remained after role restoration; explicitly removed it. Fresh reload showed employee/original department and No answer owners assigned.
- Subsequent regularuser1 sign-in confirmed original teams, all four delegated capabilities Not granted, and Admin/Review navigation absent. Restoration is complete; no temporary verification authority remains.

### Membership requests and owner review
- Add member rejects malformed email. Existing-member submission opens an explicit change confirmation; cancelled without changing the restored membership.
- Owner administration lists Create Teams, Manage Team membership, Review, and Approve answers. Grants/owner appointment are separate from administrator titles.
- Submitted one test-team request as adminuser and one as regularuser1. A repeat member submission left one visible pending item in the member view. Owner review showed two request IDs: 5b15e236-cdf8-41fd-ab4d-2332e93c15c1 and fcada1d0-6d17-471e-8dcb-52e9cd3b1873, both targeting test team 49402f87-13b7-43b4-9c5a-bd70408f2707.
- Declined both through owner review. Queue then showed No requests are pending in your scopes, and the test team remained empty. No membership approval or access expansion occurred.
- Earlier inference that the two requests proved a duplicate bug is withdrawn: two accounts submitted requests. Likewise initial absence of the owner's request from review does not prove self-review protection. Requester names are absent, so request ownership/self-review/duplicate handling need source or backend confirmation.
- Review cards expose raw target/request UUIDs instead of member and team names; record as a clarity finding.

### Remaining and source diagnosis
- Successful membership approval and post-approval member state remain untested. No group invitation redemption/approval is claimed by the organisation membership tests.
- Organisation question reload resetting to root is supported by source: sessionDeepLinkInitialLocation accepts only guided/personal Interact session routes, and app_router uses overridePlatformDefaultLocation: true. Other routes default to '/'. Application fix/tests remain Copilot scope; no fix or deployment performed here.
- Private organisation session denial spinner, personal-session reload, proposals' repeat submission/feedback, CSV/print, lifecycle edges and live narrow-screen checks remain open or unverified as previously recorded.
- Earlier 392 Flutter/201 backend passes belong to the deployment receipt; no suites rerun in this continuation. Existing Codespace was not started here.
- Evidence saved: intqaflow-permissions-restored.jpg and intqaflow-request-review.jpg. Browser retains the owner session for remaining checks.

## Continued acceptance — 9 October 2026, from 13:42 London

Owner session was retained and independently confirmed as Organisation owner. No application source, deployment or permission changes were made.

Passed live:
- All-participant organisation report for synthetic template-derived session 7c9cd6eb-00aa-4109-9d23-9bc6130abca8 retains both question texts, Participant 1's exact answer and the unanswered second question.
- CSV dialog renders its header and the answered/unanswered rows. Copy was invoked, but browser clipboard reads returned empty, so clipboard delivery is not passed.
- Dedicated printable HTML preview opens in another tab with session title, participant, scope, status, UTC generation timestamp, answer and Unanswered marker. Print button produced no observable browser print dialog; PDF generation/pagination is not passed.
- Synthetic session transitioned Draft -> Active -> Completed with Saved feedback. Save history records Session active revision 3 and Session completed revision 4. Completed editing remains enabled, consistent with existing design. Session is now Completed.
- Archive confirmation clearly says organisation archiving is read-only and has no reopen/restore. Cancelled; archive mutation is not passed.
- Created owner test-team request 6da4b0b2-127f-4f0b-9246-0f2029c6bb2d, then declined it. Fresh review list has no pending requests; no membership/access expansion occurred.

Reproduced findings:
- Full reload of the owner's own organisation session URL returns to root Ask & search. This extends the earlier question/private-account reload finding; source cause for this session variant is not established merely by the route allowlist.
- Owner navigation to regularuser1's private organisation session 17d72509-e354-4e66-bf0f-563ac41fddef remains on the spinner across separate observations. No private content displayed.
- Successful request submission refreshes Your requests but leaves Requests you can review stale. Leaving for Admin and returning shows the pending item. Source OrganisationPage._request invalidates only myOrganisationJoinRequestsProvider on success, supporting this UI refresh defect.

Read-only source confirmation (not a new live API test):
- Membership request service returns the existing pending request for the same requester/type/target; concurrent duplicates are handled after IntegrityError.
- Membership request approval explicitly rejects actor == requester with HTTP 403. The listing does not hide the owner's own request; no self-approval bug is established.
- GuidedKnowledgeService.create_proposal creates a fresh pending proposal without checking for an existing matching pending proposal, supporting the earlier repeated-proposal finding.
- Request cards render target/request UUIDs without requester/team names, confirming the previously observed clarity problem.

Remaining blockers: regularuser1 sign-in for employee cross-account checks and a new member request; successful membership approval requires action-time permission confirmation. Group invitation redemption/approval, actual narrow-screen browser/device coverage, irreversible archive/delete and generated PDF/clipboard delivery remain unpassed. No test suites were rerun; earlier 392 Flutter/201 backend results remain deployment evidence only. Owner signed out normally and app is on the Sign in form for continued testing.

## Employee continuation — 9 October 2026, after 13:55 London

User completed manual regularuser1 sign-in. My organisation independently confirms employee, original E2E Operations Department and two original teams.

Passed live:
- Direct /admin shows No organisation administration permission is assigned.
- Direct /review-queue shows You do not have access to this queue.
- Group Interact shared-copy question edited to `QA private shared checkpoint? Group edit` and saved as revision 2. Revision history lists revisions 1 and 2. Flutter automation input exhibited append/timeout behavior; exact saved draft was inspected before saving, and this is not classified as an application keyboard defect.
- Private original session guest-v2-4f1f35c3ded320b82170756785e8ef01-1 still visually shows original `QA private shared checkpoint?` and exact original answer after reopening; Group edits do not overwrite the private original.
- Employee team selector excludes the two existing memberships, offers only the isolated test team. Submitted test-team request; repeated submission leaves one pending item in Your requests. Original memberships remain unchanged while pending.

Findings reproduced:
- Employee direct navigation to owner's private organisation session 7c9cd6eb-00aa-4109-9d23-9bc6130abca8 remains on a spinner; no private content displayed. This reproduces private-denial UX in both directions.
- Full reload of the employee Personal Interact session returns to root; reopening exact route loads retained source content.

Next: owner sign-in to identify and approve the employee's pending request, subject to action-time confirmation for adding test-team membership, then verify employee state and restore the temporary membership. Group invitation and actual narrow-screen/PDF output remain unpassed. No privileges changed in this continuation.

## Approved membership and Group invitation setup — 9 October 2026, after 14:07 London

User gave action-time approval for temporary regularuser1 membership in DEV QA 20261009 test team and cleanup.

Passed live:
- Owner approved exact pending request 2520ce47-048c-492b-af74-ee5edcfd9c0a. Pending queue becomes empty.
- Admin team expansion lists regularuser1@test.com as employee. Full page reload followed by reopening Admin and expanding the test team confirms persisted membership.
- Removed only that test-team membership; fresh team list is empty. Both original E2E Department Handover Team and E2E Operations Team still list regularuser1. Organisation role remains employee and primary department E2E Operations Department; department answer-owner list is empty.
- Created isolated empty Group DEV QA 20261009 invitation acceptance as QA Owner, admin. Required display-name validation was exercised.

Browser-input qualification: semantic field filling showed a value that did not reach the display-name controller and submission reported empty. Direct visible-field click, keyboard input, blur and coordinate submission succeeded. Do not classify this as an established application form defect.

Invitation is staged at Create invitation with Contributor — own content. No invitation token generated and no new Group member added. Action-time approval is pending for invitation creation and subsequent access approval. Employee-side view while the temporary organisation team membership was active was not exercised; approval persistence and cleanup are owner-side live checks. Evidence: intqaflow-team-membership-approved-20261009.jpg.
## Contributor invitation creation — 9 October 2026, after 14:14 London

User approved Contributor invitation creation in the isolated empty DEV QA 20261009 invitation acceptance Group. Created a one-time invitation and observed its role/expiry. Revoked the unused first invitation, then created the replacement and copied its code through the app; clipboard delivery succeeded. Final member list shows only QA Owner admin/active and one active contributor invitation, expiring 2026-10-10T13:16:27.459498+00:00. No new member has joined or been approved. Invitation code remains only in browser-session memory/clipboard, is not printed or stored in docs. Next: regularuser1 manual sign-in for invitation redemption and pending-member isolation. Evidence screenshot omits the token.


## Pending Contributor join — 9 October 2026, after 14:20 London

User signed in as regularuser1. Organisation view confirms approved test-team request history but only the two original teams after cleanup; original employee/department restored.

Passed live: invitation preview reveals no Group content, explicitly states admin approval is required, and Request access submits. Employee approved-Group dropdown excludes the invitation acceptance Group. Visual inspection shows three pre-existing approved Groups (DEV QA 20261009 group acceptance, E2E Lifecycle Acceptance 20261005, E2E Registered Shared Group); early accessibility snapshots omitted offscreen menu items. Repeating the same token preview/request succeeds without granting access; owner-side pending-member count remains to be checked.

Source qualification: join_invitation returns the existing pending membership when the redeemed token belongs to the same UID, making retries idempotent. A different UID or non-pending reuse is rejected with 409. preview_invitation only checks expiry, revocation and group availability, so an already-redeemed token can still preview as valid. Record this as a preview/join messaging mismatch, not an access bypass. Live cross-account reuse denial and membership approval remain pending. Invitation code remains private browser memory only.


## Group administrator pending readback — 9 October 2026, after 14:26 London

Fresh adminuser sign-in. Isolated invitation acceptance Group member list contains QA Owner admin/active and exactly one QA Contributor contributor/pending after the employee repeated redemption. Active invitation list is empty (redeemed invitation no longer listed). This establishes one pending member and no duplicate caused by retry. Contributor activation awaits action-time confirmation. No Group privileges changed here. Evidence: intqaflow-contributor-approval-ready-20261009.jpg.


## Contributor activated — 9 October 2026, after 14:28 London

User approved activation. Owner approved QA Contributor; reopening Group member management twice confirms contributor/active, QA Owner admin/active, no active invitations. Added synthetic owner-authored Knowledge `DEV QA 20261009 owner group policy` with answer `Synthetic owner content. Contributors may read this but only edit their own items.` for cross-author permission checks. No existing Group content changed. Contributor-side read/own-create/other-author-edit boundaries and cleanup remain pending. Evidence: intqaflow-contributor-active-20261009.jpg.


## Contributor checks and cleanup — 9 October 2026, after 14:52 London

Prior live continuation recorded Contributor owner-item read with no Edit/Delete, own Knowledge create/edit with revisions 1 and 2, member-list visibility without management/invitation/archive controls, unified search opening approved Group owner Knowledge, and editable shared Interact copy revision 2 while private original retained its question/answer. Those checks were performed in the preceding conversation, not rerun here.

Fresh owner sign-in independently confirmed adminuser@test.com and My organisation Role: Organisation owner. Removed only QA Contributor from DEV QA 20261009 invitation acceptance through Remove member. Reopening member management shows only QA Owner admin/active and no active invitations. Synthetic Group content retained. Evidence: intqaflow-contributor-removed-20261009.jpg.

New wording finding: removal confirmation title says “Remove this guest member?” for the registered Contributor. Employee-side post-removal approved-list/search/direct-content denial remains pending and requires regularuser1 sign-in. No source or deployment changes and no automated suites rerun.


## Post-removal employee acceptance — 9 October 2026, after 14:58 London

User completed regularuser1 sign-in. My organisation confirms employee, E2E Operations Department, and exactly the two original teams (E2E Department Handover Team and E2E Operations Team). Approved Groups dropdown visually lists only the three original approved Groups; DEV QA 20261009 invitation acceptance is absent. Personal unified search for policy returns No matching results, excluding the removed Group owner policy fixture. The broad fixture title query matches individual words and returns other authorised organisation fixtures, so it was not used as evidence of exact-match behavior.

Group creation → invitation/revocation/replacement → repeated pending join → approval → Contributor own-content boundaries → removal → approved-list/search exclusion is now covered. Direct removed-Group content request denial is not marked passed: exact Group/content IDs were not retained in this browser session. Evidence: intqaflow-removed-group-excluded-20261009.jpg.

Outstanding coverage: direct removed-Group content denial; cross-account redeemed-invitation reuse denial; employee-side access while temporary test-team membership is active; actual narrow-screen/device checks; independently parsed generated PDF; irreversible archive/delete. Full acceptance remains partial. No source/deployment changes or new automated-suite results.


## PDF, template and removal validation — 9 October 2026, after 15:05 London

Downloaded selected-participant PDF independently parsed with pdftotext and rendered with Poppler. Title, participant, original shared question/answer and answer-owned follow-up are present; one-page visual review shows no clipping/overlap.

Created private template DEV QA 20261009 private template validation from original synthetic session. Saved template appears as Personal account saved, 1 questions. Created DEV QA 20261009 template roundtrip, session guest-v2-c2688a8edd8657545a30bddefeca1861-3. Visual readback retains shared question and follow-up, replaces original participant name with Participant 1 and leaves answers empty. Personal account saved confirmed. Evidence intqaflow-template-roundtrip-20261009.jpg.

Removed only the new roundtrip session through Delete session. List excludes it and shows removal queued with Undo. Invoking Undo restores it as Local on this device; toast explicitly says private account removal is not undone. Record recovery limitation: Undo restores local content only, not account persistence. Original session and saved template unchanged. Roundtrip local copy retained for investigation.

Checkpoint published through connected GitHub API after CLI lacked credentials. GitHub qa/live-acceptance-20261009 branch was created from copilot/fixinteract-parity-batch4-edit-shared-copy. Existing checkpoint contents replaced with approved local checkpoint, commit b16d9588eeabf0c15bf6b4605180d848ace7d430. Local 60b23fa commit itself was not pushed.


## Group archive/restore — 9 October 2026, after 15:12 London

Owner archived only DEV QA 20261009 invitation acceptance. Confirmation states 30-day same-Firebase-account recovery; archive UI lists deadline 2026-11-08T14:13:49.442201+00:00. Restore succeeded; Group returned to approved selector. Reopened member management confirms only QA Owner admin/active and no invitations; removed Contributor remains removed. Evidence intqaflow-group-restore-membership-20261009.jpg. No permanent deletion performed. Owner Group detail uses a modal without a content URL, so no exact deep-link reference was acquired through the visible UI.

Admin staged regularuser1@test.com for DEV QA 20261009 test team. Add team member not submitted; action-time confirmation awaited for temporary membership and subsequent employee-side verification/cleanup. Evidence intqaflow-team-access-retest-ready-20261009.jpg.


## Temporary test-team membership applied — 9 October 2026, after 15:17 London

User gave action-time approval. Owner Add team member applied only regularuser1@test.com to DEV QA 20261009 test team. Fresh visual readback lists regularuser1 employee under that test team; primary department remains E2E Operations Department in Members. Evidence intqaflow-team-access-retest-added-20261009.jpg. Temporary membership remains active pending employee-side checks and subsequent removal. No delegation/role changes made.


## Employee active-team permission checks — 9 October 2026, after 15:25 London

Manual regularuser1 sign-in succeeded after secure-form sign-in surfaced Check your email and password. No credential cause inferred. My organisation confirms DEV QA test team plus the two original teams, employee role and original E2E Operations Department. Your permissions shows Create Teams, Manage Team membership, Review requests and proposals, Approve answers all Not granted. Direct Admin and Review routes deny access. Evidence intqaflow-employee-test-team-permissions-20261009.jpg. No test-team scoped content fixture was exercised. Temporary test-team membership remains active awaiting owner cleanup; no other privileges changed.


## Final temporary-team cleanup — 9 October 2026, after 15:30 London

Owner removed only regularuser1 from DEV QA 20261009 test team. Expanded test team empty; both original team expansions retain regularuser1 employee; Department owners says No answer owners assigned. Original primary department/role shown unchanged in Members. Evidence intqaflow-team-final-cleanup-20261009.jpg. No temporary memberships/delegations remain from these checks.

Synthetic invitation acceptance Group rearchived for final permanent-delete test, recoverable until 2026-11-08T14:32:19.357454+00:00. Exact permanent-delete dialog staged: deletes Group/content/memberships irreversibly; existing exports/local copies unaffected. Delete permanently not submitted, awaiting action-time user confirmation. Evidence intqaflow-test-group-permanent-delete-ready-20261009.jpg.


## Permanent synthetic-Group deletion — 9 October 2026, after 15:34 London

User approved exact permanent deletion. Deleted DEV QA 20261009 invitation acceptance through named confirmation. Archived recovery card disappears. App Refresh and approved selector show only E2E Accepted Transfer 20261005; deleted Group is absent from both active and archived UI. Evidence intqaflow-test-group-deleted-20261009.jpg. This completes live Group permanent-delete UI/persistence verification; no database-level cascade assertion performed. Temporary Contributor and test-team memberships already cleaned up. Other original Groups and original private Interact untouched.

Coverage limits still explicit: actual narrow-screen/physical-device coverage; cross-account redeemed invitation reuse denial (source checked, token no longer retained); direct removed-Group content request denial (modal lacks a visible deep link and IDs not retained); team-scoped content visibility (membership and privilege boundary checked, no scoped fixture). Full exhaustive acceptance not claimed. No new automated suites or source/deployment changes.
