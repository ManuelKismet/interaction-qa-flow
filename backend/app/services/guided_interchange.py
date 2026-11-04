"""Validate an entire interchange graph before the importer writes any rows."""

import json
from typing import Any

from pydantic import ValidationError

from app.core.exceptions import ConflictError
from app.models.guided import GuidedQuestionScope
from app.schemas.guided import (
    GuidedAnswerResponse,
    GuidedFlowQuestion,
    GuidedParticipantResponse,
    GuidedSessionResponse,
)


def _invalid(path: str, message: str) -> None:
    raise ConflictError(f"Invalid guided import at {path}: {message}")


def _text(value: Any, path: str, *, blank: bool = True, limit: int | None = None) -> str:
    if not isinstance(value, str) or (not blank and not value.strip()):
        _invalid(path, "expected a non-blank string" if not blank else "expected a string")
    if limit is not None and len(value) > limit:
        _invalid(path, f"must not exceed {limit} characters")
    return value


def _order(value: Any, path: str) -> int:
    if type(value) is not int or value < 0:
        _invalid(path, "expected a non-negative integer")
    return value


def _extras(record: dict, allowed: set[str], path: str, warnings: list[str]) -> None:
    for key in sorted(record.keys() - allowed):
        warnings.append(f"{path}.{key} is not supported and was not imported.")


