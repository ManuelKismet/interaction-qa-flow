# IntQAFlow

IntQAFlow is a multi-tenant internal knowledge platform with two connected
modules:

- **IntQAFlow Knowledge** provides organisational Q&A, semantic retrieval,
  verified answers, governance, canonical knowledge, and reusable memory.
- **IntQAFlow Interact** provides structured sessions, participants, shared and
  participant-specific questions, answer-triggered follow-ups, templates,
  reports, and deliberate knowledge capture.

They are modules of the same platform, not separate applications. Interact can
produce reusable Knowledge, and Knowledge can be referenced during Interact
sessions. The repository also preserves the original local-first flow format
for compatibility and JSON migration.

In the Flutter navigation, IntQAFlow Knowledge contains the **Ask & search**
and **Questions** views. Questions is not a separate platform module. Review is
the shared governance area for Knowledge and proposals produced by Interact.

Departments represent formal ownership; teams represent operational groups.
A team may belong to a department or remain cross-functional, and users may
belong to multiple teams. The existing nullable `users.department_id` remains
the user's single primary department for compatibility.

## Repository layout

```text
apps/flutter_app/  Flutter web application
backend/           FastAPI, SQLAlchemy, Alembic, and tests
docs/              Architecture documentation
index.html         Local-first Interact compatibility experience
compose.yaml       Local PostgreSQL service
```

## Local PostgreSQL

Start PostgreSQL 16 with the pgvector extension using Docker Compose:

```sh
docker compose up -d --wait postgres
```

Some installations use the standalone command instead:

```sh
docker-compose up -d --wait postgres
```

Stop it without deleting data:

```sh
docker compose down
```

## FastAPI

From the repository root:

```sh
cd backend
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.lock
cp .env.example .env
alembic upgrade head
uvicorn app.main:app --reload --port 8000
```

Set `EMBEDDING_API_KEY` for the default OpenAI-compatible provider. The model
defaults to `text-embedding-3-small`; `EMBEDDING_BASE_URL` can point to another
API implementing the same embeddings contract. For deterministic local testing
without credentials, set `EMBEDDING_PROVIDER=fake`.

Verified answers default to a 180-day review period. Configure
`DEFAULT_REVIEW_DAYS` to change that interval and `REVIEW_DUE_SOON_DAYS` to
change when answers enter the due-soon queue.

The database column is fixed at 1536 dimensions. Changing
`EMBEDDING_DIMENSIONS` requires a migration and full embedding backfill.

Backfill missing or stale embeddings after configuring the provider:

```sh
cd backend
.venv/bin/python -m scripts.backfill_question_embeddings
```

The command is idempotent: unchanged question text and model combinations are
skipped using a source hash, while failures can be retried by rerunning it.

The API is available at `http://localhost:8000`; `/health` is a liveness check,
and `/ready` checks database connectivity and the required `organisations` table.
Interactive documentation is available at `/docs`.

`requirements.txt` contains supported dependency ranges;
`backend/requirements.lock` pins the resolved runtime and test dependencies for
reproducible Python 3.12 installs. Backend CI installs the lock, runs
`pip check`, Ruff syntax/undefined-name checks, compiles application/test
modules, and runs the full test suite.
Run backend tests locally with:

```sh
cd backend
.venv/bin/python -m pytest -q
```

## Flutter web

From the repository root:

See [`apps/flutter_app/README.md`](apps/flutter_app/README.md) for local and
hosted build configuration. The app uses Firebase email/password
authentication; never pass caller-selected user, organisation, or role IDs.

Run Flutter checks with:

```sh
cd apps/flutter_app
flutter test
flutter analyze
flutter build web
```

## Current API

