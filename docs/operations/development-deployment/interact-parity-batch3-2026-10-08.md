# Interact parity batch 3 – coverage, decisions and validation receipts (2026-10-08)

Branch: `copilot/fixinteract-parity-batch3`. Base: `80f421d1c0ecc907d0d88a8147ccb1f2138fe377`
(app subtree `fd44cfb309d64bac30b8f4da5ae1caa6b35c9938`). Batches 1+2 are kept unchanged
except where noted below. No backend, schema, IAM, credential, firewall or deployment change.
This is not a deployment or merge. Codex acceptance is still required. Hosted
authenticated personal/organisation/Group acceptance is still **OPEN** (cloud-browser
auth blocker, not assigned here).

Validated app subtree (`apps/flutter_app`) at the final source commit:
`320f74e08d8dd2f974aacbe31fe2ca5853feb909`. This document is outside the app subtree, so
that hash does not depend on this file. The repository tree and commit hashes are recorded
in the artifact commit receipt
(`interact-parity-batch3-20261008.patch.receipt.md`).

## Scope ID coverage

| ID | Status | Delivered behaviour |
| --- | --- | --- |
| IP19 | Done for personal accounts; guest partly done, open decision below | **Session list and editor:** guest and personal sessions open as list cards into a dedicated editor (`_GuestSessionEditor`) built on the existing question models. The editor shows:<br>• a "Back to sessions" button<br>• an explicit destination chip ("Local · this device" or "Private account")<br>• the active participant<br>• live storage/save status<br><br>**Personal routes:** `/personal/interact` and `/personal/interact/sessions/:id` share one page key, so pending writes and timers survive URL changes. Reload, deep links and the hash form (`session_deep_link.dart`) restore the editor.<br><br>**Safety:** a missing or deleted session shows a "not available" view with a way back. A UID change closes the editor and returns to the list route. Back closes the editor before leaving. Pending-save guards are unchanged.<br><br>**Organisation route:** `/guided/sessions/:id` is unchanged. |
| IP20/IP21 | Done | **Wording:** the "Prepared" wording is removed (organisation label "Shared", count "N of M questions answered").<br><br>**Flow:** active participant → shared or participant question → answer → answer-owned follow-up.<br>• Guest: a pinned bar keeps "Active participant: X", the save status and "Add a question" visible while scrolling.<br>• Organisation: the controls area is bounded (≤60%, or 40% on short viewports) and scrolls, so the question list and focused fields stay reachable. Fields get scroll padding above the keyboard.<br><br>**Unchanged:** optional templates, shared vs participant targeting, participant-specific answers and recursive branches. |
| IP23 | Done | **Guest/personal:** "Edit question" / "Edit follow-up question" updates text by ID only. IDs, targets, answers and branches are preserved (test: `deep-linked editor edits follow-up text…`). Blank text is rejected.<br><br>**Organisation:** the existing inline question editing and its permissions are unchanged. Fields now have accessible labels ("Question text" / "Follow-up question text"); no duplicate control was added. |
| IP06 | Done | **Messages by destination:**<br>• Guest: "…locally"<br>• Personal: "…queued for your private account. Check the save status." It never says "saved" before confirmation.<br>• Organisation: "…in the organisation workspace", only after the server confirms.<br><br>**Failures:** uncertain template creation says "not confirmed… check Templates before retrying".<br><br>**Fixes:**<br>• Undo follow-up messages are now queued, so the Undo action no longer hides them.<br>• Undoing a pending account removal re-queues a create or update. |
| IP07 | Done | **Guest/personal:** "Save as local/private template" uses the existing slot templates.<br><br>**Organisation:** new "Save as organisation template", available only to editors (`canEditSession`).<br>• Reads the full session (all participants, all relevant questions).<br>• Builds `GuidedTemplateCreate` question inputs (`guidedTemplateQuestionsFromSession`) for the existing `POST /api/v1/guided/templates`.<br>• **Removed:** answers, participant names/IDs and deleted questions.<br>• **Kept:** shared/participant scope (as zero-padded `Participant N` slots), follow-up parent references and nesting.<br>• Creates version 1. Existing version/archive/restore governance and version pinning are untouched. A duplicate name (409) reports that nothing was created.<br><br>No cross-workspace copy or import. |
| IP08 | Done (organisation); guest documented | **Organisation:**<br>• Header shows "Organisation · <visibility> · Status: X".<br>• A "Lifecycle and recovery" info dialog explains the existing server transitions (draft→active→completed, archive from any non-archived state).<br>• "Archive session" needs confirmation that states archive is final.<br>• Archived sessions show a read-only notice, and a new "Archived sessions" tab lists them (existing `status=archived` filter).<br><br>**Recovery:** no reopen or restore is advertised because the server has none. Completed sessions stay editable. Save history is labelled "audit entries only". Question delete keeps its existing Undo.<br><br>**Guest:** the lifecycle info button explains that local sessions have no lifecycle states. |
| IP09 | Done | **Guest/personal:**<br>• Rename session.<br>• Rename or remove the active participant. Removal is blocked when the participant has content, is confirmed otherwise, and offers Undo.<br>• Copy the selected session as JSON. The confirmation says account-only sessions are excluded from the full local backup. No automatic upload.<br>• PDF report.<br><br>**Organisation:**<br>• Edit session details (title/owner/context) with `expected_revision`; a conflict uses the existing `GuidedConflict` handling.<br>• Rename participant.<br>• Remove participant, with confirmation. The server refuses removal when the participant has answers or targeted questions (409 → "nothing was removed"). Successful removal offers "Add back", which re-adds the name as a new participant.<br>• Reports and JSON/CSV export are unchanged. The existing export/interchange schemas are reused. |
| IP22 | Done in widget tests; hosted device acceptance open (batch4) | **Narrow-layout coverage:** 320×568 with a 260 px keyboard inset; 360×640 for guest editors; long labels and deep branches. Tests check overflow (`takeException`), hit-testability and bounded controls.<br><br>**Accessibility:** dialogs are `scrollable`, menus have tooltips, and secondary explanations sit behind info buttons. |
| IP24 | Done | **Hint text** (examples only, never prefilled answers) supplements visible labels:<br>• Guest: session, participant and question fields.<br>• Organisation:<br>&nbsp;&nbsp;– add participant / question / follow-up dialogs<br>&nbsp;&nbsp;– session details<br>&nbsp;&nbsp;– template name<br>&nbsp;&nbsp;– inline question and answer fields |

