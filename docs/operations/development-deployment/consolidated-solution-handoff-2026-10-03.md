# Recommended IntQAFlow solution and consolidated implementation handoff

Date: 3 October 2026. Founder requested a consolidated solution, all earlier/new findings, simple UI/UX refinements and Copilot implementation followed by independent Codespace verification.

## Product aim

Knowledge answers recurring organisational questions with reusable, governed answers. Interact captures a planned conversation, independent participant answers and unexpected answer-owned follow-ups, then permits deliberate promotion of selected content into Knowledge. These are two connected modules. Keep solo-local use useful without registration; cloud sharing is explicit. Avoid new product modules, generative AI, document ingestion or unrelated features.

## Work ownership and source

Copilot owns application code/tests and reviewable draft changes. Codex owns environment/configuration and independent Codespace/hosted-dev verification. Founder + Codex review acceptance. Start from combined df6bcd3026295e9f492d140282376c927bb66844, preserving guest, printable reports and retention. Existing guest implementation is active in draft PR13, based on PR12; continue it rather than creating competing versions. Use sequential draft follow-ups for security/governance/operations if needed and state exact dependency chain.

Sources: original IQ audit on docs/intqaflow-operating-audit-2026-09-30; current code df6bcd3; dated deployment/acceptance records on chore/intqaflow-private-dev-isolation; guest-product-ux-review-2026-10-03.md. Do not treat historical states as current defects or ordinary test success as browser/security acceptance.

## Recommended flow and permission design

1. **Identity and account state:** lightweight Account menu with display name, registered/guest state, current workspace and authoritative role. Clearly labelled Sign in, Create account, recovery and Sign out. Distinguish no membership, inactive membership, loading and service errors. No auto-enrolment from signup, email domain or client-selected IDs. Do not add unsupported profile edits.
2. **Solo guest:** Knowledge/Interact usable immediately, browser-local save and clear backup/recovery notices. No automatic upload on login, rendering, template creation or sharing entry.
3. **Shared groups:** retain anonymous device identity plus invitation/approval. Recommend also permitting a verified registered personal identity to create/join shared groups explicitly, so signing up does not remove collaboration capabilities. Both identities use the same individual group memberships and bounded roles; possessing a token or invitation does not grant org/private access. If implementing this narrow capability, replace only the anonymous-only create/join restriction with verified identity + existing server membership/approval checks, update UX and add anonymous/registered positive and cross-group/org negative tests. Never silently sign a registered user out or auto-transfer guest memberships. Existing-account link conflicts must remain deliberate.
4. **Organisation:** active server-controlled membership, one primary department and multiple teams. Admin-managed department/team/member assignment. Implement the smallest safe UI/API gaps for managing membership and primary-department assignment, keeping all mutation endpoints admin-only and audited. Initial organisation provisioning stays operator-controlled; document its onboarding/runbook rather than re-enabling an unauthenticated bootstrap. A self-serve company onboarding system is out of this iteration.
5. **Sharing:** one understandable audience control for Private / Team / Department / Organisation in both modules. Implement actual TEAM visibility for Knowledge with safe enum/schema/index migration and exact team-membership filters before displaying team-private UI. Existing team tags retain their old visibility; never silently reclassify content. Team membership does not grant department visibility; department membership does not grant each team's private work. Private remains owner-only even against org admins. Preserve current admin-read boundaries; source differs between Knowledge and non-private Interact. Disclose existing exceptions and propose any admin-policy change separately instead of silently broadening reads.
6. **Access versus actions:** keep read, contribute/edit, manage membership and verify/review distinct. Team membership is not department answer-owner authority. Viewer/shared access does not automatically grant mutation. Department answer-owner proposal review should follow documented explicitly assigned departmental governance, including a team's parent department where already defined; cross-functional/no-department cases remain admin-governed. Reviewers receive the deliberately submitted proposal, not unrelated private session content.
7. **One privacy policy everywhere:** enforce audience before pagination/search/retrieval and on direct IDs, answers/comments/reactions, canonical/alias traversal, proposals, history, export and any subscriptions. Membership removal denies subsequent requests and invalidates inaccessible cached views. Previously downloaded copies cannot be revoked.

This design adds genuine team privacy and coherent verified-identity group use; it does not grant access by labels, inferred memberships or arbitrary account creation.

## Priority A: privacy and reliability

- Add Knowledge TEAM visibility and shared audience explanations with the matrix above. Audit metadata/content scope transitions; reject invalid team/department/null/foreign-org references. Migration must preserve historical rows and require independently reviewed hosted-dev execution.
- IQ-03/04/05: retain corrected private/department/null/canonical boundaries. Current CanonicalService._root checks each parent visibility, so the historical canonical-target issue is not simply still unfixed. Rerun focused regressions on submitted final source; do not remove those guards while adding TEAM.
- IQ-06: current GuidedKnowledgeService list_proposals and decide still admin-only. Implement documented department-answer-owner review with tenant/scope checks and tests, not a blanket answer_owner grant.
- IQ-07: original missing-key/embedding-error proposal acceptance issue needs targeted current-source reproduction and correction if present. QuestionService now catches EmbeddingProviderError/ValueError without rollback, but SQLAlchemyError still rolls back/refreshes only the question; do not claim the old failure unchanged without testing. Ensure proposal acceptance is atomic and retry-safe with no half-created duplicate Knowledge across provider failure and transaction errors. Keep external embeddings best-effort and fake provider for dev; no paid calls.
- IQ-08: current GuidedService.export_csv writes user-controlled title/name/question/answer through csv.writer unchanged. Implement a documented spreadsheet-safe text encoding policy for all user-controlled columns (including formula prefixes and leading control/whitespace variants). JSON stays faithful. Test parsed output and scope authorization; quoting alone is insufficient.
- Auth/membership/cache transitions: implement accurate account states and preserve private identity-scoped data boundaries. Real sign-in/account-link/conflict/cache browser acceptance remains deferred, not passed.

