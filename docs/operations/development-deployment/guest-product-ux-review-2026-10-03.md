# Guest acceptance and product UX review — 3 October 2026

## Scope and product contract

Founder requested continuing guest checks while tracking the original IQ-01–IQ-14 audit, product logic and UI/UX. Keep the experience simple: consistent spacing, clear actions and privacy boundaries, and minimal competing controls. Registered/admin sign-in and account-linking/conflict/switch checks are explicitly deferred.

Knowledge reduces repeated questions through reusable governed answers. Interact captures prepared questions, participant-specific answers and unexpected recursive answer-owned follow-ups. Both are modules of one platform. Solo work stays local; group sharing is deliberate; formal organisation membership and private ownership stay separate.

Browser target: https://intqaflow-dev.web.app/. Recorded deployed candidate: PR12 df6bcd3026295e9f492d140282376c927bb66844. This session did not redeploy or independently fingerprint the live bundle. Source cross-check: PR11 477c941f942aa6d4ee364c32e6fe231d5dca4a79 guest_workspace_page.dart, which is the guest/retention source incorporated into the combined candidate. No production change.

## Fresh browser observations

| Case | Result | Limit |
|---|---|---|
| Existing local Knowledge after navigation/reload | Existing synthetic item remains visible | Does not prove every search/edit/export operation |
| Add second participant | Original synthetic session now shows two participants | Participant chips are informational, not participant selectors |
| Existing answer-owned branch | Original participant's answer and its nested follow-up appear together in the report | Browser did not verify independent second-participant answers or full deep nesting |
| Local template save and selection | Saved Guest acceptance template 1503 appears in the template dropdown | Not template-version isolation |
| Create from saved template | Template reuse acceptance 1505 contains the root question and initially empty answer | Follow-up structure is not retained; see limitation below |
| Persistence after reload | New session and local-template control remain; original session retains two participants | Full cache/account-switch isolation deferred |
| Solo report | Report opens and visually shows synthetic participants and answer-owned nested JSON | Raw JSON, not a readable conversation report; rendered PDF remains unverified |
| Backup export | Export dialog opens | Clipboard copy/round trip not confirmed; no export success claimed |
| Shared group | Existing synthetic group and Knowledge revision 1 load; current identity is group admin | One browser profile/identity only |
| Members and invitation preview | Host shown active/admin; Create invitation offers Contributor — own content by default | Invitation cancelled; no invite issued or membership changed |

Synthetic changes remain: second participant, saved local template, new template-derived local session. No local clearing or test-data deletion.

## Confirmed product limitations and recommendations

1. **Guest targeted questions only address the first participant.** Source _addQuestion uses participantIds.first and UI says Add question for first participant. Participant chips have no selection callback. Recommend one simple active-participant selector used for individual questions and answers; retain shared-question creation. This is functional parity work, not evidence of a server privacy defect.
2. **Local templates discard branch structure and question scope.** _saveTemplate copies root id/text only; _createSession rebuilds root shared questions with empty follow-ups. Browser reuse confirmed root question with no follow-up. Preserve intended reusable question graph/scope while clearing answers and assigning fresh IDs, or clearly disclose a roots-only template as a narrower supported contract. Do not silently claim full Interact template parity.
3. **Solo Report / Print renders raw JSON.** Use a readable participant/question/answer report with branch context; keep JSON as a separately labelled backup/export. PDF acceptance stays pending until actual output can be observed.
4. **Desktop layout is vertically dense despite large width.** New-session and participant inputs stack directly; participant chips each occupy their own row; large answer cards, secondary controls and multiple expanded sessions lengthen scrolling. Recommend consistent field gaps, compact participant wrapping and progressive disclosure, rather than adding panels/features. Only the current desktop viewport was observed; mobile/narrow-width browser acceptance remains pending.
5. **Accessibility exposes participant labels as checkboxes, although source uses noninteractive Chip.** This caused a misleading apparent selector during testing. Verify screen-reader semantics and avoid signalling an interactive participant switch without an action.
6. **Account entry can route an anonymous guest into Create or link an account first.** Observed earlier; Back to sign in reveals the existing-account form. Recommend clear existing-account sign-in versus guest recovery wording without changing identity/linking rules. No credential or linking tests performed in this pass.

These are observations/recommendations, not application fixes or a Copilot implementation request.

## Audit reconciliation — evidence levels, not blanket closure

| IDs | Known evidence | Current disposition |
|---|---|---|
| IQ-01 | Startup fix and subsequent automated suites/build/deployment checkpoint | Implementation verified in prior records; not rerun here |
| IQ-02 | Firebase verified identity, UID membership and denied unauthenticated deployed smoke in prior records | Auth implementation evidence exists; registered browser/sign-out and production guard sign-off not completed here |
| IQ-03–IQ-05 | Original ordinary privacy fixes have independent synthetic evidence; prior live API owner/same-org/foreign-org checks recorded. Acceptance checklist also records a historical canonical-root leak | Do not close all routes from guest UI. Reconcile canonical correction on final source and retain registered multi-account browser checks |
| IQ-06 | Original department answer-owner proposal-review discrepancy | Current correction/role matrix not established by this pass; requires focused source and actor tests |
| IQ-07 | Original embedding-failure proposal transaction problem | Fake-provider suite is not outage acceptance; targeted failure/retry verification still needs current-source evidence |
| IQ-08 | Original CSV formula-prefix finding | Guest raw JSON report is unrelated evidence; current CSV policy/coverage must be independently reconciled |
| IQ-09 | Development remains fake embeddings in deployment checkpoint | Real provider activation/disclosure/customer-content policy remains a separate decision |
| IQ-10 | Original revision labels versus snapshots discrepancy | History/restore contract requires current-source verification; no restore claim |
| IQ-11 | Combined candidate records 75 backend/56 Flutter tests and build; no merge | Tests/build are evidence, not required CI checks or branch-protection completion |
| IQ-12 | Health smoke recorded | Liveness does not establish readiness/DB outage alerting; not verified here |
| IQ-13 | Original unfrozen backend dependency concern | Supported locked resolution not established here |
| IQ-14 | Dedicated dev inventory, backups, rollback and retention review/dry run documented | Recovery drill, real concurrent retention apply paths and scheduler acceptance remain incomplete |

