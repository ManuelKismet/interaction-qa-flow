# Codespace App Check acceptance setup — 2026-10-04

Development project: intqaflow-dev. Hosted frontend remains on 2351c97; no deployment or merge performed.

Registered one Firebase App Check debug token for the dev web app via the official REST API. Token is stored outside the repository in a mode-0600 private file; isolated Chrome profile is mode 0700. Never commit the token, embed it in deployed bundles, or print it in logs. App Check enforcement remains enabled. Revoke the registered test token when guest acceptance testing is complete.

Runner: /home/vscode/.local/share/intqaflow/codespace-appcheck-probe.py
Private profile: /home/vscode/.local/share/intqaflow/isolated-guest-appcheck-profile
Sanitized evidence log: /home/vscode/.local/share/intqaflow/codespace-appcheck-probe.log

Verified: official Chrome launches with the previously approved test-only no-sandbox flag; normal anonymous guest activation succeeds; Firebase debug-token exchange returns HTTP 200; hosted GET /api/v1/guest/groups returns HTTP 200; isolated guest sees no approved groups and no local work. No invitation redeemed or member approved in this setup.

Management API calls require x-goog-user-project: intqaflow-dev with the retained gcloud authorization. Initial missing quota-project request was rejected; specifying the dev quota project resolved management API access.

Pending: invitation redemption, pending-member privacy, membership approval/access boundaries, actual PDF saving, final cleanup. Owner session must be recovered independently before invitation testing.

Separate PR13 review: 184a47d targeted tests finished with 9 passes and 1 failure. guest_group_dialog_test.dart:229 pumpAndSettle timed out in opt-in sharing test. This candidate is not signed off or deployed.

## Two-browser invitation acceptance continuation

Owner cloud browser recovered with original local Knowledge and disposable group intact. Replacement Contributor invitation created. Clipboard/terminal capture attempts initially failed; the token that echoed was revoked immediately and replaced. Current token captured through a validated hidden-input prompt and stored outside the repository with mode 0600. Never print or commit that token.

Isolated Chrome profile submitted a normal invitation preview and join request through the hosted frontend. Rendered token and display-name fields were asserted before submission. POST /api/v1/guest/invitations/preview returned 200; POST /api/v1/guest/invitations/join returned 200; subsequent group list returned 200 with no approved groups/content visible. Owner UI independently confirms Isolated acceptance contributor as contributor/pending. No membership approval performed. Invitation was consumed by the pending join; old original unused invitation remains active.

Next: explicit approval of this disposable pending Contributor, then validate content access and Contributor ownership restrictions. Pending UI exclusion is verified; direct API denial for pending membership is not yet independently exercised.

PR13 184a47d widget-test timeout has been reported to Copilot with exact reproduction and instruction to preserve assertions; no deployment or merge performed.

## Reconnection checkpoint — 2026-10-04 18:25 UTC

User explicitly approved the disposable Contributor membership. Owner UI independently confirms Isolated acceptance contributor is contributor / active. Approved-group visibility and server ownership/admin boundaries are now being exercised using the isolated browser's normal Firebase and App Check request headers, kept only in memory. No production deployment or PR merge performed.

### Lessons learned

- Resume interrupted sessions by checking actual browser/member state before repeating mutations; an approval may have completed before the stream disconnected.
- Keep debug tokens and invitations outside the repository with restrictive permissions. Validate a hidden-input prompt before supplying a token; revoke and replace any token accidentally echoed.
- Flutter web form tests must assert rendered field values after input and blur before submission; an unfilled required display name makes an invalid-token test inconclusive.
- Separate UI visibility evidence from server authorization evidence. Pending membership exclusion in the UI does not prove a direct API denial.
- Review fixes against an exact commit; passing an older revision cannot sign off a newer Copilot head.

### Confirmed results after reconnect

