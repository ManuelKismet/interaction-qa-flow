# IntQAFlow operating audit — 30 September 2026

## Scope and decision

This is a source and local-test audit of **IntQAFlow**, repository `ManuelKismet/interaction-qa-flow`, at commit `0ff4ab941264604aedda368909961bdee602cb67`. It covers Knowledge, Interact, the Flutter workspace, FastAPI backend, PostgreSQL/pgvector migrations, and legacy local Interact compatibility. It is a documentation-only audit; it implements no fixes.

**Release assessment:** the platform is not ready for remotely accessible customer use on the evidence available. The unmodified backend fails to import in the audit environment. Authentication is explicitly deferred, and additional visibility defects remain beyond that planned deferral. The legacy static application and the server-backed platform must have separate release assessments.

Happnn and TempConnect are separate applications. Their infrastructure, Apple accounts, findings, fixes, and release approvals are not evidence for IntQAFlow. A shared company or founder does not establish a shared data boundary.

## Product and ownership register

| Item | IntQAFlow boundary |
| --- | --- |
| Accountable operator | Solo founder; confirm the intended contracting company before customer launch |
| Knowledge | Tenant Q&A, canonical questions, verified answers, department ownership and review |
| Interact | Operational sessions, participants, independent answer branches, templates, reports, proposals to Knowledge |
| Local compatibility | Root index.html, local browser storage and portable exports |
| Platform stack | Flutter web; FastAPI; asynchronous SQLAlchemy; PostgreSQL 16 and pgvector |
| Governance | Departments grant answer governance; teams provide operational grouping/visibility and do not independently grant governance |
| Identity | Development identifiers supplied by callers; no verified authentication yet |
| External processing | Configurable OpenAI-compatible embeddings; deterministic fake provider for tests |
| Deployment | GitHub Pages build observed; no server-backed production environment or runtime account has been verified |
| Separate app resources | Repository, credentials, databases, tenant namespaces, monitoring, backup policy and release evidence must be identified for IntQAFlow itself |

## Validation and limits

- Inspected the complete repository tree and text sources at the pinned commit. No repository AGENTS.md or committed .github test workflows were present.
- Python 3.12.14. Dependencies installed from backend/requirements.txt into an isolated environment. Selected resolved versions: FastAPI 0.142.2, SQLAlchemy 2.1.1, Pydantic 2.13.5, pytest 8.4.2, pytest-asyncio 1.4.0, asyncpg 0.31.0, aiosqlite 0.22.1, pgvector 0.5.0, httpx 0.28.1.
- **Unmodified baseline:** pytest cannot load conftest because TeamService class construction raises TypeError. No clean-source passing test result is claimed.
- **Diagnostic run only:** prepend `from __future__ import annotations` to the isolated local copy of backend/app/services/team.py. With `EMBEDDING_PROVIDER=fake python -m pytest -q`, the existing suite returns **38 passed**.
- With the same import workaround and the default embedding provider, no API key configured: **37 passed, 1 failed**. The failed test is `test_knowledge_proposal_rejects_or_creates_primary_knowledge_with_source`. It also fails when run alone; MissingGreenlet occurs following the embedding-error rollback.
- Three additional synthetic probes pass assertions describing the observed defects: private Knowledge direct reads/listing; null-department Interact access plus private-session administrator access; raw CSV formula prefix plus department-owner review denial. These are observation probes, not successful security regression tests.
- No actual customer data, paid embedding call, database setting, deployed application, or repository protection was modified.
- Flutter and Docker are not installed in the audit environment. Flutter tests, browser behavior, PostgreSQL migrations/composite foreign keys, actual pgvector execution, backup restore and production settings remain unverified. The SQLite fixture uses metadata.create_all and is not migration evidence.

## Findings register

P1 means resolve before remote customer use or a release claim; P2 means a policy, reliability or operational gap to schedule explicitly. Findings describe inspected source and local behavior, not an assertion that a deployed service is exposed.

