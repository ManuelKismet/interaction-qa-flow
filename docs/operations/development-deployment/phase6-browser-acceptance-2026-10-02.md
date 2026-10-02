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
- Attempted synthetic template creation was not visible in Templates or the New session selector. Do not mark creation/snapshot isolation passed.
- PDF output, template snapshot immutability, and multi-account live privacy/tenant checks remain unverified.
- App Check server attestation remains unverified. Observation mode and successful browser API requests alone are insufficient evidence.
- Codespace became stopped during checks. Restart accepted but remained on setup for several minutes; a clean stop/start recovery was initiated. Backend terminal/log access remains unavailable at this checkpoint.

The JSON download timeout was a mistaken expectation about UI behavior, not an export failure: export content was subsequently validated through Copy.
