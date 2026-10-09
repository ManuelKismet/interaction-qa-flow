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
