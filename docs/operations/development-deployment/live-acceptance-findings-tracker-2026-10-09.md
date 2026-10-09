# Live acceptance findings tracker — 9 October 2026

Source: live-workspace-acceptance-2026-10-09.md, through commit 077f02f.
Process: handle one numbered item at a time. Implementation does not establish hosted verification. Keep every row until its outcome and evidence are recorded. F01–F09 have been authorized individually. User instruction: resolve the findings one at a time, then deploy the validated fixes together to DEV; no interim deployments.

| ID | Finding or behavior | Status |
| --- | --- | --- |
| F01 | Reload loses organisation question / organisation Interact / Personal Interact route | Fixed / automated-validated in PR #22; held for combined DEV confirmation |
| F02 | Another creator's private organisation session stays on a spinner | Fixed / automated-validated in PR #23; held for combined DEV confirmation |
| F03 | Requests you can review remains stale after request submission | Fixed / automated-validated in PR #24; held for combined DEV confirmation |
| F04 | Request cards show UUIDs rather than requester/team names | Fixed / automated-validated in PR #25; held for combined DEV confirmation |
| F05 | Repeated Interact-to-Knowledge proposals create duplicate pending proposals / unclear immediate feedback | Fixed / automated-validated in PR #26; held for combined DEV confirmation |
| F06 | Redeemed invitation still previews as valid although join rejects cross-account reuse | Fixed / automated-validated in PR #27; held for combined DEV confirmation |
| F07 | Registered Group member removal says guest member | Fixed / automated-validated in PR #28; held for combined DEV confirmation |
| F08 | Personal Interact Undo restores local content without restoring account persistence | Fixed / automated-validated in PR #29; held for combined DEV confirmation |
| F09 | Non-owner admin role-editing controls offered although server rejects with 403 | Fixed / automated-validated in PR #30; held for combined DEV confirmation |
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


## F02 automated validation completed — 9 October 2026

Final source/test commit 23ccfee5a5748eaf446f51616d24e06ae736f49e; GitHub Actions Private session denial validation run 37957307102, job 113910975134: 81 Flutter tests passed (guided_safety_test.dart, guided_page_test.dart, session_deep_link_test.dart); formatting gate passed. Covers owner/employee 403 and 404, no automatic denial retry across 10 seconds, no content/export/write exposure, explicit Try again, Back to Interact, transient 503 recovery, and the existing identity/authority safety and reload regressions. Backend validation run 37957308347 passed. Fresh local isolated API run: tests/test_guided.py and tests/test_guided_safety.py => 41 passed in 5.00s (SQLite/test authentication; not hosted acceptance).

Earlier CI runs failed new test setup/count assumptions, not the existing suite: settle authority by pumping Flutter's fake async zone, and distinguish the successful page's participant-scoped read from retries of the original query. These corrections retained strict single-read denial and two-read original-query recovery assertions. Final complete suite passed; earlier running/failure text is superseded.

F01/F02 are source-fixed and automated-validated, not hosted-verified. Per user instruction, hold all deployment until the findings have been addressed, then perform one combined DEV rollout and hosted retests. F03–F14 and C01–C06 stay tracked. No merge or deployment performed.

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
