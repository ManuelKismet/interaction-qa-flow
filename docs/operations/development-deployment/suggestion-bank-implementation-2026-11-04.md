# Suggestion Bank implementation — 4 November 2026

Source: feat/suggestion-bank-20261104, based on 381096526773944744258e56cdeb3b19c40d6427 (the latest development feature stack). NOPAK working principles applied. Original isolation workspace HEAD 59351f1297647707ef0a73487b4a8aa6f4523104 and its four uncommitted documentation changes are preserved.

Implemented: organisation/department/team and independent Group banks; suggestions, proposals, feedback and etiquette; reviewer assignment and due dates; official responses and tracked statuses; support/comments and in-app following/updates; duplicate linking with retained input; explicit previewed escalation; lasting and revisable practices; deliberate same-audience Interact handoffs and verified organisational Knowledge links. NIA helpers use permission-filtered keyword/typo matching and review prompts. Group-only accounts enter through Groups > Group options > Suggestions & practices. See docs/suggestion-bank.md for policy and recovery details.

## Verified

- Backend: 199 passed, 32 environment-gated checks skipped, using a clean dedicated PostgreSQL test database. Includes 13 new bank tests, real concurrent retry/CAS checks, tenant foreign-key rejection and Group rate-budget-before-root-lock ordering.
- Flutter: all 439 tests passed, including eight new tests for permission controls, draft recovery/idempotency, Group-only navigation, account changes, standing practices and deep links. Responsive organisation navigation now includes Suggestions.
- Analysis: no errors or warnings; 11 informational style hints. No diagnostics in new bank source or tests.
- Web release compilation passed with existing guarded intqaflow-dev defines. No dependency or backend configuration changes.
- PostgreSQL migration 0016 -> 0017 -> 0016 -> 0017 passed in a separate disposable local database, preserving the original organisation fixture throughout.
- git diff --check passed. Original uncommitted workspace changes remain unchanged.

A first broad PostgreSQL run reused the migration database, causing old integration fixtures to reuse public tables. Verification was corrected to use a separate clean test database with only the required extensions; the final complete run passed. No production data or existing DEV backend was changed.

## Delivery status

Source implementation and automated validation are complete. Migration 0017 is included. No merge, Cloud Run deployment, Firebase Hosting publication, production promotion or live user/device acceptance is claimed. The existing development release remains in place. The new local test PostgreSQL instance may be stopped after validation; existing services, databases and active worktrees must be preserved.
