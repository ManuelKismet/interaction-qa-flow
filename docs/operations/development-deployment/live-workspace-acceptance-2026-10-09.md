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

## Finding F01 reload-only repair — 9 October 2026

User authorized fixing only reload route loss. Isolated fix/reload-route-20261009, PR #22. Production route parser: 38 direct Dart assertions passed; pure resolver analysis, formatting and whitespace checks passed. Auth-loading widget regressions added; focused GitHub routing/account-state validation running. No merge or DEV deployment performed yet. F01 implemented / validation pending, not hosted-verified.

Complete durable F01–F14 and C01–C06 ledger: live-acceptance-findings-tracker-2026-10-09.md. Other findings and recorded behaviors remain pending and unchanged. Do not close F01 merely on implementation or let earlier pending checks override latest acceptance results.


F01 validation completion: GitHub Actions reload-routing run 37954911646 succeeded: 81 Flutter routing/account-state tests passed, including the five auth-loading route regressions. Formatting gate passed; backend validation run 37954911649 succeeded. PR #22 contains only F01 implementation plus regression validation and tracking. Status: implemented / automated validation passed / DEV deployment and hosted refresh retest pending. Other findings remain pending.


## Finding F02 private organisation session denial repair — 9 October 2026

User authorized only F02 and explicitly instructed holding all fixes for one DEV rollout after the findings are resolved. PR #23 is stacked on PR #22; session-detail retry stops on 403/404, safe unavailable/no-permission view replaces the prolonged spinner and provides Back to Interact / explicit Try again. Transient errors retain default retry; backend access rules unchanged.

Validation: 81 Flutter guided safety/page/reload tests passed in run 37957307102 on 23ccfee5a5748eaf446f51616d24e06ae736f49e; formatting passed; backend CI 37957308347 succeeded. Local session/access suites: 41 passed in 5.00s, isolated SQLite/test auth rather than hosted. New fixture initialization/query-count assumptions corrected before the final passing run; all five regressions pass.

Complete F01–F14 / C01–C06 ledger retained in live-acceptance-findings-tracker-2026-10-09.md. F01/F02 fixed and automated-validated, held for combined DEV deployment and hosted confirmation. F03–F14 unchanged/pending. No merge or deployment. Knowledge assignment/visibility finding F12 does not generalize to Interact's explicit TEAM visibility mode.

## F03 implementation and automated validation — 9 October 2026

Draft PR #24: https://github.com/ManuelKismet/interaction-qa-flow/pull/24, branch fix/reviewer-request-refresh-20261009, stacked on PR #23. Successful membership submission now invalidates both myOrganisationJoinRequestsProvider and pendingOrganisationJoinRequestsProvider within the existing mounted/current-scope guard. No review authority, self-approval, backend policy, or other finding behavior changed.

Source/test/workflow commit 73cf15007b291b6b37ac7b1525b95d92dc8d7d2a. GitHub Actions Organisation request refresh validation run 37958624256 / job 113915450707 succeeded: 20 Flutter tests passed across organisation_scope_test.dart, organisation_page_test.dart and responsive_organisation_test.dart, with the formatting gate passed. New routed widget regression submits a membership request through the real repository/HTTP test adapter, observes updated personal and reviewer lists without navigation, and confirms /organisation remains selected. Existing revoked-review, UID/signout, owner controls and narrow viewport tests also pass. Backend validation run 37958624065 passed. Local Dart format and git diff --check passed; Flutter execution used CI because local dependency setup remains unavailable.

Workflow ownership guidance checked in docs/operations/isolated-development.md and cloud-development.md. User offered Copilot collaboration as optional; this small fix was implemented directly and independently checked. No Copilot handoff claimed.

F01–F03 are source-fixed and automated-validated, awaiting combined DEV deployment and hosted confirmation. F04–F14 and C01–C06 remain tracked and untouched. No merge or deployment performed.

## F04 implementation and automated validation — 9 October 2026

