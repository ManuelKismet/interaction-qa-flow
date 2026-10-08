# Interact parity batch 3 – queued uncertain-delete Undo fix (2026-10-08)

Branch: `copilot/fixinteract-parity-batch3`. Base: artifact commit
`8728b802654e8507aabb63b9c38625c678ac8626` (tree `3703ffe399c8ce34ab0bf3086fe023b4777ac88e`,
app subtree `56768f0d721cc43b75363450478ba0ae920e61ea`). The two earlier mailboxes and their
receipts are unchanged. This fix supersedes the "Residual, not separately tested" note in
`interact-parity-batch3-review-fix-2026-10-08.md`: that case is now fixed and tested.

No backend, schema, production, IAM, credential, firewall, deployment or authentication-code
changes. Hosted authenticated acceptance remains **pending**. Guest reload/open-session
routing remains **OPEN**, and there is no new router or auth design.

## Problem

An account DELETE can fail without confirmation (an error, or a lost response after the
server applied it). It stays queued for retry, and the user may then choose Undo.
`_syncPersonalWorkspace` used to pick `update`, because the stale `_personalItems` still held
the old record. If the server had actually removed it, Retry sent `PUT` to a missing ID and
got a 404 from the server, so the Undo never converged.

## Fix (`guest_workspace_page.dart`)

- Before each DELETE is sent, its target record (ID and revision) is recorded in
  `_uncertainPersonalDeletes`. The entry is removed when any write for that source key is
  confirmed, and cleared on a UID change (`didUpdateWidget`) or sign-out (`_signOut`).
- Undo of a pending, not-in-flight DELETE with an unconfirmed outcome enqueues a `reconcile`
  write that keeps the full restored data (answers and nested branches). The in-flight Undo
  path (`create`) is unchanged.
- Processing a `reconcile` write first reads the authoritative same-UID account list. The
  mounted, UID and generation guard is rechecked after the read, then:
  - **Missing:** `createItem`, which is idempotent by source key. If the server returns a
    record whose content differs, it is treated as a conflict.
  - **Same ID and the revision the DELETE targeted:** `updateItem` with that known revision.
    The server's 409 check prevents any blind overwrite. Existing queued-not-applied
    behaviour is retained (one revision-guarded write, giving revision 2).
  - **Different record or revision with identical title and data** (for example a previous
    recreate whose response was lost): adopted without writing.
  - **Different content** (changed or recreated on another device): no write. The pending
    restore becomes an ordinary pending edit, the remote record is shown, and the existing
    explicit "Review account change" dialog decides. A 409 from the reconcile update goes
    through the same review.
- A failure to read or write keeps the pending Undo with "save not confirmed" status and
  "Retry account save". Nothing is reported as saved.
- No local import or copy, no deletion of originals, no access expansion.

## Tests (`test/account_state_widget_test.dart`, group "batch3 review correction")

The fake repository now follows the server's semantics:
- `updateItem` returns 404 for an unknown ID.
- A revision mismatch returns 409, except the server's idempotent same-content replay.
- `deleteItem` returns 409 on a revision mismatch.

The existing tests, including the in-flight and queued-not-applied Undo tests, still pass.

Eight new tests. In each, Undo is tapped only after the DELETE has finished with an
unconfirmed outcome, so it is pending but not in flight; the test asserts "Retry account
save" is shown and `deleteCalls == 1`.

| Test | Proves |
| --- | --- |
| Undo after a queued uncertain DELETE (applied on server) | One reconcile read, then an idempotent recreate gives exactly one item (`record-interact_session:s1`, revision 1) with full data. No update, no repeated DELETE, local store unchanged. |
| … (not applied on server) | The original `remote-s1` is retained at revision 2 via known-revision update. No import, no duplicate. |
| reconciliation read failure keeps the Undo pending and retry converges | The failed read gives "save not confirmed" and Retry, with nothing written. The second Retry converges to one item. |
| a lost recreate response does not create a duplicate | The recreate is applied but its response is lost. Retry adopts it: still one import and one item. |
| a changed / recreated remote record … needs explicit review | "Review account change" is shown. The remote record is untouched (no import or update) and the restored local copy is still shown. The review dialog shows the latest revision and offers "Save my pending edit". |
| uncertain-delete reconciliation sends no writes after a UID switch / sign-out | The old-UID read is delayed and the identity changes. No import or update under any UID, and the old content is not shown. |

**Negative control:** with the pre-fix `lib/` and the new tests, all 8 new tests fail. The
server-applied case gets stuck on the 404, and the UID-switch cases send an update.

## Validation receipts

Environment: Flutter 3.41.4 / Dart 3.11.1, `CI=true FLUTTER_SUPPRESS_ANALYTICS=true`,
`--suppress-analytics`. These were run on source commit
`c61cb7d1d013fb24f4fd9c3fefbeded8b06df916` (tree `fcab97e12b08b5512eaa9f9fffdf013b66c71798`,
app subtree `1a3642d9fde6dd377300c056966712174dcae89a`). This document is the only later
change.

| Command (in `apps/flutter_app`) | Exit | Result |
| --- | --- | --- |
| `dart format --output=none --set-exit-if-changed lib/features/guest/presentation/guest_workspace_page.dart test/account_state_widget_test.dart` | 0 | 2 files, 0 changed |
| `flutter analyze --suppress-analytics` | 1 | 0 errors, 0 warnings, 12 baseline infos |
| `flutter test --suppress-analytics test/account_state_widget_test.dart --plain-name 'batch3 review correction'` with pre-fix `lib/` (negative control) | 1 | 10 passed, 8 failed (all 8 new) |
| same, with the fix | 0 | 18 passed |
| `flutter test --suppress-analytics test/account_state_widget_test.dart test/guest_interact_widget_test.dart test/guided_batch3_test.dart test/session_deep_link_test.dart` | 0 | 108 passed |
| `flutter test --suppress-analytics` (full) | 0 | 298 passed (290 + 8 new) |

The backend is unchanged, so no backend tests were run. The configured DEV release build
remains Codex's responsibility.
