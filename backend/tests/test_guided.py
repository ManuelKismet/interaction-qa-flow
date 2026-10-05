from uuid import UUID

import pytest
from sqlalchemy import func, select

from app.models.audit_event import AuditAction, AuditEvent
from app.models.guided import GuidedQuestion, GuidedSession, KnowledgeProposal
from app.models.question import Question
from app.models.question_embedding import QuestionEmbedding
from tests.test_answer_governance import headers, seed_governance


async def create_session(client, ids, *, title="Incident review", template_id=None):
    payload = {
        "title": title,
        "owner_text": "Case owner",
        "context_reference": "INC-42",
        "department_id": str(ids["finance_department"]),
        "visibility": "private",
    }
    if template_id:
        payload["template_id"] = template_id
    response = await client.post(
        "/api/v1/guided/sessions",
        headers=headers(ids, "employee"),
        json=payload,
    )
    assert response.status_code == 201, response.text
    return response.json()


async def add_participant(client, ids, session_id, name):
    response = await client.post(
        f"/api/v1/guided/sessions/{session_id}/participants",
        headers=headers(ids, "employee"),
        json={"name": name},
    )
    assert response.status_code == 201, response.text
    return response.json()


async def add_question(client, ids, session_id, text, scope="shared", participant_id=None):
    response = await client.post(
        f"/api/v1/guided/sessions/{session_id}/questions",
        headers=headers(ids, "employee"),
        json={"text": text, "scope": scope, "target_participant_id": participant_id},
    )
    assert response.status_code == 201, response.text
    return response.json()


async def answer(client, ids, question_id, participant_id, body):
    response = await client.post(
        f"/api/v1/guided/questions/{question_id}/answers",
        headers=headers(ids, "employee"),
        json={"participant_id": participant_id, "body": body},
    )
    assert response.status_code == 200, response.text
    return response.json()


@pytest.mark.asyncio
async def test_shared_answers_have_independent_recursive_branches_and_views(app_client) -> None:
    client, session_factory = app_client
    ids = await seed_governance(session_factory)
    guided = await create_session(client, ids)
    alice = await add_participant(client, ids, guided["id"], "Alice")
    bob = await add_participant(client, ids, guided["id"], "Bob")
    shared = await add_question(client, ids, guided["id"], "What happened?")
    alice_answer = await answer(client, ids, shared["id"], alice["id"], "I received an email.")
    bob_answer = await answer(client, ids, shared["id"], bob["id"], "I received a phone call.")

    alice_follow = await client.post(
        f"/api/v1/guided/answers/{alice_answer['id']}/follow-ups",
        headers=headers(ids, "employee"),
        json={"text": "Who sent the email?"},
    )
    bob_follow = await client.post(
        f"/api/v1/guided/answers/{bob_answer['id']}/follow-ups",
        headers=headers(ids, "employee"),
        json={"text": "Who called you?"},
    )
    assert alice_follow.status_code == bob_follow.status_code == 201
    alice_follow_answer = await answer(
        client, ids, alice_follow.json()["id"], alice["id"], "Finance."
    )
    nested = await client.post(
        f"/api/v1/guided/answers/{alice_follow_answer['id']}/follow-ups",
        headers=headers(ids, "employee"),
        json={"text": "Which Finance employee?"},
    )
    assert nested.status_code == 201

    alice_flow = await client.get(
        f"/api/v1/guided/sessions/{guided['id']}",
        headers=headers(ids, "employee"),
        params={"participant_id": alice["id"], "view_mode": "all_relevant"},
    )
    root = alice_flow.json()["questions"][0]
    assert root["answers"][0]["body"] == "I received an email."
    assert root["follow_ups"][0]["text"] == "Who sent the email?"
    assert root["follow_ups"][0]["follow_ups"][0]["text"] == "Which Finance employee?"

    bob_flow = await client.get(
        f"/api/v1/guided/sessions/{guided['id']}",
        headers=headers(ids, "employee"),
        params={"participant_id": bob["id"]},
    )
    bob_root = bob_flow.json()["questions"][0]
    assert bob_root["answers"][0]["body"] == "I received a phone call."
    assert [item["text"] for item in bob_root["follow_ups"]] == ["Who called you?"]

    participant_only = await client.get(
        f"/api/v1/guided/sessions/{guided['id']}",
        headers=headers(ids, "employee"),
        params={"participant_id": alice["id"], "view_mode": "participant_only"},
    )
    assert participant_only.json()["questions"] == []