Draft PR #25: https://github.com/ManuelKismet/interaction-qa-flow/pull/25, branch fix/request-display-names-20261009, stacked on PR #24. Request-list API adds optional requester_name and target_name, resolved in batches only after existing per-request authorization filtering, with organisation constraints on every user/team/department lookup. Flutter personal request cards show target names; reviewer cards show target and requester names. Missing/blank names use Team unavailable, Department unavailable, or Requester unavailable; internal IDs remain in data for unchanged decision actions. No migrations or expanded directory permissions.

Tested source commit f42d3fbd0358f785c6bb65edc97073637f178758. Flutter Organisation request refresh validation run 37959477426 / job 113918345587: 20 tests passed and formatting passed. Regression exercises named requester/team rendering, suppresses displayed internal request/target IDs, handles legacy/missing department/requester names, and retains the F03 refresh and route assertion. Existing role/UID/signout/revocation and responsive cases pass. Backend validation run 37959477501 / job 113918345629: 172 passed, 32 skipped; dependency check, analysis and compilation passed. Three new API cases cover team and department names for owners/personal lists, no requests for unauthorized reviewers or foreign organisations, and no foreign department name resolution. Local targeted organisation administration/member tests: 15 passed. Dart formatting and git diff --check passed. Local ruff was unavailable; CI analysis passed.

F01–F04 are source-fixed and automated-validated, awaiting combined DEV deployment and hosted confirmation. F05–F14 and C01–C06 remain tracked and untouched. No merge or deployment performed.

## F05 implementation and automated validation — 9 October 2026

Draft PR #26: https://github.com/ManuelKismet/interaction-qa-flow/pull/26, branch fix/pending-knowledge-proposals-20261009, stacked on PR #25. Knowledge proposal creation locks the source answer row, validates the existing identity/content authority and target scope, then returns an existing pending proposal for the organisation/question/answer pair with already_pending=true. It preserves original proposal content and creates no second proposal-created audit event. Reviewed proposals still allow a new submission. Flutter prevents overlapping local proposal actions while saving and gives immediate explicit pending-review confirmation, distinguishing repeated submissions; it replaces an older snackbar so the result is visible.

No migration or destructive cleanup: previously created duplicate rows are retained. This prevents new sequential/concurrent duplicates; it does not claim prior duplicates were removed. F06–F14 behavior unchanged.

Tested source/workflow commit 1cce3e9adc309ac2caebde0605123dc2e4228b90. Flutter validation run 37960501480 / job 113921825971: 82 tests passed (guided safety/page and session routes), formatting passed, including new and already-pending feedback. Backend validation run 37960501485 / job 113921825600: 173 passed, 33 skipped; dependency checks, analysis and compilation passed. Dedicated PostgreSQL/pgvector concurrency run 37960502367 / job 113921829046: 1 passed, executing the race otherwise skipped in the default suite. Two concurrent requests return one proposal ID with one new and one already-pending result and one stored row. Local guided API/safety suite: 42 passed, including repeated-submission content preservation and one creation audit; existing acceptance/rejection and safety tests remain passing. Dart format and git diff --check passed.

F01–F05 are source-fixed and automated-validated, awaiting combined DEV deployment and hosted confirmation. F06–F14 and C01–C06 remain tracked and untouched. No merge or deployment performed.

## F06 implementation and automated validation — 9 October 2026

Draft PR #27: https://github.com/ManuelKismet/interaction-qa-flow/pull/27, branch fix/redeemed-invitation-preview-20261009, stacked on PR #26. Preview returns valid=false and used=true for an available but redeemed invitation, except the existing same-Firebase-account pending membership retry allowed by join (valid=true, used=true). Approved/removed memberships cannot reuse it. Unavailable/expired/revoked invitations retain generic valid=false, used=false. The response carries only these booleans, never redeemer identity or group metadata. Flutter displays an explicit already-used message asking for a new invitation and offers no Request access confirmation or join write for that preview. Existing join authorization/idempotency remains unchanged; no membership or invitation cleanup performed.

