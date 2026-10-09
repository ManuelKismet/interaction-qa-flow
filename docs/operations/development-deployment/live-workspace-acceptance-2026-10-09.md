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
The deployed organisation model has no distinct owner reference and its user roles are employee, answer_owner and admin. User agreed adminuser@test.com covers organisation admin/owner testing. Firebase Authentication identity confirmed; DEV Firestore has no configured database. App roles are backend records, not Firebase user-list ownership.

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
