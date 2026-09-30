# IntQAFlow Architecture

IntQAFlow is a monorepo with one shared backend for **IntQAFlow Knowledge** and
**IntQAFlow Interact**, plus future Teams, browser extension, and agent clients.
They are modules of one platform: Interact can produce reusable Knowledge, and
Knowledge can be referenced during Interact sessions.

The application shell exposes Knowledge and Interact as primary destinations.
Knowledge owns the route-backed Ask/Search and Questions views; Review remains
a shared governance destination rather than a third product module.

## Current boundaries

- `apps/flutter_app` contains the employee web shell and uses feature-first
  Flutter modules.
- `backend/app/api` owns HTTP concerns only.
- `backend/app/services` owns validation and business rules.
- `backend/app/repositories` owns SQLAlchemy queries.
- `backend/app/models` owns persisted entities and tenant foreign keys.
- `backend/app/services/permissions.py` owns temporary actor authorization so
  token-based identity can replace request IDs without moving business rules.
- `backend/app/ai` owns the swappable embedding provider and canonical question
  text/hash lifecycle. It does not generate answers or other content.
- `apps/flutter_app/lib/features/guided` owns the native Interact workspace,
  reports, templates, and Review proposal controls. The internal `guided` name
  remains a technical identifier.
- The root `index.html` remains the local-first Interact compatibility
  experience and a supported legacy JSON source for native Interact import.

## Tenant boundary

Every department, team, membership, user, question, answer, comment, and reaction stores
`organisation_id`.
Repositories that retrieve tenant data require that identifier in their query.
Services also verify that referenced users and departments belong to the same
organisation before writing questions or answers.

Question detail uses bounded aggregate reads: question/author/department,
answers/authors/reaction counts, and comment count. It does not issue one query
per answer.

Authentication is not implemented. Development clients currently send
`organisation_id` and `user_id`; TODO markers identify every boundary where
these values must later come from validated authentication tokens.

Semantic search and governance take their temporary identity from
`X-Organisation-ID` and `X-User-ID` headers rather than the request body. Its
repository filters by organisation, answered/resolved state, eligible answer,
embedding model, and visibility before returning candidates. Organisation-visible rows
are shared within the tenant, department-visible rows require the user's single
primary `department_id`, and private rows are visible only to their author.

`users.department_id` is the nullable primary department. Operational team
membership is many-to-many through `team_memberships`; it does not replace or
infer the user's formal department.

## Organisation structure

- Departments own knowledge governance. Teams model operational groups and may
  reference one department or remain cross-functional.
- Team, membership, and question-team relationships use tenant-scoped service
  checks and composite database foreign keys to prevent cross-organisation
  links.
- Questions may carry `department_id`, `team_id`, both, or neither. A linked
  team's parent department must match an explicitly supplied question
  department. The backend does not silently rewrite either field.
- Department owners govern team-only questions when the team has a parent
  department. Cross-functional team questions are admin-governed for now.
- Team-only visibility is intentionally deferred. Existing organisation,
  department, and private visibility rules remain unchanged.
- Search returns canonical department/team metadata without weighting teams in
  ranking. Canonical merges preserve every historical question's team.

## Semantic search

- Canonical embedding input is the trimmed question title followed by the body,
  when present. Author, tenant, timestamps, reactions, and answers are excluded.
- `question_embeddings` stores vectors separately from questions. A source hash
  avoids provider calls when text and model are unchanged.
- Question creation and title/body updates commit before best-effort embedding
  synchronization, so provider outages do not make core Q&A writes unusable.
- The default provider uses an OpenAI-compatible embeddings API. A deterministic
  fake implements the same interface for tests and local development.
- Candidate retrieval uses pgvector cosine distance. The search service owns
  confidence classification and deterministic ranking by similarity band,
  answer freshness/status, and resolution recency. Current verified answers
  outrank overdue verified answers, followed by accepted community answers and
  other eligible content within the same similarity band.