Tested source/workflow commit 52a5f0898bcde9e719ca118d450627bae3aeae3f. Invitation preview Flutter validation run 37963462055 / job 113931820727: 39 Group dialog/repository tests passed and formatting passed. New UI regression verifies already-used explanation, no join dialog/action/write and no token displayed outside input; four repository cases cover unused, redeemed, same-account pending and older generic-unavailable responses. Backend validation run 37963462039 / job 113931820740 succeeded: 173 passed, 33 skipped; analysis/dependency/compilation gates passed. Local Group API suite: 14 passed. Extended lifecycle assertions check unused preview, cross-account used preview and 409 join denial, same-account pending preview and idempotent retry ID, approved account used preview, and expired/revoked/unavailable cases. Dart format and git diff --check passed.

F01–F06 are source-fixed and automated-validated, awaiting combined DEV deployment and hosted confirmation. F07–F14 and C01–C06 remain tracked and untouched. No merge or deployment performed.

## F07 implementation and automated validation — 9 October 2026

Draft PR #28: https://github.com/ManuelKismet/interaction-qa-flow/pull/28, branch fix/group-member-removal-wording-20261009, stacked on PR #27. Removal confirmation now says "Remove this Group member?" and the removal endpoint's not-found error says "Group member not found". Existing removal widget test expects the neutral title. Three one-line wording changes only; membership identity, permissions, status mutation, admin protection and removal flow are unchanged. Other member actions' terminology is outside this scoped removal finding.

Tested source commit de9c36253e39526ed568e5243d6ec89a0499b94f. Flutter Group dialog/repository validation run 37965211802 / job 113937734255 succeeded: 39 tests passed, including removal confirmation, one removal request, removed status and continued mounted Group page; formatting passed. Backend validation run 37965211776 / job 113937733681 succeeded: 173 passed, 33 skipped, with analysis/compilation/dependency checks passed. Local formatting and git diff --check passed.

F01–F07 are source-fixed and automated-validated, awaiting combined DEV deployment and hosted confirmation. F08–F14 and C01–C06 remain tracked and untouched. No merge or deployment performed.

## F08 implementation and automated validation — 9 October 2026

Draft PR #29: https://github.com/ManuelKismet/interaction-qa-flow/pull/29, branch fix/personal-session-undo-20261009, stacked on PR #28. Finding clarified as Personal-workspace Interact Undo, not organisation private-session visibility. Account-owned sessions normally load from account records and are excluded from the guest browser store. The defect arose after a confirmed deletion removed the ownership record: generic Undo then treated the restored session as local.

Undo retains original account intent and UID. For a completed deletion it queues account reconciliation, recreates the session privately if still absent, accepts matching already-restored content, or invokes existing conflict review if a newer account version exists. Account keys keep the restored session out of browser-only persistence. Existing in-flight/failed/uncertain deletion reconciliation and explicit retry remain intact. Account changes block stale account Undo; local guest sessions keep local Undo. Feedback says account restore queued and directs the user to save status. No broader browser-storage migration or backend policy change.

Final tested source commit 9609385fe06fab5be8d6e0b1a9f3cc08215a59d2. Personal session Undo validation run 37967446579 / job 113945235239: 109 tests passed (account_state_widget_test.dart, guest_interact_widget_test.dart, guest_workspace_store_test.dart); formatting passed. New completed-delete Undo regression asserts one restored account item, original content, original UID, no session in guest browser storage, and survival after reconstructing the page with fresh browser storage. New concurrent-account-content regression asserts a newer remote copy is not overwritten and explicit conflict review is shown. Existing pending/in-flight/failed/uncertain deletion, lost acknowledgement, conflict, UID/signout and guest-storage cases pass. Group dialog/repository run 37967446508 / job 113945234797: 39 tests passed. Backend validation run 37967446477 / job 113945234688: 173 passed, 33 skipped; analysis/compile/dependency checks passed. Local format and git diff --check passed. Earlier initial 108-test pass was superseded by the final reconciliation/conflict regression.