Normal isolated Contributor group listing and shared-entry read returned 200. Exactly one owner Knowledge entry was visible. A PATCH carrying the existing owner title/data returned 403; invitation-list GET returned 403. Headers came from this browser's normal Firebase SDK requests and stayed in memory. These establish the exercised ownership and admin-list server boundaries; pending direct API denial remains untested.

Exact PR13 head 7bcc6a4697b9cfaa7d134647f60042add9c211cb independently returned 9 passes / 1 failure for guest_group_dialog_test.dart and guest_interact_widget_test.dart. The same opt-in sharing test now times out at line 232 after opening the sharing dialog. Reported to Copilot in PR comment 5983061801. No sign-off, merge, or deployment.

Contributor own-entry lifecycle passed: create returned 201; edit own Knowledge returned 200; own history returned 200; exporting readable owner Knowledge returned 200. Disposable synthetic fixture retained for inspection; private fixture metadata is outside git. Export endpoint success is not evidence of an actual browser PDF download.

### PDF continuation and remaining checkpoint

Cloud owner UI opens the shared Knowledge PDF preview with the expected body and edited answer. The cloud automation attempt to await a download and activate Download PDF timed out at the tool level; no downloaded file was captured, and the click completion is not independently confirmed. This is inconclusive, not a proved product failure. Codespace PDF inspection initially timed out because its exact button name omitted the row's revision description; corrected to a partial-name locator. Broader PDF download, pending direct API denial, conflict/revocation and cleanup acceptance remain open.

Docs checkpoint committed locally as 1709404 before this PDF addendum. No remote push, merge, or deployment; unrelated migration notes were left untouched.

### PDF download resolved in Codespace

Isolated Contributor UI opens owner Knowledge details and shows Download / Share PDF, History, Done; Edit and Delete are absent. Normal hosted preview then Download PDF produced an actual Chrome download: 9,155 bytes, %PDF- header confirmed. File retained privately at /home/vscode/.local/share/intqaflow/contributor-knowledge-acceptance.pdf. Cloud-browser event timeout was inconclusive; the independent Codespace result establishes download success. PDF page rendering/text extraction, nested Interact downloads, pending direct API denial, conflict/revocation and cleanup still require separate acceptance evidence.

Lesson: distinguish cloud automation event failures from application failures; confirm the actual file via a controlled browser before assigning a product defect.

## Acceptance continuation — 2026-10-04

Copilot head 10d033085b58fe51fff5a594abd2c71fe6b97732 independently passes all 10 targeted guest-group/guest-interact widget tests. Broader Flutter, analyzer, release compilation and backend checks are running against that exact head. No merge/deployment.

Source inspection: guest Knowledge update has row locking and version snapshots but no expected_revision precondition. Exercise two stale-snapshot writes only against the disposable Contributor fixture; do not infer optimistic conflict protection from history alone. A first harness attempt selected the newest row by position and therefore hit the Contributor's own fixture; its 200 is not a failed owner boundary. Harness corrected to select the owner fixture by exact title before rerun. Existing owner content remains untouched.

Lesson: select multi-user acceptance fixtures by stable identity, not list position, as new content changes ordering.

Confirmed live stale-snapshot result: both edits return 200, revision 3→5, and the second answer is current. This is last-write-wins, not optimistic conflict denial. Reported to Copilot in PR13 comment 5983197884 for focused concurrency follow-up. Stable owner fixture PATCH remains 403.

Exact head 10d0330: all 99 Flutter tests pass; analyzer with --no-fatal-infos exits 0. Build/backend results pending. Owner nested Interact all-participant PDF preview shows Participant B's answer-owned follow-up and nested follow-up with attribution. Actual nested PDF byte/text validation remains open.

Broader exact-head verification complete: 99 Flutter tests, analyzer exit 0 with 12 infos/no warnings or errors, release build exit 0, and 82 backend tests pass (one pytest warning). Backend initial import blocker resolved by installing this revision's declared firebase_admin dependency; retry exit 0. No deployment or merge.

