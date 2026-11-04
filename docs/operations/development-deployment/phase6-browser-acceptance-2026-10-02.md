# Hosted Phase 6 browser acceptance

Environment: development Firebase Hosting, API revision intqaflow-dev-api-00002-bm6. Synthetic session d718d5b8-c08b-4ee9-8d34-d51e98d1eb82; no real participant data. No merge or production deployment.

Verified in the hosted browser:
- Legacy JSON import creates a private draft session with Alice/Bob and two nested follow-ups.
- Participant switching: Bob sees Phone and no Alice follow-up branch; Alice sees Email, Finance and Synthetic nested answer.
- Active participant report and combined report preserve answer/branch ownership.
- Bob's edited answer Phone browser acceptance autosaves, shows revision 2 in save history, and survives reload/reopening.
- JSON export is a Copy dialog, not a download. Its JSON parses and includes both the edited answer and nested answer.
- CSV Copy export has header session_title,participant,scope,type,depth,question,answer,returns_to, and includes both answers.
- Soft deleting the nested question reduces follow-ups to one; Undo restores both.
- Collapse/expand retains the nested branch and saves its state.
- Start changes draft to active. Complete changes to completed, removes the session from active, and lists it under Completed sessions.

Issues / unverified:
- Reloading a session URL redirected to Knowledge; the session was reopened through Interact. Deep-link preservation needs investigation.
- Attempted synthetic template creation was not visible in Templates or the New session selector. Later log review found no POST create request. Automated input appeared in accessibility values but not in the rendered Flutter fields; treat this as an input/testing limitation until direct entry establishes behavior. Do not mark creation/snapshot isolation passed.
- PDF output, template snapshot immutability, and multi-account live privacy/tenant checks remain unverified.
- Real App Check server attestation passed on revision intqaflow-dev-api-00003-2bz; see the live evidence below. Enforcement remains observe.
- Codespace stalled during the earlier checks; clean stop/start recovered terminal and Google Cloud access.

The JSON download timeout was a mistaken expectation about UI behavior, not an export failure: export content was subsequently validated through Copy.

Codespace recovery: a clean GitHub stop/restart restored the remote terminal. Google Cloud active sign-in and Cloud Logging reads succeed. The temporary review venv was cleared by restart; dependencies were restored in the development worktree backend/.venv and all 57 tests pass again. Safe development App Check outcome logging is committed as 9236eb5 and its API update is live as revision intqaflow-dev-api-00003-2bz.


Completed live App Check: revision intqaflow-dev-api-00003-2bz verified configured-web-app tokens from three fresh hosted-browser requests at 2026-10-02T21:44:50–52Z. Invalid App Check: 401. Foreign organisation: 403. Missing authentication: 401. Missing App Check: 200, expected in observe mode. Enforcement remains observe. All 57 backend tests passed. Template snapshot, PDF and multi-account browser checks remain unverified.


## Continued template and layout acceptance

Hosted template creation passed. Template 5eddaac6-8acf-40d3-a172-8bf8e027cbeb created v1 session 9835c632-a39e-4495-8235-77fe56043c44 with two questions. UI Save as new version cloned v2. Live API revised the template to v3 (one new question): the old session retained version 87974ad3-3f8e-4f5c-916e-774f9e6d772c and its original question texts; a new session c5fc0611-fb14-4cdf-958b-0765fc223ba0 used v3. Immutable snapshot check: PASS. UI editing of version contents remains unverified.

PDF output remains unverified: report contents are correct, and the Print / Save PDF action maps to window.print(), but no print preview/file was observable in this cloud browser. Separate authenticated-account checks remain pending.

User-requested deep follow-up UX review reproduced a severe width problem using eight long nested follow-ups in the synthetic v3 session. The deepest text wraps nearly one character per line at desktop width. See interact-deep-followup-layout-review-2026-10-02.md for source evidence, proposed flat layout/capped indentation and focused branch navigation, and acceptance criteria. Recommendation is recorded, not implemented or assigned to Copilot yet.
