# IntQAFlow private development isolation

> Historical local/container preparation record. The founder subsequently
> selected a hosted development backend. See [cloud-development.md](cloud-development.md)
> for current cloud resources, budget, application gates and acceptance state.

Updated 2026-10-02. Repository: ManuelKismet/interaction-qa-flow.
Baseline: 0ff4ab941264604aedda368909961bdee602cb67.

## Status and scope

Configuration prepared; runtime isolation is **not yet verified**. No Codespace,
cloud deployment, database container, tenant or application server was created
by this change. Docker and Flutter are unavailable in the preparation runtime.
YAML/JSON parsing, configuration consistency and bootstrap shell syntax passed.
A fresh Python 3.12 virtual environment installed backend dependencies with
pip check passing. Clean app import and pytest collection both fail at the
existing TeamService annotation blocker (IQ-01); no tests passed in this run.
Docker Compose execution, PostgreSQL migrations and Flutter/browser acceptance
remain pending.

Knowledge and Interact stay in one platform. This runbook's previous development
identity commands are superseded by Firebase Auth and App Check. Use
[cloud-development.md](cloud-development.md) for current non-secret web
configuration and fresh-account acceptance steps. Do not use a synthetic
membership seed or publish the server-backed platform without private review.
The existing root index.html compatibility app is a separate static experience;
its hosting success does not verify the platform.

The existing audit draft PR #1 records IQ-01: clean backend startup/test
collection is blocked by TeamService class annotations. This environment change
does not fix or close that finding. Do not apply an undocumented import
workaround and report the result as clean-source acceptance.

## Resource boundary

| Resource | Isolated development |
| --- | --- |
| Compose project | intqaflow-isolated-dev |
| Database | intqaflow_dev, isolated disposable development data only |
| Database binding | 127.0.0.1:55432 |
| Persistent volume | Project-scoped isolated_postgres; separate from default smart_qa volume |
| API binding | 127.0.0.1:8000 |
| Flutter binding | 127.0.0.1:8080 |
| Embeddings | Deterministic fake provider; no provider key |
| Access | Local loopback; any workspace forwarding must be private and separately verified |
| Credentials | Public disposable local values; no founder cloud login or other app credentials |

A local shared machine or container host can access loopback/containers: this
setup is for a trusted development machine, not protection from other users
with host access. CORS and development identity IDs are not authentication.
No Happnn or TempConnect resources are used. No main-branch, Pages, repository
settings or production changes are included.

## Prepare a clean development checkout

Use the isolation branch in a separate checkout without production credentials
or customer exports. Install Docker Compose, Python 3.12 and the repository's
compatible Flutter SDK. Do not reuse an existing backend .env or development
database. The commands below use explicit exported development settings, which
override pydantic's .env values.

From the repository root:

```sh
docker compose -f compose.isolated-dev.yaml config
docker compose -f compose.isolated-dev.yaml up -d --wait postgres
cd backend
python3 -m venv .venv
. .venv/bin/activate
pip install -r requirements.lock
set -a
. ./.env.isolated-dev.example
set +a
python -c 'from app.main import app; print("Clean backend import passed")'
```

**Stop if clean import fails.** Record the failure against IQ-01 and send a
scoped application-fix handoff to Copilot under founder + Codex review.
Dependencies currently use version ranges, so record resolved versions;
this PR does not claim a frozen dependency environment.

Only after the clean import passes, in that same shell:

```sh
alembic upgrade head
python -m pytest -q
uvicorn app.main:app --host 127.0.0.1 --port 8000
```

Do not substitute the original compose.yaml: it uses the default smart_qa
database and an unrestricted host port binding. Always use this standalone
file with -f, without combining the two Compose files.

## Flutter and account acceptance

The previous caller-selected development identity flow is disabled. For live
manual acceptance, create and verify a fresh account through the app, sign out,
and sign in normally. Account creation alone gives no organisation access.
Follow `cloud-development.md` for authorized membership provisioning. Unit and
widget tests use isolated fakes; they are not evidence of live authentication.

In a separate shell, from apps/flutter_app:

```sh
flutter pub get
flutter analyze
flutter test
```

Follow the Firebase build defines in `apps/flutter_app/README.md` to launch the
web client. App Check requires the registered web provider/site key.

Replace angle-bracket placeholders before execution. For a local browser use
localhost:8080. If a future Codespace is used, both web and API ports must remain
private; localhost in a remote browser does not refer to the Codespace. Verify
a supported private tunnel/origin arrangement before claiming browser access.
Codespace provisioning and forwarding verification are outstanding.

## Acceptance evidence required

- Validate the standalone Compose model with Docker Compose, inspect the actual
  loopback port binding and verify its project-scoped volume.
- Confirm an isolated database and the exact environment settings, without
  printing unrelated credentials. Verify migrations on PostgreSQL/pgvector.
- Run clean backend import/tests with fake embeddings. Preserve failures as
  failures; audit issues remain separate.
- Run Flutter analyze/tests and exercise Knowledge, Interact, Review and legacy
  migration using a freshly registered account with explicitly provisioned
  membership. The full manual parity matrix remains pending.
- Confirm no external embedding requests, other-application credentials or
  production database connections are used during the exercised paths.
- Test access from outside the private development boundary; require rejection.
  A loopback configuration file alone is not this runtime evidence.
