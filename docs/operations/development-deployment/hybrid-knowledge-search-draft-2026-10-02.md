# Hybrid Knowledge search implementation draft

Status: drafted for review; not implemented or deployed. Decision recorded 2026-10-02. Development currently uses deterministic-fake-v1; approved direction is hybrid keyword and real semantic embedding retrieval with privacy preserved.

## Problem and intended behavior
Current related-match threshold 0.68 rejects single-word password (0.4082) and reset password (0.5774) against How do I reset my password? Prefix pass scores 0 and paraphrase How can I recover account access? scores 0.3333. These are provider-only synthetic baseline measurements, not live-corpus quality metrics.

Typing pass, password, reset password and then a complete question should progressively return relevant, permitted questions. Do not wait for a completed sentence. Real semantic embeddings already supply meaning matching; no generative LLM is required for this retrieval feature.

## Proposed implementation
1. Retain the current three-character minimum and 350 ms debounce. Cancel obsolete work where possible and ignore responses for older queries. Empty or punctuation-only input returns no suggestions. Render keyword results even if embedding lookup is unavailable.
2. Add weighted PostgreSQL full-text indexing over question titles and details, including historical question phrasing. Weight titles more strongly. Preserve normalized exact-title matching. Use prefix matching for the unfinished final token so pass can find password. Safely tokenize input and bind SQL parameters; do not interpolate raw user input as SQL or trust user-supplied tsquery operators. Preserve exact identifiers through a simple-token lexical path if English stemming discards or changes them. Use any-term candidates with an all-term/phrase relevance boost so adding words refines results without blindly requiring a whole sentence.
3. Retrieve keyword candidates and semantic candidates separately. Do not apply the semantic 0.68 cutoff to keyword matches. Each branch must enforce organisation, author-only private visibility, department membership, eligible question/answer states, and permission on both the matched historical question and its canonical target before limiting candidates.
4. Keep the embedding provider abstraction. Select/configure a real provider and re-embed stored questions using that provider's model/dimensions. Avoid mixing fake and real vectors. Initially index title plus details as the existing embedding service does; keep answer-content indexing as a separately evaluated extension. Cache embeddings by normalized query, model and dimensions with short retention, avoiding raw query logs. Check provider disclosure and incremental spending against the agreed development budget before activation. This draft does not choose or activate a paid provider.
5. Collapse permitted aliases to their canonical question and combine rankings using reciprocal rank fusion, rather than adding incomparable keyword/vector scores. Preserve exact-match priority and use current verification/freshness as a tie-break among similarly relevant results. Apply the final result limit after canonical collapse. Keep existing match provenance. Do not present lexical-only scores or RRF scores as semantic probabilities; adjust confidence labels accordingly.
6. Keep the search API response backward compatible or explicitly update Flutter parsing and result labels together. Add lexical retrieval/index migration, safe query construction, ranking integration, graceful embedding-error fallback, and meaningful backend/Flutter tests. No change to approved-content ownership or visibility follows implicitly from retrieval changes.

## Quality acceptance plan
Build at least 30 reviewed synthetic queries against a small seeded corpus with expected canonical IDs and roles. Include one-word queries, prefixes, two-word phrases, punctuation/case, exact technical identifiers, paraphrases, irrelevant queries, historical aliases, answered versus open questions, archived content, current versus stale verification and missing department membership.

Required gates: password, reset password and pass return the intended permitted password question in the top five; agreed paraphrases succeed only with the real provider; inaccessible private/foreign-tenant items never appear; aliases do not duplicate results; unrelated queries do not receive high-confidence labels; embedding failure preserves lexical results; rapid typing never replaces newer results with older responses. Evaluate retrieval recall, top-result relevance, latency, request count and incremental provider cost. Set broader numerical quality targets after reviewing the labeled corpus; do not manufacture a production quality score from the seven fake-provider probes.

Run existing backend suite and Flutter analysis/tests/build in Codespace, then hosted development acceptance. Retain the isolated local database until end-to-end sign-off. Nothing is merged or sent to production by this plan.

## Ownership policy dependency
Unanswered questions may be edited/removed by their author. Once answered, question changes/removal are gated. Authors manage their own unapproved answers. Changes/removal of accepted or verified question/answer content are administrator-only, retain revisions and reasons, and respect existing private visibility. Recommended removal is recoverable archive/soft deletion. See knowledge-search-ownership-review-2026-10-02.md for the recorded user policy and current implementation gaps.

## Official implementation references
- PostgreSQL 16 full-text search controls, weights, ranking and prefix queries: https://www.postgresql.org/docs/16/textsearch-controls.html
- pgvector official maintainer repository, Hybrid Search and Reciprocal Rank Fusion: https://github.com/pgvector/pgvector
- OpenAI official vector embeddings guide: https://developers.openai.com/api/docs/guides/embeddings
