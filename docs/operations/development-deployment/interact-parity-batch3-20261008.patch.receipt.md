# Receipt: interact-parity-batch3-20261008.patch

- Base (complete): `80f421d1c0ecc907d0d88a8147ccb1f2138fe377`. Repository tree: `911bda4e2349f16fd949225c6bf90a5f5973e181`; app subtree `apps/flutter_app` = `fd44cfb309d64bac30b8f4da5ae1caa6b35c9938`.
- Final source commit: `04f8adabbb1be25877a640b2f9e420599c9d1560`
  - Repository tree: `245a6206bf141f20abf62f209a0d0ba33edff34a`
  - App subtree `apps/flutter_app`: `320f74e08d8dd2f974aacbe31fe2ca5853feb909`
- Mailbox: `git format-patch --stdout 80f421d1c0ecc907d0d88a8147ccb1f2138fe377..04f8adabbb1be25877a640b2f9e420599c9d1560`. It contains 5 original commits:
  1. `943b2d0`: WIP checkpoint
  2. `9456e84`: partial
  3. `ea530df`: organisation operations
  4. `168a56e`: tests and fixes
  5. `04f8ada`: docs and receipts
- Mailbox size: 226378 bytes (valid UTF-8). SHA256: `28799e6f7f09ab95ff6d9550ffd7bae607d319a18a98dddc03cc9dba27e22cdc`.
- The artifact commit adds only this receipt and the mailbox. Both are excluded from the patch.
- `git am` proof:
  - Steps: clean detached worktree at the base, then `git -c user.name=proof -c user.email=proof@example.invalid am interact-parity-batch3-20261008.patch`.
  - Result: exit 0; 5 patches applied.
  - Resulting repository tree `245a6206bf141f20abf62f209a0d0ba33edff34a` matches the source tree.
  - Resulting app subtree `320f74e08d8dd2f974aacbe31fe2ca5853feb909` matches the source app subtree.
- Changed files (15):
  - `apps/flutter_app/lib/core/routing/app_router.dart`
  - `apps/flutter_app/lib/core/routing/session_deep_link.dart`
  - `apps/flutter_app/lib/features/guest/domain/guest_interact_helpers.dart`
  - `apps/flutter_app/lib/features/guest/presentation/guest_workspace_page.dart`
  - `apps/flutter_app/lib/features/guided/application/guided_providers.dart`
  - `apps/flutter_app/lib/features/guided/data/guided_repository.dart`
  - `apps/flutter_app/lib/features/guided/domain/guided_models.dart`
  - `apps/flutter_app/lib/features/guided/presentation/guided_page.dart`
  - `apps/flutter_app/lib/features/guided/presentation/guided_report_document.dart`
  - `apps/flutter_app/lib/features/guided/presentation/guided_session_page.dart`
  - `apps/flutter_app/test/account_state_widget_test.dart`
  - `apps/flutter_app/test/guest_interact_widget_test.dart`
  - `apps/flutter_app/test/guided_batch3_test.dart`
  - `apps/flutter_app/test/session_deep_link_test.dart`
  - `docs/operations/development-deployment/interact-parity-batch3-2026-10-08.md`
- Validation receipts, scope coverage and open decisions: `interact-parity-batch3-2026-10-08.md`.
- Automated code review was unavailable in this session because of a tool model-registry error. CodeQL found no analysable languages (Dart).