F01–F08 are source-fixed and automated-validated, awaiting combined DEV deployment and hosted confirmation. F09–F14 and C01–C06 remain tracked and untouched. No merge or deployment performed.

## F09 implementation and automated validation — 9 October 2026

Draft PR #30: https://github.com/ManuelKismet/interaction-qa-flow/pull/30, branch fix/owner-only-role-controls-20261009, stacked on PR #29. Fresh source review confirmed the historical mismatch: Manage member only excluded granting Admin for non-owners, while other existing-role changes remained offered; every update included role, even a department-only save. Backend update_member rejects any role/status field from a non-owner.

Existing-member editor now renders role as read-only with an owner-only explanation for non-owner legacy admins. Their update passes null role, which the existing GovernanceRepository omits from the PATCH body; department editing remains available. Owners retain the role dropdown and existing Admin confirmation. New-member creation and backend permission rules remain unchanged. No F10–F14 work performed.

Tested source/workflow commit d044f85d4336564195359ff52ce4f80095003c50. Owner role controls validation run 37968435458 / job 113948601611: 14 Flutter tests passed across team_ui_test.dart, organisation_page_test.dart and organisation_scope_test.dart, with formatting passed. Two new routed-surface widget cases assert no role dropdown for non-owner, owner-only explanation, null role on non-owner department save, owner dropdown permitting answer-owner change, submitted owner role, and preserved department value. Existing team/membership controls and organisation identity/capability tests passed. Backend validation run 37968435284 / job 113948600880: 173 passed, 33 skipped; analysis/compilation/dependency gates passed. Local formatting and git diff --check passed. Hosted non-owner retest remains pending the combined deployment.

F01–F09 are source-fixed and automated-validated, awaiting combined DEV deployment and hosted confirmation. F10–F14 and C01–C06 remain tracked and untouched. No merge or deployment performed.

## F10 implementation and automated validation — 9 October 2026

Draft PR #31: https://github.com/ManuelKismet/interaction-qa-flow/pull/31, branch fix/inaccessible-group-link-20261009, stacked on PR #30. Group loading preserves the requested link as its preference. If it is absent from the caller's approved Group list, selection stays empty and an unavailable/no-access message is displayed instead of automatically loading the first approved Group. The unresolved initial link persists on refresh/identity loading. Approved Groups remain available for explicit selection. Initial entry auto-opening additionally requires the selected Group to match the linked Group; switching to another Group cannot open the original entry there. Content authorization and backend policies unchanged.

Tested source commit 748a6567d4d6fefedb947602194add4feed54670. Group dialog/repository validation run 37969482256 / job 113952136776: 41 Flutter tests passed, formatting passed. New cases cover an unavailable requested Group with another approved Group and with no Groups: clear unavailable message, no Group detail read or entry rendering, refresh retains unavailable state, and explicit approved-Group selection loads its content without opening the linked entry dialog in that different Group. Existing authorized Group/entry deep-link regression passes. Personal/account/Interact/store validation run 37969482282 / job 113952137147: 109 Flutter tests passed, including prior F08 regressions. Backend validation run 37969482395 / job 113952137465: 173 passed, 33 skipped, analysis/dependency/compilation passed. Local formatting and git diff --check passed.

F01–F10 are source-fixed and automated-validated, awaiting combined DEV deployment and hosted confirmation. F11–F14 and C01–C06 remain tracked and untouched. No merge or deployment performed.

## F11 implementation and automated validation — 9 October 2026

Draft PR #32: https://github.com/ManuelKismet/interaction-qa-flow/pull/32, branch fix/guest-interact-reload-20261009, stacked on PR #31. F01 already preserved supported launch URLs, but the local guest workspace never recorded session navigation or consumed the Interact route on startup. Guest startup now reads the captured launch route and opens its Interact tab and saved local session. Opening/closing a session and switching Knowledge/Interact update the guest browser location without replacing the guest tab controls. Question/participant query selection is retained on startup. Registered-account persistence and organisation routing are unchanged; guest data remains in the existing local store.

