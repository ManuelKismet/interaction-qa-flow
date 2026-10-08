# Synthetic acceptance fixtures

phase6-legacy-session.json is adapted from the existing legacy-import regression on commit 2962b2c. It contains Alice and Bob as synthetic participants, a shared root question with independent Email/Phone answers, and two levels of answer-owned follow-ups for Alice. All content is synthetic. Paste the JSON object into the existing legacy import dialog; do not wrap it in a payload object in the UI. API calls wrap it as {payload: fixture}.

Backend validation: phase6_fixture_validation.py passed on 2962b2c with in-memory SQLite, real UID mapping and mocked Firebase verification. Independent participant answers, both nested follow-up levels and successful JSON/CSV exports were verified. This is not manual browser acceptance, template-version validation or CSV formula-safety sign-off.

Manual next steps: switch Alice/Bob; confirm Bob does not inherit Alice's branches; expand/collapse nested follow-ups; edit answers and reload; inspect active-participant and all-participant reports; export and compare ownership/answers. Run template-version isolation separately from test_guided.py's existing scenario.

identity-manifest.json is a role inventory, not provisioned accounts. Firebase UID fields remain null until real synthetic development users exist; participants are session participants, not Firebase identities. Hosted seeding is not executed and migration 0008 remains pending reviewed acceptance.
