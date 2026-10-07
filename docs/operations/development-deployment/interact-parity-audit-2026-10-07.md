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
