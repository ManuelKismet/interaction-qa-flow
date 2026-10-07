# Interact parity audit — 2026-10-07

## Scope and authority

Founder requested complete Interact parity analysis with **no implementation**, then authorised documentation/checkpoint updates. This records a read-only review across guest, verified registered personal, organisation and shared Groups. It is not an implementation assignment or deployment approval.

Reviewed complete source: **7aac21fad638570cf6f60a5dad478b776278c603**, tree **48a205f417aad95cb34197dc7737c24924ba57d2**, branch `fix/unified-search-dev-20261006`; branch head rechecked when publishing these docs. Documentation is maintained on `docs/user-admin-e2e-checkpoint-20261004`.

**Conclusion: core participant/question/answer/follow-up concepts align, but full functional and UI/UX parity is not established.** Local/private/organisation permissions and explicit import boundaries are intentional. “Seamless across all users” must not imply identical capabilities, automatic migration or collaborative editing.

Evidence labels:
- **SOURCE**: behaviour or missing UI established by reading the pinned source; not newly reproduced in hosted DEV.
- **RISK**: plausible failure requiring a targeted reproduction.
- **DECISION**: product/workflow difference requiring an explicit scope choice before implementation.
- **OPEN**: missing acceptance evidence.

No new backend, PostgreSQL, Flutter, analyzer, release or hosted functional checks were executed for this audit. Prior 126 backend / 190 Flutter passes and analyzer 0 errors / 0 warnings / 13 existing infos are rollout evidence, not complete parity acceptance.

## Feature matrix

Registered personal means the user's private account workspace; an organisation member can also use this separate workspace.

| Capability | Guest | Registered personal | Organisation |
|---|---|---|---|
| Shared / participant questions, participant-specific answers, recursive answer-owned branches | Supported | Supported | Supported |
| Switch participants and collapse branches | Supported | Supported | Supported |
| New session and storage | Browser-local | Starts local; explicit selected import creates account copy, retains local original | Backend draft, private by default; explicit visibility |
| Participant management UI | Add, switch, rename | Add, switch, rename | Add and switch; API rename/remove not exposed |
| Session lifecycle | No formal status workflow; local deletion/Undo | No matching status workflow | Draft/active/completed; archive not fully exposed |
| Templates | Save existing session as reusable template, stripping answers | Same plus selected account import | Versions, duplicate, archive/restore; different creation path |
| Reports | Participant/all participants; PDF download/share/print fallback | Same shared report path | Participant/all participants; browser print/Save PDF |
| JSON/CSV | Local workspace JSON backup/paste import | Local backup excludes account-only copies | Distinct session JSON/CSV copy export and legacy importer |
| Save recovery/history | Local save failure/retry | Expected-revision conflicts and pending-edit recovery | Audit history; no comparable pending-edit recovery or restorable session snapshots |
| Knowledge integration | Separate Knowledge tab | Separate Knowledge tab | In-editor Check Knowledge / Propose for Knowledge |
| Navigation/views | Expand sessions in workspace | Same; separate personal navigation for org members | Dedicated session route; All relevant / Shared only / This participant filters and progress |
| Group sharing | Explicit shared entry copies | Explicit shared entry copies | Group sharing remains separate from organisation authority |

## Findings and acceptance criteria