@pytest.mark.asyncio
async def test_participant_targeting_soft_delete_restore_and_exports(app_client) -> None:
    client, session_factory = app_client
    ids = await seed_governance(session_factory)
    guided = await create_session(client, ids)
    alice = await add_participant(client, ids, guided["id"], "Alice")
    bob = await add_participant(client, ids, guided["id"], "Bob")
    question = await add_question(
        client, ids, guided["id"], "What time did you arrive?", "participant", alice["id"]
    )
    wrong = await client.post(
        f"/api/v1/guided/questions/{question['id']}/answers",
        headers=headers(ids, "employee"),
        json={"participant_id": bob["id"], "body": "09:00"},
    )
    assert wrong.status_code == 409
    await answer(client, ids, question["id"], alice["id"], "08:30")

    deleted = await client.delete(
        f"/api/v1/guided/questions/{question['id']}", headers=headers(ids, "employee")
    )
    assert deleted.status_code == 200 and deleted.json()["deleted_at"]
    restored = await client.post(
        f"/api/v1/guided/questions/{question['id']}/restore", headers=headers(ids, "employee")
    )
    assert restored.status_code == 200 and restored.json()["deleted_at"] is None

    csv_export = await client.get(
        f"/api/v1/guided/sessions/{guided['id']}/export/csv", headers=headers(ids, "employee")
    )
    json_export = await client.get(
        f"/api/v1/guided/sessions/{guided['id']}/export/json", headers=headers(ids, "employee")
    )
    assert csv_export.status_code == 200 and "What time did you arrive?" in csv_export.text
    assert json_export.status_code == 200 and json_export.json()["kind"] == "intqaflow-guided-session"


@pytest.mark.asyncio
async def test_template_versions_are_snapshotted_and_answers_start_empty(app_client) -> None:
    client, session_factory = app_client
    ids = await seed_governance(session_factory)
    created = await client.post(
        "/api/v1/guided/templates",
        headers=headers(ids, "employee"),
        json={
            "name": "Exit Interview",
            "questions": [{"text": "Why are you leaving?", "scope": "shared", "order_index": 0}],
        },
    )
    assert created.status_code == 201, created.text
    template = created.json()
    session_a = await create_session(client, ids, template_id=template["id"], title="Session A")
    versioned = await client.post(
        f"/api/v1/guided/templates/{template['id']}/versions",
        headers=headers(ids, "employee"),
        json={"questions": [{"text": "What should change?", "scope": "shared", "order_index": 0}]},
    )
    assert versioned.status_code == 200 and versioned.json()["current_version"] == 2
    session_b = await create_session(client, ids, template_id=template["id"], title="Session B")
    a = await client.get(f"/api/v1/guided/sessions/{session_a['id']}", headers=headers(ids, "employee"))
    b = await client.get(f"/api/v1/guided/sessions/{session_b['id']}", headers=headers(ids, "employee"))
    assert [item["text"] for item in a.json()["questions"]] == ["Why are you leaving?"]
    assert [item["text"] for item in b.json()["questions"]] == ["What should change?"]
    assert a.json()["questions"][0]["answers"] == []
    assert a.json()["template_version_id"] != b.json()["template_version_id"]