def normalize_import(payload: dict[str, Any] | list[Any]) -> tuple[dict, list[dict], list[dict], list[str]]:
    warnings: list[str] = []
    if isinstance(payload, dict) and ("workspaces" in payload or "sessions" in payload):
        raise ConflictError(
            "Guest multi-workspace backups cannot be imported into an organisation session. "
            "Export one supported legacy flow or guided session instead; the backup is unchanged."
        )
    if isinstance(payload, dict) and "kind" in payload:
        if payload["kind"] != "intqaflow-guided-session" or type(payload.get("version")) is not int or payload["version"] != 1:
            _invalid("root", "unsupported interchange kind or version")
        return _guided(payload, warnings)
    source = {"flow": payload} if isinstance(payload, list) else payload
    if not isinstance(source, dict) or not isinstance(source.get("flow"), list):
        _invalid("flow", "expected a legacy flow array or a version 1 guided session envelope")
    _extras(source, {"meta", "participants", "flow", "activeParticipantId", "viewMode"}, "root", warnings)
    meta = source.get("meta", {})
    if not isinstance(meta, dict):
        _invalid("meta", "expected an object")
    _extras(meta, {"caseTitle", "interviewer", "interviewee"}, "meta", warnings)
    values = {
        "title": _text(meta.get("caseTitle", "Imported Interaction QA Flow"), "meta.caseTitle", blank=False, limit=500),
        "owner_text": _text(meta["interviewer"], "meta.interviewer", limit=255) if "interviewer" in meta else None,
        "context_reference": _text(meta["interviewee"], "meta.interviewee") if "interviewee" in meta else None,
    }
    participants = source.get("participants")
    if participants is None or participants == []:
        participants = [{"id": "participant-1", "name": "Participant 1"}]
        warnings.append("No participant list was present; Participant 1 was created.")
    if not isinstance(participants, list):
        _invalid("participants", "expected an array")
    normalized_participants = []
    ids: set[str] = set()
    for index, participant in enumerate(participants):
        path = f"participants[{index}]"
        if not isinstance(participant, dict):
            _invalid(path, "expected an object")
        key = _text(participant.get("id", f"participant-{index + 1}"), f"{path}.id", blank=False)
        if key in ids:
            _invalid(f"{path}.id", "duplicate participant ID")
        ids.add(key)
        _extras(participant, {"id", "name", "role_label", "role", "notes", "sort_order"}, path, warnings)
        normalized_participants.append({
            "id": key,
            "name": _text(participant.get("name", f"Participant {index + 1}"), f"{path}.name", blank=False, limit=255),
            "role_label": _text(participant.get("role_label", participant.get("role")), f"{path}.role", limit=255)
            if participant.get("role_label", participant.get("role")) is not None else None,
            "notes": _text(participant["notes"], f"{path}.notes") if participant.get("notes") is not None else None,
            "sort_order": _order(participant.get("sort_order", index), f"{path}.sort_order"),
        })
    question_ids: set[str] = set()

    def node(raw: Any, path: str, parent: str | None = None, depth: int = 0) -> dict:
        if depth > 100:
            _invalid(path, "branch depth exceeds 100")
        if not isinstance(raw, dict):
            _invalid(path, "expected a question object")
        _extras(raw, {"id", "question", "scope", "participantId", "answers", "answer", "branches", "branchesCollapsed"}, path, warnings)
        if "id" in raw:
            key = _text(raw["id"], f"{path}.id", blank=False)
            if key in question_ids:
                _invalid(f"{path}.id", "duplicate question ID")
            question_ids.add(key)
        scope = raw.get("scope", "participant" if parent else "shared")
        if not isinstance(scope, str) or scope not in {"shared", "participant"}:
            _invalid(f"{path}.scope", "expected shared or participant")
        target = raw.get("participantId", parent)
        if target is not None and not isinstance(target, str):
            _invalid(f"{path}.participantId", "expected a participant ID string")
        if scope == "participant" and target not in ids:
            _invalid(f"{path}.participantId", "unknown participant")
        if scope == "shared" and target is not None:
            _invalid(f"{path}.participantId", "shared questions cannot target a participant")
        if parent and (scope != "participant" or target != parent):
            _invalid(path, "follow-up must belong to its triggering answer's participant")
        answers = raw.get("answers")
        if answers is None:
            key = target or next(iter(item["id"] for item in normalized_participants))
            answers = {key: {field: raw.get(field, default) for field, default in (
                ("answer", ""), ("branches", []), ("branchesCollapsed", False)
            )}}
        elif any(key in raw for key in ("answer", "branches", "branchesCollapsed")):
            _invalid(path, "cannot mix answers with legacy single-answer fields")
        if not isinstance(answers, dict):
            _invalid(f"{path}.answers", "expected an object keyed by participant ID")
        result = {"question": _text(raw.get("question"), f"{path}.question", blank=False),
                  "scope": scope, "participantId": target, "answers": {}}
        for key, record in answers.items():
            answer_path = f"{path}.answers.{key}"
            if key not in ids or (target is not None and key != target):
                _invalid(answer_path, "answer belongs to an unknown or different participant")
            if not isinstance(record, dict):
                _invalid(answer_path, "expected an answer object")
            _extras(record, {"answer", "branches", "branchesCollapsed"}, answer_path, warnings)
            branches = record.get("branches", [])
            collapsed = record.get("branchesCollapsed", False)
            if not isinstance(branches, list) or type(collapsed) is not bool:
                _invalid(answer_path, "branches must be an array and branchesCollapsed a boolean")
            result["answers"][key] = {
                "answer": _text(record.get("answer", ""), f"{answer_path}.answer"),
                "branchesCollapsed": collapsed,
                "branches": [node(branch, f"{answer_path}.branches[{index}]", key, depth + 1)
                             for index, branch in enumerate(branches)],
            }
        return result

    flow = [node(item, f"flow[{index}]") for index, item in enumerate(source["flow"])]
    return values, normalized_participants, flow, warnings


