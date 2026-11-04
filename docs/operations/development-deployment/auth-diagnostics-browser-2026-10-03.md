# Development Firebase sign-in diagnostic — 3 October 2026

User authorized direct verification of saved synthetic admin credentials, a secure browser retry, and enabling development-only sanitized authentication logs. Existing role split retained: configuration and independent verification by Codex; application changes by Copilot. Hosted development only.

## Verified results

- A Codespace Python HTTPS probe loaded the saved synthetic admin credentials privately and called Firebase signInWithPassword using the existing development web configuration. HTTP 200, ID token returned, expected UID matched. Only result booleans/status were printed; credential/token values were not displayed.
- Secure browser sign-in retries returned the generic credential error after the guest identity switch confirmation. Backend membership success was not observed.
- Read deployed source df6bcd3026295e9f492d140282376c927bb66844: SignInPage passes trimmed email controller text and unchanged password controller text to Firebase Auth. The API client attaches Firebase ID and App Check tokens; it does not send the password to the application backend.
- Built the independently reviewed combined source c28d694 with existing AUTH_DIAGNOSTICS=true and the same approved development Firebase/App Check/API configuration. Release web build passed in 45.6 seconds. No application source changes.
- Published diagnostic Hosting release sites/intqaflow-dev/releases/1791033587516000, version sites/intqaflow-dev/versions/f6c665645d532b26, 35 files. Hosted main.dart.js returned HTTP 200 and SHA256-matched the diagnostic artifact. Sanitized authentication log marker present.
- Reloaded development app and performed one secure sign-in attempt with the diagnostic build. After the guest switch confirmation, the page displayed [auth/invalid-email]; console extraction independently returned auth/invalid-email. No credential field values were inspected.

## Interpretation and limits

The saved credentials are valid. The browser attempt rejects the email as invalid at the Firebase authentication layer. This does not prove that the secure form supplied the same email as the saved credential file, that Flutter retained it, or that a Firebase network request was issued. Request payloads and credential values were not inspected. The exact input/secure-fill/Flutter boundary remains unresolved; backend membership loading is not the demonstrated failure.

Next useful step is direct manual browser entry of the known synthetic admin identity to distinguish secure filling from application handling, then independent registered account-transition/cache/PDF acceptance. No password reset, IAM/security changes, backend deployment, migration, cleanup apply, schedule, merge, or production change. Development diagnostic logging remains enabled and emits sanitized error codes only.

Logs in private Codespace: auth-diagnostics-20261003-build.log and auth-diagnostics-20261003-hosting.log. Prior API/Flutter/full backend validation remains separately attributed; no new full test-suite run was claimed for the compile-time diagnostics flag.