@pytest.mark.asyncio
async def test_archived_template_can_be_restored_without_losing_versions(app_client) -> None:
    client, session_factory = app_client
    ids = await seed_governance(session_factory)
    created = await client.post(
        "/api/v1/guided/templates",
        headers=headers(ids, "employee"),
        json={
            "name": "Recoverable template",
            "questions": [{"text": "Original question", "scope": "shared", "order_index": 0}],
        },
    )
    assert created.status_code == 201
    template = created.json()
    archived = await client.post(
        f"/api/v1/guided/templates/{template['id']}/archive",
        headers=headers(ids, "employee"),
    )
    assert archived.status_code == 200
    assert archived.json()["status"] == "archived"

    denied = await client.post(
        f"/api/v1/guided/templates/{template['id']}/restore",
        headers=headers(ids, "finance_owner"),
    )
    assert denied.status_code == 403
    archived_session = await client.post(
        "/api/v1/guided/sessions",
        headers=headers(ids, "employee"),
        json={"title": "Archived template session", "template_id": template["id"]},
    )
    assert archived_session.status_code == 404

    restored = await client.post(
        f"/api/v1/guided/templates/{template['id']}/restore",
        headers=headers(ids, "employee"),
    )
    assert restored.status_code == 200
    assert restored.json()["status"] == "active"
    assert restored.json()["current_version"] == template["current_version"]
    assert [
        question["text"]
        for question in restored.json()["version"]["questions"]
    ] == ["Original question"]
    restored_session = await client.post(
        "/api/v1/guided/sessions",
        headers=headers(ids, "employee"),
        json={"title": "Restored template session", "template_id": template["id"]},
    )
    assert restored_session.status_code == 201
    assert [
        question["text"]
        for question in restored_session.json()["questions"]
    ] == ["Original question"]

    async with session_factory() as session:
        audit_actions = list(
            await session.scalars(
                select(AuditEvent.action)
                .where(AuditEvent.entity_id == UUID(template["id"]))
                .order_by(AuditEvent.created_at)
            )
        )
    assert AuditAction.GUIDED_TEMPLATE_ARCHIVED.value in audit_actions
    assert AuditAction.GUIDED_TEMPLATE_RESTORED.value in audit_actions


@pytest.mark.asyncio
async def test_default_template_and_portable_template_round_trip(app_client) -> None:
    client, session_factory = app_client
    ids = await seed_governance(session_factory)

    initial = await client.get("/api/v1/guided/templates", headers=headers(ids, "employee"))
    assert initial.status_code == 200
    assert [item["name"] for item in initial.json()] == ["General Interaction QA"]

    exported = await client.get(
        "/api/v1/guided/templates/export/all", headers=headers(ids, "employee")
    )
    assert exported.status_code == 200
    assert exported.json()["kind"] == "intqaflow-guided-templates"

    imported = await client.post(
        "/api/v1/guided/templates/import",
        headers=headers(ids, "employee"),
        json={"payload": exported.json()},
    )
    assert imported.status_code == 200, imported.text
    assert imported.json()[0]["name"] == "General Interaction QA"
    assert imported.json()[0]["current_version"] == 2
    assert len(imported.json()[0]["version"]["questions"]) == 4


@pytest.mark.asyncio
async def test_legacy_import_preserves_per_participant_nested_branches(app_client) -> None:
    client, session_factory = app_client
    ids = await seed_governance(session_factory)
    legacy = {
        "meta": {"caseTitle": "Imported case", "interviewer": "Owner", "interviewee": "INC-9"},
        "participants": [{"id": "alice", "name": "Alice"}, {"id": "bob", "name": "Bob"}],
        "activeParticipantId": "alice",
        "viewMode": "mixed",
        "flow": [
            {
                "question": "What happened?",
                "scope": "shared",
                "answers": {
                    "alice": {
                        "answer": "Email",
                        "branches": [{"question": "Who sent it?", "scope": "participant", "participantId": "alice", "answers": {"alice": {"answer": "Finance", "branches": []}}}],
                    },
                    "bob": {"answer": "Phone", "branches": []},
                },
            }
        ],
    }
    imported = await client.post(
        "/api/v1/guided/import/legacy",
        headers=headers(ids, "employee"),
        json={"payload": legacy},
    )
    assert imported.status_code == 200, imported.text
    result = imported.json()
    assert result["warnings"] == []
    session = result["session"]
    assert session["title"] == "Imported case"
    root = session["questions"][0]
    assert {item["body"] for item in root["answers"]} == {"Email", "Phone"}
    assert root["follow_ups"][0]["text"] == "Who sent it?"


@pytest.mark.asyncio
async def test_tenant_isolation_and_guided_privacy_from_search_index(app_client) -> None:
    client, session_factory = app_client
    ids = await seed_governance(session_factory)
    guided = await create_session(client, ids, title="Sensitive interview")
    participant = await add_participant(client, ids, guided["id"], "Alice")
    question = await add_question(client, ids, guided["id"], "Secret operational detail?")
    await answer(client, ids, question["id"], participant["id"], "Never index this answer")

    foreign = await client.get(
        f"/api/v1/guided/sessions/{guided['id']}",
        headers=headers(ids, "outsider", "other_organisation"),
    )
    assert foreign.status_code == 404
    async with session_factory() as session:
        assert await session.scalar(select(func.count()).select_from(QuestionEmbedding)) == 0
        stored = await session.scalar(select(GuidedSession).where(GuidedSession.id == UUID(guided["id"])))
        assert stored is not None