- `GET /health`
- `GET /api/v1/auth/me`
- `POST /api/v1/departments`
- `GET /api/v1/departments`
- `GET /api/v1/teams`
- `POST /api/v1/teams`
- `GET /api/v1/teams/{team_id}`
- `PATCH /api/v1/teams/{team_id}`
- `GET /api/v1/teams/{team_id}/members`
- `POST /api/v1/teams/{team_id}/members`
- `DELETE /api/v1/teams/{team_id}/members/{user_id}`
- `POST /api/v1/questions`
- `POST /api/v1/questions/search`
- `GET /api/v1/questions`
- `GET /api/v1/questions/{question_id}`
- `PATCH /api/v1/questions/{question_id}`
- `POST /api/v1/questions/{question_id}/resolve`
- `POST /api/v1/questions/{question_id}/reopen`
- `POST /api/v1/questions/{question_id}/archive`
- `GET /api/v1/questions/{question_id}/duplicate-candidates`
- `POST /api/v1/questions/{question_id}/duplicate-suggestions`
- `POST /api/v1/questions/{canonical_question_id}/merge`
- `POST /api/v1/questions/{question_id}/unmerge`
- `POST /api/v1/questions/{question_id}/answers`
- `GET /api/v1/questions/{question_id}/answers`
- `PATCH /api/v1/answers/{answer_id}`
- `DELETE /api/v1/answers/{answer_id}`
- `POST /api/v1/answers/{answer_id}/reaction`
- `POST /api/v1/answers/{answer_id}/verify`
- `POST /api/v1/answers/{answer_id}/unverify`
- `POST /api/v1/answers/{answer_id}/review`
- `POST|GET /api/v1/answers/{answer_id}/challenges`
- `GET /api/v1/answers/{answer_id}/versions`
- `POST /api/v1/challenges/{challenge_id}/accept`
- `POST /api/v1/challenges/{challenge_id}/reject`
- `GET /api/v1/review-queue`
- `GET /api/v1/department-answer-owners`
- `POST /api/v1/departments/{department_id}/answer-owners`
- `DELETE /api/v1/departments/{department_id}/answer-owners/{user_id}`
- `GET /api/v1/audit-events`
- `POST /api/v1/duplicate-suggestions/{suggestion_id}/accept`
- `POST /api/v1/duplicate-suggestions/{suggestion_id}/reject`
- `POST /api/v1/questions/{question_id}/comments`
- `GET /api/v1/questions/{question_id}/comments`
- `PATCH /api/v1/comments/{comment_id}`
- `DELETE /api/v1/comments/{comment_id}`
- `/api/v1/guided/templates` and template version/import/export operations
- `/api/v1/guided/sessions` and lifecycle/revision/export operations
- Interact participant, question, answer, and recursive follow-up operations
- Interact-to-Knowledge search and proposal review operations

All `/api/v1` routes require a verified Firebase ID token mapped to an active
server-side membership and a distinct App Check gate. Tenant scope is derived
from that membership; organisation creation is a private operator operation,
not an API endpoint.

Question lists support `status`, `department_id`, `team_id`, `author_id`, `offset`, and
`limit` query parameters. Tenant selection is not caller-controlled.

Semantic search accepts `{ "query": "...", "limit": 5 }`. Search returns answered
or resolved questions with eligible answers that the caller may access.
Knowledge Ask sends `include_unanswered: true` so duplicate prevention also
returns accessible open questions. Normalized exact-title matches are retained
even when question detail text lowers embedding similarity. Interact and other
reusable-Knowledge lookups keep the default answer-only behavior.
Within a similarity band, current verified answers rank ahead of overdue
verified answers, accepted community answers, and other eligible content.
Overdue and challenged answers remain searchable and are labelled in the
response. Vectors and provider credentials are never returned to clients.
Search responses include department and team metadata, but teams do not alter
ranking.

Question authors and organisation admins can correct a submitted question's
title, detail, department, and team. Mistaken questions are archived rather
than deleted so history and governance records remain intact.

Merged questions are never deleted. Their original wording, author, body,
answers, comments, timestamps, embeddings, and audit history remain attached to
the historical question. Each duplicate points directly to a root canonical
question. Search evaluates both canonical and historical embeddings, groups raw
matches by canonical ID, keeps the strongest similarity, and returns one
knowledge result with matched-phrasing metadata.

Governance endpoints use the same development identity headers. Organisation
admins can govern all departments. An `answer_owner` can govern only explicitly
assigned departments; employees can submit challenges but cannot verify,
review, or decide them. Replacements create immutable question-scoped versions
and supersede the previous verified answer. A simple review changes freshness
dates without creating a content version. Governance actions append audit
events whose metadata intentionally excludes answer bodies.

Admins and department-scoped answer owners can merge and unmerge questions.
Conflicting accepted or verified answers require an explicit canonical answer
selection; selected duplicate answers are copied to the canonical question so
the original answer and history remain intact. Employees may report likely
duplicates for review but cannot merge them directly.

