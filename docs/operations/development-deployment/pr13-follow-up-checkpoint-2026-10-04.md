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