@pytest.mark.asyncio
async def test_session_lifecycle_revisions_and_private_visibility(app_client) -> None:
    client, session_factory = app_client
    ids = await seed_governance(session_factory)
    guided = await create_session(client, ids)

    hidden = await client.get(
        f"/api/v1/guided/sessions/{guided['id']}",
        headers=headers(ids, "finance_owner"),
    )
    assert hidden.status_code == 403

    invalid = await client.post(
        f"/api/v1/guided/sessions/{guided['id']}/complete",
        headers=headers(ids, "employee"),
    )
    assert invalid.status_code == 409
    started = await client.post(
        f"/api/v1/guided/sessions/{guided['id']}/start",
        headers=headers(ids, "employee"),
    )
    completed = await client.post(
        f"/api/v1/guided/sessions/{guided['id']}/complete",
        headers=headers(ids, "employee"),
    )
    assert started.json()["status"] == "active"
    assert completed.json()["status"] == "completed"

    revisions = await client.get(
        f"/api/v1/guided/sessions/{guided['id']}/revisions",
        headers=headers(ids, "employee"),
    )
    assert revisions.status_code == 200
    assert [item["summary"]["change"] for item in revisions.json()][:2] == [
        "Session completed",
        "Session active",
    ]


@pytest.mark.asyncio
async def test_knowledge_proposal_rejects_or_creates_primary_knowledge_with_source(app_client) -> None:
    client, session_factory = app_client
    ids = await seed_governance(session_factory)
    guided = await create_session(client, ids)
    participant = await add_participant(client, ids, guided["id"], "Alice")
    question = await add_question(client, ids, guided["id"], "How do I submit mileage?")
    guided_answer = await answer(client, ids, question["id"], participant["id"], "Use the Expenses portal.")

    proposed = await client.post(
        "/api/v1/guided/knowledge-proposals",
        headers=headers(ids, "employee"),
        json={"guided_question_id": question["id"], "guided_answer_id": guided_answer["id"]},
    )
    assert proposed.status_code == 201
    accepted = await client.post(
        f"/api/v1/guided/knowledge-proposals/{proposed.json()['id']}",
        headers=headers(ids),
        json={"action": "accept"},
    )
    assert accepted.status_code == 200, accepted.text
    assert accepted.json()["status"] == "accepted"
    assert accepted.json()["created_question_id"]

    second = await client.post(
        "/api/v1/guided/knowledge-proposals",
        headers=headers(ids, "employee"),
        json={"guided_question_id": question["id"], "guided_answer_id": guided_answer["id"]},
    )
    rejected = await client.post(
        f"/api/v1/guided/knowledge-proposals/{second.json()['id']}",
        headers=headers(ids),
        json={"action": "reject"},
    )
    assert rejected.json()["status"] == "rejected"
    async with session_factory() as session:
        proposal = await session.scalar(
            select(KnowledgeProposal).where(KnowledgeProposal.id == UUID(proposed.json()["id"]))
        )
        created_question = await session.scalar(
            select(Question).where(Question.id == proposal.created_question_id)
        )
        assert created_question is not None
        assert await session.scalar(select(func.count()).select_from(Question)) == 3


@pytest.mark.asyncio
async def test_knowledge_proposal_can_link_existing_primary_question(app_client) -> None:
    client, session_factory = app_client
    ids = await seed_governance(session_factory)
    guided = await create_session(client, ids)
    participant = await add_participant(client, ids, guided["id"], "Alice")
    question = await add_question(client, ids, guided["id"], "How do I claim mileage?")
    guided_answer = await answer(client, ids, question["id"], participant["id"], "Use the form.")
    proposed = await client.post(
        "/api/v1/guided/knowledge-proposals",
        headers=headers(ids, "employee"),
        json={"guided_question_id": question["id"], "guided_answer_id": guided_answer["id"]},
    )

    linked = await client.post(
        f"/api/v1/guided/knowledge-proposals/{proposed.json()['id']}",
        headers=headers(ids),
        json={"action": "link", "existing_question_id": str(ids["finance_question"])},
    )
    assert linked.status_code == 200, linked.text
    assert linked.json()["status"] == "duplicate"
    assert linked.json()["linked_question_id"] == str(ids["finance_question"])