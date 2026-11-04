# Hosted browser acceptance progress — 3 October 2026

Candidate PR12 df6bcd3026295e9f492d140282376c927bb66844, deployed dev API intqaflow-dev-api-guestdf6bcd3 and Hosting version d6f1722e1d603e67. Used the cloud browser on https://intqaflow-dev.web.app/. Codespace is the terminal/API/database verification environment, not an installed browser runtime.

## Executed browser observations

- Created synthetic solo Knowledge item Hosted acceptance checkpoint 2026-10-03. Reloaded hosted page; item visibly remains.
- Explicit shared-mode consent explains per-device guest identity and deliberate import. Continued to shared mode; workspace shows Firebase guest membership availability, with local item preserved.
- Shared list successfully loads against hosted API. Before group creation, no approved memberships are shown.
- Created Synthetic acceptance A 2026-10-03 with Synthetic host A after visually confirming both form fields. Group appears as admin and starts with no content. Local draft was not silently uploaded.
- Explicit preview shows selected local item; confirmed Share selected with group. Item appears in group as Knowledge revision1. Repeated the same selected import; only one item remains at revision1. Returned to solo workspace; original remains.
- Created synthetic private local Interact session Synthetic PDF acceptance 2026-10-03, participant label Participant 1Synthetic participant, root question Does the PDF preserve the question and answer?, answer Synthetic answer for PDF acceptance., and answer-owned unanswered follow-up Is the nested follow-up included?.
- Report / Print dialog opens. Visual report is JSON, includes session/participant/root answer and nested follow-up. This is the solo guest compatibility report, not the separate registered Interact HTML report.
- Clicked Print / Save PDF. Cloud browser exposed neither print-preview page nor downloaded/rendered PDF; do not count pagination/PDF output as passed.
- Account transition entry offers Create or link an account with Link recovery account; Back to sign in shows existing-account email/password form. No credential submitted or recovery account created. Registered transitions/link conflict/cache isolation and registered HTML/PDF report remain unverified pending a secure test login/signup.

## Input timing and limits

Early synthetic group attempts did not create rows or send a POST because typed values had not settled in Flutter's real edit controls. Native/Playwright typing must focus a field, inspect fresh state, type in a later action, and visually verify values before submit. Once fields were visibly populated, group creation succeeded. This is a browser-control timing limitation, not evidence of a confirmed application create-group defect. Hosted read-only aggregate probe before successful attempt found zero synthetic groups/memberships; request statuses showed GET200 and no POST.

No second browser/device identity, registered account linking/conflict, sign-out/account-switch cache isolation, full two-group/organisation acceptance, or actual rendered PDF observed. Prior API privacy tests and code/build evidence remain separately attributed. No production changes, cleanup apply/purge/scheduler or merge. Synthetic group/shared item remain in hosted dev; synthetic solo items/session remain in this cloud browser. No test data deletion.

Next: secure existing-account sign-in or user-performed recovery signup in this cloud browser, then account transitions/privacy and registered report acceptance. PDF output requires a browser surface capable of exposing preview/download.