## Intentional differences and open decisions

1. **OPEN – guest reload deep link:** guests (no Firebase identity) and registered users
   without membership render `GuestWorkspacePage` outside the router, so the guest
   editor is in-page. Back and missing-session handling are safe, but a browser reload
   returns to the session list. Adding guest URLs would mean routing the guest shell
   (auth gate/router change, which is out of scope here) or persisting an open-session
   marker locally. Founder decision required.
2. **Organisation archive is final:** there is no reopen or restore endpoint, so none is
   offered. Whether to add one is a product/backend decision.
3. **Organisation participant removal recovery** is "Add back", which re-adds the name as
   a new participant ID. The server only allows removing participants with no content, so
   no answers are lost.
4. **Organisation templates are organisation-wide**, matching existing template
   visibility; sessions stay private by default. Slots are created only for participants
   that own participant questions or follow-ups, so shared-only templates instantiate
   "Participant 1", as the server already does.
5. **Guest/local sessions** have no lifecycle states or CSV export (local JSON and PDF
   only), as before.

## Validation receipts

Environment: official Flutter 3.41.4 (revision ff37bef603), Dart 3.11.1, from session setup
`/home/runner/work/_temp/copilot-flutter-3.41.4`. Every command was run with
`CI=true FLUTTER_SUPPRESS_ANALYTICS=true` and `--suppress-analytics` where supported.
No metadata endpoints were queried.

| Command (in `apps/flutter_app`) | Exit | Result |
| --- | --- | --- |
| `flutter pub get --enforce-lockfile --offline` | 0 | lockfile sha256 `9dadb733857d8c5fab46f36327e3da65599ff5f17631a59bc62c988a5dd0cd65` |
| `dart format --output=none --set-exit-if-changed <14 changed Dart files>` | 0 | 0 changed |
| `flutter analyze --suppress-analytics` | 1 (infos only) | 0 errors, 0 warnings, 12 existing infos, identical to baseline (governance_repository ×2, guest_report_document ×1, guest_workspace_page ×3, questions_repository ×6) |
| focused: `flutter test test/guided_batch3_test.dart test/guided_session_page_test.dart test/guided_safety_test.dart test/guided_ui_test.dart test/guided_page_test.dart` | 0 | 98 passed |
| focused: `flutter test test/guest_interact_widget_test.dart` | 0 | 23 passed |
| focused: `flutter test test/session_deep_link_test.dart` | 0 | 7 passed |
| full: `flutter test --suppress-analytics -r expanded` | 0 | **280 passed** (baseline 264 + 16 new) |
| `flutter build web --release --suppress-analytics` with the committed public DEV defaults (`FIREBASE_AUTH_DOMAIN`, `FIREBASE_PROJECT_ID`, `FIREBASE_APP_ID`, `FIREBASE_MESSAGING_SENDER_ID`) | 0 | built `build/web` (`main.dart.js` 4,627,528 bytes) |

**Release build limitation:** the private-handoff values (`FIREBASE_API_KEY`,
`RECAPTCHA_ENTERPRISE_SITE_KEY`, hosted `API_BASE_URL`) are not in source control and were
not available in this session. This receipt is a release compile using the repository's
committed DEV defaults, not a hosted-configured build. No credentials were requested or
added.

**Backend:** unchanged, so backend and PostgreSQL suites were not rerun. The batch1
receipt (158 passed) still applies.

### New focused regression tests

**Organisation (`test/guided_batch3_test.dart`):**
- Template inputs strip answers, names, IDs and deleted questions, and keep slots, targets and nested parents.
- Zero-padded slot ordering.
- Non-owner sees no mutation controls.
- Destination, status, labels and placeholders.
- Archive confirmation and transition.
- Archived session is read-only with no reopen.
- Session details send the trimmed values and `expected_revision`.
- Blank title is rejected without a request.
- Save-as-template reads the full session and strips answers.
- Duplicate template name reports a conflict.
- Participant rename, guarded removal (409) and "Add back".
- 320×568 with keyboard inset: bounded controls, deep branch is hit-testable, menus are reachable.

**Guest (`test/guest_interact_widget_test.dart`):**
- Deep-linked editor: follow-up text edit preserves IDs, answers, targets and branches; blank text is rejected; content-guarded participant removal; back clears the route.
- Empty participant removal is confirmed and Undo restores it, with other answers unchanged.
- A missing deep-linked session returns safely without touching data.

**Routing (`test/session_deep_link_test.dart`):** personal path and hash links.

**Not yet covered by a dedicated new test (gap for Codex review):**
- Re-queueing after Undo of a pending private-account session removal (`_syncPersonalWorkspace`).
- Closing the personal editor when the UID changes (`didUpdateWidget`).

Both are implemented; the existing account-state suite passes unchanged,
but neither behaviour has a targeted assertion yet.
