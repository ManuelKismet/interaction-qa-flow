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


## Independent rerun on corrected PR commit 936e801

Codespace validation on 2026-10-02 used a detached worktree at 936e801848c20ac3b453212add47dc7c895fde44, Flutter 3.41.4 and Dart 3.11.1. Dependency resolution, analysis and the Flutter tests all exited successfully. The initial release web build ended with the compiler terminated (exit -15) and an unsuccessful optional Wasm dry run; it did not report the previous source errors. A release retry with `--no-wasm-dry-run` succeeded and produced `build/web` in 42.3 seconds. This validates the JavaScript release build, not a Wasm build.

The build used a private development defines file with the Enterprise site-key setting and a loopback API URL. No live Firebase sign-in, App Check token exchange, hosted backend end-to-end flow, merge or deployment was performed.

Backend IQ-03 and IQ-04 corrections were handed to Copilot on PR 4 in comment 5960196899, with the independent review and synthetic reproduction cases. Copilot acknowledged the request with an eyes reaction. IQ-05 remains a separate privacy policy decision; the existing IQ-07 failure remains outstanding.
