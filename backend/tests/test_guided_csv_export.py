import csv
import io
from datetime import UTC, datetime
from uuid import uuid4

import pytest

from app.schemas.guided import GuidedSessionResponse
from app.services.guided import GuidedService


def synthetic_session() -> GuidedSessionResponse:
    now = datetime.now(UTC).isoformat()
    organisation_id = str(uuid4())
    user_id = str(uuid4())
    session_id = str(uuid4())
    participant_id = str(uuid4())
    root_question_id = str(uuid4())
    root_answer_id = str(uuid4())
    nested_question_id = str(uuid4())
    nested_answer_id = str(uuid4())

    def question(question_id: str, text: str, order: int) -> dict:
        return {
            "id": question_id,
            "created_at": now,
            "updated_at": now,
            "organisation_id": organisation_id,
            "session_id": session_id,
            "template_question_id": None,
            "created_by": user_id,
            "text": text,
            "scope": "shared",
            "target_participant_id": None,
            "source": "manual",
            "main_order_index": order,
            "branch_order_index": None,
            "triggering_answer_id": None,
            "knowledge_question_id": None,
            "deleted_at": None,
        }

    root = question(root_question_id, " \t=1+1", 0)
    root["answers"] = [
        {
            "id": root_answer_id,
            "created_at": now,
            "updated_at": now,
            "organisation_id": organisation_id,
            "session_id": session_id,
            "question_id": root_question_id,
            "participant_id": participant_id,
            "answered_by_user_id": user_id,
            "body": '=HYPERLINK("x","y"),\nnext line',
            "branches_collapsed": False,
        }
    ]
    nested = question(nested_question_id, "@SUM(1,1)", 0)
    nested["answers"] = [
        {
            "id": nested_answer_id,
            "created_at": now,
            "updated_at": now,
            "organisation_id": organisation_id,
            "session_id": session_id,
            "question_id": nested_question_id,
            "participant_id": participant_id,
            "answered_by_user_id": user_id,
            "body": "-1+1",
            "branches_collapsed": False,
        }
    ]
    nested["follow_ups"] = []
    root["follow_ups"] = [nested]

    return GuidedSessionResponse.model_validate(
        {
            "id": session_id,
            "created_at": now,
            "updated_at": now,
            "organisation_id": organisation_id,
            "created_by": user_id,
            "template_id": None,
            "template_version_id": None,
            "title": "\r-1+1",
            "owner_text": None,
            "context_reference": None,
            "department_id": None,
            "team_id": None,
            "visibility": "private",
            "status": "draft",
            "revision": 1,
            "started_at": None,
            "completed_at": None,
            "participants": [
                {
                    "id": participant_id,
                    "created_at": now,
                    "updated_at": now,
                    "organisation_id": organisation_id,
                    "session_id": session_id,
                    "name": "\n+1+1",
                    "role_label": None,
                    "linked_user_id": None,
                    "notes": None,
                    "sort_order": 0,
                }
            ],
            "questions": [root],
            "prepared_question_count": 2,
            "follow_up_count": 1,
        }
    )


@pytest.mark.asyncio
async def test_csv_export_escapes_formulas_and_preserves_quoted_nested_content():
    detail = synthetic_session()
    service = GuidedService(None)

    async def get_session(*_args, **_kwargs):
        return detail

    service.get_session = get_session
    exported = await service.export_csv(
        detail.id, detail.organisation_id, detail.created_by
    )
    rows = list(csv.reader(io.StringIO(exported)))

    assert rows[0] == [
        "session_title",
        "participant",
        "scope",
        "type",
        "depth",
        "question",
        "answer",
        "returns_to",
    ]
    assert rows[1] == [
        "'\r-1+1",
        "'\n+1+1",
        "shared",
        "question",
        "0",
        "' \t=1+1",
        '\'=HYPERLINK("x","y"),\nnext line',
        "",
    ]
    assert rows[2] == [
        "'\r-1+1",
        "'\n+1+1",
        "shared",
        "follow_up",
        "1",
        "'@SUM(1,1)",
        "'-1+1",
        "main path",
    ]


@pytest.mark.asyncio
async def test_json_export_keeps_original_unescaped_user_content():
    detail = synthetic_session()
    service = GuidedService(None)

    async def get_session(*_args, **_kwargs):
        return detail

    service.get_session = get_session
    exported = await service.export_json(
        detail.id, detail.organisation_id, detail.created_by
    )

    assert exported["session"]["title"] == "\r-1+1"
    assert exported["session"]["participants"][0]["name"] == "\n+1+1"
    (root,) = exported["session"]["questions"]
    assert root["text"] == " \t=1+1"
    assert root["answers"][0]["body"] == '=HYPERLINK("x","y"),\nnext line'
    assert root["follow_ups"][0]["text"] == "@SUM(1,1)"
    assert root["follow_ups"][0]["answers"][0]["body"] == "-1+1"