Team creation, editing, and membership changes are admin-only and append audit
events. If a question supplies both department and team, the team's parent
department must match. Department owners retain authority for their department
and its teams; cross-functional team questions remain admin-governed.

## IntQAFlow Interact

IntQAFlow Interact is the platform's structured interaction module. Sessions
move from draft to active, completed, and archived states; contain multiple
participants; and support shared or participant-targeted prepared questions.
Every participant answer is independent. Follow-up questions belong to the
exact answer that triggered them and may recurse to any depth, so one
participant's branch never leaks into another participant's flow.

The Flutter Interact workspace includes participant and view filters, progress,
autosave state, soft-delete undo, recursive branches, read-only participant and
all-participant reports, JSON/CSV export, print/PDF, and revision history.
Templates are versioned snapshots: later edits do not change sessions already
created from an earlier version. Template sets can be duplicated and moved as
JSON, and an empty organisation receives the built-in General Interaction QA
template.

Interact session content is private operational data and is never embedded in
the global semantic index. Users may deliberately search existing
organisational Knowledge from an Interact question. They may also propose a
specific Interact question/answer pair for reuse; admins or the appropriate
department answer owner then accept it into IntQAFlow Knowledge, link it to an
existing question, or reject it through the shared Review queue. Team
visibility and department governance remain separate concerns.

## Local Interact compatibility

The root `index.html` remains a free, local-first browser tool for mapping
shared questions, individual questions, live answers, and unexpected follow-up
branches. Its exports can be imported into IntQAFlow Interact.

It is designed for conversations and workflows where you start with a planned question path, switch between participants, and capture new follow-up questions when an answer reveals something unexpected.

## Use Cases

- Customer support troubleshooting
- Incident reports
- Audit or compliance checks
- Requirements discovery
- Consulting or discovery calls
- QA and exploratory testing notes

## Features

- Prepared question path
- Multiple participants
- Shared questions with separate answers per participant
- Individual questions
- Answer fields for each question
- Follow-up branches from any answer
- Nested follow-up branches
- Editable questions and answers
- Question deletion with undo
- Local autosave in the browser
- Autosave history summary
- Named JSON export files
- JSON import to reopen or share flows
- CSV export
- Read-only active participant and all-participants report views
- Print / Save PDF support
- One built-in default template
- Local custom templates for repeated question sets
- Template import and export
- No login or backend required

## Privacy

This tool stores data locally in your browser using `localStorage`. Nothing is uploaded by the app. A flow only leaves your device if you export and share a JSON, CSV, or PDF file yourself.

If you clear browser storage, local autosaved data may be removed. Use **Save JSON file** for anything important.

Autosave runs after each edit, add, delete, import, template load, or view change. The autosave history list is summarized and throttled so quick edits do not create a new history row for every keystroke.

## How To Use

1. Open `index.html` in a browser.
2. Add shared questions when every participant should answer the same prompt.
3. Add participants and switch between them to capture separate answers.
4. Add individual questions when only the active participant needs that prompt.
5. Use **Add follow-up** to create an individual branch.
6. Use **Report view** for a read-only summary of the active participant view, or **All participants report** for every participant.
7. Use **Save JSON file** to keep a reusable copy.
8. Use **Open JSON file** to reopen a saved flow.

## Templates

The local experience includes one default template for a general interaction flow.

You can also save your own recurring question sets as local templates. Custom templates are stored in your browser, keep the question and branch structure, and clear answer text so sensitive responses are not carried into the reusable template.

Use **Export templates** and **Import templates** to share template sets with another browser, device, or team. Loading a template replaces the current flow after confirmation when data already exists.

**Clear flow** resets the active flow only. It does not delete saved local templates; use **Delete template** for that.

## Hosting

This is a static site. You can host it with:

- GitHub Pages
- Cloudflare Pages
- Netlify
- Vercel
- Any static web server

No build step is required.

## Development

The app is currently a single self-contained HTML file:

- `index.html`

A quick JavaScript syntax check can be run with:

```sh
node -e 'const fs=require("fs"); const html=fs.readFileSync("index.html","utf8"); for (const [,code] of html.matchAll(/<script>([\s\S]*?)<\/script>/g)) new Function(code); console.log("inline script syntax ok");'
```

## License

MIT. See `LICENSE`.