Synthetic nested Interact fixture imported locally into the isolated profile (two named participants, shared answers, answer-owned two-level branch, participant-only unanswered prompt). Preview/download automation reached download but save_as failed because its browser target closed; actual nested PDF file remains unverified and is being retried. This is separate from the successful Knowledge download. Copy backup from the cloud owner did not yield JSON in the automation clipboard, so the test uses a new synthetic fixture and does not modify the owner's drafts.

Nested Interact download serial retry reproduced Download.save_as TargetClosedError after the download event, with no completed PDF file captured. Text extraction/render QA cannot be claimed. Copilot notified in comment 5983264529; product vs browser environment cause remains unresolved. Knowledge download success is preserved as a separate control. All browser contexts from the timed runners have ended; disposable nested fixture remains local to the isolated profile.

Next checkpoint: create a fresh 24-hour Contributor invitation for a third isolated pending guest, verify direct group/entry/export/write denial before approval, revoke its invitation and verify preview/join denial. Prepared owner Create invitation dialog, Contributor own-content role selected, not submitted; action-time confirmation required by browser access rules. Do not approve the third member for this pending-only test. Review Copilot concurrency fix when available. No cleanup of existing acceptance fixtures yet; no merge/deployment.

## Pending API acceptance continuation

User confirmed creation of the prepared disposable 24-hour Contributor invitation. Owner created it; the token was validated and captured via observed getpass hidden input to pending-guest-invite-private.txt, mode 0600, outside git. New isolated-pending-guest-profile is separate from the active Contributor profile. Normal frontend invitation preview/join and direct group/entry/history/export/create/edit/admin-list denial checks are running; membership will not be approved. No results claimed until runner completes and owner independently confirms pending state.

Invitations are one-use: successful join consumes its token. Consumed-token denial and administrative revocation are distinct tests. A second same-scope disposable invitation is necessary for revocation before any join; never describe consumption as revocation.

### Confirmed pending membership boundary

Owner refreshed the group and independently confirms Pending API acceptance guest contributor/pending. Normal isolated SDK group listing returns 200 with no approved groups. Direct group detail, entries, entry detail, history, export, admin invitation list, create, and edit all return 404 with application detail Guest group not found. This is intentional group-existence hiding, not an unmatched route. Initial harness assertion expected 403 and was corrected after checking error details. No unauthorized writes or membership approval occurred.

Correction to invitation assumptions: preview checks availability/revocation/expiry and returns HTTP 200 with a valid boolean. A redeemed token may still preview as valid; repeat join by the same pending identity is intentionally idempotent, whereas join by another identity is rejected. Do not equate an absent active-list invitation with preview denial. Administrative revocation must be tested using preview valid=false and join unavailable, not status!=200 alone.

Revocation token capture was overwritten by a concurrent Codespace clipboard paste before private capture. That unused test token (expiry 2026-10-05T19:04:20.640553+00:00) was revoked; replacement created with identical dev group, Contributor role and 24-hour duration. Replacement hidden capture succeeded; before/after revocation check running. Tokens were not printed or committed.

Exact Copilot head dca98b796e00b77b947b2176f9060df51ee884b3: 101 Flutter tests, 82 backend tests, analyzer exit 0 with --no-fatal-infos, and release build exit 0. Source now requires expected_revision and rejects stale edits with 409 before history mutation. Old deployed frontend/backend do not yet include this protection. Required revision field creates an API compatibility change: plan frontend/backend rollout together and handle old cached clients; do not silently deploy backend alone. No merge/deployment performed.

Lessons: use semantic payloads, not HTTP status alone, for preview validity; validate intentional authorization hiding against known group IDs and application error details; refresh owner data before comparing membership state; finish clipboard capture before any other paste.

### Revocation result

Replacement invitation expiry 2026-10-05T19:06:29.507685+00:00: preview before revocation 200/valid=true. Owner revoked it. After revocation: preview 200/valid=false; join 404/Invitation is unavailable. Same-identity replay of the redeemed pending-test token returns 200/pending, confirming intentional idempotency. No third identity approved. Original older active invitation is retained unchanged. Both unused revocation-test invitations have been revoked.

