> NIA naming update —16October2026: **Native Intelligence Architecture (NIA)** replaces HAPPNN Native Intelligence (HNI) as the product-neutral architecture name. **NIC** is Native Intelligence Core; **ANI** is Ambient Native Intelligence; each product retains its own specialised intelligence. This is terminology only: historical HNI filenames, branch names and Dart symbols remain for compatibility; no redesign or refactoring is implied. Read [current progress checkpoint](NIA_PROGRESS_2026-10-16.md) before executing next steps.

# NIA brainstorming continuation — 16 October 2026
Status: PROPOSAL / brainstorming, not implemented or approved for rollout. Companion to NOPAK_HNI_WORK_HANDOVER_2026-10-16.md and HNI_CONTEXTUAL_EXAMPLES_AND_LOGIC.md.

## Happnn: Intelligent Activity Formation
**Problem:** compatible nearby opted-in users want to do an activity but none is hosted/scheduled. Happnn is not a messaging app; simply identifying shared interests does not help participants actually meet.

Proposed flow:
1. Users optionally express a **time-limited intention** ("want to play badminton this afternoon"), distinguished from stable interest ("like badminton") and actual commitment ("going to a specific activity").
2. NIC first seeks relevant existing activities; where none are suitable, it recognises independently opted-in users who share activity, compatible time window and coarse discovery area. Enforce mutual consent, blocked-user rules and safe visibility; never reveal exact locations or identifying small-group aggregates.
3. App subtly shows a contextual opportunity, such as "Others in your discovery area want to play badminton this afternoon" with Explore / Interested / Not now. Numbers must not be invented or displayed unsafely.
4. When enough people express interest, create a **temporary proposed activity group** (not a public event, confirmed booking, or open-ended chat). Use structured controls for preferred time, safe public venue, participation count, equipment, and whether booking/host is needed. Match requirements to activity: jogging may need two, doubles badminton four; no single global threshold.
5. Interested users individually confirm. Default recommendation: **shared structured coordination plus app-generated host draft**. A user volunteers for organiser role where required; once confirmed, convert proposal through *existing* Happnn host/scheduled-activity APIs and permissions. Do not falsely appoint a host or invent venue availability.
6. Provide confirmed users with authorised details; expire stale intentions/proposals, allow withdrawal/cancellation; keep existing safety/moderation and activity lifecycle.

Alternatives: anonymous aggregate interest indicator is first choice; mutual interest can unlock voluntary activity-based introductions without private contact exchange. Personal activity profiles require explicit opt-in and are not approved by default. Heatmaps deferred until safe against re-identification. Hostless shared coordination is a possible future option, not yet selected.

Example: four consenting people interested in badminton today can discover compatible interest, suggest 5/6/7pm, agree public venue, confirm and have a volunteer host create the normal activity. All counts/venues/times are *synthetic concept examples*, not real availability.

Rationale: solves a sparse-host/cold-start problem and turns intent into outdoor participation without turning Happnn into a chat/dating app.

## Ambient Native Intelligence: helping users use the application
Proposed **Contextual Assistance Intelligence** extends adaptive UI:
- Invisible help: preserve drafts, safe defaults, continuation and user-authorised preferences.
- Dismissible micro-hints near relevant controls, subtle and temporary (e.g. "Save this host setup as a template").
- Intent-aware micro-actions that help directly: "Show similar activities", "Save for later", "Reuse previous setup", "Explore tennis nearby", "Continue where you left off".
- Smart next-step assistance when input incomplete, e.g. an absent host thumbnail.
- Intelligent recovery when operation repeatedly fails, with concrete supported options and drafts preserved.
- **Intentional silence:** experienced users or successful workflows receive no interruption. The system deciding *not* to show a tip is central.
- Trigger via deterministic, event-driven rules first. Later privacy-preserving ML only if evidence of user benefit. Apply opt-out, dismissal, frequency caps, cooldowns, suppression of repeated hints, nonblocking positioning. Preserve accepted compact layout, navigation, brand, and existing functionality.

Illustrations: new explorer gets a single contextual save hint; repeat host gets a template micro-action; repeated thumbnail upload error shows recovery; returning proficient host sees nothing. In TempConnect analogous hints concern QR/card sharing/visibility and contact opportunity actions; in IntQAFlow knowledge suggestions and review guidance.

## Shared conceptual architecture
Permissioned context -> opt-in/policy gate -> match or assistance decision -> safe explanation/indicator/micro-action (or silence) -> user confirmation -> authoritative existing app action -> auditable result.
Opportunity Intelligence handles interest/intention/proximity/activity formation. Assistance Intelligence handles guidance, feature discovery and recovery. Proximity stays conceptual shared NIC capability; actual cross-user matching and permissions are product-specific authoritative services. Avoid cross-app user-data pooling.

## Open technical/product decisions
Intent expiry; approximate distance thresholds and location inference; small-group aggregation privacy; time compatibility rules; group moderation, cancellation, reporting and host duties; public venue availability; how draft conversion fits current broadcast/scheduling cycle; UI placements; tip thresholds and learning opt-in; rate limits; feasibility on iOS/Android background execution. These require evidence before feature approval.

## Test/acceptance ideas
Use synthetic fixtures initially. Reject matches without both parties opting in, if blocked, expired or time-incompatible. Avoid exact coordinate disclosure. Never create a hosted activity or booking without user confirmation. Test activity-specific minimum participation, host cancellation, repeated tip suppression, dismiss/opt-out, accessibility, unchanged navigation and no-AI fallback. Measure proposed-to-confirmed activities, successful participation, helpfulness, privacy/safety incidents, tip dismissal and workflow success.

## Operational restrictions
All work limited to `experiment/hni-from-dev-isolation-20261016` in each of three repos. No modifications/merges/deployment to main, dev or production. Ongoing development is read-only. IP discussions paused. **Current HNI matching/proximity code does NOT implement activity formation or ambient guidance.**
