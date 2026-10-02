# IntQAFlow Flutter App

The employee-facing Flutter web shell for IntQAFlow.

## Run locally

Start the API first, then run:

```sh
flutter pub get
flutter run -d chrome \
	--dart-define=API_BASE_URL=http://localhost:8000 \
	--dart-define=FIREBASE_API_KEY=<dev-web-api-key> \
	--dart-define=FIREBASE_AUTH_DOMAIN=intqaflow-dev.firebaseapp.com \
	--dart-define=FIREBASE_PROJECT_ID=intqaflow-dev \
	--dart-define=FIREBASE_APP_ID=1:398672910103:web:e968506023d8eab9290952 \
	--dart-define=FIREBASE_MESSAGING_SENDER_ID=398672910103 \
	--dart-define=RECAPTCHA_ENTERPRISE_SITE_KEY=<registered-app-check-site-key>
```

The Firebase web API key and reCAPTCHA site key are public web configuration,
not service credentials. Obtain the development web API key and the approved
App Check site key from the private Codex handoff; do not add them to source
control. The defaults are limited to the registered `intqaflow-dev` web app.
The app requires these two values at startup and uses Firebase email/password
sign-in. Firebase ID and App Check tokens are attached to API requests by the
shared Dio client. User, organisation, and role are obtained from `/api/v1/auth/me`;
the caller cannot choose them.

To build the hosted web client, pass the same non-secret Firebase defines and
the hosted API URL:

```sh
flutter build web --release \
	--dart-define=API_BASE_URL=<hosted-development-api-url> \
	--dart-define=FIREBASE_API_KEY=<dev-web-api-key> \
	--dart-define=FIREBASE_AUTH_DOMAIN=intqaflow-dev.firebaseapp.com \
	--dart-define=FIREBASE_PROJECT_ID=intqaflow-dev \
	--dart-define=FIREBASE_APP_ID=1:398672910103:web:e968506023d8eab9290952 \
	--dart-define=FIREBASE_MESSAGING_SENDER_ID=398672910103 \
	--dart-define=RECAPTCHA_ENTERPRISE_SITE_KEY=<registered-app-check-site-key>
```

Use the same defines for the `flutter test` and `flutter analyze` CI/build
environment as needed. Never use local development values to authorize a
hosted service.

Employees can see answer provenance and freshness, inspect version history, and
submit update challenges. Department answer owners and admins additionally see
the review queue and controls to verify/review answers and decide challenges.
Admins can assign department owners. Presentation uses the server-resolved
membership role; the API validates role and department assignment for every
action.

Linked historical questions remain directly accessible and explain where the
current canonical answer lives. Canonical pages show up to three alternate
phrasings. Owners and admins can compare strong semantic candidates, keep them
separate, merge into the existing canonical question, make the current question
canonical, or unmerge a mistaken link. Employees can submit a secondary
duplicate report, which enters the existing review queue.

The Ask form supports optional department and team metadata. Selecting a team
with a parent department suggests that department without making either field
mandatory. Ask suggestions include related open questions as well as reusable
answers. Question authors and admins can edit submitted question text and scope,
or archive a mistaken question without deleting its history. Question lists can
be filtered by department and team. Admins can
create departmental or cross-functional teams and manage membership from the
existing Admin view.

See the repository root README for complete database and backend setup.