## Priority B: conversation workflow and simple UX

Continue prior approved scopes in PR13:
- Active participant selection; targeted question for any participant; independent answers and recursive answer-owned follow-ups.
- Templates preserve question graph, shared/individual scope and participant-slot relationships, clear response text, remap fresh IDs and keep existing backups/templates compatible. Original sessions must not change.
- Readable solo reports with current/all-participant scope, attributed nested prompts, unanswered items and escaped output. Reuse reviewed printable HTML where possible; JSON remains export/backup, not the user report.
- Backup/import: make valid selected round trips reliable/idempotent; malformed data produces useful errors without partial mutation. Browser malformed-JSON rejection already observed. Clipboard copy/download and full legacy/native round trips remain unverified.
- Spacing proposal: small consistent scale such as 8px within related actions, 12–16px between form fields, 16–24px between sections; adapt existing theme rather than forcing arbitrary exact values. Use a constrained reading width, wrapping participant/action controls, clear headings, one primary action, secondary menus for less-used actions, modest cards and progressive disclosure. Avoid all sessions/branches expanded by default when it overwhelms; preserve unsaved edits on collapse/navigation.
- Responsive/accessibility: desktop and narrow/mobile, long labels, deep branches, keyboard/focus, labelled account actions, touch targets and no misleading checkbox semantics on static labels. Branch parent/participant context stays visible; do not trade clarity for compactness.

These are recommendations from current desktop observations; mobile spacing is not a confirmed pass or defect.

## Priority C: remaining older audit items

| ID | Current evidence / disposition | Work |
|---|---|---|
| IQ-01 | Startup fix and later passing suites recorded | Preserve, clean-import regression; no duplicate fix |
| IQ-02 | Verified Firebase UID identity implemented; live smoke denies missing credentials | Verify invalid/wrong-project/revoked/inactive/unmapped identity and production fail-closed configuration; retain App Check mode |
| IQ-03 | Ordinary visibility fixes plus current canonical parent guards | Final expanded privacy matrix including TEAM |
| IQ-04 | Non-null department checks present in reviewed Interact code | Preserve creation/import/list/report/export tests |
| IQ-05 | Private sessions owner-only in current code | Preserve against admin; no bypass |
| IQ-06 | Admin-only proposal review still source-confirmed | Bounded department answer-owner review |
| IQ-07 | Provider handling changed; transaction rollback path remains | Reproduce then fix atomicity/outage/retry |
| IQ-08 | Raw CSV columns source-confirmed | Spreadsheet-safe text exports |
| IQ-09 | Fake embeddings in dev; provider policy not accepted | Document exact external payloads, visibility, endpoint/credentials, allowed content and deletion/rebuild; no activation |
| IQ-10 | _save_revision stores summary change labels | Accurately label activity history and remove snapshot/restore promises; retain backups and immutable template snapshots. Do not build broad time-travel restore in this iteration |
| IQ-11 | Independent tests/build exist; enforced CI/protection not confirmed | Add repeatable backend import/tests + Flutter analyze/tests/build CI. Prepare migration-check runbook; no automated reset/apply against hosted dev. Branch protection/settings remain separately reviewed |
| IQ-12 | /health only status/environment | Keep liveness; add bounded database/schema readiness with sanitized 503 failure, tests and alerting runbook. No credential/internal detail disclosure |
| IQ-13 | requirements mostly ranges | Commit reproducible supported backend dependency resolution/lock; verify supported runtime and upgrade procedure |
| IQ-14 | Dev inventory/backups/rollback/retention dry run exist | Complete precise retention/recovery inventory and synthetic restore-drill plan; code/tests/docs within scope, actual infrastructure drill/scheduler/purge deferred |

Physical guest retention cleanup already implemented/reviewed; preserve dry-run default, batch limit, locking, scope and unscheduled status. Do not build it again or execute apply.

## Acceptance and review

Submitted artifact must include source commit, base/dependencies, changed scope, exact available tests and unresolved/unavailable checks. Independent Codespace verification follows: clean import/dependencies, backend suite, targeted privacy/governance/export/outage tests, Flutter analyzer/test/release build, migration review against hosted intqaflow_dev as explicitly authorized. No disposable local PostgreSQL requirement.

Privacy matrix: Team A/B same department, another department, multi-team, departmentless, owner, org admin, scoped answer owner and foreign-org identity; private/team/department/org content in both modules; list/search/direct/canonical/children/proposals/history/export, edits and membership removal. Group matrix: anonymous and registered verified identities, two groups, host approval/roles/removal/revocation, no org/private grant. Distinguish in-process/mock tests from real Firebase/browser evidence.

Real multi-profile browser checks and admin sign-in are currently blocked/deferred. Rendered PDF needs actual preview/download output; do not count widget/HTML tests as PDF pagination.

No merge/deploy/production release, IAM/Firebase/App Check changes, paid provider, database reset, retention purge/apply or scheduler activation. Application migrations may be written but not applied by Copilot. Preserve existing work and checkpoints.

## General product recommendation

Finish a complete, understandable Knowledge/Interact loop before adding more integrations: ask/find an answer, run a structured conversation, capture unexpected branches, deliberately promote useful knowledge, and make the audience obvious. Trustworthy privacy and predictable account state are core product behavior. Reuse existing components and reduce competing actions; a lightweight Account menu and Sharing summary are more valuable now than a large profile/settings system.
