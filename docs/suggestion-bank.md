# IntQAFlow Suggestion Bank

Implemented on the development feature stack in feat/suggestion-bank-20261104. This is a third connected module alongside Knowledge and Interact.

## Experience

Employees can submit suggestions, proposals, feedback and workplace etiquette to an existing organisation, department or operational team. Verified registered Group members can use an independent Group bank. Every item shows its status, original proposal, accountable reviewer, expected review date, official responses and immutable contribution history. Submitting, commenting or supporting follows the item. Following and Updates provide an in-app response loop; no email or external messages are sent.

Reviewers use the existing scoped review permission, department answer ownership or organisation administration authority, and must also have audience visibility. Group decisions require the Group admin role; editors/contributors can submit and contribute, and viewers remain read-only. Assignments require a current active reviewer with both visibility and decision authority. Progress checks reassess that authority. Organisation and Group roles never substitute for one another.

The review flow is Submitted -> Under review -> Needs information / Planned -> In progress -> Implemented / Not proceeding. A reviewer can decline with a reason, or reopen a closed decision for review. Planning/progress/completion require an accountable reviewer. Official actions require an explanation. Closed suggestions remain readable and can retain agreed workplace guidance.

## Duplicate contributions and escalation

The submission dialog checks related accessible suggestions and offers a deliberate choice to open/support an existing suggestion or submit separately. Reviewers link duplicates only within the identical audience. Original suggestions, authors, examples and history are retained; links can be removed. Linked originals cannot form chains or cycles. Linking is a reversible merge-by-reference, not destructive consolidation.

Escalation previews the exact title, problem, proposed change and benefit. It requires a selected accessible destination and explicit visibility confirmation. It creates a destination submission; the source stays in its original audience. Private comments, contributor history and examples are never copied. Organisation and Group workspaces cannot be crossed. A source reviewer can escalate to an audience where they can submit, but does not gain authority there.

## Standing practices, Interact and Knowledge

For an agreed/assigned proposal, reviewers can adopt, revise or withdraw a standing workplace practice. The Practices view remains available after closure; every version or withdrawal remains in the suggestion history. Example: refill the printer tray after using its last sheet.

A deliberate Start Interact action creates a draft review with the same audience and a source reference, problem/proposed-change/benefit questions and an outcome prompt. It works for organisational sessions and Group Interact entries. It does not publish Knowledge. Organisational users can use the existing Interact -> Knowledge proposal/review process, then explicitly link a verified Knowledge question with the same audience back to the originating suggestion. Group practice guidance remains in the Group bank; its Interact workspace provides the existing deliberate Group Knowledge capture workflow. Review permission does not grant answer verification authority.

## Practical NIA helpers

The bank service owns authoritative context and permissions. NIA provides bounded, scoped keyword/typo matching, related suggestions, accessible verified organisational Knowledge and concrete review prompts. Unanswered/overdue queues and in-app updates expose work needing a response. No generated answer, embedding call, automatic decision, automatic publication, worker scoring or permission expansion is introduced. Real semantic embeddings remain deferred until the first customer.

Flutter reads are keyed by Firebase UID, workspace, audience and query, and are cancelled on disposal. The existing API client attaches Firebase authentication and App Check and rejects late responses after account changes. Every server operation independently checks current membership, audience, Group lifecycle and authority.

## Persistence and recovery

Migration 0017 adds bank_suggestions, bank_activities and bank_followers without altering existing tables. Organisation/Group root deletions cascade into the new records; user work and existing development data are preserved. No new data deletion endpoint or retention policy is introduced. Group access follows its existing archive/expiry and membership lifecycle.

Audience and submitted content are immutable. Actions use revision checks and row locks/CAS, plus request fingerprints for safe acknowledgement retries. Submission keys are scoped to the author; reusing a key for different content fails. Support is idempotent per contributor. Response dialogs keep drafts on failures and can explicitly review the latest state before retrying a conflict. Uncertain submissions retain their original payload for safe retry. Activity and list reads are paginated. Suggestions and helper results never include private cross-scope search candidates.

## Delivery boundaries

Use the existing isolated development environment only. Run migration checks, backend tests, Flutter analysis/tests and a web build before any DEV rollout. Production changes, merging the pre-existing draft PR stack and cleanup of unrelated work are separate tasks. Migration downgrade removes only the new bank tables and must not be used on data that needs preserving.

The development implementation checkpoint records exact validation and rollout evidence. Passing source tests does not establish hosted or physical-device acceptance.