Tested source commit aef75ecccb0e9fc9e58409455001e07341ea13c9. Reload routing validation run 37970667080 / job 113956150769: 85 Flutter tests passed, formatting passed. Two new regressions cover path and hash launch URLs: open a saved guest session from Interact, verify its recorded URL, reconstruct the app with that URL and the saved local store, verify the same editor/content reopens without duplicating the session, then verify session-list and Knowledge locations. Existing authentication-loading route and account identity/persistence tests pass. Personal session Undo validation run 37970667018 / job 113956150659: 109 tests passed. Group dialog/repository validation run 37970667023 / job 113956150633: 41 tests passed. Backend validation run 37970667086 / job 113956150842: 173 passed, 33 skipped; analysis/dependency/compilation checks passed. Local Dart format and git diff --check passed; uploaded source blobs match local file hashes. Local Flutter dependency setup remains unavailable, so execution used CI.

F01–F11 are source-fixed and automated-validated, awaiting combined DEV deployment and hosted confirmation. F12–F14 and C01–C06 remain tracked and untouched. No merge or deployment performed. The F11 hosted browser reload retest remains pending the combined rollout.

## F12 implementation and automated validation — 9 October 2026

Draft PR #33: https://github.com/ManuelKismet/interaction-qa-flow/pull/33, branch fix/knowledge-visibility-20261009, stacked on PR #32. User selected explicit Organisation / Department / Team Knowledge visibility, separate from assignment. Creation and editing now send the selected visibility; the selected department/team is the audience when that visibility is restricted. Organisation visibility remains the default and existing recorded visibility is retained. Existing private records retain private access and can be edited without silently changing visibility. The UI explains responsibility versus audience, requires the relevant target before submission, shows recorded visibility, and fits the 360px automated viewport.

One shared membership-aware SQL visibility clause now governs direct question checks, lists, aliases, versions and both lexical/semantic search candidate queries, including canonical and matched-question audiences. Direct answer/comment/history and governance paths await that same visibility check. Restricted access requires current department membership or current membership of the selected active team; author/admin status does not bypass it. Restricted creation or scope edits require the actor to belong to the selected scope. Team membership removal, department changes and inactive teams deny subsequent reads. Owner/admin governance permissions remain separate from content visibility. Existing Knowledge visibility is checked before proposal linking, and canonical merges across different visibility audiences are rejected before answer copying. Question-detail 403/404 stops automatic retries while retaining safe error/Back to Questions/explicit retry. Other finding behavior is unchanged.

Migration 0016 adds 'team' to PostgreSQL question_visibility, also used by QuestionVersion snapshots. It rewrites no existing content. Downgrade retains the additive enum value and restricted records instead of widening their visibility or deleting history; any application rollback must retain support for reading this enum value. Apply the migration before releasing the new backend/UI in the eventual combined DEV rollout. No hosted database mutation performed here.

Final tested source commit 1db9f3f6afdf9557b643fa35c7129e1310712644. Knowledge visibility validation run 37973214917: Flutter job 113964842070 passed 18 tests (ask_page, question_detail_page, questions_repository, question_models, unified_search_results), formatting and focused Flutter analysis passed with no issues. New regressions exercise explicit department/team selection and submitted scope, missing-scope disabled submission, recorded visibility in edit, unchanged organisation assignment, safe denial with no automatic retry and explicit retry, and production repository request bodies. Existing 360px/mobile keyboard and unified-search cases pass. PostgreSQL job 113964842508 passed the native-enum/member/search/version test, full baseline upgrade to 0015 then 0016, downgrade to 0015 with team question/version rows retained, and re-upgrade. Proposal concurrency run 37973214896 / job 113964841783 passed its existing race regression (1 test).