| ID | Priority / evidence | Finding and effect | Required verification or decision; NOT assigned |
|---|---|---|---|
| IP01 | P1 SOURCE | Organisation session/template controls use membership role `admin`; backend recognises active owner or explicit legacy_admin grant. Valid non-admin-role owners/grant holders can lose controls; role-only admin can see server-denied controls. Backend enforcement remains intact. | Align UI to actual capabilities; owner, grant holder, role-only, revoked and private creator/non-creator matrix. Do not assume every scoped delegate is a generic Interact administrator. |
| IP02 | P1 SOURCE | Organisation debounced field saves only non-empty trimmed values. Erasing an answer sends no update, leaving stored answer unchanged. | Save blank answer, reload and verify cleared value; maintain appropriate non-empty question validation separately. |
| IP03 | P1 SOURCE / RISK | Pending 650ms timer is cancelled on field disposal without flush. No equivalent personal pending-edit retry/reconcile flow. Field controller also lacks update reconciliation. | Rapid navigation/close, failed request/retry, external refresh, concurrent edits; verify final persisted values and truthful save status. Session metadata has optional expected_revision; answer mutations do not expose that same check. Do not claim all organisation revisions lack concurrency support. |
| IP04 | P1 SOURCE | Guest backup, organisation session envelope and legacy importer use incompatible structures. Legacy importer expects root meta/participants/flow, can create an empty/default draft with warnings for incompatible objects. Flutter repository discards response warnings. | Accepted/rejected schemas explicit; round-trip fixtures retain participants, targets, nested branches, answers and metadata; incompatible input gives visible diagnostics, not silent success. No original-data overwrite was established. |
| IP05 | P2 SOURCE / DECISION | Shared Group Interact entry editor changes title only; questions/answers remain unchanged. Entries are copies, not the full session editor or live collaboration. | Decide snapshot sharing versus editable collaborative session; label behaviour accurately and preserve independent group permissions. |
| IP06 | P2 SOURCE | Personal-account question/follow-up removal still announces “Local … removed.” | Correct storage-specific feedback; verify local and private account copies independently, without automatic upload. |
| IP07 | P2 SOURCE / DECISION | Template capabilities differ: guest/personal session-to-template creation versus org version governance. Org has no equivalent save-current-session-as-template action. | Define common authoring operations and intentional governance differences; test scopes, answer stripping, branch preservation and version pinning. |
| IP08 | P2 SOURCE / DECISION | Organisation completed status does not itself disable editing; archive/reopen/recovery UI and guest/personal lifecycle differ. Audit history is not restorable session content. | Define completed/editable/archive semantics and recovery expectations; distinguish template snapshots, audit records and recoverable session versions. |
| IP09 | P2 SOURCE / DECISION | Org participant rename/remove and session metadata APIs are not surfaced. Reports/export mechanisms and personal account backup coverage differ. | Decide required common controls; test actual PDF/JSON/CSV outputs and discoverability, including account-only data. |
| IP10 | P2 SOURCE / DECISION | Two editor implementations produce different layouts, filters, save messages, reports and navigation. No universal cross-workspace session list/deep link or automatic conversion. | Consistent core editing, labels and save/report workflows; explicit Local / Private / organisation destination; personal/org navigation acceptance. |
| IP11 | P2 RISK / OPEN | Guided providers/repository lack the explicit expected-UID response guard used in newer account paths. Root UID-keyed scope reduces risk but does not establish all delayed request/session transitions are safe. | Delayed read/write during UID, org, permission and session changes; verify no stale render or wrong-identity mutation. No cross-account disclosure has been demonstrated. |
| IP12 | P2 OPEN | Full hosted cross-role, multi-device and accessibility/mobile parity is not proven by existing passing suites. | Test owner/grant/member/read-only/private actors, personal imports/edits across devices, keyboard/screen reader, narrow dialogs and report flows. |

## Source anchors and test evidence

