# Hosted development UI/UX click-through — 3 October 2026 evening

Founder requested UI/UX review and logging before guest feature/functional acceptance. Review target: https://intqaflow-dev.web.app/ in cloud Chrome, desktop viewport approximately 1363 × 936. Review is of the visibly served app; deployed source SHA has not been independently identified in this review. Do not attribute observations to PR13 abb224f merely because that candidate passed automated checks.

## Confirmed observations and recommendations

| ID | Observation | Recommendation / priority |
| --- | --- | --- |
| UX-E01 | Knowledge search/form and Interact session forms span nearly the whole desktop width. | Constrain reading/form width and use responsive gutters; medium polish. |
| UX-E02 | Knowledge Question, Details and Answer fields meet without vertical gaps; Interact answer and follow-up fields also meet. | Apply consistent field/section spacing; medium polish. |
| UX-E03 | Interact nested question cards, response labels and follow-up controls have weak visual hierarchy and substantial repeated chrome. | Clarify question/answer/parent branch grouping with modest spacing and typography; medium polish, preserve answer ownership. |
| UX-E04 | Entering Sign in replaces guest workspace; inspected Sign in/Create account screens offer no visible return-to-guest control. Reload returns to guest. | Add explicit Back to guest workspace without losing local work; navigation issue. Browser Back not yet checked. |
| UX-E05 | Sign-in secondary action combines Create account or link guest recovery. | Explain distinct signup/recovery intent and consequences before identity change; wording recommendation, linking not tested. |

## Verified UI-only paths

- Knowledge/Interact tab switching and existing local session expand/scroll.
- Existing session presents active participant, rename/add participant, shared/targeted questions, nested answer-owned follow-ups, template and Download / Share PDF controls. Presence does not prove functional success.
- Knowledge no-match search displays No local matches and explains organisation Knowledge is not shown.
- Account menu displays local guest status, Sign in and Create account.
- Sign-in and registration screens open with constrained centered cards and field gaps.
- Workspace utility menu currently exposes Clear local guest copy. No deletion performed.
- Browser-local/privacy messaging is clear; local content survives the inspected reload. Existing browser-local acceptance content is not evidence of retained cloud test accounts.

## Review boundaries and continuation

No credentials submitted, accounts created, roles granted, shared groups enabled, cloud configuration changed, app deployed or merged. Do not delete existing local content. UI checks are not guest functional/privacy acceptance. Mobile viewport, PDF preview/action menus, templates, keyboard focus, registered/admin screens, shared-group UI and actual download/share remain pending. Continue UI review before guest functional tests per founder direction.

Workflow: Copilot owns application corrections/tests, Codex owns environment and independent review, founder reviews acceptance. Current continuation checkpoint records candidate abb224f with 82 backend/79 Flutter passing and release JavaScript build pass; 12 analyzer infos remain. Earlier deployment record must not be substituted for proof that latest candidate is served.