Backend validation run 37973214900 / job 113964842130: 177 passed, 34 skipped; dependency consistency, Ruff analysis and compilation passed. Four new API regressions cover department/team detail/list/search/answer/comment/version/challenge boundaries, unauthorized writes, alias/canonical search leakage, author membership loss, multiple-team membership, inactive teams, missing/null scope validation, explicit restriction of an existing question, assignment independence, and cross-audience merge protection. Local targeted API tests passed; local full backend suite passed before addition of the PostgreSQL-only skipped case. All 24 uploaded source/test/workflow blobs match local hashes; local formatting and git diff --check passed. Earlier lint failures and test-scroll/mobile-dropdown issues were corrected; the final complete validation above supersedes them.

F01–F12 are source-fixed and automated-validated, awaiting combined DEV deployment and hosted confirmation. F13–F14 and C01–C06 remain tracked and untouched. No merge or deployment performed. F12 hosted member/non-member direct-link and search retests remain pending the combined rollout; automated viewport checks do not close physical-device coverage.

## F13 implementation and automated validation — 9 October 2026

Draft PR #34: https://github.com/ManuelKismet/interaction-qa-flow/pull/34, branch fix/completed-interact-read-only-20261009, stacked on PR #33. Completed organisation Interact sessions are read-only in both the UI and API. Details, participant changes, question edits/deletion/restoration, answers, branch state and follow-ups are rejected with 409 under the session row lock. The same guard enforces the existing archived read-only policy. Reports, JSON/CSV exports, revision history, template creation and authorised archiving remain available.

Only the explicit POST /guided/sessions/{id}/reopen action returns Completed to Active. It uses existing creator/admin and visibility authorisation, preserves original started_at, clears current completed_at, increments the revision and records a distinct GUIDED_SESSION_REOPENED audit event and “Session reopened” revision; earlier completion history remains. Ordinary Start cannot reopen a completed session, and archived sessions cannot reopen. UI displays a completed/read-only notice, hides all content editing controls, suspends queued autosaves when editing access changes, and offers Reopen session only to authorised editors. Reopening restores editing controls. Personal/account and local guest sessions have no Completed lifecycle and remain unchanged.

Final tested source commit ff3c93d110d2570fd4af16664528544c4160b118. Completed Interact validation run 37975604100: Flutter job 113972997789 passed 86 tests across guided_batch3, guided_safety, guided_page and guided_session_page, with formatting and focused analysis clean; PostgreSQL job 113972997294 passed the completion-versus-waiting-edit race (1 test). New narrow-screen cases prove completed owners/viewers have no content controls, authorised explicit reopening restores controls, viewers cannot reopen, and completed reports remain readable. The older session-denial fixture was stabilised across authority initialisation, given an actual 404 and the existing safe denial message, and now asserts no automatic retries while denied plus explicit recovery.

Private session denial validation run 37975603979 / job 113972996702 passed 84 tests. Backend validation run 37975604110 / job 113972997395 passed 179 tests, 35 skipped; dependency consistency, Ruff analysis and compilation passed. Two new API scenarios cover private and organisation sessions, all 12 write surfaces denied without stored graph/audit/revision changes, creator/admin/non-authorised reopening, completion/reopen timestamps and history, ordinary Start rejection, re-completion and archived write/reopen denial. The skipped PostgreSQL race was separately executed successfully above. Existing proposal race run 37975604009 / job 113972996983 passed (1 test). Local full backend suite also passed 179 tests, 35 skipped. All nine uploaded source/test/workflow blob hashes match local files; local formatting and git diff --check passed. Earlier style and test-fixture failures were corrected and are superseded by these final successful checks.

F01–F13 are source-fixed and automated-validated, awaiting combined DEV deployment and hosted confirmation. F14 and C01–C06 remain tracked. No merge or deployment performed. F13 hosted completion/reopen/permissions checks and archive/export acceptance remain pending the combined rollout; automated API/export and narrow viewport tests do not close the hosted or physical-device coverage items.

## F14 implementation and automated validation — 9 October 2026

