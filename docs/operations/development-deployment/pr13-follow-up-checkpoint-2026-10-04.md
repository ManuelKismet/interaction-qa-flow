# PR13 follow-up checkpoint — 2026-10-04

This is a source and test update for the existing draft PR, not acceptance of a
development deployment. No production configuration, organisation membership,
test accounts, or persisted data were changed.

## Addressed in this follow-up

- Corrected the malformed widget-tree closures reported in
  `guest_workspace_page.dart` and `guided_page.dart`.
- Renamed the guest-link action to **Create account from this guest**. On
  successful linking the app requests email verification when needed, refreshes
  the Firebase user, reports the result, and returns to the guest workspace.
  Verification-send and refresh failures are reported separately. Cancelling
  separate-account creation now explains that guest identity, group access, and
  local work are unchanged.
- Kept local work explicitly device-local; account linking does not upload it
  or create organisation membership.
- Made registered-account guest-group lookup failures visible and retryable
  without interpreting a failed lookup as “no groups.” Error text is sanitized.
  The shared-groups page also no longer shows its empty-state message while the
  group lookup is failing.
  The client requests `/api/v1/guest/groups` with Firebase ID-token and App
  Check headers. The separately mounted API route validates those claims and
  lists groups by Firebase UID; this route does not require organisation
  membership. These source contracts do not establish why an unidentified
  development server returned an error.
- Added client/repository coverage for the guest-group route, token headers,
  sanitized authorization errors, and retryable lookup failures.
- Added a template-created all-participant report assertion for distinct answer
  owners, nested content, and print pagination rules. Clarified that direct
  download attempts to save a PDF file while browser print opens a separate
  report for the browser’s **Print → Save as PDF** flow. The web download anchor
  is now attached to the document while clicked, and the UI reports that a
  download was requested rather than claiming it completed.

## Verification status

The independent report for the exact prior head `0079511d244a1a8648e61f2cee4b1529ac89a9fb`
recorded 82 backend tests passing, 59 Flutter tests passing with five test files
failing to load, 21 analyzer issues, and a failed release web build due to the
reported syntax blockers. Those results apply only to that prior head.

In this coding environment, Flutter and Dart are unavailable. The added Flutter
tests, analyzer, and release web build have therefore not been run against this
follow-up. `git diff --check` is a source whitespace check, not a compilation or
runtime result. Backend code was not changed here; prior backend test results
are not a live-auth or guest-group acceptance test.

## Still blocked on independent environment checks

- Re-run backend and Flutter tests, analyzer, and release web build on the new
  PR head.
- Verify live guest-group listing, invitation, membership, conflict, and privacy
  behavior on the intended development build. The served source SHA was not
  identified, so the reported group request failure cannot be assigned to this
  PR source.
- Verify real email delivery with the founder’s real-account flow.
- Verify browser download behavior, rendered print-to-PDF pagination, full
  nested report output, and the guest backup/import menu on the served build.
  Source-level report and backup tests do not establish browser behavior.
- Complete the existing PR9 wide-screen outline/narrow-screen branch navigation
  and pending-edit-flush gaps separately; this follow-up does not claim them
  fixed.

## Independent continuation after reconnect

Codespace exact-head review of 7bcc6a4697b9cfaa7d134647f60042add9c211cb: targeted guest-group and guest-interact Flutter tests returned 9 passes / 1 failure. Opt-in sharing pumpAndSettle still times out at line 232 after opening the sharing dialog. Copilot notified in comment 5983061801. This revision is not signed off or deployed.

Deployed frontend remains 2351c97. Owner independently confirms approved isolated Contributor active. Isolated browser group and shared Knowledge reads return 200; attempting to PATCH owner Knowledge returns 403; admin invitation listing returns 403. Tested through normal Firebase/App Check SDK request headers, with no enforcement change. See codespace-appcheck-2026-10-04.md for setup, chronology, and lessons. Pending direct API denial, browser PDF download, and broader acceptance remain open.

Continuation: Contributor own create/edit/history passed (201/200/200). Owner entry detail hides Edit/Delete. Actual hosted Knowledge PDF download succeeded in isolated Codespace Chrome (9,155 bytes, %PDF- header), resolving that narrow download check; nested Interact PDF acceptance remains separate. See the App Check checkpoint for retained private evidence paths and remaining scope.

## Exact-head 10d0330 verification

Targeted guest UI tests: 10 passed. Full Flutter suite: 99 passed. Analyzer: exit 0 with --no-fatal-infos, 12 informational notices and no warnings/errors. Release web compilation: exit 0. Backend pytest initially stopped at conftest import because the reused environment lacked firebase_admin; declared requirements were installed and a retry is running. No backend pass claimed until retry completes. This compilation is not a deployed acceptance build; hosted frontend remains 2351c97.

Live stale-snapshot editing of disposable Contributor Knowledge accepted both updates (200/200, revisions 3→5) and retained the second as current. No revision precondition exists. Open concurrency finding sent to Copilot in comment 5983197884; history alone is not conflict prevention. Owner entry remains revision 1 and its Contributor edit denial remains 403.

Pending API-denial/revocation test requires a fresh disposable Contributor invitation, prepared in owner UI but not created. New security-sensitive invitation confirmation is pending. Nested Interact all-participant preview confirms answer-owned follow-up attribution; an isolated synthetic nested download/text inspection is in progress.

Backend retry completed: 82 tests pass, one warning, exit 0. Full exact-head compilation/test checks now pass. Live concurrency remains open. Nested Interact download retry remains unverified (TargetClosedError while saving after a download event), reported in comment 5983264529. Fresh pending-test Contributor invitation is prepared but awaits action-time confirmation; it must not approve the third test identity.

