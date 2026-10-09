# Live acceptance findings tracker — 9 October 2026

Source: live-workspace-acceptance-2026-10-09.md, through commit 077f02f.
Process: handle one numbered item at a time. Implementation does not establish hosted verification. Keep every row until its outcome and evidence are recorded. Only F01 is authorized for implementation now.

| ID | Finding or behavior | Status |
| --- | --- | --- |
| F01 | Reload loses organisation question / organisation Interact / Personal Interact route | Implemented on fix/reload-route-20261009; Flutter and hosted validation pending |
| F02 | Another creator's private organisation session stays on a spinner | Pending |
| F03 | Requests you can review remains stale after request submission | Pending |
| F04 | Request cards show UUIDs rather than requester/team names | Pending |
| F05 | Repeated Interact-to-Knowledge proposals create duplicate pending proposals / unclear immediate feedback | Pending |
| F06 | Redeemed invitation still previews as valid although join rejects cross-account reuse | Pending |
| F07 | Registered Group member removal says guest member | Pending |
| F08 | Private-session Undo restores local content only, not account persistence | Pending behavior review |
| F09 | Non-owner admin role-editing controls offered although server rejects with 403 | Pending; historical state, non-owner UI not retested |
| F10 | Inaccessible Group deep link silently falls back to another approved Group | Pending |
| F11 | Guest reload returns Knowledge; saved Interact can be reopened | Pending behavior review; reopening previously accepted |
| F12 | Team assignment is routing/governance metadata, not exclusive read scope; department assignment alone also is not department visibility | Pending behavior review; current policy verified |
| F13 | Completed Interact remains editable | Pending behavior review; current design |
| F14 | Restoring employee role leaves separate department-answer-owner assignment until explicitly removed | Pending behavior review; cleanup completed |

## F01 implementation

Capture initial location in a non-auto-disposed provider at the first app build, before authentication/membership MaterialApps can replace the browser URL. Router consumes that captured location. Preserve registered app question/session/workspace paths and hash routes, including query parameters. Hash route takes precedence over hosting-document path. Unknown/malformed routes fall back to root; normal content authorization still handles unknown identifiers.

Changed app.dart, app_router.dart, session_deep_link.dart and session_deep_link_test.dart. Added a focused routing/account-startup CI workflow. No behavior or permissions for F02–F14 changed.

Validation so far: production route resolver executed with Dart 3.11.1: 38 route assertions passed. Dart formatting and git diff --check pass. Added five widget regressions for delayed router creation after auth loading, and path/hash/query/invalid-route checks. Local Flutter suites cannot yet run: no package config/cache; Flutter tool attempts to resolve its own dependencies even with offline app pub get. Both stalled setup attempts stopped. GitHub validation and hosted DEV retest pending; no deployment performed.

## Coverage ledger (not application defects)

- C01 Physical-phone/narrow-screen acceptance: outstanding.
- C02 CSV clipboard delivery: unverified.
- C03 Browser print output and pagination: unverified.
- C04 Organisation session archive mutation: not exercised.
- C05 Raw hosted API denial statuses/export/history calls: not directly asserted; local API cases passed.
- C06 Permanent Group deletion database cascade: not independently asserted; hosted UI deletion passed.

Corrections retained: duplicate membership requests and self-approval bypass were not established defects. Earlier sign-in typo/stale pre-verification state did not establish App Check/cloud-browser rejection. Earlier full-suite failure gate was resolved by 392 Flutter/201 backend release passes.
