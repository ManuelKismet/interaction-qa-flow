# Knowledge search and ownership review — 2026-10-02

## Agreed search direction
Use hybrid keyword and real semantic embedding retrieval, with organisation and visibility constraints applied to both branches. Show suggestions while typing, without requiring a completed sentence. Existing Ask controller starts at three trimmed characters with a 350 ms debounce. Prefix matching should handle unfinished words; keyword matching should retain exact identifiers. Real embeddings already perform meaning matching and do not require a separate generative chat model.

This is a recorded implementation decision, not a claim that hybrid search or real embeddings have been deployed. Development still uses deterministic-fake-v1. Switching providers requires rebuilding stored embeddings with the selected model, suitable provider credentials, and review of the text disclosed to that provider.

## Executed quality baseline
Provider-only synthetic probe in the development-release backend virtual environment. Target question: How do I reset my password? Related threshold: 0.68. Question details were omitted; these are controlled vector probes, not a live corpus relevance evaluation.

| Query | Cosine similarity | Clears current threshold |
|---|---:|---|
| How do I reset my password? | 1.0000 | Yes |
| password | 0.4082 | No |
| reset password | 0.5774 | No |
| pass | 0.0000 | No |
| How can I recover account access? | 0.3333 | No |
| password reset | 0.5774 | No |
| office lunch menu | 0.0000 | No |

Exact-title equality is additionally admitted by the repository. Current fake vectors hash lowercase alphanumeric tokens and discard word order. Baseline demonstrates short-query, prefix and paraphrase limitations; it does not sign off the future hybrid implementation. Follow-up evaluation must cover exact terms, prefixes, paraphrases, unrelated queries, canonical collapse, stale verification, tenant/private filtering, latency and stale responses while typing.

## Current ownership behavior (source inspection)
Question service update, resolve, reopen and archive share the author-or-admin gate after visibility checks. Archive changes status to archived; no question hard-delete route was found. It does not reject answered, accepted or verified content. Archived questions are excluded from normal search eligible statuses. Updating a question is not blocked after answer verification. Resolve marks an answer accepted; administrator or assigned department answer-owner verification is a separate governance operation. Reopen clears the accepted-answer reference and resolved timestamp.

Answer update rejects verified and accepted answers. Answer deletion rejects verified and accepted answers. Governance includes version snapshots, superseding and audit events. These answer protections do not protect the parent question from author changes. Private visibility remains owner-only, including for administrators without visibility.

## Recommended ownership policy — proposal, not yet implemented
- Unanswered questions: author may edit and archive; retain content instead of hard deleting.
- Questions with answers: preserve other contributors' work; author may request substantial edits or archival, with reviewer approval.
- Accepted or verified shared knowledge: author retains attribution; permitted administrators or department knowledge owners control archival and reviewed version changes. Changes to question meaning require answer review again.
- Keep accept/resolve distinct from formal verification; request reopening/review rather than silently removing the approved state.
- Record actor, reason and timestamp for archival and provide restoration. Never widen private-content visibility through governance authority.

Sources inspected: backend/app/services/question.py, services/answer.py, services/permissions.py, services/governance.py, repositories/search.py, ai/embedding_provider.py and apps/flutter_app/lib/features/ask/application/ask_suggestions_controller.dart on fix/development-auth-diagnostics (9236eb5).

## User-directed ownership policy — recorded 2026-10-02
This supersedes the earlier proposal allowing department knowledge owners to manage approved content. Implementation remains pending.

| Content state | Author rights | Administrator rights |
|---|---|---|
| Question with no answers | Edit or remove own question | Manage visible content |
| Question with answers | Question edits/removal gated to preserve contributors; request changes | Review changes/removal |
| Answer not accepted or verified | Answer author may edit/remove own answer | Moderate visible content |
| Question or answer with accepted/verified answer | No ordinary author edit/removal | Admin-only versioned changes or removal |

Recommendations accompanying the policy: use recoverable archive/soft deletion for removal, retain attribution and audit records, preserve approved versions, and require review again when meaning changes. Existing private visibility rules still apply to administrators. The admin-only rule concerns modifying/removing approved content; approval creation and assigned department verifier roles are a separate existing governance capability and have not been changed by this record.