Referenced records: operations README audit, development-acceptance-checklist.md, combined-dev-deployment-2026-10-03.md, guest-retention-verification-2026-10-03.md, guest-live-api-privacy-2026-10-03.md and hosted-browser-progress-2026-10-03.md. Some early docs describe superseded states; use dated later records and founder decisions.

## Remaining acceptance and boundary

Existing live API privacy record reports 26 passing checks with three real anonymous identities and hosted PostgreSQL in-process ASGI. It is supporting evidence, not this deployed-browser multi-device matrix.

This available cloud browser has one profile. Another tab reuses the same persisted Firebase guest identity; it is not a second participant/device security test. No browser isolation API was advertised. Do not clear the existing workspace to manufacture another identity. Pending: independent guest identity, host approval, viewer/contributor/admin actions, removal, expired/revoked/replayed invitations and two-group/organisation matrix on the final deployed candidate.

Still pending: full local answer/edit/nested/deletion-undo scenarios, backup round trip and invalid-import atomicity, narrow-width UI, readable/rendered PDF, and registered identity/linking/cache transitions. Sign-in remains deferred by founder. No cleanup apply, scheduler, IAM, App Check mode change, paid provider, merge or production release.

## Additional browser validation

Entered malformed synthetic backup text in Import backup. The visible form reports The backup is not valid IntQAFlow guest JSON and Review selection remains disabled. Cancelled without importing. This confirms malformed-JSON UI rejection, not successful round-trip import or deeper schema/atomicity acceptance. Screenshot: intqaflow-guest-import-validation-1791036605108.jpg.

## Organisation, department, team and guest-group access review

Source checked on combined deployed candidate df6bcd3: PermissionService, QuestionVisibility, GuidedService._require_view/_owned_session, TeamService, department routes, mounted v1 router and guest routes. This is source review, not fresh registered-browser acceptance.

Confirmed current behavior:
- Registered Firebase identity must resolve active server-controlled organisation/user/role membership. Signup alone does not enrol an organisation; organisation creation route file is not mounted in the protected v1 router. Complete customer-facing organisation invitation/provisioning UX is not established by this review.
- Organisation admins create departments/teams and add/remove team members. Users currently have one nullable primary department and can belong to multiple teams. Teams may have a parent department or be cross-functional.
- Knowledge visibility is organisation, department or private only. Organisation content is visible to active members of that org; department content requires the actor's matching non-null primary department; private content requires its author. A team_id tag does NOT restrict Knowledge to that team's members. Another team in the same department can read department-visible content.
- Interact adds team visibility. Owner can view own session; matching team membership grants team-session read; matching primary department grants department-session read; organisation visibility grants org read. Organisation admin can view non-private sessions, including team/department sessions; private sessions remain owner-only. Viewing does not grant editing: current _owned_session limits session mutation to owner or admin of a non-private session.
- Department/answer-owner governance is a separate server-controlled grant; team membership does not grant verification authority. Metadata listing can expose names of org teams/departments without granting access to their content.
- Guest groups use separate guest memberships/invitations/roles, not organisation teams/departments. Current guest create/join endpoints explicitly require anonymous Firebase provider. A linked registered identity can continue authorized existing memberships, but arbitrary registered identities cannot currently create/join guest groups through those endpoints. Account UX must accurately disclose this limitation; do not silently switch identities.

Finding: inconsistent scope support between Knowledge and Interact makes team privacy easy to misunderstand. Current team-tagged Knowledge must not be presented as team-private. Admin non-private Interact access needs explicit disclosure rather than a blanket only team members claim. Registered organisation enrolment and department assignment UI need a separate end-to-end review.

Recommendation for founder review, NOT an implemented permission change:
- One clear Sharing control with Private / Team / Department / Organisation, plus a who-can-access summary, once both modules truly implement those scopes.
- Add genuine team visibility to Knowledge before offering team-private sharing. Team membership does not imply access to all parent-department content, and department membership does not imply access to each team. Choose whether the existing primary-department model is sufficient; do not silently introduce multiple departments.
- Private owner-only. Disclose and decide admin handling for non-private scopes. Separate read/contribute/edit/manage membership/verify permissions. Use organisation-admin-approved onboarding/membership, with no self-selected privilege or auto-enrolment by signup/email domain.
- Apply identical membership rules to search, lists, direct IDs, aliases/canonical links, attachments/children, history and exports; membership removal should deny subsequent requests and clear inaccessible cached views. Downloaded copies cannot be revoked.
- Keep guest groups out of formal org privilege, and avoid adding a third organisational group concept if teams already cover collaboration.

Acceptance: users in Team A and B in the same department, another department, multi-team user, departmentless user, owner, org admin and foreign-org member. Check positive/negative reads and changes across both modules, search/direct/history/export, removal and visibility changes. This organisation matrix remains pending while registered sign-in is deferred.
