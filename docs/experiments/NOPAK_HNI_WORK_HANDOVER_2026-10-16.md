# NOPAK — HNI Intelligence-Native Applications handover
Date: 16 October 2026
Status: research/prototype, isolated; no production integration

## Vision
HAPPNN TECHNOLOGIES Ltd is exploring **Intelligence-Native Applications**: intelligence integrated into app design and workflows, not a separate visible agent or chatbot. Apps understand user intent/context, adapt guidance and UI in real time, proactively suggest relevant opportunities, and carry out only duly authorised low-risk steps, escalating consequential actions for review. Prioritise small deterministic native logic, then optional on-device ML/cloud inference as necessary. Keep UX simple and user control explicit.

Working architectural names: **HAPPNN Native Intelligence (HNI)**; shared **Native Intelligence Core (NIC)**. These are exploratory names, not separately shipped products.

## Product applications
- **Happnn — activity intelligence**: match shared activity interests and intentions; discover relevant local real-world experiences and optionally suggest mutually opted-in nearby peers. Goal is real-world participation, not screen time.
- **TempConnect — opportunity intelligence**: match contact-card offerings (skills, services, businesses) with needs or collaboration opportunities; allow temporary controlled connection. Respect per-card visibility and never silently reveal private contact details.
- **IntQAFlow — knowledge intelligence**: assist knowledge retrieval, identify duplicate questions and gaps, suggest relevant authorised knowledge and reviews. Maintain multi-tenant permissions, review/audit governance.

## Cross-cutting architecture
- NIC conceptual modules: context handling, consent/permission policy, matching/recommendation, adaptive UX, explanations, learning/feedback, action/approval gate.
- **Proximity/context** belongs in the shared architecture, applied selectively by products. Potential location sources: approximate GPS location, event-based copresence, possibly Bluetooth when platform permits. The present prototype only computes distance from supplied coordinates; it does **not** collect device location, query actual users, or send notifications.
- Default deny for proximity discovery unless both participants opt in; backend must authoritatively enforce disclosure and per-user/card visibility; avoid exposing exact coordinates or identity through suggestions without consent.
- No autonomous payments, irreversible operations or private disclosures without appropriate approval. Allow opt out, revoke, explain why, dismiss, and deterministic fallback.
- Adaptive UI should change relevant content, explanations, shortcuts and workflow priorities without unpredictably rearranging core navigation. Retain approved product branding, UI, and existing business logic.
- No shared cross-app user data or cross-app integrations without separate explicit design and permission.

## Actual GitHub repositories
- Happnn: `ManuelKismet/happnn`
- TempConnect: `ManuelKismet/tempconnect`
- IntQAFlow: `ManuelKismet/interaction-qa-flow`

**Latest HNI experimental branches, created from identified development-isolation branches** (not directly from main):
- Happnn: `experiment/hni-from-dev-isolation-20261016` based on `feature/happnn-environment-isolation`
- TempConnect: `experiment/hni-from-dev-isolation-20261016` based on `feature/tempconnect-environment-isolation`
- IntQAFlow: `experiment/hni-from-dev-isolation-20261016` based on `chore/intqaflow-private-dev-isolation`

Development-isolation branches may not include every newer in-progress development commit. Verify ancestry and progress read-only before future integration.

### Files copied into dev-isolation-based experiments
Happnn:
- `docs/experiments/hni-native-intelligence-poc.md`
- `lib/hni_experimental/activity_matcher.dart`
- `lib/hni_experimental/proximity.dart`
- `test/hni_activity_matcher_test.dart`
- `test/hni_proximity_test.dart`

TempConnect:
- `lib/hni_experimental/opportunity_matcher.dart`
- `lib/hni_experimental/proximity.dart`
- `test/hni_opportunity_matcher_test.dart`

IntQAFlow:
- `docs/experiments/hni-native-intelligence-poc.md`
- `apps/flutter_app/lib/hni_experimental/knowledge_matcher.dart`
- `apps/flutter_app/test/hni_knowledge_matcher_test.dart`

Current implementations are simple deterministic Dart matchers, not on-device learned models, live proximity sensing, or integrated UI. Matching engines and tests were committed; tests **not yet executed**. No deployment or integration performed. Further hardening required.

### Old branches pending deletion
**Do not mistake these for current work:** `experiment/hni-native-intelligence-poc` in **all three** repositories. These were originally based on `main`. User expressly requested their deletion. As of last response, they **still existed** because the available GitHub connector lacked a branch deletion method; user was given GitHub branches links for manual deletion. Check their current status before asserting that they were deleted. Delete only those exact old experiment branches if a safe, authorised method is available; NEVER delete new branches or touch main/dev.

## Strong operational constraints / approved decisions
- **DO NOT modify, push to, merge to or deploy `main`, production, or development branches/environments.** Read-only inspection of dev is allowed. Ongoing dev work must not be disturbed.
- Limit HNI writes to the three explicitly isolated experimental branches; do not presume merge approval.
- Do not touch release/readiness batches or accepted interfaces.
- IP/patent/publication research is deliberately **paused** by user; focus on real implementation.
- Do not call experiments 'validated' until actual tests run; distinguish synthetic demos from production functionality.
- Prefer working via Codespaces/Work and GitHub with explicit validation and documentation/checkpoints; consult repository workflows and up-to-date checkpoints before acting.

## Next stage
1. Inspect new experimental branches and ongoing dev state read-only; verify isolation and transferred files.
2. Run Flutter/Dart formatting, analysis and tests in an appropriate Codespace or environment for each isolated branch. Fix defects only on experiment branch.
3. Extend isolated demonstrations for proximity + interest matching (Happnn), card offerings/needs + proximity + card visibility (TempConnect), authorised knowledge matching (IntQAFlow).
4. Add safety tests for missing or revoked consent, invalid location, no matches, stable rankings, unauthorised results and data minimisation; backend authority must be considered before live user-to-user discovery.
5. Prototype unobtrusive, reversible adaptive UI using synthetic fixtures while preserving current accepted designs.
6. Document findings, metrics, tradeoffs and next decisions; do not merge/deploy without user's explicit authorisation.

## How to resume
In a new ChatGPT Work conversation inside the **NOPAK** project, instruct the assistant to read this handover from one of the three HNI experimental branches and inspect the same-branch files in each GitHub repository. Reconfirm all branch statuses and recent code since this document is a snapshot. Continue work on experiment branches only.

## Contextual examples and behavioural rationale
Read **[HNI_CONTEXTUAL_EXAMPLES_AND_LOGIC.md](HNI_CONTEXTUAL_EXAMPLES_AND_LOGIC.md)** in the same experimental branch for the detailed Happnn/TempConnect/IntQAFlow scenarios, adaptive UI examples, proximity/privacy logic, and agreed versus unresolved decisions. Treat that document as part of this handover.

## Latest brainstorm: activity formation and ambient assistance
Read **[HNI_ACTIVITY_FORMATION_AND_AMBIENT_ASSISTANCE.md](HNI_ACTIVITY_FORMATION_AND_AMBIENT_ASSISTANCE.md)** in this experiment branch for the no-existing-activity proximity flow, temporary activity groups, host-draft handoff, micro-hints, micro-actions, intentional silence, constraints and open questions. It is a required part of this handover; these are proposals, not implemented features.
