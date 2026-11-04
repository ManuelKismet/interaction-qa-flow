# Responsive workspaces validation — 2026-10-09

Source parent: 6d470ae4ecdaa42fd0f9dbb75457be8fa07daf5f, on copilot/fixinteract-parity-batch4-edit-shared-copy. Changes were made in an isolated Codespace worktree. The four original dirty documents in the root checkout were preserved byte-for-byte.

## Changes

- Adaptive phone typography, field/button padding, icons and bottom navigation in all four MaterialApp entry points.
- Phone outer padding for Guest/Personal Knowledge and Interact, Groups, Organisation and organisation Interact lists/reports.
- Compact organisation toolbar below 600 pixels, retaining workspace/account menus.
- Organisation request field widths constrained to phones; expanded permission/member dropdowns fix a reproduced 320–390-pixel overflow.
- Owner delegation coverage documented without changing authority or assignments.
- Earlier database-ID/Firebase-UID search gate repair retained from the parent.

## Checks

- Focused workspace/search suite: **131 tests passed**.
- Organisation owner/navigation suite: **11 tests passed**, including five repeated owner-width cases and six additional navigation cases.
- Interact rendering suite using the production responsive theme: **20 tests passed**, including 360-pixel deeply nested editors and 768/1366-pixel layouts.
- **157 distinct focused tests passed** across those runs.
- New phone cases cover 320/360/390 pixels, tablet/desktop, landscape, keyboard insets and 2× text scaling. Buttons remain tappable and text scaling stays intact.
- Analyzer: **0 errors, 0 warnings, 18 pre-existing informational lints**. Flutter analyze returns 1 for these informational lints; this is not a zero-exit claim.
- Release web build: **passed** (118.7 seconds).
- Git whitespace check: passed.

The full suite was not rerun for this UI follow-up. The independently confirmed **31 pre-existing full-suite failures** remain an unresolved release gate. Focused passes do not establish a green full suite. See [prior search validation](unified-interact-search-validation-2026-10-09.md) for baseline evidence. No assertions were weakened to conceal those failures.

## Deployment and acceptance

No DEV deployment was performed. Hosted frontend remains bd713485d01eaa13a7bf3d5159d2215e22e13616; API remains intqaflow-dev-api-review80f421d. Source includes earlier undeployed UI and unified search changes; do not deploy only the frontend assuming the current API implements new search routes. Authenticated hosted phone acceptance is external/manual because the cloud-browser sign-in issue is paused.

Next: resolve the full-suite release gate, validate matching backend/frontend source and authorised DEV deployment, then accept actual phone layouts and permission-scoped search externally. Stop the Codespace after pushing the source receipt.

## Superseding full-suite validation

The remaining full-suite gate was resolved on 2026-10-09: 392 Flutter tests and 201 backend tests passed, including PostgreSQL integration checks; DEV-configured release build passed. See [DEV release validation](dev-release-validation-2026-10-09.md) for corrections and rollout status. Earlier figures above are historical checkpoints.
