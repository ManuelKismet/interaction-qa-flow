# Firebase Flutter validation — 2026-10-02

Reviewed PR #4 at 862ecef2c9716510cec5f1e68d61ffb0b9f60838 in
an isolated detached Codespace worktree. No application changes, merge,
cloud migration or deployment performed.

Runtime: Flutter 3.41.4, Dart 3.11.1; resolved Riverpod 3.3.2.
`flutter pub get` succeeded and generated Firebase entries missing from
the PR's committed pubspec.lock. The updated lock remains in the review
worktree; it has not been pushed into Copilot's branch.

## Results

- Analysis failed: five undefined valueOrNull getters, one unused-import
  warning, and five information-level diagnostics (11 total).
- Tests failed: 15 passed, 3 test-file loading failures due to compilation.
- Release web build failed with the undefined valueOrNull compilation errors.

## Required application corrections

1. Use the supported Riverpod 3 AsyncValue API in auth_providers.dart,
   admin_page.dart, review_queue_page.dart, question_detail_page.dart,
   and app_shell.dart. Retain safe loading/error handling.
2. Align main.dart with the registered reCAPTCHA Enterprise provider;
   the current ReCaptchaV3Provider and RECAPTCHA_V3_SITE_KEY documentation
   do not match the verified cloud registration. Use the supported
   providerWeb parameter and update the build define/runbooks consistently.
3. Commit a resolved Firebase dependency lock and clear analyzer diagnostics.
4. Repeat analysis, all Flutter tests and release build after corrections.

Compilation checks do not establish live Firebase token exchange, membership,
App Check enforcement, tenant/privacy acceptance or hosted browser behavior.
The known backend guided-proposal failure remains a separate issue.
