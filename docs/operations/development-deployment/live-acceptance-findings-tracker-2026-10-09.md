# Live acceptance findings tracker — 9 October 2026

Source: live-workspace-acceptance-2026-10-09.md, through commit 077f02f.
Process: handle one numbered item at a time. Implementation does not establish hosted verification. Keep every row until its outcome and evidence are recorded. F01 and F02 have been authorized individually. User instruction: resolve the findings one at a time, then deploy the validated fixes together to DEV; no interim deployments.

| ID | Finding or behavior | Status |
| --- | --- | --- |
| F01 | Reload loses organisation question / organisation Interact / Personal Interact route | Implemented; automated validation passed; DEV deployment / hosted reload retest pending |
| F02 | Another creator's private organisation session stays on a spinner | Implemented in PR #23; automated validation running; held for combined DEV deployment |
| F03 | Requests you can review remains stale after request submission | Pending |
| F04 | Request cards show UUIDs rather than requester/team names | Pending |
| F05 | Repeated Interact-to-Knowledge proposals create duplicate pending proposals / unclear immediate feedback | Pending |
| F06 | Redeemed invitation still previews as valid although join rejects cross-account reuse | Pending |
| F07 | Registered Group member removal says guest member | Pending |
| F08 | Private-session Undo restores local content only, not account persistence | Pending behavior review |
| F09 | Non-owner admin role-editing controls offered although server rejects with 403 | Pending; historical state, non-owner UI not retested |
| F10 | Inaccessible Group deep link silently falls back to another approved Group | Pending |
| F11 | Guest reload returns Knowledge; saved Interact can be reopened | Pending behavior review; reopening previously accepted |
| F12 | Knowledge question team/department assignment alone does not restrict organisation-visible questions; Interact separately supports explicit team visibility | Pending behavior review; current policy verified |
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

## F01 automated validation completed

GitHub Actions routing run 37954911646 / job 113902856678 succeeded on PR #22 source b1f02a443c2deb8b029bcbe4324dc3c5d1bc1905 (merge ref 6e1b342b8fbf8daddca22cfc6ade67b62f337850). Flutter 3.41.4: 81 routing/account-state tests passed, including all five new authentication-loading route regressions. Formatting gate passed. Backend validation run 37954911649 also succeeded. Production parser's 38 direct Dart assertions and isolated analysis passed locally. Earlier pending CI text is superseded. F01 is not yet deployed or hosted-verified; F02–F14 unchanged.

## F02 implementation / combined deployment instruction

PR #23, fix/private-session-denial-20261009, stacked on PR #22. Session-detail provider stops automatic retry on ApiException 403/404; other errors retain ProviderContainer.defaultRetry. Error view gives a safe unavailable/no-permission message and Back to Interact, retaining explicit Try again. Backend private-session rules remain unchanged. Added owner/employee x 403/404 regressions with production retry enabled, no title/response/export/write exposure, no automatic replay, explicit retry and return navigation; transient 503 still recovers. Guided safety/page and route CI running. No merge/deployment. F01 remains automated-validated; F03–F14 pending. F12 wording clarified to Knowledge questions: backend GuidedSessionVisibility separately includes TEAM.