- [Organisation session editor](https://github.com/ManuelKismet/interaction-qa-flow/blob/7aac21fad638570cf6f60a5dad478b776278c603/apps/flutter_app/lib/features/guided/presentation/guided_session_page.dart): canEditSession, _save, _DebouncedField._changed/dispose; lifecycle/report controls.
- [Organisation list/templates UI](https://github.com/ManuelKismet/interaction-qa-flow/blob/7aac21fad638570cf6f60a5dad478b776278c603/apps/flutter_app/lib/features/guided/presentation/guided_page.dart): template role checks and legacy import.
- [Permission service](https://github.com/ManuelKismet/interaction-qa-flow/blob/7aac21fad638570cf6f60a5dad478b776278c603/backend/app/services/permissions.py): is_organisation_admin owner/grant authority.
- [Guided service](https://github.com/ManuelKismet/interaction-qa-flow/blob/7aac21fad638570cf6f60a5dad478b776278c603/backend/app/services/guided.py): owned-session policy, export_json/import_legacy, session/template lifecycle, audit revisions.
- [Guided schemas](https://github.com/ManuelKismet/interaction-qa-flow/blob/7aac21fad638570cf6f60a5dad478b776278c603/backend/app/schemas/guided.py): metadata expected_revision versus answer update fields.
- [Guided repository](https://github.com/ManuelKismet/interaction-qa-flow/blob/7aac21fad638570cf6f60a5dad478b776278c603/apps/flutter_app/lib/features/guided/data/guided_repository.dart): importLegacy drops warnings, request options and surfaced API operations.
- [Local/personal/Groups UI](https://github.com/ManuelKismet/interaction-qa-flow/blob/7aac21fad638570cf6f60a5dad478b776278c603/apps/flutter_app/lib/features/guest/presentation/guest_workspace_page.dart): local creation, selected import, pending personal writes, backup source, removal messages, title-only Group Interact editing.
- Existing guest helper/widget tests cover participant ownership, recursive branches, template answer stripping, reports/PDF, narrow layouts and local save/disposal failures.
- Account-state tests cover imported nested private-session editing, UID isolation and revision conflict recovery.
- Guided UI/session/template tests cover participant views, collapse, debounce, narrow layout, report/export, retry and old-role owner/non-owner controls. They do not prove the IP01 owner/grant authority matrix or IP02 blank-answer persistence.
- Backend guided tests cover participant targeting, privacy/tenant boundaries, templates, legacy imports, lifecycle, exports and Knowledge proposals. Historical passing checks remain scoped evidence.

## Runtime and handoff boundaries

This audit did not alter runtime. Latest recorded rollout is source 7aac21fad638570cf6f60a5dad478b776278c603, Cloud Run `intqaflow-dev-api-review7aac21f` at 100% traffic, additive schema0015, Hosting release1791372154776000 / version8dc80b67398948f1 on both DEV origins. Exact bundle hashes, runtime-preservation and database evidence remain in [the rollout checkpoint](unified-knowledge-search-checkpoint-2026-10-06.md); not freshly measured here.

No application/test edits, Copilot request, new task/session, deployment, merge, production change, live owner appointment, content upload or schema downgrade. Codespace remains last-confirmed stopped; no temporary database/proxy started. Main worktree's dirty docs were not touched.

F04/F08/F09 and hosted personal/organisation-role acceptance remain open. Existing founder-authorised organisation implementation and its rollout are not revoked or marked failed by this audit; this adds an Interact assessment, not a new implementation scope. Real semantic provider work remains deferred until first customer; fake embeddings do not prove meaning matching. Monitoring remains cancelled.

Next implementation work requires founder authorisation. When authorised, prioritise IP01–IP04, consolidate exact-baseline requests to Copilot, then independently verify changes before any separately authorised DEV rollout.

## Founder additions and consolidated final-review register — 2026-10-07

Founder requested preservation of IP01–IP12, added IP13–IP23, and authorised work after final review, with regression protection and no repetitive implementation. These additions broaden scope into workspace navigation and personal Knowledge. User-observed symptoms below are not automatically reproduced defects.

| ID | Evidence / proposed outcome |
|---|---|
| IP13 | Groups belongs under Personal workspace rather than a global main navigation destination. Preserve guest Group access and organisation members' separate personal access; moving navigation must not require registration for existing shared-guest usage. |
| IP14 | Remove the separate Groups search field; existing unified Ask & search covers accessible Group Knowledge. Preserve Group source labels, membership enforcement and navigation; reuse retrieval. |
| IP15 | Move secondary explanatory text behind accessible info icons; essential instructions, errors, privacy and save status remain visible. Inventory actual pages before edits. |
| IP16 | Workspace-aware navigation: personal Knowledge/Interact/Groups versus organisation Knowledge/Interact/governance; clear switcher and destination. Consolidate with IP10/IP13. |
| IP17 | New registered personal work defaults to private account storage; guest originals stay local and selected imports remain explicit. Preserve account conflict recovery, identity isolation, sign-out behavior and existing data. |
| IP18 | Personal Knowledge adopts Ask & search / Questions and private-by-default creation using existing unified search. Preserve source navigation and explicit sharing; guests remain local. Consolidate with IP14/IP17. |
| IP19 | Dedicated session editor across workspaces rather than expanding personal sessions inline. Organisation already has a dedicated route: reuse its established navigation behavior. |
| IP20 | Natural flow: add participants, select active participant, add shared/participant questions, then answers/follow-ups. Remove mandatory prepared-question step/terminology, not underlying question semantics or optional templates. |
| IP21 | Keep shared/participant question actions reachable during scrolling; clearly display active participant and avoid covering editor/keyboard. |
| IP22 | Full phone responsive review: navigation, narrow dialogs, touch controls, keyboard, scrolling, reports and deep branches. Consolidate with IP12 and existing responsive work. |
| IP23 | User reports questions not editable. SOURCE final review: guest/personal _GuestQuestionEditor renders question title as Text with deletion, but no title-edit control; organisation _QuestionCard already uses _DebouncedField for question.text when editable. Implement missing guest/personal editing; diagnose organisation permissions/discoverability/save behavior before adding duplicate controls. Preserve answers, targets and branches. |

### Final-review progress and implementation grouping

GitHub recheck confirms current complete development source remains 7aac21fad638570cf6f60a5dad478b776278c603; original IP01–IP12 audit therefore remains applicable. Documentation branch is separate. Existing rollout evidence is 126 backend / 190 Flutter passing; this turn has not rerun tests or hosted acceptance.

Read current app_shell.dart, app_router.dart, guided_session_page.dart and guest_workspace_page.dart. Groups remains a global destination for verified registered users; organisation question editing exists; personal question title editing is missing. Open PR13/19/20 and older chained PRs are historical carriers, not proof of active pending jobs; use checkpoint/source provenance, not open state, before assignment. Do not restart quarantined PR13.

Implementation batches, retaining all IDs:
1. Persistence, permission and interchange safety: IP01–IP04, IP11 and the relevant IP12 regressions.
2. Workspace shell, registered storage and Knowledge: IP10, IP13–IP18; establish private creation/storage before navigation redesign.
3. Interact editor consistency: IP06–IP09, IP19–IP23; one coordinated editor pass rather than repeated layout rewrites.
4. Group sharing product decision and final cross-role/device/accessibility acceptance: IP05, remaining IP12/IP22.

Before application handoff, finish targeted source/hosted review of new observations and record exact acceptance criteria. Scope safety tests to real permissions, blank saves, navigation/disposal, schema round-trips, stale identity, privacy/no implicit uploads, existing templates/reports/branches and account conflicts. Run affected checks then full backend/Flutter/analyzer/configured release gates for coherent batches; maintain rollback and data-preserving additive migrations. No full test run per small cosmetic change.

No new application edit, Copilot message/task, deployment or merge in this checkpoint update. Source review is in progress, not complete implementation or live validation. Real semantics remains first-customer deferred.

## Implementation authorised — 2026-10-07

Founder said “Okay, action improvements” after confirming four batches. IP24: meaningful contextual placeholders throughout, supplementing visible labels, never prefilled answers. IP23 confirmed missing editing applies to personal/guest Interact, not a new organisation editing feature. Batch 3 includes IP24. All 24 IDs retained. Batch 1 starts with IP01–IP04/IP11 and relevant IP12 regression coverage against complete base7aac21fad638570cf6f60a5dad478b776278c603. Existing guest originals/import boundaries and working functionality must remain intact. Implementation via one Copilot task per sequential batch; independent review and gates precede DEV rollout. No production/merge/destructive changes. Earlier analysis-only statements are historical, superseded by this explicit authorisation.

### Batch 1 started — 2026-10-07 20:03Z

ONE GitHub Copilot task created and UI verified Queued/Started: https://github.com/ManuelKismet/interaction-qa-flow/tasks/6e51ca93-7c0d-407f-94c3-b8ed6fc9afba . Selected branch fix/unified-search-dev-20261006; exact complete base7aac21f specified. Scope IP01-IP04/IP11 and relevant IP12 safety regressions, explicit read of separate docs branch. Required original mailbox interact-parity-batch1-20261007.patch with provenance, meaningful tests and preservation of existing features. No duplicate submission; initial type input timed out before submission, recovered form and replaced full prompt, then sent exactly once. Old queued PR13 task remains quarantined; do not apply late output. Subsequent batches wait for this coherent delivery and independent review. No implementation result/tests/deployment claimed. DEV unchanged; Codespace not started. Next: inspect task delivery, verify base/source/artifact/tree/checksum, apply unchanged in isolated Codespace worktree and independently validate before DEV rollout.

### Live task check — 2026-10-07 20:16Z

Batch1 task6e51ca93 UI confirmed In progress / Copilot is working, session91578940-183f-4850-a70b-3fd77e9edda1. Logs show baseline/docs inspected, guest backup validation and regressions implemented, guided frontend/backend work underway and isolated PostgreSQL validation activity. Flutter SDK absent; official SDK download HTTP403, so Flutter checks remain unavailable to Copilot and require independent Codespace validation. No completion/pass claimed. Old task8c57d37e/PR13 still Queued with122historical sessions. Clicked Stop session once; UI remains disabled Loading/Queued, cancellation NOT confirmed. All late old-task output REJECTED for application/merge/deployment; only authorised batch1 provenance accepted for current work. Do not send additional old-task steering/restart or apply its branch head. No new competing task. Runtime unchanged.
