"""Permission-scoped, read-only Interact search.

Only current session graphs are searched. Nothing is promoted into Knowledge,
and collapsed branches are included without changing their saved state.
"""
import re
from collections import defaultdict
from datetime import datetime, timezone
from typing import Any
from uuid import UUID

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.department import Department
from app.models.guest import GuestGroup, GuestGroupEntry, GuestGroupMembership
from app.models.guided import GuidedAnswer, GuidedQuestion
from app.models.organisation import Organisation
from app.models.personal_workspace import PersonalWorkspaceItem
from app.models.team import Team
from app.schemas.guided import GuidedViewMode
from app.services.guided import GuidedService


def _match(query: str, text: object) -> tuple[float, str | None]:
    if not isinstance(text, str) or not text.strip():
        return 0.0, None
    folded = text.casefold()
    needle = query.casefold().strip()
    terms = re.findall(r"\w+", needle)
    if not needle or not terms or not all(term in folded for term in terms):
        return 0.0, None
    score = 1.9 if folded.strip() == needle else 1.7 if folded.startswith(needle) else 1.5
    positions = [folded.find(term) for term in terms]
    # Unicode casefold can change character count. A bounded text preview is
    # preferable to pretending folded offsets are exact original offsets.
    start = max(0, min(positions) - 50) if len(folded) == len(text) else 0
    end = min(len(text), start + 220)
    return score, ("…" if start else "") + text[start:end] + ("…" if end < len(text) else "")


def session_matches(
    query: str, session: dict[str, Any], *, metadata: dict[str, Any]
) -> list[dict[str, Any]]:
    """One hit per matching question, plus a distinct session-title hit."""
    hits: list[dict[str, Any]] = []
    score, snippet = _match(query, session.get("title"))
    if score:
        hits.append({
            **metadata, "question_id": None, "participant_id": None,
            "matched_in": "session title", "snippet": snippet,
            "relevance_score": score, "match_method": "keyword",
        })
    stack = [(item, None) for item in reversed(session.get("questions") or [])]
    seen: set[int] = set()
    while stack:
        question, inherited_participant = stack.pop()
        if not isinstance(question, dict) or id(question) in seen:
            continue
        seen.add(id(question))
        if question.get("deleted_at") is not None:
            continue
        participant = question.get("target_participant_id") or inherited_participant
        score, snippet = _match(query, question.get("text"))
        matched_in = "follow-up" if question.get("source") == "follow_up" or inherited_participant else "question"
        for answer in question.get("answers") or []:
            if not isinstance(answer, dict):
                continue
            answer_score, answer_snippet = _match(query, answer.get("body"))
            if answer_score > score:
                score, snippet = answer_score, answer_snippet
                participant = answer.get("participant_id")
                matched_in = "answer"
            for child in reversed(answer.get("follow_ups") or []):
                stack.append((child, answer.get("participant_id")))
        # Organisation Interact serialises branches beside answers; guest and
        # personal sessions keep them inside their owning answer.
        for child in reversed(question.get("follow_ups") or []):
            stack.append((child, participant))
        question_id = question.get("id")
        if score and isinstance(question_id, str):
            hits.append({
                **metadata, "question_id": question_id,
                "participant_id": participant,
                "matched_in": matched_in, "snippet": snippet,
                "relevance_score": score, "match_method": "keyword",
            })
    return hits


def ranked_response(hits: list[dict[str, Any]], limit: int) -> dict[str, Any]:
    hits.sort(key=lambda hit: (
        -hit["relevance_score"], hit["title"].casefold(),
        hit["source"], hit["session_id"], hit.get("question_id") or "",
    ))
    return {"results": hits[:limit], "partial": len(hits) > limit}