- Record resolved dependencies, commit, resource names, checks, failures and
  founder acceptance separately. No production readiness claim follows from
  this development configuration.

## Ownership and handoff

Codex owns environment/configuration setup and independent technical checks.
Copilot owns scoped application fixes and their tests in the IntQAFlow workspace.
Founder + Codex review together; the founder owns product acceptance and release
approval. This PR does not authorize implementation of audit remediation.
The next application handoff is IQ-01 clean startup, followed by fresh-account
acceptance and the remaining runtime checks. Monitoring
agents remain deferred.

## Stop and resume

Stop the API and Flutter processes, then from the repository root:

```sh
docker compose -f compose.isolated-dev.yaml down
```

This retains the isolated volume. Resume with the same standalone file and
development settings. Removing volumes deletes isolated development data and
requires a deliberate reset; do not include -v in routine shutdown commands.
Stop any future Codespace when unused.

## Context reviewed before implementation

Read the repository root README, docs/architecture.md, Flutter README,
answers feature README, backend settings, environment example, Compose model,
API startup source and dependency requirements at the baseline commit. Also read
the IntQAFlow audit in draft PR #1 and the agreed company workflow in Happnn
draft PR #9 at b5a90194a23190afcba8f77e76352b7e37847725. That workflow describes
shared responsibilities; its Happnn resource inventory is not an IntQAFlow
environment inventory. No dedicated IntQAFlow workflow file existed in the
inspected baseline documentation.

Retrieved relevant excerpts from the NOPAK chats titled Interactive Question
Flow and Smart Q&A Platform. Full transcripts were not available, so this is
not a claim of complete chat review. Recovered decisions preserve answer-owned
follow-up branching, one platform with both modules, incremental Flutter/Copilot
implementation, temporary identity during local development, and deferral of
document ingestion, generative AI, agents and Teams/browser integrations.
Current repository documents govern implementation details where an older
planning excerpt differs. The supplied Phase 6 completion message also records
paste/copy rather than native JSON file handling and an incomplete manual A–M
parity matrix; prior test counts do not supersede the later audit's clean-import
failure.

Known setup boundary: configuration prepared and statically checked; complete
chat recovery, a development Codespace and live acceptance are not complete.
Do not treat the isolation branch or this runbook as a working environment.

## Development container candidate and fresh baseline check

The .devcontainer directory adds a Python 3.12 workspace plus a PostgreSQL 16
pgvector sidecar. The database has no published host ports. Its workspace-only
DATABASE_URL uses postgres:5432 rather than the host's loopback:55432; these are
two separate development launch modes. Do not source the local-host environment
example inside the devcontainer, because it would replace the sidecar URL.

The bootstrap installs backend tooling and the Flutter source revision recorded
in apps/flutter_app/.metadata (ff37bef603469fb030f2b72995ab929ccfc227f0).
It prepares Flutter web dependencies; it does not migrate, seed, start servers,
or patch application code. Backend ranges remain in requirements.txt, while
requirements.lock pins the resolved Python 3.12 runtime, test dependencies, and
Ruff analyzer. The backend validation workflow installs that lock, runs pip
check, Ruff syntax/undefined-name checks, compileall, and the full pytest suite.
Container images and Flutter tooling are still not digest/version locked.

No ports are explicitly forwarded, and automatic forwarding is disabled.
Before adding a private web/API tunnel, inspect actual Codespace port
visibility and verify signed-out access is denied. No database forwarding is
needed. Browser preview routing is not established by this configuration.
Do not switch the server-backed platform to public access to solve routing.

Development container JSON/YAML, no-published-port assertions, fake-provider
settings, database consistency, Flutter revision consistency and bootstrap
bash syntax passed static checks. Neither the container image build nor
bootstrap execution nor Codespace rebuild has been verified.

Fresh backend check on 2026-10-02, Python 3.12.14, clean branch application
source, exported local isolated settings and fake embeddings:
- Dependencies installed in a new backend .venv; pip check passed.
- app.main import fails with TypeError: 'function' object is not subscriptable
  at backend/app/services/team.py line 157.
- pytest exits 4 during conftest import; no tests are collected.
- No import workaround, migration, seed, API launch or customer data is used.
- Resolved versions: FastAPI 0.142.2, SQLAlchemy 2.1.2, Pydantic 2.13.5,
  pydantic-settings 2.15.0, pytest 8.4.2, pytest-asyncio 1.4.0,
  asyncpg 0.31.0, pgvector 0.5.0, Alembic 1.20.0.

IQ-01 application handoff for founder + Codex review: Copilot should restore
clean supported-Python import without changing access policy or unrelated
audit findings, then run the existing fake-provider backend suite and record
the supported resolved dependencies. This is a prepared scope, not evidence
that Copilot has been assigned or implemented it.

Codespace provisioning requires a capability beyond the current connected
GitHub repository tools. Plugin discovery found the installed GitHub plugin
but no additional Codespaces control. A browser fallback needs user approval
before it is used. No Codespace has been created or started.

References: [Dev Container specification](https://github.com/devcontainers/spec/blob/main/docs/specs/devcontainerjson-reference.md)
and [GitHub port forwarding](https://docs.github.com/en/codespaces/developing-in-a-codespace/forwarding-ports-in-your-codespace).