- Only high-confidence and related results are returned. The Flutter Ask flow
  debounces input, shows accepted-answer previews, and still permits submission
  as a new question.

## Basic workflow

- Questions can be created, edited, filtered, resolved, reopened, and archived.
- Answers are community answers by default and can be edited or deleted by
  their author until verified or accepted.
- A question author or organisation admin can accept one answer. Reopening
  clears that accepted answer and the resolution timestamp.
- Comments remain secondary discussion and never change resolution state.
- Answer reactions are unique per answer/user and update in place.

## Answer governance

- Organisation admins govern answers across the tenant. The `answer_owner`
  role requires an explicit `department_answer_owners` mapping and is limited
  to questions in those departments.
- Verification locks the question, supersedes any current verified answer,
  records verifier/review metadata, and optionally accepts the answer.
- Employees may challenge outdated, incorrect, unclear, or incomplete answers
  or suggest replacement content. Owners decide challenges in their scope.
- Accepted replacement content is a new answer row. `answer_versions` provides
  immutable, question-scoped history; freshness-only review creates no version.
- Freshness is derived centrally as current, review due soon, overdue,
  challenged, or superseded. Overdue content remains visible and searchable.
- `audit_events` records governance actions without copying answer bodies into
  event metadata. The application exposes no update or delete operation.
- The review queue is tenant- and department-scoped and supports department,
  queue type, and challenge status filters.

## Canonical questions

- A canonical question has no `canonical_question_id`. A historical duplicate
  points directly to that root; merge traversal rejects cycles and flattens any
  existing descendant chain in one transaction.
- Merge never deletes or moves the duplicate question, comments, answers,
  timestamps, audit events, or embedding. Linked questions therefore act as
  durable aliases without a second alias-text table.
- If reusable answers differ, merge requires an explicit `canonical_answer_id`.
  Selecting a duplicate answer copies it to the canonical question and leaves
  the source answer untouched. Verified answer replacement also creates version
  and audit records.
- Semantic retrieval searches every retained question embedding, joins each raw
  match to its canonical root, and collapses by root using the strongest score.
  Responses identify the canonical question, strongest matched wording, source
  type, and all matched question IDs collected in the candidate window.
- `duplicate_suggestions` represents the employee-to-owner review lifecycle.
  Open suggestions appear in the existing department-scoped review queue and
  may be accepted through merge or rejected without altering either question.
- Canonical linking, answer selection, and suggestions derive tenant/actor
  identity from headers and use the existing admin/department-owner policy.

## IntQAFlow Interact

- Interact sessions, participants, questions, answers, revisions, templates, and
  proposals are tenant-scoped PostgreSQL entities. Composite foreign keys guard
  organisation boundaries for recursive branches and proposal metadata.
- The recursive graph is `GuidedQuestion -> GuidedAnswer -> GuidedQuestion`.
  `triggering_answer_id` is the branch boundary, preserving independent shared
  answers and arbitrarily nested participant follow-ups.
- Session visibility controls access. Private sessions are owner-only;
  department, team, and organisation visibility use explicit scoped checks.
  Team access does not grant department verification authority.
- Mutations create compact revision snapshots and lifecycle audit events.
  Questions use soft deletion so the client can provide immediate undo.
- Template versions are immutable session inputs. Starting a session copies the
  selected version's question graph and stores its version ID, so later template
  edits cannot alter the session.
- Interact content is operational data and has no `question_embeddings` rows.
  Reverse lookup sends only deliberate question text through existing semantic
  Knowledge search. Accepted proposals create primary Question/Answer records
  through the existing Knowledge services, which own embeddings, governance,
  and audit behavior.
- Legacy import normalizes local Interact JSON into the same answer-
  owned recursive graph. Native sessions and template sets have portable JSON;
  session reports also support CSV and browser print/PDF.

## Deferred work

Generative AI, Firebase Auth, team-only visibility for primary Q&A, Microsoft
Teams integration, browser extensions, document ingestion, and agent access
remain intentionally deferred.