Draft PR #35: https://github.com/ManuelKismet/interaction-qa-flow/pull/35, branch fix/member-role-assignment-review-20261009, stacked on PR #34. Existing department answer-owner assignments are now listed in the member editor with an explicit explanation that changing the organisation role does not remove them. Saving shows whether the assignments will be kept or removed. Organisation owners can deliberately select “Remove all department answer-owner assignments on save”; the checkbox is unchecked by default. Non-owner admins retain read-only roles and see the assignment explanation without the combined-cleanup control. If assignment loading fails, member editing is unavailable with an explicit retry message, avoiding a role change without the assignment review.

The member PATCH accepts clear_department_answer_owners=true only from an organisation owner. It removes the member's assignments within the current organisation in the same transaction as role/primary-department/status updates, and records one existing DEPARTMENT_OWNER_REMOVED audit event for each removed assignment. Omitted/false cleanup preserves assignments, and repeating cleanup is harmless. Validation failures roll back the combined changes. New department assignments lock and refresh the target member row before checking the existing answer_owner role requirement; a concurrent assignment waiting behind demotion and cleanup cannot recreate the removed assignment. No migration, implicit bulk cleanup or broader permission redesign. Existing individual assignment management remains separate.

Final tested source commit a1b9ea0c2ac365704960293c71fd4b557d575d40. Member assignment review validation run 37976782931: Flutter job 113976981027 passed 28 tests across team_ui, member_assignment_repository, organisation_page, organisation_scope and responsive_organisation, with formatting and focused Flutter analysis clean. New 360px owner cases verify the Employee role change clearly retains or explicitly removes multiple assignments and sends the chosen flag; the non-owner regression shows no role/cleanup control and preserves assignments. Production repository test verifies the cleanup flag is sent only when selected, and department-only updates omit role and cleanup. PostgreSQL job 113976981426 passed the assignment-versus-demotion/cleanup race (1 test).

Owner role controls validation run 37976782815 / job 113976980432 passed 16 tests. Backend validation run 37976782922 / job 113976981185 passed 182 tests, 36 skipped; dependency consistency, Ruff analysis and compilation passed. Three new API scenarios cover default retention, explicit removal across multiple departments, per-assignment audit, unrelated-member preservation, owner-only cleanup, foreign-member denial, idempotent cleanup, rejected assignment after demotion and invalid combined-save rollback. The default-suite PostgreSQL skip was separately exercised successfully above. Local full backend suite passed 182 tests, 36 skipped. All ten uploaded source/test/workflow blobs match local hashes; local formatting and git diff --check passed.

F01–F14 are now source-fixed and automated-validated, awaiting one combined DEV deployment and hosted confirmation. C01–C06 remain open in the coverage ledger; no coverage item is silently closed by these automated tests. No merge or deployment performed. The combined rollout must include migration 0016 before the new backend/UI; hosted retests must verify all findings and preserve the original acceptance history and coverage evidence.


## U01 — conditional guest recovery tools

Authorized before C02–C06. Implemented in draft PR #36 (`fix/conditional-guest-recovery-tools-20261009`), source commit `381096526773944744258e56cdeb3b19c40d6427`. Registered Personal settings show “Finish importing your guest data” only for remaining local guest records or unfinished imports. Confirmed source keys from the current account exclude already imported originals; another account never inherits that completion state. Import offers only remaining items. Backup and explicit discard remain available during recovery; discard is disabled while import writes are in flight and otherwise cancels pending retry state without deleting account or Group content. Registered users do not get a new guest JSON-import action. Guest users retain their existing tools.

Validation: complete Flutter suite 431 passed, backend suite 182 passed / 36 environment-dependent skipped, release web compilation passed. Final source CI run 37979773081 / job 113987012414 completed successfully, including format, analysis (three existing info hints), full Flutter tests, and release build. Backend, Personal Undo, and invitation-preview workflows also passed at the final source commit. These checks do not establish hosted acceptance. Combined DEV-configured build and no-traffic backend staging have started in the existing Codespace; database migration and traffic/hosting publication have not yet been completed. C02–C06 remain pending; C01 remains physical-device acceptance.