Different-identity replay of the redeemed pending token returned 409 / Invitation has already been used. Pending boundary and invitation lifecycle acceptance are complete. Owner final view shows pending guest still unapproved and only the original older invitation active; both unused test invitations are revoked. Pending browser profile explicitly chmod 0700; token files remain 0600 outside git. Live findings reported in PR13 comment 5983427618.

Remaining: nested Interact PDF artifact capture/text/render QA; live concurrency-fix rollout after coordinated frontend/backend compatibility review; final disposable fixture/debug-token cleanup after acceptance. No merge/deployment, no pending-member approval. Retained fixtures allow repeatable follow-up.


## Nested PDF acceptance completed — 2026-10-04 19:20 UTC
Hosted dev nested Interact PDF downloaded through the normal UI with the existing isolated Contributor profile and App Check enforcement retained. Explicit accept_downloads=True on the persistent Playwright context resolved the earlier save_as failure; the earlier failure was a harness configuration issue, not a demonstrated application defect. Actual file: 9,358 bytes, PDF header valid, one page. PyMuPDF extraction confirmed both PDF Alice/PDF Bob attribution, both shared-root answers, two levels of Alice answer-owned follow-ups and their answers, and Bob-only unanswered prompt. Rendered page inspected in VSCode: no clipping or overlap observed for this fixture. Multipage pagination and unusual glyph coverage are not established by this one-page fixture.
Lesson: explicitly enable downloads in persistent browser acceptance contexts, and distinguish harness failures from product defects before reporting. Never mark PDF acceptance complete from preview text alone.
PR13 remains draft/unmerged at dca98b796e00b77b947b2176f9060df51ee884b3. Exact-head 101 Flutter / 82 backend tests, analysis and release build passed previously. Next: prepare coordinated dev frontend/backend rollout, assess cached old-client recovery for required expected_revision, live stale-update rejection, then disposable-fixture/debug-token cleanup. No merge or deployment performed.


## Coordinated dev rollout and acceptance completed — 2026-10-04 19:35 UTC
User authorized coordinated rollout. Exact reviewed dca98b796e00b77b947b2176f9060df51ee884b3 deployed to dev only; PR13 remains draft/unmerged. Backend intqaflow-dev-api-reviewdca98b7 serves 100% traffic. Hosting release sites/intqaflow-dev/releases/1791142233375000, version sites/intqaflow-dev/versions/af3d426e061782b0, 36 files. Both release builds passed. Prior backend reviewabb224f and Hosting version 2be73b0d8df32cd9 retained for rollback.
Live normal Firebase SDK/App Check Contributor checks: current-revision update 200, stale-snapshot update 409, missing-revision old-client request 422. Entry revision 5→6, newer data retained, rejected requests did not increment revision. Owner reload retained original local draft and group access. Ordinary updated frontend edit of disposable entry saved revision 7. Original owner shared entry remained revision 1.
Compatibility limitation: old already-open clients cannot edit until reload; missing expected_revision fails closed with 422. Reload recovery and ordinary frontend save verified; no automatic old-client upgrade UX claimed. Deployment used existing no-service-worker build and max-age=300 Hosting configuration. App Check enforcement and server authentication remain enabled.
Cleanup: remaining test invitation revoked; owner member view has no active invitations. Disposable active Contributor removed from group; pending guest never approved. App Check debug-token DELETE returned 200 and GET postcheck 404; private debug/invitation token files and both isolated Codespace Chrome profiles removed. Synthetic shared revision-history fixture and pending membership retained for traceability; owner data retained. Temporary build Docker files removed from review checkout. No old-PC database cleanup performed because that device is not accessible here.
Lessons: stage reviewed backend with no traffic; capture rollback IDs before coordinated contract changes; verify stale and legacy writes preserve newer content, and test ordinary UI save after reload. Revoking debug token prevents new exchanges; already issued short-lived tokens can remain valid until expiry, so disposable member access was separately removed.