| ID | Priority | Finding | Evidence and acceptance target |
| --- | --- | --- | --- |
| IQ-01 | P1 | Backend startup fails on class annotation | [TeamService](https://github.com/ManuelKismet/interaction-qa-flow/blob/0ff4ab941264604aedda368909961bdee602cb67/backend/app/services/team.py) defines list(), then annotates a later return as list[TeamMembershipResponse]. Python resolves the class-local method rather than the builtin; TypeError: function object is not subscriptable. A clean supported-Python import and unmodified test suite must pass. |
| IQ-02 | P1, known deferral | Development identity has no remote-release guard | [Dependencies](https://github.com/ManuelKismet/interaction-qa-flow/blob/0ff4ab941264604aedda368909961bdee602cb67/backend/app/api/dependencies.py), [settings](https://github.com/ManuelKismet/interaction-qa-flow/blob/0ff4ab941264604aedda368909961bdee602cb67/backend/app/core/config.py), [main](https://github.com/ManuelKismet/interaction-qa-flow/blob/0ff4ab941264604aedda368909961bdee602cb67/backend/app/main.py). Caller-supplied organisation/user IDs are trusted as identity; roles are loaded from the database, not verified identity claims. APP_ENV=production changes CORS behavior but does not replace identity or fail closed. Authentication is deliberately deferred in the product docs. Keep this a development-only boundary until verified identity and a production startup guard exist. CORS is not authentication. |
| IQ-03 | P1, reproduced | Knowledge direct read/list ignores private and department visibility | [Question routes](https://github.com/ManuelKismet/interaction-qa-flow/blob/0ff4ab941264604aedda368909961bdee602cb67/backend/app/api/v1/routes/questions.py), [service](https://github.com/ManuelKismet/interaction-qa-flow/blob/0ff4ab941264604aedda368909961bdee602cb67/backend/app/services/question.py), [repository](https://github.com/ManuelKismet/interaction-qa-flow/blob/0ff4ab941264604aedda368909961bdee602cb67/backend/app/repositories/question.py). GET detail and list use organisation_id without an actor visibility policy. Synthetic private question created by employee is returned to people_owner through both endpoints. Tenant scoping exists, but tenant membership is not sufficient for private access. Apply the same actor visibility policy to direct reads, answers/comments and related endpoints; test private, department, organisation and canonical alias paths. |
| IQ-04 | P1, reproduced | Missing department creates an unintended visibility group | [Guided schema](https://github.com/ManuelKismet/interaction-qa-flow/blob/0ff4ab941264604aedda368909961bdee602cb67/backend/app/schemas/guided.py) allows department visibility with null department_id. [GuidedService._require_view](https://github.com/ManuelKismet/interaction-qa-flow/blob/0ff4ab941264604aedda368909961bdee602cb67/backend/app/services/guided.py) compares actor.department_id == session.department_id, so null equals null. Synthetic departmentless non-owner gets HTTP 200. Require a valid scoped department when selecting department visibility and reject null equality as authorization. Verify listing and exports too. |
| IQ-05 | P2, policy discrepancy reproduced | Private Interact sessions are accessible to tenant administrators | [Architecture](https://github.com/ManuelKismet/interaction-qa-flow/blob/0ff4ab941264604aedda368909961bdee602cb67/docs/architecture.md) says private sessions are owner-only. [GuidedService](https://github.com/ManuelKismet/interaction-qa-flow/blob/0ff4ab941264604aedda368909961bdee602cb67/backend/app/services/guided.py) permits admins to view and change them; synthetic private-session admin read is HTTP 200. Decide whether private means owner-only or owner-plus-admin, then align disclosure, reads, mutations, reports and exports. This is a contract discrepancy, not proof that administrator access is inherently unintended. |
| IQ-06 | P2, governance discrepancy | Interact proposal review excludes department answer owners | [README](https://github.com/ManuelKismet/interaction-qa-flow/blob/0ff4ab941264604aedda368909961bdee602cb67/README.md) promises admins or the appropriate department answer owner can review. [GuidedKnowledgeService](https://github.com/ManuelKismet/interaction-qa-flow/blob/0ff4ab941264604aedda368909961bdee602cb67/backend/app/services/guided_knowledge.py) restricts list_proposals to ADMIN and decide() uses require_admin. A mapped Finance owner gets HTTP 403 from the queue. Reuse explicit department-owner governance with tenant/department checks, or narrow the documented contract. Team membership must not grant this authority. |
| IQ-07 | P1, reproduced conditionally | Proposal acceptance is fragile when embedding generation fails | Existing [guided acceptance test](https://github.com/ManuelKismet/interaction-qa-flow/blob/0ff4ab941264604aedda368909961bdee602cb67/backend/tests/test_guided.py) fails in the resolved audit environment when the default provider has no key; fake provider passes. [QuestionService._sync_embedding_safely](https://github.com/ManuelKismet/interaction-qa-flow/blob/0ff4ab941264604aedda368909961bdee602cb67/backend/app/services/question.py) rolls back the shared session and refreshes only the question; the proposal path then encounters expired-state async IO (MissingGreenlet). Isolate embedding failure from the proposal transaction; verify no partially accepted or duplicate knowledge remains after failure/retry. Test missing key and a controlled provider exception on supported database/dependency versions. |
| IQ-08 | P2, reproduced | CSV export preserves spreadsheet formula prefixes | [GuidedService.export_csv](https://github.com/ManuelKismet/interaction-qa-flow/blob/0ff4ab941264604aedda368909961bdee602cb67/backend/app/services/guided.py) writes user-controlled title, names, questions and answers directly via csv.writer. A synthetic title =SUM(1,1) survives parsing unchanged. CSV quoting alone does not define spreadsheet-safe text. Define a safe spreadsheet export policy and verify all user-controlled columns; keep JSON faithful to original text. No spreadsheet formula was executed during the audit. |
| IQ-09 | P2, release policy gap | Embedding disclosure and provider boundary need explicit operating policy | [EmbeddingService](https://github.com/ManuelKismet/interaction-qa-flow/blob/0ff4ab941264604aedda368909961bdee602cb67/backend/app/ai/embedding_service.py) sends Knowledge title/body to the configured provider, including non-public visibility content; default [provider settings](https://github.com/ManuelKismet/interaction-qa-flow/blob/0ff4ab941264604aedda368909961bdee602cb67/backend/app/core/config.py) point to an external OpenAI-compatible endpoint. Interact sessions are excluded from automatic Knowledge indexing; deliberate reverse lookup still sends selected question text. Document payloads, endpoint, tenancy, secrets, allowed content and deletion/rebuild policy before use with customer content. The local-only promise must remain scoped to index.html. No provider account/retention setting was verified. |
| IQ-10 | P2, recovery contract discrepancy | Interact revision entries are change labels rather than restorable snapshots | [GuidedService._save_revision](https://github.com/ManuelKismet/interaction-qa-flow/blob/0ff4ab941264604aedda368909961bdee602cb67/backend/app/services/guided.py) stores summary={change: ...} and a revision number. [Architecture](https://github.com/ManuelKismet/interaction-qa-flow/blob/0ff4ab941264604aedda368909961bdee602cb67/docs/architecture.md) calls these snapshots. Template versions are separate immutable inputs; session revision labels do not reconstruct earlier session state. Clarify history versus restore, or add recoverable snapshots with a tested restore policy. |
| IQ-11 | P1, release-control gap | Pages success does not validate the platform | No committed test workflows. GitHub main metadata reports protected=false; repository rulesets returned an empty list. Latest observed run is the successful dynamic Pages build for the audited commit. Add clean backend imports/tests, Flutter analyze/tests and PostgreSQL migration checks as release evidence; propose required checks and protection in a separate authorized settings change. Do not treat static deployment success as server readiness. |
| IQ-12 | P2, availability gap | Health endpoint cannot establish database readiness | [main.py](https://github.com/ManuelKismet/interaction-qa-flow/blob/0ff4ab941264604aedda368909961bdee602cb67/backend/app/main.py) returns status=ok and environment without a database or migration check. Keep liveness separate and provide readiness for database/schema requirements. Verify failure behavior and alerting in the identified environment. |
| IQ-13 | P2, reproducibility gap | Backend dependency resolution is not frozen | [requirements](https://github.com/ManuelKismet/interaction-qa-flow/blob/0ff4ab941264604aedda368909961bdee602cb67/backend/requirements.txt) uses version ranges, including SQLAlchemy <3; no backend lock is committed. A Flutter lock does exist. Record supported versions and use a repeatable backend resolution; reproduce IQ-07 under that supported set before attributing it across versions. |
| IQ-14 | P2, audit incomplete | Runtime inventory, retention and recovery have not been established | The repository documents local setup and a named database volume, but provides no verified production service/account inventory or completed database restore drill. Session JSON/CSV exports do not cover the whole tenant, governance, audit history and vector rebuild state. Record actual endpoints, resource owner, environments, backups, restore objectives and retention responsibilities, then perform a synthetic restore drill. Absence of audit evidence is not proof that external controls do not exist. |

## Reproduction notes

All probes use the existing SQLite app_client fixture and seed_governance synthetic tenant. They run only after the diagnostic import workaround.

1. **IQ-03:** POST /api/v1/questions with the seeded employee author, visibility=private and title='Synthetic private marker'. GET the returned ID and GET /api/v1/questions using organisation_id and people_owner headers. Both return the private record; these routes do not consume the actor headers.
2. **IQ-04:** Seed a regular user with department_id unset. As employee, POST /api/v1/guided/sessions with visibility=department and no department_id. Creation returns 201. The other departmentless user GETs the session and receives 200.
3. **IQ-05:** Create the existing test helper's private session as employee; admin GETs it successfully.
4. **IQ-06:** The seeded department-mapped finance_owner GETs /api/v1/guided/knowledge-proposals and receives 403. Source inspection separately confirms decide() also requires admin.
5. **IQ-08:** Create a session titled '=SUM(1,1)' with one question. Call export_csv as its owner, parse with csv.reader, and inspect first data row/first column: '=SUM(1,1)' unchanged.
6. **IQ-07:** With no EMBEDDING_API_KEY and the default provider, run python -m pytest tests/test_guided.py::test_knowledge_proposal_rejects_or_creates_primary_knowledge_with_source -q --tb=short. Repeat with EMBEDDING_PROVIDER=fake: the latter passes in this environment.

## What is working in the inspected design

The source has explicit tenant-scoped repositories and governance checks, independent answer-triggered participant branches, immutable template inputs, canonical-question governance, semantic candidate visibility filtering, and an explicit separation between Interact operational data and Knowledge indexing. The diagnostic fake-provider suite exercises these contracts. This does not validate every route's privacy policy or PostgreSQL enforcement; IQ-03 and IQ-04 identify concrete exceptions.

## Proposed remediation sequence

1. Restore clean startup, repeat the baseline suite and define a supported dependency resolution (IQ-01, IQ-13).
2. Keep development identity confined to development; implement verified identity and uniform visibility checks before remote access (IQ-02, IQ-03, IQ-04).
3. Make proposal acceptance resilient to provider failure, then verify retry/atomicity (IQ-07).
4. Resolve private-admin and department-review contracts; add spreadsheet export protection and precise external-processing disclosure (IQ-05, IQ-06, IQ-08, IQ-09).
5. Establish platform CI, PostgreSQL migration evidence, readiness, recovery and the session-history contract (IQ-10 through IQ-14).
6. Conduct a separate runtime audit after identifying the IntQAFlow environments. Do not reuse other applications' credentials or release conclusions.

## Solo-founder operating checklist

These are proposed release deliverables, not completed controls:

- Maintain one company-level owner/contact and shared incident process, with **separate app-level** resource registers, secrets, data responsibilities, finding IDs and release decisions.
- For IntQAFlow, identify local legacy versus server-backed users and avoid applying a local-only privacy statement to hosted Knowledge/Interact.
- Require evidence for tenant isolation, actor visibility, verified identity, provider outage behavior, backup restoration, retention and a rollback path.
- Store deployment and incident evidence under this application's operating record. Keep development/demo content separate from customer tenants.
- Record the founder's accept/reject decision for each policy discrepancy and retest the resulting behavior. This PR itself is not release approval.

## Audit status

Initial source audit complete; runtime/deployment, browser and PostgreSQL verification outstanding. All findings remain open. No implementation, merge, deployment, credential, infrastructure or settings changes are included.