def _guided(payload: dict, warnings: list[str]) -> tuple[dict, list[dict], list[dict], list[str]]:
    try:
        detail = GuidedSessionResponse.model_validate_json(json.dumps(payload.get("session")), strict=True)
    except (ValidationError, RecursionError) as error:
        _invalid("session", f"malformed guided session: {error}")
    _extras(payload, {"kind", "version", "exportedAt", "session"}, "root", warnings)
    _extras(payload["session"], set(GuidedSessionResponse.model_fields), "session", warnings)
    for index, participant in enumerate(payload["session"].get("participants", [])):
        _extras(participant, set(GuidedParticipantResponse.model_fields), f"session.participants[{index}]", warnings)

    def warn_extras(raw, path):
        _extras(raw, set(GuidedFlowQuestion.model_fields), path, warnings)
        for index, answer in enumerate(raw.get("answers", [])):
            _extras(answer, set(GuidedAnswerResponse.model_fields), f"{path}.answers[{index}]", warnings)
        for index, child in enumerate(raw.get("follow_ups", [])):
            warn_extras(child, f"{path}.follow_ups[{index}]")

    for index, raw in enumerate(payload["session"].get("questions", [])):
        warn_extras(raw, f"session.questions[{index}]")
    participant_ids: set[str] = set()
    participants = []
    for index, item in enumerate(detail.participants):
        key = str(item.id)
        if key in participant_ids or item.session_id != detail.id or item.organisation_id != detail.organisation_id:
            _invalid(f"session.participants[{index}]", "duplicate ID or foreign session/organisation")
        participant_ids.add(key)
        participants.append({
            "id": key, "name": _text(item.name, "participant.name", blank=False, limit=255),
            "role_label": _text(item.role_label, "participant.role_label", limit=255) if item.role_label is not None else None,
            "notes": item.notes, "sort_order": _order(item.sort_order, "participant.sort_order"),
        })
        if item.linked_user_id:
            warnings.append(f"Participant {item.name}'s account link was not imported.")
    question_ids: set[str] = set()
    answer_ids: set[str] = set()

    def node(item, parent=None, depth=0):
        path = f"question[{item.id}]"
        if depth > 100:
            _invalid(path, "branch depth exceeds 100")
        key = str(item.id)
        if key in question_ids or item.session_id != detail.id or item.organisation_id != detail.organisation_id:
            _invalid(path, "duplicate ID or foreign session/organisation")
        question_ids.add(key)
        target = str(item.target_participant_id) if item.target_participant_id else None
        if item.scope == GuidedQuestionScope.PARTICIPANT and target not in participant_ids:
            _invalid(path, "unknown target participant")
        if item.scope == GuidedQuestionScope.SHARED and target is not None:
            _invalid(path, "shared question has a target")
        if parent:
            if item.triggering_answer_id != parent.id or target != str(parent.participant_id) or item.scope != GuidedQuestionScope.PARTICIPANT or item.source.value != "follow_up":
                _invalid(path, "follow-up does not belong to its triggering answer")
        elif item.triggering_answer_id is not None or item.source.value == "follow_up":
            _invalid(path, "root question cannot reference a triggering answer")
        order = item.branch_order_index if parent else item.main_order_index
        _order(order, f"{path}.order")
        result = {
            "question": _text(item.text, f"{path}.text", blank=False),
            "scope": item.scope.value, "participantId": target, "answers": {},
            "order": order, "source": item.source, "deleted_at": item.deleted_at,
        }
        by_id = {}
        for answer in item.answers:
            participant = str(answer.participant_id)
            if str(answer.id) in answer_ids or participant in result["answers"]:
                _invalid(path, "duplicate answer ID or participant answer")
            answer_ids.add(str(answer.id))
            if answer.question_id != item.id or answer.session_id != detail.id or answer.organisation_id != detail.organisation_id:
                _invalid(path, "answer references a foreign question/session/organisation")
            if participant not in participant_ids or (target is not None and target != participant):
                _invalid(path, "answer belongs to an unknown or different participant")
            by_id[answer.id] = answer
            result["answers"][participant] = {
                "answer": answer.body, "branchesCollapsed": answer.branches_collapsed, "branches": []
            }
        for child in item.follow_ups:
            parent_answer = by_id.get(child.triggering_answer_id)
            if parent_answer is None:
                _invalid(path, "follow-up references an answer outside its parent question")
            result["answers"][str(parent_answer.participant_id)]["branches"].append(
                node(child, parent_answer, depth + 1)
            )
        if item.knowledge_question_id or item.template_question_id:
            warnings.append(f"{path}: Knowledge/template links were not imported.")
        return result

    flow = [node(item) for item in detail.questions]
    if detail.visibility.value != "private" or detail.status.value != "draft" or detail.department_id or detail.team_id or detail.template_id:
        warnings.append("Imported as a new private draft; sharing, lifecycle and template/account links are not copied.")
    values = {
        "title": _text(detail.title, "session.title", blank=False, limit=500),
        "owner_text": _text(detail.owner_text, "session.owner_text", limit=255) if detail.owner_text is not None else None,
        "context_reference": detail.context_reference,
    }
    return values, participants, flow, warnings