## dca98b7 and live pending/revocation acceptance

Exact head dca98b796e00b77b947b2176f9060df51ee884b3 passed 101 Flutter tests, 82 backend tests (one warning), analyzer --no-fatal-infos, and release build. Revision precondition is now required, and backend stale-write test confirms 409 with latest value/history preserved. Hosted 2351c97/older backend remains unchanged; coordinated rollout/old-client recovery must be planned for required expected_revision. Review reported in PR13 comment 5983409204.

Owner independently confirms Pending API acceptance guest remains contributor/pending. Normal isolated group list is empty. Eight direct routes (group detail, entries, entry detail, history, export, invitations, create, edit) deny with 404 / Guest group not found. No approval, no unauthorized writes.

Revocation acceptance passed: a separate identical-scope Contributor token previewed 200/valid=true before revocation; after owner revocation, preview is 200/valid=false and join is 404 / Invitation is unavailable. Redeemed same-identity retry returns 200/pending by design. A second unused token whose capture was overwritten was also revoked and replaced safely. Original older invitation remains unchanged. Nested Interact file download remains the separate unresolved acceptance limitation.

Invitation lifecycle completion: another identity cannot reuse the pending member's redeemed token (409 / Invitation has already been used). Same-identity replay stays pending; revoked-token preview invalid and join unavailable verified. Final owner view confirms no pending approval and only original older invitation active. Posted PR13 comment 5983427618. Remaining live gap is nested Interact PDF capture; final cleanup and coordinated concurrency rollout are pending.


## Nested PDF acceptance completed — 2026-10-04 19:20 UTC
Hosted dev nested Interact PDF downloaded through the normal UI with the existing isolated Contributor profile and App Check enforcement retained. Explicit accept_downloads=True on the persistent Playwright context resolved the earlier save_as failure; the earlier failure was a harness configuration issue, not a demonstrated application defect. Actual file: 9,358 bytes, PDF header valid, one page. PyMuPDF extraction confirmed both PDF Alice/PDF Bob attribution, both shared-root answers, two levels of Alice answer-owned follow-ups and their answers, and Bob-only unanswered prompt. Rendered page inspected in VSCode: no clipping or overlap observed for this fixture. Multipage pagination and unusual glyph coverage are not established by this one-page fixture.
Lesson: explicitly enable downloads in persistent browser acceptance contexts, and distinguish harness failures from product defects before reporting. Never mark PDF acceptance complete from preview text alone.
PR13 remains draft/unmerged at dca98b796e00b77b947b2176f9060df51ee884b3. Exact-head 101 Flutter / 82 backend tests, analysis and release build passed previously. Next: prepare coordinated dev frontend/backend rollout, assess cached old-client recovery for required expected_revision, live stale-update rejection, then disposable-fixture/debug-token cleanup. No merge or deployment performed.


## Coordinated dev rollout started — 2026-10-04 19:30 UTC
User authorized rollout and live verification. Exact dca98b7 backend image build passed (Cloud Build 4e16e542-2aef-4a6d-a380-f8050485e08e); matching Firebase-configured frontend release build passed with --pwa-strategy=none. Backend staged as intqaflow-dev-api-reviewdca98b7 with no traffic. Previous serving revision intqaflow-dev-api-reviewabb224f and Hosting sites/intqaflow-dev/versions/2be73b0d8df32cd9 retained for rollback. Coordinated publish launched with automatic backend rollback if Hosting publish fails. Pending: publish completion, live current/stale/missing-revision checks, frontend reload recovery and cleanup. PR remains draft/unmerged.


## Coordinated dev rollout and acceptance completed — 2026-10-04 19:35 UTC
User authorized coordinated rollout. Exact reviewed dca98b796e00b77b947b2176f9060df51ee884b3 deployed to dev only; PR13 remains draft/unmerged. Backend intqaflow-dev-api-reviewdca98b7 serves 100% traffic. Hosting release sites/intqaflow-dev/releases/1791142233375000, version sites/intqaflow-dev/versions/af3d426e061782b0, 36 files. Both release builds passed. Prior backend reviewabb224f and Hosting version 2be73b0d8df32cd9 retained for rollback.
Live normal Firebase SDK/App Check Contributor checks: current-revision update 200, stale-snapshot update 409, missing-revision old-client request 422. Entry revision 5→6, newer data retained, rejected requests did not increment revision. Owner reload retained original local draft and group access. Ordinary updated frontend edit of disposable entry saved revision 7. Original owner shared entry remained revision 1.
Compatibility limitation: old already-open clients cannot edit until reload; missing expected_revision fails closed with 422. Reload recovery and ordinary frontend save verified; no automatic old-client upgrade UX claimed. Deployment used existing no-service-worker build and max-age=300 Hosting configuration. App Check enforcement and server authentication remain enabled.
Cleanup: remaining test invitation revoked; owner member view has no active invitations. Disposable active Contributor removed from group; pending guest never approved. App Check debug-token DELETE returned 200 and GET postcheck 404; private debug/invitation token files and both isolated Codespace Chrome profiles removed. Synthetic shared revision-history fixture and pending membership retained for traceability; owner data retained. Temporary build Docker files removed from review checkout. No old-PC database cleanup performed because that device is not accessible here.
Lessons: stage reviewed backend with no traffic; capture rollback IDs before coordinated contract changes; verify stale and legacy writes preserve newer content, and test ordinary UI save after reload. Revoking debug token prevents new exchanges; already issued short-lived tokens can remain valid until expiry, so disposable member access was separately removed.
