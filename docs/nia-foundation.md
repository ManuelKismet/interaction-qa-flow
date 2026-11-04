# IntQAFlow NIA foundation

NIA is the shared architecture. NIC owns product-neutral context, capability,
evaluation and feedback contracts; ANI places assistance inside existing tasks.
IntQAFlow supplies permitted workflow facts and existing human-operated actions.
No nearby matching, location collection, automatic approvals, model provider,
embedding pipeline or new sharing authority is introduced by this foundation.

## Contract and ownership

The dependency-free Dart package packages/nopak_nia contains the shared core.
Its six concerns map to bounded context sensing, session preferences/feedback,
authorized opportunity matching, adaptive presentation, deterministic evaluation
and learning receipts. One NIC session lives below the real Firebase auth boundary.
Workspace scopes share that owner. Account, membership, role, department, team or
permission changes invalidate assistance; old reads cannot revive old decisions.
Navigator dialogs retain their original binding and withdraw assistance when that
binding changes. User drafts stay with existing application stores.

Contexts contain bounded primitive facts and expire after two minutes. This is an
assistance lifetime, not a backend permission cache. Evaluation uses a 50ms budget;
automatic presentations have a three-item session budget and two-minute cooldown.
Explicit help remains subject to current context. Receipts are accepted only for
actually presented current decisions. Dismissal and feedback stay in memory;
account changes, disable/reset and disposal clear them. No persistent user
profiling or new telemetry store is added.

## IntQAFlow capabilities

- Knowledge keeps source authorization, local ranking, cancellation and duplicate
  handling. Shared matching preserves existing title/answer/body scores and never
  retrieves records itself.
- Suggestion Bank shows useful overdue/unread queue guidance inline. The persistent
  review-helper card and generic backend prompts are removed. Explicit related
  lookup retains authorized suggestions and approved organisational Knowledge.
  Changed query, identity or authority discards results without losing the draft.
  Opening Knowledge explicitly confirms leaving the draft. Review and publication
  continue through existing human-operated services.
- Existing information controls use the common ANI adapter with current storage,
  identity, role, session phase and workflow facts. Active Knowledge/Interact help
  follows the actual tab controller, including swipes. Factual errors, save status,
  permission gates, confirmations and Undo remain visible.

Personal navigation exposes Knowledge, Interact and Groups together. Groups keeps
its verified-account gate and draft flush. Organisation Interact places the
existing Import session menu in the app bar on phone and desktop.

## Validation and delivery boundary

Core tests cover scopes, actors, immutability, expiry/rollback, authority withdrawal,
cancellation, output/time budgets, no writes, receipts, quietness, disable/reset
and unchanged ranking. Widget tests cover real dialog boundaries, late results,
draft preservation and navigation. Existing account, Group, import, lifecycle and
responsive tests remain gates. Backend tests include an isolated PostgreSQL schema.

This is the reusable base and deterministic IntQAFlow adapters. Future model-backed
capabilities must implement these contracts and authorize sources before evaluation.
AI provider integration, persistent learning and adoption by other products remain
separate work; they are not claimed as completed by this release.

Deploy only to the existing DEV backend and web Hosting. No migration, Firebase
authority change, production release or native build is required. Retain the prior
DEV backend revision and Hosting version for rollback.
