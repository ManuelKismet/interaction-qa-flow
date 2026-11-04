# IntQAFlow pending PR consolidation — 4 November 2026

Current validated feature behavior wins conflicting older implementations. Original PR histories are retained. Unique additions are reviewed and the combined result is tested before main/deployment.

## PR #20 — [WIP] Unify Ask search across knowledge sources

Original head: 6843474ab45ae164dd144731c2612a365fd264ff. Original commits are retained in merge history.

Retained non-conflicting file changes: apps/flutter_app/test/ask_suggestions_controller_test.dart, docs/operations/development-deployment/unified-knowledge-ask-parity-correction-20261007.patch, docs/operations/development-deployment/unified-knowledge-ask-parity-navigation-20261007.patch, docs/operations/development-deployment/unified-knowledge-ask-parity-replacement-20261007.patch.

## PR #18 — Improve short-query search, protect approved knowledge, preserve session links, and enhance Interact reports and guest recovery

Original head 3b0b4ecfb30a98d7fd471ab3bb4249c1f6cbf668 retained in merge history. Current validated fixes win conflicting older implementations. Unique retained paths: apps/flutter_app/lib/core/auth/auth_diagnostics.dart, apps/flutter_app/lib/core/auth/auth_providers.dart, apps/flutter_app/lib/core/auth/sign_in_page.dart, apps/flutter_app/lib/core/config/app_config.dart, apps/flutter_app/test/account_state_widget_test.dart, apps/flutter_app/test/auth_diagnostics_test.dart, apps/flutter_app/test/guest_workspace_store_test.dart, docs/operations/development-deployment/pr13-follow-up-checkpoint-2026-10-04.md.
