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
