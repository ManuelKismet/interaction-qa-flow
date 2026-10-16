# HNI — contextual examples and behavioural rationale
Companion to NOPAK_HNI_WORK_HANDOVER_2026-10-16.md. Design examples, NOT shipped functionality.

## Principle
An Intelligence-Native Application builds context awareness, recommendation, adaptive UX and safe action into product workflows, **not an external agent/chatbot**. Use small deterministic native Dart logic for simple tasks; optional on-device or server-side inference only where justified. User retains control. Proactive suggestions should not require prompting each time.

## Happnn — activity intelligence
1. **Tennis**: Two independently opted-in nearby people want to play tennis today. Suggest a possible shared interest without revealing either person's identity or exact location. Expressing interest should precede any connection.
2. **Football**: Several users want to play this afternoon. Suggest compatible activities or forming an activity; check time/availability and existing product rules. Shared static interest alone is not an agreement.
3. **Outdoor weekend**: A user says “I want to meet people in Leeds this weekend through outdoor activities, under £20.” Rank appropriate activities, explain recommendations and optionally prepare a plan. Don't book/pay/share private data without required approval.
Rationale: encourage people to step outside and participate, rather than maximise screen time.

## TempConnect — opportunity intelligence
4. **Business owner + designer**: One contact card expresses a need for branding/logo design; another opted-in card offers graphic design. Match complementary *needs and offers*, not just identical profile labels. Offer a discreet connection suggestion without revealing private fields.
5. **Discovery contexts**: nearby opted-in users, people at the same networking event, or opt-in nonlocal intent-based matches. Distance is a useful signal, not a prerequisite for remote business opportunities.
6. **Adaptive sharing**: based on intentional use, prioritise frequently used QR/contact card controls or offer guidance, but keep other options accessible and preserve existing visibility, temporary sharing and expiration rules.
Rationale: TempConnect remains a privacy-controlled contact/QR sharing application, not a full business marketplace.

## IntQAFlow — knowledge intelligence
7. **Relevant answer**: Suggest previously answered, accessible questions in Knowledge when someone asks a similar question. Apply organisation/department/team/group/personal authorisation *before* ranking so even the existence of inaccessible knowledge is not leaked.
8. **Stewardship**: Identify duplicate/stale/gap candidates; prepare review proposals, but do not automatically rewrite verified knowledge, merge canonical records or bypass review/audit. Interact guided Q&A can suggest contextually relevant questions.
Rationale: reduce repetitive questions and improve governed knowledge, not become a generic chatbot/forum.

## Adaptive and proactive experience
9. **Different Happnn users**: new user receives subtle help choosing interests, explorer receives relevant activities, host receives relevant scheduling/hosting shortcuts. Illustrative only, not approval to replace accepted designs.
10. **User struggles**: provide contextual explanations, restore path or simpler controls, without assuming sensitive characteristics.
11. **Unprompted suggestions**: surface genuinely useful activity, service or knowledge opportunities at sensible times. Provide explanation, dismissal, control and frequency limits. Avoid interruptive UX.
Preserve brand, compact styling, established navigation and existing product logic. Adaptive UI should mainly adjust content ordering, hints, shortcuts and suggestions, with user control and reset.

## NIC conceptual workflow and limits
Permissioned context -> policy/consent gate -> match/rank -> explanation -> optional user acceptance -> backend-authorised action -> auditable outcome.
Proximity is a shared *architectural capability* used differently by each app, but it does not imply a shared cross-app data store. Potential sources include approximate GPS, event co-presence and possibly Bluetooth if supported. Both users must opt into peer discovery. Do not infer consent from granting location permission. Backend controls actual disclosure. Block/mute, expiry, revocation, stale coordinates, location-inference attacks, anti-harassment and rate limits need design before live use.

Present code is isolated pure-Dart matching and an approximate distance calculator on supplied coordinates; **no live sensing, learned behavioural adaptation, background scanning, UI integration or production test validation**. Test exact, partial and no matches; timing conflicts; needs/offers; both-party opt-in; blocked or expired cards; revoked permissions; invalid coordinates; cross-tenant leakage; rankings; battery/performance; notification restraint.

## Questions still open
Location accuracy/radius and retention; permission UX; iOS/Android background feasibility; model selection; adaptive learning from explicitly stated preferences vs behaviour; useful match thresholds; notification rates; rollout sequence. These are design questions, not approvals.

## Delivery constraints
Only use `experiment/hni-from-dev-isolation-20261016` in each repository for HNI changes. No modification of main, dev, production or ongoing release work, and no merges/deployments without explicit approval. IP discussion is paused. Inspect latest checkpoint and branches before work. Older `experiment/hni-native-intelligence-poc` branches were requested for deletion, but deletion had not been verified.
