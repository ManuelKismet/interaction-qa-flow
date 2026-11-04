# Interact parity batch 3 – Codex review correction (2026-10-08)

Branch: `copilot/fixinteract-parity-batch3`. Base: artifact commit
`05ec5386181fe39b9a2bc5f3a21c2d94e8f7f96d` (tree `5e82d87de40d9964f62140d8f37d9bc7e0c5544e`,
app subtree `320f74e08d8dd2f974aacbe31fe2ca5853feb909`). The original batch 3 mailbox
`interact-parity-batch3-20261008.patch` and its receipt are unchanged.

No backend, schema, production, IAM, credential, firewall, deployment or authentication-code
changes. Hosted authenticated personal/organisation/Group acceptance remains **pending**
(cloud-browser auth), and nothing here claims it passed.

## 1. Privacy fix: account-scoped session JSON copy

`_copySessionJson` (`guest_workspace_page.dart`) previously held an account session
snapshot across a plain `showDialog` and checked only `confirmed` and `mounted` before
`Clipboard.setData`. Now:

- The originating verified UID (null for local guests), the personal generation, the
  session ID and its destination (Local or Private account) are captured when the dialog opens.
- The dialog route is registered as account-scoped. When the UID changes in `didUpdateWidget`
  or the user signs out in-app (`_signOut`), the dialog is removed, so a stale confirmation
  cannot be acted on.
- After the dialog closes, the copy proceeds only if the page is mounted, the UID and
  generation are unchanged, and the same session ID still exists with the same destination.
  It copies the **current** session, not the earlier snapshot.
- Otherwise it shows "The account or session changed before copying. Nothing was copied."
  No success toast is shown, and nothing reaches the clipboard. The export destination is
  never silently switched.
- A legitimate copy still uses the existing local JSON backup format
  (`GuestWorkspaceData.encodeBackup`) and uploads nothing. Local guests work without Firebase.

## 2. New targeted tests (`test/account_state_widget_test.dart`, group "batch3 review correction")

| Test | Proves |
| --- | --- |
| account session JSON copy uses the backup format only | Copied text decodes with `GuestWorkspaceData.decodeBackup` to exactly the selected account session. There are no import, update or delete calls, and the local store is unchanged. |
| stale copy confirmation … (UID switch) / (sign-out) | The dialog is held open while the identity changes. A mocked platform clipboard receives nothing, the dialog is dismissed, there is no success toast, the "Nothing was copied" notice is shown, and no old-account text is displayed. Negative control: both tests fail against the pre-fix source. |
| local guest session JSON copy works without Firebase | `firebaseReady: false`; the local session copies in backup format. |
| Undo during an in-flight account DELETE restores one item | DELETE is gated, Undo is tapped mid-flight, then DELETE completes. Result: exactly one account item for the source key, recreated (revision 1, full answers and nested branches), with no duplicate and no local copy. |
| Undo during an uncertain / failing account DELETE retries to one restored item | A gated DELETE throws, with or without the server having applied it. "Retry account save" leads to exactly one item: recreated when the server had deleted it, or the original record (`remote-s1`, revision 1, no update) when it had not. No duplicate. |
| Undo of a queued failed account DELETE keeps the account item | The DELETE fails and stays queued (not in flight). Undo replaces it with an update; Retry gives a single item at revision 2 with identical data, and DELETE is not re-sent. |
| open personal editor drops delayed old-account reads and writes on UID switch / sign-out | The personal editor is deep-linked and open, with an account-A update gated and the account-A and account-B lists delayed, then the identity changes. The route callback receives `null` and the editor closes. The late A write and late A read never render A content. No write is sent under B's UID (`updateUids == ['a']`, no imports or deletes), local storage stays empty, and B sees only its own session. |

## 3. Decisions recorded (not completed features)

- **OPEN – guest reload/open-session routing:** for guests, a browser reload of an open
  session returns to the session list. A guest dedicated-editor deep link that survives
  reload would need an auth/router change or a local route-persistence decision. That is a
  founder product decision and is not implemented here.
- **Intentional server difference – organisation archive is final:** the existing server
  has no reopen transition for archived organisation sessions, so none is advertised.
- **Intentional server difference – participant Add back:** restoring a removed organisation
  participant uses the existing add endpoint, which creates a new participant ID. Earlier
  answers stay with the removed participant. No new backend feature was added.
- **Residual, not separately tested:** a *queued* (not in-flight) DELETE whose failure was
  in fact applied on the server, followed by Undo, is replaced with an update against a
  record that no longer exists. Retry then reports "not confirmed" and the local Undo state
  is kept, rather than losing data silently. This case is not separately exercised by the
  tests above.
- The configured DEV release build is left for Codex to validate in its normal configured
  environment. A default release compile alone is not configured-DEV acceptance.

## 4. Validation receipts

Environment: official Flutter 3.41.4 / Dart 3.11.1, `CI=true FLUTTER_SUPPRESS_ANALYTICS=true`,
`--suppress-analytics`. These were run on the source after commit
`49f5a1a345947d807f3db0dfdbb075b4fd949240` (tree `c4a2ab53eb63aa13b5fae4c1bea355d0649e0c31`,
app subtree `56768f0d721cc43b75363450478ba0ae920e61ea`). This document is the only later
change.

| Command (in `apps/flutter_app`) | Exit | Result |
| --- | --- | --- |
| `dart format --output=none --set-exit-if-changed lib/features/guest/presentation/guest_workspace_page.dart test/account_state_widget_test.dart` | 0 | 2 files, 0 changed |
| `flutter analyze --suppress-analytics` | 1 | 0 errors, 0 warnings, 12 baseline infos (unchanged) |
| `flutter test --suppress-analytics test/account_state_widget_test.dart --plain-name 'stale copy confirmation'` against pre-fix `lib/` (negative control) | 1 | 2 failed, as expected |
| `flutter test --suppress-analytics test/account_state_widget_test.dart test/guest_interact_widget_test.dart test/guided_batch3_test.dart test/session_deep_link_test.dart` | 0 | 100 passed |
| `flutter test --suppress-analytics` (full) | 0 | 290 passed (280 baseline + 10 new) |

Backend: unchanged, so no backend or PostgreSQL regressions were run.
