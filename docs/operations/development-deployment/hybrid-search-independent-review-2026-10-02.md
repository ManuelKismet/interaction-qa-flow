# Independent hybrid search review — 2026-10-02

Reviewed PR #8 commit 34fb5222b07eac98d6fb56d5624460df027f86ce in detached Codespace worktree /workspaces/intqaflow-search-review-34fb522. The verified development base 9236eb5 is an ancestor. Source was pinned while Copilot continued other tasks.

## Validation

- Existing backend suite: 59 passed in 6.66s, isolated SQLite and fake embeddings.
- Flutter dependency lockfile accepted; analyzer clean.
- Flutter tests: 21 passed.
- Release web build: passed with --no-wasm-dry-run (optional Wasm dry run excluded).
- Copilot's 31-query labeled test passes within that backend suite. It deliberately fails the embedding provider and exercises SQLite keyword fallback, canonical collapse, archive/department/private/foreign-tenant filtering. It is not evidence for real embedding semantic quality, PostgreSQL full-text SQL, pgvector execution, or migration 0009 upgrade/downgrade.

## Confirmed blocker: repeated answers crowd out canonical search results

Independent synthetic regression fails. Two accessible answered questions match password. First title is exactly password and has 60 community answers; second title is password rotation policy with one community answer. Search limit 5 returns only the first canonical question, hiding the second valid match. Expected both results.

Repository candidate statement joins all eligible answers, orders scores, then applies limit * 10. The first question's 60 answer rows exhaust 50 candidate rows before the service collapses canonical IDs. A larger fixed multiplier is not a robust correction. Select a representative governed answer without multiplying candidate rows; apply the candidate budget to distinct permitted questions/canonical groups. Review both lexical and semantic branches, and alias fanout. Preserve visibility filtering for both alias and canonical question before budgets, and verified/accepted answer precedence.

Reproduction: copy regressions/test_search_answer_fanout.py into backend/tests/test_independent_search_review.py in the reviewed worktree and run pytest for that file with APP_ENV=development and EMBEDDING_PROVIDER=fake. It uses existing app_client fixture and disposable SQLite data; no hosted data or credentials.

The independent failure is separate from the 59 passing existing tests. Search approval is blocked until corrected and independently rerun. Ownership gates, session reload, deep follow-up layout, PDF investigation and final evaluation are separate Copilot scopes. No migration, provider activation, merge, or deployment occurred during this review.
