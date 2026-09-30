# IntQAFlow Flutter App

The employee-facing Flutter web shell for IntQAFlow.

## Run locally

Start the API first, then run:

```sh
flutter pub get
flutter run -d chrome \
	--dart-define=API_BASE_URL=http://localhost:8000 \
	--dart-define=DEV_ORGANISATION_ID=<organisation-uuid> \
	--dart-define=DEV_USER_ID=<user-uuid> \
	--dart-define=DEV_USER_ROLE=<employee-answer_owner-or-admin>
```

The development identity values are temporary and will be replaced by
authentication token claims. The Ask page uses them as temporary request headers
for debounced semantic duplicate detection and never receives embedding vectors
or provider credentials.

Employees can see answer provenance and freshness, inspect version history, and
submit update challenges. Department answer owners and admins additionally see
the review queue and controls to verify/review answers and decide challenges.
Admins can assign department owners. `DEV_USER_ROLE` controls presentation only;
the API validates the stored role and department assignment for every action.

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