class InteractSearchService:
    def __init__(self, session: AsyncSession) -> None:
        self.session = session

    async def personal_and_groups(self, firebase_uid: str, query: str, *, limit: int = 25) -> dict:
        hits: list[dict[str, Any]] = []
        private = await self.session.scalars(
            select(PersonalWorkspaceItem).where(
                PersonalWorkspaceItem.firebase_uid == firebase_uid,
                PersonalWorkspaceItem.kind == "interact_session",
            )
        )
        for item in private:
            source_id = item.data.get("id")
            if not isinstance(source_id, str):
                continue
            hits.extend(session_matches(query, {**item.data, "title": item.title}, metadata={
                "id": str(item.id), "session_id": source_id,
                "title": item.title, "source": "Private", "destination": "personal",
                "owner_uid": firebase_uid, "kind": "interact_session",
                "status": item.data.get("status", "private"),
            }))
        # Permission checks precede reading/matching content, and match the
        # Group entry access boundary: active membership, live unarchived group.
        groups = await self.session.execute(
            select(GuestGroupEntry, GuestGroup.name)
            .join(GuestGroup, GuestGroup.id == GuestGroupEntry.group_id)
            .join(GuestGroupMembership, GuestGroupMembership.group_id == GuestGroup.id)
            .where(
                GuestGroupMembership.firebase_uid == firebase_uid,
                GuestGroupMembership.status == "active",
                GuestGroup.archived_at.is_(None),
                GuestGroup.expires_at > datetime.now(timezone.utc),
                GuestGroupEntry.kind == "interact_session",
            )
        )
        for entry, group_name in groups:
            hits.extend(session_matches(query, {**entry.data, "title": entry.title}, metadata={
                "id": str(entry.id), "session_id": str(entry.id),
                "group_id": str(entry.group_id), "title": entry.title,
                "source": f"Group: {group_name}", "destination": "group",
                "kind": "interact_session", "status": "Group copy",
            }))
        return ranked_response(hits, limit)

    async def organisation(self, organisation_id: UUID, user_id: UUID, query: str, *, limit: int = 25) -> dict:
        guided = GuidedService(self.session)
        # This is the same visibility/role logic used by the session list.
        sessions = await guided.list_sessions(organisation_id, user_id)
        if not sessions:
            return {"results": [], "partial": False}
        session_ids = [item.id for item in sessions]
        questions = await self.session.scalars(
            select(GuidedQuestion).where(
                GuidedQuestion.organisation_id == organisation_id,
                GuidedQuestion.session_id.in_(session_ids),
                GuidedQuestion.deleted_at.is_(None),
            ).order_by(
                GuidedQuestion.main_order_index.asc().nullslast(),
                GuidedQuestion.branch_order_index.asc().nullslast(),
                GuidedQuestion.created_at,
            )
        )
        answers = await self.session.scalars(
            select(GuidedAnswer).where(
                GuidedAnswer.organisation_id == organisation_id,
                GuidedAnswer.session_id.in_(session_ids),
            )
        )
        questions_by_session: dict = defaultdict(list)
        answers_by_session: dict = defaultdict(list)
        for question in questions:
            questions_by_session[question.session_id].append(question)
        for answer in answers:
            answers_by_session[answer.session_id].append(answer)
        organisation_name = await self.session.scalar(
            select(Organisation.name).where(Organisation.id == organisation_id)
        )
        departments = {item.id: item.name for item in await self.session.scalars(
            select(Department).where(Department.organisation_id == organisation_id)
        )}
        teams = {item.id: item.name for item in await self.session.scalars(
            select(Team).where(Team.organisation_id == organisation_id)
        )}
        hits: list[dict[str, Any]] = []
        for item in sessions:
            # Use the editor's graph construction, excluding deleted questions
            # and orphaned descendants rather than searching raw answer rows.
            flow = guided._build_flow(
                questions_by_session[item.id], answers_by_session[item.id],
                None, GuidedViewMode.ALL_RELEVANT, item.revision,
            )
            data = {"title": item.title, "questions": [
                question.model_dump(mode="json") for question in flow
            ]}
            metadata = {
                "id": str(item.id), "session_id": str(item.id),
                "title": item.title, "source": f"Organisation: {organisation_name or 'Organisation'}",
                "destination": "organisation_interact", "kind": "interact_session",
                "status": item.status.value, "visibility": item.visibility.value,
            }
            if item.department_id in departments:
                metadata["department"] = {"name": departments[item.department_id]}
            if item.team_id in teams:
                metadata["team"] = {"name": teams[item.team_id]}
            hits.extend(session_matches(query, data, metadata=metadata))
        return ranked_response(hits, limit)
