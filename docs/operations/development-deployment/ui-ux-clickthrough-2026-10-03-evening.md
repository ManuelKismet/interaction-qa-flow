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

## Continued desktop UI pass

- Template picker opens and names the available local template and Start blank clearly. Its popup spans the whole desktop width; include it in UX-E01 width refinement. No template applied and no session created.
- More session actions opens with Delete session as its sole visible item. Workspace options likewise has Clear local guest copy only. No deletion attempted. JSON backup/import was not discoverable in these inspected menus; record as a discoverability/scope question against approved backup requirements, not proof that no other path exists (UX-E08).
- Download / Share PDF opens a scope dialog identifying the current participant and offering Selected participant / All participants / Cancel. Selected participant opens a readable report with parent answer attribution, nested follow-up, unanswered marker and clear Download / Share / Print fallback actions. These are preview UI observations only, not generated PDF/download/share or cross-participant privacy acceptance.
- UX-E06: Preview PDF has no visible Close/Back control. Escape closes it and returns focus to Download / Share PDF. Add an explicit Close control for touch/mouse discoverability; preserve Escape and focus return.
- UX-E07: Preview labels Exported: 2026-10-03 12:22:35.895 during this evening review of an existing local acceptance session. Investigate whether a saved export timestamp is reused and label original-export time accurately or generate a fresh timestamp when exporting. No PDF was downloaded, so actual output metadata is not verified.
- Rename active participant opens a compact, labelled dialog with Cancel and Save name locally. Cancel was used; no name changed.

Desktop UI pass covers currently accessible unauthenticated/local surfaces. Mobile/narrow viewport has NOT been verified: browser F12 did not expose responsive controls through the available UI observation, and no viewport/emulation API is advertised. Do not substitute desktop zoom for mobile acceptance. Signed-in/admin screens and cloud group UI remain for the subsequent identity/guest phase, as they are not currently accessible without starting those flows. Long-content PDF pagination, native share, screen-reader use and comprehensive keyboard navigation remain pending. No production-ready signoff.

Next: reconcile this log with existing guest UX/consolidated handoff (avoid duplicate fixes), resolve deployed candidate identity/configured build separately, finish supported UI coverage, then proceed to guest feature/functional acceptance only after this UI-stage review. User explicitly asked to keep this sequence.

## Phone and iPad UI gate — founder correction

Founder explicitly requested phone and iPad UI/UX review before guest feature testing. Preserve this order; do not advance to guest functional acceptance on the basis of desktop completion.

Attempted browser responsive controls via Ctrl+Shift+I and Ctrl+Shift+M. Screenshots continued to show the unchanged 1363 × 936 desktop page; no device toolbar or narrowed viewport appeared. Available cloud-browser API has no viewport resize/device-emulation method. Native computer controls are disabled. Therefore this session cannot establish live phone/tablet UI results. No responsive pass is claimed.

Required follow-up targets (planned, not executed): phone 390 × 844 and 360 × 800; representative iPad portrait 820 × 1180 and landscape 1180 × 820. Check Knowledge form/search, header and menus, Interact creation and participant controls, deep branches, template picker, PDF scope/preview/footer, sign-in/signup, scrolling and keyboard-obscured inputs. Record overflow, clipping, wrapping, touch targets and dismiss/back paths per viewport. These CSS viewport checks also do not substitute for physical iPad Safari, native share or software keyboard acceptance.

Current stop point: UI-stage responsive review blocked by browser viewport capability. Guest feature/functional tests remain pending per founder sequence.


## Codespace responsive review and interactive continuation

Founder authorized an isolated Codespace browser setup. Machine reports 2 CPUs and 7941 MiB RAM; latest check showed 1476 MiB available, no swap. Playwright 1.55 / Chromium shell installed outside the app workspace. Signed Debian runtime packages installed; unrelated Yarn repository signature failure was not bypassed. Browser context explicitly uses en-GB after an initial locale startup error.

Actual CSS viewport screenshots were captured at 390 × 844, 360 × 800, 820 × 1180 and 1180 × 820. Knowledge and empty Interact rendered at all four sizes; 390-phone and landscape-iPad editor/PDF previews were captured. Initial 360-phone and portrait-iPad runner interactions timed out without JavaScript page errors; these are incomplete automation paths, not confirmed app failures. Stabilized rerun remains partial. Document scroll width matched viewport width in captures; Flutter canvas overflow still requires visual inspection.

Visual observations: phone PDF actions stack vertically and report question text wraps; therefore describing the phone screen as merely a stretched desktop is inaccurate. Knowledge search helper and Interact participant/shared-question helper text truncate with ellipses on phone (UX-E09: wrap explanatory text at narrow widths). UX-E02 touching input spacing persists on phone; UX-E06 missing visible preview close remains particularly relevant for touch. Landscape tablet retains wide fields (UX-E01). Newly generated preview showed a fresh evening timestamp; UX-E07 remains specific to the existing saved-session case and is not a universal stale-export defect.

Founder requested interactive review instead of screenshots alone. Installing a minimal virtual display/noVNC stack and full Chromium in the isolated tools environment, with one browser instance and private Codespace forwarding. No interactive session is yet verified. Screenshot contexts use synthetic local layout sample data only; no account or cloud group creation, no sharing, no guest functional/privacy acceptance.

Remaining gate: finish interactive phone/tablet menus, forms, branches, preview dismiss/scroll, templates and unauthenticated account navigation. Real iOS Safari, touch behavior and software keyboard remain separate device checks. Guest feature testing stays pending until this UI pass is complete. Served build SHA still unverified.


Interactive setup now verified: full Chromium launched in Xvfb :97, x11vnc bound to localhost:5997, noVNC/websockify localhost:8767. Codespace 8767 forwarding explicitly verified Private. Hosted dev app is visible; live click switched Knowledge to Interact, and real Chromium DevTools responsive toolbar opened (initial 400 × 625). This resolves the interactive viewport capability blocker. Phone/iPad full interactive review is still pending, as are guest functional tests. Full stabilized screenshot run completed: 390-phone and landscape-iPad paths succeeded without page errors; 360-phone session locator and portrait-iPad answer locator timed out without page errors. Do not classify these automation timeouts as app defects without interactive reproduction.
