undefined

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
